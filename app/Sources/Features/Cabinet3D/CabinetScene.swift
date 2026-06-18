import SwiftUI
import RealityKit
import CoreMotion
import simd
import DiecastVaultCore

/// Builds and drives the RealityKit cabinet scene graph. Kept separate from the
/// SwiftUI view so the geometry/lighting/camera logic is testable-by-reading and
/// the view stays declarative.
@available(iOS 18.0, *)
@MainActor
final class CabinetScene {
    // MARK: Layout constants (a wall-mounted vitrine of lit cells).
    private let columns = 4
    private let nicheSize: Float = 0.26      // niche opening (square-ish)
    private let nicheDepth: Float = 0.18
    private let gap: Float = 0.03            // shelf-edge gap between cells
    private let wallThickness: Float = 0.02

    private var cameraRig: Entity?
    private var camera: PerspectiveCameraComponent?

    // CoreMotion gyro parallax (subtle camera lean toward device tilt).
    private let motion = CMMotionManager()
    private var motionAttitude: simd_float2 = .zero  // (roll, pitch) offsets
    private var reduceMotion = false

    // MARK: Build

    func build(in content: RealityViewCameraContent, shelf: [Release], reduceMotion: Bool) {
        self.reduceMotion = reduceMotion

        let root = Entity()
        content.add(root)

        let rows = Int(ceil(Double(shelf.count) / Double(columns)))
        let cell = nicheSize + gap
        let boardWidth = Float(columns) * cell - gap
        let boardHeight = Float(rows) * cell - gap

        // The warm cabinet carcass (light chrome around the dark stage): a back
        // panel + outer frame in a near-white surface so niches read as recesses.
        root.addChild(makeCarcass(width: boardWidth, height: boardHeight))

        // A glowing lightbar strip across the top (the signature fixture).
        root.addChild(makeLightbar(width: boardWidth, topY: boardHeight / 2))

        // Lay out niches centered on origin.
        for (index, release) in shelf.enumerated() {
            let col = index % columns
            let row = index / columns
            let x = -boardWidth / 2 + nicheSize / 2 + Float(col) * cell
            let y = boardHeight / 2 - nicheSize / 2 - Float(row) * cell
            let isHero = release.isLit && firstLitIndex(shelf) == index
            root.addChild(makeNiche(release: release, isHero: isHero, at: SIMD3(x, y, 0)))
        }

        // Ambient fill so MATTE recesses are still legible, plus a soft key light.
        // (Lighting is fully explicit — point/spot/directional below — so we keep
        // the default RealityView environment rather than constructing one.)
        root.addChild(makeFillLight())

        // Camera rig: a pivot at origin with the camera pushed back along +Z.
        let rig = Entity()
        let camEntity = Entity()
        var cam = PerspectiveCameraComponent()
        cam.fieldOfViewInDegrees = 42
        camEntity.components.set(cam)
        // Distance scales with board size so the whole vitrine frames nicely.
        let distance = max(boardWidth, boardHeight) * 1.5 + 0.4
        camEntity.position = SIMD3(0, 0, distance)
        rig.addChild(camEntity)
        content.add(rig)
        self.cameraRig = rig
        self.camera = cam

        orient(yaw: 0, pitch: 0.18)
        startMotion()
    }

    private func firstLitIndex(_ shelf: [Release]) -> Int? {
        shelf.firstIndex(where: \.isLit)
    }

    // MARK: Orientation (clamped orbit + gyro parallax)

    func orient(yaw: Float, pitch: Float) {
        guard let rig = cameraRig else { return }
        let gyroYaw = reduceMotion ? 0 : motionAttitude.x * 0.25
        let gyroPitch = reduceMotion ? 0 : motionAttitude.y * 0.25
        let q = simd_quatf(angle: yaw + gyroYaw, axis: SIMD3(0, 1, 0))
              * simd_quatf(angle: pitch + gyroPitch, axis: SIMD3(1, 0, 0))
        rig.orientation = q
    }

    // MARK: Geometry

    private func makeCarcass(width: Float, height: Float) -> Entity {
        let entity = Entity()
        // Back panel: a darker warm tone so the lit white niche faces lift off it
        // (the design's value-gap depth) and unlit recesses read as carved wells.
        let back = ModelEntity(
            mesh: .generateBox(width: width + 0.08, height: height + 0.08, depth: wallThickness),
            materials: [matte(color(Palette.cellRecess).darkened(0.45), roughness: 0.95)]
        )
        back.position = SIMD3(0, 0, -nicheDepth - wallThickness / 2)
        entity.addChild(back)
        return entity
    }

    private func makeNiche(release: Release, isHero: Bool, at position: SIMD3<Float>) -> Entity {
        let niche = Entity()
        niche.position = position

        // The recess shell: a five-sided open box (lit face vs matte fill).
        let litFace = release.isLit
        let shellColor: UIColor = litFace
            ? color(Palette.cellSurface)
            : color(Palette.cellRecess)
        let shell = ModelEntity(
            mesh: .generateBox(width: nicheSize, height: nicheSize, depth: nicheDepth),
            materials: [matte(shellColor, roughness: litFace ? 0.55 : 0.85)]
        )
        shell.position = SIMD3(0, 0, -nicheDepth / 2)
        niche.addChild(shell)

        // The car sits on the niche floor.
        let car = makeCar(release: release, isHero: isHero)
        car.position = SIMD3(0, -nicheSize / 2 + 0.03, -nicheDepth / 2 + 0.02)
        niche.addChild(car)

        // Light = state: a LIT niche gets its own warm point light pooling glow.
        // Intensities are intentionally low — these are 0.26 m niches with
        // near-white faces, so small lumen values already pool a clear glow
        // without blowing the surface out.
        if litFace {
            let light = Entity()
            var point = PointLightComponent(
                color: color(Palette.tungstenGlow),
                intensity: isHero ? 150 : 95,
                attenuationRadius: nicheSize * 1.3
            )
            point.attenuationRadius = nicheSize * 1.3
            light.components.set(point)
            // Pull the light forward and a touch lower so it rakes across the car
            // (the focal object catching the display light) rather than flooding
            // the back face.
            light.position = SIMD3(0, nicheSize / 2 - 0.05, 0.06)
            niche.addChild(light)
        }
        return niche
    }

