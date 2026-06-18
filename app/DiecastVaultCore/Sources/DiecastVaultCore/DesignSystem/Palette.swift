import Foundation

/// The LOCKED Diecast Vault palette, expressed as pure sRGB component values
/// (0...1) with zero UI-framework dependency. The SwiftUI `Color` bridge lives
/// in the app layer (`DesignSystem/Theme.swift`) so this package stays
/// platform-independent and `swift test`-able without a simulator.
///
/// Source of truth: docs/pipeline/DESIGN.html `:root` tokens.
public struct PaletteToken: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    /// Original hex string for reference / debugging only.
    public let hex: String

    public init(_ hex: String) {
        self.hex = hex
        let trimmed = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let value = UInt32(trimmed, radix: 16) ?? 0
        self.red = Double((value >> 16) & 0xFF) / 255.0
        self.green = Double((value >> 8) & 0xFF) / 255.0
        self.blue = Double(value & 0xFF) / 255.0
    }
}

/// Namespaced LOCKED palette. Names mirror the CSS custom properties so the
/// design doc and the app read 1:1.
public enum Palette {
    // App canvas / gallery wall.
    public static let paper = PaletteToken("#F7F4EC")
    // Lit niche face, sheets, rows.
    public static let cellSurface = PaletteToken("#FFFFFF")
    // Unlit / empty niche fill.
    public static let cellRecess = PaletteToken("#EAE4D6")

    // Ink scale.
    public static let ink = PaletteToken("#16181D")       // primary text
    public static let inkSoft = PaletteToken("#3F434D")    // secondary text
    public static let muted = PaletteToken("#7C828E")      // tertiary labels
    public static let line = PaletteToken("#E4DECF")       // hairlines / dividers

    // PRIMARY ACCENT — lit / present / action.
    public static let tungsten = PaletteToken("#F26B1F")
    public static let tungstenDeep = PaletteToken("#D8540F") // pressed/active
    public static let tungstenGlow = PaletteToken("#FFE6CE") // lit-niche halo

    // System / community / metadata identity.
    public static let steel = PaletteToken("#2B3A55")
    public static let steelSoft = PaletteToken("#EAF0F8")

    // Drive decals (the other half of the catalog key).
    public static let lhd = PaletteToken("#1F7A8C")  // teal-steel
    public static let rhd = PaletteToken("#9A4B17")  // burnt amber

    // Status.
    public static let ok = PaletteToken("#1F9D62")    // canonical / success
    public static let warn = PaletteToken("#B8860B")  // pending / caveat

    // The ONLY dark surface — the 3D viewer stage.
    public static let stage0 = PaletteToken("#101319")    // deepest backdrop
    public static let stage1 = PaletteToken("#1B2029")    // plinth / control material
    public static let stageRim = PaletteToken("#F26B1F")  // rim-light / horizon
}
