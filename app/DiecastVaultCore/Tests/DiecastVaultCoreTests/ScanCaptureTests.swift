import XCTest
@testable import DiecastVaultCore

final class ScanCapabilityTests: XCTestCase {

    func testSupportedDeviceCanCapture() {
        // Arrange / Act
        let capability = ScanCapability(isSupported: true)

        // Assert
        XCTAssertEqual(capability, .supported)
        XCTAssertTrue(capability.canCapture)
    }

    func testUnsupportedDeviceShowsInviteInsteadOfCapture() {
        // Arrange / Act — the simulator / non-Pro path.
        let capability = ScanCapability(isSupported: false)

        // Assert
        XCTAssertEqual(capability, .unsupported)
        XCTAssertFalse(capability.canCapture)
    }
}

final class ScanResultTests: XCTestCase {

    private func makeResult(coverage: Double, bytes: Int, detail: ReconstructionDetail = .reduced) -> ScanResult {
        ScanResult(
            modelURL: URL(fileURLWithPath: "/tmp/scan.usdz"),
            detail: detail,
            coverage: coverage,
            shotCount: 41,
            byteSize: bytes
        )
    }

    func testCoverageIsClampedAndReportedAsPercent() {
        // Arrange / Act
        let result = makeResult(coverage: 0.72, bytes: 2_800_000)
        let overshoot = makeResult(coverage: 1.4, bytes: 1)

        // Assert
        XCTAssertEqual(result.coveragePercent, 72)
        XCTAssertEqual(overshoot.coverage, 1.0, accuracy: 0.0001, "coverage clamps to 0...1")
    }

    func testReducedDetailCarriesTheCaveat() {
        // Arrange / Act
        let reduced = makeResult(coverage: 0.72, bytes: 2_800_000, detail: .reduced)
        let full = makeResult(coverage: 0.95, bytes: 9_000_000, detail: .full)

        // Assert — the verdict's caveat follows the detail tier, not a UI flag.
        XCTAssertTrue(reduced.showsReducedCaveat)
        XCTAssertEqual(reduced.detail.monoLabel, "REDUCED")
        XCTAssertFalse(full.showsReducedCaveat)
    }

    func testSizeLabelIsHumanReadable() {
        // Arrange / Act
        let result = makeResult(coverage: 0.72, bytes: 2_800_000)

        // Assert — non-empty, file-style size (e.g. "2.8 MB").
        XCTAssertTrue(result.sizeLabel.contains("MB"))
    }
}

final class BondDraftTests: XCTestCase {

    func testIncompleteWithoutDrive() {
        // Arrange — number is fine, drive not yet chosen (drive is half the key).
        let draft = BondDraft(mgtNumber: "MGT00802", drive: nil)

        // Act / Assert
        XCTAssertTrue(draft.hasValidNumber)
        XCTAssertFalse(draft.isComplete)
        XCTAssertNil(draft.validKey)
        XCTAssertNil(draft.ownedCopy(hasModel: true))
    }

    func testRejectsMalformedNumber() {
        // Arrange / Act
        let blank = BondDraft(mgtNumber: "   ", drive: .lhd)
        let noPrefix = BondDraft(mgtNumber: "00802", drive: .lhd)
        let tooShort = BondDraft(mgtNumber: "MGT12", drive: .lhd)

        // Assert
        XCTAssertFalse(blank.isComplete)
        XCTAssertFalse(noPrefix.hasValidNumber)
        XCTAssertFalse(tooShort.hasValidNumber)
    }

    func testCompleteDraftFormsNormalizedKeyAndOwnedCopy() {
        // Arrange — lowercase + spaces to prove normalization happens in the key.
        let draft = BondDraft(mgtNumber: " mgt 00802 ", drive: .rhd, editionNo: "1510/2022")

        // Act
        let key = draft.validKey
        let copy = draft.ownedCopy(hasModel: true)

        // Assert
        XCTAssertTrue(draft.isComplete)
        XCTAssertEqual(key?.mgtNumber, "MGT00802")
        XCTAssertEqual(key?.drive, .rhd)
        XCTAssertEqual(copy?.editionNo, "1510/2022")
        XCTAssertTrue(copy?.hasModel == true, "a bonded scan lights the niche")
        // Edition is a per-copy attribute, never part of identity.
        XCTAssertEqual(copy?.key.stableID, "MGT00802·R")
    }

    func testBlankEditionPersistsAsNil() {
        // Arrange / Act
        let draft = BondDraft(mgtNumber: "MGT00748", drive: .lhd, editionNo: "   ")

        // Assert
        XCTAssertNil(draft.trimmedEdition)
        XCTAssertNil(draft.ownedCopy(hasModel: false)?.editionNo)
    }

    func testDevPathBondsWithoutScanSuccess() {
        // Arrange — identity must be reachable even when hasModel is false
        // (bonding never depends on a scan succeeding).
        let draft = BondDraft(mgtNumber: "MGT00295", drive: .lhd)

        // Act
        let copy = draft.ownedCopy(hasModel: false)

        // Assert
        XCTAssertNotNil(copy)
        XCTAssertEqual(copy?.mgtNumber, "MGT00295")
        XCTAssertFalse(copy?.hasModel == true)
    }
}