    /// Placeholder low-poly car. The hero (promoted-USDZ stand-in) gets a richer
    /// body + cabin + four wheels; impostors get a cheaper single-block shell.
    private func makeCar(release: Release, isHero: Bool) -> Entity {
        let car = Entity()
        let bodyColor = release.drive == .lhd ? color(Palette.lhd) : color(Palette.rhd)
        let bodyMat = isHero ? glossy(bodyColor) : matte(bodyColor, roughness: 0.6)

        let w: Float = 0.16, h: Float = 0.045, d: Float = 0.07
        let body = ModelEntity(mesh: .generateBox(size: SIMD3(w, h, d), cornerRadius: 0.012), materials: [bodyMat])
        body.position = SIMD3(0, h / 2 + 0.02, 0)
        car.addChild(body)

        if isHero {
            // Cabin glasshouse for the promoted hero only (more polys = LOD high).
            let cabin = ModelEntity(
                mesh: .generateBox(size: SIMD3(w * 0.5, h * 0.9, d * 0.7), cornerRadius: 0.008),
                materials: [glossy(color(Palette.stage1))]
            )
            cabin.position = SIMD3(-0.01, h + 0.02, 0)
            car.addChild(cabin)

            let wheelR: Float = 0.018
            let wheelMesh = MeshResource.generateCylinder(height: 0.012, radius: wheelR)
            let wheelMat = matte(color(Palette.ink), roughness: 0.7)
            for sx in [Float(-1), 1] {
                for sz in [Float(-1), 1] {
                    let wheel = ModelEntity(mesh: wheelMesh, materials: [wheelMat])
                    wheel.orientation = simd_quatf(angle: .pi / 2, axis: SIMD3(0, 0, 1))
                    wheel.position = SIMD3(sx * w * 0.36, 0.018, sz * d * 0.42)
                    car.addChild(wheel)
                }
            }
        }
        return car
    }

    private func makeLightbar(width: Float, topY: Float) -> Entity {
        let bar = ModelEntity(
            mesh: .generateBox(width: width + 0.06, height: 0.02, depth: 0.03),
            materials: [emissive(color(Palette.tungsten), strength: 6)]
        )
        bar.position = SIMD3(0, topY + 0.05, 0.02)
        let holder = Entity()
        holder.addChild(bar)
        // A real light so the bar actually casts the warm wash downward.
        let wash = Entity()
        var spot = SpotLightComponent(
            color: color(Palette.tungstenGlow),
            intensity: 900,
            innerAngleInDegrees: 35,
            outerAngleInDegrees: 70,
            attenuationRadius: width * 2.2
        )
        spot.attenuationRadius = width * 2.5
        wash.components.set(spot)
        wash.position = SIMD3(0, topY + 0.06, 0.18)
        wash.look(at: SIMD3(0, 0, 0), from: wash.position, relativeTo: nil)
        holder.addChild(wash)
        return holder
    }

    private func makeFillLight() -> Entity {
        // A low, cool-neutral key from front-above so MATTE recesses stay legible
        // without flattening the warm tungsten pools in the lit niches.
        let light = Entity()
        let dir = DirectionalLightComponent(color: .white, intensity: 600)
        light.components.set(dir)
        light.look(at: SIMD3(0, -0.2, -0.4), from: SIMD3(0.3, 0.6, 0.9), relativeTo: nil)
        return light
    }

    // MARK: Materials

    private func matte(_ c: UIColor, roughness: Float) -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: c)
        m.roughness = .init(floatLiteral: roughness)
        m.metallic = .init(floatLiteral: 0)
        return m
    }

    private func glossy(_ c: UIColor) -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: c)
        m.roughness = .init(floatLiteral: 0.18)
        m.metallic = .init(floatLiteral: 0.35)
        return m
    }

    private func emissive(_ c: UIColor, strength: Float) -> RealityKit.Material {
        var m = PhysicallyBasedMaterial()
        m.baseColor = .init(tint: c)
        m.emissiveColor = .init(color: c)
        m.emissiveIntensity = strength
        return m
    }

    private func color(_ token: PaletteToken) -> UIColor {
        UIColor(red: token.red, green: token.green, blue: token.blue, alpha: 1)
    }
}

private extension UIColor {
    /// Darken toward black by `amount` (0...1) — used to push the cabinet
    /// carcass below the lit niche faces for the design's value-gap depth.
    func darkened(_ amount: CGFloat) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        getRed(&r, green: &g, blue: &b, alpha: &a)
        let k = 1 - amount
        return UIColor(red: r * k, green: g * k, blue: b * k, alpha: a)
    }
}

// MARK: - CoreMotion gyro parallax
@available(iOS 18.0, *)
extension CabinetScene {
    func startMotion() {
        guard !reduceMotion, motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 30.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, let attitude = data?.attitude else { return }
            // Clamp the parallax so it's a subtle lean, never a full orbit.
            let roll = Float(max(min(attitude.roll, 0.5), -0.5))
            let pitch = Float(max(min(attitude.pitch, 0.5), -0.5))
            self.motionAttitude = SIMD2(roll, pitch)
        }
    }

    func stopMotion() {
        if motion.isDeviceMotionActive { motion.stopDeviceMotionUpdates() }
    }
}
