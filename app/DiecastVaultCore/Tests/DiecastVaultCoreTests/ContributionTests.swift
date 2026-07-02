import XCTest
@testable import DiecastVaultCore

final class ContributionSummaryTests: XCTestCase {

    func testFreshInstallClaimsNoShares() {
        // Arrange — the bundled starter library, exactly as a fresh install sees it.
        let lib = CommunityContribution.sampleLibrary

        // Act
        let summary = ContributionSummary(contributions: lib)

        // Assert — recognition is earned, never seeded: a user who has shared
        // nothing is credited with nothing.
        XCTAssertEqual(summary.litReleases, 0)
        XCTAssertEqual(summary.totalDownloads, 0)
        XCTAssertEqual(summary.worldFirsts, 0)
    }

    func testSummaryCountsOnlyMyShares() {
        // Arrange — a synthetic mix of my shares and other contributors'.
        let lib: [CommunityContribution] = [
            .init(key: .init(mgtNumber: "MGT00001", drive: .lhd), name: "A",
                  contributor: "@me", isMine: true, isWorldFirst: true, downloads: 5),
            .init(key: .init(mgtNumber: "MGT00002", drive: .rhd), name: "B",
                  contributor: "@me", isMine: true, isWorldFirst: false, downloads: 7),
            .init(key: .init(mgtNumber: "MGT00003", drive: .lhd), name: "C",
                  contributor: "@other", isMine: false, isWorldFirst: true, downloads: 90),
        ]

        // Act
        let summary = ContributionSummary(contributions: lib)

        // Assert — only opted-in shares I own count toward recognition.
        XCTAssertEqual(summary.litReleases, 2)
        XCTAssertEqual(summary.totalDownloads, 12)
        XCTAssertEqual(summary.worldFirsts, 1)
    }

    func testBadgesAreEarnedNotDecorative() {
        // Arrange — someone with a world-first share.
        let withFirst = ContributionSummary(
            contributions: [
                .init(key: .init(mgtNumber: "MGT00489", drive: .rhd), name: "911 Turbo",
                      contributor: "@me", isMine: true, isWorldFirst: true, downloads: 5)
            ]
        )
        // Act / Assert — first-light + seeder + verified-owner all earned.
        XCTAssertTrue(withFirst.badges.contains(.firstLight))
        XCTAssertTrue(withFirst.badges.contains(.seeder))
        XCTAssertTrue(withFirst.badges.contains(.verifiedOwner))
    }

    func testNoSharesEarnsOnlyVerifiedOwner() {
        // Arrange — verified owner who has shared nothing.
        let none = ContributionSummary(contributions: [], isVerifiedOwner: true)

        // Assert — no seeder / first-light without shares.
        XCTAssertEqual(none.litReleases, 0)
        XCTAssertFalse(none.badges.contains(.seeder))
        XCTAssertFalse(none.badges.contains(.firstLight))
        XCTAssertTrue(none.badges.contains(.verifiedOwner))
    }
}

final class CommunityContributionTests: XCTestCase {

    func testSampleLibraryIsDedupedByKey() {
        // Arrange / Act
        let keys = CommunityContribution.sampleLibrary.map(\.id)

        // Assert — one canonical scan per (number, drive).
        XCTAssertEqual(Set(keys).count, keys.count)
    }

    func testBundledLibraryNeverClaimsUserContributions() {
        // Assert — the starter library is other collectors' work; nothing in it
        // is presented as the user's own share (no fabricated history).
        XCTAssertTrue(CommunityContribution.sampleLibrary.allSatisfy { !$0.isMine })
    }
}
