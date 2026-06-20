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

    // Clamped orbit/tilt state, driven by the drag gesture.
    @State private var yaw: Float = 0          // left/right orbit
    @State private var pitch: Float = 0.07      // up/down tilt (near head-on)
    @GestureState private var dragDelta: CGSize = .zero

    private let scene = CabinetScene()

    var body: some View {
        RealityView { content in
            scene.build(in: content, shelf: shelf, style: style, modelURL: modelURL, reduceMotion: reduceMotion)
        } update: { _ in
            // Apply the clamped camera orientation each update.
            let liveYaw = reduceMotion ? 0 : yaw + Float(dragDelta.width) * orbitSensitivity
            let livePitch = reduceMotion ? 0.07 : clampPitch(pitch - Float(dragDelta.height) * orbitSensitivity)
            scene.orient(yaw: clampYaw(liveYaw), pitch: livePitch)
        }
        // A stationary tap routes (opens detail) while a drag orbits. Compose them
        // simultaneously and give the drag a `minimumDistance` so the touch-down
        // isn't swallowed before the SpatialTapGesture can fire — previously the
        // last-attached zero-distance DragGesture captured every touch and the tap
        // never landed (Defect 1).
        .simultaneousGesture(tapGesture)
        .gesture(orbitGesture)
        .ignoresSafeArea()
        .background(Color(style.theme.stageBackdrop))
        .onAppear { harness.start() }
        .onDisappear {
            harness.stop()
            scene.stopMotion()
        }
        .accessibilityLabel("3D cabinet, \(shelf.count) niches, \(shelf.filter(\.isLit).count) lit")
    }

    /// Tap a niche → route by light-as-state (lit → detail, matte → catalog/pick).
    private var tapGesture: some Gesture {
        SpatialTapGesture()
            .targetedToAnyEntity()
            .onEnded { value in
                if let release = scene.release(forHitName: value.entity.name) {
                    onSelect(release)
                }
            }
    }

    private var orbitGesture: some Gesture {
        // `minimumDistance` of 10pt means a stationary tap is NOT consumed by the
        // drag (it falls through to the simultaneous SpatialTapGesture), and only a
        // deliberate finger/mouse drag past the threshold starts the orbit.
        DragGesture(minimumDistance: 10)
            .updating($dragDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                guard !reduceMotion else { return }
                yaw = clampYaw(yaw + Float(value.translation.width) * orbitSensitivity)
                pitch = clampPitch(pitch - Float(value.translation.height) * orbitSensitivity)
            }
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
