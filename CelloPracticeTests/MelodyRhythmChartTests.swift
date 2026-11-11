import Foundation
import XCTest
@testable import Cello

final class MelodyRhythmChartTests: XCTestCase {
    func testPhraseUsesNoteStartTimesAndKeepsTheLongLastNoteOnTheTimeline() throws {
        let context = try MelodyRhythmContext.hotCrossBuns(section: .phrase1)
        let data = MelodyRhythmChartData(context: context, offsets: [0: 0.05, 1: -0.12, 2: 0.21])
        XCTAssertTrue(data.hasValidContext)
        XCTAssertEqual(data.expectedTimes, [0, 1, 2])
        XCTAssertEqual(data.points.map(\.time), [0, 1, 2])
        XCTAssertEqual(data.points.map(\.milliseconds), [50, -120, 210])
        XCTAssertEqual(data.timeRange, 0...4, "The continuing final note must not shorten the chart")
        XCTAssertTrue(data.missedNoteIndices.isEmpty)
        XCTAssertEqual(data.onTimeCount, 2)
        XCTAssertEqual(data.lateCount, 1)
    }

    func testWholeMelodyUsesItsSeventeenStartsAndTempoInsteadOfUniformTapNumbers() throws {
        let context = try MelodyRhythmContext.hotCrossBuns(section: .whole, tempoBPM: 120)
        let data = MelodyRhythmChartData(context: context, offsets: [0: 0, 6: 0.05, 16: -0.1])
        XCTAssertEqual(data.expectedTimes, [0, 0.5, 1, 2, 2.5, 3, 4, 4.25, 4.5, 4.75, 5, 5.25, 5.5, 5.75, 6, 6.5, 7])
        XCTAssertEqual(data.points.map(\.time), [0, 4, 7])
        XCTAssertEqual(data.timeRange, 0...8)
        XCTAssertEqual(data.missedNoteIndices.count, 14)
    }

    func testMissingStartsHaveNoPerfectZeroOffsetsAndContinuingBeatsAreNotMisses() throws {
        let context = try MelodyRhythmContext.hotCrossBuns(section: .phrase1)
        let data = MelodyRhythmChartData(context: context, offsets: [1: 0])
        XCTAssertEqual(data.points.map(\.noteIndex), [1])
        XCTAssertEqual(data.points.first?.milliseconds, 0)
        XCTAssertEqual(data.missedNoteIndices, [0, 2])
        XCTAssertEqual(data.expectedTimes.count, 3, "Beat four continues the half note; it is not a fourth missing tap")
        let empty = MelodyRhythmChartData(context: context, offsets: [:])
        XCTAssertTrue(empty.points.isEmpty)
        XCTAssertEqual(empty.missedNoteIndices, [0, 1, 2])
        XCTAssertEqual(empty.onTimeCount, 0)
    }

    func testTimingBoundaryMatchesTheScoreTolerance() throws {
        let context = try MelodyRhythmContext.hotCrossBuns(section: .whole)
        let offsets = [-0.150000002, -0.15, -0.1500000005, 0, 0.15, 0.1500000005, 0.150000002]
        let data = MelodyRhythmChartData(context: context,
            offsets: Dictionary(uniqueKeysWithValues: offsets.enumerated().map { ($0.offset + 1, $0.element) }))
        XCTAssertEqual(data.onTimeCount, 5)
        XCTAssertEqual(data.earlyCount, 1)
        XCTAssertEqual(data.lateCount, 1)
    }

    func testInvalidIndicesOffsetsAndOutOfRoundTapsDoNotBecomeChartPoints() throws {
        let context = try MelodyRhythmContext.hotCrossBuns(section: .phrase3)
        let data = MelodyRhythmChartData(context: context, offsets: [
            -1: 0, 8: 0, 0: -0.01, 1: .nan, 2: .infinity,
            3: -.infinity, 4: 0.226, 5: -0.226, 6: -0.225, 7: 0.225
        ])
        XCTAssertEqual(data.points.map(\.noteIndex), [6, 7])
        XCTAssertEqual(data.points.map(\.time), [3, 3.5])
        XCTAssertEqual(data.missedNoteIndices, [0, 1, 2, 3, 4, 5])
    }

    func testWideValidErrorsExpandTheScaleWithoutHidingRecordedOffsets() throws {
        let context = try MelodyRhythmContext.hotCrossBuns(section: .phrase1)
        let data = MelodyRhythmChartData(context: context, offsets: [0: 0.44, 1: -0.45])
        XCTAssertEqual(data.offsetRange, -500...500)
        XCTAssertEqual(data.points.map(\.milliseconds), [440, -450])
        XCTAssertTrue(data.points.allSatisfy { data.offsetRange.contains($0.milliseconds) })
    }

    func testExplicitRestsAndGapsDoNotAcquireExpectedOrMissingTaps() {
        let reference = MelodyPracticeContext(pieceID: "hotCrossBuns", scoreVersion: 1, register: .lowVoice,
            referenceKey: "G major", tuningA4Hz: 440, tempoBPM: 60, section: .phrase1,
            expectedEvents: [MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 43),
                             MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: nil),
                             MelodyEvent(onsetBeat: 3, durationBeats: 1, midiNote: 47)],
            durationBeats: 4, gradingVersion: nil)
        let data = MelodyRhythmChartData(context: MelodyRhythmContext(reference: reference),
                                         offsets: [0: 0, 1: -0.2], unexpectedTapCount: 2)
        XCTAssertTrue(data.hasValidContext)
        XCTAssertEqual(data.expectedTimes, [0, 3])
        XCTAssertTrue(data.missedNoteIndices.isEmpty)
        XCTAssertEqual(data.points.count, 2)
        XCTAssertEqual(data.unexpectedTapCount, 2)
        XCTAssertTrue(data.accessibilitySummary.contains("2 extra taps"))
        XCTAssertTrue(data.accessibilitySummary.contains("no invented timing offset"))
    }

    func testInvalidContextDoesNotInventMissesOrTiming() throws {
        let valid = try MelodyRhythmContext.hotCrossBuns()
        let invalid = MelodyRhythmContext(reference: valid.reference, scoringVersion: 0)
        for data in [MelodyRhythmChartData(context: invalid, offsets: [0: 0]),
                     MelodyRhythmChartData(context: valid, offsets: [0: 0], unexpectedTapCount: -1)] {
            XCTAssertFalse(data.hasValidContext)
            XCTAssertTrue(data.points.isEmpty)
            XCTAssertTrue(data.missedNoteIndices.isEmpty)
            XCTAssertEqual(data.timeRange, 0...1)
        }
    }

    func testAFirstTapATouchEarlyIsPlottedRatherThanShownAsMissed() throws {
        let context = try MelodyRhythmContext.hotCrossBuns()
        let data = MelodyRhythmChartData(context: context, offsets: [0: -0.11, 1: -0.11, 2: -0.1])
        XCTAssertEqual(data.points.count, 3)
        XCTAssertTrue(data.missedNoteIndices.isEmpty, "Three stars and one missed note cannot both be shown")
    }
}
