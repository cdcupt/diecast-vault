import Foundation

/// The in-progress bond form: a catalog number, a required drive side, and an
/// optional per-copy edition serial. Bonding is the step that attaches the
/// canonical `(mgtNumber, drive)` identity to an owned model — deliberately
/// SEPARATE from scanning, so identity never depends on a scan succeeding
/// (TECH.html: "Bond no.+drive · separate step").
///
/// Pure and validating: the view binds raw strings to it and reads `validKey` /
/// `ownedCopy`; the rules (number required, drive required, edition optional and
/// never part of the key) live here, unit-tested without any UI.
public struct BondDraft: Hashable, Sendable {
    /// Raw catalog number as typed (normalized only when forming the key).
    public var mgtNumber: String
    /// Drive side — required, because it is half the dedup key. `nil` until chosen.
    public var drive: Drive?
    /// Optional per-copy edition serial, e.g. "1510/2022". Never part of the key.
    public var editionNo: String

    public init(mgtNumber: String = "", drive: Drive? = nil, editionNo: String = "") {
        self.mgtNumber = mgtNumber
        self.drive = drive
        self.editionNo = editionNo
    }

    /// A Mini GT number looks like `MGT` + at least 3 digits once normalized. Kept
    /// permissive (the server is the real authority); this only blocks obviously
    /// empty / malformed input so a bond can't save a junk key.
    public var hasValidNumber: Bool {
        let normalized = CatalogKey.normalize(mgtNumber)
        guard normalized.hasPrefix("MGT") else { return false }
        let digits = normalized.dropFirst(3)
        return digits.count >= 3 && digits.allSatisfy(\.isNumber)
    }

    /// True when both halves of the key are present and the number is well-formed —
    /// the bond CTA's enabled condition (light-as-state, not a permanently greyed
    /// button: the action lights up only when the key is complete).
    public var isComplete: Bool { hasValidNumber && drive != nil }

    /// The catalog key once the draft is complete, else `nil`.
    public var validKey: CatalogKey? {
        guard hasValidNumber, let drive else { return nil }
        return CatalogKey(mgtNumber: mgtNumber, drive: drive)
    }

    /// Trimmed edition serial, or `nil` when blank (so empty input never persists
    /// as an empty string).
    public var trimmedEdition: String? {
        let trimmed = editionNo.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    /// Build the device-only `OwnedCopy` this draft bonds. `hasModel` reflects
    /// whether a viewable model is attached (true for a real or dev-path scan) —
    /// that is what lights the niche in the cabinet. Returns `nil` if the draft
    /// is incomplete.
    public func ownedCopy(hasModel: Bool, acquiredAt: Date = Date()) -> OwnedCopy? {
        guard let key = validKey else { return nil }
        return OwnedCopy(
            key: key,
            editionNo: trimmedEdition,
            notes: nil,
            acquiredAt: acquiredAt,
            hasModel: hasModel
        )
    }
}
