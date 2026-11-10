import AVFoundation
import Foundation
import XCTest
@testable import Cello

final class EchoAudioTests: XCTestCase {
    func testRecordedHumanPatternsEarnThreeStarsInBothVoiceRegisters() throws {
        let selections: [(EchoLevel, [Int])] = [(.twoNotes, [0, 1, 2]),
                                               (.threeNotes, [0, 1, 4, 10])]
        for register in [MelodyRegister.lowVoice, .higherVoice] {
            for (level, patterns) in selections {
                for index in patterns {
                    let context = try level.context(patternIndex: index, register: register)
                    let data = try RecordedReference.wavData(context: context)
                    let player = try AVAudioPlayer(data: data)
                    XCTAssertEqual(player.numberOfChannels, 1)
                    XCTAssertEqual(player.duration, Double(level.noteCount * 2),
                                   accuracy: 1 / Double(RecordedReference.sampleRate))
                    let rating = rate(pcm(data), context: context)
                    let selection = "\(level.rawValue), pattern \(index), \(register.rawValue)"
                    XCTAssertEqual(rating.status, .rated, selection)
                    XCTAssertEqual(rating.starCount, 3,
                        "\(selection): Notes \(String(describing: rating.matchedNoteFraction)), Timing \(String(describing: rating.timedNoteFraction)), Clarity \(String(describing: rating.clearNoteFraction))")
                    XCTAssertEqual(rating.noteResults.count, level.noteCount, selection)
                    for (event, result) in zip(context.expectedEvents, rating.noteResults) {
                        XCTAssertEqual(result.expectedStart, event.onsetBeat, accuracy: 1e-6)
                        XCTAssertEqual(result.expectedDuration, 2, accuracy: 1e-6)
                        XCTAssertEqual(try XCTUnwrap(result.expectedFrequency),
                                       try XCTUnwrap(context.frequency(for: event)), accuracy: 1e-6)
                    }
                }
            }
        }
    }

    func testIndependentWrongNotesAndMissingNoteDoNotEarnThreeStars() throws {
        for register in [MelodyRegister.lowVoice, .higherVoice] {
            let context = try EchoLevel.threeNotes.context(patternIndex: 4, register: register)
            let wrongPitch = replacing(context, events: context.expectedEvents.map {
                MelodyEvent(onsetBeat: $0.onsetBeat, durationBeats: $0.durationBeats,
                            midiNote: $0.midiNote.map { $0 + 2 })
            })
            let missingNote = replacing(context, events: context.expectedEvents.enumerated().compactMap {
                $0.offset == 1 ? nil : $0.element
            })
            for signal in [wrongPitch, missingNote] {
                let data = try SyntheticMelodyReference.wavData(context: signal)
                let rating = rate(pcm(data), context: context)
                XCTAssertEqual(rating.status, .rated, "Clear but incorrect sound should receive useful feedback")
                XCTAssertFalse(rating.notes)
                XCTAssertFalse(rating.goalReached)
                XCTAssertLessThan(rating.starCount ?? 3, 3)
                XCTAssertEqual(rating.noteResults.count, 3)
            }
        }
    }

    func testSilenceRemainsUnscoredForEitherEchoLength() throws {
        for level in EchoLevel.allCases {
            let context = try level.context(patternIndex: 1, register: .lowVoice)
            let silence = [Float](repeating: 0,
                count: Int(context.duration * Double(RecordedReference.sampleRate)))
            let rating = rate(silence, context: context)
            XCTAssertNotEqual(rating.status, .rated)
            XCTAssertNil(rating.starCount)
            XCTAssertFalse(rating.goalReached)
        }
    }

    private func rate(_ samples: [Float], context: MelodyPracticeContext) -> MelodyRating {
        MelodyRecordingRater.rate(samples: samples,
            sampleRate: Double(RecordedReference.sampleRate), context: context)
    }

    private func pcm(_ data: Data) -> [Float] {
        stride(from: 44, to: data.count, by: 2).map { offset in
            Float(Int16(bitPattern: UInt16(data[offset]) | UInt16(data[offset + 1]) << 8)) / 32_768
        }
    }

    private func replacing(_ context: MelodyPracticeContext, events: [MelodyEvent]) -> MelodyPracticeContext {
        MelodyPracticeContext(pieceID: context.pieceID, scoreVersion: context.scoreVersion,
            register: context.register, referenceKey: context.referenceKey, tuningA4Hz: context.tuningA4Hz,
            tempoBPM: context.tempoBPM, section: context.section, expectedEvents: events,
            durationBeats: context.durationBeats, gradingVersion: context.gradingVersion)
    }
}
