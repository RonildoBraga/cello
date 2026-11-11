import XCTest

final class LearningUITests: XCTestCase {
    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testMusicShowsOnePathOfLevelsWithOneContinueLesson() {
        let app = XCUIApplication.cello()
        app.launch()
        XCTAssertTrue(app.navigationBars["Music"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.tabBars.buttons["Music"].isSelected)
        for tab in ["Music", "Recordings", "About"] { XCTAssertTrue(app.tabBars.buttons[tab].isHittable) }
        XCTAssertFalse(app.tabBars.buttons["Practice"].exists, "Practice is a screen pushed from Music, not a tab")
        for id in ["foundation-humming", "foundation-rhythm", "foundation-cello", "piece-hotCrossBuns"] {
            XCTAssertFalse(app.buttons[id].exists, "Foundations and Pieces are no longer separate lists")
        }
        var unfinished = false
        for (id, number, title) in [("firstSounds", 1, "First sounds"), ("hotCrossBuns", 2, "Hot Cross Buns"),
                                    ("odeToJoy", 3, "Ode to Joy"), ("cello", 4, "Cello · open strings")] {
            let level = app.buttons["level-\(id)"]
            app.scroll(to: level)
            XCTAssertTrue(level.label.contains("Level \(number), \(title)"))
            let steps = number == 1 ? 6 : 5
            XCTAssertTrue(level.label.contains("of \(steps) lessons done"))
            if !level.label.contains("\(steps) of \(steps)") { unfinished = true }
        }
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists, "Opening Music should not activate capture")
        XCTAssertFalse(app.buttons["previewTargetButton"].exists)
        screenshot("Music · one path of levels")

        // Every melody level has the same lessons in the same order, and all are open.
        for piece in ["hotCrossBuns", "odeToJoy"] {
            for (index, step) in [("listen", "Listen"), ("tap", "Tap it"), ("notes", "Meet the notes"),
                                  ("hum", "Hum it"), ("whole", "Whole melody")].enumerated() {
                let row = app.pathRow("lesson-\(piece)-\(step.0)")
                XCTAssertTrue(row.isEnabled, "Every lesson can be opened regardless of progress")
                XCTAssertTrue(row.label.contains("Lesson \(index + 1), \(step.1)"))
            }
        }
        screenshot("Music · a melody level and its lessons")
        // Everything belongs to a level: the extra rhythm, ear training and the cello too.
        for (id, step) in [("lesson-steadyHum", 1), ("lesson-mixedRhythm", 5), ("echoPracticeLink", 6),
                           ("celloIntroductionLink", 1), ("lesson-openA", 5)] {
            let row = app.pathRow(id)
            XCTAssertTrue(row.isEnabled)
            XCTAssertTrue(row.label.contains("Lesson \(step), "), "\(id) should be lesson \(step) of its level")
        }
        XCTAssertFalse(app.buttons["level-more"].exists)
        // With every level open, one lesson at most is marked as the next one.
        let marked = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Continue, Lesson"))
        XCTAssertEqual(marked.count, unfinished ? 1 : 0, "Exactly one lesson is highlighted as Continue")
        // The long-term goal and the credits live on the About tab, off the path.
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "pathDestinationNote").firstMatch.exists)
        XCTAssertFalse(app.buttons["aboutButton"].exists, "Music has no info button")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testAboutTabCreditsTheBuildersAndEverySoundSource() {
        let app = XCUIApplication.cello()
        app.launch()
        app.tabBars.buttons["About"].tap()
        XCTAssertTrue(app.staticTexts["aboutTitle"].waitForExistence(timeout: 5))
        for text in ["Ronildo Braga", "Claude, by Anthropic", "“Deep Humming Noise” by retropttam", "VSCO 2 Community Edition"] {
            let credit = app.staticTexts[text]
            app.scroll(to: credit)
        }
        for link in ["Original recording on Freesound", "Creative Commons Attribution 3.0", "Creative Commons CC0 1.0"] {
            XCTAssertTrue(app.buttons[link].exists || app.links[link].exists, "\(link) should stay available")
        }
        screenshot("About · sound sources")
        let version = app.staticTexts["aboutVersion"]
        app.scroll(to: version)
        XCTAssertTrue(version.label.hasPrefix("Cello "))
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        app.tabBars.buttons["Music"].tap()
        XCTAssertTrue(app.buttons["level-firstSounds"].waitForExistence(timeout: 5))
    }

    func testMelodyLevelOpensWholeMelodyAndLessonsWithoutInventingScores() {
        let app = XCUIApplication.cello()
        app.launch()
        app.pathLesson("lesson-hotCrossBuns-whole").tap()
        XCTAssertTrue(app.navigationBars["Hot Cross Buns"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["screenTitle"].label, "Whole melody")
        XCTAssertTrue(app.buttons["previewTargetButton"].label.hasPrefix("Whole melody"), "Whole melody is one part, shown as one chip")
        XCTAssertFalse(app.staticTexts["lessonPartPosition"].exists)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists, "Opening a lesson must not invent a score")
        screenshot("Hot Cross Buns · whole melody lesson")
        app.pathLesson("lesson-hotCrossBuns-hum").tap()
        XCTAssertTrue(app.navigationBars["Hot Cross Buns"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["screenTitle"].label, "Hum it")
        XCTAssertTrue(app.buttons["previewTargetButton"].label.hasPrefix("Phrase 1"))

        // The lesson bar is the one way forward: through the phrases, then to
        // the next lesson, then into the next level. And back the same way.
        let next = app.buttons["nextLessonButton"]
        let previous = app.buttons["previousLessonButton"]
        let position = app.staticTexts["lessonPosition"]
        XCTAssertEqual(app.staticTexts["lessonPartPosition"].label, "Phrase 1 of 4")
        XCTAssertEqual(previous.label, "Previous lesson, Meet the notes")
        XCTAssertEqual(next.label, "Next part, Phrase 2")
        XCTAssertFalse(app.buttons["nextMelodyPhraseButton"].exists, "There is no second way to move on")
        next.tap()
        let onPhraseTwo = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", "Phrase 2"), object: app.buttons["previewTargetButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [onPhraseTwo], timeout: 5), .completed)
        XCTAssertEqual(position.label, "Lesson 4 of 5", "A phrase is a part of the same lesson")
        XCTAssertEqual(previous.label, "Previous part")
        previous.tap()
        let onPhraseOne = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label BEGINSWITH %@", "Phrase 1"), object: app.buttons["previewTargetButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [onPhraseOne], timeout: 5), .completed)

        selectMelodyHummingSection("Phrase 4", in: app)
        XCTAssertEqual(next.label, "Next lesson, Whole melody")
        next.tap()
        let onWhole = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Lesson 5 of 5"), object: position)
        XCTAssertEqual(XCTWaiter.wait(for: [onWhole], timeout: 5), .completed)
        XCTAssertEqual(app.staticTexts["screenTitle"].label, "Whole melody")
        XCTAssertEqual(next.label, "Next level, Ode to Joy", "The last lesson of a level leads on to the next level")
        previous.tap()
        let onHum = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Lesson 4 of 5"), object: position)
        XCTAssertEqual(XCTWaiter.wait(for: [onHum], timeout: 5), .completed)
        XCTAssertTrue(app.buttons["previewTargetButton"].label.hasPrefix("Phrase 1"))
        openLesson("pulse", title: "Pulse", in: app)
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testEarnedRhythmCompletionDoesNotInventAPiecePerformance() throws {
        try requireRecordingFixtures()
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        let hummingProgress = app.staticTexts["practiceProgressText"].label
        startLesson("Pulse", in: app)
        let rhythmProgress = app.staticTexts["practiceProgressText"].label
        guard rhythmProgress.contains("Goal reached") else {
            throw XCTSkip("Requires externally copied completed production Pulse history")
        }
        let pulse = app.pathRow("lesson-pulse")
        XCTAssertTrue(pulse.label.contains("Gold"))
        XCTAssertTrue(pulse.label.contains("Best score 3 of 3 stars"))
        let whole = app.pathRow("lesson-hotCrossBuns-whole")
        XCTAssertFalse(whole.label.contains("Gold"), "A foundation success is not a melody performance")
        XCTAssertFalse(app.staticTexts["ratingStarCount"].exists)
        XCTAssertFalse(app.staticTexts["pulse.stars"].exists)
        screenshot("Music · foundation success remains separate from piece performances")
        startLesson("Pulse", in: app)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, rhythmProgress)
        startLesson("Steady hum", in: app)
        assertReadyToRecord(in: app)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, hummingProgress)
    }

    func testArchivedProductionRatingAndCompletedProgressSurviveRelaunch() throws {
        try requireRecordingFixtures()
        let app = XCUIApplication.cello()
        launchPractice(in: app)
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

        startLesson("Steady hum", in: app)
        let progress = app.staticTexts["practiceProgressText"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertTrue(progress.label.contains("Goal reached"), "Three rated successes should complete the Steady hum goal")
        XCTAssertTrue(app.buttons["nextLessonButton"].isEnabled)
        screenshot("Humming · completed goal from three rated takes")
        let completed = progress.label
        app.terminate()
        launchPractice(in: app)
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        XCTAssertEqual(progress.label, completed, "Earned completion should remain after relaunch")

        let lesson = app.pathRow("lesson-steadyHum")
        XCTAssertTrue(lesson.waitForExistence(timeout: 5))
        XCTAssertTrue(lesson.label.contains("Gold"))
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
        try requireRecordingFixtures()
        let app = XCUIApplication.cello()
        launchPractice(in: app)
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

    func testArchivedMelodyFeedbackChartAndCompletionStaySeparateFromFoundations() throws {
        try requireRecordingFixtures()
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        let foundationTarget = app.buttons["previewTargetButton"].label
        let foundationProgress = app.staticTexts["practiceProgressText"].label
        app.tabBars.buttons["Recordings"].tap()
        // Optional external setup: three real decoder/rater results from the
        // human-based Phrase 1 fixture, a delayed two-star result and an unclear
        // noise take. Only folder/session IDs are normalized; grades are not set
        // by the UI test or by a special app mode.
        let successfulIDs = (1...3).map { "FA000000-0000-4000-8000-00000000000\($0)" }
        let partialID = "FB000000-0000-4000-8000-000000000001"
        let unclearID = "FB000000-0000-4000-8000-000000000002"
        let rows = (successfulIDs + [partialID, unclearID]).map {
            app.descendants(matching: .any)["recording-\($0)"]
        }
        guard rows[0].waitForExistence(timeout: 5), rows.allSatisfy(\.exists) else {
            throw XCTSkip("Requires externally seeded, production-rated melody fixtures FA...001–003 and FB...001–002")
        }
        rows[0].tap()
        let stars = app.staticTexts["melodyRatingStars"]
        reveal(stars, in: app)
        XCTAssertEqual(stars.label, "3 of 3 stars")
        for id in ["melodyGoal-notes", "melodyGoal-timing", "melodyGoal-clarity"] {
            XCTAssertTrue(app.descendants(matching: .any)[id].label.contains("goal reached"))
        }
        let chart = app.descendants(matching: .any).matching(identifier: "melodyPitchChart").firstMatch
        reveal(chart, in: app)
        XCTAssertTrue(chart.isHittable)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "pitchTraceChart").firstMatch.exists,
                       "A changing melody needs its own expected-note chart")
        screenshot("Melody recording · three stars and phrase chart")

        app.navigationBars["Your session"].buttons.firstMatch.tap()
        rows[3].tap()
        reveal(stars, in: app)
        XCTAssertEqual(stars.label, "2 of 3 stars")
        XCTAssertTrue(app.descendants(matching: .any)["melodyGoal-notes"].label.contains("goal reached"))
        XCTAssertTrue(app.descendants(matching: .any)["melodyGoal-clarity"].label.contains("goal reached"))
        XCTAssertTrue(app.descendants(matching: .any)["melodyGoal-timing"].label.contains("keep practising"))
        reveal(chart, in: app)
        screenshot("Melody recording · delayed phrase keeps Timing separate")

        app.navigationBars["Your session"].buttons.firstMatch.tap()
        rows[4].tap()
        let unscored = app.staticTexts["melodyRatingUnclear"]
        reveal(unscored, in: app)
        XCTAssertTrue(app.staticTexts["Progress unchanged"].exists)
        XCTAssertFalse(stars.exists, "Uncertain sound must not receive zero stars")
        for id in ["melodyGoal-notes", "melodyGoal-timing", "melodyGoal-clarity"] {
            XCTAssertFalse(app.descendants(matching: .any)[id].exists)
        }
        XCTAssertTrue(app.staticTexts["melodyFeedback"].exists)
        reveal(chart, in: app)
        screenshot("Melody recording · unclear take leaves progress unchanged")

        openMelodyHumming(in: app)
        let progress = app.staticTexts["practiceProgressText"]
        reveal(progress, in: app)
        XCTAssertTrue(progress.label.contains("Goal reached"))
        XCTAssertTrue(app.buttons["nextLessonButton"].isEnabled)
        selectMelodyHummingSection("Phrase 3", in: app)
        reveal(progress, in: app)
        XCTAssertFalse(progress.label.contains("Goal reached"), "A different phrase earns its own completion")
        XCTAssertTrue(progress.label.contains("0 of 3"))
        startLesson("Steady hum", in: app)
        waitForRecord(in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, foundationTarget)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, foundationProgress,
                       "Melody stars cannot grant a foundation achievement")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testArchivedTakeShowsPitchTraceWithoutChangingItsRatingOrPlayback() throws {
        try requireRecordingFixtures()
        let app = XCUIApplication.cello()
        launchPractice(in: app)
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
        let share = app.buttons["shareSessionButton"]
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
        try requireRecordingFixtures()
        let app = XCUIApplication.cello()
        launchPractice(in: app)
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

        app.terminate()
        launchPractice(in: app)
        let target = app.buttons["previewTargetButton"]
        XCTAssertTrue(target.waitForExistence(timeout: 5))
        XCTAssertTrue(target.label.contains("A2") && target.label.contains("110.6"))
        let lesson = app.pathLesson("lesson-steadyHum")
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

    func testThreeAreasKeepLessonsAndTargetsSeparate() {
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        XCTAssertTrue(app.navigationBars["Humming"].exists)
        XCTAssertEqual(app.staticTexts["practiceLessonArea"].label, "Level 1 · First sounds")
        assertReadyToRecord(in: app)
        let target = app.buttons["previewTargetButton"]
        let hummingTarget = target.label
        XCTAssertTrue(hummingTarget.contains("A2") && hummingTarget.contains("110.6"))
        XCTAssertFalse(app.buttons["changeTarget"].exists)
        XCTAssertFalse(app.buttons["useHummingExampleNote"].exists)
        XCTAssertFalse(app.segmentedControls["practiceAreaPicker"].exists, "Lessons are chosen in Music, not on the practice screen")
        XCTAssertFalse(app.buttons["exercisePicker"].exists)
        XCTAssertFalse(app.buttons["musicLibraryButton"].exists)
        screenshot("Humming · voice foundation practice")

        startLesson("Two taps per beat", in: app)
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertFalse(target.exists, "Rhythm must not inherit a voice tuning target")
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists)
        screenshot("Rhythm · independent practice area")

        startLesson("Open G string", in: app)
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        XCTAssertTrue(target.label.contains("G2") && target.label.contains("98.0"))
        assertReadyToRecord(in: app)
        startLesson("Open C string", in: app)
        let celloTarget = target.label
        XCTAssertTrue(celloTarget.contains("C2") && celloTarget.contains("65.4"))
        screenshot("Cello · its own open-string reference")

        startLesson("Listen & match", in: app)
        XCTAssertEqual(target.label, hummingTarget)
        assertReadyToRecord(in: app)
        startLesson("Open C string", in: app)
        XCTAssertEqual(target.label, celloTarget)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testRecordedCelloReferencesPlayWithoutStartingCapture() {
        let app = XCUIApplication.cello()
        app.launch()
        for (exercise, note) in [("Open C string", "C2"), ("Open G string", "G2"),
                                 ("Open D string", "D3"), ("Open A string", "A3")] {
            startLesson(exercise, in: app)
            let target = app.buttons["previewTargetButton"]
            XCTAssertTrue(target.label.contains(note))
            let hear = app.buttons["previewTargetButton"]
            XCTAssertTrue(hear.label.contains("Hear string"))
            hear.tap()
            let listening = XCTNSPredicateExpectation(
                predicate: NSPredicate(format: "label == %@", "Cancel"),
                object: app.buttons["practiceRecordButton"])
            XCTAssertEqual(XCTWaiter.wait(for: [listening], timeout: 3), .completed)
            XCTAssertTrue(app.staticTexts["LISTEN"].exists)
            waitForRecord(in: app)
            XCTAssertTrue(target.label.contains(note))
            XCTAssertFalse(app.staticTexts["captureMessage"].exists)
            XCTAssertFalse(app.buttons["Turn off camera and microphone"].exists)
        }
        screenshot("Cello · recorded references without microphone setup")
        assertNoPermissionAlerts(in: app)
    }

    func testHumanHumPreviewWorksWithoutCaptureAndCancelsOnLeaving() {
        let app = XCUIApplication.cello()
        app.launch()
        startLesson("Listen & match", in: app)
        assertReadyToRecord(in: app)
        let target = app.buttons["previewTargetButton"]
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
        startLesson("Open G string", in: app)
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        waitForRecord(in: app)
        XCTAssertFalse(app.staticTexts["captureMessage"].exists)
        XCTAssertFalse(app.buttons["Hear hum"].exists)
        startLesson("Listen & match", in: app)
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        waitForRecord(in: app)
        XCTAssertEqual(target.label, hummingTarget)
        XCTAssertTrue(hear.isEnabled)
        XCTAssertFalse(app.buttons["Turn off camera and microphone"].exists)
        assertNoPermissionAlerts(in: app)
        screenshot("Humming · ready after leaving during playback")
    }

    func testMelodyReferencePlaysOnlyOnRequestAndStopsOnNavigation() {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyReference(in: app)
        let play = app.buttons["melodyPlayButton"]
        let status = app.descendants(matching: .any).matching(identifier: "melodyPlaybackStatus").firstMatch
        let key = app.staticTexts["melodyReferenceKey"]
        XCTAssertEqual(play.label, "Hear melody")
        XCTAssertFalse(status.exists, "Opening the melody must not start playback")
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists, "Melody recording is a separate delivery")
        XCTAssertFalse(app.buttons["previewTargetButton"].exists)
        XCTAssertFalse(app.buttons["Turn off camera and microphone"].exists)
        XCTAssertTrue(app.staticTexts["Recorded hum"].exists)
        XCTAssertTrue(key.label.contains("G major") && key.label.contains("G2–B2"))
        assertNoPermissionAlerts(in: app)
        assertNoWrittenInput(in: app)

        let registers = app.segmentedControls["melodyRegisterPicker"]
        XCTAssertFalse(registers.buttons["Higher voice"].exists, "The app offers one voice")
        registers.buttons["Cello"].tap()
        XCTAssertTrue(key.label.contains("D major") && key.label.contains("D3–F♯3"))
        registers.buttons["Low voice"].tap()
        XCTAssertEqual(play.label, "Hear melody", "Changing register must not autoplay")
        screenshot("Hot Cross Buns · whole melody and comfortable registers")

        play.tap()
        waitForMelodyButton("Stop", in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        let clockAdvanced = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@ AND NOT label CONTAINS %@", " / 0:16", "0:00 /"),
            object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [clockAdvanced], timeout: 5), .completed,
                       "The displayed position should advance with real playback")
        play.tap()
        waitForMelodyButton("Hear melody", in: app)
        XCTAssertFalse(status.exists)

        play.tap()
        waitForMelodyButton("Stop", in: app)
        app.navigationBars["Listen"].buttons.firstMatch.tap()
        openMelodyReference(in: app)
        waitForMelodyButton("Hear melody", in: app)
        XCTAssertFalse(status.exists, "Returning after Back must not resume the old reference")

        play.tap()
        waitForMelodyButton("Stop", in: app)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Music"].tap()
        waitForMelodyButton("Hear melody", in: app)
        XCTAssertFalse(status.exists, "Changing tabs must stop the melody")

        startLesson("Steady hum", in: app)
        assertReadyToRecord(in: app)
        waitForRecord(in: app)
        let hum = app.buttons["previewTargetButton"]
        XCTAssertTrue(hum.isHittable && hum.isEnabled)
        hum.tap()
        let listening = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Cancel"), object: app.buttons["practiceRecordButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [listening], timeout: 3), .completed,
                       "The existing human humming preview should still use the shared player")
        waitForRecord(in: app)
        XCTAssertFalse(app.staticTexts["captureMessage"].exists)
        assertNoPermissionAlerts(in: app)
    }

    func testEachLevelOnePrimerExplainsItsIdeaAndContinuesIntoItsLesson() {
        let app = XCUIApplication.cello(seenPrimers: "")
        app.launch()
        for (id, lesson, idea) in [("steadyHum", "Steady hum", "A note"), ("matchHum", "Listen & match", "Higher and lower"),
                                   ("pulse", "Pulse", "A beat"), ("twoTaps", "Two taps per beat", "Two taps per beat")] {
            app.pathLesson("lesson-\(id)").tap()
            let title = app.staticTexts["primerTitle"]
            XCTAssertTrue(title.waitForExistence(timeout: 5), "\(lesson) opens with its primer the first time")
            XCTAssertEqual(title.label, idea)
            let demo = app.buttons["primerDemoButton"]
            XCTAssertNotEqual(demo.label, "Stop", "A primer plays only on request")
            XCTAssertFalse(app.buttons["practiceRecordButton"].exists, "A primer never records")
            demo.tap()
            let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Stop"), object: demo)
            XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 3), .completed)
            if id == "pulse" {
                let count = app.staticTexts["primerCount"]
                let counted = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "3"), object: count)
                XCTAssertEqual(XCTWaiter.wait(for: [counted], timeout: 4), .completed, "The beats are counted one by one")
                screenshot("Primer · a beat")
            }
            assertNoPermissionAlerts(in: app)
            app.buttons["primerContinueButton"].tap()
            let heading = app.staticTexts["lessonDetailTitle"]
            XCTAssertTrue(heading.waitForExistence(timeout: 5))
            XCTAssertEqual(heading.label, lesson, "Continue leads into the lesson")

            // The primer can be reopened from the lesson page.
            app.buttons["lessonPrimerLink"].tap()
            XCTAssertTrue(title.waitForExistence(timeout: 5))
            XCTAssertEqual(title.label, idea)
            XCTAssertNotEqual(demo.label, "Stop", "Leaving a primer stops its sound")
            app.buttons["primerContinueButton"].tap()
            XCTAssertTrue(heading.waitForExistence(timeout: 5))
        }
        assertNoWrittenInput(in: app)
    }

    func testReadPrimersAreSkippedAndOtherLessonsHaveNone() {
        let app = XCUIApplication.cello()
        app.launch()
        for id in ["steadyHum", "mixedRhythm"] {
            app.pathLesson("lesson-\(id)").tap()
            XCTAssertTrue(app.staticTexts["lessonDetailTitle"].waitForExistence(timeout: 5))
            XCTAssertFalse(app.staticTexts["primerTitle"].exists)
            XCTAssertEqual(app.buttons["lessonPrimerLink"].exists, id == "steadyHum")
        }
    }

    func testMeetTheNotesListsThePieceNotesAndPlaysOneOnRequest() {
        let app = XCUIApplication.cello()
        app.launch()
        let step = app.pathLesson("lesson-hotCrossBuns-notes")
        XCTAssertTrue(step.label.contains("Lesson 3, Meet the notes"))
        XCTAssertTrue(step.label.contains("of 3 notes passed"))
        step.tap()
        XCTAssertTrue(app.navigationBars["Hot Cross Buns"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["screenTitle"].label, "Meet the notes")
        let record = app.buttons["practiceRecordButton"]
        let hear = app.buttons["previewTargetButton"]
        XCTAssertTrue(hear.label.hasPrefix("G2"), "The first note is on show")
        XCTAssertTrue(hear.label.contains("Hear note"))
        XCTAssertFalse(app.buttons["Hear note"].exists, "The chip is how a note is heard; there is no separate button")
        waitForRecord(in: app)
        XCTAssertEqual(record.label, "Record", "Opening the lesson must not play anything")
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists, "Opening the lesson must not invent a score")
        assertNoPermissionAlerts(in: app)

        // Every note is on show at once, and tapping one plays it.
        for title in ["A2", "B2", "G2 then B2 · going higher", "B2 then G2 · going lower"] {
            XCTAssertTrue(app.buttons["part-\(title)"].exists, "\(title) should be offered")
        }
        app.buttons["part-A2"].tap()
        let listening = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Cancel"), object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [listening], timeout: 4), .completed, "Choosing a note plays it")
        XCTAssertTrue(hear.label.hasPrefix("A2"))
        waitForRecord(in: app, timeout: 10)
        screenshot("Hot Cross Buns · meet the notes")

        // Tapping the note on show plays it again.
        hear.tap()
        let again = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Cancel"), object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [again], timeout: 3), .completed, "The chip on show replays its note")
        waitForRecord(in: app, timeout: 10)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists, "Hearing a note is not a take")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testHearingTheWholeMelodyToTheEndPassesListen() {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyReference(in: app, pieceID: "odeToJoy")
        app.buttons["melodyPlayButton"].tap()
        waitForMelodyButton("Stop", in: app)
        waitForMelodyButton("Hear melody", in: app, timeout: 25)
        app.navigationBars["Listen"].buttons.firstMatch.tap()
        let step = app.pathRow("lesson-odeToJoy-listen")
        XCTAssertTrue(step.label.contains("Listened"), "Playing the whole melody to its end passes Listen")
        let level = app.buttons["level-odeToJoy"]
        XCTAssertFalse(level.label.contains("0 of 5 lessons done"), "The level counts the passed lesson")
        app.terminate()
        app.launch()
        XCTAssertTrue(app.pathRow("lesson-odeToJoy-listen").label.contains("Listened"), "Listening survives relaunch")
        screenshot("Ode to Joy · Listen passed")
    }

    func testMelodyPhrasePlaybackFinishesAndCancelsWhenSelectionChanges() {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyReference(in: app)
        chooseListenPart("Phrase 3", in: app)
        let play = app.buttons["melodyPlayButton"]
        let status = app.descendants(matching: .any).matching(identifier: "melodyPlaybackStatus").firstMatch
        XCTAssertFalse(status.exists)
        screenshot("Hot Cross Buns · phrase 3 with eight quick notes")

        let startedAt = ProcessInfo.processInfo.systemUptime
        play.tap()
        waitForMelodyButton("Stop", in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        XCTAssertTrue(status.label.contains("Playing phrase 3"))
        XCTAssertTrue(status.label.contains("/ 0:04"))
        waitForMelodyButton("Hear phrase", in: app, timeout: 7)
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - startedAt, 3.8,
                                    "The four-beat phrase should play in real time at60BPM")
        XCTAssertFalse(status.exists)

        play.tap()
        waitForMelodyButton("Stop", in: app)
        app.segmentedControls["melodyRegisterPicker"].buttons["Cello"].tap()
        waitForMelodyButton("Hear phrase", in: app)
        XCTAssertFalse(status.exists, "A register change must cancel the previous reference")
        XCTAssertTrue(app.staticTexts["melodyReferenceKey"].label.contains("D3–F♯3"))

        play.tap()
        waitForMelodyButton("Stop", in: app)
        // Choosing another phrase stops this one and plays the one chosen.
        _ = choosePart("Phrase 1", in: app)
        let onPhraseOne = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label CONTAINS %@", "Playing phrase 1"), object: status)
        XCTAssertEqual(XCTWaiter.wait(for: [onPhraseOne], timeout: 5), .completed)
        play.tap()
        waitForMelodyButton("Hear phrase", in: app)
        XCTAssertFalse(status.exists)
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists)
        XCTAssertFalse(app.staticTexts["ratingStarCount"].exists)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testOdeToJoyReferenceRegistersPhrasePlaybackAndCancellation() {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyReference(in: app, pieceID: "odeToJoy")
        let play = app.buttons["melodyPlayButton"]
        let status = app.descendants(matching: .any).matching(identifier: "melodyPlaybackStatus").firstMatch
        let key = app.staticTexts["melodyReferenceKey"]
        let registers = app.segmentedControls["melodyRegisterPicker"]
        XCTAssertTrue(app.staticTexts["Level 3 · Ode to Joy"].exists)
        XCTAssertFalse(status.exists, "Opening Listen & follow must not play a reference")
        XCTAssertTrue(key.label.contains("G major") && key.label.contains("G2–D3"))
        registers.buttons["Cello"].tap()
        XCTAssertTrue(key.label.contains("D major") && key.label.contains("D3–A3"))
        XCTAssertTrue(key.label.contains("Recorded cello"))
        XCTAssertFalse(status.exists, "Changing register must not autoplay")

        chooseListenPart("Phrase 4", in: app)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", ", 1.5 beats")).count, 1)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", ", 0.5 beats")).count, 1)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label ENDSWITH %@", ", 2 beats")).count, 1)
        XCTAssertFalse(status.exists)
        screenshot("Ode to Joy · cello reference and three-note ending")
        let startedAt = ProcessInfo.processInfo.systemUptime
        play.tap()
        waitForMelodyButton("Stop", in: app)
        XCTAssertTrue(status.waitForExistence(timeout: 3))
        XCTAssertTrue(status.label.contains("Playing phrase 4") && status.label.contains("/ 0:04"))
        waitForMelodyButton("Hear phrase", in: app, timeout: 7)
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - startedAt, 3.8)
        XCTAssertFalse(status.exists)

        play.tap()
        waitForMelodyButton("Stop", in: app)
        registers.buttons["Low voice"].tap()
        waitForMelodyButton("Hear phrase", in: app)
        XCTAssertFalse(status.exists, "A register change cancels playback without starting a replacement")
        XCTAssertTrue(key.label.contains("G2–D3"))
        play.tap()
        waitForMelodyButton("Stop", in: app)
        app.navigationBars["Listen"].buttons.firstMatch.tap()
        openMelodyReference(in: app, pieceID: "odeToJoy")
        waitForMelodyButton("Hear melody", in: app)
        XCTAssertFalse(status.exists, "Returning after Back must not resume the previous reference")
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testOdeToJoyPathHummingRegistersAndManualReferenceStaySeparate() {
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        let foundationTarget = app.buttons["previewTargetButton"].label
        let foundationProgress = app.staticTexts["practiceProgressText"].label
        app.returnToPath()
        let level = app.buttons["level-odeToJoy"]
        app.scroll(to: level)
        XCTAssertTrue(level.label.contains("Level 3, Ode to Joy"))
        for step in ["listen", "tap", "notes", "hum", "whole"] {
            XCTAssertTrue(app.pathRow("lesson-odeToJoy-\(step)").isEnabled)
        }
        screenshot("Ode to Joy · five-note level")
        app.pathLesson("lesson-odeToJoy-hum").tap()
        XCTAssertTrue(app.navigationBars["Ode to Joy"].waitForExistence(timeout: 5))
        waitForRecord(in: app)
        let sections = app.buttons["previewTargetButton"]
        let duration = app.staticTexts["melodyTakeDuration"]
        let target = app.buttons["previewTargetButton"]
        XCTAssertFalse(app.segmentedControls["melodyHummingRegisterPicker"].exists, "Humming uses one voice")
        XCTAssertTrue(duration.label.contains("4 seconds") && duration.label.contains("60 BPM"))
        XCTAssertTrue(target.label.contains("G2–D3"), "The five-note piece must not inherit Hot Cross Buns’ smaller range")
        XCTAssertFalse(app.staticTexts["LISTEN"].exists)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists)
        screenshot("Ode to Joy · humming ready in the low voice")

        app.pathLesson("lesson-odeToJoy-whole").tap()
        waitForRecord(in: app)
        XCTAssertTrue(duration.label.contains("16 seconds"))
        XCTAssertTrue(app.buttons["previewTargetButton"].label.contains("Hear melody"))
        XCTAssertFalse(app.staticTexts["LISTEN"].exists)
        openMelodyHumming(in: app, pieceID: "odeToJoy")
        selectMelodyHummingSection("Phrase 4", in: app)
        XCTAssertTrue(target.label.contains("G2–D3"))
        XCTAssertTrue(duration.label.contains("4 seconds"))
        let hear = app.buttons["previewTargetButton"]
        reveal(hear, in: app)
        hear.tap()
        let listening = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Cancel"), object: app.buttons["practiceRecordButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [listening], timeout: 3), .completed)
        XCTAssertTrue(app.staticTexts["LISTEN"].exists)
        XCTAssertFalse(sections.isEnabled)
        screenshot("Ode to Joy · selected human reference locks the phrase")

        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Music"].tap()
        waitForRecord(in: app)
        XCTAssertTrue(target.label.contains("G2–D3"))
        XCTAssertFalse(app.staticTexts["LISTEN"].exists, "A hidden reference must not resume when returning")
        startLesson("Steady hum", in: app)
        waitForRecord(in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, foundationTarget)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, foundationProgress)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testOdeToJoyRecordDoesNotAutoplayOrInventFeedbackWithoutCapture() {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyHumming(in: app, pieceID: "odeToJoy")
        let record = app.buttons["practiceRecordButton"]
        record.tap()
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<2 {
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 1) {
                let allow = alert.buttons.matching(NSPredicate(format: "label == 'Allow' OR label == 'OK'")).firstMatch
                XCTAssertTrue(allow.exists)
                allow.tap()
            }
        }
        XCTAssertFalse(app.staticTexts["LISTEN"].exists, "Only Hear may play the reference")
        let message = app.staticTexts["captureMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 20), "Unavailable Simulator capture should return with an explanation")
        XCTAssertTrue(message.label.localizedCaseInsensitiveContains("camera")
                      || message.label.localizedCaseInsensitiveContains("microphone"))
        waitForRecord(in: app)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists)
        XCTAssertFalse(app.staticTexts["melodyRatingUnclear"].exists)
        XCTAssertTrue(app.navigationBars["Ode to Joy"].exists)
        screenshot("Ode to Joy · unavailable capture leaves progress unchanged")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testOdeToJoyRhythmUsesDottedEndingAndWholeMelodyPad() throws {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyRhythm(in: app, pieceID: "odeToJoy")
        XCTAssertEqual(app.staticTexts["melodyRhythmTapCount"].label, "0 / 4 starts · 0 extra")
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Note, 1 beats")).count, 4)
        selectMelodyRhythmSection("All phrases", in: app)
        XCTAssertTrue(app.staticTexts["melodyRhythmDuration"].label.contains("16 seconds"))
        for number in 1...4 { XCTAssertTrue(app.staticTexts["Phrase \(number)"].exists) }
        let progress = app.staticTexts["practiceProgressText"].label
        reveal(app.staticTexts["Phrase 4"], in: app)
        let start = app.buttons["melodyRhythmStartButton"]
        let tap = app.buttons["melodyRhythmTapButton"]
        start.tap()
        waitForMelodyRhythmButton("Stop", in: app)
        let padVisible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: tap)
        XCTAssertEqual(XCTWaiter.wait(for: [padVisible], timeout: 2), .completed)
        XCTAssertFalse(tap.isEnabled)
        XCTAssertEqual(app.staticTexts["melodyRhythmPhase"].label, "Count in", "Start begins the count-in without playing an example")
        XCTAssertTrue(app.staticTexts["Phrase 1"].exists)
        XCTAssertFalse(app.staticTexts["Phrase 4"].exists)
        XCTAssertEqual(app.staticTexts["melodyRhythmTapCount"].label, "0 / 15 starts · 0 extra")
        screenshot("Ode to Joy rhythm · whole opening count-in and visible pad")
        start.tap()
        waitForMelodyRhythmButton("Start", in: app)
        XCTAssertFalse(app.staticTexts["melodyRhythmUnscored"].exists)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, progress)

        selectMelodyRhythmSection("Phrase 4", in: app)
        XCTAssertTrue(app.staticTexts["Note, 1.5 beats"].exists)
        XCTAssertTrue(app.staticTexts["Note, 0.5 beats"].exists)
        XCTAssertTrue(app.staticTexts["Note, 2 beats"].exists)
        XCTAssertTrue(app.staticTexts["Tap on 1, the & after 2, and 3. Count 4 while the last note continues."].exists)
        screenshot("Ode to Joy rhythm · dotted ending explained before Start")
        let startedAt = ProcessInfo.processInfo.systemUptime
        start.tap()
        waitForMelodyRhythmButton("Stop", in: app)
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: tap)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 7), .completed)
        let deadline = ProcessInfo.processInfo.systemUptime + 6
        var touches = 0
        let pad = fixedPoint(at: tap, in: app)
        while isLive("melodyRhythmTapButton", in: app) && ProcessInfo.processInfo.systemUptime < deadline {
            pad.tap()
            touches += 1
            Thread.sleep(forTimeInterval: 0.12)
        }
        XCTAssertGreaterThanOrEqual(touches, 4)
        waitForMelodyRhythmButton("Try again", in: app)
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - startedAt, 7.8)
        let stars = app.staticTexts["melodyRhythmStars"]
        reveal(stars, in: app)
        XCTAssertTrue(stars.exists)
        XCTAssertTrue(app.navigationBars["Ode to Joy"].exists)
        for id in ["melodyRhythmPattern", "melodyRhythmTiming", "melodyRhythmConsistency"] {
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: id).firstMatch.exists)
        }
        let chart = app.descendants(matching: .any).matching(identifier: "melodyRhythmTimingChart").firstMatch
        reveal(chart, in: app)
        let counts = try melodyRhythmCounts(in: chart.label)
        XCTAssertEqual(counts.matched + counts.missed, 3, "The dotted ending has three expected starts")
        XCTAssertTrue(chart.label.contains("full 4 second phrase"))
        XCTAssertGreaterThanOrEqual(try extraTapCount(in: chart.label), 1)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, progress)
        screenshot("Ode to Joy rhythm · actual taps stars and timing chart")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testMelodyRhythmOpensFromMusicWithNoteLengthsAndManualReference() {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyRhythm(in: app)
        let sections = app.buttons["melodyRhythmHearButton"]
        let duration = app.staticTexts["melodyRhythmDuration"]
        let tap = app.buttons["melodyRhythmTapButton"]
        let progress = app.staticTexts["practiceProgressText"].label
        XCTAssertTrue(sections.isSelected)
        XCTAssertTrue(duration.label.contains("4 seconds") && duration.label.contains("60 BPM"))
        XCTAssertTrue(app.staticTexts["Note, 2 beats"].exists, "The last note continues for two beats")
        XCTAssertFalse(tap.exists, "The tap pad appears with the count-in, not before")
        XCTAssertEqual(app.staticTexts["melodyRhythmPhase"].label, "Ready")
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists, "Rhythm takes native taps without camera or microphone capture")
        selectMelodyRhythmSection("Phrase 3", in: app)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Note, 0.5 beats")).count, 8)
        XCTAssertFalse(tap.exists)
        selectMelodyRhythmSection("All phrases", in: app)
        XCTAssertTrue(duration.label.contains("16 seconds"))
        selectMelodyRhythmSection("Phrase 1", in: app)

        let hear = app.buttons["melodyRhythmHearButton"]
        reveal(hear, in: app)
        hear.tap()
        waitForMelodyRhythmButton("Cancel", in: app)
        XCTAssertEqual(app.staticTexts["melodyRhythmPhase"].label, "Listen")
        XCTAssertFalse(tap.exists)
        XCTAssertFalse(sections.isEnabled)
        screenshot("Hot Cross Buns rhythm · manual human reference")
        waitForMelodyRhythmButton("Start", in: app, timeout: 7)
        XCTAssertEqual(app.staticTexts["melodyRhythmPhase"].label, "Ready")
        XCTAssertFalse(tap.exists, "Finishing Hear must not start a tapping round")
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, progress)
        XCTAssertFalse(app.staticTexts["melodyRhythmStars"].exists)
        XCTAssertFalse(app.staticTexts["melodyRhythmUnscored"].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "melodyRhythmTimingChart").firstMatch.exists)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testMelodyRhythmRealClockRoundShowsStarsChartAndCountsContinuingNoteTapsAsExtra() throws {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyRhythm(in: app)
        let progress = app.staticTexts["practiceProgressText"].label
        let tap = app.buttons["melodyRhythmTapButton"]
        let startedAt = ProcessInfo.processInfo.systemUptime
        app.buttons["melodyRhythmStartButton"].tap()
        waitForMelodyRhythmButton("Stop", in: app)
        XCTAssertFalse(tap.isEnabled, "Four real count-in beats come before tapping")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: tap)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 7), .completed)

        // Exercise real native touches, including beat four while the final
        // half note continues. The production clock and touches determine stars.
        let deadline = ProcessInfo.processInfo.systemUptime + 6
        var touches = 0
        var continuingNoteTouches = 0
        let pad = fixedPoint(at: tap, in: app)
        while isLive("melodyRhythmTapButton", in: app) && ProcessInfo.processInfo.systemUptime < deadline {
            // One query, so the count vanishing at the end of the round cannot fail the read.
            let onBeatFour = app.staticTexts.matching(NSPredicate(format: "identifier == %@ AND label == %@",
                                                                  "melodyRhythmBeat", "4")).count > 0
            pad.tap()
            touches += 1
            if onBeatFour { continuingNoteTouches += 1 }
            Thread.sleep(forTimeInterval: 0.12)
        }
        XCTAssertGreaterThanOrEqual(touches, 4)
        XCTAssertGreaterThanOrEqual(continuingNoteTouches, 1, "Beat four remains open for taps, which are extra rather than a fourth note")
        waitForMelodyRhythmButton("Try again", in: app)
        XCTAssertGreaterThanOrEqual(ProcessInfo.processInfo.systemUptime - startedAt, 7.8,
                                    "The full four-second phrase follows the four-second count-in")
        let stars = app.staticTexts["melodyRhythmStars"]
        reveal(stars, in: app)
        XCTAssertTrue(stars.exists)
        for id in ["melodyRhythmPattern", "melodyRhythmTiming", "melodyRhythmConsistency"] {
            XCTAssertTrue(app.descendants(matching: .any).matching(identifier: id).firstMatch.exists)
        }
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "melodyRhythmPattern").firstMatch.label.contains("keep practising"))
        XCTAssertTrue(app.staticTexts["melodyRhythmFeedback"].exists)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, progress, "Extra taps cannot earn a successful round")
        XCTAssertFalse(tap.exists)
        let chart = app.descendants(matching: .any).matching(identifier: "melodyRhythmTimingChart").firstMatch
        reveal(chart, in: app)
        XCTAssertTrue(chart.isHittable)
        let counts = try melodyRhythmCounts(in: chart.label)
        XCTAssertEqual(counts.matched + counts.missed, 3, "The continuing fourth beat is not a missing note start")
        XCTAssertGreaterThanOrEqual(try extraTapCount(in: chart.label), 1)
        XCTAssertTrue(chart.label.contains("full 4 second phrase"))
        screenshot("Hot Cross Buns rhythm · real taps and full-phrase chart")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testMelodyRhythmWholeMelodyKeepsTapPadVisibleDuringCountInAndPractice() {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyRhythm(in: app)
        selectMelodyRhythmSection("Phrase 3", in: app)
        XCTAssertEqual(app.staticTexts.matching(NSPredicate(format: "label == %@", "Note, 0.5 beats")).count, 8)
        selectMelodyRhythmSection("All phrases", in: app)
        XCTAssertTrue(app.staticTexts["melodyRhythmDuration"].label.contains("16 seconds"))
        let progress = app.staticTexts["practiceProgressText"].label
        for number in 1...4 {
            XCTAssertTrue(app.staticTexts["Phrase \(number)"].exists, "The ready preview includes all four phrases")
        }
        reveal(app.staticTexts["Phrase 4"], in: app)
        screenshot("Hot Cross Buns rhythm · whole melody preview")
        let start = app.buttons["melodyRhythmStartButton"]
        let tap = app.buttons["melodyRhythmTapButton"]
        XCTAssertTrue(start.isHittable, "Start remains reachable below the full preview")
        start.tap()
        waitForMelodyRhythmButton("Stop", in: app)
        let padVisible = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: tap)
        XCTAssertEqual(XCTWaiter.wait(for: [padVisible], timeout: 2), .completed,
                       "Starting automatically brings the pattern and pad into view")
        XCTAssertFalse(tap.isEnabled)
        XCTAssertTrue(start.isHittable)
        XCTAssertTrue(app.staticTexts["Phrase 1"].exists)
        for number in 2...4 {
            XCTAssertFalse(app.staticTexts["Phrase \(number)"].exists, "Only the active phrase occupies space during a round")
        }
        screenshot("Hot Cross Buns rhythm · whole melody count-in and visible pad")
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: tap)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 7), .completed)
        XCTAssertTrue(tap.isHittable, "The active whole-melody pad needs no manual scrolling")
        XCTAssertTrue(start.isHittable)
        tap.tap()
        let accepted = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "exists == true AND label != %@", "0 / 17 starts · 0 extra"),
            object: app.staticTexts["melodyRhythmTapCount"])
        XCTAssertEqual(XCTWaiter.wait(for: [accepted], timeout: 2), .completed)
        screenshot("Hot Cross Buns rhythm · whole melody live tapping")
        start.tap()
        waitForMelodyRhythmButton("Start", in: app)
        XCTAssertFalse(app.staticTexts["melodyRhythmStars"].exists)
        XCTAssertFalse(app.staticTexts["melodyRhythmUnscored"].exists)
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "melodyRhythmTimingChart").firstMatch.exists)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, progress)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testMelodyRhythmStopAndBackgroundDiscardUnfinishedRounds() {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyRhythm(in: app)
        let progress = app.staticTexts["practiceProgressText"].label
        let start = app.buttons["melodyRhythmStartButton"]
        let tap = app.buttons["melodyRhythmTapButton"]
        start.tap()
        waitForMelodyRhythmButton("Stop", in: app)
        start.tap()
        waitForMelodyRhythmButton("Start", in: app)
        XCTAssertFalse(app.staticTexts["melodyRhythmStars"].exists)
        XCTAssertFalse(app.staticTexts["melodyRhythmUnscored"].exists)

        start.tap()
        let enabled = XCTNSPredicateExpectation(predicate: NSPredicate(format: "enabled == true"), object: tap)
        XCTAssertEqual(XCTWaiter.wait(for: [enabled], timeout: 7), .completed)
        tap.tap()
        XCUIDevice.shared.press(.home)
        app.activate()
        waitForMelodyRhythmButton("Start", in: app)
        XCTAssertEqual(app.staticTexts["melodyRhythmPhase"].label, "Ready")
        XCTAssertFalse(tap.exists)
        XCTAssertFalse(app.staticTexts["melodyRhythmStars"].exists)
        XCTAssertFalse(app.staticTexts["melodyRhythmUnscored"].exists, "An interrupted round must not create even an unscored attempt")
        XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "melodyRhythmTimingChart").firstMatch.exists)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, progress)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testMelodyHummingHasSeparatePhrasesRegistersAndManualReference() {
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        let foundationTarget = app.buttons["previewTargetButton"].label
        let foundationProgress = app.staticTexts["practiceProgressText"].label
        openMelodyHumming(in: app)
        let sections = app.buttons["previewTargetButton"]
        let duration = app.staticTexts["melodyTakeDuration"]
        let target = app.buttons["previewTargetButton"]
        XCTAssertFalse(app.segmentedControls["melodyHummingRegisterPicker"].exists, "Humming uses one voice")
        XCTAssertFalse(app.buttons["Higher voice"].exists)
        XCTAssertTrue(sections.isSelected)
        XCTAssertTrue(duration.label.contains("4 seconds") && duration.label.contains("60 BPM"))
        XCTAssertTrue(target.label.contains("G2–B2"))
        XCTAssertFalse(app.staticTexts["LISTEN"].exists)
        XCTAssertFalse(app.buttons["Turn off camera and microphone"].exists)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists)
        assertNoPermissionAlerts(in: app)
        screenshot("Hot Cross Buns · humming ready for phrase 1")

        app.pathLesson("lesson-hotCrossBuns-whole").tap()
        waitForRecord(in: app)
        XCTAssertTrue(duration.label.contains("16 seconds"), "Whole-melody takes must not use the three-second foundation limit")
        XCTAssertTrue(app.buttons["previewTargetButton"].label.contains("Hear melody"))
        XCTAssertFalse(app.staticTexts["LISTEN"].exists, "Opening a lesson must not autoplay")
        openMelodyHumming(in: app)
        selectMelodyHummingSection("Phrase 3", in: app)
        XCTAssertTrue(duration.label.contains("4 seconds"))
        XCTAssertTrue(target.label.contains("G2–B2"))
        waitForRecord(in: app)
        let hear = app.buttons["previewTargetButton"]
        reveal(hear, in: app)
        hear.tap()
        let previewing = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Cancel"), object: app.buttons["practiceRecordButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [previewing], timeout: 3), .completed)
        XCTAssertTrue(app.staticTexts["LISTEN"].exists)
        XCTAssertFalse(sections.isEnabled, "The reference cannot change during playback or a take")
        screenshot("Hot Cross Buns · hearing the selected humming phrase")

        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Music"].tap()
        waitForRecord(in: app)
        XCTAssertTrue(target.label.contains("G2–B2"))
        XCTAssertFalse(app.staticTexts["LISTEN"].exists, "Returning to Humming must not resume playback")
        startLesson("Steady hum", in: app)
        waitForRecord(in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, foundationTarget)
        XCTAssertEqual(app.staticTexts["practiceProgressText"].label, foundationProgress)
        XCTAssertFalse(app.staticTexts["captureMessage"].exists)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testMelodyRecordDoesNotAutoplayAndUnavailableCaptureDoesNotCreateFeedback() {
        let app = XCUIApplication.cello()
        app.launch()
        openMelodyHumming(in: app)
        let record = app.buttons["practiceRecordButton"]
        XCTAssertEqual(record.label, "Record")
        record.tap()
        // Camera/microphone consent follows the explicit Record action. A real
        // Simulator has no camera; this exercises its recoverable error, rather
        // than adding an app-only camera or scoring fixture.
        let springboard = XCUIApplication(bundleIdentifier: "com.apple.springboard")
        for _ in 0..<2 {
            let alert = springboard.alerts.firstMatch
            if alert.waitForExistence(timeout: 1) {
                let allow = alert.buttons.matching(NSPredicate(format: "label == 'Allow' OR label == 'OK'")).firstMatch
                XCTAssertTrue(allow.exists, "Only explicit camera/microphone permission alerts are expected")
                allow.tap()
            }
        }
        XCTAssertFalse(app.staticTexts["LISTEN"].exists, "Record must never play the reference first")
        let message = app.staticTexts["captureMessage"]
        XCTAssertTrue(message.waitForExistence(timeout: 20), "Unavailable capture must leave Preparing with an explanation")
        XCTAssertTrue(message.label.localizedCaseInsensitiveContains("camera")
                      || message.label.localizedCaseInsensitiveContains("microphone"))
        waitForRecord(in: app)
        XCTAssertTrue(record.isEnabled)
        XCTAssertFalse(app.staticTexts["melodyRatingStars"].exists)
        XCTAssertFalse(app.staticTexts["melodyRatingUnclear"].exists, "No take means no invented assessment")
        screenshot("Hot Cross Buns · camera unavailable without a fabricated result")
        openMelodyHumming(in: app)
        waitForRecord(in: app)
        XCTAssertFalse(app.staticTexts["LISTEN"].exists)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testLessonsOpenBothGuidedHummingActivities() {
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        assertReadyToRecord(in: app)
        let target = app.buttons["previewTargetButton"].label
        openLessons(in: app)
        assertNoWrittenInput(in: app)
        screenshot("Lessons · humming library")
        openLesson("steadyHum", title: "Steady hum", in: app)
        screenshot("Lessons · steady hum instructions")
        app.buttons["startLessonButton"].tap()
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["practiceLessonArea"].label, "Level 1 · First sounds")
        XCTAssertEqual(app.staticTexts["practiceLessonTitle"].label, "Steady hum")
        XCTAssertEqual(app.buttons["previewTargetButton"].label, target)
        assertReadyToRecord(in: app)
        assertNoWrittenInput(in: app)

        openLessons(in: app)
        openLesson("matchHum", title: "Listen & match", in: app)
        screenshot("Lessons · listening and matching instructions")
        app.buttons["startLessonButton"].tap()
        XCTAssertTrue(app.navigationBars["Humming"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["practiceLessonArea"].label, "Level 1 · First sounds")
        XCTAssertEqual(app.staticTexts["practiceLessonTitle"].label, "Listen & match")
        XCTAssertEqual(app.buttons["previewTargetButton"].label, target)
        assertReadyToRecord(in: app)
        assertNoWrittenInput(in: app)
        screenshot("Humming · listen and match")

        // The lesson bar moves back and forward inside the level.
        XCTAssertEqual(app.staticTexts["lessonPosition"].label, "Lesson 2 of 6")
        let previous = app.buttons["previousLessonButton"]
        XCTAssertEqual(previous.label, "Previous lesson, Steady hum")
        previous.tap()
        let title = app.staticTexts["practiceLessonTitle"]
        let onFirst = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Steady hum"), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [onFirst], timeout: 5), .completed)
        XCTAssertEqual(app.staticTexts["lessonPosition"].label, "Lesson 1 of 6")
        XCTAssertFalse(previous.isEnabled, "The first lesson of a level has no previous lesson")
        XCTAssertEqual(app.buttons["previewTargetButton"].label, target)
        screenshot("Steady hum · lesson bar at the first lesson")

        // Back from practice returns straight to the path.
        app.navigationBars["Humming"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["level-firstSounds"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["lessonDetailTitle"].exists)
    }

    func testPathKeepsEveryLessonOpenWithItsOwnTarget() {
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        let hummingTarget = app.buttons["previewTargetButton"].label
        XCTAssertFalse(app.buttons["How to practise"].exists)
        XCTAssertFalse(app.buttons["How to practice"].exists)
        app.returnToPath()
        XCTAssertFalse(app.descendants(matching: .any)["lessonInstruction"].exists)
        for (step, id, title) in [(1, "steadyHum", "Steady hum"), (2, "matchHum", "Listen & match"),
                                  (3, "pulse", "Pulse"), (4, "twoTaps", "Two taps per beat")] {
            assertAvailableLesson(id, step: step, title: title, in: app)
        }
        screenshot("Music · Level 1 lessons")
        openLesson("matchHum", title: "Listen & match", in: app)
        XCTAssertTrue(app.descendants(matching: .any)["lessonInstruction"].exists)
        assertNoWrittenInput(in: app)

        assertAvailableLesson("mixedRhythm", step: 5, title: "Mixed rhythm", in: app)
        for (step, id, title) in [(2, "openC", "Open C string"), (3, "openG", "Open G string"),
                                  (4, "openD", "Open D string"), (5, "openA", "Open A string")] {
            assertAvailableLesson(id, step: step, title: title, in: app)
        }
        screenshot("Music · the cello level")
        openLesson("openC", title: "Open C string", in: app)
        app.buttons["startLessonButton"].tap()
        XCTAssertTrue(app.navigationBars["Cello"].waitForExistence(timeout: 5))
        XCTAssertEqual(app.staticTexts["practiceLessonArea"].label, "Level 4 · Cello · open strings")
        let celloTarget = app.buttons["previewTargetButton"].label
        XCTAssertTrue(celloTarget.contains("C2") && celloTarget.contains("65.4"))
        assertReadyToRecord(in: app)
        startLesson("Open C string", in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, celloTarget)
        startLesson("Steady hum", in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, hummingTarget)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testPulseRunsCountInAndShowsDescriptiveTapFeedback() {
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        let target = app.buttons["previewTargetButton"].label
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
        let pad = fixedPoint(at: tap, in: app)
        let deadline = ProcessInfo.processInfo.systemUptime + 22
        var tookReleasedScreenshot = false
        while !app.buttons["Try again"].exists && ProcessInfo.processInfo.systemUptime < deadline {
            if isLive("pulseTapButton", in: app) {
                pad.tap()
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
        XCTAssertTrue(app.navigationBars["Rhythm"].exists)
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

        startLesson("Steady hum", in: app)
        XCTAssertEqual(app.staticTexts["practiceLessonArea"].label, "Level 1 · First sounds")
        XCTAssertEqual(app.buttons["previewTargetButton"].label, target)
        assertReadyToRecord(in: app)
    }

    func testListenAndMatchCanContinueAcrossAreasAndCancelUnfinishedRhythm() throws {
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        startLesson("Listen & match", in: app)
        let target = app.buttons["previewTargetButton"].label
        let progress = app.staticTexts["practiceProgressText"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5))
        guard !progress.label.contains("Goal reached") else {
            throw XCTSkip("Requires Listen & match to be incomplete to verify advancing before completion")
        }
        let next = app.buttons["nextLessonButton"]
        app.scroll(to: next)
        XCTAssertTrue(next.isEnabled)
        XCTAssertEqual(next.label, "Next lesson, Pulse")
        next.tap()
        assertInlinePulseReady(in: app)
        XCTAssertFalse(app.buttons["previewTargetButton"].exists)
        screenshot("Rhythm · next action from humming")

        // Back during a count-in leaves the round and returns to the path; the
        // lesson starts a fresh one.
        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 5))
        app.navigationBars["Rhythm"].buttons.firstMatch.tap()
        XCTAssertTrue(app.buttons["level-firstSounds"].waitForExistence(timeout: 5),
                      "Back from practice returns to the path")
        startLesson("Pulse", in: app)
        assertInlinePulseReady(in: app)
        let pulseProgress = progress.label

        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        app.tabBars.buttons["Music"].tap()
        assertInlinePulseReady(in: app)
        XCTAssertEqual(progress.label, pulseProgress, "Leaving during the count-in must not earn progress")

        app.buttons["Start"].tap()
        XCTAssertTrue(app.buttons["Stop"].waitForExistence(timeout: 5))
        openLessons(in: app)
        openLesson("pulse", title: "Pulse", in: app)
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app)
        XCTAssertEqual(progress.label, pulseProgress, "Opening Music during count-in must not earn progress")
        XCTAssertFalse(app.staticTexts["lessonDetailTitle"].exists)
        startLesson("Listen & match", in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, target)
        assertReadyToRecord(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testArchivedCompletedPulseCanContinueToLessonFourWithoutChangingEarlierProgress() throws {
        try requireRecordingFixtures()
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        let voiceTarget = app.buttons["previewTargetButton"].label
        startLesson("Pulse", in: app)
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
        let pulse = app.pathRow("lesson-pulse")
        XCTAssertTrue(pulse.label.contains("Gold"))
        XCTAssertTrue(pulse.label.contains("Best score 3 of 3 stars"))
        openLesson("pulse", title: "Pulse", in: app)
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app)
        let next = app.buttons["nextLessonButton"]
        app.scroll(to: next)
        XCTAssertTrue(next.isEnabled)
        XCTAssertEqual(next.label, "Next lesson, Two taps per beat")
        screenshot("Pulse · earned completion recommends Lesson 4")
        next.tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertEqual(app.buttons["nextLessonButton"].label, "Next lesson, Mixed rhythm")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
        screenshot("Lesson 4 · inline from completed Pulse")

        startLesson("Pulse", in: app)
        assertInlinePulseReady(in: app)
        XCTAssertEqual(progress.label, completedPulse, "Opening the new lesson must preserve earned Pulse completion")
        startLesson("Steady hum", in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, voiceTarget)
        assertReadyToRecord(in: app)
    }

    func testLessonFourRunsTwoTapsPerBeatInlineAndKeepsItsOwnProgress() throws {
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        let voiceTarget = app.buttons["previewTargetButton"].label
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        let recordingIDs = visibleRecordingIDs(in: app)
        startLesson("Pulse", in: app)
        assertInlinePulseReady(in: app)
        let pulseProgress = app.staticTexts["practiceProgressText"].label

        openLessons(in: app)
        openLesson("twoTaps", title: "Two taps per beat", in: app)
        screenshot("Lessons · two taps per beat instructions")
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists)
        XCTAssertFalse(app.buttons["previewTargetButton"].exists, "A tap lesson should not show a voice target")
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
        let pad = fixedPoint(at: tap, in: app)
        let deadline = ProcessInfo.processInfo.systemUptime + 14
        var actualTouches = 0
        while !app.buttons["Try again"].exists && ProcessInfo.processInfo.systemUptime < deadline {
            if isLive("pulseTapButton", in: app) {
                pad.tap()
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
        startLesson("Pulse", in: app)
        assertInlinePulseReady(in: app)
        XCTAssertEqual(progress.label, pulseProgress, "A Lesson 4 round must not change Lesson 3 progress")
        app.terminate()
        launchPractice(in: app)
        assertReadyToRecord(in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, voiceTarget)
        startLesson("Two taps per beat", in: app)
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertEqual(progress.label, twoTapsProgress, "Lesson 4 should retain its own saved progress")
        openLessons(in: app)
        openLesson("twoTaps", title: "Two taps per beat", in: app)
        let latest = app.descendants(matching: .any).matching(identifier: "lessonLatestScore").firstMatch
        reveal(latest, in: app)
        XCTAssertTrue(latest.label.contains(savedStars), "The lesson book should show this actual round's saved rating")
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        startLesson("Steady hum", in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, voiceTarget)
        assertReadyToRecord(in: app)
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        XCTAssertEqual(visibleRecordingIDs(in: app), recordingIDs, "Tap practice must not create an audio/video recording")
    }

    func testArchivedCompletedLessonFourCanContinueToMixedRhythm() throws {
        try requireRecordingFixtures()
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        startLesson("Two taps per beat", in: app)
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        let progress = app.staticTexts["practiceProgressText"]
        // Optional setup: copy completed production TwoTapsPractice.json from
        // a private archive into Simulator Documents, without changing grades.
        guard progress.label.contains("Goal reached") else {
            throw XCTSkip("Requires externally copied completed Lesson 4 practice history")
        }
        let completed = progress.label
        let next = app.buttons["nextLessonButton"]
        app.scroll(to: next)
        XCTAssertEqual(next.label, "Next lesson, Mixed rhythm")
        next.tap()
        assertInlinePulseReady(in: app, title: "Mixed rhythm")
        XCTAssertEqual(app.buttons["nextLessonButton"].label, "Next lesson, Listen & Echo")
        XCTAssertTrue(app.descendants(matching: .any).matching(identifier: "mixedRhythmInstructions").firstMatch.isHittable)
        screenshot("Lesson 5 · continue from completed Lesson 4")
        startLesson("Two taps per beat", in: app)
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertEqual(progress.label, completed, "Opening Lesson 5 must preserve earned Lesson 4 completion")
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testMixedRhythmRunsInlineAndKeepsPatternScoreAndProgressSeparate() throws {
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        let voiceTarget = app.buttons["previewTargetButton"].label
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        let recordingIDs = visibleRecordingIDs(in: app)
        startLesson("Two taps per beat", in: app)
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
        XCTAssertFalse(app.buttons["previewTargetButton"].exists)
        XCTAssertFalse(app.buttons["practiceRecordButton"].exists)
        XCTAssertEqual(app.buttons["nextLessonButton"].label, "Next lesson, Listen & Echo")
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
        let pad = fixedPoint(at: tap, in: app)
        let deadline = ProcessInfo.processInfo.systemUptime + 14
        var actualTouches = 0
        while !app.buttons["Try again"].exists && ProcessInfo.processInfo.systemUptime < deadline {
            if isLive("pulseTapButton", in: app) {
                pad.tap()
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

        // Starting the same finished lesson through Music must create a fresh
        // practice screen while preserving its measured score and progression.
        scrollToPracticeTop(in: app)
        openLessons(in: app)
        openLesson("mixedRhythm", title: "Mixed rhythm", in: app)
        let sameLessonLatest = app.descendants(matching: .any).matching(identifier: "lessonLatestScore").firstMatch
        XCTAssertTrue(sameLessonLatest.label.contains(savedStars))
        app.buttons["startLessonButton"].tap()
        assertInlinePulseReady(in: app, title: "Mixed rhythm")
        XCTAssertFalse(result.exists, "Music should restart the selected lesson rather than retain its old inline result")
        XCTAssertFalse(chart.exists)
        XCTAssertEqual(progress.label, mixedProgress, "Restarting must not change earned progress")
        screenshot("Lesson 5 · fresh practice from the same finished lesson")

        scrollToPracticeTop(in: app)
        startLesson("Two taps per beat", in: app)
        assertInlinePulseReady(in: app, title: "Two taps per beat")
        XCTAssertEqual(progress.label, earlierProgress)
        app.terminate()
        launchPractice(in: app)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, voiceTarget)
        startLesson("Mixed rhythm", in: app)
        assertInlinePulseReady(in: app, title: "Mixed rhythm")
        XCTAssertEqual(progress.label, mixedProgress)
        openLessons(in: app)
        openLesson("mixedRhythm", title: "Mixed rhythm", in: app)
        let latest = app.descendants(matching: .any).matching(identifier: "lessonLatestScore").firstMatch
        reveal(latest, in: app)
        XCTAssertTrue(latest.label.contains(savedStars))
        screenshot("Lessons · mixed rhythm score after relaunch")
        app.tabBars.buttons["Recordings"].tap()
        XCTAssertTrue(app.navigationBars["Recordings"].waitForExistence(timeout: 5))
        XCTAssertEqual(visibleRecordingIDs(in: app), recordingIDs)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    func testProgressSuggestsNextExerciseWithoutLockingPractice() {
        let app = XCUIApplication.cello()
        launchPractice(in: app)
        assertReadyToRecord(in: app)
        let target = app.buttons["previewTargetButton"].label
        let progress = app.staticTexts["practiceProgressText"]
        XCTAssertTrue(progress.waitForExistence(timeout: 5), "Progress should be available before microphone setup")
        let next = app.buttons["nextLessonButton"]
        app.scroll(to: next)
        XCTAssertTrue(next.isEnabled, "The next exercise must remain available before its predecessor is completed")
        XCTAssertFalse(app.buttons["Turn off camera and microphone"].exists)
        assertNoPermissionAlerts(in: app)
        screenshot("Humming · progress and optional next exercise")

        next.tap()
        let title = app.staticTexts["practiceLessonTitle"]
        let changed = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", "Listen & match"), object: title)
        XCTAssertEqual(XCTWaiter.wait(for: [changed], timeout: 5), .completed)
        XCTAssertEqual(app.buttons["previewTargetButton"].label, target)
        XCTAssertTrue(progress.exists)
        scrollToPracticeTop(in: app)
        assertReadyToRecord(in: app)

        for id in ["steadyHum", "matchHum", "pulse", "twoTaps", "mixedRhythm", "openC", "openG", "openD", "openA"] {
            XCTAssertTrue(app.pathRow("lesson-\(id)").isEnabled, "No lesson is locked by earlier progress")
        }
        openLesson("openG", title: "Open G string", in: app)
        app.buttons["startLessonButton"].tap()
        assertReadyToRecord(in: app)
        assertNoWrittenInput(in: app)
        assertNoPermissionAlerts(in: app)
    }

    /// Launches into the first foundation lesson's practice screen.
    private func launchPractice(in app: XCUIApplication) {
        app.launch()
        XCTAssertTrue(app.tabBars.buttons["Music"].waitForExistence(timeout: 5))
        startLesson("Steady hum", in: app)
    }

    private func openMelodyReference(in app: XCUIApplication, pieceID: String = "hotCrossBuns") {
        app.pathLesson("lesson-\(pieceID)-listen").tap()
        XCTAssertTrue(app.navigationBars["Listen"].waitForExistence(timeout: 5))
        waitForMelodyButton("Hear melody", in: app)
    }

    private func openMelodyHumming(in app: XCUIApplication, pieceID: String = "hotCrossBuns") {
        app.pathLesson("lesson-\(pieceID)-hum").tap()
        XCTAssertTrue(app.navigationBars[melodyTitle(for: pieceID)].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["previewTargetButton"].waitForExistence(timeout: 5))
        waitForRecord(in: app)
    }

    private func melodyTitle(for pieceID: String) -> String {
        pieceID == "odeToJoy" ? "Ode to Joy" : "Hot Cross Buns"
    }

    /// Taps a part's chip, such as "Phrase 3" or "A2", wherever its lesson shows
    /// them. Returns false when that part is already on show, which a tap would replay.
    @discardableResult
    private func choosePart(_ title: String, in app: XCUIApplication) -> Bool {
        let chip = app.buttons["part-\(title)"]
        guard chip.waitForExistence(timeout: 2) else { return false }
        for _ in 0..<5 where !chip.isHittable { app.scrollViews.firstMatch.swipeDown() }
        XCTAssertTrue(chip.isHittable)
        chip.tap()
        return true
    }

    /// Chooses a phrase to hum. Choosing plays it; the test then cancels the sound.
    private func selectMelodyHummingSection(_ title: String, in app: XCUIApplication) {
        if choosePart(title, in: app) {
            let record = app.buttons["practiceRecordButton"]
            let playing = XCTNSPredicateExpectation(predicate: NSPredicate(format: "label == %@", "Cancel"), object: record)
            XCTAssertEqual(XCTWaiter.wait(for: [playing], timeout: 4), .completed, "Choosing a phrase plays it")
            record.tap()
        }
        waitForRecord(in: app)
    }

    /// Chooses a part on Listen. Choosing plays it; the test then stops the sound.
    private func chooseListenPart(_ title: String, in app: XCUIApplication) {
        XCTAssertTrue(choosePart(title, in: app))
        waitForMelodyButton("Stop", in: app)
        app.buttons["melodyPlayButton"].tap()
        waitForMelodyButton(title == "Whole melody" ? "Hear melody" : "Hear phrase", in: app)
    }

    private func openMelodyRhythm(in app: XCUIApplication, pieceID: String = "hotCrossBuns") {
        app.pathLesson("lesson-\(pieceID)-tap").tap()
        XCTAssertTrue(app.navigationBars[melodyTitle(for: pieceID)].waitForExistence(timeout: 5))
        waitForMelodyRhythmButton("Start", in: app)
    }

    /// Chooses a part to tap. Choosing plays it; the test then cancels the sound.
    private func selectMelodyRhythmSection(_ title: String, in app: XCUIApplication) {
        if choosePart(title, in: app) {
            waitForMelodyRhythmButton("Cancel", in: app)
            app.buttons["melodyRhythmStartButton"].tap()
        }
        waitForMelodyRhythmButton("Start", in: app)
    }

    private func waitForMelodyRhythmButton(_ label: String, in app: XCUIApplication, timeout: TimeInterval = 5) {
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ AND enabled == true", label), object: app.buttons["melodyRhythmStartButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed)
    }

    private func waitForMelodyButton(_ label: String, in app: XCUIApplication, timeout: TimeInterval = 5) {
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ AND enabled == true", label), object: app.buttons["melodyPlayButton"])
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed)
    }

    private func lessonID(forTitle title: String) -> String {
        switch title {
        case "Steady hum": return "steadyHum"
        case "Listen & match": return "matchHum"
        case "Pulse": return "pulse"
        case "Two taps per beat": return "twoTaps"
        case "Mixed rhythm": return "mixedRhythm"
        case "Open C string": return "openC"
        case "Open G string": return "openG"
        case "Open D string": return "openD"
        default: return "openA"
        }
    }

    /// Opens a lesson's practice screen the way a learner does: the path, the
    /// lesson page, then Start.
    private func startLesson(_ title: String, in app: XCUIApplication) {
        openLesson(lessonID(forTitle: title), title: title, in: app)
        app.buttons["startLessonButton"].tap()
        let heading = app.staticTexts["practiceLessonTitle"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, title)
    }

    private func assertReadyToRecord(in app: XCUIApplication) {
        let record = app.buttons["practiceRecordButton"]
        XCTAssertTrue(record.waitForExistence(timeout: 5))
        XCTAssertTrue(record.isHittable, "Record must be visible before microphone input")
        XCTAssertTrue(record.isEnabled, "Record must not require a warm-up hum")
        XCTAssertTrue(app.buttons["previewTargetButton"].exists)
        XCTAssertFalse(app.buttons["Enable camera & microphone"].exists)
    }

    private func assertInlinePulseHeader(in app: XCUIApplication, title: String = "Pulse") {
        XCTAssertTrue(app.navigationBars["Rhythm"].waitForExistence(timeout: 5))
        let heading = app.staticTexts["practiceLessonTitle"]
        let selected = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@", title), object: heading)
        XCTAssertEqual(XCTWaiter.wait(for: [selected], timeout: 5), .completed)
        let headerReady = XCTNSPredicateExpectation(predicate: NSPredicate(format: "hittable == true"), object: heading)
        XCTAssertEqual(XCTWaiter.wait(for: [headerReady], timeout: 5), .completed)
        XCTAssertEqual(app.staticTexts["practiceLessonArea"].label, "Level 1 · First sounds")
        for tab in ["Music", "Recordings", "About"] { XCTAssertTrue(app.tabBars.buttons[tab].isHittable) }
        XCTAssertFalse(app.navigationBars[title].exists, "The lesson should share the Rhythm practice screen")
        XCTAssertFalse(app.navigationBars.buttons["Done"].exists)
        assertNoPulseHapticsSwitches(in: app)
    }

    private func assertInlinePulseReady(in app: XCUIApplication, title: String = "Pulse") {
        assertInlinePulseHeader(in: app, title: title)
        XCTAssertTrue(app.buttons["Start"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.buttons["Start"].isEnabled)
        XCTAssertFalse(app.buttons["pulseTapButton"].exists, "The tap pad appears with the count-in, not before")
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

    private func melodyRhythmCounts(in summary: String) throws -> (matched: Int, missed: Int) {
        let text = summary as NSString
        let expression = try NSRegularExpression(pattern: "(\\d+) matched taps:.*?, (\\d+) missed note starts")
        let match = try XCTUnwrap(expression.firstMatch(in: summary, range: NSRange(location: 0, length: text.length)))
        let matched = try XCTUnwrap(Int(text.substring(with: match.range(at: 1))))
        let missed = try XCTUnwrap(Int(text.substring(with: match.range(at: 2))))
        return (matched, missed)
    }

    private func waitForRecord(in app: XCUIApplication, timeout: TimeInterval = 6) {
        let record = app.buttons["practiceRecordButton"]
        let ready = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "label == %@ AND enabled == true", "Record"), object: record)
        XCTAssertEqual(XCTWaiter.wait(for: [ready], timeout: timeout), .completed)
    }

    /// From anywhere, shows the path with every level that holds lessons open.
    private func openLessons(in app: XCUIApplication) {
        for id in ["openC", "mixedRhythm", "steadyHum"] { _ = app.pathRow("lesson-\(id)") }
    }

    private func openLesson(_ identifier: String, title: String, in app: XCUIApplication) {
        let lesson = app.pathLesson("lesson-\(identifier)")
        XCTAssertTrue(lesson.isEnabled, "Every lesson remains available")
        lesson.tap()
        let heading = app.staticTexts["lessonDetailTitle"]
        XCTAssertTrue(heading.waitForExistence(timeout: 5))
        XCTAssertEqual(heading.label, title)
        let instruction = app.descendants(matching: .any).matching(identifier: "lessonInstruction").firstMatch
        reveal(instruction, in: app)
        XCTAssertTrue(instruction.isHittable)
        reveal(app.buttons["startLessonButton"], in: app)
        XCTAssertTrue(app.buttons["startLessonButton"].isEnabled)
    }

    private func assertAvailableLesson(_ identifier: String, step: Int, title: String, in app: XCUIApplication) {
        let lesson = app.pathRow("lesson-\(identifier)")
        XCTAssertTrue(lesson.isEnabled, "\(title) must remain available before earlier goals are completed")
        XCTAssertTrue(lesson.label.contains(title))
        XCTAssertTrue(lesson.label.contains("Lesson \(step), \(title)"), "The path should announce each lesson's place")
        if lesson.label.contains("Not started") {
            XCTAssertFalse(lesson.label.localizedCaseInsensitiveContains("stars"),
                           "An unstarted lesson must not receive an invented score")
            XCTAssertTrue(lesson.label.contains("No score yet"))
            XCTAssertFalse(app.descendants(matching: .any).matching(identifier: "lessonCompletion-\(identifier)").firstMatch.exists)
        }
    }

    /// True while a tap pad is on screen and accepting taps, read in one query.
    /// A round replaces its pad with the result the moment it ends, so reading
    /// `exists` and then `isEnabled` can straddle that and fail the test.
    private func isLive(_ identifier: String, in app: XCUIApplication) -> Bool {
        app.buttons.matching(NSPredicate(format: "identifier == %@ AND enabled == true", identifier)).count > 0
    }

    /// The screen position of an element, for taps that must not depend on the
    /// element still existing. A round replaces its tap pad with the result the
    /// moment it ends; tapping the pad element itself can race that and fail.
    private func fixedPoint(at element: XCUIElement, in app: XCUIApplication) -> XCUICoordinate {
        let frame = element.frame
        return app.coordinate(withNormalizedOffset: .zero)
            .withOffset(CGVector(dx: frame.midX, dy: frame.midY))
    }

    private func scrollToPracticeTop(in app: XCUIApplication) {
        let section = app.staticTexts["practiceLessonTitle"]
        for _ in 0..<6 {
            if section.exists && section.isHittable { return }
            app.scrollViews.firstMatch.swipeDown()
        }
        XCTAssertTrue(section.exists && section.isHittable)
    }
}
