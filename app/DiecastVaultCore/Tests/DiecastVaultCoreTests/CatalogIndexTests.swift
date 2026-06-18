import XCTest
@testable import DiecastVaultCore

final class CatalogIndexTests: XCTestCase {

    func testEmptyQueryReturnsWholeDedupedCatalog() {
        // Arrange
        let index = CatalogIndex()

        // Act
        let hits = index.search("")

        // Assert — one hit per distinct number, sorted ascending.
        XCTAssertFalse(hits.isEmpty)
        let numbers = hits.map(\.mgtNumber)
        XCTAssertEqual(numbers, numbers.sorted())
        XCTAssertEqual(Set(numbers).count, numbers.count, "hits must be deduped by number")
    }

    func testSearchMatchesByName() {
        // Arrange
        let index = CatalogIndex()

        // Act
        let hits = index.search("supra")

        // Assert
        XCTAssertEqual(hits.count, 1)
        XCTAssertEqual(hits.first?.mgtNumber, "MGT00748")
    }

    func testSearchMatchesByNumber() {
        // Arrange
        let index = CatalogIndex()

        // Act
        let hits = index.search("00512")

        // Assert
        XCTAssertEqual(hits.first?.name, "Mazda RX-7 FD3S")
    }

    func testHitCarriesBothDrivesWhenOffered() {
        // Arrange
        let index = CatalogIndex()

        // Act — MGT00748 ships in both L and R in the catalog sample.
        let hit = index.search("00748").first

        // Assert
        XCTAssertEqual(hit?.drives.count, 2)
        XCTAssertTrue(hit?.drives.contains(.lhd) ?? false)
        XCTAssertTrue(hit?.drives.contains(.rhd) ?? false)
    }

    func testNoMatchReturnsEmpty() {
        // Arrange
        let index = CatalogIndex()

        // Act / Assert
        XCTAssertTrue(index.search("zzzznope").isEmpty)
    }

    func testResolveReleaseForChosenDrive() {
        // Arrange
        let index = CatalogIndex()

        // Act
        let release = index.release(forNumber: "mgt00748", drive: .rhd)

        // Assert — normalized number + requested drive.
        XCTAssertEqual(release.mgtNumber, "MGT00748")
        XCTAssertEqual(release.drive, .rhd)
    }

    func testResolveSynthesizesMatteReleaseForUnlistedDrive() {
        // Arrange — MGT00295 is only listed in LHD in the sample.
        let index = CatalogIndex()

        // Act
        let release = index.release(forNumber: "MGT00295", drive: .rhd)

        // Assert — drive is always pickable; synthesized release is matte.
        XCTAssertEqual(release.drive, .rhd)
        XCTAssertFalse(release.isLit)
        XCTAssertEqual(release.name, "Ford Mustang GT")
    }
}
