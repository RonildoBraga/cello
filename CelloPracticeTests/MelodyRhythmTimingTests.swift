import CelloPitch
import Foundation
import XCTest
@testable import Cello

final class MelodyRhythmTimingTests: XCTestCase {
    func testExpectedTapsComeFromSharedNotesAndKeepTheFinalLongNote() throws {
        for section in [MelodySection.phrase1, .phrase2, .phrase4] {
            let context = try MelodyRhythmContext.hotCrossBuns(section: section)
            XCTAssertTrue(context.isValid)
            XCTAssertEqual(context.expectedTapTimes, [0, 1, 2])
            XCTAssertEqual(context.duration, 4)
            XCTAssertEqual(context.reference.expectedEvents.last?.durationBeats, 2)
            XCTAssertNil(context.reference.gradingVersion)
        }
        let quick = try MelodyRhythmContext.hotCrossBuns(section: .phrase3)
        XCTAssertEqual(quick.expectedTapTimes, (0..<8).map { Double($0) / 2 })
        let whole = try MelodyRhythmContext.hotCrossBuns(section: .whole)
        XCTAssertEqual(whole.expectedTapTimes, [0, 1, 2, 4, 5, 6, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12, 13, 14])
        XCTAssertEqual(whole.expectedTapTimes.count, 17)
        XCTAssertEqual(whole.duration, 16)
        XCTAssertEqual(whole.scoringVersion, MelodyRhythmContext.currentScoringVersion)
    }

    func testCountInAndPhraseEndFollowMonotonicTimeDespiteSkippedFrames() throws {
        let context = try MelodyRhythmContext.hotCrossBuns()
        let timing = MelodyRhythmTiming(startTime: 100, context: context)
        XCTAssertEqual(timing.practiceStartTime, 104)
        XCTAssertEqual(timing.endTime, 108)
        XCTAssertEqual(timing.phase(at: 99), .countIn(4))
        XCTAssertEqual(timing.phase(at: 100), .countIn(4))
        XCTAssertEqual(timing.phase(at: 103.99), .countIn(1))
        XCTAssertEqual(timing.phase(at: 104), .tapping(1))
        XCTAssertEqual(timing.phase(at: 105.4), .tapping(2))
        XCTAssertEqual(timing.phase(at: 107.99), .tapping(3))
        XCTAssertEqual(timing.phase(at: 108), .finished)
        XCTAssertFalse(timing.canTap(at: 103.5), "The count-in is not for tapping")
        XCTAssertTrue(timing.canTap(at: 103.99), "The first note may be met a touch early")
        XCTAssertTrue(timing.canTap(at: 107.99))
        XCTAssertFalse(timing.canTap(at: 108))
    }

    func testTempoChangesCountInOnsetsAndEndTogether() throws {
        for tempo in [40, 60, 120] {
            let context = try MelodyRhythmContext.hotCrossBuns(tempoBPM: tempo)
            let beat = 60 / Double(tempo)
            let timing = MelodyRhythmTiming(startTime: 10, context: context)
            XCTAssertEqual(context.beatInterval, beat)
            XCTAssertEqual(context.countInDuration, 4 * beat)
            XCTAssertEqual(context.expectedTapTimes, [0, beat, 2 * beat])
            XCTAssertEqual(context.duration, 4 * beat)
            XCTAssertEqual(timing.endTime, 10 + 8 * beat)
            XCTAssertEqual(timing.phase(at: 10 + 3 * beat), .countIn(1))
            XCTAssertEqual(timing.phase(at: timing.practiceStartTime), .tapping(1))
        }
    }

    func testWindowsAdaptToQuickNotesAndDoNotOverlap() throws {
        let ordinary = try MelodyRhythmContext.hotCrossBuns()
        XCTAssertEqual(ordinary.tapWindow(for: 0), 0.45)
        XCTAssertEqual(ordinary.tapWindow(for: 2), 0.45)
        let quick = try MelodyRhythmContext.hotCrossBuns(section: .phrase3)
        XCTAssertEqual(quick.tapWindow(for: 0), 0.225)
        XCTAssertEqual(quick.tapWindow(for: 7), 0.225)
        XCTAssertEqual(quick.tapWindow(for: -1), 0)
        XCTAssertEqual(quick.tapWindow(for: 8), 0)
        var timing = MelodyRhythmTiming(startTime: 100, context: quick)
        XCTAssertFalse(timing.recordTap(at: 104.25))
        XCTAssertEqual(timing.offsets.count, 0)
        XCTAssertEqual(timing.unexpectedTapCount, 1)
    }

