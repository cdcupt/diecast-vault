import Foundation

/// The four shipped cabinet styles (DESIGN §4.2b — "one structure, four theme
/// swaps"). Every style is the SAME per-niche z-stack — frame → backboard →
/// light → car → shelf — over the one RealityKit scene; a style only swaps
/// material colours and light temperature/strength. The layer order, the markup,
/// and every semantic (light = state, drive decals, mono codes, serif names, the
/// data) are identical. Purely cosmetic, never a feature unlock.
///
/// Pure + `Sendable` so it lives in Core: the app layer turns each `CabinetTheme`
/// into RealityKit materials/lights, and tests can assert the theme table without
/// a simulator.
public enum CabinetStyle: String, CaseIterable, Identifiable, Sendable, Codable {
    /// Bright showroom vitrine — the recommended ship default (PM light-chrome
    /// preference: black frame + glossy white cells + lit rail).
    case lightbarWhite
    /// Warm collector's study — walnut case, brass, 2700K LED wash.
    case walnut
    /// A dark, contained case — like the 3D stage. The only dark cabinet,
    /// justified exactly like the 3D viewer (a physical object, not app chrome).
    case museum
    /// Lived-in workshop energy — brushed-steel tool cabinet, pegboard, work lamp.
    case garage

    public var id: String { rawValue }

    /// The shipped default on first launch (DESIGN §4.2b callout).
    public static let `default`: CabinetStyle = .lightbarWhite

    /// Serif display name (shown in the picker + the header chip a11y).
    public var displayName: String {
        switch self {
        case .lightbarWhite: return "Lightbar White"
        case .walnut: return "Walnut Case"
        case .museum: return "Museum Vitrine"
        case .garage: return "Garage / Pit"
        }
    }

    /// Localization key for the serif name (re-resolves against the live locale).
    public var nameKey: String { "cabinet.style.\(rawValue).name" }

    /// Localization key for the mono tagline under the name in the picker.
    public var taglineKey: String { "cabinet.style.\(rawValue).tagline" }

    /// Whether this style is a dark, contained case (Museum only). Used to keep
    /// the picker note "a dark, contained case — like the 3D stage" honest and to
    /// pick a legible matte-recess tone.
    public var isDarkCase: Bool { self == .museum }

