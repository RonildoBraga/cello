import Foundation
import XCTest
@testable import Cello

final class OdeToJoyScoreTests: XCTestCase {
    func testOpeningHasFivePitchesAcrossFourCompleteBars() {
        let score = MelodyScore.odeToJoy
        XCTAssertEqual(score.pieceID, "odeToJoy")
        XCTAssertEqual(score.version, 1)
        XCTAssertEqual(score.beatsPerBar, 4)
        XCTAssertEqual(score.totalBeats, 16)
        XCTAssertEqual(score.phraseBoundaries, [0, 4, 8, 12, 16])
        XCTAssertEqual(score.events.map(\.midiNote),
                       [54, 54, 55, 57, 57, 55, 54, 52, 50, 50, 52, 54, 54, 52, 52])
        XCTAssertEqual(Set(score.events.compactMap(\.midiNote)), [50, 52, 54, 55, 57])
        XCTAssertEqual(score.events.map(\.durationBeats), Array(repeating: 1, count: 12) + [1.5, 0.5, 2])
        XCTAssertEqual(score.events.map(\.onsetBeat), Array(0...12).map(Double.init) + [13.5, 14])
        XCTAssertEqual(score.events.last?.endBeat, score.totalBeats)
    }

    func testRegistersKeepIntervalsAndUseTheCorrectFiveNoteRange() throws {
        let base = try MelodyPracticeContext.odeToJoy(register: .cello)
        for (register, range) in [(MelodyRegister.lowVoice, "G2–D3"),
                                  (.higherVoice, "G3–D4"), (.cello, "D3–A3")] {
            let context = try MelodyPracticeContext.odeToJoy(register: register)
            XCTAssertTrue(context.isValid)
            XCTAssertEqual(context.duration, 16)
            XCTAssertEqual(context.referenceKey, register.keyName)
            XCTAssertEqual(context.tuningA4Hz, 440)
            XCTAssertNil(context.gradingVersion)
            XCTAssertEqual(context.rangeLabel, range)
            XCTAssertEqual(MelodyPiece.odeToJoy.rangeLabel(for: register), range)
            for (original, transposed) in zip(base.expectedEvents, context.expectedEvents) {
                XCTAssertEqual(transposed.midiNote, original.midiNote.map { $0 + register.transpositionSemitones })
                XCTAssertEqual(transposed.onsetBeat, original.onsetBeat)
                XCTAssertEqual(transposed.durationBeats, original.durationBeats)
            }
        }
    }

    func testEveryPhraseStartsAtZeroAndKeepsTheFinalHeldNote() throws {
        for (section, count) in [(MelodySection.phrase1, 4), (.phrase2, 4), (.phrase3, 4), (.phrase4, 3)] {
            let context = try MelodyPracticeContext.odeToJoy(register: .lowVoice, section: section)
            XCTAssertEqual(context.section, section)
            XCTAssertEqual(context.expectedEvents.count, count)
            XCTAssertEqual(context.expectedEvents.first?.onsetBeat, 0)
            XCTAssertEqual(context.expectedEvents.last?.endBeat, 4)
            XCTAssertEqual(context.durationBeats, 4)
            XCTAssertTrue(context.isValid)
        }
        let ending = try MelodyPracticeContext.odeToJoy(register: .cello, section: .phrase4)
        XCTAssertEqual(ending.expectedEvents.map(\.midiNote), [54, 52, 52])
        XCTAssertEqual(ending.expectedEvents.map(\.onsetBeat), [0, 1.5, 2])
        XCTAssertEqual(ending.expectedEvents.map(\.durationBeats), [1.5, 0.5, 2])
        XCTAssertEqual(ending.eventIndex(at: 1.499), 0)
        XCTAssertEqual(ending.eventIndex(at: 1.5), 1)
        XCTAssertEqual(ending.eventIndex(at: 2), 2)
        XCTAssertEqual(ending.eventIndex(at: 3.999), 2)
        XCTAssertNil(ending.eventIndex(at: 4))
    }

    func testTempoScalesTheDottedEndingWithoutChangingItsScore() throws {
        let slow = try MelodyPracticeContext.odeToJoy(register: .lowVoice, section: .phrase4, tempoBPM: 40)
        let fast = try MelodyPracticeContext.odeToJoy(register: .lowVoice, section: .phrase4, tempoBPM: 120)
        XCTAssertEqual(slow.duration, 6)
        XCTAssertEqual(fast.duration, 2)
        XCTAssertEqual(slow.expectedEvents, fast.expectedEvents)
        XCTAssertEqual(fast.eventIndex(at: 0.749), 0)
        XCTAssertEqual(fast.eventIndex(at: 0.75), 1)
        XCTAssertEqual(fast.eventIndex(at: 1), 2)
        XCTAssertNil(fast.eventIndex(at: 2))
    }

