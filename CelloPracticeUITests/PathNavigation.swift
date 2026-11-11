import XCTest

/// Ten tests replay private recordings and saved histories that are not in the
/// repository. They say so first, so an ordinary run skips them at once instead
/// of launching the app to find the data missing. After copying the fixtures
/// into the Simulator, run with TEST_RUNNER_CELLO_RECORDING_FIXTURES=1.
func requireRecordingFixtures() throws {
    try XCTSkipUnless(ProcessInfo.processInfo.environment["CELLO_RECORDING_FIXTURES"] == "1",
                      "Needs private recording fixtures; set TEST_RUNNER_CELLO_RECORDING_FIXTURES=1 once they are in the Simulator")
}

/// Finding a lesson on the Music path, shared by every UI test.
extension XCUIApplication {
    /// The app as a returning learner sees it: every primer already read, so a
    /// lesson opens on its own page. Pass `seenPrimers: ""` for a first visit.
    /// Launch arguments override the stored preference without changing it.
    static func cello(seenPrimers: String = "steadyHum,matchHum,pulse,twoTaps") -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments += ["-seenPrimers", seenPrimers]
        return app
    }

    /// Goes back to the Music path from wherever the app is.
    func returnToPath() {
        let firstLevel = buttons["level-firstSounds"]
        // Tapping the selected tab would scroll the path back to its top.
        if firstLevel.exists { return }
        tabBars.buttons["Music"].tap()
        for _ in 0..<5 where !firstLevel.waitForExistence(timeout: 1) {
            let back = navigationBars.buttons.firstMatch
            XCTAssertTrue(back.exists, "A Music destination should have native back navigation")
            back.tap()
        }
        XCTAssertTrue(firstLevel.waitForExistence(timeout: 5))
    }

    /// Returns to the path and opens the lesson's level if it is closed. The row
    /// can then be read; use `pathLesson` to tap it. Lessons are named by their
    /// accessibility identifier.
    func pathRow(_ identifier: String) -> XCUIElement {
        returnToPath()
        let step = buttons[identifier]
        if !step.exists {
            let level = buttons["level-\(Self.level(forLesson: identifier))"]
            scroll(to: level)
            level.tap()
            XCTAssertTrue(step.waitForExistence(timeout: 5))
        }
        return step
    }

    /// The lesson's row, scrolled into reach for a tap.
    func pathLesson(_ identifier: String) -> XCUIElement {
        let step = pathRow(identifier)
        scroll(to: step)
        return step
    }

    /// Scrolls up or down until the element can be tapped.
    func scroll(to element: XCUIElement) {
        XCTAssertTrue(element.waitForExistence(timeout: 5), "\(element) should be on this screen")
        for _ in 0..<12 where !element.isHittable {
            if element.frame.midY < frame.midY { scrollViews.firstMatch.swipeDown() }
            else { scrollViews.firstMatch.swipeUp() }
        }
        XCTAssertTrue(element.isHittable)
    }

    private static func level(forLesson identifier: String) -> String {
        switch identifier {
        case "lesson-steadyHum", "lesson-matchHum", "lesson-pulse", "lesson-twoTaps",
             "lesson-mixedRhythm", "echoPracticeLink": return "firstSounds"
        case _ where identifier.hasPrefix("lesson-hotCrossBuns-") || identifier.hasPrefix("lesson-odeToJoy-"): return String(identifier.split(separator: "-")[1])
        default: return "cello"
        }
    }
}
