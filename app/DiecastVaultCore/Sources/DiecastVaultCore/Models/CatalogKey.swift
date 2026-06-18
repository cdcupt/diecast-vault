import Foundation

/// The canonical identity of a release in Diecast Vault: the Mini GT catalog
/// number paired with its drive side. The client never holds an opaque server
/// `modelId`; community resources are addressed by this key (TECH.html R5).
public struct CatalogKey: Hashable, Codable, Sendable {
    /// Mini GT catalog number, normalized (e.g. "MGT00748").
    public let mgtNumber: String
    public let drive: Drive

    public init(mgtNumber: String, drive: Drive) {
        self.mgtNumber = CatalogKey.normalize(mgtNumber)
        self.drive = drive
    }

    /// Normalize a raw catalog string: trim, uppercase, strip internal spaces.
    /// Keeps the key stable regardless of how a number was typed or scanned.
    public static func normalize(_ raw: String) -> String {
        raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .uppercased()
            .replacingOccurrences(of: " ", with: "")
    }

    /// Stable wire / display form, e.g. "MGT00748·L".
    public var stableID: String { "\(mgtNumber)·\(drive.rawValue)" }
}
