import Foundation

/// A known Mini GT release. In the cabinet metaphor this is one niche: it may be
/// LIT (an owned/present scan) or a MATTE recess (known release, no scan yet).
/// This is the foundation value type for slice 1 — scanning/3D arrive later.
public struct Release: Identifiable, Hashable, Codable, Sendable {
    public var id: String { key.stableID }

    public let key: CatalogKey
    /// Marque + model, a proper noun shown in the serif voice (e.g. "Toyota GR Supra").
    public let name: String
    /// Optional run / year line shown in mono (e.g. "1510/2022").
    public let edition: String?
    /// Light-as-state: true when a scan is present (LIT), false for a MATTE slot.
    public let isLit: Bool

    public init(key: CatalogKey, name: String, edition: String? = nil, isLit: Bool = false) {
        self.key = key
        self.name = name
        self.edition = edition
        self.isLit = isLit
    }

    public var mgtNumber: String { key.mgtNumber }
    public var drive: Drive { key.drive }
}

public extension Release {
    /// Placeholder shelf for slice-1 UI (no backend / no scan yet). A mix of LIT
    /// and MATTE niches so the light-as-state spine is visible immediately.
    static let sampleShelf: [Release] = [
        Release(key: .init(mgtNumber: "MGT00748", drive: .lhd), name: "Toyota GR Supra", edition: "1510/2022", isLit: true),
        Release(key: .init(mgtNumber: "MGT00219", drive: .rhd), name: "Nissan Skyline GT-R", edition: "0480/2021"),
        Release(key: .init(mgtNumber: "MGT00512", drive: .lhd), name: "Mazda RX-7 FD3S", edition: "0902/2022", isLit: true),
        Release(key: .init(mgtNumber: "MGT00333", drive: .rhd), name: "Honda Civic Type R", edition: "1180/2023"),
        Release(key: .init(mgtNumber: "MGT00640", drive: .lhd), name: "Porsche 911 GT3 RS", edition: "0775/2023", isLit: true),
        Release(key: .init(mgtNumber: "MGT00471", drive: .rhd), name: "Subaru Impreza WRX", edition: "0612/2022"),
        Release(key: .init(mgtNumber: "MGT00588", drive: .lhd), name: "Lamborghini Huracán", edition: "0344/2023", isLit: true),
        Release(key: .init(mgtNumber: "MGT00295", drive: .lhd), name: "Ford Mustang GT", edition: "1024/2021")
    ]
}
