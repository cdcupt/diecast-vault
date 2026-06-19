import XCTest
@testable import DiecastVaultCore

/// Covers the cosmetic-only cabinet style table (DESIGN §4.2b). Styles are pure
/// theme swaps over one structure, so the contract worth pinning is: the set is
/// complete, the default is Lightbar White, only Museum is a dark case, the
/// theme/key derivation is stable, and `Codable` round-trips (it persists).
final class CabinetStyleTests: XCTestCase {

    func testShipsExactlyFourStyles() {
        XCTAssertEqual(CabinetStyle.allCases.count, 4)
        XCTAssertEqual(
            Set(CabinetStyle.allCases),
            [.lightbarWhite, .walnut, .museum, .garage]
        )
    }

    func testDefaultIsLightbarWhite() {
        XCTAssertEqual(CabinetStyle.default, .lightbarWhite)
    }

    func testOnlyMuseumIsADarkContainedCase() {
        for style in CabinetStyle.allCases {
            XCTAssertEqual(style.isDarkCase, style == .museum, "\(style) dark-case flag")
        }
    }

    func testLocalizationKeysDeriveFromRawValue() {
        XCTAssertEqual(CabinetStyle.walnut.nameKey, "cabinet.style.walnut.name")
        XCTAssertEqual(CabinetStyle.museum.taglineKey, "cabinet.style.museum.tagline")
    }

    func testEveryStyleHasADistinctTheme() {
        let themes = CabinetStyle.allCases.map(\.theme)
        XCTAssertEqual(Set(themes).count, CabinetStyle.allCases.count,
                       "each style must render a distinct material/light theme")
    }

    func testThemeColoursAreInUnitRange() {
        for style in CabinetStyle.allCases {
            let t = style.theme
            for rgb in [t.carcass, t.backboard, t.litFace, t.matteRecess, t.shelf, t.stageBackdrop] {
                for c in [rgb.r, rgb.g, rgb.b] {
                    XCTAssertTrue((0.0...1.0).contains(c), "\(style) colour component out of range: \(c)")
                }
            }
        }
    }

    func testMuseumBackdropIsTheDarkStage() {
        // The one dark cabinet reuses the locked stage-0 backdrop, exactly like
        // the 3D viewer — that justification is what keeps it on-system.
        XCTAssertEqual(CabinetStyle.museum.theme.stageBackdrop, RGB(Palette.stage0.red, Palette.stage0.green, Palette.stage0.blue))
    }

    func testCodableRoundTrips() throws {
        for style in CabinetStyle.allCases {
            let data = try JSONEncoder().encode(style)
            let decoded = try JSONDecoder().decode(CabinetStyle.self, from: data)
            XCTAssertEqual(decoded, style)
        }
    }
}
