import XCTest

final class LearningUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testArchivedProductionRatingAndCompletedProgressSurviveRelaunch() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Recordings"].tap()
        // Optional visual integration setup: copy the three public-hum movie
        // sessions produced by the real SessionStore/RecordingRater integration
        // test into this Simulator's PracticeSessions directory, normalizing only
        // their session IDs to the stable values below, before the run.
        // Also seed the newer real one-star DF...001 session so best and latest
        // scores are verified independently. This test never fabricates grades
        // or enables an app-only fixture mode.
        let fixtureIDs = [
            "DE000000-0000-4000-8000-000000000001",
            "DE000000-0000-4000-8000-000000000002",
            "DE000000-0000-4000-8000-000000000003"
        ]
        let rows = fixtureIDs.map { app.descendants(matching: .any)["recording-\($0)"] }
        let latestPartial = app.descendants(matching: .any)["recording-DF000000-0000-4000-8000-000000000001"]
        guard rows[0].waitForExistence(timeout: 5), rows.allSatisfy(\.exists), latestPartial.exists else {
            throw XCTSkip("Requires three production-rated Steady hum successes and the newer real one-star session")
        }
        rows[0].tap()
        let count = app.staticTexts["ratingStarCount"]
        reveal(count, in: app)
        XCTAssertEqual(count.label, "3 of 3 stars")
        XCTAssertTrue(app.descendants(matching: .any)["archivedRatingCard"].exists)
        for identifier in ["ratingMatch", "ratingSteady", "ratingHold"] {
            let goal = app.descendants(matching: .any)[identifier]
            XCTAssertTrue(goal.exists)
            XCTAssertTrue(goal.label.contains("goal reached"))
        }
        XCTAssertTrue(app.staticTexts["ratingFeedback"].exists)
        assertNoWrittenInput(in: app)
        screenshot("Recording · production-rated three-star result")

        app.tabBars.buttons["Practice"].tap()
        let progress = app.staticTexts["practiceProgressText"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("Goal reached"), "Three rated successes should complete the Steady hum goal")
        XCTAssertTrue(app.buttons["nextExerciseButton"].isEnabled)
        screenshot("Humming · completed goal from three rated takes")
        let completed = progress.label
        app.terminate()
        app.launch()
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.label, completed, "Earned completion should remain after relaunch")

        openLessons(in: app)
        let lesson = app.buttons["lesson-steadyHum"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 5))
        XCTAssertTrue(lesson.label.contains("Completed"))
        XCTAssertTrue(lesson.label.contains("Best score 3 of 3 stars"),
                      "The library should summarize the saved production ratings")
        lesson.tap()
        XCTAssertTrue(app.staticTexts["lessonDetailTitle"].waitForExistence(timeout: 5))
        let best = app.descendants(matching: .any).matching(identifier: "lessonBestScore-steadyHum").firstMatch
        let latest = app.descendants(matching: .any).matching(identifier: "lessonLatestScore").firstMatch
        reveal(best, in: app)
        XCTAssertTrue(best.label.contains("3 of 3 stars"))
        XCTAssertTrue(latest.label.contains("1 of 3 stars"),
                      "The newer one-star take should be latest while the best score and earned completion remain intact")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "lessonCompletion-steadyHum").firstMatch.exists)
        screenshot("Lessons · earned completion and saved scores")
    }

    func testArchivedPartialAndUnclearRatingsRenderDistinctStates() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Recordings"].tap()
        // Optional design review setup: these Simulator-only fixture sessions
        // come from an actual one-star take and an actual production-rater
        // unclear result. Only their IDs are normalized; no grades are invented.
        let partial = app.descendants(matching: .any)["recording-DF000000-0000-4000-8000-000000000001"]
        let unclear = app.descendants(matching: .any)["recording-DF000000-0000-4000-8000-000000000002"]
        guard partial.waitForExistence(timeout: 5), unclear.exists else {
            throw XCTSkip("Requires externally seeded production-rated one-star and unclear design fixtures")
        }

        partial.tap()
        let count = app.staticTexts["ratingStarCount"]
        reveal(count, in: app)
        XCTAssertEqual(count.label, "1 of 3 stars")
        XCTAssertTrue(app.descendants(matching: .any)["archivedRatingCard"].exists)
        XCTAssertTrue(app.descendants(matching: .any)["ratingHold"].label.contains("goal reached"))
        for identifier in ["ratingMatch", "ratingSteady"] {
            XCTAssertTrue(app.descendants(matching: .any)[identifier].label.contains("keep practising"))
        }
        XCTAssertTrue(app.staticTexts["ratingFeedback"].exists)
        assertNoWrittenInput(in: app)
        screenshot("Recording · one-star Hold result")

        app.navigationBars["Your session"].buttons.firstMatch.tap()
        XCTAssertTrue(unclear.waitForExistence(timeout: 5))
        unclear.tap()
        let unscored = app.staticTexts["ratingUnclear"]
        reveal(unscored, in: app)
        XCTAssertTrue(unscored.exists)
        XCTAssertTrue(app.staticTexts["Progress unchanged"].exists)
        XCTAssertFalse(app.staticTexts["ratingStarCount"].exists, "An unclear take must not appear to receive a low star rating")
        for identifier in ["ratingMatch", "ratingSteady", "ratingHold"] {
            XCTAssertFalse(app.descendants(matching: .any)[identifier].exists)
        }
        XCTAssertTrue(app.staticTexts["ratingFeedback"].exists)
        assertNoWrittenInput(in: app)
        screenshot("Recording · unclear take without a grade")
    }

    func testArchivedTakeShowsPitchTraceWithoutChangingItsRatingOrPlayback() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Recordings"].tap()
        // Optional Simulator setup: copy an archived production-rated recording folder,
        // preserving its movie, observations and saved rating; normalize its metadata ID and folder name to the reserved fixture ID below.
        // The chart is verified against the genuine take, without a fixture mode.
        let recording = app.descendants(matching: .any)["recording-E1000000-0000-4000-8000-000000000001"]
        guard recording.waitForExistence(timeout: 5) else {
            throw XCTSkip("Requires the externally seeded one-star archived fixture E1000000-0000-4000-8000-000000000001")
        }
        recording.tap()
        XCTAssertTrue(app.navigationBars["Your session"].waitForExistence(timeout: 5))

        let rating = app.staticTexts["ratingStarCount"]
        reveal(rating, in: app)
        XCTAssertEqual(rating.label, "1 of 3 stars")
        XCTAssertTrue(app.descendants(matching: .any)["ratingHold"].label.contains("goal reached"))
        for identifier in ["ratingMatch", "ratingSteady"] {
            XCTAssertTrue(app.descendants(matching: .any)[identifier].label.contains("keep practising"))
        }

        let chart = app.descendants(matching: .any).matching(identifier: "pitchTraceChart").firstMatch
        reveal(chart, in: app)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "pitchTraceCard").firstMatch.exists)
        XCTAssertTrue(chart.isHittable, "The saved take should show its pitch observations")
        for text in ["Recorded pitch chart", "target", "above", "below"] {
            XCTAssertTrue(chart.label.contains(text), "The chart should explain the saved pitch relative to the target")
        }
        XCTAssertTrue(app.staticTexts["Your pitch"].exists)
        screenshot("Recording · real take pitch trace and target")

        let playback = app.descendants(matching: .any).matching(identifier: "sessionPlaybackPlayer").firstMatch
        reveal(playback, in: app)
        XCTAssertTrue(playback.isHittable, "Adding a pitch trace must keep the recorded video reachable")
        let share = app.buttons["Prepare session to share"]
        reveal(share, in: app)
        XCTAssertTrue(share.isEnabled, "The existing recording actions should remain accessible below the chart")
        for _ in 0..<8 {
            if playback.isHittable { break }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(playback.isHittable, "Playback should remain reachable when scrolling back from recording actions")
        assertNoWrittenInput(in: app)
        screenshot("Recording · playback remains accessible after pitch chart")
    }

    func testArchivedTakeShowsTwentyTwoPitchObservationsAndTwoStarLessonScores() throws {
        let app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Recordings"].tap()
        // Optional Simulator setup: use only these two archived production-rated fixtures,
        // with their actual saved ratings and a fresh practice-progress file.
        // Production-rating integration fixtures belong to separate UI tests.
        let recording = app.descendants(matching: .any)["recording-E1000000-0000-4000-8000-000000000002"]
        let previous = app.descendants(matching: .any)["recording-E1000000-0000-4000-8000-000000000001"]
        guard recording.waitForExistence(timeout: 5), previous.exists else {
            throw XCTSkip("Requires the two reserved archived fixtures E1000000...001 and E1000000...002")
        }
        let integrationFixtures = app.descendants(matching: .any).matching(
            NSPredicate(format: "identifier BEGINSWITH %@ OR identifier BEGINSWITH %@", "recording-DE000000", "recording-DF000000"))
        guard integrationFixtures.count == 0 else {
            throw XCTSkip("Requires the two archived fixtures without separate production-rating integration fixtures")
        }
        recording.tap()
        XCTAssertTrue(app.navigationBars["Your session"].waitForExistence(timeout: 5))

        let rating = app.staticTexts["ratingStarCount"]
        reveal(rating, in: app)
        XCTAssertEqual(rating.label, "2 of 3 stars")
        for identifier in ["ratingHold", "ratingSteady"] {
            XCTAssertTrue(app.descendants(matching: .any)[identifier].label.contains("goal reached"))
        }
        XCTAssertTrue(app.descendants(matching: .any)["ratingMatch"].label.contains("keep practising"))

        let chart = app.descendants(matching: .any).matching(identifier: "pitchTraceChart").firstMatch
        reveal(chart, in: app)
        XCTAssertTrue(chart.isHittable)
        XCTAssertTrue(chart.label.contains("22 observations"), "The pitch trace should use the new take’s actual saved observations")
        for text in ["target", "above", "below"] {
            XCTAssertTrue(chart.label.contains(text))
        }
        screenshot("Recording · newer two-star take with 22 pitch observations")

        app.tabBars.buttons["Practice"].tap()
        app.terminate()
        app.launch()
        let target = app.staticTexts["currentTargetLabel"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertTrue(target.label.contains("A2") && target.label.contains("110.6"))
        openLessons(in: app)
        let lesson = app.buttons["lesson-steadyHum"]
        XCTAssertTrue(lesson.waitForExistence(timeout: 5))
        XCTAssertTrue(lesson.label.contains("Best score 2 of 3 stars"))
        lesson.tap()
        XCTAssertTrue(app.staticTexts["lessonDetailTitle"].waitForExistence(timeout: 5))
        let best = app.descendants(matching: .any).matching(identifier: "lessonBestScore-steadyHum").firstMatch
        let latest = app.descendants(matching: .any).matching(identifier: "lessonLatestScore").firstMatch
        reveal(best, in: app)
        XCTAssertTrue(best.label.contains("2 of 3 stars"), "The best score should come from the actual newer take")
        XCTAssertTrue(latest.label.contains("2 of 3 stars"), "The latest saved score should survive relaunch")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "lessonCompletion-steadyHum").firstMatch.exists)
        assertNoWrittenInput(in: app)
        screenshot("Lessons · actual best and latest two-star take after relaunch")
    }

    func testHummingAndCelloKeepExercisesAndTargetsSeparate() {
        let app = XCUIApplication()
        app.launch()
        XCTAssertTrue(app.segmentedControls["practiceSectionPicker"].buttons["Humming"].isSelected)
        XCTAssertTrue(app.navigationBars["Humming"].exists)
        assertReadyToRecord(in: app)
        assertNoWrittenInput(in: app)
        let target = app.staticTexts["currentTargetLabel"]
        let hummingTarget = target.label
        XCTAssertTrue(hummingTarget.contains("A2") && hummingTarget.contains("110.6"))
        XCTAssertFalse(app.buttons["changeTarget"].exists)
        XCTAssertFalse(app.buttons["useHummingExampleNote"].exists)
        screenshot("Humming · one human reference")

        app.buttons["exercisePicker"].tap()
        XCTAssertTrue(app.buttons["Steady hum"].exists)
        XCTAssertTrue(app.buttons["Listen & match"].exists)
        XCTAssertTrue(app.buttons["Pulse"].exists)
        XCTAssertTrue(app.buttons["Two taps per beat"].exists)
        XCTAssertTrue(app.buttons["Mixed rhythm"].exists)
        assertCelloExercisesAbsent(in: app)
        XCTAssertFalse(app.buttons["Free recording"].exists)
        app.buttons["Steady hum"].tap()

        app.segmentedControls["practiceSectionPicker"].buttons["Cello"].tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        XCTAssertTrue(target.label.contains("G2") && target.label.contains("98.0"))
        XCTAssertFalse(app.buttons["Hear hum"].exists)
        XCTAssertTrue(app.buttons["hummingLearnButton"].exists, "Lessons must be available in the Cello section")
        assertReadyToRecord(in: app)
        assertNoWrittenInput(in: app)
        app.buttons["exercisePicker"].tap()
        for title in ["Open C string", "Open G string", "Open D string", "Open A string"] {
            XCTAssertTrue(app.buttons[title].exists)
        }
        XCTAssertFalse(app.buttons["Steady hum"].exists)
        XCTAssertFalse(app.buttons["Listen & match"].exists)
        XCTAssertFalse(app.buttons["Pulse"].exists)
        XCTAssertFalse(app.buttons["Two taps per beat"].exists)
        XCTAssertFalse(app.buttons["Mixed rhythm"].exists)
        XCTAssertFalse(app.buttons["Free recording"].exists)
        app.buttons["Open C string"].tap()
        XCTAssertTrue(target.label.contains("C2") && target.label.contains("65.4"))
        let celloTarget = target.label
        screenshot("Cello · separate C string target")

        app.segmentedControls["practiceSectionPicker"].buttons["Humming"].tap()
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, hummingTarget, "A cello string choice must not change the humming reference")
        app.buttons["exercisePicker"].tap()
        app.buttons["Listen & match"].tap()
        XCTAssertEqual(target.label, hummingTarget)
        XCTAssertTrue(app.buttons["exercisePicker"].label.contains("Listen & match"))
        assertReadyToRecord(in: app)

        app.segmentedControls["practiceSectionPicker"].buttons["Cello"].tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        XCTAssertEqual(target.label, celloTarget, "Humming activity changes must preserve the cello string selection")
        XCTAssertTrue(app.buttons["exercisePicker"].label.contains("Open C string"))
        app.segmentedControls["practiceSectionPicker"].buttons["Humming"].tap()
        XCTAssertEqual(target.label, hummingTarget)
        screenshot("Humming · unchanged after cello choices")
    }

    func testHumanHumPreviewWorksWithoutCaptureAndCancelsOnSectionSwitch() {
        let app = XCUIApplication()
        app.launch()
        assertReadyToRecord(in: app)
        app.buttons["exercisePicker"].tap()
        app.buttons["Listen & match"].tap()
        XCTAssertTrue(app.buttons["exercisePicker"].label.contains("Listen & match"))
        let target = app.staticTexts["currentTargetLabel"]
        let hummingTarget = target.label
        let hear = app.buttons["previewTargetButton"]
        XCTAssertTrue(hear.isHittable && hear.isEnabled)
        XCTAssertTrue(hear.label.contains("Hear hum"))
        XCTAssertFalse(app.buttons["Turn off camera and microphone"].exists)
        hear.tap()

        let record = app.buttons["practiceRecordButton"]
        let playing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Cancel"), object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 3), .completed)
        XCTAssertTrue(app.staticTexts["LISTEN"].exists)
        assertNoPermissionAlerts(in: app)
        screenshot("Humming · hearing human reference without setup")
        waitForRecord(in: app)
        XCTAssertEqual(target.label, hummingTarget)
        XCTAssertFalse(app.staticTexts["captureMessage"].exists)
        XCTAssertFalse(app.buttons["Turn off camera and microphone"].exists)
        assertNoPermissionAlerts(in: app)

        hear.tap()
        let replaying = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Cancel"), object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [replaying], timeout: 3), .completed)
        app.segmentedControls["practiceSectionPicker"].buttons["Cello"].tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        waitForRecord(in: app)
        XCTAssertFalse(app.staticTexts["captureMessage"].exists)
        XCTAssertFalse(app.buttons["Hear hum"].exists)
        app.segmentedControls["practiceSectionPicker"].buttons["Humming"].tap()
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        waitForRecord(in: app)
        XCTAssertEqual(target.label, hummingTarget)
        XCTAssertTrue(hear.isEnabled)
        XCTAssertTrue(app.buttons["exercisePicker"].label.contains("Listen & match"))
        XCTAssertFalse(app.buttons["Turn off camera and microphone"].exists)
        assertNoPermissionAlerts(in: app)
        screenshot("Humming · ready after changing sections during playback")
    }

    func testLessonsOpenBothGuidedHummingActivities() {
        let app = XCUIApplication()
        app.launch()
        assertReadyToRecord(in: app)
        let target = app.staticTexts["currentTargetLabel"].label
        openLessons(in: app)
        assertNoWrittenInput(in: app)
        screenshot("Lessons · humming library")
        openLesson("steadyHum", title: "Steady hum", in: app)
        screenshot("Lessons · steady hum instructions")
        app.buttons["startLessonButton"].tap()
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["practiceSectionPicker"].buttons["Humming"].isSelected)
        XCTAssertTrue(app.buttons["exercisePicker"].label.contains("Steady hum"))
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, target)
        assertReadyToRecord(in: app)
        assertNoWrittenInput(in: app)

        openLessons(in: app)
        openLesson("matchHum", title: "Listen & match", in: app)
        screenshot("Lessons · listening and matching instructions")
        app.buttons["startLessonButton"].tap()
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["practiceSectionPicker"].buttons["Humming"].isSelected)
        XCTAssertTrue(app.buttons["exercisePicker"].label.contains("Listen & match"))
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, target)
        assertReadyToRecord(in: app)
        assertNoWrittenInput(in: app)
        screenshot("Humming · listen and match")
    }

    func testLessonsShowNumberedAvailableActivitiesAndKeepInstructionsInDetails() {
        let app = XCUIApplication()
        app.launch()
        let hummingTarget = app.staticTexts["currentTargetLabel"].label
        XCTAssertFalse(app.buttons["How to practise"].exists, "Lesson instructions should live in the library")
        XCTAssertFalse(app.buttons["How to practice"].exists)
        openLessons(in: app)

        let sections = app.segmentedControls["lessonsSectionPicker"]
        XCTAssertTrue(sections.buttons["Humming"].isSelected)
        XCTAssertFalse(app.descendants(matching: .any)["lessonInstruction"].exists,
                       "The library should show a short overview, with instructions on each lesson detail")
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label CONTAINS %@", "of 5 lessons completed")).firstMatch.exists)
        for (number, lesson, title) in [(1, "steadyHum", "Steady hum"), (2, "matchHum", "Listen & match"),
                                        (3, "pulse", "Pulse"), (4, "twoTaps", "Two taps per beat"), (5, "mixedRhythm", "Mixed rhythm")] {
            assertAvailableLesson(lesson, number: number, title: title, in: app)
        }
        XCTAssertFalse(app.buttons["lesson-openC"].exists)
        screenshot("Lessons · numbered humming activities")

        // A later lesson remains available without completing the first one.
        openLesson("matchHum", title: "Listen & match", in: app)
        let instruction = app.descendants(matching: .any).matching(identifier: "lessonInstruction").firstMatch
        XCTAssertTrue(instruction.exists)
        assertNoWrittenInput(in: app)
        app.navigationBars["Lesson 2"].buttons["Lessons"].tap()
        XCTAssertTrue(app.navigationBars["Lessons"].waitForExistence(timeout: 5))

        scrollToLessonsTop(in: app)
        sections.buttons["Cello"].tap()
        XCTAssertTrue(sections.buttons["Cello"].isSelected)
        for lesson in ["steadyHum", "matchHum", "pulse", "twoTaps", "mixedRhythm"] {
            XCTAssertFalse(app.buttons["lesson-\(lesson)"].exists, "The Cello library should only show cello lessons")
        }
        for (number, lesson, title) in [(1, "openC", "Open C string"), (2, "openG", "Open G string"),
                                        (3, "openD", "Open D string"), (4, "openA", "Open A string")] {
            assertAvailableLesson(lesson, number: number, title: title, in: app)
        }
        screenshot("Lessons · separate cello activities")
        openLesson("openC", title: "Open C string", in: app)
        XCTAssertTrue(instruction.exists)
        reveal(app.buttons["startLessonButton"], in: app)
        app.buttons["startLessonButton"].tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.segmentedControls["practiceSectionPicker"].buttons["Cello"].isSelected)
        XCTAssertTrue(app.buttons["exercisePicker"].label.contains("Open C string"))
        let celloTarget = app.staticTexts["currentTargetLabel"].label
        XCTAssertTrue(celloTarget.contains("C2") && celloTarget.contains("65.4"))
        assertReadyToRecord(in: app)

        openLessons(in: app)
        XCTAssertTrue(sections.buttons["Cello"].isSelected, "Lessons should open in the current practice section")
        app.navigationBars["Lessons"].buttons["Done"].tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, celloTarget)
        app.segmentedControls["practiceSectionPicker"].buttons["Humming"].tap()
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, hummingTarget,
                       "Starting a cello lesson must preserve the voice reference")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testPulseRunsCountInAndShowsDescriptiveTapFeedback() {
        let app = XCUIApplication()
        app.launch()
        let target = app.staticTexts["currentTargetLabel"].label
        openLessons(in: app)
        openLesson("pulse", title: "Pulse", in: app)
        screenshot("Lessons · pulse instructions")
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app)
        screenshot("Pulse · ready in the main practice screen")

        let start = app.buttons["Start"]
        reveal(start, in: app)
        start.tap()
        let tap = app.buttons["pulseTapButton"]
        XCTAssertTrue(tap.waitForExistence(timeout: 5))
        XCTAssertEqual(tap.label, "Tap on the beat")
        XCTAssertFalse(tap.isEnabled)
        screenshot("Pulse · count in")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: tap)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 7), .completed)
        XCTAssertTrue(tap.isHittable)
        screenshot("Pulse · live button before tapping")

        // Use the real practice clock and touch path, without fabricated scores.
        // Capture the first existing tap's released state without adding a hold
        // or an extra tap that would change the learner's timing observations.
        let deadline = ProcessInfo.processInfo.systemUptime + 22
        var tookReleasedScreenshot = false
        while !app.buttons["Try again"].exists && ProcessInfo.processInfo.systemUptime < deadline {
            if tap.exists && tap.isEnabled {
                tap.tap()
                if !tookReleasedScreenshot {
                    screenshot("Pulse · live button just after a real tap")
                    tookReleasedScreenshot = true
                }
            }
            Thread.sleep(forTimeInterval: 0.15)
        }
        XCTAssertTrue(tookReleasedScreenshot, "The real round should exercise the live Tap button")
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 5))
        let result = app.descendants(matching: .any).matching(identifier: "pulse.result").firstMatch
        reveal(result, in: app)
        XCTAssertTrue(result.exists)
        XCTAssertTrue(app.staticTexts["pulse.stars"].exists, "A completed round should show the earned timing rating")
        XCTAssertTrue(app.staticTexts["practiceProgressText"].exists, "Pulse should use the same separate progress row as voice lessons")
        XCTAssertFalse(tap.exists, "The finished result should replace the live tapping card")
        XCTAssertTrue(app.navigationBars["Humming"].exists)
        XCTAssertFalse(app.navigationBars["Pulse"].exists)
        XCTAssertFalse(app.navigationBars.buttons["Done"].exists)
        assertNoPulseHapticsSwitches(in: app)
        screenshot("Pulse · completed rating and separate progress")

        let chart = app.descendants(matching: .any).matching(identifier: "pulseTimingChart").firstMatch
        reveal(chart, in: app)
        XCTAssertTrue(chart.isHittable, "The completed round should show the learner’s actual tap timing")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "pulseTimingChartCard").firstMatch.exists)
        let summary = chart.label.lowercased()
        for text in ["taps", "on time", "150 milliseconds", "early", "late", "missed", "zero milliseconds"] {
            XCTAssertTrue(summary.contains(text), "The timing chart should explain actual taps, missed taps and the goal band around zero")
        }
        screenshot("Pulse · actual timing chart after the completed round")

        app.buttons["Try again"].tap()
        let cleared = XCTNSPredicateExpectation(predicate: NSPredicate(format: "exists == false"), object: chart)
        XCTAssertEqual(XCTWaiter.wait(for: [cleared], timeout: 5), .completed)
        XCTAssertFalse(result.exists, "Trying again should clear the previous result")
        assertInlinePulseHeader(in: app)
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 5))
        XCTAssertTrue(tap.exists)
        app.buttons["Stop"].tap()
        assertInlinePulseReady(in: app)
        XCTAssertFalse(chart.exists)
        screenshot("Pulse · ready after cancelling a fresh retry")

        scrollToPracticeTop(in: app)
        app.buttons["exercisePicker"].tap()
        app.buttons["Steady hum"].tap()
        XCTAssertTrue(app.segmentedControls["practiceSectionPicker"].buttons["Humming"].isSelected)
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, target)
        assertReadyToRecord(in: app)
    }

    func testListenAndMatchCanContinueToPulseBeforeCompletionAndReturnUnchanged() throws {
        let app = XCUIApplication()
        app.launch()
        assertReadyToRecord(in: app)
        app.buttons["exercisePicker"].tap()
        app.buttons["Listen & match"].tap()
        let exercise = app.buttons["exercisePicker"]
        XCTAssertTrue(exercise.label.contains("Listen & match"))
        let target = app.staticTexts["currentTargetLabel"].label
        let progress = app.staticTexts["practiceProgressText"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        guard !progress.label.contains("Goal reached") else {
            throw XCTSkip("Requires Listen & match to be incomplete to verify advancing before completion")
        }

        let next = app.buttons["nextExerciseButton"]
        reveal(next, in: app)
        XCTAssertTrue(next.isEnabled, "Lesson 3 must remain available before the Listen & match goal is completed")
        XCTAssertTrue(next.label.contains("Lesson 3") && next.label.contains("Pulse"),
                      "The next action should clearly identify the Pulse lesson")
        screenshot("Humming · Listen and match can continue to Pulse")
        next.tap()
        assertInlinePulseReady(in: app)
        assertNoPermissionAlerts(in: app)
        screenshot("Pulse · inline from the next lesson action")
        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 5))

        let sections = app.segmentedControls["practiceSectionPicker"]
        sections.buttons["Cello"].tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        assertReadyToRecord(in: app)
        sections.buttons["Humming"].tap()
        assertInlinePulseReady(in: app)
        screenshot("Pulse · selected after returning from Cello")
        let pulseProgress = app.staticTexts["practiceProgressText"].label

        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Tap on the beat"].isEnabled)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Practice"].tap()
        assertInlinePulseReady(in: app)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, pulseProgress,
                       "Leaving during the count-in must not advance Pulse progress")
        screenshot("Pulse · ready after returning from Recordings")

        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Tap on the beat"].isEnabled)
        openLessons(in: app)
        app.navigationBars["Lessons"].buttons["Done"].tap()
        assertInlinePulseReady(in: app)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, pulseProgress,
                       "Opening Lessons during the count-in must not advance Pulse progress")
        screenshot("Pulse · ready after closing Lessons")

        exercise.tap()
        app.buttons["Listen & match"].tap()
        XCTAssertTrue(exercise.label.contains("Listen & match"))
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, target,
                       "Switching back from Pulse should preserve the voice reference")
        assertReadyToRecord(in: app)

        openLessons(in: app)
        XCTAssertTrue(app.segmentedControls["lessonsSectionPicker"].buttons["Humming"].isSelected)
        openLesson("pulse", title: "Pulse", in: app)
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app)
        XCTAssertFalse(app.staticTexts["lessonDetailTitle"].exists, "Starting Pulse should dismiss the lesson library")
        screenshot("Pulse · library starts the same main practice activity")
        exercise.tap()
        app.buttons["Steady hum"].tap()
        XCTAssertTrue(exercise.label.contains("Steady hum"))
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, target)
        assertReadyToRecord(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testArchivedCompletedPulseCanContinueToLessonFourWithoutChangingEarlierProgress() throws {
        let app = XCUIApplication()
        app.launch()
        let voiceTarget = app.staticTexts["currentTargetLabel"].label
        app.buttons["exercisePicker"].tap()
        app.buttons["Pulse"].tap()
        assertInlinePulseReady(in: app)
        let progress = app.staticTexts["practiceProgressText"]
        // Optional setup: copy completed production Pulse history, unchanged,
        // from a private test archive to the
        // Simulator app's Documents/PulsePractice.json before launching tests.
        // Saved rounds and their earned completion must come from actual practice.
        guard progress.label.contains("Goal reached") else {
            throw XCTSkip("Requires externally copied completed production Pulse history")
        }
        let completedPulse = progress.label
        openLessons(in: app)
        let pulse = app.buttons["lesson-pulse"]
        reveal(pulse, in: app)
        XCTAssertTrue(pulse.label.contains("Completed"))
        XCTAssertTrue(pulse.label.contains("Best score 3 of 3 stars"))
        openLesson("pulse", title: "Pulse", in: app)
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app)
        let next = app.buttons["nextExerciseButton"]
        reveal(next, in: app)
        XCTAssertTrue(next.isEnabled)
        XCTAssertTrue(next.label.contains("Continue to Lesson 4") && next.label.contains("Two taps per beat"))
        screenshot("Pulse · earned completion recommends Lesson 4")
        next.tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertTrue(app.buttons["nextExerciseButton"].label.contains("Lesson 5"), "Lesson 4 should recommend the next available rhythm")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        screenshot("Lesson 4 · inline from completed Pulse")

        app.buttons["exercisePicker"].tap()
        app.buttons["Pulse"].tap()
        assertInlinePulseReady(in: app)
        XCTAssertEqual(progress.label, completedPulse, "Opening the new lesson must preserve earned Pulse completion")
        app.buttons["exercisePicker"].tap()
        app.buttons["Steady hum"].tap()
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, voiceTarget)
        assertReadyToRecord(in: app)
    }

    func testLessonFourRunsTwoTapsPerBeatInlineAndKeepsItsOwnProgress() throws {
        let app = XCUIApplication()
        app.launch()
        let voiceTarget = app.staticTexts["currentTargetLabel"].label
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        let recordingIDs = visibleRecordingIDs(in: app)
        app.tabBars.buttons["Practice"].tap()
        app.buttons["exercisePicker"].tap()
        app.buttons["Pulse"].tap()
        assertInlinePulseReady(in: app)
        let pulseProgress = app.staticTexts["practiceProgressText"].label

        openLessons(in: app)
        openLesson("twoTaps", title: "Two taps per beat", in: app)
        screenshot("Lessons · two taps per beat instructions")
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists)
        XCTAssertFalse(app.staticTexts["currentTargetLabel"].exists, "A tap lesson should not show a voice target")
        XCTAssertTrue(app.staticTexts["Two taps each second · 8 beats."].exists)
        let instructions = app.descendants(matching: .any).matching(identifier: "twoTapsInstructions").firstMatch
        XCTAssertTrue(instructions.isHittable, "The explanation should be visible before Start, without opening a help screen")
        let pattern = app.descendants(matching: .any).matching(identifier: "twoTapsCountPattern").firstMatch
        XCTAssertTrue(pattern.isHittable)
        XCTAssertTrue(pattern.label.contains("Tap on every number and every and"))
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        screenshot("Lesson 4 · ready in shared practice")

        let startedAt = ProcessInfo.processInfo.systemUptime
        app.buttons["Start"].tap()
        XCTAssertFalse(instructions.exists, "The explanation should give way to the live exercise")
        let tap = app.buttons["pulseTapButton"]
        XCTAssertTrue(tap.waitForExistence(timeout: 5))
        XCTAssertFalse(tap.isEnabled, "The four-beat count-in must happen before tapping")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: tap)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 7), .completed)

        // Exercise actual half-second slots with native touches and the real
        // monotonic clock. The test never supplies offsets, stars or completion.
        let deadline = ProcessInfo.processInfo.systemUptime + 14
        var actualTouches = 0
        while !app.buttons["Try again"].exists && ProcessInfo.processInfo.systemUptime < deadline {
            if tap.exists && tap.isEnabled {
                tap.tap()
                actualTouches += 1
            }
            Thread.sleep(forTimeInterval: 0.12)
        }
        XCTAssertGreaterThanOrEqual(actualTouches, 3)
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - startedAt, 11.8,
                                    "The four-second count-in and eight-second exercise must run in real time")
        let result = app.descendants(matching: .any).matching(identifier: "pulse.result").firstMatch
        reveal(result, in: app)
        XCTAssertTrue(result.exists)
        let stars = app.staticTexts["pulse.stars"]
        XCTAssertTrue(stars.exists, "Enough genuine taps should produce the measured round rating")
        let savedStars = stars.label
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "pulse.beats").firstMatch.label.contains("Taps"))
        XCTAssertFalse(tap.exists, "Finished feedback should replace the live tap pad")
        XCTAssertFalse(instructions.exists, "The results should stay focused on performance")
        let progress = app.staticTexts["practiceProgressText"]
        XCTAssertTrue(progress.exists)
        let twoTapsProgress = progress.label
        assertNoPulseHapticsSwitches(in: app)
        assertNoWrittenInput(in: app)
        screenshot("Lesson 4 · measured result and own progress")

        let chart = app.descendants(matching: .any).matching(identifier: "pulseTimingChart").firstMatch
        reveal(chart, in: app)
        XCTAssertTrue(chart.isHittable)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "pulseTimingChartCard").firstMatch.exists)
        let counts = try timingCounts(in: chart.label, beats: 8)
        XCTAssertEqual(counts.taps + counts.missed, 16, "The eight beats should contain sixteen distinct tap slots")
        XCTAssertGreaterThanOrEqual(counts.taps, 3)
        for text in ["on time", "150 milliseconds", "early", "late", "Missed taps have no timing point"] {
            XCTAssertTrue(chart.label.contains(text))
        }
        screenshot("Lesson 4 · actual sixteen-slot timing chart")

        scrollToPracticeTop(in: app)
        app.buttons["exercisePicker"].tap()
        app.buttons["Pulse"].tap()
        assertInlinePulseReady(in: app)
        XCTAssertEqual(progress.label, pulseProgress, "A Lesson 4 round must not change Lesson 3 progress")
        app.terminate()
        app.launch()
        assertReadyToRecord(in: app)
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, voiceTarget)
        app.buttons["exercisePicker"].tap()
        app.buttons["Two taps per beat"].tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertEqual(progress.label, twoTapsProgress, "Lesson 4 should retain its own saved progress")
        openLessons(in: app)
        openLesson("twoTaps", title: "Two taps per beat", in: app)
        let latest = app.descendants(matching: .any).matching(identifier: "lessonLatestScore").firstMatch
        reveal(latest, in: app)
        XCTAssertTrue(latest.label.contains(savedStars), "The lesson book should show this actual round's saved rating")
        app.navigationBars["Lesson 4"].buttons["Done"].tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        app.buttons["exercisePicker"].tap()
        app.buttons["Steady hum"].tap()
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, voiceTarget)
        assertReadyToRecord(in: app)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        XCTAssertEqual(visibleRecordingIDs(in: app), recordingIDs, "Tap practice must not create an audio/video recording")
    }

    func testArchivedCompletedLessonFourCanContinueToMixedRhythm() throws {
        let app = XCUIApplication()
        app.launch()
        app.buttons["exercisePicker"].tap()
        app.buttons["Two taps per beat"].tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        let progress = app.staticTexts["practiceProgressText"]
        // Optional setup: copy completed production TwoTapsPractice.json from
        // a private archive into Simulator Documents, without changing grades.
        guard progress.label.contains("Goal reached") else {
            throw XCTSkip("Requires externally copied completed Lesson 4 practice history")
        }
        let completed = progress.label
        let next = app.buttons["nextExerciseButton"]
        reveal(next, in: app)
        XCTAssertTrue(next.label.contains("Continue to Lesson 5") && next.label.contains("Mixed rhythm"))
        next.tap()
        assertInlinePulseReady(in: app, title: "Mixed rhythm")
        XCTAssertFalse(app.buttons["nextExerciseButton"].exists)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "mixedRhythmInstructions").firstMatch.isHittable)
        screenshot("Lesson 5 · continue from completed Lesson 4")
        app.buttons["exercisePicker"].tap()
        app.buttons["Two taps per beat"].tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertEqual(progress.label, completed, "Opening Lesson 5 must preserve earned Lesson 4 completion")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testMixedRhythmRunsInlineAndKeepsPatternScoreAndProgressSeparate() throws {
        let app = XCUIApplication()
        app.launch()
        let voiceTarget = app.staticTexts["currentTargetLabel"].label
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        let recordingIDs = visibleRecordingIDs(in: app)
        app.tabBars.buttons["Practice"].tap()
        app.buttons["exercisePicker"].tap()
        app.buttons["Two taps per beat"].tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        let earlierProgress = app.staticTexts["practiceProgressText"].label

        openLessons(in: app)
        openLesson("mixedRhythm", title: "Mixed rhythm", in: app)
        screenshot("Lessons · mixed rhythm instructions")
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app, title: "Mixed rhythm")
        let instructions = app.descendants(matching: .any).matching(identifier: "mixedRhythmInstructions").firstMatch
        let pattern = app.descendants(matching: .any).matching(identifier: "mixedRhythmCountPattern").firstMatch
        XCTAssertTrue(instructions.isHittable && pattern.isHittable)
        XCTAssertTrue(pattern.label.contains("Tap once on odd numbers and twice on even numbers"))
        XCTAssertTrue(app.staticTexts["12 taps · 8 beats · 60 BPM."].exists)
        XCTAssertFalse(app.staticTexts["currentTargetLabel"].exists)
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists)
        XCTAssertFalse(app.buttons["nextExerciseButton"].exists)
        assertNoWrittenInput(in: app)
        screenshot("Lesson 5 · mixed rhythm ready")

        let startedAt = ProcessInfo.processInfo.systemUptime
        app.buttons["Start"].tap()
        XCTAssertFalse(instructions.exists)
        let tap = app.buttons["pulseTapButton"]
        XCTAssertTrue(tap.waitForExistence(timeout: 5))
        XCTAssertFalse(tap.isEnabled)
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: tap)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 7), .completed)
        // Native touches follow the real clock. The measured taps and any
        // off-pattern touches determine the score; this test supplies no grade.
        let deadline = ProcessInfo.processInfo.systemUptime + 14
        var actualTouches = 0
        while !app.buttons["Try again"].exists && ProcessInfo.processInfo.systemUptime < deadline {
            if tap.exists && tap.isEnabled {
                tap.tap()
                actualTouches += 1
            }
            Thread.sleep(forTimeInterval: 0.12)
        }
        XCTAssertGreaterThanOrEqual(actualTouches, 3)
        XCTAssertTrue(app.buttons["Try again"].waitForExistence(timeout: 5))
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - startedAt, 11.8)
        let result = app.descendants(matching: .any).matching(identifier: "pulse.result").firstMatch
        reveal(result, in: app)
        let stars = app.staticTexts["pulse.stars"]
        XCTAssertTrue(stars.exists, "The real round should have enough accepted taps for a rating")
        let savedStars = stars.label
        let feedback = app.staticTexts["pulse.feedback"].label
        let extraCount = try extraTapCount(in: feedback)
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "pulse.beats").firstMatch.label.contains("Pattern"))
        let progress = app.staticTexts["practiceProgressText"]
        let mixedProgress = progress.label
        XCTAssertFalse(tap.exists)
        XCTAssertFalse(instructions.exists)
        assertNoPulseHapticsSwitches(in: app)
        screenshot("Lesson 5 · actual pattern score")

        let chart = app.descendants(matching: .any).matching(identifier: "pulseTimingChart").firstMatch
        reveal(chart, in: app)
        let counts = try timingCounts(in: chart.label, beats: 8)
        XCTAssertEqual(counts.taps + counts.missed, 12)
        XCTAssertGreaterThanOrEqual(counts.taps, 3)
        XCTAssertTrue(chart.label.contains("\(extraCount) extra taps"), "Chart and result should agree on recorded extra taps")
        screenshot("Lesson 5 · twelve-place timing chart")

        scrollToPracticeTop(in: app)
        app.buttons["exercisePicker"].tap()
        app.buttons["Two taps per beat"].tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertEqual(progress.label, earlierProgress)
        app.terminate()
        app.launch()
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, voiceTarget)
        app.buttons["exercisePicker"].tap()
        app.buttons["Mixed rhythm"].tap()
        assertInlinePulseReady(in: app, title: "Mixed rhythm")
        XCTAssertEqual(progress.label, mixedProgress)
        openLessons(in: app)
        openLesson("mixedRhythm", title: "Mixed rhythm", in: app)
        let latest = app.descendants(matching: .any).matching(identifier: "lessonLatestScore").firstMatch
        reveal(latest, in: app)
        XCTAssertTrue(latest.label.contains(savedStars))
        screenshot("Lessons · mixed rhythm score after relaunch")
        app.navigationBars["Lesson 5"].buttons["Done"].tap()
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        XCTAssertEqual(visibleRecordingIDs(in: app), recordingIDs)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testProgressSuggestsNextExerciseWithoutLockingPractice() {
        let app = XCUIApplication()
        app.launch()
        assertReadyToRecord(in: app)
        let target = app.staticTexts["currentTargetLabel"].label
        let progress = app.staticTexts["practiceProgressText"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "Progress should be available before microphone setup")
        let next = app.buttons["nextExerciseButton"]
        reveal(next, in: app)
        XCTAssertTrue(next.isEnabled, "The next exercise must remain available before its predecessor is completed")
        XCTAssertFalse(app.buttons["Turn off camera and microphone"].exists)
        assertNoPermissionAlerts(in: app)
        screenshot("Humming · progress and optional next exercise")

        next.tap()
        let exercise = app.buttons["exercisePicker"]
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Listen & match"), object: exercise)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        XCTAssertEqual(app.staticTexts["currentTargetLabel"].label, target)
        XCTAssertTrue(progress.exists)
        scrollToPracticeTop(in: app)
        assertReadyToRecord(in: app)

        exercise.tap()
        XCTAssertTrue(app.buttons["Steady hum"].isEnabled)
        XCTAssertTrue(app.buttons["Listen & match"].isEnabled)
        XCTAssertTrue(app.buttons["Pulse"].isEnabled)
        XCTAssertTrue(app.buttons["Two taps per beat"].isEnabled)
        app.buttons["Steady hum"].tap()
        app.segmentedControls["practiceSectionPicker"].buttons["Cello"].tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        exercise.tap()
        for title in ["Open C string", "Open G string", "Open D string", "Open A string"] {
            XCTAssertTrue(app.buttons[title].isEnabled, "Cello exercises must not be locked by humming progress")
        }
        app.buttons["Open G string"].tap()
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    private func assertReadyToRecord(in app: XCUIApplication) {
        let record = app.buttons["practiceRecordButton"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertTrue(record.isHittable, "Record must be visible before microphone input")
        XCTAssertTrue(record.isEnabled, "Record must not require a warm-up hum")
        XCTAssertTrue(app.staticTexts["currentTargetLabel"].exists)
        XCTAssertFalse(app.buttons["Enable camera & microphone"].exists)
    }

    private func assertInlinePulseHeader(in app: XCUIApplication, title: String = "Pulse") {
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        let exercise = app.buttons["exercisePicker"]
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", title), object: exercise)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        let headerReady = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "hittable == true"), object: exercise)
        XCTAssertEqual(XCTWaiter.wait(for: [headerReady], timeout: 5), .completed)
        XCTAssertTrue(app.segmentedControls["practiceSectionPicker"].buttons["Humming"].isSelected)
        XCTAssertTrue(app.segmentedControls["practiceSectionPicker"].isHittable)
        XCTAssertTrue(exercise.isHittable, "Pulse should keep the exercise menu visible in main practice")
        XCTAssertTrue(app.buttons["hummingLearnButton"].isHittable)
        XCTAssertTrue(app.tabBars.buttons["Practice"].isHittable)
        XCTAssertTrue(app.tabBars.buttons["Recordings"].isHittable)
        XCTAssertFalse(app.navigationBars[title].exists, "\(title) should share the Humming practice screen")
        XCTAssertFalse(app.navigationBars.buttons["Done"].exists, "Inline Pulse should not have a modal Done control")
        assertNoPulseHapticsSwitches(in: app)
    }

    private func assertInlinePulseReady(in app: XCUIApplication, title: String = "Pulse") {
        assertInlinePulseHeader(in: app, title: title)
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start"].isEnabled)
        let tap = app.buttons["pulseTapButton"]
        XCTAssertTrue(tap.exists)
        XCTAssertFalse(tap.isEnabled)
    }

    private func assertNoPulseHapticsSwitches(in app: XCUIApplication) {
        for label in ["Haptics", "Vibration"] {
            XCTAssertFalse(app.switches[label].exists, "Pulse should provide its beat feedback without a separate switch")
        }
    }

    private func timingCounts(in summary: String, beats: Int) throws -> (taps: Int, missed: Int) {
        let text = summary as NSString
        let expression = try NSRegularExpression(pattern: "(\\d+) taps across \(beats) beats:.*?, (\\d+) missed\\.")
        let match = try XCTUnwrap(expression.firstMatch(in: summary, range: NSRange(location: 0, length: text.length)))
        let taps = try XCTUnwrap(Int(text.substring(with: match.range(at: 1))))
        let missed = try XCTUnwrap(Int(text.substring(with: match.range(at: 2))))
        return (taps, missed)
    }

    private func extraTapCount(in summary: String) throws -> Int {
        let text = summary as NSString
        let expression = try NSRegularExpression(pattern: "(\\d+) extra taps")
        let match = try XCTUnwrap(expression.firstMatch(in: summary, range: NSRange(location: 0, length: text.length)))
        return try XCTUnwrap(Int(text.substring(with: match.range(at: 1))))
    }

    private func visibleRecordingIDs(in app: XCUIApplication) -> Set<String> {
        let recordings = app.descendants(matching: .any).matching(NSPredicate(format: "identifier BEGINSWITH %@", "recording-"))
        return Set(recordings.allElementsBoundByIndex.map(\.identifier))
    }

    private func waitForRecord(in app: XCUIApplication) {
        let record = app.buttons["practiceRecordButton"]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ AND enabled == true", "Record"), object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: 6), .completed)
    }

    private func openLessons(in app: XCUIApplication) {
        let lessons = app.buttons["hummingLearnButton"]
        reveal(lessons, in: app)
        XCTAssertTrue(lessons.label.contains("Lessons"), "The book control should name the library it opens")
        lessons.tap()
        XCTAssertTrue(app.navigationBars["Lessons"].waitForExistence(timeout: 5))
    }

    private func openLesson(_ identifier: String, title: String, in app: XCUIApplication) {
        scrollToLessonsTop(in: app)
        let lesson = app.buttons["lesson-\(identifier)"]
        reveal(lesson, in: app)
        XCTAssertTrue(lesson.isEnabled, "Every lesson should be available before its predecessor is completed")
        lesson.tap()
        let heading = app.staticTexts["lessonDetailTitle"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, title)
        let instruction = app.descendants(matching: .any).matching(identifier: "lessonInstruction").firstMatch
        reveal(instruction, in: app)
        XCTAssertTrue(instruction.isHittable, "Each lesson should show its own practice instructions")
        reveal(app.buttons["startLessonButton"], in: app)
        XCTAssertTrue(app.buttons["startLessonButton"].isEnabled)
    }

    private func scrollToLessonsTop(in app: XCUIApplication) {
        let sections = app.segmentedControls["lessonsSectionPicker"]
        let first = app.buttons["lesson-steadyHum"].exists ? app.buttons["lesson-steadyHum"] : app.buttons["lesson-openC"]
        for _ in 0..<6 {
            if sections.isHittable && first.isHittable { return }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(sections.isHittable && first.isHittable)
    }

    private func assertAvailableLesson(_ identifier: String, number: Int, title: String, in app: XCUIApplication) {
        let lesson = app.buttons["lesson-\(identifier)"]
        reveal(lesson, in: app)
        XCTAssertTrue(lesson.isEnabled, "Lesson \(number) must remain available before earlier goals are completed")
        XCTAssertTrue(lesson.label.contains("Lesson \(number)"), "The library should announce each lesson number")
        XCTAssertTrue(lesson.label.contains(title))
        if lesson.label.contains("Not started") {
            XCTAssertFalse(lesson.label.localizedCaseInsensitiveContains("stars"),
                           "An unstarted lesson must not receive an invented score")
            XCTAssertTrue(lesson.label.contains("No score yet"))
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "lessonCompletion-\(identifier)").firstMatch.exists)
        }
    }

    private func assertCelloExercisesAbsent(in app: XCUIApplication) {
        for title in ["Open C string", "Open G string", "Open D string", "Open A string"] {
            XCTAssertFalse(app.buttons[title].exists)
        }
    }

    private func assertNoWrittenInput(in app: XCUIApplication) {
        XCTAssertEqual(app.textFields.count, 0)
        XCTAssertEqual(app.textViews.count, 0)
        XCTAssertEqual(app.secureTextFields.count, 0)
    }

    private func assertNoPermissionAlerts(in app: XCUIApplication) {
        XCTAssertEqual(app.alerts.count, 0)
        XCTAssertEqual(XCUIApplication(bundleIdentifier: "com.apple.springboard").alerts.count, 0)
    }

    private func reveal(_ element: XCUIElement, in app: XCUIApplication) {
        for _ in 0..<10 {
            if element.exists && element.isHittable { return }
            app.scrollViews.firstMatch.swipeUp()
        }
        XCTAssertTrue(element.exists && element.isHittable)
    }

    private func scrollToPracticeTop(in app: XCUIApplication) {
        let section = app.segmentedControls["practiceSectionPicker"]
        for _ in 0..<6 {
            if section.exists && section.isHittable { return }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(section.exists && section.isHittable)
    }

    private func screenshot(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
