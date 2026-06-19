import XCTest
@testable import DiecastVaultCore

final class ContributionSummaryTests: XCTestCase {

    func testSummaryCountsOnlyMyShares() {
        // Arrange — a mix of my shares and other contributors'.
        let lib = CommunityContribution.sampleLibrary
        let mineCount = lib.filter(\.isMine).count

        // Act
        let summary = ContributionSummary(contributions: lib)

        // Assert — "lit for the community" counts only opted-in shares I own.
        XCTAssertEqual(summary.litReleases, mineCount)
        XCTAssertGreaterThan(summary.litReleases, 0)
    }

    func testSummaryDerivesDownloadsAndWorldFirsts() {
        // Arrange
        let lib = CommunityContribution.sampleLibrary
        let mine = lib.filter(\.isMine)
        let expectedDownloads = mine.reduce(0) { $0 + $1.downloads }
        let expectedFirsts = mine.filter(\.isWorldFirst).count

        // Act
        let summary = ContributionSummary(contributions: lib)

        // Assert
        XCTAssertEqual(summary.totalDownloads, expectedDownloads)
        XCTAssertEqual(summary.worldFirsts, expectedFirsts)
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

    func testMyContributionsAreCredited() {
        // Arrange
        let mine = CommunityContribution.sampleLibrary.filter(\.isMine)

        // Assert — every share I own credits my handle.
        XCTAssertFalse(mine.isEmpty)
        XCTAssertTrue(mine.allSatisfy { $0.creditHandle == CommunityContribution.myHandle })
    }
}
