import Foundation

/// A copy of a release the user owns — the DEVICE-ONLY collection entity
/// (TECH.html §2 scope boundary: `OwnedCopy` never reaches the server). This is
/// the pure value type; the SwiftData persistence model that mirrors it lives in
/// the app layer so this package stays UI- and storage-free.
///
/// Bonded to the catalog by the same `(mgtNumber, drive)` key as everything else
/// — the per-copy `editionNo` (e.g. "1510/2022") is a copy-level attribute, not
/// part of identity.
public struct OwnedCopy: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    public let key: CatalogKey
    /// Per-copy edition serial, e.g. "1510/2022". Optional — not all copies carry one.
    public let editionNo: String?
    /// Free-form personal note.
    public let notes: String?
    /// When the copy was added to the shelf.
    public let acquiredAt: Date
    /// Whether a viewable 3D model is bonded to this copy (drives the LIT look).
    public let hasModel: Bool

    public init(
        id: UUID = UUID(),
        key: CatalogKey,
        editionNo: String? = nil,
        notes: String? = nil,
        acquiredAt: Date = Date(),
        hasModel: Bool = false
    ) {
        self.id = id
        self.key = key
        self.editionNo = editionNo
        self.notes = notes
        self.acquiredAt = acquiredAt
        self.hasModel = hasModel
    }

    public var mgtNumber: String { key.mgtNumber }
    public var drive: Drive { key.drive }
}

public extension OwnedCopy {
    /// First-run seed for the local collection (slice 2). Mirrors the lit entries
    /// in `Release.sampleShelf` so the cabinet shows an owned, partly-bonded shelf
    /// immediately, local-first, with no network. Clearly a sample set.
    static let sampleSeed: [OwnedCopy] = Release.sampleShelf
        .filter(\.isLit)
        .map { release in
            OwnedCopy(
                key: release.key,
                editionNo: release.edition,
                notes: nil,
                hasModel: true
            )
        }
}
