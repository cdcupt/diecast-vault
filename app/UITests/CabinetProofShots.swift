import XCTest

/// PROOF-SHOT capture for the PM: drives the cabinet's hidden debug harness
/// (`DV_GESTURE_DEBUG=1`) — the SAME `scene.orient(...)` and `onSelect` paths
/// the real drag/tap gestures use — and saves full-screen PNG screenshots that
/// visually prove the rotate + open-detail PIPELINES work end to end.
///
/// Why a harness and not a real drag: no synthetic touch on this host (neither
/// XCUITest's synthetic events nor cliclick) reaches RealityKit's hit-test /
/// gesture layer, so the gesture *recognizers* cannot be fired from a test. The
/// debug Buttons ARE XCUITest-drivable and call the identical downstream code,
/// so driving them proves everything downstream of recognition is sound. The
/// second test (`testRealCoordinateInputDoesNotReachCabinet`) documents the
/// limit with before/after evidence.
///
/// Screenshots are attached with `.keepAlways` so they survive into the
/// `.xcresult`, then extracted to /tmp/dv-proof/ by the runner.
final class CabinetProofShots: XCTestCase {

    override func setUp() {
        continueAfterFailure = false
    }

    private func launchCabinetDebug() -> XCUIApplication {
        let app = XCUIApplication()
        app.launchEnvironment["DV_GESTURE_DEBUG"] = "1"
        app.launchEnvironment["DV_LANG"] = "en"          // force English chrome
        app.launchArguments += ["-AppleLanguages", "(en)", "-AppleLocale", "en_US"]
        app.launch()
        return app
    }

    /// Attach a full-screen screenshot that persists into the .xcresult.
    private func shot(_ named: String) {
        let screenshot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: screenshot)
        attachment.name = named
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    /// Give RealityKit a beat to re-render the camera rig to the on-screen
    /// texture before grabbing the framebuffer (orient() is synchronous but the
    /// composited frame lands a render tick later).
    private func settleRender() {
        let settle = expectation(description: "render settle")
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { settle.fulfill() }
        wait(for: [settle], timeout: 2)
    }

    /// Reads the live `dbg.readout` ("yaw X · pitch Y") for the yaw component, so
    /// assertions can prove the orient pipeline actually moved (not stale shots).
    private func yaw(from readout: XCUIElement) -> Float {
        // Label looks like: "yaw 0.500 · pitch 0.070"
        let label = readout.label
        guard let token = label.split(separator: "·").first?
            .replacingOccurrences(of: "yaw", with: "")
            .trimmingCharacters(in: .whitespaces),
            let value = Float(token) else { return .nan }
        return value
    }

