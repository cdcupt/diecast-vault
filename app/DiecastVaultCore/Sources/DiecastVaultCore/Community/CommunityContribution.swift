import Foundation

/// A scan a contributor has OPTED IN to share with the community (DESIGN Flow F,
/// mockup #s-community / #s-settings). This is the credited, deduped community
/// artifact — distinct from the device-only `OwnedCopy`, which never leaves the
/// device. Sharing is explicit and revocable; a personal model is only ever a
/// contribution once the owner chose to share it.
///
/// The upload itself is STUBBED for v1.1 (no backend yet); this value type is the
/// honest local representation of "scans I've offered", so the recognition stat
/// and the per-model "scanned by @you" credit are DERIVED, never hardcoded.
public struct CommunityContribution: Identifiable, Hashable, Codable, Sendable {
    public var id: String { key.stableID }

    /// The deduped community identity — one canonical scan per `(number, drive)`.
    public let key: CatalogKey
    /// Marque + model, shown in the serif voice (e.g. "Porsche 911 Turbo").
    public let name: String
    /// The handle credited on the shared model (e.g. "@erik_64").
    public let contributor: String
    /// Whether THIS account is the contributor (drives the "· you" credit suffix).
    public let isMine: Bool
    /// True when this was the first scan of the key in the whole library — a
    /// "world-first" that lit a previously-dark niche for everyone.
    public let isWorldFirst: Bool
    /// How many owners have reused this scan instead of re-scanning their own.
    public let downloads: Int

    public init(
        key: CatalogKey,
        name: String,
        contributor: String,
        isMine: Bool,
        isWorldFirst: Bool,
        downloads: Int
    ) {
        self.key = key
        self.name = name
        self.contributor = contributor
        self.isMine = isMine
        self.isWorldFirst = isWorldFirst
        self.downloads = downloads
    }

    public var mgtNumber: String { key.mgtNumber }
    public var drive: Drive { key.drive }

    /// The "scanned by @handle" credit line (mockup #s-community placard). The
    /// "· you" suffix is appended in the view layer so the localized "you" word
    /// stays out of this pure type.
    public var creditHandle: String { contributor }
}

public extension CommunityContribution {
    /// Bundled starter library (no backend in v1.1). A deduped set of OTHER
    /// contributors' scans: a fresh install has shared nothing, so nothing here
    /// is credited to the user — recognition is earned via a real opted-in
    /// share, never seeded (App Review honesty: no fabricated history).
    static let sampleLibrary: [CommunityContribution] = [
        .init(key: .init(mgtNumber: "MGT00489", drive: .rhd), name: "Porsche 911 Turbo",
              contributor: "@torque_scale", isMine: false, isWorldFirst: true, downloads: 142),
        .init(key: .init(mgtNumber: "MGT00377", drive: .rhd), name: "Mazda RX-7",
              contributor: "@kaz_jdm", isMine: false, isWorldFirst: false, downloads: 98),
        .init(key: .init(mgtNumber: "MGT00256", drive: .lhd), name: "Honda NSX",
              contributor: "@miura_collects", isMine: false, isWorldFirst: false, downloads: 211),
        .init(key: .init(mgtNumber: "MGT00521", drive: .lhd), name: "Cayman GT4",
              contributor: "@vitrine_jp", isMine: false, isWorldFirst: true, downloads: 73),
        .init(key: .init(mgtNumber: "MGT00640", drive: .lhd), name: "Porsche 911 GT3 RS",
              contributor: "@lhd_garage", isMine: false, isWorldFirst: false, downloads: 188),
        .init(key: .init(mgtNumber: "MGT00802", drive: .rhd), name: "Toyota GR Supra A90",
              contributor: "@matte_diecast", isMine: false, isWorldFirst: true, downloads: 102),
    ]

    /// Placeholder handle used to credit a fresh local share until accounts
    /// exist (there is no sign-in in this build; shares stay on-device).
    static let myHandle = "@collector"
}
