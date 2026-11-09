import Foundation
import XCTest
@testable import Cello

final class MelodyTraceTests: XCTestCase {
    func testExpectedPhraseKeepsItsTimedStepsAndActualOctave() throws {
        let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1)
        let first = try XCTUnwrap(context.expectedEvents.first?.frequency())
        let data = MelodyTraceData(context: context, samples: [
            sample(0.2, first), sample(0.3, first * 2), sample(0.4, first / 2)
        ], duration: 4)
        XCTAssertEqual(data.expectedNotes.map(\.start), [0, 1, 2])
        XCTAssertEqual(data.expectedNotes.map(\.end), [1, 2, 4])
        XCTAssertEqual(data.expectedNotes.map(\.pitch), [47, 45, 43])
        XCTAssertEqual(data.points[0].pitch, 47, accuracy: 1e-8)
        XCTAssertEqual(data.points[1].pitch, 59, accuracy: 1e-8)
        XCTAssertEqual(data.points[2].pitch, 35, accuracy: 1e-8)
        XCTAssertTrue(data.points.allSatisfy { data.pitchRange.contains($0.pitch) })
        XCTAssertEqual(data.timeRange, 0...4)
    }

    func testRestsAndUnwrittenSilenceNeverBecomeReferenceNotes() throws {
        let source = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1)
        let context = MelodyPracticeContext(pieceID: source.pieceID, scoreVersion: source.scoreVersion,
            register: source.register, referenceKey: source.referenceKey, tuningA4Hz: source.tuningA4Hz,
            tempoBPM: 60, section: .phrase1, expectedEvents: [
                MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 47),
                MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: nil),
                MelodyEvent(onsetBeat: 3, durationBeats: 1, midiNote: 43)
            ], durationBeats: 4, gradingVersion: nil)
        let data = MelodyTraceData(context: context, samples: [], duration: 4)
        XCTAssertEqual(data.expectedNotes.map(\.id), [0, 2])
        XCTAssertEqual(data.expectedNotes.map(\.start), [0, 3])
        XCTAssertEqual(data.expectedNotes.map(\.end), [1, 4])
        XCTAssertTrue(data.points.isEmpty)
    }

    func testSilenceAndRejectedReadingsSplitTheObservedLine() throws {
        let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1)
        let data = MelodyTraceData(context: context, samples: [
            sample(0.1, 110), sample(0.2, 110),
            sample(0.3, 110, confidence: 0.4), sample(0.4, 110),
            sample(0.8, 110), sample(0.9, 110),
            sample(1, 110, rms: 0), sample(1.1, 110)
        ], duration: 4)
        XCTAssertEqual(data.points.map(\.time), [0.1, 0.2, 0.4, 0.8, 0.9, 1.1])
        XCTAssertEqual(data.points.map(\.segment), [0, 0, 1, 2, 2, 3])
    }

    func testInvalidReadingsCannotDistortAxesAndPointsStayTimeSorted() throws {
        let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1)
        let data = MelodyTraceData(context: context, samples: [
            sample(0.4, 110), sample(0.1, 110), sample(-1, 110), sample(.nan, 110),
            sample(5, 110), sample(0.5, .nan), sample(0.6, .infinity), sample(0.7, 0),
            sample(0.8, 1), sample(0.9, 100_000), sample(1, 110, confidence: .infinity),
            sample(1.1, 110, confidence: 1.1), sample(1.2, 110, rms: .nan)
        ], duration: .nan)
        XCTAssertEqual(data.points.map(\.time), [0.1, 0.4])
        XCTAssertEqual(data.timeRange, 0...4)
        XCTAssertTrue(data.pitchRange.lowerBound.isFinite && data.pitchRange.upperBound.isFinite)
        XCTAssertLessThan(data.pitchRange.upperBound - data.pitchRange.lowerBound, 10)
    }

    func testChartAlwaysShowsFullReferenceWhenRecordingStopsEarly() throws {
        let context = try MelodyPracticeContext.hotCrossBuns(register: .higherVoice)
        let data = MelodyTraceData(context: context, samples: [sample(0.2, 220), sample(0.7, 220)], duration: 0.5)
        XCTAssertEqual(data.timeRange, 0...16)
        XCTAssertEqual(data.expectedNotes.last?.end, 16)
        XCTAssertEqual(data.points.count, 1)
        XCTAssertEqual(MelodyTraceData.noteName(for: 55), "G3")
        XCTAssertEqual(MelodyTraceData.noteName(for: 59), "B3")
        XCTAssertEqual(MelodyTraceData.noteName(for: .infinity), "—")
    }

    func testChartUsesTheFrozenA4TuningWithoutChangingItsNoteNames() throws {
        let source = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1)
        let context = MelodyPracticeContext(pieceID: source.pieceID, scoreVersion: source.scoreVersion,
            register: source.register, referenceKey: source.referenceKey, tuningA4Hz: 432,
            tempoBPM: source.tempoBPM, section: source.section, expectedEvents: source.expectedEvents,
            durationBeats: source.durationBeats, gradingVersion: nil)
        let frequency = try XCTUnwrap(context.frequency(for: context.expectedEvents[0]))
        let data = MelodyTraceData(context: context, samples: [sample(0.1, frequency)], duration: 4)
        XCTAssertEqual(data.expectedNotes.first?.pitch, 47)
        XCTAssertEqual(try XCTUnwrap(data.points.first?.pitch), 47, accuracy: 1e-8)
    }

    func testInvalidContextHasNoTargetOrObservedPitchAndFiniteAxes() throws {
        let source = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1)
        let context = MelodyPracticeContext(pieceID: source.pieceID, scoreVersion: source.scoreVersion,
            register: source.register, referenceKey: source.referenceKey, tuningA4Hz: source.tuningA4Hz,
            tempoBPM: 0, section: source.section, expectedEvents: source.expectedEvents,
            durationBeats: source.durationBeats, gradingVersion: nil)
        let data = MelodyTraceData(context: context, samples: [sample(0.1, 110)], duration: .infinity)
        XCTAssertFalse(data.hasValidContext)
        XCTAssertTrue(data.expectedNotes.isEmpty)
        XCTAssertTrue(data.points.isEmpty)
        XCTAssertEqual(data.timeRange, 0...1)
        XCTAssertTrue(data.pitchRange.lowerBound.isFinite && data.pitchRange.upperBound.isFinite)
    }

    func testSavedAudioMissesAndOctaveAmbiguityBreakTheTrace() throws {
        let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1)
        let rating = MelodyRating(status: .unclear, pitchPoints: [
            MelodyPitchPoint(time: 0.1, frequency: 110, confidence: 0.95, rms: 0.02, ambiguous: false),
            MelodyPitchPoint(time: 0.2, frequency: nil, confidence: 0, rms: 0.02, ambiguous: false),
            MelodyPitchPoint(time: 0.3, frequency: 110, confidence: 0.95, rms: 0.02, ambiguous: false),
            MelodyPitchPoint(time: 0.4, frequency: 220, confidence: 0.95, rms: 0.02, ambiguous: true),
            MelodyPitchPoint(time: 0.5, frequency: 220, confidence: 0.95, rms: 0.02, ambiguous: false)
        ])
        let data = MelodyTraceData(context: context, rating: rating, duration: 4)
        XCTAssertEqual(data.points.map(\.time), [0.1, 0.3, 0.5])
        XCTAssertEqual(data.points.map(\.segment), [0, 1, 2])
        XCTAssertEqual(data.points[2].pitch - data.points[0].pitch, 12, accuracy: 1e-8)
        XCTAssertNil(rating.starCount, "Plotting a clear subset must not turn an unclear take into stars")
    }

    private func sample(_ time: Double, _ frequency: Double, confidence: Double = 0.95,
                        rms: Double = 0.02) -> PitchSample {
        PitchSample(time: time, frequency: frequency, confidence: confidence, rms: rms)
    }
}