    /// 01–05: the screenshots the PM wants. Each step asserts the readout/route
    /// actually changed so every PNG is meaningful, not a stale frame.
    func testCaptureCabinetProofShots() {
        let app = launchCabinetDebug()

        let readout = app.staticTexts["dbg.readout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 12),
                      "Gesture-debug harness must be visible with DV_GESTURE_DEBUG=1")
        settleRender()

        // 01 — default front-on angle.
        let homeYaw = yaw(from: readout)
        shot("01-home")

        // 02 — rotate RIGHT: tap yaw+ several times, prove yaw advanced positive.
        let yawPlus = app.buttons["dbg.yawPlus"]
        XCTAssertTrue(yawPlus.waitForExistence(timeout: 3), "Yaw + button should exist")
        for _ in 0..<5 { yawPlus.tap() }
        settleRender()
        let rightYaw = yaw(from: readout)
        XCTAssertGreaterThan(rightYaw, homeYaw,
                             "Tapping Yaw + must orbit the cabinet to one side (yaw increased)")
        shot("02-rotated-right")

        // 03 — rotate LEFT: tap yaw- past centre, prove yaw is now well below 02.
        let yawMinus = app.buttons["dbg.yawMinus"]
        XCTAssertTrue(yawMinus.exists, "Yaw - button should exist")
        for _ in 0..<10 { yawMinus.tap() }
        settleRender()
        let leftYaw = yaw(from: readout)
        XCTAssertLessThan(leftYaw, rightYaw,
                          "Tapping Yaw - must orbit the other way (yaw decreased from the right pose)")
        shot("03-rotated-left")

        // 04 — tilt: nudge pitch up then settle, prove the readout changed again.
        let before04 = readout.label
        let pitchPlus = app.buttons["dbg.pitchPlus"]
        let pitchMinus = app.buttons["dbg.pitchMinus"]
        XCTAssertTrue(pitchPlus.exists && pitchMinus.exists, "Pitch +/- buttons should exist")
        for _ in 0..<3 { pitchPlus.tap() }
        pitchMinus.tap()
        settleRender()
        XCTAssertNotEqual(before04, readout.label,
                          "Tapping Pitch +/- must change the readout (pitch orient pipeline live)")
        shot("04-tilted")

        // 05 — open detail: dbg.openFirst drives the SAME onSelect a niche tap
        // calls → CabinetView.handleSelect → ReleaseDetailView push.
        let openFirst = app.buttons["dbg.openFirst"]
        XCTAssertTrue(openFirst.exists, "Open-first button should exist")
        openFirst.tap()

        // Prove the route fired: the Release detail's "Model | Real Car" segmented
        // control appears and a nav back button is present (we pushed a screen).
        let modelSegment = app.buttons["Model"]
        let realCarSegment = app.buttons["Real Car"]
        XCTAssertTrue(modelSegment.waitForExistence(timeout: 6),
                      "Open-first must push ReleaseDetailView (Model segment visible) — route pipeline live")
        XCTAssertTrue(realCarSegment.exists,
                      "ReleaseDetailView should show the Real Car segment too")
        let backButton = app.navigationBars.buttons.element(boundBy: 0)
        XCTAssertTrue(backButton.exists, "A nav back button should exist after the detail pushed")
        settleRender()
        shot("05-detail-open")
    }

    /// HONEST-LIMIT evidence: attempt a REAL XCUITest coordinate drag across the
    /// cabinet and a coordinate tap on a niche, with before/after screenshots and
    /// a readout check. Expected outcome: NOTHING moves and no detail opens —
    /// synthetic input does not reach RealityKit's hit-test layer. This proves the
    /// harness shots are the best obtainable on this host; real-touch gesture
    /// recognition must be verified on a physical device / TestFlight.
    func testRealCoordinateInputDoesNotReachCabinet() {
        let app = launchCabinetDebug()

        let readout = app.staticTexts["dbg.readout"]
        XCTAssertTrue(readout.waitForExistence(timeout: 12), "Debug readout should exist")
        settleRender()
        let yawBefore = yaw(from: readout)
        shot("06-coord-before")

        // Real coordinate drag straight across the middle of the cabinet.
        let mid = app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
        let right = app.coordinate(withNormalizedOffset: CGVector(dx: 0.92, dy: 0.45))
        mid.press(forDuration: 0.15, thenDragTo: right)
        settleRender()
        let yawAfterDrag = yaw(from: readout)

        // Real coordinate tap on a niche-ish point of the cabinet.
        app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4)).tap()
        settleRender()
        shot("07-coord-after")

        // We do NOT fail the test on the (expected) no-op — we record the fact.
        // The detail page must NOT have appeared from the synthetic tap.
        let detailAppeared = app.buttons["Real Car"].exists
        let yawMoved = abs(yawAfterDrag - yawBefore) > 0.001

        // A debug annotation surfaced in the test log + result bundle for the PM.
        let verdict = XCTAttachment(string:
            """
            REAL COORDINATE INPUT PROBE
            yaw before drag : \(yawBefore)
            yaw after drag  : \(yawAfterDrag)  (moved: \(yawMoved))
            detail opened from synthetic tap: \(detailAppeared)
            EXPECTED: no movement, no detail — synthetic touch does not reach the
            RealityKit hit-test/gesture layer on this host.
            """)
        verdict.name = "coord-probe-verdict"
        verdict.lifetime = .keepAlways
        add(verdict)

        // Assert the EXPECTED limitation so the run is green and documents it:
        // synthetic input is a no-op against the 3D gesture layer.
        XCTAssertFalse(yawMoved,
                       "Documented limit: a real XCUITest coordinate drag should NOT orbit the RealityKit cabinet")
        XCTAssertFalse(detailAppeared,
                       "Documented limit: a real XCUITest coordinate tap should NOT open the niche detail")
    }
}
