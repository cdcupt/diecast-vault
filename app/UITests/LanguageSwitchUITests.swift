import XCTest

/// Proves the runtime language switch (DESIGN F4) flips the whole app **live** —
/// no relaunch. Launches in English into the Me screen, opens Language, taps
/// 简体中文, and asserts the UI re-renders in Chinese in the same session.
final class LanguageSwitchUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    func testSwitchingToChineseReRendersLive() {
        let app = XCUIApplication()
        // Boot straight into Me in English so the test is deterministic and fast
        // (the same debug-route / language hooks the sim screenshots use).
        app.launchEnvironment["DV_ROUTE"] = "me"
        app.launchEnvironment["DV_LANG"] = "en"
        app.launch()

        // English baseline: the settings list shows the English "Language" row.
        let languageRow = app.staticTexts["Language"]
        XCTAssertTrue(languageRow.waitForExistence(timeout: 5), "English Me screen should show a 'Language' row")

        languageRow.tap()

        // On the Language screen, English is the selected language.
        XCTAssertTrue(app.staticTexts["Selected"].waitForExistence(timeout: 3),
                      "English should be marked Selected before switching")

        // Tap the Simplified-Chinese row.
        let chineseRow = app.staticTexts["简体中文"]
        XCTAssertTrue(chineseRow.waitForExistence(timeout: 3), "Language list should offer 简体中文")
        chineseRow.tap()

        // LIVE proof: without relaunching, the selected badge is now the Chinese
        // 已选 and the live note is the Chinese copy — the tree re-rendered against
        // the new locale.
        XCTAssertTrue(app.staticTexts["已选"].waitForExistence(timeout: 3),
                      "After tapping 简体中文 the selected badge should flip to 已选 live")
        XCTAssertTrue(app.staticTexts["显示语言"].waitForExistence(timeout: 3),
                      "The Language screen heading should re-render as 显示语言 live")
    }
}
