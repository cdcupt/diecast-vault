import Foundation

/// The scan/model presence for a release, expressed through light-as-state in
/// the UI (never a greyed-out control). Slice 2 surfaces the first two minimally;
/// the Pro-only scan path arrives with the capture pipeline.
///
/// - `hasModel`:   a viewable model is present (community canonical or owned) →
///                 the niche is LIT, "View in 3D" is offered.
/// - `noScanPro`:  no scan yet on a Pro device → tungsten "Guided scan" invite.
/// - `noScanBasic`: no scan yet on a non-Pro device → calm steel contribution
///                  note ("needs a Pro iPhone to seed it"), an invitation not a
///                  failure.
public enum ScanState: String, Codable, Sendable, CaseIterable {
    case hasModel
    case noScanPro
    case noScanBasic

    /// Whether a model exists to lift into the 3D viewer.
    public var hasViewableModel: Bool { self == .hasModel }

    /// The designed note shown on a matte (no-scan) detail. `nil` when a model
    /// is present (the lit poster speaks for itself).
    public var contributionNote: String? {
        switch self {
        case .hasModel: return nil
        case .noScanPro: return "Be the first to light this for the community."
        case .noScanBasic: return "No community scan yet — needs a Pro iPhone to seed it."
        }
    }
}