    func testGenericSelectionMatchesBothConvenienceFactories() throws {
        for register in MelodyRegister.allCases {
            for section in MelodySection.allCases {
                let ode = try MelodyPracticeContext.odeToJoy(register: register, section: section, gradingVersion: 1)
                XCTAssertEqual(ode, try .melody(piece: .odeToJoy, register: register,
                                               section: section, gradingVersion: 1))
                let hot = try MelodyPracticeContext.hotCrossBuns(register: register, section: section, gradingVersion: 1)
                XCTAssertEqual(hot, try .melody(piece: .hotCrossBuns, register: register,
                                               section: section, gradingVersion: 1))
                XCTAssertNotEqual(ode.pieceID, hot.pieceID)
                XCTAssertNotEqual(ode, hot)
            }
        }
    }

    func testHotCrossBunsSnapshotsEncodeExactlyAsTheOriginalFactory() throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let pitches = [54, 52, 50, 54, 52, 50, 50, 50, 50, 50, 52, 52, 52, 52, 54, 52, 50]
        let onsets = [0.0, 1, 2, 4, 5, 6, 8, 8.5, 9, 9.5, 10, 10.5, 11, 11.5, 12, 13, 14]
        let lengths = [1.0, 1, 2, 1, 1, 2, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, 1, 2]
        for register in MelodyRegister.allCases {
            for section in MelodySection.allCases {
                for version in [Int?.none, 1] {
                    let range = section.beatRange
                    let expected = pitches.indices.filter { range.contains(onsets[$0]) }.map {
                        MelodyEvent(onsetBeat: onsets[$0] - range.lowerBound, durationBeats: lengths[$0],
                                    midiNote: pitches[$0] + register.transpositionSemitones)
                    }
                    let original = MelodyPracticeContext(pieceID: "hotCrossBuns", scoreVersion: 1,
                        register: register, referenceKey: register == .cello ? "D major" : "G major",
                        tuningA4Hz: 440, tempoBPM: 72, section: section, expectedEvents: expected,
                        durationBeats: range.upperBound - range.lowerBound, gradingVersion: version)
                    let current = try MelodyPracticeContext.hotCrossBuns(register: register, section: section,
                                                                        tempoBPM: 72, gradingVersion: version)
                    XCTAssertEqual(try encoder.encode(current), try encoder.encode(original))
                }
            }
            XCTAssertEqual(MelodyPiece.hotCrossBuns.rangeLabel(for: register), register.rangeLabel)
        }
    }

    func testFrozenOdeSnapshotRoundTripsWithItsOwnIdentityAndGradingVersion() throws {
        let context = try MelodyPracticeContext.odeToJoy(register: .higherVoice, section: .phrase4,
                                                        tempoBPM: 72, gradingVersion: 1)
        let data = try JSONEncoder().encode(context)
        let restored = try JSONDecoder().decode(MelodyPracticeContext.self, from: data)
        XCTAssertEqual(restored, context)
        XCTAssertEqual(restored.displayPieceTitle, "Ode to Joy")
        XCTAssertEqual(restored.expectedEvents.map(\.onsetBeat), [0, 1.5, 2])
        XCTAssertEqual(restored.gradingVersion, 1)
        XCTAssertTrue(restored.isValid)
        XCTAssertEqual(MelodyPiece.odeToJoy.id, "odeToJoy")
        XCTAssertEqual(try JSONDecoder().decode(MelodyPiece.self, from: JSONEncoder().encode(MelodyPiece.odeToJoy)), .odeToJoy)
    }

    func testGenericFactoryRejectsInvalidTempoAndGradingVersions() {
        for piece in MelodyPiece.allCases {
            for tempo in [Int.min, 0, 39, 121, Int.max] {
                XCTAssertThrowsError(try MelodyPracticeContext.melody(piece: piece, register: .lowVoice, tempoBPM: tempo))
            }
            for version in [0, -1, Int.min] {
                XCTAssertThrowsError(try MelodyPracticeContext.melody(piece: piece, register: .lowVoice,
                                                                     gradingVersion: version))
            }
        }
    }

    func testFrozenRangeUsesSelectedMidiNotesRatherThanCurrentPieceOrTuning() {
        let context = MelodyPracticeContext(pieceID: "futurePiece", scoreVersion: 7, register: .cello,
            referenceKey: "A major", tuningA4Hz: 480, tempoBPM: 60, section: .phrase1,
            expectedEvents: [MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: nil),
                             MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: 57)],
            durationBeats: 4, gradingVersion: nil)
        XCTAssertTrue(context.isValid)
        XCTAssertEqual(context.displayPieceTitle, "Melody")
        XCTAssertEqual(context.rangeLabel, "A3")
    }
}
