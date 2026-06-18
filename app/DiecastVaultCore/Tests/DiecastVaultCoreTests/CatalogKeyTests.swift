import XCTest
@testable import DiecastVaultCore

final class CatalogKeyTests: XCTestCase {

    func testNormalizeTrimsUppercasesAndStripsSpaces() {
        // Arrange
        let raw = "  mgt 00748 "

        // Act
        let normalized = CatalogKey.normalize(raw)

        // Assert
        XCTAssertEqual(normalized, "MGT00748")
    }

    func testInitNormalizesNumber() {
        // Arrange / Act
        let key = CatalogKey(mgtNumber: "mgt00219", drive: .rhd)

        // Assert
        XCTAssertEqual(key.mgtNumber, "MGT00219")
        XCTAssertEqual(key.drive, .rhd)
    }

    func testStableIDCombinesNumberAndDrive() {
        // Arrange
        let key = CatalogKey(mgtNumber: "MGT00748", drive: .lhd)

        // Act / Assert
        XCTAssertEqual(key.stableID, "MGT00748·L")
    }

    func testKeysWithSameNumberDifferentDriveAreDistinct() {
        // Arrange
        let left = CatalogKey(mgtNumber: "MGT00748", drive: .lhd)
        let right = CatalogKey(mgtNumber: "MGT00748", drive: .rhd)

        // Act / Assert
        XCTAssertNotEqual(left, right)
        XCTAssertNotEqual(left.hashValue, right.hashValue)
    }
}

final class PaletteTests: XCTestCase {

    func testTungstenParsesToExpectedComponents() {
        // Arrange / Act
        let t = Palette.tungsten

        // Assert — #F26B1F
        XCTAssertEqual(t.red, 0xF2 / 255.0, accuracy: 0.0001)
        XCTAssertEqual(t.green, 0x6B / 255.0, accuracy: 0.0001)
        XCTAssertEqual(t.blue, 0x1F / 255.0, accuracy: 0.0001)
    }

    func testHexPrefixIsOptional() {
        // Arrange / Act
        let withHash = PaletteToken("#FFFFFF")
        let without = PaletteToken("FFFFFF")

        // Assert
        XCTAssertEqual(withHash.red, 1.0, accuracy: 0.0001)
        XCTAssertEqual(without.red, withHash.red, accuracy: 0.0001)
    }
}

final class ReleaseTests: XCTestCase {

    func testSampleShelfHasMixOfLitAndMatte() {
        // Arrange / Act
        let shelf = Release.sampleShelf

        // Assert
        XCTAssertFalse(shelf.isEmpty)
        XCTAssertTrue(shelf.contains { $0.isLit })
        XCTAssertTrue(shelf.contains { !$0.isLit })
    }

    func testReleaseIDMatchesKeyStableID() {
        // Arrange
        let release = Release(key: .init(mgtNumber: "MGT00512", drive: .lhd), name: "Mazda RX-7 FD3S")

        // Act / Assert
        XCTAssertEqual(release.id, "MGT00512·L")
    }
}
