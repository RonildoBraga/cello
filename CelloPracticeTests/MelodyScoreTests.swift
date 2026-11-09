import Foundation
import XCTest
@testable import Cello

final class MelodyScoreTests: XCTestCase {
    func testHotCrossBunsHasFourCompleteBarsAndSeventeenNotes() {
        let score = MelodyScore.hotCrossBuns
        XCTAssertEqual(score.pieceID, "hotCrossBuns")
        XCTAssertEqual(score.version, 1)
        XCTAssertEqual(score.beatsPerBar, 4)
        XCTAssertEqual(score.totalBeats, 16)
        XCTAssertEqual(score.phraseBoundaries, [0, 4, 8, 12, 16])
        XCTAssertEqual(score.events.map(\.midiNote),
                       [54, 52, 50, 54, 52, 50, 50, 50, 50, 50, 52, 52, 52, 52, 54, 52, 50])
        XCTAssertEqual(score.events.map(\.durationBeats),
                       [1, 1, 2, 1, 1, 2, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, 1, 2])
        XCTAssertEqual(score.events.map(\.onsetBeat),
                       [0, 1, 2, 4, 5, 6, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12, 13, 14])
        XCTAssertEqual(score.events.last?.endBeat, score.totalBeats)
    }

    func testRegistersPreserveEveryIntervalAndDuration() throws {
        let base = try MelodyPracticeContext.hotCrossBuns(register: .cello)
        let low = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice)
        let high = try MelodyPracticeContext.hotCrossBuns(register: .higherVoice)
        XCTAssertEqual(base.expectedEvents.prefix(3).map(\.midiNote), [54, 52, 50])
        XCTAssertEqual(low.expectedEvents.prefix(3).map(\.midiNote), [47, 45, 43])
        XCTAssertEqual(high.expectedEvents.prefix(3).map(\.midiNote), [59, 57, 55])
        for context in [base, low, high] {
            XCTAssertTrue(context.isValid)
            XCTAssertEqual(context.duration, 16)
            XCTAssertEqual(context.referenceKey, context.register.keyName)
            XCTAssertEqual(context.tuningA4Hz, 440)
            XCTAssertNil(context.gradingVersion)
            for (original, transposed) in zip(base.expectedEvents, context.expectedEvents) {
                XCTAssertEqual(transposed.midiNote, original.midiNote.map { $0 + context.register.transpositionSemitones })
                XCTAssertEqual(transposed.onsetBeat, original.onsetBeat)
                XCTAssertEqual(transposed.durationBeats, original.durationBeats)
            }
        }
        XCTAssertEqual(MelodyRegister.lowVoice.rangeLabel, "G2–B2")
        XCTAssertEqual(MelodyRegister.higherVoice.rangeLabel, "G3–B3")
        XCTAssertEqual(MelodyRegister.cello.rangeLabel, "D3–F♯3")
    }

    func testPhraseSelectionsStartAtZeroAndKeepTheirFullFourBeats() throws {
        for (section, count) in [(MelodySection.phrase1, 3), (.phrase2, 3), (.phrase3, 8), (.phrase4, 3)] {
            let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: section)
            XCTAssertEqual(context.section, section)
            XCTAssertEqual(context.expectedEvents.count, count)
            XCTAssertEqual(context.expectedEvents.first?.onsetBeat, 0)
            XCTAssertEqual(context.expectedEvents.last?.endBeat, 4)
            XCTAssertEqual(context.durationBeats, 4)
            XCTAssertEqual(context.duration, 4)
            XCTAssertTrue(context.isValid)
        }
        let repeatedNotes = try MelodyPracticeContext.hotCrossBuns(register: .cello, section: .phrase3)
        XCTAssertEqual(repeatedNotes.expectedEvents.map(\.midiNote), [50, 50, 50, 50, 52, 52, 52, 52])
        XCTAssertEqual(repeatedNotes.expectedEvents.map(\.onsetBeat), [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5])
    }

    func testTempoChangesSecondsWithoutChangingScore() throws {
        let slow = try MelodyPracticeContext.hotCrossBuns(register: .cello, tempoBPM: 40)
        let fast = try MelodyPracticeContext.hotCrossBuns(register: .cello, tempoBPM: 120)
        XCTAssertEqual(slow.duration, 24)
        XCTAssertEqual(fast.duration, 8)
        XCTAssertEqual(slow.expectedEvents, fast.expectedEvents)
        for invalidTempo in [Int.min, 0, 39, 121, Int.max] {
            XCTAssertThrowsError(try MelodyPracticeContext.hotCrossBuns(register: .cello, tempoBPM: invalidTempo))
        }
    }

    func testEventLookupUsesTempoAndExclusiveEndpoints() throws {
        let context = try MelodyPracticeContext.hotCrossBuns(register: .cello, section: .phrase1, tempoBPM: 120)
        XCTAssertEqual(context.eventIndex(at: 0), 0)
        XCTAssertEqual(context.eventIndex(at: 0.499), 0)
        XCTAssertEqual(context.eventIndex(at: 0.5), 1)
        XCTAssertEqual(context.eventIndex(at: 1), 2)
        XCTAssertEqual(context.eventIndex(at: 1.999), 2)
        for outside in [-1.0, 2, 3, .nan, .infinity, -.infinity] {
            XCTAssertNil(context.eventIndex(at: outside))
        }
    }

    func testRestIsAnEventWhileUnwrittenSilenceHasNoEvent() {
        let context = snapshot(events: [
            MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 50),
            MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: nil),
            MelodyEvent(onsetBeat: 3, durationBeats: 1, midiNote: 54)
        ])
        XCTAssertTrue(context.isValid)
        XCTAssertEqual(context.eventIndex(at: 1.5), 1)
        XCTAssertNil(context.frequency(for: context.expectedEvents[1]))
        XCTAssertNil(context.eventIndex(at: 2.5))
        XCTAssertEqual(context.eventIndex(at: 3), 2)
    }

    func testSnapshotRoundTripKeepsSelectedVersionRegisterTempoAndEvents() throws {
        let original = try MelodyPracticeContext.hotCrossBuns(register: .higherVoice, section: .phrase3, tempoBPM: 72)
        let decoded = try JSONDecoder().decode(MelodyPracticeContext.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(decoded, original)
        XCTAssertTrue(decoded.isValid)
        XCTAssertEqual(decoded.pieceID, "hotCrossBuns")
        XCTAssertEqual(decoded.scoreVersion, 1)
        XCTAssertEqual(decoded.register, .higherVoice)
        XCTAssertEqual(decoded.referenceKey, "G major")
        XCTAssertEqual(decoded.tempoBPM, 72)
        XCTAssertEqual(decoded.expectedEvents.count, 8)
        XCTAssertNil(decoded.gradingVersion)
    }

    func testFrequencyUsesTuningAndRejectsInvalidNotes() throws {
        let a4 = MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 69)
        XCTAssertEqual(try XCTUnwrap(a4.frequency()), 440, accuracy: 0.0001)
        XCTAssertEqual(try XCTUnwrap(a4.frequency(tuningA4Hz: 442)), 442, accuracy: 0.0001)
        let d3 = MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 50)
        XCTAssertEqual(try XCTUnwrap(d3.frequency()), 146.8323839587038, accuracy: 0.0001)
        XCTAssertNil(a4.frequency(tuningA4Hz: .nan))
        XCTAssertNil(a4.frequency(tuningA4Hz: 0))
        XCTAssertNil(MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 128).frequency())
        XCTAssertNil(MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: nil).frequency())
    }

    func testMalformedAndUnboundedDecodedTimelinesAreInvalid() {
        for events in [
            [],
            [MelodyEvent(onsetBeat: .nan, durationBeats: 1, midiNote: 50)],
            [MelodyEvent(onsetBeat: 0, durationBeats: .infinity, midiNote: 50)],
            [MelodyEvent(onsetBeat: -1, durationBeats: 1, midiNote: 50)],
            [MelodyEvent(onsetBeat: 0, durationBeats: 0, midiNote: 50)],
            [MelodyEvent(onsetBeat: 0, durationBeats: 5, midiNote: 50)],
            [MelodyEvent(onsetBeat: 0, durationBeats: 2, midiNote: 50),
             MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: 52)],
            [MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: Int.max)],
            Array(repeating: MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 50), count: 129)
        ] {
            let context = snapshot(events: events)
            XCTAssertFalse(context.isValid)
            XCTAssertNil(context.eventIndex(at: 0))
        }
        XCTAssertFalse(snapshot(durationBeats: .nan).isValid)
        XCTAssertFalse(snapshot(durationBeats: 129).isValid)
        XCTAssertFalse(snapshot(tempoBPM: 0).isValid)
    }

    private func snapshot(events: [MelodyEvent] = [MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 50)],
                          durationBeats: Double = 4, tempoBPM: Int = 60) -> MelodyPracticeContext {
        MelodyPracticeContext(pieceID: "hotCrossBuns", scoreVersion: 1, register: .cello,
                              referenceKey: "D major", tuningA4Hz: 440, tempoBPM: tempoBPM,
                              section: .whole, expectedEvents: events, durationBeats: durationBeats,
                              gradingVersion: nil)
    }
}
