import XCTest
@testable import Cello

final class CompletionRuleTests: XCTestCase {
    func testRecentSuccessesCountsOnlyTheNewestFiveAttempts() {
        XCTAssertEqual(CompletionRule.recentSuccesses([Bool]()), 0)
        XCTAssertEqual(CompletionRule.recentSuccesses([true, false, true]), 2)
        // The sixth-newest success has left the window.
        XCTAssertEqual(CompletionRule.recentSuccesses([false, false, false, true, true, true]), 2)
    }

    func testThreeSuccessesAmongFiveConsecutiveAttemptsEarnAKey() {
        let earned = CompletionRule.earnedKeys([true, false, true, false, true].map { (key: "a", success: $0) })
        XCTAssertEqual(earned, ["a"])
        let spread = CompletionRule.earnedKeys([true, false, false, true, false, false, true]
            .map { (key: "a", success: $0) })
        XCTAssertTrue(spread.isEmpty)
    }

    func testLaterMissesDoNotEraseAnEarnedKeyAndKeysStaySeparate() {
        let history: [(key: String, success: Bool)] = [
            ("a", true), ("b", true), ("a", true), ("b", true), ("a", true),
            ("a", false), ("a", false), ("a", false), ("a", false), ("a", false)
        ]
        XCTAssertEqual(CompletionRule.earnedKeys(history), ["a"])
    }
}
