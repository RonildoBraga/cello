import XCTest

final class EchoPracticeUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testLegacyEchoArchiveKeepsItsFrozenStarsAndPitchChart() throws {
        try requireRecordingFixtures()
        let app = XCUIApplication.cello()
        app.launch()
        app.tabBars.buttons["Recordings"].tap()
        let recording = app.descendants(matching: .any)["recording-EC000000-0000-4000-8000-000000000002"]
        guard recording.waitForExistence(timeout: 5) else {
            throw XCTSkip("Requires an externally seeded version-one low-voice G2/A2 Echo take with its original zero-star rating")
        }
        reveal(recording, in: app)
        recording.tap()
        XCTAssertTrue(app.navigationBars["Your session"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["Listen & Echo · Two notes"].exists)
        let stars = app.staticTexts["melodyRatingStars"]
        reveal(stars, in: app)
        XCTAssertEqual(stars.label, "0 of 3 stars", "A grading update must not silently rewrite the stored assessment")
        let chart = app.descendants(matching: .any).matching(identifier: "melodyPitchChart").firstMatch
        reveal(chart, in: app)
        XCTAssertTrue(chart.isHittable)
        XCTAssertTrue(chart.label.contains("saved audio assessment"))
        XCTAssertTrue(chart.label.contains("recorded octave"))
        let chartImage = XCTAttachment(screenshot: chart.screenshot())
        chartImage.name = "Listen and Echo · original saved version-one pitch chart"
        chartImage.lifetime = .keepAlways
        add(chartImage)
    }

