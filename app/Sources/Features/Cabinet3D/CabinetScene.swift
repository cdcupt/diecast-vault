import SwiftUI
import RealityKit
import CoreMotion
import simd
import DiecastVaultCore

/// Builds and drives the RealityKit cabinet scene graph — the real-time Home.
/// Kept separate from the SwiftUI view so the geometry/lighting/camera/LOD logic
/// is testable-by-reading and the view stays declarative.
///
/// One structure, four dressings (DESIGN §4.2b): the scene reads a `CabinetTheme`
/// and skins the identical scene graph — carcass, backboard, per-niche light, the
/// lightbar wash — so switching styles is a material swap, never a rewrite.
///
/// LOD (DESIGN §4.2 "≤ 1 full USDZ resident"): the focused/nearest lit niche
/// renders the bundled full USDZ; every other niche uses a lightweight procedural
/// impostor so a full shelf stays performant. Niches carry their `Release` on a
/// `CollisionComponent` so the view can hit-test a tap and route it.
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

    /// Maps a hit-tested niche entity's name back to its release id so the view
    /// can route the tap. Niches are named `"niche:<release.id>"`.
    private var nicheReleaseByName: [String: Release] = [:]

    // CoreMotion gyro parallax (subtle camera lean toward device tilt).
    private let motion = CMMotionManager()
    private var motionAttitude: simd_float2 = .zero  // (roll, pitch) offsets
    private var reduceMotion = false

    // MARK: Build

    func build(in content: RealityViewCameraContent, shelf: [Release], style: CabinetStyle, modelURL: URL?, reduceMotion: Bool) {
        self.reduceMotion = reduceMotion
        let theme = style.theme

        let root = Entity()
        content.add(root)

        let rows = max(Int(ceil(Double(shelf.count) / Double(columns))), 1)
        let cell = nicheSize + gap
        let boardWidth = Float(columns) * cell - gap
        let boardHeight = Float(rows) * cell - gap

        // The cabinet carcass + mullions, themed (carcass colour) so the niches
        // read as wells carved into the active style's case.
        root.addChild(makeCarcass(width: boardWidth, height: boardHeight, rows: rows, cell: cell, theme: theme))

        // A glowing lightbar strip across the top (the signature fixture).
        root.addChild(makeLightbar(width: boardWidth, topY: boardHeight / 2, theme: theme))

        // LOD: only the focused/nearest LIT niche gets the full USDZ; the rest are
        // procedural impostors. The hero is the first lit niche in shelf order.
        let heroIndex = shelf.firstIndex(where: \.isLit)

        // Lay out niches centered on origin.
        for (index, release) in shelf.enumerated() {
            let col = index % columns
            let row = index / columns
            let x = -boardWidth / 2 + nicheSize / 2 + Float(col) * cell
            let y = boardHeight / 2 - nicheSize / 2 - Float(row) * cell
            let isHero = index == heroIndex
            let niche = makeNiche(
                release: release,
                isHero: isHero,
                theme: theme,
                modelURL: isHero ? modelURL : nil,
                at: SIMD3(x, y, 0)
            )
            root.addChild(niche)
        }

        // Ambient/key fill so MATTE recesses stay legible, themed per style.
        root.addChild(makeFillLight(theme: theme))

        // Camera rig: a pivot at origin with the camera pushed back along +Z.
        let rig = Entity()
        let camEntity = Entity()
        var cam = PerspectiveCameraComponent()
        cam.fieldOfViewInDegrees = 46
        camEntity.components.set(cam)
        // Distance scales with board size so the WHOLE vitrine (all rows) frames
        // with breathing room above + below for the header / tab bar overlays.
        // Keyed off height (the taller axis once rows stack) so deep shelves fit.
        let distance = max(boardWidth * 1.4, boardHeight) * 1.55 + 0.5
        camEntity.position = SIMD3(0, 0, distance)
        rig.addChild(camEntity)
        content.add(rig)
        self.cameraRig = rig

        // A gentle, near head-on framing (small up-tilt) so rows don't foreshorten
        // and the lit top row reads fully.
        orient(yaw: 0, pitch: 0.07)
        startMotion()
    }

    /// Resolve a hit-tested entity (or one of its ancestors) back to its release.
    func release(forHitName name: String) -> Release? { nicheReleaseByName[name] }

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

    private func makeCarcass(width: Float, height: Float, rows: Int, cell: Float, theme: CabinetTheme) -> Entity {
        let entity = Entity()
        let carcassMat = matte(color(theme.carcass), roughness: 0.55)

        // A back panel closing off the case behind the niches (so you never see
        // through to the dark backdrop between cells).
        let back = ModelEntity(
            mesh: .generateBox(width: width + 0.10, height: height + 0.10, depth: wallThickness),
            materials: [carcassMat]
        )
        back.position = SIMD3(0, 0, -nicheDepth - wallThickness / 2)
        entity.addChild(back)

        // Mullion strips: vertical + horizontal bars that project FORWARD to the
        // niche openings (z=0), framing each niche as a recessed well. The strips
        // sit between cells; the niche openings stay clear so cars are visible.
        let strip = gap + 0.012                       // mullion thickness
        let halfW = width / 2, halfH = height / 2
        let mullDepth = nicheDepth

        // Vertical mullions at each column boundary (including the two outer edges).
        // Boundary b sits at the gap centre between niche columns (b-1) and b.
        for b in 0...columns {
            let xPos = -halfW - gap / 2 + Float(b) * cell
            let bar = ModelEntity(
                mesh: .generateBox(width: strip, height: height + strip, depth: mullDepth),
                materials: [carcassMat]
            )
            bar.position = SIMD3(xPos, 0, -mullDepth / 2)
            entity.addChild(bar)
        }
        // Horizontal mullions at each row boundary (including top + bottom edges).
        for b in 0...rows {
            let yPos = halfH + gap / 2 - Float(b) * cell
            let bar = ModelEntity(
                mesh: .generateBox(width: width + strip, height: strip, depth: mullDepth),
                materials: [carcassMat]
            )
            bar.position = SIMD3(0, yPos, -mullDepth / 2)
            entity.addChild(bar)
        }
        return entity
    }

    private func makeNiche(release: Release, isHero: Bool, theme: CabinetTheme, modelURL: URL?, at position: SIMD3<Float>) -> Entity {
        let niche = Entity()
        niche.position = position
        niche.name = "niche:\(release.id)"
        nicheReleaseByName[niche.name] = release

        // The recess backboard: a thin panel at the BACK of the niche so the car
        // floats in FRONT of it (visible from the camera), not sealed inside a box.
        // Lit faces use the bright board material; matte recesses use the unlit
        // fill — that material swap PLUS the per-niche light is the lit/matte state.
        let litFace = release.isLit
        let boardColor: UIColor = litFace ? color(theme.litFace) : color(theme.matteRecess)
        let board = ModelEntity(
            mesh: .generateBox(width: nicheSize, height: nicheSize, depth: 0.012),
            materials: [matte(boardColor, roughness: litFace ? Float(theme.backboardRoughness) : Float(theme.matteRoughness))]
        )
        board.position = SIMD3(0, 0, -nicheDepth + 0.012)
        niche.addChild(board)

        // The car (and shelf/light) only exist for LIT niches — a MATTE recess is
        // an empty, unlit well (light-as-state: the empty state IS the light off).
        if litFace {
            // A thin shelf the car rests on, in the style's shelf material.
            let shelf = ModelEntity(
                mesh: .generateBox(width: nicheSize * 0.9, height: 0.01, depth: nicheDepth * 0.6),
                materials: [matte(color(theme.shelf), roughness: 0.7)]
            )
            shelf.position = SIMD3(0, -nicheSize / 2 + 0.03, -nicheDepth * 0.5)
            niche.addChild(shelf)

            // The car: hero loads the full USDZ (LOD high); impostors are procedural.
            // Sits forward, near the niche opening, so it reads from the camera.
            let car = makeCar(release: release, isHero: isHero, modelURL: modelURL)
            car.position = SIMD3(0, -nicheSize / 2 + 0.05, -nicheDepth * 0.42)
            niche.addChild(car)

            // Light = state: a LIT niche gets its own light pooling glow in the
            // style's niche-light temperature (warm tungsten / 2700K LED / cool
            // 4000K spot). Intensity is high so the pool reads clearly even with
            // the simulator's flat host-GPU shading.
            let light = Entity()
            var point = PointLightComponent(
                color: color(theme.nicheLight.washColor),
                intensity: Float(theme.nicheLight.washLumens) * 26 * (isHero ? 1.1 : 1.0),
                attenuationRadius: nicheSize * 1.6
            )
            point.attenuationRadius = nicheSize * 1.6
            light.components.set(point)
            // Pull the light forward and above so it rakes the car + pools on the
            // board behind it (the floor glow).
            light.position = SIMD3(0, nicheSize / 2 - 0.04, -nicheDepth * 0.2)
            niche.addChild(light)
        }

        // Make the whole niche tappable: a collision box over the opening so a
        // SpatialTapGesture in the view can hit-test and route to detail / catalog.
        let collider = ModelEntity()
        collider.name = niche.name
        collider.components.set(CollisionComponent(
            shapes: [.generateBox(width: nicheSize, height: nicheSize, depth: nicheDepth)]
        ))
        collider.components.set(InputTargetComponent())
        collider.position = SIMD3(0, 0, -nicheDepth / 2)
        niche.addChild(collider)

        return niche
    }

    /// The car content. Hero attempts the bundled full USDZ (normalized into the
    /// niche); on failure (or for impostors) it falls back to a procedural body —
    /// richer for the hero (LOD high), a cheap single block for impostors.
    private func makeCar(release: Release, isHero: Bool, modelURL: URL?) -> Entity {
        if isHero, let modelURL, let usdz = try? Entity.load(contentsOf: modelURL) {
            return normalizedUSDZ(usdz)
        }
        return proceduralCar(release: release, isHero: isHero)
    }

    /// Scale + recenter a loaded USDZ to sit on the niche floor at a niche-fitting
    /// size, regardless of the source units.
    private func normalizedUSDZ(_ model: Entity) -> Entity {
        let holder = Entity()
        let raw = model.visualBounds(relativeTo: nil)
        let rawMax = max(raw.extents.x, max(raw.extents.y, raw.extents.z))
        let target: Float = nicheSize * 0.72
        if rawMax > 0 { model.scale = SIMD3(repeating: target / rawMax) }
        let bounds = model.visualBounds(relativeTo: nil)
        // Rest on the floor (y at -extent/2 → 0) and centre x/z.
        model.position = SIMD3(-bounds.center.x, -bounds.center.y + bounds.extents.y / 2, -bounds.center.z)
        holder.addChild(model)
        return holder
    }

    /// Procedural low-poly car. The hero stand-in gets a richer body + cabin +
    /// four wheels; impostors get a cheaper single-block shell (the LOD billboard
    /// stand-in for non-focused niches).
    private func proceduralCar(release: Release, isHero: Bool) -> Entity {
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

    private func makeLightbar(width: Float, topY: Float, theme: CabinetTheme) -> Entity {
        let bar = ModelEntity(
            mesh: .generateBox(width: width + 0.06, height: 0.02, depth: 0.03),
            materials: [emissive(color(theme.lightbar.color), strength: Float(theme.lightbar.intensity))]
        )
        bar.position = SIMD3(0, topY + 0.05, 0.02)
        let holder = Entity()
        holder.addChild(bar)
        // A real light so the bar actually casts the warm wash downward.
        let wash = Entity()
        var spot = SpotLightComponent(
            color: color(theme.lightbar.washColor),
            intensity: Float(theme.lightbar.washLumens),
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

    private func makeFillLight(theme: CabinetTheme) -> Entity {
        // A low key from front-above so MATTE recesses stay legible without
        // flattening the style's per-niche light pools.
        let light = Entity()
        let dir = DirectionalLightComponent(color: color(theme.fill.color), intensity: Float(theme.fill.intensity))
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

    private func color(_ rgb: RGB) -> UIColor {
        UIColor(red: rgb.r, green: rgb.g, blue: rgb.b, alpha: 1)
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
