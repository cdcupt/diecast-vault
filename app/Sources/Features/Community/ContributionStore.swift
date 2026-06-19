import SwiftUI
import DiecastVaultCore

/// App-layer store for the user's OPTED-IN community shares. The upload itself is
/// stubbed for v1.1 (no backend), so this is the honest local source of truth for
/// "scans I've offered" — it backs the Me recognition stat and the Library credit
/// lines, both of which are DERIVED from it (never hardcoded).
///
/// Seeded from the bundled sample library so the recognition surface reads as a
/// real contributor on first launch; a fresh share from the post-bond prompt is
/// appended (deduped by key) and immediately reflected in Me.
@MainActor
final class ContributionStore: ObservableObject {
    @Published private(set) var contributions: [CommunityContribution]

    init(seed: [CommunityContribution] = CommunityContribution.sampleLibrary) {
        self.contributions = seed
    }

    /// The derived recognition summary shown in Me. Recomputed from the current
    /// opted-in shares every time the view reads it.
    var summary: ContributionSummary {
        ContributionSummary(contributions: contributions)
    }

    /// Record a freshly-shared scan (opt-in only). Deduped by `(number, drive)`:
    /// re-sharing the same key keeps the existing canonical entry. The upload is
    /// queued — it actually transfers once the community backend ships (v1.1).
    func queueShare(_ copy: OwnedCopy, name: String, isWorldFirst: Bool) {
        guard !contributions.contains(where: { $0.key == copy.key }) else { return }
        let contribution = CommunityContribution(
            key: copy.key,
            name: name,
            contributor: CommunityContribution.myHandle,
            isMine: true,
            isWorldFirst: isWorldFirst,
            downloads: 0
        )
        contributions.append(contribution)
    }
}
