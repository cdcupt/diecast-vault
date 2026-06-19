import SwiftUI
import DiecastVaultCore

/// SwiftUI bridge over the pure `DiecastVaultCore` design tokens. This is the
/// only place that turns the framework-independent `Palette` / `Typography`
/// specs into concrete `Color` and `Font` values, keeping Core UI-free.
extension Color {
    init(_ token: PaletteToken) {
        self.init(.sRGB, red: token.red, green: token.green, blue: token.blue, opacity: 1)
    }

    /// Bridge a Core `RGB` triple (used by `CabinetTheme`) to a SwiftUI `Color`.
    init(_ rgb: RGB) {
        self.init(.sRGB, red: rgb.r, green: rgb.g, blue: rgb.b, opacity: 1)
    }
}

/// Locked semantic colors, named to match the design doc.
enum Ink {
    static let paper = Color(Palette.paper)
    static let cellSurface = Color(Palette.cellSurface)
    static let cellRecess = Color(Palette.cellRecess)

    static let primary = Color(Palette.ink)
    static let soft = Color(Palette.inkSoft)
    static let muted = Color(Palette.muted)
    static let line = Color(Palette.line)

    static let tungsten = Color(Palette.tungsten)
    static let tungstenDeep = Color(Palette.tungstenDeep)
    static let tungstenGlow = Color(Palette.tungstenGlow)

    static let steel = Color(Palette.steel)
    static let steelSoft = Color(Palette.steelSoft)

    static let lhd = Color(Palette.lhd)
    static let rhd = Color(Palette.rhd)

    static let ok = Color(Palette.ok)
    static let warn = Color(Palette.warn)

    // The single dark surface (3D viewer only).
    static let stage0 = Color(Palette.stage0)
    static let stage1 = Color(Palette.stage1)
    static let stageRim = Color(Palette.stageRim)
}

/// Locked type voices.
/// - Serif: New York for car names + large titles (CJK falls to Songti SC).
/// - Mono: SF Mono for catalog codes / telemetry (tabular numerals).
/// - Sans: SF Pro for all chrome (the SwiftUI default).
enum Voice {
    /// Editorial serif headline. Uses New York; the system substitutes a CJK
    /// serif (Songti SC) for Chinese glyphs automatically.
    static func serif(_ size: CGFloat, weight: Font.Weight = .bold) -> Font {
        .system(size: size, weight: weight, design: .serif)
    }

    /// Monospaced catalog codes / telemetry IDs.
    static func mono(_ size: CGFloat = CGFloat(TypeScale.mono), weight: Font.Weight = .regular) -> Font {
        .system(size: size, weight: weight, design: .monospaced)
    }
}
