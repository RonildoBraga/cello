import XCTest

final class CelloIntroUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testIntroductionShowsPartsAndReturnsToFourUnchangedPlayingLessons() {
        let app = XCUIApplication()
        app.launch()
        openCelloFoundation(in: app)
        let summary = app.staticTexts["foundationCompletionSummary"].label
        XCTAssertTrue(summary.contains("of 4 lessons completed"))
        openIntroduction(in: app)

        let diagram = app.descendants(matching: .any).matching(identifier: "celloPartsDiagram").firstMatch
        reveal(diagram, in: app)
        XCTAssertGreaterThan(diagram.frame.width, 200)
        XCTAssertGreaterThan(diagram.frame.height, 300)
        for part in ["Scroll", "Pegs", "Fingerboard", "Strings", "Bridge", "f-holes", "Tailpiece", "Endpin"] {
            XCTAssertTrue(diagram.label.localizedCaseInsensitiveContains(part), "The diagram should identify \(part)")
        }
        assertIntroductionHasNoRecordingOrRating(in: app)
        assertNoWrittenInputOrPermissionAlerts(in: app)
        screenshot("Meet your cello · labelled front-view diagram")

        let nextSteps = app.descendants(matching: .any).matching(identifier: "celloIntroNextSteps").firstMatch
        reveal(nextSteps, in: app)
        app.scrollViews.firstMatch.swipeUp()
        let browse = app.buttons["celloIntroBrowseLessons"]
        XCTAssertTrue(browse.isHittable && browse.isEnabled)
        screenshot("Meet your cello · next steps before playing")
        browse.tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["foundationCompletionSummary"].label, summary,
                       "Reading an introduction must not award a playing achievement")
        for lesson in ["openC", "openG", "openD", "openA"] {
            let row = app.buttons["lesson-\(lesson)"]
            reveal(row, in: app)
            XCTAssertTrue(row.isEnabled)
        }
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists, "Browsing lessons must not start capture")
        assertNoWrittenInputOrPermissionAlerts(in: app)
    }

    func testFourStringReferencesPlayManuallyWithoutCaptureOrProgress() {
        let app = XCUIApplication()
        app.launch()
        openCelloFoundation(in: app)
        let summary = app.staticTexts["foundationCompletionSummary"].label
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
        assertNoWrittenInputOrPermissionAlerts(in: app)
        app.buttons["celloIntroBrowseLessons"].tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["foundationCompletionSummary"].label, summary,
                       "Hearing references must not earn performance stars or completion")
    }

    func testReferenceStopsOnTabBackgroundAndBackWithoutSavingHistory() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        let recordingIDs = visibleRecordingIDs(in: app)
        openCelloFoundation(in: app)
        let summary = app.staticTexts["foundationCompletionSummary"].label
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
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["foundationCompletionSummary"].label, summary)
        openIntroduction(in: app)
        XCTAssertFalse(status.exists, "Back navigation must stop playback without autoplay on return")
        assertIntroductionHasNoRecordingOrRating(in: app)
        assertNoWrittenInputOrPermissionAlerts(in: app)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        XCTAssertEqual(visibleRecordingIDs(in: app), recordingIDs,
                       "Listening and cancellation must not create learner recordings")
    }

    private func openCelloFoundation(in app: XCUIApplication) {
        app.tabBars.buttons["Music"].tap()
        let cello = app.buttons["foundation-cello"]
        reveal(cello, in: app)
        cello.tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
    }

    private func openIntroduction(in app: XCUIApplication) {
        let introduction = app.buttons["celloIntroductionLink"]
        for _ in 0..<6 {
            if introduction.exists && introduction.isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(introduction.isHittable)
        introduction.tap()
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

    private func assertNoWrittenInputOrPermissionAlerts(in app: XCUIApplication) {
        XCTAssertEqual(app.textFields.count, 0)
        XCTAssertEqual(app.textViews.count, 0)
        XCTAssertEqual(app.secureTextFields.count, 0)
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count, 0)
    }

    private func visibleRecordingIDs(in app: XCUIApplication) -> Set<String> {
        let recordings = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "recording-"))
        return Set(recordings.allElementsBoundByIndex.map(\.identifier))
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