    func testArchivedEchoResultAndVoiceSpecificProgressUseSavedPattern() throws {
        try requireRecordingFixtures()
        let app = XCUIApplication.cello()
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

        openEcho(in: app)
        let progress = app.staticTexts["practiceProgressText"]
        XCTAssertTrue(progress.label.contains("0 of 3"), "Higher-voice evidence must not credit the low voice")
        XCTAssertFalse(app.buttons["echoNextLevelButton"].exists, "One success is not a completed level")
        assertRecordNeedsHear(in: app)
        assertNoTargetHints(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        screenshot("Listen and Echo · saved higher-voice progress without target hints")
    }

    func testEchoLevelsAndVoiceRegistersHaveNoTargetHintsOrRecordingPermission() {
        let app = XCUIApplication.cello()
        app.launch()
        let summary = firstLevelSummary(in: app)
        XCTAssertTrue(summary.contains("of 6 lessons done"))
        openEcho(in: app)
        let duration = app.staticTexts["echoDuration"]
        let levels = app.segmentedControls["echoLevelPicker"]
        XCTAssertTrue(levels.buttons["Two notes"].isSelected)
        XCTAssertFalse(app.segmentedControls["echoRegisterPicker"].exists, "Echo uses one voice")
        XCTAssertTrue(app.staticTexts["Hear the pattern, then hum it back. Follow the tuning bar as you record."].exists)
        XCTAssertTrue(duration.label.contains("4 seconds") && duration.label.contains("60 BPM"))
        assertRecordNeedsHear(in: app)
        assertNoTargetHints(in: app)
        screenshot("Listen and Echo · two-note practice without target hints")

        levels.buttons["Three notes"].tap()
        XCTAssertTrue(duration.label.contains("6 seconds"))
        assertRecordNeedsHear(in: app)
        assertNoTargetHints(in: app)
        levels.buttons["Two notes"].tap()
        XCTAssertTrue(duration.label.contains("4 seconds"))
        assertRecordNeedsHear(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        app.navigationBars["Listen & Echo"].buttons.firstMatch.tap()
        XCTAssertEqual(firstLevelSummary(in: app), summary, "Opening Echo without a take earns no lesson")
        for id in ["steadyHum", "matchHum"] { XCTAssertTrue(app.pathRow("lesson-\(id)").isEnabled) }
    }

    func testFullManualHearUnlocksRecordButCancelAndNewSelectionsDoNot() {
        let app = XCUIApplication.cello()
        app.launch()
        openEcho(in: app)
        let record = app.buttons["practiceRecordButton"]
        let hear = app.buttons["previewTargetButton"]
        let newPattern = app.buttons["echoNewPatternButton"]
        let levels = app.segmentedControls["echoLevelPicker"]
        assertRecordNeedsHear(in: app)
        hear.tap()
        waitForRecord(label: "Cancel", enabled: true, in: app)
        XCTAssertFalse(newPattern.isEnabled)
        XCTAssertFalse(levels.buttons["Three notes"].isEnabled)
        record.tap()
        assertRecordNeedsHear(in: app)

        hearFullPattern(in: app, duration: 4)
        assertNoTargetHints(in: app)
        newPattern.tap()
        assertRecordNeedsHear(in: app)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists)
        hearFullPattern(in: app, duration: 4)
        levels.buttons["Three notes"].tap()
        XCTAssertTrue(app.staticTexts["echoDuration"].label.contains("6 seconds"))
        assertRecordNeedsHear(in: app)
        assertNoTargetHints(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testEchoRecordDoesNotAutoplayOrInventFeedbackWhenCaptureIsUnavailable() {
        let app = XCUIApplication.cello()
        app.launch()
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
        XCTAssertTrue(message.waitForExistence(timeout: 20), "A Simulator without a camera should explain the capture failure")
        XCTAssertTrue(message.label.localizedCaseInsensitiveContains("camera")
                      || message.label.localizedCaseInsensitiveContains("microphone"))
        waitForRecordLabel("Record", in: app)
        XCTAssertTrue(app.buttons["previewTargetButton"].isEnabled)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists)
        XCTAssertFalse(app.staticTexts["melodyRatingUnclear"].exists)
        XCTAssertFalse(app.staticTexts["LISTEN"].exists, "Record must never replay the reference")
        assertNoTargetHints(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        screenshot("Listen and Echo · unavailable capture without fabricated feedback")
    }

    func testInterruptedHearNeverUnlocksRecordOrChangesFoundationHistory() {
        let app = XCUIApplication.cello()
        app.launch()
        openSteadyHumPractice(in: app)
        XCTAssertTrue(app.buttons["previewTargetButton"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.staticTexts["practiceProgressText"].waitForExistence(timeout: 5))
        let foundationTarget = app.buttons["previewTargetButton"].label
        let foundationProgress = app.staticTexts["practiceProgressText"].label
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        let recordingIDs = visibleRecordingIDs(in: app)
        let summary = firstLevelSummary(in: app)
        openEcho(in: app)
        let echoProgress = app.staticTexts["practiceProgressText"].label
        let hear = app.buttons["previewTargetButton"]

        hear.tap()
        waitForRecord(label: "Cancel", enabled: true, in: app)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
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
        XCTAssertEqual(firstLevelSummary(in: app), summary)
        openEcho(in: app)
        assertRecordNeedsHear(in: app)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, echoProgress)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists)
        assertNoTargetHints(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        openSteadyHumPractice(in: app)
        waitForRecord(label: "Record", enabled: true, in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, foundationTarget)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, foundationProgress)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        XCTAssertEqual(visibleRecordingIDs(in: app), recordingIDs)
    }

    /// From anywhere, opens Steady hum's practice screen.
    private func openSteadyHumPractice(in app: XCUIApplication) {
        app.pathLesson("lesson-steadyHum").tap()
        let start = app.buttons["startLessonButton"]
        XCTAssertTrue(start.waitForExistence(timeout: 5))
        start.tap()
        XCTAssertTrue(app.staticTexts["practiceLessonTitle"].waitForExistence(timeout: 5))
    }

    /// Level 1's spoken summary on the path, including its count of finished lessons.
    private func firstLevelSummary(in app: XCUIApplication) -> String {
        app.returnToPath()
        return app.buttons["level-firstSounds"].label
    }

    private func openEcho(in app: XCUIApplication) {
        app.pathLesson("echoPracticeLink").tap()
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
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "echoLiveTuner").firstMatch.exists,
                       "The live guide appears when capture starts, not while hearing or preparing")
        XCTAssertFalse(app.staticTexts["livePitchCents"].exists)
        XCTAssertFalse(app.staticTexts["currentTargetLabel"].exists)
        XCTAssertFalse(app.staticTexts["LIVE TUNER"].exists)
        XCTAssertFalse(app.staticTexts["Live tuner"].exists)
        XCTAssertFalse(app.staticTexts["Camera preview"].exists)
        XCTAssertFalse(app.buttons["Switch camera"].exists)
        let notes = app.staticTexts.matching(NSPredicate(format: "label MATCHES %@", "^[A-G][♯♭#]?[0-9]$"))
        XCTAssertEqual(notes.count, 0, "Reference note hints remain hidden before recording")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "echoPracticeStatus").firstMatch.exists)
    }
}
