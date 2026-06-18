import Foundation

/// Pure, UI-free search over the bundled catalog. Slice 2's Catalog tab searches
/// by number / name / livery; the real implementation queries the server's
/// tsvector index (TECH.html §3) — this local index gives the same behavior
/// offline and is unit-testable without a simulator.
///
/// One release row per release here is keyed by `(mgtNumber, drive)`, but search
/// dedups to the bare number so a single result expands to a drive toggle (the
/// drive is chosen at pick time — it is part of the key, not a search facet).
public struct CatalogIndex: Sendable {
    /// A search hit: a release number/name and which drives the catalog offers.
    public struct Hit: Identifiable, Hashable, Sendable {
        public var id: String { mgtNumber }
        public let mgtNumber: String
        public let name: String
        public let edition: String?
        public let drives: [Drive]

        public init(mgtNumber: String, name: String, edition: String?, drives: [Drive]) {
            self.mgtNumber = mgtNumber
            self.name = name
            self.edition = edition
            self.drives = drives
        }
    }

    private let releases: [Release]

    public init(releases: [Release] = Release.catalogSample) {
        self.releases = releases
    }

    /// Search by number, name, or livery substring. An empty query returns the
    /// whole catalog (so the list reads as a browsable index, not a blank search).
    /// Results are deduped by number and sorted by number for stable ordering.
    public func search(_ rawQuery: String) -> [Hit] {
        let query = rawQuery.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        let matched = releases.filter { release in
            guard !query.isEmpty else { return true }
            return release.mgtNumber.lowercased().contains(query)
                || release.name.lowercased().contains(query)
                || (release.edition?.lowercased().contains(query) ?? false)
        }

        // Group by bare number; each group becomes one hit carrying its drives.
        var byNumber: [String: [Release]] = [:]
        for release in matched {
            byNumber[release.mgtNumber, default: []].append(release)
        }

        return byNumber
            .map { number, group -> Hit in
                let first = group[0]
                let drives = Drive.allCases.filter { d in group.contains { $0.drive == d } }
                return Hit(mgtNumber: number, name: first.name, edition: first.edition, drives: drives)
            }
            .sorted { $0.mgtNumber < $1.mgtNumber }
    }

    /// Resolve the full `Release` for a chosen `(number, drive)` pick. Falls back
    /// to a synthesized matte release if that exact drive isn't pre-listed (the
    /// drive is always pickable — it's part of the key).
    public func release(forNumber mgtNumber: String, drive: Drive) -> Release {
        let normalized = CatalogKey.normalize(mgtNumber)
        if let exact = releases.first(where: { $0.mgtNumber == normalized && $0.drive == drive }) {
            return exact
        }
        let any = releases.first { $0.mgtNumber == normalized }
        return Release(
            key: .init(mgtNumber: normalized, drive: drive),
            name: any?.name ?? normalized,
            edition: any?.edition,
            isLit: false
        )
    }
}
