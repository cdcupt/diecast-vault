import SwiftUI
import RealityKit
import DiecastVaultCore

/// Primary renderer: the real-time RealityKit cabinet that IS the Home.
///
/// - A cabinet frame with a grid of niches (4 columns), themed per `CabinetStyle`.
/// - The **lit-niche look**: each LIT niche has its own light pooling glow in the
///   style's temperature; MATTE recesses stay unlit. Light = state, in 3D.
/// - **LOD**: the focused/nearest lit niche renders the bundled full USDZ; every
///   other niche is a lightweight procedural impostor so a full shelf stays
///   performant.
/// - A clamped **orbit + tilt** drag gesture, plus optional CoreMotion gyro
///   parallax, with a reduced-motion path that pins the camera front-on but still
///   renders the lit scene.
/// - **Tap to route**: tapping a niche calls back with its `Release` so the Home
///   can open Release detail (owned/lit) or the catalog/pick path (matte).
@available(iOS 18.0, *)
@MainActor
struct RealityKitCabinetRenderer: CabinetRenderer {
    let rendererName = "RealityKit (primary)"

    func makeView(shelf: [Release], style: CabinetStyle, modelURL: URL?, harness: PerfHarness, onSelect: @escaping (Release) -> Void) -> AnyView {
        AnyView(RealityKitCabinetView(shelf: shelf, style: style, modelURL: modelURL, harness: harness, onSelect: onSelect))
    }
}

@available(iOS 18.0, *)
private struct RealityKitCabinetView: View {
    let shelf: [Release]
    let style: CabinetStyle
    let modelURL: URL?
    @ObservedObject var harness: PerfHarness
    let onSelect: (Release) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Clamped orbit/tilt state, driven DIRECTLY by the drag gesture handler.
    // Not via `@GestureState` + the RealityView `update:` closure: on iOS 18 the
    // `update:` closure is not reliably re-invoked while a gesture is in flight,
    // so the old "`.updating($dragDelta)` → read `dragDelta` in `update:`" path
    // never moved the camera in the Simulator. We now mutate `@State` in
    // `.onChanged` and call `scene.orient(...)` synchronously, so rotation does
    // not depend on the `update:` closure re-running at all (Defect 2 root cause).
    @State private var yaw: Float = 0          // left/right orbit
    @State private var pitch: Float = 0.07      // up/down tilt (near head-on)
    // Anchor captured at drag start so each move is relative to where the orbit
    // began (no jump), and the final value persists after `.onEnded`.
    @State private var dragAnchorYaw: Float = 0
    @State private var dragAnchorPitch: Float = 0.07
    @State private var isDragging = false

    // Debug-harness live readout (env-gated, OFF by default).
    @State private var lastSelectedName = "—"

    private let scene = CabinetScene()

    /// `DV_GESTURE_DEBUG=1` overlays an XCUITest-drivable button harness that
    /// exercises the SAME orient/route pipelines the gestures use, so QA can PROVE
    /// the pipeline works end-to-end even though synthetic touches don't reach the
    /// RealityKit hit-test layer. OFF in the normal app.
    private static var showsGestureDebug: Bool {
        ProcessInfo.processInfo.environment["DV_GESTURE_DEBUG"] == "1"
    }

    var body: some View {
        ZStack {
            RealityView { content in
                scene.build(in: content, shelf: shelf, style: style, modelURL: modelURL, reduceMotion: reduceMotion)
                applyOrientation()
            } update: { _ in
                // Belt-and-braces: re-apply the current orientation on any rebuild
                // (e.g. reduce-motion / gyro changes). The drag itself no longer
                // relies on this closure firing — `.onChanged` orients directly.
                applyOrientation()
            }
            // The RealityView must own the WHOLE area for hit-testing so the
            // gestures land anywhere on the cabinet, not just on opaque content.
            .contentShape(Rectangle())
            // A stationary tap routes (opens detail); a drag orbits. Compose them
            // explicitly so a tap AND a drag can both be recognized (a bare
            // `.simultaneousGesture(tap)` + `.gesture(drag)` could let the drag
            // win outright). The drag carries `minimumDistance` so a stationary
            // tap is not consumed and falls through to the spatial tap.
            .gesture(orbitGesture.simultaneously(with: tapGesture))
            .ignoresSafeArea()
            .background(Color(style.theme.stageBackdrop))
            .onAppear { harness.start() }
            .onDisappear {
                harness.stop()
                scene.stopMotion()
            }
            .accessibilityLabel("3D cabinet, \(shelf.count) niches, \(shelf.filter(\.isLit).count) lit")

            if Self.showsGestureDebug { debugHarness }
        }
    }

