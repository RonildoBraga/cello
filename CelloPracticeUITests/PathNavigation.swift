import XCTest

/// Finding a step on the Music path, shared by every UI test.
extension XCUIApplication {
    /// Goes back to the Music path from wherever the app is.
    func returnToPath() {
        tabBars.buttons["Music"].tap()
        let firstLevel = buttons["level-firstSounds"]
        for _ in 0..<5 where !firstLevel.waitForExistence(timeout: 1) {
            let back = navigationBars.buttons.firstMatch
            XCTAssertTrue(back.exists, "A Music destination should have native back navigation")
            back.tap()
        }
        XCTAssertTrue(firstLevel.waitForExistence(timeout: 5))
    }

    /// Returns to the path, opens the step's level if it is closed, and brings
    /// the step into reach. Steps are named by their accessibility identifier.
    func pathStep(_ identifier: String) -> XCUIElement {
        returnToPath()
        let step = buttons[identifier]
        if !step.exists {
            let level = buttons["level-\(Self.level(forStep: identifier))"]
            scroll(to: level)
            level.tap()
        }
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

    private static func level(forStep identifier: String) -> String {
        switch identifier {
        case "lesson-steadyHum", "lesson-matchHum", "lesson-pulse", "lesson-twoTaps": return "firstSounds"
        case "lesson-mixedRhythm", "echoPracticeLink": return "more"
        case _ where identifier.hasPrefix("step-"): return String(identifier.split(separator: "-")[1])
        default: return "cello"
        }
    }
}
