import XCTest
@testable import Cello

final class PulseTimingTests: XCTestCase {
    func testCountInPracticeAndFinishFollowMonotonicTime() {
        let timing = PulseTiming(startTime: 100)
        XCTAssertEqual(timing.phase(at: 100), .countIn(4))
        XCTAssertEqual(timing.phase(at: 103.9), .countIn(1))
        XCTAssertEqual(timing.phase(at: 104), .tapping(1))
        XCTAssertEqual(timing.phase(at: 119.9), .tapping(16))
        XCTAssertEqual(timing.phase(at: 120), .finished)
        // Skipped UI frames do not postpone the next beat.
        XCTAssertEqual(timing.phase(at: 110.4), .tapping(7))
    }

    func testEarlyLateAndDuplicateTapsKeepOneObservationPerBeat() throws {
        var timing = PulseTiming(startTime: 100)
        XCTAssertFalse(timing.recordTap(at: 103))
        XCTAssertTrue(timing.recordTap(at: 103.9))
        XCTAssertFalse(timing.recordTap(at: 104.1))
        XCTAssertFalse(timing.recordTap(at: 104.5))
        XCTAssertTrue(timing.recordTap(at: 105.2))
        XCTAssertTrue(timing.recordTap(at: 106.1))
        XCTAssertEqual(timing.offsets.count, 3)
        XCTAssertEqual(try XCTUnwrap(timing.medianOffsetMilliseconds), 100, accuracy: 1e-8)
        XCTAssertEqual(try XCTUnwrap(timing.medianDistanceMilliseconds), 100, accuracy: 1e-8)
    }

    func testNoTimingJudgmentFromOneOrTwoTaps() {
        var timing = PulseTiming(startTime: 10)
        timing.recordTap(at: 14)
        timing.recordTap(at: 15)
        XCTAssertNil(timing.medianOffsetMilliseconds)
        XCTAssertNil(timing.medianDistanceMilliseconds)
    }

    func testWindowAcceptsLastBeatButNotTailOrInvalidTimes() {
        var timing = PulseTiming(startTime: 100)
        XCTAssertTrue(timing.recordTap(at: 119.4))
        XCTAssertFalse(timing.recordTap(at: 119.8))
        XCTAssertFalse(timing.recordTap(at: 120))
        for invalid in [Double.nan, .infinity, -.infinity] {
            XCTAssertFalse(timing.recordTap(at: invalid))
        }
        XCTAssertEqual(timing.offsets.count, 1)
    }

    func testTwoTapsDivideTheSameWholeBeatAndFinishAfterEightBeats() {
        let timing = PulseTiming(startTime: 100, exercise: .twoTaps)
        XCTAssertEqual(PulseTiming.beatInterval, 1)
        XCTAssertEqual(timing.exercise.tapTimes[1] - timing.exercise.tapTimes[0], 0.5)
        XCTAssertEqual(timing.endTime, 112)
        XCTAssertEqual(timing.phase(at: 100), .countIn(4))
        XCTAssertEqual(timing.phase(at: 103.9), .countIn(1))
        XCTAssertEqual(timing.phase(at: 104), .tapping(1))
        XCTAssertEqual(timing.phase(at: 104.49), .tapping(1))
        XCTAssertEqual(timing.phase(at: 104.5), .tapping(2))
        XCTAssertEqual(timing.phase(at: 105), .tapping(3))
        XCTAssertEqual(timing.phase(at: 111.99), .tapping(16))
        XCTAssertEqual(timing.phase(at: 112), .finished)
        XCTAssertEqual(RhythmExercise.twoTaps.beatLabel(forTap: 1), "1")
        XCTAssertEqual(RhythmExercise.twoTaps.beatLabel(forTap: 2), "&")
        XCTAssertEqual(RhythmExercise.twoTaps.beatLabel(forTap: 3), "2")
        XCTAssertEqual(RhythmExercise.twoTaps.beatLabel(forTap: 16), "&")
        XCTAssertEqual(PulseTiming(startTime: 100).endTime, 120)
    }

    func testTwoTapsRejectDuplicatesBetweenSlotGapsAndTheTail() {
        var timing = PulseTiming(startTime: 100, exercise: .twoTaps)
        XCTAssertFalse(timing.recordTap(at: 103.7))
        XCTAssertTrue(timing.recordTap(at: 103.8))
        XCTAssertFalse(timing.recordTap(at: 104.1))
        XCTAssertFalse(timing.recordTap(at: 104.25))
        XCTAssertTrue(timing.recordTap(at: 104.5))
        XCTAssertTrue(timing.recordTap(at: 105.2))
        XCTAssertTrue(timing.recordTap(at: 111.5))
        XCTAssertFalse(timing.recordTap(at: 111.73))
        XCTAssertFalse(timing.recordTap(at: 112))
        XCTAssertEqual(Set(timing.offsets.keys), [0, 1, 2, 15])
    }

