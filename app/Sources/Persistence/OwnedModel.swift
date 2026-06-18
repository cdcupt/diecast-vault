import Foundation
import SwiftData
import DiecastVaultCore

/// The SwiftData persistence mirror of the pure `OwnedCopy` value type. Local-first
/// and device-only (TECH.html §2 scope boundary — never sent to the server).
/// iCloud sync is intentionally OFF in slice 2; the store is a plain local
/// `ModelContainer` so the shelf works fully offline with no VPS calls.
///
/// Identity mirrors the domain key `(mgtNumber, drive)`; `stableID` is stored so
/// it can be used as a `#Unique` constraint and matched against `CatalogKey`.
@Model
final class OwnedModel {
    /// `CatalogKey.stableID`, e.g. "MGT00748·L" — the bonded identity.
    @Attribute(.unique) var stableID: String

    var mgtNumber: String
    var driveRaw: String
    var editionNo: String?
    var notes: String?
    var acquiredAt: Date
    var hasModel: Bool

    init(
        stableID: String,
        mgtNumber: String,
        driveRaw: String,
        editionNo: String?,
        notes: String?,
        acquiredAt: Date,
        hasModel: Bool
    ) {
        self.stableID = stableID
        self.mgtNumber = mgtNumber
        self.driveRaw = driveRaw
        self.editionNo = editionNo
        self.notes = notes
        self.acquiredAt = acquiredAt
        self.hasModel = hasModel
    }

    /// Build a persistence row from a pure domain copy.
    convenience init(_ copy: OwnedCopy) {
        self.init(
            stableID: copy.key.stableID,
            mgtNumber: copy.mgtNumber,
            driveRaw: copy.drive.rawValue,
            editionNo: copy.editionNo,
            notes: copy.notes,
            acquiredAt: copy.acquiredAt,
            hasModel: copy.hasModel
        )
    }

    var drive: Drive { Drive(rawValue: driveRaw) ?? .lhd }

    /// Project back to the pure domain value type for UI/logic.
    var ownedCopy: OwnedCopy {
        OwnedCopy(
            key: CatalogKey(mgtNumber: mgtNumber, drive: drive),
            editionNo: editionNo,
            notes: notes,
            acquiredAt: acquiredAt,
            hasModel: hasModel
        )
    }
}
