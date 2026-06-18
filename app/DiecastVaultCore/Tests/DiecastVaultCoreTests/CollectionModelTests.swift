import XCTest
@testable import DiecastVaultCore

final class ScanStateTests: XCTestCase {

    func testLitReleaseHasViewableModel() {
        // Arrange
        let lit = Release(key: .init(mgtNumber: "MGT00748", drive: .lhd), name: "GR Supra", isLit: true)

        // Act / Assert
        XCTAssertEqual(lit.scanState(isProDevice: false), .hasModel)
        XCTAssertTrue(lit.scanState(isProDevice: true).hasViewableModel)
        XCTAssertNil(lit.scanState(isProDevice: true).contributionNote)
    }

    func testMatteReleaseRoutesByCapability() {
        // Arrange
        let matte = Release(key: .init(mgtNumber: "MGT00219", drive: .rhd), name: "Skyline GT-R")

        // Act / Assert
        XCTAssertEqual(matte.scanState(isProDevice: true), .noScanPro)
        XCTAssertEqual(matte.scanState(isProDevice: false), .noScanBasic)
        XCTAssertFalse(matte.scanState(isProDevice: false).hasViewableModel)
        XCTAssertNotNil(matte.scanState(isProDevice: false).contributionNote)
    }
}

final class OwnedCopyTests: XCTestCase {

    func testSampleSeedMirrorsLitShelfEntries() {
        // Arrange
        let litCount = Release.sampleShelf.filter(\.isLit).count

        // Act
        let seed = OwnedCopy.sampleSeed

        // Assert — one owned, bonded copy per lit sample release.
        XCTAssertEqual(seed.count, litCount)
        XCTAssertTrue(seed.allSatisfy(\.hasModel))
        XCTAssertEqual(Set(seed.map(\.key)).count, seed.count, "seed keys are unique")
    }

    func testOwnedCopyBondsByCatalogKey() {
        // Arrange
        let copy = OwnedCopy(key: .init(mgtNumber: "mgt00512", drive: .lhd), editionNo: "0902/2022")

        // Act / Assert — key normalizes; edition is a per-copy attribute, not identity.
        XCTAssertEqual(copy.mgtNumber, "MGT00512")
        XCTAssertEqual(copy.drive, .lhd)
        XCTAssertEqual(copy.editionNo, "0902/2022")
    }
}

final class RealCarProfileTests: XCTestCase {

    func testSampleProfileIsFlaggedAndPopulated() {
        // Arrange
        let release = Release(key: .init(mgtNumber: "MGT00748", drive: .lhd), name: "Toyota GR Supra", isLit: true)

        // Act
        let profile = RealCarProfile.sample(for: release)

        // Assert — stub is clearly marked and has believable content.
        XCTAssertTrue(profile.isSample)
        XCTAssertEqual(profile.mgtNumber, "MGT00748")
        XCTAssertFalse(profile.history.isEmpty)
        XCTAssertFalse(profile.specs.isEmpty)
        XCTAssertEqual(profile.specs.first?.value, "Toyota")
        // Gallery carries a clearly-labeled AI illustration fallback.
        XCTAssertTrue(profile.gallery.contains { $0.origin == .ai })
    }
}