    func testTwoTapsHaveTheirOwnNarrowWindowAndSixteenDistinctSlots() {
        var before = PulseTiming(startTime: 100, exercise: .twoTaps)
        XCTAssertFalse(before.recordTap(at: 104 - 0.2251))
        XCTAssertTrue(before.recordTap(at: 104 - 0.2249))
        var after = PulseTiming(startTime: 100, exercise: .twoTaps)
        XCTAssertFalse(after.recordTap(at: 104 + 0.2251))
        XCTAssertTrue(after.recordTap(at: 104 + 0.2249))
        var round = PulseTiming(startTime: 100, exercise: .twoTaps)
        for tap in 0..<16 { XCTAssertTrue(round.recordTap(at: 104 + Double(tap) * 0.5 + 0.04)) }
        XCTAssertEqual(round.offsets.count, 16)
        XCTAssertEqual(round.phase(at: 111.9), .tapping(16))
        XCTAssertEqual(round.phase(at: round.endTime), .finished)
    }

    func testMixedRhythmHasTwelveTapsAcrossEightSteadyBeats() {
        let exercise = RhythmExercise.mixedRhythm
        XCTAssertEqual(exercise.tapTimes, [0, 1, 1.5, 2, 3, 3.5, 4, 5, 5.5, 6, 7, 7.5])
        XCTAssertEqual(exercise.tapCount, 12)
        XCTAssertEqual(exercise.wholeBeats, 8)
        XCTAssertEqual(exercise.coverageTarget, 9)
        XCTAssertEqual((1...12).map(exercise.beatLabel), ["1", "2", "&", "3", "4", "&", "5", "6", "&", "7", "8", "&"])

        var timing = PulseTiming(startTime: 100, exercise: exercise)
        XCTAssertEqual(timing.phase(at: 103.9), .countIn(1))
        XCTAssertEqual(timing.phase(at: 104), .tapping(1))
        XCTAssertEqual(timing.phase(at: 104.75), .tapping(1), "The space after 1 is not another expected tap")
        XCTAssertEqual(timing.phase(at: 105), .tapping(2))
        XCTAssertEqual(timing.phase(at: 105.5), .tapping(3))
        XCTAssertEqual(timing.phase(at: 111.99), .tapping(12))
        XCTAssertEqual(timing.endTime, 112)
        XCTAssertEqual(timing.phase(at: 112), .finished)
        for time in exercise.tapTimes { XCTAssertTrue(timing.recordTap(at: 104 + time)) }
        XCTAssertEqual(timing.offsets.count, 12)
        XCTAssertEqual(timing.unexpectedTapCount, 0)
    }

    func testMixedRhythmCountsGapTapsButNotDuplicatesOrCountInAndTail() {
        var timing = PulseTiming(startTime: 100, exercise: .mixedRhythm)
        XCTAssertFalse(timing.recordTap(at: 103.7))
        XCTAssertTrue(timing.recordTap(at: 103.8), "The existing early-first-tap window remains available")
        XCTAssertFalse(timing.recordTap(at: 104.05), "A duplicate near the same slot is ignored")
        for time in [104.5, 106.5, 108.5, 110.5] { XCTAssertFalse(timing.recordTap(at: time)) }
        XCTAssertEqual(timing.unexpectedTapCount, 4)
        XCTAssertTrue(timing.recordTap(at: 111.5))
        XCTAssertFalse(timing.recordTap(at: 111.8))
        XCTAssertFalse(timing.recordTap(at: 112))
        XCTAssertFalse(timing.recordTap(at: .nan))
        XCTAssertEqual(timing.unexpectedTapCount, 4)
        XCTAssertEqual(Set(timing.offsets.keys), [0, 11])
    }

    func testTappingEveryHalfSecondRecordsFourUnexpectedMixedRhythmTaps() {
        var timing = PulseTiming(startTime: 100, exercise: .mixedRhythm)
        for slot in 0..<16 { timing.recordTap(at: 104 + Double(slot) / 2) }
        XCTAssertEqual(timing.offsets.count, 12)
        XCTAssertEqual(timing.unexpectedTapCount, 4)
    }
}