    func testEarlyAndLateWindowEdgesKeepMeasuredOffsets() throws {
        let context = try MelodyRhythmContext.hotCrossBuns(section: .phrase3)
        var early = MelodyRhythmTiming(startTime: 100, context: context)
        XCTAssertTrue(early.recordTap(at: 104.5 - 0.225))
        XCTAssertEqual(try XCTUnwrap(early.offsets[1]), -0.225, accuracy: 1e-9)
        var late = MelodyRhythmTiming(startTime: 100, context: context)
        XCTAssertTrue(late.recordTap(at: 104.5 + 0.225))
        XCTAssertEqual(try XCTUnwrap(late.offsets[1]), 0.225, accuracy: 1e-9)
        var outside = MelodyRhythmTiming(startTime: 100, context: context)
        XCTAssertFalse(outside.recordTap(at: 104.5 + 0.2251))
        XCTAssertEqual(outside.unexpectedTapCount, 1)
    }

    func testExtraPressesThroughTheFinalHeldBeatAreNotSilentlyDropped() throws {
        let context = try MelodyRhythmContext.hotCrossBuns()
        var timing = MelodyRhythmTiming(startTime: 100, context: context)
        for onset in context.expectedTapTimes { XCTAssertTrue(timing.recordTap(at: 104 + onset)) }
        XCTAssertFalse(timing.recordTap(at: 107))
        XCTAssertFalse(timing.recordTap(at: 107.9))
        XCTAssertEqual(timing.offsets.count, 3)
        XCTAssertEqual(timing.unexpectedTapCount, 2)
        XCTAssertEqual(timing.actualTapTimes.count, 5)
        for (actual, expected) in zip(timing.actualTapTimes, [0, 1, 2, 3, 3.9]) {
            XCTAssertEqual(actual, expected, accuracy: 1e-9)
        }
        XCTAssertFalse(timing.recordTap(at: 108))
        XCTAssertEqual(timing.unexpectedTapCount, 2)
    }

    func testDuplicateCallbackIsIgnoredButASeparateTouchCountsAsExtra() throws {
        var timing = MelodyRhythmTiming(startTime: 100, context: try .hotCrossBuns())
        XCTAssertTrue(timing.recordTap(at: 104))
        XCTAssertFalse(timing.recordTap(at: 104))
        XCTAssertFalse(timing.recordTap(at: 104.0499))
        XCTAssertEqual(timing.actualTapTimes, [0])
        XCTAssertEqual(timing.unexpectedTapCount, 0)
        XCTAssertFalse(timing.recordTap(at: 104.05))
        XCTAssertEqual(timing.actualTapTimes.count, 2)
        XCTAssertEqual(timing.unexpectedTapCount, 1)
        // A stale callback cannot append an earlier observation.
        XCTAssertFalse(timing.recordTap(at: 104.01))
        XCTAssertEqual(timing.actualTapTimes.count, 2)
    }

    func testMissingNotesHaveNoOffsetsAndCountInTouchesDoNotBecomeAttempts() throws {
        var timing = MelodyRhythmTiming(startTime: 100, context: try .hotCrossBuns())
        for time in [100.0, 101, 102, 103] { XCTAssertFalse(timing.recordTap(at: time)) }
        XCTAssertTrue(timing.recordTap(at: 106))
        XCTAssertEqual(Set(timing.offsets.keys), [2])
        XCTAssertEqual(timing.actualTapTimes, [2])
        XCTAssertEqual(timing.unexpectedTapCount, 0)
    }

