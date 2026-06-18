import Foundation

/// The three LOCKED type voices, expressed as framework-independent specs.
/// The SwiftUI `Font` bridge lives in the app layer (`DesignSystem/Theme.swift`).
///
/// - Serif  → car names + large titles ONLY ("New York", CJK falls to "Songti SC").
/// - Mono   → catalog / telemetry IDs (SF Mono).
/// - Sans   → all native chrome, lists, controls, labels (SF Pro).
public enum TypeVoice: String, Equatable, Sendable {
    case serif
    case mono
    case sans
}

/// Font family fallback stacks. The app maps these to concrete SwiftUI fonts;
/// keeping them here documents the locked intent and lets non-UI code reason
/// about which voice a string belongs to.
public enum FontStack {
    /// New York → CJK serif fallback for Chinese headlines.
    public static let serif = ["New York", "Iowan Old Style", "Songti SC", "STSong", "Georgia"]
    /// SF Mono → catalog codes & telemetry, tabular numerals.
    public static let mono = ["SF Mono", "Menlo"]
    /// SF Pro → system default sans.
    public static let sans = ["SF Pro Text", "SF Pro Display"]
}

/// Semantic type sizes (points) used across the shell. Names map to roles, not
/// raw numbers, so the scale is tunable in one place.
public enum TypeScale {
    public static let displayTitle: Double = 34   // large serif nav title
    public static let sectionTitle: Double = 22   // serif section / car name
    public static let body: Double = 16
    public static let label: Double = 13
    public static let caption: Double = 11
    public static let mono: Double = 13           // catalog codes
}
