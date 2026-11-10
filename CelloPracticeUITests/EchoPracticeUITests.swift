import XCTest

final class EchoPracticeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testArchivedEchoResultAndVoiceSpecificProgressUseSavedPattern() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        // Optional external setup: root copies a real production-rated Echo movie
        // and its frozen metadata, normalizing only the reserved session ID.
        let recording = app.descendants(matching: .any)["recording-EC000000-0000-4000-8000-000000000001"]
        guard recording.waitForExistence(timeout: 5) else {
            throw XCTSkip("Requires the externally seeded production-rated higher-voice Echo fixture EC000000...001")
        }
        reveal(recording, in: app)
        recording.tap()
        XCTAssertTrue(app.navigationBars["Your session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Listen & Echo · Two notes"].exists)
        let stars = app.staticTexts["melodyRatingStars"]
        reveal(stars, in: app)
        XCTAssertEqual(stars.label, "3 of 3 stars")
        for id in ["melodyGoal-notes", "melodyGoal-timing", "melodyGoal-clarity"] {
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: id).firstMatch.label.contains("goal reached"))
        }
        XCTAssertEqual(app.staticTexts["melodyFeedback"].label, "All three goals reached. Try a fresh pattern.")
        screenshot("Listen and Echo · archived production-rated three-star result")
        let chart = app.descendants(matching: .any).matching(identifier: "melodyPitchChart").firstMatch
        reveal(chart, in: app)
        XCTAssertTrue(chart.isHittable)
        for phrase in ["Reference phrase", "clear saved pitch observations", "recorded octave", "saved audio assessment"] {
            XCTAssertTrue(chart.label.contains(phrase), "The chart must describe the saved reference and actual audio observations")
        }
        screenshot("Listen and Echo · saved two-note reference and recorded pitch chart")

        openHummingFoundation(in: app)
        openEcho(in: app)
        let progress = app.staticTexts["practiceProgressText"]
        XCTAssertTrue(progress.label.contains("0 of 3"), "Higher-voice evidence must not credit the low voice")
        app.segmentedControls["echoRegisterPicker"].buttons["Higher voice"].tap()
        XCTAssertTrue(progress.label.contains("1 of 3"), "The actual rated recording contributes one success in its voice register")
        XCTAssertFalse(app.buttons["echoNextLevelButton"].exists, "One success is not a completed level")
        assertRecordNeedsHear(in: app)
        assertNoTargetHints(in: app)
        assertNoWrittenInputOrPermissionAlerts(in: app)
        screenshot("Listen and Echo · saved higher-voice progress without target hints")
    }

    func testEchoLevelsAndVoiceRegistersHaveNoTargetHintsOrRecordingPermission() {
        let app = XCUIApplication()
        app.launch()
        openHummingFoundation(in: app)
        let summary = app.staticTexts["foundationCompletionSummary"].label
        XCTAssertTrue(summary.contains("of 2 lessons completed"))
        openEcho(in: app)
        let duration = app.staticTexts["echoDuration"]
        let levels = app.segmentedControls["echoLevelPicker"]
        let registers = app.segmentedControls["echoRegisterPicker"]
        XCTAssertTrue(levels.buttons["Two notes"].isSelected)
        XCTAssertTrue(registers.buttons["Low voice"].isSelected)
        XCTAssertTrue(duration.label.contains("4 seconds") && duration.label.contains("60 BPM"))
        assertRecordNeedsHear(in: app)
        assertNoTargetHints(in: app)
        screenshot("Listen and Echo · two-note practice without target hints")

        levels.buttons["Three notes"].tap()
        XCTAssertTrue(duration.label.contains("6 seconds"))
        assertRecordNeedsHear(in: app)
        registers.buttons["Higher voice"].tap()
        XCTAssertTrue(registers.buttons["Higher voice"].isSelected)
        assertRecordNeedsHear(in: app)
        assertNoTargetHints(in: app)
        levels.buttons["Two notes"].tap()
        XCTAssertTrue(duration.label.contains("4 seconds"))
        assertRecordNeedsHear(in: app)
        assertNoWrittenInputOrPermissionAlerts(in: app)
        app.navigationBars["Listen & Echo"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["foundationCompletionSummary"].label, summary)
        for id in ["steadyHum", "matchHum"] { XCTAssertTrue(app.buttons["lesson-\(id)"].exists) }
    }

    func testFullManualHearUnlocksRecordButCancelAndNewSelectionsDoNot() {
        let app = XCUIApplication()
        app.launch()
        openHummingFoundation(in: app)
        openEcho(in: app)
        let record = app.buttons["practiceRecordButton"]
        let hear = app.buttons["previewTargetButton"]
        let newPattern = app.buttons["echoNewPatternButton"]
        let registers = app.segmentedControls["echoRegisterPicker"]
        let levels = app.segmentedControls["echoLevelPicker"]
        assertRecordNeedsHear(in: app)
        hear.tap()
        waitForRecord(label: "Cancel", enabled: true, in: app)
        XCTAssertFalse(newPattern.isEnabled)
        XCTAssertFalse(registers.buttons["Higher voice"].isEnabled)
        XCTAssertFalse(levels.buttons["Three notes"].isEnabled)
        record.tap()
        assertRecordNeedsHear(in: app)

        hearFullPattern(in: app, duration: 4)
        assertNoTargetHints(in: app)
        newPattern.tap()
        assertRecordNeedsHear(in: app)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists)
        hearFullPattern(in: app, duration: 4)
        registers.buttons["Higher voice"].tap()
        assertRecordNeedsHear(in: app)
        hearFullPattern(in: app, duration: 4)
        levels.buttons["Three notes"].tap()
        XCTAssertTrue(app.staticTexts["echoDuration"].label.contains("6 seconds"))
        assertRecordNeedsHear(in: app)
        assertNoTargetHints(in: app)
        assertNoWrittenInputOrPermissionAlerts(in: app)
    }

    func testEchoRecordDoesNotAutoplayOrInventFeedbackWhenCaptureIsUnavailable() {
        let app = XCUIApplication()
        app.launch()
        openHummingFoundation(in: app)
        openEcho(in: app)
        hearFullPattern(in: app, duration: 4)
        app.buttons["practiceRecordButton"].tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<2 {
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 1) {
                let allow = alert.buttons.matching(NSPredicate(format: "label == 'Allow' OR label == 'OK'")).firstMatch
                XCTAssertTrue(allow.exists)
                allow.tap()
            }
        }
        let message = app.staticTexts["captureMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 8), "A Simulator without a camera should explain the capture failure")
        XCTAssertTrue(message.label.localizedCaseInsensitiveContains("camera")
                      || message.label.localizedCaseInsensitiveContains("microphone"))
        waitForRecordLabel("Record", in: app)
        XCTAssertTrue(app.buttons["previewTargetButton"].isEnabled)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists)
        XCTAssertFalse(app.staticTexts["melodyRatingUnclear"].exists)
        XCTAssertFalse(app.staticTexts["LISTEN"].exists, "Record must never replay the reference")
        assertNoTargetHints(in: app)
        assertNoWrittenInputOrPermissionAlerts(in: app)
        screenshot("Listen and Echo · unavailable capture without fabricated feedback")
    }

    func testInterruptedHearNeverUnlocksRecordOrChangesFoundationHistory() {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Practice"].tap()
        XCTAssertTrue(app.staticTexts["currentTargetLabel"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["practiceProgressText"].waitForExistence(timeout: 5))
        let foundationTarget = app.staticTexts["currentTargetLabel"].label
        let foundationProgress = app.staticTexts["practiceProgressText"].label
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        let recordingIDs = visibleRecordingIDs(in: app)
        openHummingFoundation(in: app)
        let summary = app.staticTexts["foundationCompletionSummary"].label
        openEcho(in: app)
        let echoProgress = app.staticTexts["practiceProgressText"].label
        let hear = app.buttons["previewTargetButton"]

        hear.tap()
        waitForRecord(label: "Cancel", enabled: true, in: app)
        app.tabBars.buttons["Practice"].tap()
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        waitForRecord(label: "Record", enabled: true, in: app)
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, foundationTarget)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, foundationProgress)
        app.tabBars.buttons["Music"].tap()
        XCTAssertTrue(app.navigationBars["Listen & Echo"].waitForExistence(timeout: 5))
        assertRecordNeedsHear(in: app)

        hear.tap()
        waitForRecord(label: "Cancel", enabled: true, in: app)
        XCUIDevice.shared.press(.home)
        app.activate()
        assertRecordNeedsHear(in: app)
        hear.tap()
        waitForRecord(label: "Cancel", enabled: true, in: app)
        app.navigationBars["Listen & Echo"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["foundationCompletionSummary"].label, summary)
        openEcho(in: app)
        assertRecordNeedsHear(in: app)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, echoProgress)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists)
        assertNoTargetHints(in: app)
        assertNoWrittenInputOrPermissionAlerts(in: app)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        XCTAssertEqual(visibleRecordingIDs(in: app), recordingIDs)
    }

    private func openHummingFoundation(in app: XCUIApplication) {
        app.tabBars.buttons["Music"].tap()
        let humming = app.buttons["foundation-humming"]
        reveal(humming, in: app)
        humming.tap()
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
    }

    private func openEcho(in app: XCUIApplication) {
        let echo = app.buttons["echoPracticeLink"]
        reveal(echo, in: app)
        echo.tap()
        XCTAssertTrue(app.navigationBars["Listen & Echo"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "echoPracticeCard").firstMatch.exists)
        assertRecordNeedsHear(in: app)
    }

    private func hearFullPattern(in app: XCUIApplication, duration: TimeInterval) {
        let hear = app.buttons["previewTargetButton"]
        reveal(hear, in: app)
        let startedAt = ProcessInfo.processInfo.systemUptime
        hear.tap()
        waitForRecord(label: "Cancel", enabled: true, in: app)
        assertNoTargetHints(in: app)
        screenshot("Listen and Echo · hearing the pattern without pitch clues")
        waitForRecord(label: "Record", enabled: true, in: app, timeout: duration + 3)
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - startedAt, duration - 0.2,
                                    "The complete reference is heard before recording is enabled")
    }

    private func assertRecordNeedsHear(in app: XCUIApplication) {
        waitForRecord(label: "Record", enabled: false, in: app)
        let hear = app.buttons["previewTargetButton"]
        XCTAssertTrue(hear.isEnabled)
        XCTAssertTrue(hear.label.localizedCaseInsensitiveContains("Hear pattern"))
    }

    private func waitForRecord(label: String, enabled: Bool, in app: XCUIApplication, timeout: TimeInterval = 5) {
        let expectation = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ AND enabled == %@", label, NSNumber(value: enabled)),
            object: app.buttons["practiceRecordButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: timeout), .completed)
    }

    private func waitForRecordLabel(_ label: String, in app: XCUIApplication) {
        let expectation = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", label),
                                                   object: app.buttons["practiceRecordButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [expectation], timeout: 5), .completed)
    }

    private func assertNoTargetHints(in app: XCUIApplication) {
        XCTAssertFalse(app.staticTexts["currentTargetLabel"].exists)
        XCTAssertFalse(app.staticTexts["LIVE TUNER"].exists)
        XCTAssertFalse(app.staticTexts["Live tuner"].exists)
        XCTAssertFalse(app.staticTexts["Camera preview"].exists)
        XCTAssertFalse(app.buttons["Switch camera"].exists)
        let notes = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[A-G][♯♭#]?[0-9]$"))
        XCTAssertEqual(notes.count, 0, "Actual reference notes remain hidden before the result")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "echoPracticeStatus").firstMatch.exists)
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
