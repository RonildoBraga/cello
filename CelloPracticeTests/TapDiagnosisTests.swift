import XCTest
@testable import Cello

/// The cases are the mistakes found in real saved rounds.
final class TapDiagnosisTests: XCTestCase {
    private func feedback(_ kind: TapDiagnosis.Kind, expected: Int, offsets: [Int: TimeInterval], extras: Int = 0,
                          oneBeatLate: Bool = false,
                          coverage: Bool = true, timing: Bool = true, evenness: Bool = true) -> String {
        TapDiagnosis.feedback(kind: kind, expected: expected, offsets: offsets, extras: extras, oneBeatLate: oneBeatLate,
                              coverage: coverage, timing: timing, evenness: evenness)
    }

    func testStartingAMelodyOneBeatLateIsNamedBeforeAnythingElse() {
        // Taps at 1.08, 2.07 and 3.04 s against notes at 0, 1 and 2 s.
        let text = feedback(.melody, expected: 3, offsets: [1: 0.08, 2: 0.07], extras: 1, oneBeatLate: true,
                            coverage: false, timing: false)
        XCTAssertTrue(text.hasPrefix("You started one beat late"))
        XCTAssertTrue(text.contains("right after the count of 4"))
        // A missed first note with an extra tap elsewhere is not called a beat late.
        XCTAssertTrue(feedback(.melody, expected: 3, offsets: [2: 0.0], extras: 2, coverage: false)
            .hasPrefix("You missed the first note"))
    }

    func testARealRoundStartedABeatLateIsRecognisedFromItsTapTimes() throws {
        var late = MelodyRhythmTiming(startTime: 100, context: try .hotCrossBuns())
        for time in [105.08, 106.07, 107.04] { late.recordTap(at: time) }
        XCTAssertTrue(try XCTUnwrap(MelodyRhythmAttempt(timing: late, finishedAt: late.endTime)).cue
            .hasPrefix("You started one beat late"))

        var scattered = MelodyRhythmTiming(startTime: 100, context: try .hotCrossBuns())
        for time in [106.0, 106.1, 107.0] { scattered.recordTap(at: time) }
        XCTAssertTrue(try XCTUnwrap(MelodyRhythmAttempt(timing: scattered, finishedAt: scattered.endTime)).cue
            .hasPrefix("You missed the first note"))
    }

    func testAMissedFirstTapIsNamedForEveryKind() {
        XCTAssertTrue(feedback(.twoTaps, expected: 16, offsets: [2: 0, 3: 0, 4: 0]).hasPrefix("You missed the first tap"))
        XCTAssertTrue(feedback(.melody, expected: 3, offsets: [1: 0, 2: 0]).hasPrefix("You missed the first note"))
    }

    func testATapDuringAHeldNoteIsCountedAndExplained() {
        let text = feedback(.melody, expected: 3, offsets: [0: 0.19, 1: 0.14, 2: 0.1], extras: 1, timing: false)
        XCTAssertTrue(text.hasPrefix("1 tap landed where no note starts"))
        XCTAssertTrue(text.contains("keep counting while it holds"))
        XCTAssertTrue(feedback(.melody, expected: 3, offsets: [0: 0, 1: 0, 2: 0], extras: 2).hasPrefix("2 taps landed"))
    }

    func testMixedRhythmExtrasSayWhichBeatsGetOneTap() {
        let text = feedback(.mixed, expected: 12, offsets: [0: 0, 1: 0, 2: 0, 3: 0], extras: 4, coverage: false)
        XCTAssertTrue(text.hasPrefix("4 taps landed in the gaps"))
        XCTAssertTrue(text.contains("Beats 1, 3, 5 and 7 get one tap"))
        // One stray tap is within the rule, so the missed taps are the thing to fix.
        XCTAssertTrue(feedback(.mixed, expected: 12, offsets: [0: 0, 1: 0, 2: 0], extras: 1, coverage: false)
            .hasPrefix("You missed 9 of 12 taps"))
    }

    func testLateAndEarlyTimingGiveTheSizeAndOppositeAdvice() {
        let late = Dictionary(uniqueKeysWithValues: (0..<16).map { ($0, 0.16) })
        XCTAssertTrue(feedback(.pulse, expected: 16, offsets: late, timing: false)
            .hasPrefix("Most taps were about 0.16 s late"))
        let early = late.mapValues { -$0 }
        XCTAssertTrue(feedback(.pulse, expected: 16, offsets: early, timing: false)
            .hasPrefix("Most taps were about 0.16 s early"))
        let scattered = Dictionary(uniqueKeysWithValues: (0..<16).map { ($0, $0.isMultiple(of: 2) ? 0.2 : -0.2) })
        XCTAssertTrue(feedback(.pulse, expected: 16, offsets: scattered, timing: false)
            .hasPrefix("Your taps landed on both sides of the beat"))
    }

    func testUnevenTwoTapsSaysWhichWayTheBetweenTapsDrift() {
        let lateBetween = Dictionary(uniqueKeysWithValues: (0..<16).map { ($0, $0.isMultiple(of: 2) ? 0.0 : 0.12) })
        XCTAssertTrue(feedback(.twoTaps, expected: 16, offsets: lateBetween, evenness: false)
            .hasPrefix("The taps between beats came late"))
        let earlyBetween = lateBetween.mapValues { -$0 }
        XCTAssertTrue(feedback(.twoTaps, expected: 16, offsets: earlyBetween, evenness: false)
            .hasPrefix("The taps between beats came early"))
        XCTAssertTrue(feedback(.pulse, expected: 16, offsets: lateBetween, evenness: false)
            .hasPrefix("The gaps between taps changed"))
        XCTAssertTrue(feedback(.mixed, expected: 12, offsets: lateBetween, evenness: false)
            .hasPrefix("The beat drifted as you switched"), "Mixed rhythm's gaps are meant to differ")
    }

    func testACleanRoundSaysSo() {
        let clean = Dictionary(uniqueKeysWithValues: (0..<16).map { ($0, 0.02) })
        XCTAssertEqual(feedback(.pulse, expected: 16, offsets: clean), "All three goals reached. Your taps stayed with the beat.")
    }
}
