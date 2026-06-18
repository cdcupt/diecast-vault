import SwiftUI
import RealityKit
import DiecastVaultCore

/// Builds and drives the single dark surface — the 3D viewer stage (DESIGN §4.6).
/// A spotlit turntable over `stage-0`, a thin tungsten rim/horizon, and the
/// bundled USDZ as the brightest thing on screen. Kept separate from the SwiftUI
/// view so the geometry/lighting/turntable logic stays declarative-by-reading.
///
/// The car sits on a `turntable` pivot the view rotates: a slow idle auto-orbit
/// that stops on first touch, then user drag (yaw + clamped pitch) and pinch
/// (clamped zoom).
@available(iOS 18.0, *)
@MainActor
final class StageScene {
    private var turntable: Entity?
    private var cameraEntity: Entity?
    private var modelRoot: Entity?

    /// Whether the bundled USDZ actually loaded (the view shows a fallback if not).
    private(set) var didLoadModel = false

    // Camera framing (overridden once model bounds are known).
    private var baseDistance: Float = 0.6
    /// Height of the car's center above the plinth — the camera's look target, so
    /// the car sits centered on the dark stage rather than down by the controls.
    private var focusHeight: Float = 0.04

    func build(in content: RealityViewCameraContent, modelURL: URL?, reduceMotion: Bool) {
        let root = Entity()
        content.add(root)

        // Turntable pivot at origin; the car is parented to it so spinning the
        // pivot spins the car while lights/camera stay put.
        let pivot = Entity()
        root.addChild(pivot)
        self.turntable = pivot

        let modelSpan = loadModel(from: modelURL, into: pivot)

        // A subtle plinth disc under the car for grounding (stage-1 material),
        // sized just inside the car's footprint so the car reads as the subject.
        let plinthRadius = max(modelSpan * 0.6, 0.04)
        let plinth = ModelEntity(
            mesh: .generateCylinder(height: 0.006, radius: plinthRadius),
            materials: [matte(color(Palette.stage1), roughness: 0.6)]
        )
        plinth.position = SIMD3(0, -0.004, 0)
        root.addChild(plinth)

        // Lighting: a warm tungsten key from front-above (the "spotlight"), a cool
        // low fill so the far side isn't black, and a tungsten rim from behind for
        // the brand horizon glow.
        root.addChild(makeKeyLight())
        root.addChild(makeFillLight())
        root.addChild(makeRimLight())

        // Camera pushed back along +Z, angled slightly down onto the turntable.
        let camRig = Entity()
        let cam = Entity()
        var perspective = PerspectiveCameraComponent()
        perspective.fieldOfViewInDegrees = 38
        cam.components.set(perspective)
        cam.position = SIMD3(0, focusHeight + baseDistance * 0.12, baseDistance)
        cam.look(at: SIMD3(0, focusHeight, 0), from: cam.position, relativeTo: nil)
        camRig.addChild(cam)
        content.add(camRig)
        self.cameraEntity = cam
    }

    /// Loads, recenters, and frames the model. Returns its horizontal span (max
    /// of width/depth) so the plinth can be sized to the footprint. Falls back to
    /// a default span when no model is available.
    @discardableResult
    private func loadModel(from url: URL?, into pivot: Entity) -> Float {
        guard let url, let model = try? Entity.load(contentsOf: url) else {
            didLoadModel = false
            return 0.12
        }
        // Frame the loaded model: recenter on its bounds and scale the camera
        // distance so it fills the stage regardless of source units.
        let bounds = model.visualBounds(relativeTo: nil)
        let extent = bounds.extents
        let maxDim = max(extent.x, max(extent.y, extent.z))
        if maxDim > 0 {
            // Tight framing: the USDZ should be the brightest, largest thing on
            // the stage (DESIGN §4.6), leaving headroom for the title/control bar.
            baseDistance = maxDim * 1.9 + 0.06
        }
        // Sit the car on the plinth (y=0) and centered in x/z.
        model.position = SIMD3(-bounds.center.x, -bounds.center.y + extent.y / 2, -bounds.center.z)
        focusHeight = extent.y / 2
        pivot.addChild(model)
        self.modelRoot = model
        didLoadModel = true
        return max(extent.x, extent.z)
    }

    /// Spin the turntable to `angle` radians (yaw) and tilt the car slightly.
    func orient(spin: Float, pitch: Float) {
        guard let turntable else { return }
        turntable.orientation =
            simd_quatf(angle: spin, axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0))
    }

    /// Dolly the camera in/out for pinch zoom (clamped multiplier applied by view).
    func zoom(_ factor: Float) {
        guard let cam = cameraEntity else { return }
        let distance = baseDistance / factor
        cam.position = SIMD3(0, baseDistance * 0.22, distance)
        cam.look(at: SIMD3(0, 0.02, 0), from: cam.position, relativeTo: nil)
    }

    // MARK: Lights

    private func makeKeyLight() -> Entity {
        let e = Entity()
        var spot = SpotLightComponent(
            color: color(Palette.tungstenGlow),
            intensity: 9000,
            innerAngleInDegrees: 32,
            outerAngleInDegrees: 66,
            attenuationRadius: 4
        )
        spot.attenuationRadius = 4
        e.components.set(spot)
        e.position = SIMD3(0.18, 0.5, 0.42)
        e.look(at: SIMD3(0, 0.02, 0), from: e.position, relativeTo: nil)
        return e
    }

    private func makeFillLight() -> Entity {
        let e = Entity()
        let dir = DirectionalLightComponent(color: .white, intensity: 600)
        e.components.set(dir)
        e.look(at: SIMD3(0, 0, 0), from: SIMD3(-0.4, 0.2, 0.5), relativeTo: nil)
        return e
    }

    private func makeRimLight() -> Entity {
        let e = Entity()
        var point = PointLightComponent(
            color: color(Palette.stageRim),
            intensity: 1400,
            attenuationRadius: 2
        )
        point.attenuationRadius = 2
        e.components.set(point)
        // Behind + below so it rakes a tungsten edge along the car (the horizon).
        e.position = SIMD3(0, -0.05, -0.32)
        return e
    }

    // MARK: Materials (mirrors CabinetScene's PBR helpers)

    private func matte(_ c: UIColor, roughness: Float) -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: c)
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = .init(floatLiteral: 0)
        return m
    }

    private func color(_ token: PaletteToken) -> UIColor {
        UIColor(red: token.red, green: token.green, blue: token.blue, alpha: 1)
    }
}