    func testAFirstTapATouchEarlyCountsForTheFirstNote() throws {
        var timing = MelodyRhythmTiming(startTime: 100, context: try .hotCrossBuns())
        XCTAssertTrue(timing.recordTap(at: 103.95), "Meeting the first note slightly early is still a tap")
        XCTAssertEqual(try XCTUnwrap(timing.offsets[0]), -0.05, accuracy: 1e-9)
        XCTAssertTrue(timing.recordTap(at: 105))
        XCTAssertTrue(timing.recordTap(at: 106))
        XCTAssertEqual(timing.unexpectedTapCount, 0)
        let attempt = try XCTUnwrap(MelodyRhythmAttempt(timing: timing, finishedAt: timing.endTime))
        XCTAssertEqual(attempt.starCount, 3, "An early first tap is graded like any other tap")
    }

    func testExplicitRestAndUnwrittenGapHaveNoExpectedTap() {
        let reference = snapshot(events: [
            MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 43),
            MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: nil),
            MelodyEvent(onsetBeat: 3, durationBeats: 1, midiNote: 47)
        ])
        let context = MelodyRhythmContext(reference: reference)
        XCTAssertTrue(context.isValid)
        XCTAssertEqual(context.expectedTapTimes, [0, 3])
        var timing = MelodyRhythmTiming(startTime: 10, context: context)
        XCTAssertTrue(timing.recordTap(at: 14))
        XCTAssertFalse(timing.recordTap(at: 15))
        XCTAssertFalse(timing.recordTap(at: 16))
        XCTAssertTrue(timing.recordTap(at: 17))
        XCTAssertEqual(timing.offsets.count, 2)
        XCTAssertEqual(timing.unexpectedTapCount, 2)
    }

    func testContextRoundTripKeepsRhythmAndReferenceWithoutVoiceGrades() throws {
        let context = try MelodyRhythmContext.hotCrossBuns(section: .whole, tempoBPM: 40)
        let restored = try JSONDecoder().decode(MelodyRhythmContext.self, from: JSONEncoder().encode(context))
        XCTAssertEqual(restored, context)
        XCTAssertTrue(restored.isValid)
        XCTAssertEqual(restored.expectedTapTimes.last, 21)
        XCTAssertNil(restored.reference.gradingVersion)
        let future = MelodyRhythmContext(reference: restored.reference, scoringVersion: 2)
        XCTAssertTrue(future.isValid, "Structural validity is separate from the scorer's supported version")
    }

    func testInvalidContextAndNonfiniteOrUnrepresentableClocksCannotRun() throws {
        let valid = try MelodyRhythmContext.hotCrossBuns()
        for clock in [Double.nan, .infinity, -.infinity, -1, Double.greatestFiniteMagnitude] {
            var timing = MelodyRhythmTiming(startTime: clock, context: valid)
            XCTAssertEqual(timing.phase(at: 104), .finished)
            XCTAssertFalse(timing.canTap(at: 104))
            XCTAssertFalse(timing.recordTap(at: 104))
            XCTAssertTrue(timing.actualTapTimes.isEmpty)
        }
        var timing = MelodyRhythmTiming(startTime: 100, context: valid)
        for time in [Double.nan, .infinity, -.infinity] {
            XCTAssertEqual(timing.phase(at: time), .finished)
            XCTAssertFalse(timing.recordTap(at: time))
        }
        let voice = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, gradingVersion: 1)
        for context in [MelodyRhythmContext(reference: snapshot(events: [])),
                        MelodyRhythmContext(reference: snapshot(events: [MelodyEvent(onsetBeat: 0, durationBeats: 4, midiNote: nil)])),
                        MelodyRhythmContext(reference: voice),
                        MelodyRhythmContext(reference: valid.reference, scoringVersion: 0)] {
            XCTAssertFalse(context.isValid)
            var invalid = MelodyRhythmTiming(startTime: 0, context: context)
            XCTAssertEqual(invalid.phase(at: 4), .finished)
            XCTAssertFalse(invalid.recordTap(at: 4))
        }
    }

    private func snapshot(events: [MelodyEvent]) -> MelodyPracticeContext {
        MelodyPracticeContext(pieceID: "hotCrossBuns", scoreVersion: 1, register: .lowVoice,
                              referenceKey: "G major", tuningA4Hz: 440, tempoBPM: 60, section: .phrase1,
                              expectedEvents: events, durationBeats: 4, gradingVersion: nil)
    }
}
