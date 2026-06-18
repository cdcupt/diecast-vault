import SwiftUI
import RealityKit
import DiecastVaultCore

/// Primary Spike-1 renderer: a true real-time RealityKit scene.
///
/// What it proves (PRD Spike-1 go/no-go):
/// - A cabinet frame with a grid of niches (here 4 columns × up to 6 rows,
///   covering the PRD's 12–24-car range).
/// - The **lit-niche look**: each LIT niche has its own warm point light pooling
///   tungsten glow; MATTE recesses stay unlit. Light = state, in 3D.
/// - Placeholder low-poly cars (procedural primitives, no bundled USDZ needed to
///   de-risk the *rendering + cost* question — see the LOD note below).
/// - A clamped **orbit + tilt** drag gesture, plus optional CoreMotion gyro
///   parallax, with a reduced-motion path that pins the camera front-on but
///   still renders the lit scene.
///
/// LOD / billboard plan (validated structurally here, full USDZ deferred): the
/// production scene keeps **≤ 1 full USDZ resident** — only the focused "hero"
/// niche — while every other niche is a billboard/low-LOD impostor (reuses the
/// R2 poster). In this spike the "hero" car gets a richer procedural body and a
/// brighter key light to stand in for the promoted full-USDZ slot; the rest are
/// cheaper shells standing in for impostors. Promotion/demotion of real USDZ is
/// a later slice; this proves the scene graph + lighting + interaction hold.
@available(iOS 18.0, *)
@MainActor
struct RealityKitCabinetRenderer: CabinetRenderer {
    let rendererName = "RealityKit (primary)"

    func makeView(shelf: [Release], harness: PerfHarness) -> AnyView {
        AnyView(RealityKitCabinetView(shelf: shelf, harness: harness))
    }
}

@available(iOS 18.0, *)
private struct RealityKitCabinetView: View {
    let shelf: [Release]
    @ObservedObject var harness: PerfHarness
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Clamped orbit/tilt state, driven by the drag gesture.
    @State private var yaw: Float = 0          // left/right orbit
    @State private var pitch: Float = 0.18      // up/down tilt (slightly above)
    @GestureState private var dragDelta: CGSize = .zero

    private let scene = CabinetScene()

    var body: some View {
        RealityView { content in
            scene.build(in: content, shelf: shelf, reduceMotion: reduceMotion)
        } update: { _ in
            // Apply the clamped camera orientation each update.
            let liveYaw = reduceMotion ? 0 : yaw + Float(dragDelta.width) * 0.006
            let livePitch = reduceMotion ? 0.18 : clampPitch(pitch - Float(dragDelta.height) * 0.006)
            scene.orient(yaw: clampYaw(liveYaw), pitch: livePitch)
        }
        .gesture(orbitGesture)
        .ignoresSafeArea()
        .background(Color(Palette.stage0))  // the single dark surface
        .onAppear { harness.start() }
        .onDisappear {
            harness.stop()
            scene.stopMotion()
        }
        .accessibilityLabel("3D cabinet, \(shelf.count) niches, \(shelf.filter(\.isLit).count) lit")
    }

    private var orbitGesture: some Gesture {
        DragGesture()
            .updating($dragDelta) { value, state, _ in
                state = value.translation
            }
            .onEnded { value in
                guard !reduceMotion else { return }
                yaw = clampYaw(yaw + Float(value.translation.width) * 0.006)
                pitch = clampPitch(pitch - Float(value.translation.height) * 0.006)
            }
    }

    // Clamp bounds keep the cabinet always readable (no flipping behind / under).
    private func clampYaw(_ v: Float) -> Float { min(max(v, -0.6), 0.6) }
    private func clampPitch(_ v: Float) -> Float { min(max(v, -0.15), 0.5) }
}
