import Foundation

/// Steering-wheel side — one half of the catalog key `(mgtNumber, drive)`.
/// Rendered as the teal (L) / burnt-amber (R) decal in the cabinet.
public enum Drive: String, Codable, CaseIterable, Sendable, Identifiable {
    case lhd = "L"
    case rhd = "R"

    public var id: String { rawValue }

    /// Short single-letter decal label.
    public var decal: String { rawValue }

    /// Human-readable name for accessibility / detail rows.
    public var displayName: String {
        switch self {
        case .lhd: return "Left-hand drive"
        case .rhd: return "Right-hand drive"
        }
    }
}
