import Foundation

/// Provenance for a reference image (DESIGN §4.5b — attribution is non-negotiable).
public enum ImageOrigin: String, Codable, Sendable {
    /// A real photograph (e.g. Wikimedia Commons) — shows a CC attribution line.
    case commons
    /// An AI illustration fallback — badged "Illustration", never passed off as real.
    case ai
}

/// One spec row in the Real-Car profile (mono key/value list from Wikidata).
public struct RealCarSpec: Hashable, Codable, Sendable, Identifiable {
    public var id: String { key }
    public let key: String
    public let value: String

    public init(key: String, value: String) {
        self.key = key
        self.value = value
    }
}

/// A reference image entry (hero or gallery thumbnail) with its provenance.
public struct RealCarImage: Hashable, Codable, Sendable, Identifiable {
    public var id: String { caption }
    /// Short caption / source label shown under the image.
    public let caption: String
    public let attribution: String
    public let license: String
    public let origin: ImageOrigin

    public init(caption: String, attribution: String, license: String, origin: ImageOrigin) {
        self.caption = caption
        self.attribution = attribution
        self.license = license
        self.origin = origin
    }
}

/// The light reference profile of the full-size car a release replicates
/// (DESIGN §4.5b "Model | Real Car"). On the server this is built once per
/// `(mgtNumber, locale)` by the §8 enrichment pipeline and cached; **in slice 2
/// it is STUBBED with local sample data** (`RealCarProfile.sample(for:)`) and is
/// clearly tagged "sample — server-backed later" in the UI. No network.
public struct RealCarProfile: Hashable, Codable, Sendable {
    public let mgtNumber: String
    /// History paragraphs (grounded + cited in the real pipeline).
    public let history: [String]
    public let historySource: String
    public let specs: [RealCarSpec]
    public let hero: RealCarImage
    public let gallery: [RealCarImage]
    /// True when this profile is locally-stubbed sample data, not server-fetched.
    public let isSample: Bool

    public init(
        mgtNumber: String,
        history: [String],
        historySource: String,
        specs: [RealCarSpec],
        hero: RealCarImage,
        gallery: [RealCarImage],
        isSample: Bool = false
    ) {
        self.mgtNumber = mgtNumber
        self.history = history
        self.historySource = historySource
        self.specs = specs
        self.hero = hero
        self.gallery = gallery
        self.isSample = isSample
    }
}

public extension RealCarProfile {
    /// Local STUB used by the Real-Car view until the enrichment backend lands.
    /// Returns a sample profile keyed loosely off the release name so the screen
    /// has believable content; everything is marked `isSample`.
    static func sample(for release: Release) -> RealCarProfile {
        let model = release.name
        return RealCarProfile(
            mgtNumber: release.mgtNumber,
            history: [
                "The \(model) is the full-size car this 1:64 release replicates. This write-up is bundled sample copy so the Real-Car view is reviewable offline.",
                "When the enrichment backend lands, these paragraphs come from a grounded, cited Wikipedia extract resolved per (release, locale)."
            ],
            historySource: "Wikipedia (sample)",
            specs: [
                RealCarSpec(key: "MAKER", value: String(model.split(separator: " ").first ?? "—")),
                RealCarSpec(key: "ENGINE", value: "— (sample)"),
                RealCarSpec(key: "POWER", value: "— (sample)"),
                RealCarSpec(key: "0–100", value: "— (sample)"),
                RealCarSpec(key: "DRIVETRAIN", value: release.drive == .lhd ? "LHD layout" : "RHD layout")
            ],
            hero: RealCarImage(
                caption: "Reference photo placeholder",
                attribution: "Sample — Wikimedia Commons later",
                license: "CC-BY-SA (sample)",
                origin: .commons
            ),
            gallery: [
                RealCarImage(caption: "front 3/4", attribution: "sample", license: "CC-BY", origin: .commons),
                RealCarImage(caption: "rear", attribution: "sample", license: "CC-BY", origin: .commons),
                RealCarImage(caption: "interior", attribution: "sample", license: "CC-BY-SA", origin: .commons),
                RealCarImage(caption: "illustration", attribution: "AI illustration", license: "—", origin: .ai)
            ],
            isSample: true
        )
    }
}
