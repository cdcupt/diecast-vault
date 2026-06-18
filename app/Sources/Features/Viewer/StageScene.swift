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

    /// Target on-stage size (metres) the car is normalized to, so framing/lighting
    /// are reliable regardless of the source USDF's units. Tuned so the car fills
    /// most of the dark stage (DESIGN §4.6 — the model is the brightest, largest
    /// thing on screen) while leaving headroom for the title + control bars.
    private let targetStageSize: Float = 0.34

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
        // Normalize the model to a consistent on-stage size so framing and lighting
        // are reliable regardless of the source USDZ's units (the prior version
        // framed off raw bounds, which left the procedural sample car tiny + dim).
        let rawBounds = model.visualBounds(relativeTo: nil)
        let rawMax = max(rawBounds.extents.x, max(rawBounds.extents.y, rawBounds.extents.z))
        if rawMax > 0 {
            model.scale = SIMD3(repeating: targetStageSize / rawMax)
        }

        // Re-measure after scaling, then recenter on the (now stage-sized) bounds.
        let bounds = model.visualBounds(relativeTo: nil)
        let extent = bounds.extents
        let horizontalSpan = max(extent.x, extent.z)
        // Framing: distance keyed to the model's diagonal (it sits at a 3/4 angle,
        // so the diagonal — not a single axis — is what must fit) with breathing
        // room for the title + control bars. The car fills most of the stage
        // (DESIGN §4.6) without cropping at any idle-orbit angle.
        let diagonal = (extent.x * extent.x + extent.z * extent.z).squareRoot()
        baseDistance = max(diagonal, extent.y) * 2.2 + 0.06
        // Sit the car on the plinth (y=0) and centered in x/z.
        model.position = SIMD3(-bounds.center.x, -bounds.center.y + extent.y / 2, -bounds.center.z)
        focusHeight = extent.y / 2
        pivot.addChild(model)
        self.modelRoot = model
        didLoadModel = true
        return horizontalSpan
    }

    /// Spin the turntable to `angle` radians (yaw) and tilt the car slightly.
    func orient(spin: Float, pitch: Float) {
        guard let turntable else { return }
        turntable.orientation =
            simd_quatf(angle: spin, axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: pitch, axis: SIMD3(1, 0, 0))
    }

    /// Dolly the camera in/out for pinch zoom (clamped multiplier applied by view).
    /// Keeps the same slight downward tilt and look-target (`focusHeight`) as the
    /// initial framing so the car stays centered on the stage while zooming.
    func zoom(_ factor: Float) {
        guard let cam = cameraEntity else { return }
        let distance = baseDistance / factor
        cam.position = SIMD3(0, focusHeight + baseDistance * 0.12, distance)
        cam.look(at: SIMD3(0, focusHeight, 0), from: cam.position, relativeTo: nil)
    }

    // MARK: Lights

    private func makeKeyLight() -> Entity {
        // Warm tungsten "spotlight" from front-above. Positions scale with the
        // stage size, and intensity is raised so the (now larger) car reads
        // clearly and brightly against stage-0 instead of dim.
        let e = Entity()
        var spot = SpotLightComponent(
            color: color(Palette.tungstenGlow),
            intensity: 60000,
            innerAngleInDegrees: 38,
            outerAngleInDegrees: 78,
            attenuationRadius: 12
        )
        spot.attenuationRadius = 12
        e.components.set(spot)
        e.position = SIMD3(targetStageSize * 0.5, targetStageSize * 1.5, targetStageSize * 1.2)
        e.look(at: SIMD3(0, focusHeight, 0), from: e.position, relativeTo: nil)
        return e
    }

    private func makeFillLight() -> Entity {
        // Cool, soft fill so the shadowed far side isn't black — brightened
        // markedly (directional intensity is in lux) to lift the body.
        let e = Entity()
        let dir = DirectionalLightComponent(color: color(Palette.steelSoft), intensity: 2600)
        e.components.set(dir)
        e.look(at: SIMD3(0, focusHeight, 0), from: SIMD3(-targetStageSize, targetStageSize * 0.7, targetStageSize), relativeTo: nil)
        return e
    }

    private func makeRimLight() -> Entity {
        // Tungsten rim from behind + below, raking a warm brand edge along the car
        // (the horizon glow). Scaled + brightened for the larger stage.
        let e = Entity()
        var point = PointLightComponent(
            color: color(Palette.stageRim),
            intensity: 14000,
            attenuationRadius: 6
        )
        point.attenuationRadius = 6
        e.components.set(point)
        e.position = SIMD3(0, focusHeight * 0.4, -targetStageSize * 1.1)
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
