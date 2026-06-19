import Foundation

/// A contributor-recognition badge earned from opted-in shares (mockup
/// #s-settings recognition strip). Light badges only — earned, never decorative.
public enum ContributionBadge: String, Codable, Sendable, CaseIterable, Identifiable {
    /// Lit a previously-dark niche for everyone (one per world-first, capped label).
    case firstLight
    /// Has shared at least one scan.
    case seeder
    /// A signed-in, verified owner.
    case verifiedOwner

    public var id: String { rawValue }
}

/// The DERIVED contributor-recognition stat shown in Me (mockup #s-settings).
/// Everything here is computed from the user's opted-in `CommunityContribution`s
/// — the "N releases lit" headline is never a hardcoded literal, so it stays
/// honest as shares are added or removed.
public struct ContributionSummary: Equatable, Sendable {
    /// How many releases this account has lit for the community (= shared scans).
    public let litReleases: Int
    /// Total downloads across the user's shared scans.
    public let totalDownloads: Int
    /// How many of the user's shares were world-firsts.
    public let worldFirsts: Int
    /// The light badges earned (order is display order).
    public let badges: [ContributionBadge]

    public init(litReleases: Int, totalDownloads: Int, worldFirsts: Int, badges: [ContributionBadge]) {
        self.litReleases = litReleases
        self.totalDownloads = totalDownloads
        self.worldFirsts = worldFirsts
        self.badges = badges
    }

    /// Derive the summary from the user's opted-in shares. Only contributions the
    /// account owns (`isMine`) count toward recognition.
    public init(contributions: [CommunityContribution], isVerifiedOwner: Bool = true) {
        let mine = contributions.filter(\.isMine)
        let lit = mine.count
        let firsts = mine.filter(\.isWorldFirst).count
        self.litReleases = lit
        self.totalDownloads = mine.reduce(0) { $0 + $1.downloads }
        self.worldFirsts = firsts

        var earned: [ContributionBadge] = []
        if firsts > 0 { earned.append(.firstLight) }
        if lit > 0 { earned.append(.seeder) }
        if isVerifiedOwner { earned.append(.verifiedOwner) }
        self.badges = earned
    }
}
