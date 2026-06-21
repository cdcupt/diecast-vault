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
    /// The content root that holds the WHOLE vitrine (carcass, niches, lights).
    /// Orientation is applied HERE (a turntable) rather than to the camera rig:
    /// on iOS RealityView, imperative camera-rig transforms made outside the render
    /// path are not reliably reflected on screen. We rotate the content root — but
    /// see `orient(...)` / the SceneEvents.Update subscription for WHY the rotation
    /// must be applied from inside RealityKit's own render loop, not imperatively.
    private var contentRoot: Entity?

    /// The turntable target the on-screen pose eases toward. Set by the view's
    /// buttons/drag (`orient(...)`); CONSUMED every frame by the render-loop
    /// subscription below — never applied imperatively from the caller (that path
    /// mutates the entity but does not re-composite on iOS; the real DEFECT).
    private var targetYaw: Float = 0
    private var targetPitch: Float = 0.07

    /// Strong handle to the per-frame `SceneEvents.Update` subscription. RealityKit
    /// fires this once per frame ON ITS OWN RENDER LOOP; applying the orientation
    /// there means the transform change is guaranteed to be composited (an
    /// imperative `.orientation =` / `move(to:)` from a button action is NOT — the
    /// update: closure never fires on a `@State` change on this iOS host, and a
    /// raw out-of-loop mutation never refreshes the frame). This is THE fix.
    private var renderLoopSubscription: EventSubscription?

    /// Maps a hit-tested niche entity's name back to its release id so the view
    /// can route the tap. Niches are named `"niche:<release.id>"`.
    private var nicheReleaseByName: [String: Release] = [:]

    // CoreMotion gyro parallax (subtle camera lean toward device tilt).
    private let motion = CMMotionManager()
    private var motionAttitude: simd_float2 = .zero  // (roll, pitch) offsets
    private var reduceMotion = false

    // MARK: Build

    func build(in content: RealityViewCameraContent, shelf: [Release], style: CabinetStyle, modelURL: URL?, reduceMotion: Bool, yaw: Float = 0, pitch: Float = 0.07) {
        self.reduceMotion = reduceMotion
        let theme = style.theme

        // Idempotent: a rebuild (RealityView `.id()` change — the on-this-host
        // re-composite trigger, see the view) re-runs this `make` closure on the
        // same scene instance. Clear any prior content + subscription so we never
        // stack two vitrines or leak the render-loop hook.
        renderLoopSubscription?.cancel()
        renderLoopSubscription = nil
        content.entities.removeAll()
        nicheReleaseByName.removeAll()

        let root = Entity()
        content.add(root)
        self.contentRoot = root

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

        // Seed the turntable from the pose handed in by the view. The build-time
        // `.orientation =` is the ONLY assignment that reliably composites on this
        // iOS host (the render loop does not tick between rebuilds, so SceneEvents
        // .Update never fires and out-of-loop mutations never refresh the frame —
        // the real DEFECT). The view therefore re-runs this `make` (via `.id()`)
        // whenever the pose changes, so each new pose is baked into a fresh render.
        targetYaw = yaw
        targetPitch = pitch
        root.orientation = quaternion(yaw: targetYaw, pitch: targetPitch)

        // THE FIX: drive the turntable from RealityKit's own per-frame render loop.
        // `SceneEvents.Update` fires once per frame on the render thread, so any
        // transform we set inside it is guaranteed to be composited — unlike an
        // imperative `.orientation =` made from a SwiftUI button action / the
        // `update:` closure (which never fires on a `@State` change on this host).
        // Each frame we ease the live orientation toward `targetYaw/Pitch` (+ gyro),
        // so a button tap or drag that moves the target produces a smooth, VISIBLE
        // on-screen rotation.
        renderLoopSubscription = content.subscribe(to: SceneEvents.Update.self) { [weak self] event in
            self?.stepTurntable(deltaTime: Float(event.deltaTime))
        }
        startMotion()
    }

    /// Resolve a hit-tested entity (or one of its ancestors) back to its release.
    func release(forHitName name: String) -> Release? { nicheReleaseByName[name] }

    // MARK: Orientation (clamped orbit + gyro parallax)

    /// Set the turntable TARGET. This does NOT touch the entity directly — the
    /// per-frame `SceneEvents.Update` subscription (set up in `build`) reads this
    /// target and rotates the content root from inside RealityKit's render loop,
    /// which is the only path that actually re-composites the frame on this iOS host
    /// (an imperative `.orientation =` / `move(to:)` from a button action mutates the
    /// entity but never refreshes the display — the real DEFECT this fixes).
    ///
    /// A turntable spins the model the opposite visual way a camera orbit would, so
    /// the angles are negated (in `quaternion`) to keep "yaw +" turning the case the
    /// direction a user expects. Yaw spins about Y; pitch tips about X.
    func orient(yaw: Float, pitch: Float) {
        targetYaw = yaw
        targetPitch = pitch
    }

    /// Per-frame turntable step, invoked by `SceneEvents.Update` on RealityKit's
    /// render thread. Eases the live orientation toward the target (+ gyro lean) and
    /// writes it onto the content root. On a real device this runs inside the render
    /// loop so the write is composited every frame and the cabinet rotates smoothly;
    /// on the Simulator the loop is static (this never fires), so the view's
    /// `.id(poseToken)` rebuild is what re-composites the runtime rotation there.
    private func stepTurntable(deltaTime: Float) {
        guard let root = contentRoot else { return }
        let gyroYaw = reduceMotion ? 0 : motionAttitude.x * 0.25
        let gyroPitch = reduceMotion ? 0 : motionAttitude.y * 0.25
        let desired = quaternion(yaw: targetYaw + gyroYaw, pitch: targetPitch + gyroPitch)
        // Critically-damped-ish smoothing toward the target so a button nudge or a
        // drag glides instead of snapping; framerate-independent via deltaTime.
        let t = min(1, deltaTime * turntableResponse)
        root.orientation = simd_slerp(root.orientation, desired, t)
    }

    /// The turntable quaternion for a yaw/pitch pair (angles negated so a turntable
    /// reads like a camera orbit; yaw about Y, pitch about X).
    private func quaternion(yaw: Float, pitch: Float) -> simd_quatf {
        simd_quatf(angle: -yaw, axis: SIMD3(0, 1, 0))
            * simd_quatf(angle: -pitch, axis: SIMD3(1, 0, 0))
    }

    /// How fast the live pose chases the target (higher = snappier). Tuned so a
    /// single button nudge resolves in a few frames yet a drag stays smooth.
    private let turntableResponse: Float = 12

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
            // Turn each car to a 3/4 stance — the camera is near head-on, so a
            // straight side-on body foreshortens into a lozenge; a ~24° yaw shows
            // the hood + flank and reads unmistakably as a car. Alternate the turn
            // by drive so the shelf doesn't look rubber-stamped.
            let turn: Float = release.drive == .lhd ? 0.42 : -0.42
            car.orientation = simd_quatf(angle: turn, axis: SIMD3(0, 1, 0))
            niche.addChild(car)

            // Light = state: a LIT niche gets its own light pooling glow in the
            // style's niche-light temperature (warm tungsten / 2700K LED / cool
            // 4000K spot). Intensity reads the pool clearly even with the
            // simulator's flat host-GPU shading, but the HERO niche is toned DOWN,
            // not up: it renders the full reflective USDZ (real metallic paint),
            // which blows out near-white under the same close point-light that the
            // matte procedural impostors absorb fine. The impostors keep the bright
            // pool; the hero gets a softer wash + a wider falloff so the model reads
            // as a lit car, not a white silhouette (HERO-NICHE WASH-OUT fix).
            let light = Entity()
            // Pull the hero light back so it rakes the model rather than baking the
            // face that's nearest the lamp, and widen its radius so the falloff is
            // gradual instead of a hot near-field spike.
            let heroDim: Float = isHero ? 0.55 : 1.0
            let radius = nicheSize * (isHero ? 2.0 : 1.6)
            var point = PointLightComponent(
                color: color(theme.nicheLight.washColor),
                intensity: Float(theme.nicheLight.washLumens) * 26 * heroDim,
                attenuationRadius: radius
            )
            point.attenuationRadius = radius
            light.components.set(point)
            // Pull the light forward and above so it rakes the car + pools on the
            // board behind it (the floor glow). The hero lamp sits a touch further
            // back so the full USDZ isn't lit point-blank.
            light.position = SIMD3(0, nicheSize / 2 - 0.04, -nicheDepth * (isHero ? 0.34 : 0.2))
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
    ///
    /// Measured in the model's OWN local space (`relativeTo: model`) so the bounds
    /// are scale-invariant: querying `relativeTo: nil` before AND after setting
    /// `.scale` double-applies the loaded entity's own transform, which previously
    /// blew the model up to ~18 m on stage — it scaled off-screen, leaving an empty
    /// white niche (the real HERO-NICHE WASH-OUT cause: there was no visible car).
    private func normalizedUSDZ(_ model: Entity) -> Entity {
        let holder = Entity()
        // Local-space bounds: independent of the entity's own scale, so the ratio
        // and the recenter are computed once and applied once.
        let local = model.visualBounds(relativeTo: model)
        let rawMax = max(local.extents.x, max(local.extents.y, local.extents.z))
        let target: Float = nicheSize * 0.72
        let factor: Float = rawMax > 0 ? target / rawMax : 1
        model.scale = SIMD3(repeating: factor)
        // Recenter using the local center scaled by the same factor: rest on the
        // floor (bottom at y=0) and centre x/z within the niche.
        let scaledCenter = local.center * factor
        let scaledHalfHeight = (local.extents.y * factor) / 2
        model.position = SIMD3(-scaledCenter.x, -scaledCenter.y + scaledHalfHeight, -scaledCenter.z)
        // Soften the loaded materials so the close per-niche lamp can't blow the
        // hero's real (often glossy/metallic) paint out to a white silhouette —
        // floor the roughness and cap the metallic so highlights stay matte enough
        // to read the body, not a hot specular wash (HERO-NICHE WASH-OUT fix).
        softenForNiche(model)
        holder.addChild(model)
        return holder
    }

    /// Walk a loaded model's hierarchy and tame any material that would
    /// specular-blow under the tight per-niche light. The bundled USDZ ships
    /// glossy, part-metallic paint plus a near-white 60%-metallic trim that, under
    /// the close top wash, blooms to a white silhouette. Force the hero's surfaces
    /// fully matte + non-metallic (kills the specular bloom) and pull bright
    /// diffuse tints down toward a readable mid-tone so the body reads as a lit
    /// car, not a white card (HERO-NICHE WASH-OUT fix).
    private func softenForNiche(_ entity: Entity) {
        if var model = entity.components[ModelComponent.self] {
            model.materials = model.materials.map { material in
                guard var pbr = material as? PhysicallyBasedMaterial else { return material }
                // Floor roughness and cap metallic so the close lamp grazes the
                // body instead of throwing a hot specular highlight; the model
                // keeps its diffuse paint (the orange body, dark cabin) so it still
                // reads as a finished car, just not a glossy bloom.
                pbr.roughness = .init(floatLiteral: max(pbr.roughness.scale, 0.7))
                pbr.metallic = .init(floatLiteral: min(pbr.metallic.scale, 0.1))
                pbr.clearcoat = .init(floatLiteral: 0)
                // Knock back only NEAR-WHITE constant tints (e.g. the model's
                // 60%-metallic white trim) so a bright diffuse can't read as a
                // blown highlight; the body/cabin colours are left intact.
                if pbr.baseColor.texture == nil {
                    pbr.baseColor = .init(tint: dimmedTint(pbr.baseColor.tint))
                }
                return pbr
            }
            entity.components.set(model)
        }
        for child in entity.children { softenForNiche(child) }
    }

    /// Scale a base-colour tint down once it climbs into the near-white range, so
    /// the hero's bright trims sit a readable notch below the lit board behind them.
    private func dimmedTint(_ c: UIColor) -> UIColor {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        guard c.getRed(&r, green: &g, blue: &b, alpha: &a) else { return c }
        let luma = 0.2126 * r + 0.7152 * g + 0.0722 * b
        guard luma > 0.7 else { return c }             // only the brightest tints
        let k: CGFloat = 0.78                           // pull them ~22% darker
        return UIColor(red: r * k, green: g * k, blue: b * k, alpha: a)
    }

    /// Procedural low-poly car. The hero stand-in gets a richer body + cabin +
    /// four wheels; impostors get a cheaper single-block shell (the LOD billboard
    /// stand-in for non-focused niches).
    private func proceduralCar(release: Release, isHero: Bool) -> Entity {
        let car = Entity()
        let bodyColor = release.drive == .lhd ? color(Palette.lhd) : color(Palette.rhd)
        let bodyMat = isHero ? glossy(bodyColor) : matte(bodyColor, roughness: 0.5)

        // Lower, wider body with a tight corner radius — a flatter sportscar profile
        // that reads as a CAR, not a rounded lozenge. The cabin bump (below) is what
        // sells the silhouette, so every lit niche gets one (cheap: one box + a slab).
        let w: Float = 0.17, h: Float = 0.034, d: Float = 0.072
        let body = ModelEntity(mesh: .generateBox(size: SIMD3(w, h, d), cornerRadius: 0.005), materials: [bodyMat])
        body.position = SIMD3(0, h / 2 + 0.02, 0)
        car.addChild(body)

        // A greenhouse/cabin bump set back from centre — the single cue that turns a
        // slab into a car at niche scale. Impostors get a body-matched matte cabin
        // (no extra material churn); the hero gets a glassy stage-blue cabin + wheels.
        let cabinW = w * 0.46, cabinH = h * 1.05, cabinD = d * 0.74
        let cabinMat = isHero ? glossy(color(Palette.stage1)) : matte(bodyColor, roughness: 0.45)
        let cabin = ModelEntity(
            mesh: .generateBox(size: SIMD3(cabinW, cabinH, cabinD), cornerRadius: 0.004),
            materials: [cabinMat]
        )
        // Sit the cabin ON the body and slightly rearward, so the long hood reads.
        cabin.position = SIMD3(-w * 0.07, h + cabinH / 2 - 0.004, 0)
        car.addChild(cabin)

        if isHero {
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
        } else {
            // Impostor wheels: two cheap dark slabs along the flanks (a hint of
            // wheels without four cylinders) — keeps the impostor light but car-like.
            let arch = ModelEntity(
                mesh: .generateBox(size: SIMD3(w * 0.84, 0.012, d * 1.02), cornerRadius: 0.004),
                materials: [matte(color(Palette.ink), roughness: 0.7)]
            )
            arch.position = SIMD3(0, 0.012, 0)
            car.addChild(arch)
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
        renderLoopSubscription?.cancel()
        renderLoopSubscription = nil
    }
}
