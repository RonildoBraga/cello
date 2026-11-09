import Foundation
import XCTest
@testable import Cello

final class PulseTimingChartTests: XCTestCase {
    func testStoredOffsetsKeepTheirSignAndBecomeMillisecondsAtOneBasedBeats() {
        let data = PulseTimingChartData(totalBeats: 16, offsets: [15: 0.321, 0: -0.12345, 7: 0])
        XCTAssertTrue(data.hasValidBeatCount)
        XCTAssertEqual(data.points.map(\.beat), [1, 8, 16])
        XCTAssertEqual(data.points[0].milliseconds, -123.45, accuracy: 1e-9)
        XCTAssertEqual(data.points[1].milliseconds, 0, accuracy: 1e-9)
        XCTAssertEqual(data.points[2].milliseconds, 321, accuracy: 1e-9)
        XCTAssertEqual(data.beatRange, 0.5...16.5)
    }

    func testMissingBeatsStayMissingInsteadOfBecomingPerfectZeroOffsets() {
        let data = PulseTimingChartData(totalBeats: 16, offsets: [0: 0])
        XCTAssertEqual(data.points.count, 1)
        XCTAssertEqual(data.points.first?.beat, 1)
        XCTAssertEqual(data.points.first?.milliseconds, 0)
        XCTAssertEqual(data.missedBeats, Array(2...16))
        XCTAssertEqual(data.onTimeCount, 1)
        XCTAssertEqual(data.earlyCount, 0)
        XCTAssertEqual(data.lateCount, 0)

        let noTaps = PulseTimingChartData(totalBeats: 16, offsets: [:])
        XCTAssertTrue(noTaps.points.isEmpty)
        XCTAssertEqual(noTaps.missedBeats, Array(1...16))
        XCTAssertEqual(noTaps.onTimeCount, 0)
    }

    func testGoalBandIncludesBoth150MillisecondBoundariesAndScoringTolerance() {
        let offsets = [-0.150000002, -0.15, -0.1500000005, 0, 0.15, 0.1500000005, 0.150000002]
        let data = PulseTimingChartData(totalBeats: 16,
            offsets: Dictionary(uniqueKeysWithValues: offsets.enumerated().map { ($0.offset, $0.element) }))
        XCTAssertEqual(data.onTimeCount, 5)
        XCTAssertEqual(data.earlyCount, 1)
        XCTAssertEqual(data.lateCount, 1)
        XCTAssertEqual(data.points.map(\.isOnTime), [false, true, true, true, true, true, false])
    }

    func testInvalidIndicesAndOffsetsAreNotPlottedAsTaps() {
        let data = PulseTimingChartData(totalBeats: 16, offsets: [
            -1: 0, 16: 0, 0: .nan, 1: .infinity, 2: -.infinity,
            3: 0.451, 4: -0.451, 5: 0.075
        ])
        XCTAssertEqual(data.points.map(\.beat), [6])
        XCTAssertEqual(data.points.first?.milliseconds, 75)
        XCTAssertEqual(data.missedBeats.count, 15)
        XCTAssertFalse(data.missedBeats.contains(6))
    }

    func testWideValidTapErrorsExpandTheScaleWithoutChangingOffsets() {
        let data = PulseTimingChartData(totalBeats: 16, offsets: [0: -0.45, 15: 0.44])
        XCTAssertEqual(data.points[0].milliseconds, -450, accuracy: 1e-9)
        XCTAssertEqual(data.points[1].milliseconds, 440, accuracy: 1e-9)
        XCTAssertEqual(data.offsetRange, -500...500)
        XCTAssertTrue(data.points.allSatisfy { data.offsetRange.contains($0.milliseconds) })

        let centred = PulseTimingChartData(totalBeats: 16, offsets: [0: 0])
        XCTAssertEqual(centred.offsetRange, -250...250)
        XCTAssertTrue(centred.offsetRange.contains(-150))
        XCTAssertTrue(centred.offsetRange.contains(150))
    }

    func testAnInvalidRoundDoesNotInventTapOrMissedBeatData() {
        for total in [-1, 0, 17, Int.max] {
            let data = PulseTimingChartData(totalBeats: total, offsets: [0: 0])
            XCTAssertFalse(data.hasValidBeatCount)
            XCTAssertTrue(data.points.isEmpty)
            XCTAssertTrue(data.missedBeats.isEmpty)
        }
    }

    func testTwoTapsUsesHalfBeatWindowAndDescribesEightBeats() {
        let data = PulseTimingChartData(totalBeats: 16,
            offsets: [0: -0.225, 1: 0.15, 7: 0.226, 15: 0.225], exercise: .twoTaps)
        XCTAssertEqual(data.points.map(\.beat), [1, 2, 16])
        XCTAssertEqual(data.onTimeCount, 1)
        XCTAssertEqual(data.missedBeats.count, 13)
        XCTAssertTrue(data.accessibilitySummary.contains("3 taps across 8 beats"))
        XCTAssertEqual((1...16).map(RhythmExercise.twoTaps.beatLabel),
                       ["1", "&", "2", "&", "3", "&", "4", "&", "5", "&", "6", "&", "7", "&", "8", "&"])
    }

    func testMixedRhythmShowsOnlyPatternSlotsAndKeepsDeliberateGaps() {
        let offsets = Dictionary(uniqueKeysWithValues: (0..<12).map { ($0, 0.05) })
        let data = PulseTimingChartData(totalBeats: 12, offsets: offsets,
                                       exercise: .mixedRhythm, unexpectedTapCount: 4)
        XCTAssertTrue(data.hasValidBeatCount)
        XCTAssertEqual(data.positions, [1, 2, 2.5, 3, 4, 4.5, 5, 6, 6.5, 7, 8, 8.5])
        XCTAssertEqual(data.points.map(\.position), data.positions)
        XCTAssertEqual(data.points.count, 12)
        XCTAssertTrue(data.missedBeats.isEmpty, "The quiet halves after odd beats are not missing taps")
        XCTAssertEqual(data.onTimeCount, 12)
        XCTAssertTrue(data.accessibilitySummary.contains("12 taps across 8 beats"))
        XCTAssertTrue(data.accessibilitySummary.contains("4 extra taps outside the pattern"))

        let missing = PulseTimingChartData(totalBeats: 12, offsets: [1: 0, 11: -0.1], exercise: .mixedRhythm)
        XCTAssertEqual(missing.points.map(\.position), [2, 8.5])
        XCTAssertEqual(missing.missedBeats.count, 10)
        XCTAssertFalse(PulseTimingChartData(totalBeats: 16, offsets: [:], exercise: .mixedRhythm).hasValidBeatCount)
    }
}
