import XCTest

final class CelloIntroUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testIntroductionShowsPartsAndReturnsToFourUnchangedPlayingLessons() {
        let app = XCUIApplication.cello()
        app.launch()
        let summary = celloLessonSummary(in: app)
        openIntroduction(in: app)

        let diagram = app.descendants(matching: .any).matching(identifier: "celloPartsDiagram").firstMatch
        reveal(diagram, in: app)
        XCTAssertGreaterThan(diagram.frame.width, 200)
        XCTAssertGreaterThan(diagram.frame.height, 300)
        for part in ["Scroll", "Pegs", "Fingerboard", "Strings", "Bridge", "f-holes", "Tailpiece", "Endpin"] {
            XCTAssertTrue(diagram.label.localizedCaseInsensitiveContains(part), "The diagram should identify \(part)")
        }
        assertIntroductionHasNoRecordingOrRating(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        screenshot("Meet your cello · labelled front-view diagram")

        let nextSteps = app.descendants(matching: .any).matching(identifier: "celloIntroNextSteps").firstMatch
        reveal(nextSteps, in: app)
        app.scrollViews.firstMatch.swipeUp()
        let browse = app.buttons["celloIntroBrowseLessons"]
        XCTAssertTrue(browse.isHittable && browse.isEnabled)
        screenshot("Meet your cello · next lessons before playing")
        browse.tap()
        // The introduction leads back to the four open strings of the lesson it was opened from.
        XCTAssertTrue(app.staticTexts["practiceLessonTitle"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["previewTargetButton"].label.hasPrefix("Open C string"))
        for string in ["G", "D", "A"] { XCTAssertTrue(app.buttons["part-Open \(string) string"].exists) }
        XCTAssertEqual(celloLessonSummary(in: app), summary,
                       "Reading an introduction must not award a playing achievement")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testFourStringReferencesPlayManuallyWithoutCaptureOrProgress() {
        let app = XCUIApplication.cello()
        app.launch()
        let summary = celloLessonSummary(in: app)
        openIntroduction(in: app)
        let status = app.descendants(matching: .any).matching(identifier: "celloIntroPlaybackStatus").firstMatch
        XCTAssertFalse(status.exists, "Opening the introduction must be silent")
        let references = [("openC", "C2"), ("openG", "G2"), ("openD", "D3"), ("openA", "A3")]
        for (index, reference) in references.enumerated() {
            let hear = app.buttons["celloIntroHear-\(reference.0)"]
            reveal(hear, in: app)
            waitForHear(hear)
            hear.tap()
            // The note lasts two seconds. Go straight to the status line: waiting for
            // the button to read Stop first can use up the time the status is visible.
            XCTAssertTrue(status.waitForExistence(timeout: 3))
            XCTAssertTrue(status.label.contains(reference.1), "Playback should identify the selected string pitch")
            if index == 0 {
                XCTAssertFalse(app.buttons["celloIntroHear-openG"].isEnabled,
                               "Another string cannot replace the current reference unexpectedly")
                hear.tap()
            }
            waitForHear(hear)
            XCTAssertFalse(status.exists)
            assertIntroductionHasNoRecordingOrRating(in: app)
        }
        screenshot("Meet your cello · four recorded string references")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        app.buttons["celloIntroBrowseLessons"].tap()
        XCTAssertEqual(celloLessonSummary(in: app), summary,
                       "Hearing references must not earn performance stars or completion")
    }

    func testReferenceStopsOnTabBackgroundAndBackWithoutSavingHistory() {
        let app = XCUIApplication.cello()
        app.launch()
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        let recordingIDs = visibleRecordingIDs(in: app)
        let summary = celloLessonSummary(in: app)
        openIntroduction(in: app)
        let status = app.descendants(matching: .any).matching(identifier: "celloIntroPlaybackStatus").firstMatch

        let g = app.buttons["celloIntroHear-openG"]
        reveal(g, in: app)
        g.tap()
        waitForStop(g)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Music"].tap()
        XCTAssertTrue(app.navigationBars["Meet your cello"].waitForExistence(timeout: 5))
        waitForHear(g)
        XCTAssertFalse(status.exists, "Returning to the introduction must not resume the reference")

        let d = app.buttons["celloIntroHear-openD"]
        reveal(d, in: app)
        d.tap()
        waitForStop(d)
        XCUIDevice.shared.press(.home)
        app.activate()
        waitForHear(d)
        XCTAssertFalse(status.exists, "Backgrounding must stop the reference")

        let a = app.buttons["celloIntroHear-openA"]
        reveal(a, in: app)
        a.tap()
        waitForStop(a)
        app.navigationBars["Meet your cello"].buttons.firstMatch.tap()
        XCTAssertEqual(celloLessonSummary(in: app), summary)
        openIntroduction(in: app)
        XCTAssertFalse(status.exists, "Back navigation must stop playback without autoplay on return")
        assertIntroductionHasNoRecordingOrRating(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        XCTAssertEqual(visibleRecordingIDs(in: app), recordingIDs,
                       "Listening and cancellation must not create learner recordings")
    }

    /// What the path says about the lesson the open strings belong to: status and best score.
    private func celloLessonSummary(in app: XCUIApplication) -> String {
        app.pathRow("lesson-steadyHum").label
    }

    /// The introduction is opened from the cello's side of Steady note.
    private func openIntroduction(in app: XCUIApplication) {
        app.pathLesson("lesson-steadyHum").tap()
        let start = app.buttons["startLessonButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        let cello = app.buttons["part-Cello"]
        XCTAssertTrue(cello.waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["celloIntroductionLink"].exists, "The voice has no instrument to meet")
        cello.tap()
        let link = app.buttons["celloIntroductionLink"]
        XCTAssertTrue(link.waitForExistence(timeout: 5))
        link.tap()
        XCTAssertTrue(app.navigationBars["Meet your cello"].waitForExistence(timeout: 5))
    }

    private func waitForHear(_ button: XCUIElement) {
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@ AND enabled == true", "Hear"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 5), .completed)
    }

    private func waitForStop(_ button: XCUIElement) {
        let playing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label BEGINSWITH %@ AND enabled == true", "Stop"), object: button)
        XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 3), .completed)
    }

    private func assertIntroductionHasNoRecordingOrRating(in app: XCUIApplication) {
        for id in ["practiceRecordButton", "ratingStarCount", "melodyRatingStars", "melodyRhythmStars", "practiceProgressText"] {
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: id).firstMatch.exists)
        }
    }
}
