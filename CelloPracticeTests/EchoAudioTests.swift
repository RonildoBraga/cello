import AVFoundation
import CelloPitch
import Foundation
import XCTest
@testable import Cello

final class EchoAudioTests: XCTestCase {
    func testRecordedHumanPatternsEarnThreeStarsInTheLowVoice() throws {
        let selections: [(EchoLevel, [Int])] = [(.twoNotes, [0, 1, 2]),
                                               (.threeNotes, [0, 1, 4, 10])]
        for register in [MelodyRegister.lowVoice] {
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

    func testTimingGuideAloneCannotEarnEchoNotesOrTiming() throws {
        for register in [MelodyRegister.lowVoice, .cello] {
            let context = try EchoLevel.twoNotes.context(patternIndex: 4, register: register)
            let clicks = try guideSamples(for: context)
            XCTAssertGreaterThan(clicks.map(abs).max() ?? 0, 0,
                                 "The test must contain audible guide clicks, not silence")
            let rating = rate(clicks, context: context)
            XCTAssertFalse(rating.notes, "The app's own guide is not a played note")
            XCTAssertFalse(rating.timing, "Guide clicks cannot supply the learner's note starts")
            XCTAssertNotEqual(rating.starCount, 3)
            XCTAssertFalse(rating.goalReached)
        }
    }

    func testQuietTimingClicksPreserveRecordedOpenStringEchoAssessment() throws {
        let context = try EchoLevel.twoNotes.context(patternIndex: 4, register: .cello)
        let clean = pcm(try RecordedReference.wavData(context: context))
        let baseline = rate(clean, context: context)
        XCTAssertEqual(baseline.status, .rated)
        XCTAssertEqual(baseline.starCount, 3, "The independent recorded cello must first pass on its own")

        let mixed = rate(try addingGuide(to: clean, context: context), context: context)
        XCTAssertEqual(mixed.status, baseline.status)
        XCTAssertEqual(mixed.starCount, baseline.starCount,
                       "Quiet guide leakage must not spoil correct open-string playing")
        XCTAssertTrue(mixed.notes)
        XCTAssertTrue(mixed.timing)
        XCTAssertTrue(mixed.clarity)
    }

    func testTimingClicksDoNotHideWrongPitchOrALateOpenStringChange() throws {
        let context = try EchoLevel.twoNotes.context(patternIndex: 4, register: .cello)
        let wrong = replacing(context, events: context.expectedEvents.enumerated().map { index, event in
            MelodyEvent(onsetBeat: event.onsetBeat, durationBeats: event.durationBeats,
                        midiNote: event.midiNote.map { $0 + (index == 1 ? 2 : 0) })
        })
        let wrongSound = pcm(try RecordedReference.wavData(context: wrong))
        let wrongRating = rate(try addingGuide(to: wrongSound, context: context), context: context)
        XCTAssertEqual(wrongRating.status, .rated)
        XCTAssertFalse(wrongRating.notes, "An on-time guide cannot turn a wrong second pitch into G2")
        XCTAssertFalse(wrongRating.goalReached)

        let late = replacing(context, events: context.expectedEvents.enumerated().map { index, event in
            let delay = index == 1 ? 0.4 : 0
            return MelodyEvent(onsetBeat: event.onsetBeat + delay,
                               durationBeats: event.durationBeats - delay, midiNote: event.midiNote)
        })
        let lateSound = pcm(try RecordedReference.wavData(context: late))
        let lateRating = rate(try addingGuide(to: lateSound, context: context), context: context)
        XCTAssertEqual(lateRating.status, .rated)
        XCTAssertTrue(lateRating.notes)
        XCTAssertFalse(lateRating.timing, "The guide's on-time click must not hide a 0.4-second late G2")
        XCTAssertFalse(lateRating.goalReached)
    }

    /// Simulates quiet speaker leakage without deleting the note attacks being judged.
    /// Acoustic behaviour on an actual phone still needs a physical recording test.
    private func addingGuide(to samples: [Float], context: MelodyPracticeContext) throws -> [Float] {
        let clicks = try guideSamples(for: context)
        XCTAssertEqual(samples.count, clicks.count)
        return zip(samples, clicks).map { sound, click in sound + 0.25 * click }
    }

    private func guideSamples(for context: MelodyPracticeContext) throws -> [Float] {
        let secondsPerBeat = 60 / Double(context.tempoBPM)
        let guide = PracticeTimingGuide(beatInterval: secondsPerBeat, duration: context.duration,
                                       noteOnsets: context.expectedEvents.filter { $0.midiNote != nil }
                                           .map { $0.onsetBeat * secondsPerBeat })
        let buffer = try XCTUnwrap(guide.audioBuffer(sampleRate: Double(RecordedReference.sampleRate)))
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        let start = Int((guide.countInDuration * Double(RecordedReference.sampleRate)).rounded())
        let count = Int((context.duration * Double(RecordedReference.sampleRate)).rounded())
        guard start + count <= Int(buffer.frameLength) else {
            XCTFail("The guide must cover the take after its count-in")
            return []
        }
        return Array(UnsafeBufferPointer(start: channel + start, count: count))
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
