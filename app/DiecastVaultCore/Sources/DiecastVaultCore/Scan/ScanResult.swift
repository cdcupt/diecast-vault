import Foundation

/// The detail level a reconstruction produced. Spike-0 ships only `reduced`
/// (the fast `PhotogrammetrySession.Request.Detail.reduced` tier — small,
/// honest, "good enough to show a friend"); the higher tiers are listed so the
/// verdict can speak the truth about what was made.
public enum ReconstructionDetail: String, Codable, Sendable, CaseIterable {
    case reduced
    case medium
    case full

    /// Short mono label for the verdict's spec row (e.g. "REDUCED").
    public var monoLabel: String { rawValue.uppercased() }

    /// Whether this tier carries the reduced-detail caveat the verdict surfaces.
    public var isReduced: Bool { self == .reduced }
}

/// The outcome of an on-device reconstruction — the value type the verdict card
/// is built from. Pure and `Sendable` so the capture pipeline can hand it across
/// isolation boundaries and the verdict copy stays unit-testable without a
/// PhotogrammetrySession.
///
/// This describes a *scan*; it carries no catalog identity. Bonding (attaching
/// the `(mgtNumber, drive)` key) is a deliberately separate step — a scan exists
/// and is keepable before it ever has a name (TECH.html: "bond no.+drive ·
/// separate step", identity never depends on scan success).
public struct ScanResult: Identifiable, Hashable, Codable, Sendable {
    public let id: UUID
    /// Where the reconstructed USDZ was written on-device.
    public let modelURL: URL
    public let detail: ReconstructionDetail
    /// Capture coverage fraction reached on the orbit gauge, 0...1.
    public let coverage: Double
    /// Number of frames meshed.
    public let shotCount: Int
    /// On-disk size of the USDZ, in bytes.
    public let byteSize: Int
    public let createdAt: Date

    public init(
        id: UUID = UUID(),
        modelURL: URL,
        detail: ReconstructionDetail = .reduced,
        coverage: Double,
        shotCount: Int,
        byteSize: Int,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.modelURL = modelURL
        self.detail = detail
        self.coverage = max(0, min(1, coverage))
        self.shotCount = shotCount
        self.byteSize = byteSize
        self.createdAt = createdAt
    }

    /// Coverage as a whole-percent for the mono telemetry (e.g. 72).
    public var coveragePercent: Int { Int((coverage * 100).rounded()) }

    /// Human-friendly size for the verdict's "Size" spec row (e.g. "2.8 MB").
    public var sizeLabel: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useKB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(byteSize))
    }

    /// Whether the reduced-detail caveat should be shown (always true while
    /// Spike-0 only produces `reduced` — kept on the result so a future higher
    /// tier suppresses the caveat automatically).
    public var showsReducedCaveat: Bool { detail.isReduced }
}