    /// The concrete material/light theme the RealityKit scene renders.
    public var theme: CabinetTheme {
        switch self {
        case .lightbarWhite:
            return CabinetTheme(
                carcass: RGB(0.91, 0.89, 0.84),       // powder-coated bright aluminium
                backboard: RGB(1.0, 0.99, 0.96),      // glossy near-white infinity cove
                backboardRoughness: 0.35,
                litFace: RGB(1.0, 0.99, 0.96),
                matteRecess: RGB(0.918, 0.894, 0.839), // --cell-recess
                matteRoughness: 0.85,
                shelf: RGB(0.95, 0.94, 0.90),
                lightbar: LightSpec(color: Palette.tungsten.rgb, intensity: 6, washColor: Palette.tungstenGlow.rgb, washLumens: 900),
                nicheLight: LightSpec(color: Palette.tungstenGlow.rgb, intensity: 1, washColor: Palette.tungstenGlow.rgb, washLumens: 95),
                fill: LightSpec(color: RGB(1, 1, 1), intensity: 320, washColor: RGB(1, 1, 1), washLumens: 320),
                stageBackdrop: Palette.paper.rgb
            )
        case .walnut:
            return CabinetTheme(
                carcass: RGB(0.305, 0.20, 0.118),     // American black walnut
                backboard: RGB(0.965, 0.933, 0.866),  // warm-cream suede
                backboardRoughness: 0.92,
                litFace: RGB(0.965, 0.933, 0.866),
                matteRecess: RGB(0.894, 0.839, 0.737), // flat cream recess
                matteRoughness: 0.95,
                shelf: RGB(0.42, 0.30, 0.18),
                lightbar: LightSpec(color: RGB(1.0, 0.86, 0.62), intensity: 5, washColor: RGB(1.0, 0.91, 0.76), washLumens: 800),
                nicheLight: LightSpec(color: RGB(1.0, 0.85, 0.63), intensity: 1, washColor: RGB(1.0, 0.91, 0.76), washLumens: 120), // 2700K LED
                fill: LightSpec(color: RGB(1.0, 0.95, 0.88), intensity: 240, washColor: RGB(1, 1, 1), washLumens: 240),
                stageBackdrop: RGB(0.21, 0.14, 0.085)
            )
        case .museum:
            return CabinetTheme(
                carcass: RGB(0.105, 0.108, 0.118),    // matte-black anodized case
                backboard: RGB(0.125, 0.133, 0.145),  // dark-graphite
                backboardRoughness: 0.7,
                litFace: RGB(0.149, 0.157, 0.173),    // graphite that the cool spot grazes
                matteRecess: RGB(0.082, 0.086, 0.094), // near-black recess (downlight off)
                matteRoughness: 0.8,
                shelf: RGB(0.16, 0.17, 0.18),
                // Museum top-rail toned down (MUSEUM TOP-RAIL fix): the saturated
                // tungsten-orange strip at full intensity out-competed the lit
                // niches against the dark case. Desaturate toward a soft museum
                // warm-white and drop the emissive + wash a notch so the rail reads
                // as a fixture, not the brightest thing on the shelf.
                lightbar: LightSpec(color: RGB(0.96, 0.86, 0.72), intensity: 3, washColor: Palette.tungstenGlow.rgb, washLumens: 360),
                nicheLight: LightSpec(color: RGB(0.85, 0.90, 0.97), intensity: 1, washColor: RGB(0.85, 0.90, 0.97), washLumens: 220), // ~4000K cool spot
                fill: LightSpec(color: RGB(0.62, 0.69, 0.78), intensity: 180, washColor: RGB(1, 1, 1), washLumens: 180),
                stageBackdrop: Palette.stage0.rgb     // the only dark cabinet — like the 3D stage
            )
        case .garage:
            return CabinetTheme(
                carcass: RGB(0.60, 0.627, 0.659),     // brushed stainless tool cabinet
                backboard: RGB(0.937, 0.902, 0.824),  // zinc-cream pegboard
                backboardRoughness: 0.88,
                litFace: RGB(0.937, 0.902, 0.824),
                matteRecess: RGB(0.851, 0.800, 0.690),
                matteRoughness: 0.9,
                shelf: RGB(0.11, 0.118, 0.133),       // ribbed black-rubber mat
                lightbar: LightSpec(color: Palette.tungsten.rgb, intensity: 6, washColor: Palette.tungstenGlow.rgb, washLumens: 1000),
                nicheLight: LightSpec(color: Palette.tungstenGlow.rgb, intensity: 1, washColor: Palette.tungstenGlow.rgb, washLumens: 130), // clamp-on work lamp
                fill: LightSpec(color: RGB(1, 1, 1), intensity: 300, washColor: RGB(1, 1, 1), washLumens: 300),
                stageBackdrop: RGB(0.42, 0.44, 0.47)
            )
        }
    }
}

/// A plain RGB triple (0...1) so Core can carry colours without importing UIKit /
/// SwiftUI. The app layer maps this onto `UIColor`.
public struct RGB: Hashable, Sendable, Codable {
    public let r: Double
    public let g: Double
    public let b: Double
    public init(_ r: Double, _ g: Double, _ b: Double) {
        self.r = r; self.g = g; self.b = b
    }
}

/// A light specification: an emissive/material colour + strength, plus the real
/// light it drives (a wash colour + lumen/lux value).
public struct LightSpec: Hashable, Sendable, Codable {
    public let color: RGB
    public let intensity: Double
    public let washColor: RGB
    public let washLumens: Double
    public init(color: RGB, intensity: Double, washColor: RGB, washLumens: Double) {
        self.color = color
        self.intensity = intensity
        self.washColor = washColor
        self.washLumens = washLumens
    }
}

/// The concrete material + lighting theme for one cabinet style. The RealityKit
/// scene reads only this — swapping themes re-skins the identical scene graph.
public struct CabinetTheme: Hashable, Sendable, Codable {
    public let carcass: RGB
    public let backboard: RGB
    public let backboardRoughness: Double
    public let litFace: RGB
    public let matteRecess: RGB
    public let matteRoughness: Double
    public let shelf: RGB
    public let lightbar: LightSpec
    public let nicheLight: LightSpec
    public let fill: LightSpec
    /// The backdrop behind the whole case (the SwiftUI background under the scene).
    public let stageBackdrop: RGB
}

private extension PaletteToken {
    var rgb: RGB { RGB(red, green, blue) }
}
