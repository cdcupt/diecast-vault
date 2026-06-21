import XCTest

/// Proves the cabinet's orient + route PIPELINES work end-to-end, isolating
/// "pipeline broken" from "gesture recognition broken".
///
/// No agent on this Mac (and no XCUITest synthetic touch) can drive a real
/// finger/mouse drag into RealityKit's hit-test layer, so we cannot assert the
/// gesture *recognizers* fire from a test. Instead the app exposes an env-gated
/// debug harness (`DV_GESTURE_DEBUG=1`) of SwiftUI Buttons — which ARE
/// XCUITest-drivable — that call the SAME `scene.orient(...)` and `onSelect`
/// paths the real drag/tap use. Driving those buttons and observing the live
/// yaw/pitch readout change + the route firing proves the wiring downstream of
/// gesture recognition is sound; only recognition itself still needs a real touch.
final class CabinetGestureDebugUITests: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launchCabinetDebug() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DV_GESTURE_DEBUG"] = "1"
        app.launchEnvironment["DV_LANG"] = "en"
        app.launch()
        return app
    }

    /// Yaw +/- drive the SAME `scene.orient(...)` the drag-orbit uses; the live
    /// readout must change, proving the orient pipeline moves the camera rig.
    func testYawButtonsDriveOrientPipeline() {
        let app = launchCabinetDebug()

        let readout = app.staticTexts["dbg.readout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 8),
                      "Gesture-debug harness should be visible with DV_GESTURE_DEBUG=1")
        let initial = readout.label

        let yawPlus = app.buttons["dbg.yawPlus"]
        XCTAssertTrue(yawPlus.waitForExistence(timeout: 3), "Yaw + button should exist")
        yawPlus.tap()
        yawPlus.tap()

        // The readout label must have changed — the orient() pipeline ran and the
        // @State yaw advanced (the exact path the drag-orbit mutates).
        let afterPlus = readout.label
        XCTAssertNotEqual(initial, afterPlus,
                          "Tapping Yaw + must change the live yaw/pitch readout (orient pipeline live)")

        // Yaw - moves it back the other way — the readout changes again.
        let yawMinus = app.buttons["dbg.yawMinus"]
        XCTAssertTrue(yawMinus.exists, "Yaw - button should exist")
        yawMinus.tap()
        XCTAssertNotEqual(afterPlus, readout.label,
                          "Tapping Yaw - must change the readout again (orient pipeline reversible)")
    }

    /// Pitch +/- exercise the same orient pipeline on the other axis.
    func testPitchButtonsDriveOrientPipeline() {
        let app = launchCabinetDebug()

        let readout = app.staticTexts["dbg.readout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 8), "Debug readout should exist")
        let initial = readout.label

        let pitchPlus = app.buttons["dbg.pitchPlus"]
        XCTAssertTrue(pitchPlus.waitForExistence(timeout: 3), "Pitch + button should exist")
        pitchPlus.tap()
        XCTAssertNotEqual(initial, readout.label,
                          "Tapping Pitch + must change the readout (pitch orient pipeline live)")
    }

    /// "Open first model" drives the SAME `onSelect` route a niche tap would →
    /// CabinetView.handleSelect → ReleaseDetailView. Proving the route pipeline
    /// is intact end-to-end (the part a tap would trigger).
    func testOpenFirstDrivesRoutePipeline() {
        let app = launchCabinetDebug()

        let openFirst = app.buttons["dbg.openFirst"]
        XCTAssertTrue(openFirst.waitForExistence(timeout: 8), "Open-first button should exist")

        let lastSelected = app.staticTexts["dbg.lastSelected"]
        XCTAssertTrue(lastSelected.exists, "Debug last-selected readout should exist")

        openFirst.tap()

        // The selection pipeline fired: either the readout updated to a real name
        // (the same onSelect a tap calls) and/or the detail route pushed. We assert
        // the route navigated — a back button appears once ReleaseDetailView pushes.
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.waitForExistence(timeout: 5),
                      "Tapping Open-first must push the Release detail (route pipeline live)")
    }
}