    /// Apply the live clamped orientation to the scene's camera rig.
    private func applyOrientation() {
        let liveYaw = reduceMotion ? 0 : clampYaw(yaw)
        let livePitch = reduceMotion ? 0.07 : clampPitch(pitch)
        scene.orient(yaw: liveYaw, pitch: livePitch)
    }

    /// Tap a niche → route by light-as-state (lit → detail, matte → catalog/pick).
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                if let release = scene.release(forHitName: value.entity.name) {
                    lastSelectedName = release.name
                    onSelect(release)
                }
            }
    }

    private var orbitGesture: some Gesture {
        // `minimumDistance` of 10pt means a stationary tap is NOT consumed by the
        // drag (it falls through to the simultaneous SpatialTapGesture), and only a
        // deliberate finger/mouse drag past the threshold starts the orbit. The
        // camera is oriented synchronously here, NOT via the RealityView `update:`
        // closure (which is unreliable mid-gesture on iOS 18).
        DragGesture(minimumDistance: 10)
            .onChanged { value in
                guard !reduceMotion else { return }
                if !isDragging {
                    isDragging = true
                    dragAnchorYaw = yaw
                    dragAnchorPitch = pitch
                }
                yaw = clampYaw(dragAnchorYaw + Float(value.translation.width) * orbitSensitivity)
                pitch = clampPitch(dragAnchorPitch - Float(value.translation.height) * orbitSensitivity)
                applyOrientation()
            }
            .onEnded { value in
                guard !reduceMotion else { return }
                yaw = clampYaw(dragAnchorYaw + Float(value.translation.width) * orbitSensitivity)
                pitch = clampPitch(dragAnchorPitch - Float(value.translation.height) * orbitSensitivity)
                isDragging = false
                applyOrientation()
            }
    }

    // MARK: Debug harness (env-gated, OFF by default)

    /// XCUITest-drivable proof harness for `DV_GESTURE_DEBUG=1`. Buttons call the
    /// SAME `scene.orient(...)` / `onSelect` paths the real gestures use, isolating
    /// "pipeline broken" from "gesture recognition broken". Synthetic touches can't
    /// reach RealityKit's hit-test layer, but SwiftUI Buttons ARE XCUITest-drivable.
    private var debugHarness: some View {
        VStack(spacing: 10) {
            Spacer()
            HStack(spacing: 8) {
                debugButton("Yaw −", "dbg.yawMinus") { nudgeYaw(-0.25) }
                debugButton("Yaw +", "dbg.yawPlus") { nudgeYaw(0.25) }
                debugButton("Pitch −", "dbg.pitchMinus") { nudgePitch(-0.1) }
                debugButton("Pitch +", "dbg.pitchPlus") { nudgePitch(0.1) }
            }
            debugButton("Open first model", "dbg.openFirst") { openFirst() }
            Text(String(format: "yaw %.3f · pitch %.3f", yaw, pitch))
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundStyle(.white)
                .accessibilityIdentifier("dbg.readout")
            Text("last: \(lastSelectedName)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityIdentifier("dbg.lastSelected")
        }
        .padding(12)
        .background(Color.black.opacity(0.6))
        .padding(.bottom, 30)
    }

    private func debugButton(_ title: String, _ id: String, _ action: @escaping () -> Void) -> some View {
        Button(title, action: action)
            .font(.system(size: 13, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.18)))
            .accessibilityIdentifier(id)
    }

    private func nudgeYaw(_ delta: Float) {
        yaw = clampYaw(yaw + delta)
        applyOrientation()
    }

    private func nudgePitch(_ delta: Float) {
        pitch = clampPitch(pitch + delta)
        applyOrientation()
    }

    /// Drive the SAME route a niche tap would: the first selectable release.
    private func openFirst() {
        guard let release = shelf.first(where: \.isLit) ?? shelf.first else { return }
        lastSelectedName = release.name
        onSelect(release)
    }

    // Drag → orbit tuning. The sensitivity converts drag points to radians; the
    // clamps keep the cabinet readable (no flipping behind / under). Yaw is a wide
    // turntable arc (≈ ±115°) so a normal drag visibly spins the case — the only
    // motion path in the Simulator, where there is no gyro (Defect 2). Pitch stays
    // tight so rows never foreshorten away or flip over the top.
    private let orbitSensitivity: Float = 0.011
    private func clampYaw(_ v: Float) -> Float { min(max(v, -2.0), 2.0) }
    private func clampPitch(_ v: Float) -> Float { min(max(v, -0.25), 0.6) }
}
