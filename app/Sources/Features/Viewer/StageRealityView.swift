import SwiftUI
import RealityKit
import DiecastVaultCore

/// iOS 18+ `RealityView` host for the dark stage. Drives `StageScene` with a
/// clamped drag (yaw + pitch), pinch zoom, and a slow idle auto-orbit that stops
/// on first touch — honoring reduce-motion by pinning the idle spin off.
@available(iOS 18.0, *)
struct StageRealityView: View {
    let release: Release
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let scene = StageScene()

    // Committed orientation/zoom (persist between gestures).
    @State private var spin: Float = 0.5          // starting 3/4 angle
    @State private var pitch: Float = 0.12
    @State private var zoom: Float = 1.0
    @State private var idleSpin: Float = 0
    @State private var hasInteracted = false

    @GestureState private var dragDelta: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1

    /// Idle auto-orbit driver — a slow steady yaw until the first touch.
    private let autoOrbit = Timer.publish(every: 1.0 / 30.0, on: .main, in: .common).autoconnect()

    var body: some View {
        RealityView { content in
            scene.build(in: content, modelURL: SampleModel.url, reduceMotion: reduceMotion)
            scene.orient(spin: spin, pitch: pitch)
        } update: { _ in
            let liveSpin = spin + idleSpin + Float(dragDelta.width) * 0.008
            let livePitch = clampPitch(pitch - Float(dragDelta.height) * 0.006)
            scene.orient(spin: liveSpin, pitch: livePitch)
            scene.zoom(clampZoom(zoom * Float(pinchScale)))
        }
        .gesture(orbitGesture)
        .simultaneousGesture(zoomGesture)
        .ignoresSafeArea()
        .onReceive(autoOrbit) { _ in
            guard !reduceMotion, !hasInteracted else { return }
            idleSpin += 0.004   // ~7°/s drift
        }
        .accessibilityLabel(Text("viewer.stage.a11y \(release.name)"))
    }

    private var orbitGesture: some Gesture {
        DragGesture()
            .updating($dragDelta) { value, state, _ in state = value.translation }
            .onChanged { _ in stopIdle() }
            .onEnded { value in
                spin += idleSpin + Float(value.translation.width) * 0.008
                pitch = clampPitch(pitch - Float(value.translation.height) * 0.006)
                idleSpin = 0
            }
    }

    private var zoomGesture: some Gesture {
        MagnificationGesture()
            .updating($pinchScale) { value, state, _ in state = value }
            .onChanged { _ in stopIdle() }
            .onEnded { value in zoom = clampZoom(zoom * Float(value)) }
    }

    private func stopIdle() {
        if !hasInteracted {
            // Fold the accumulated idle drift into the committed spin so the car
            // doesn't jump when auto-orbit stops.
            spin += idleSpin
            idleSpin = 0
            hasInteracted = true
        }
    }

    private func clampPitch(_ v: Float) -> Float { min(max(v, -0.3), 0.5) }
    private func clampZoom(_ v: Float) -> Float { min(max(v, 0.6), 2.2) }
}
