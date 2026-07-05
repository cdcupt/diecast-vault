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
/// `(mgtNumber, locale)` by the §8 enrichment pipeline and cached; v1.0 ships
/// bundled local profiles (`RealCarProfile.sample(for:)`, `isSample == true`).
/// Sample profiles carry no attribution/license claims — the view layer hides
/// credit lines and the gallery for them. No network.
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

/// The display locale for sample Real-Car copy. The real pipeline resolves a
/// grounded extract per `(release, locale)`; the local stub mirrors that contract
/// with two hand-written samples so the zh build reads natively (DESIGN F4 —
/// "AI real-car history is localized and cached per release"). Kept as a small
/// enum here so Core stays free of any UI / `Locale` dependency.
public enum SampleLocale: String, Sendable {
    case english
    case simplifiedChinese
}

public extension RealCarProfile {
    /// Local STUB used by the Real-Car view until the enrichment backend lands.
    /// Returns a sample profile keyed loosely off the release name so the screen
    /// has believable content; everything is marked `isSample`. The `locale`
    /// selects English or Simplified-Chinese sample prose so the zh build reads
    /// natively (the HISTORY prose stays a local sample per the slice-3 brief).
    static func sample(for release: Release, locale: SampleLocale = .english) -> RealCarProfile {
        let model = release.name
        let zh = locale == .simplifiedChinese
        let drivetrain: String = zh
            ? (release.drive == .lhd ? "左舵布局" : "右舵布局")
            : (release.drive == .lhd ? "LHD layout" : "RHD layout")
        return RealCarProfile(
            mgtNumber: release.mgtNumber,
            history: zh
                ? [
                    "\(model) 是这款 1:64 模型所复刻的真车。",
                    "该参考资料随应用内置，离线也能快速了解模型背后的原型车。"
                ]
                : [
                    "The \(model) is the full-size car this 1:64 release replicates.",
                    "This reference profile is bundled with the app — a quick offline read on the car behind the model."
                ],
            historySource: zh ? "内置参考资料" : "Bundled reference notes",
            // Only rows with REAL values ship: dash-placeholder rows read as
            // unfinished data on a production screen (App Review 2.1a lesson).
            specs: [
                RealCarSpec(key: zh ? "厂商" : "MAKER", value: String(model.split(separator: " ").first ?? "—")),
                RealCarSpec(key: zh ? "驱动" : "DRIVETRAIN", value: drivetrain)
            ],
            hero: RealCarImage(
                caption: zh ? "参考照片占位" : "Reference photo placeholder",
                attribution: zh ? "内置样例" : "Bundled sample",
                license: zh ? "—（样例）" : "— (sample)",
                origin: .commons
            ),
            gallery: [
                RealCarImage(caption: zh ? "前 3/4" : "front 3/4", attribution: "sample", license: "CC-BY", origin: .commons),
                RealCarImage(caption: zh ? "尾部" : "rear", attribution: "sample", license: "CC-BY", origin: .commons),
                RealCarImage(caption: zh ? "内饰" : "interior", attribution: "sample", license: "CC-BY-SA", origin: .commons),
                RealCarImage(caption: zh ? "插画" : "illustration", attribution: "AI illustration", license: "—", origin: .ai)
            ],
            isSample: true
        )
    }
}
