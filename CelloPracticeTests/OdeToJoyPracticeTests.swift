import AVFoundation
import CelloPitch
import Foundation
import XCTest
@testable import Cello

final class OdeToJoyPracticeTests: XCTestCase {
    func testRecordedHumanPhrasesAndWholeOpeningEarnThreeIndependentStars() throws {
        for register in [MelodyRegister.lowVoice, .higherVoice] {
            for section in MelodySection.allCases {
                let context = try MelodyPracticeContext.odeToJoy(
                    register: register, section: section, gradingVersion: MelodyRating.currentVersion)
                let data = try RecordedReference.wavData(context: context)
                let player = try AVAudioPlayer(data: data)
                XCTAssertEqual(player.numberOfChannels, 1)
                XCTAssertEqual(player.duration, context.duration, accuracy: 1 / Double(RecordedReference.sampleRate))
                let sound = pcm(data)
                XCTAssertEqual(sound.first, 0)
                XCTAssertEqual(sound.last, 0)
                XCTAssertLessThan(sound.map(abs).max() ?? 1, 0.90)
                let rating = rate(sound, for: context)
                XCTAssertEqual(rating.status, .rated, "\(register.rawValue), \(section.rawValue)")
                XCTAssertEqual(rating.starCount, 3,
                    "\(register.rawValue), \(section.rawValue): notes \(String(describing: rating.matchedNoteFraction)), timing \(String(describing: rating.timedNoteFraction)), clarity \(String(describing: rating.clearNoteFraction))")
                XCTAssertEqual(rating.noteResults.count, context.expectedEvents.count)
            }
        }
    }

    func testAllFiveRecordedPitchTargetsMatchEachVoiceAndCelloRegister() throws {
        for register in MelodyRegister.allCases {
            var heardNotes: Set<Int> = []
            for section in [MelodySection.phrase1, .phrase3] {
                let context = try MelodyPracticeContext.odeToJoy(register: register, section: section)
                let sound = pcm(try RecordedReference.wavData(context: context))
                for event in context.expectedEvents {
                    heardNotes.insert(try XCTUnwrap(event.midiNote))
                    let measured = measuredFrequencies(sound, times: [0.25, 0.40, 0.55, 0.70].map {
                        event.onsetBeat + $0
                    })
                    XCTAssertGreaterThanOrEqual(measured.count, 3)
                    let actual = try XCTUnwrap(median(measured))
                    let expected = try XCTUnwrap(context.frequency(for: event))
                    XCTAssertLessThan(abs(1_200 * log2(actual / expected)), 25,
                                      "\(register.rawValue), MIDI \(event.midiNote ?? -1)")
                }
            }
            XCTAssertEqual(heardNotes, Set([50, 52, 54, 55, 57].map { $0 + register.transpositionSemitones }))
        }
    }

    func testIndependentWrongPitchAndMissingNoteSignalsDoNotEarnNotesOrThreeStars() throws {
        let context = try MelodyPracticeContext.odeToJoy(register: .lowVoice, section: .phrase1,
                                                         gradingVersion: MelodyRating.currentVersion)
        let wrongPitch = replacing(context, events: context.expectedEvents.map {
            MelodyEvent(onsetBeat: $0.onsetBeat, durationBeats: $0.durationBeats,
                        midiNote: $0.midiNote.map { $0 + 2 })
        })
        let missingNote = replacing(context, events: context.expectedEvents.enumerated().compactMap {
            $0.offset == 1 ? nil : $0.element
        })
        for signal in [wrongPitch, missingNote] {
            let samples = pcm(try SyntheticMelodyReference.wavData(context: signal))
            let rating = rate(samples, for: context)
            XCTAssertEqual(rating.status, .rated, "A clear but incorrect melody should receive useful feedback")
            XCTAssertFalse(rating.notes)
            XCTAssertFalse(rating.goalReached)
            XCTAssertLessThan(rating.starCount ?? 3, 3)
            XCTAssertEqual(rating.noteResults.count, 4)
        }
    }

    func testDottedEndingRequiresItsRealOnsetsAndCountsAnExtraHeldBeat() throws {
        for section in MelodySection.allCases {
            let context = try MelodyRhythmContext.melody(piece: .odeToJoy, section: section)
            let timing = round(context)
            XCTAssertEqual(try XCTUnwrap(MelodyRhythmAttempt(timing: timing, finishedAt: timing.endTime)).starCount, 3)
        }
        let context = try MelodyRhythmContext.melody(piece: .odeToJoy, section: .phrase4)
        XCTAssertEqual(context.expectedTapTimes, [0, 1.5, 2])
        let quarterNotes = round(context, times: [0.04, 1.04, 2.04])
        let incorrect = try XCTUnwrap(MelodyRhythmAttempt(timing: quarterNotes, finishedAt: quarterNotes.endTime))
        XCTAssertEqual(incorrect.matchedTapCount, 2)
        XCTAssertEqual(incorrect.missingTapCount, 1)
        XCTAssertEqual(incorrect.unexpectedTapCount, 1)
        XCTAssertFalse(incorrect.patternGoal)
        XCTAssertNotEqual(incorrect.starCount, 3)

        var extra = round(context)
        XCTAssertTrue(extra.canTap(at: extra.practiceStartTime + 3))
        extra.recordTap(at: extra.practiceStartTime + 3)
        let result = try XCTUnwrap(MelodyRhythmAttempt(timing: extra, finishedAt: extra.endTime))
        XCTAssertEqual(result.unexpectedTapCount, 1)
        XCTAssertFalse(result.patternGoal)
        XCTAssertTrue(result.timingGoal)
        XCTAssertTrue(result.consistencyGoal)
        XCTAssertEqual(result.starCount, 2)
    }

    @MainActor
    func testHummingAndRhythmProgressStaySeparateForBothPiecesAfterReload() throws {
        let hot = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1,
                                                        gradingVersion: MelodyRating.currentVersion)
        let ode = try MelodyPracticeContext.odeToJoy(register: .lowVoice, section: .phrase1,
                                                    gradingVersion: MelodyRating.currentVersion)
        let hotRating = rate(pcm(try RecordedReference.wavData(context: hot)), for: hot)
        let odeRating = rate(pcm(try RecordedReference.wavData(context: ode)), for: ode)
        XCTAssertEqual(hotRating.starCount, 3)
        XCTAssertEqual(odeRating.starCount, 3)
        let hotSessions = (0..<2).map { session(context: hot, rating: hotRating, at: $0) }
        let odeSessions = (2..<5).map { session(context: ode, rating: odeRating, at: $0) }
        let sessions = hotSessions + odeSessions
        var ledger = MelodyProgressLedger()
        XCTAssertTrue(ledger.update(from: sessions))
        let restored = try JSONDecoder().decode(MelodyProgressLedger.self, from: JSONEncoder().encode(ledger))
        XCTAssertTrue(restored.progress(for: ode, sessions: sessions).completed)
        XCTAssertEqual(restored.progress(for: hot, sessions: sessions).successfulAttempts, 2)
        XCTAssertFalse(restored.progress(for: hot, sessions: sessions).completed)
        let nextPhrase = try MelodyPracticeContext.odeToJoy(register: .lowVoice, section: .phrase2,
                                                           gradingVersion: MelodyRating.currentVersion)
        XCTAssertFalse(restored.progress(for: nextPhrase, sessions: sessions).completed)

        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("OdePractice-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = MelodyRhythmStore(directory: directory)
        let hotRhythm = try MelodyRhythmContext.hotCrossBuns()
        let odeRhythm = try MelodyRhythmContext.melody(piece: .odeToJoy)
        for context in [hotRhythm, hotRhythm, odeRhythm, odeRhythm, odeRhythm] {
            let timing = round(context)
            XCTAssertEqual(store.record(timing: timing, at: timing.endTime)?.starCount, 3)
        }
        let reloaded = MelodyRhythmStore(directory: directory)
        XCTAssertNil(reloaded.errorMessage)
        XCTAssertEqual(reloaded.attempts.count, 5)
        XCTAssertTrue(reloaded.progress(for: odeRhythm).completed)
        XCTAssertEqual(reloaded.progress(for: hotRhythm).successfulAttempts, 2)
        XCTAssertFalse(reloaded.progress(for: hotRhythm).completed)
        XCTAssertFalse(reloaded.progress(for: try .melody(piece: .odeToJoy, section: .whole)).completed)
        XCTAssertFalse(reloaded.progress(for: try .melody(piece: .odeToJoy, section: .phrase2)).completed)
        XCTAssertEqual(restored.progress(for: hot, sessions: sessions).successfulAttempts, 2,
                       "Rhythm completion must not grant humming completion")
    }

    func testRecordedRatedSessionRoundTripsItsOdeTitleAndFrozenContext() throws {
        let context = try MelodyPracticeContext.odeToJoy(register: .higherVoice, section: .phrase4,
                                                         gradingVersion: MelodyRating.currentVersion)
        let rating = rate(pcm(try RecordedReference.wavData(context: context)), for: context)
        XCTAssertEqual(rating.starCount, 3)
        let original = session(context: context, rating: rating, at: 0)
        let restored = try JSONDecoder().decode(PracticeSession.self, from: JSONEncoder().encode(original))
        XCTAssertEqual(restored.title, "Ode to Joy · Phrase 4")
        XCTAssertEqual(restored.melodyContext, context)
        XCTAssertEqual(restored.melodyRating, rating)
        XCTAssertEqual(restored.starCount, 3)
        XCTAssertNil(restored.rating)
        XCTAssertNil(restored.effectiveTargetFrequency)
        XCTAssertEqual(restored.melodyContext?.expectedEvents.map(\.onsetBeat), [0, 1.5, 2])
        XCTAssertEqual(restored.melodyRating?.noteResults.map(\.expectedStart), [0, 1.5, 2])
    }

    private func rate(_ samples: [Float], for context: MelodyPracticeContext) -> MelodyRating {
        MelodyRecordingRater.rate(samples: samples, sampleRate: Double(RecordedReference.sampleRate), context: context)
    }

    private func pcm(_ data: Data) -> [Float] {
        stride(from: 44, to: data.count, by: 2).map { offset in
            Float(Int16(bitPattern: UInt16(data[offset]) | UInt16(data[offset + 1]) << 8)) / 32_768
        }
    }

    private func measuredFrequencies(_ samples: [Float], times: [Double]) -> [Double] {
        let detector = PitchDetector()
        return times.compactMap { time in
            let start = Int(time * Double(RecordedReference.sampleRate))
            guard start + 8_192 <= samples.count,
                  let estimate = detector.estimate(samples: Array(samples[start..<(start + 8_192)]),
                      sampleRate: Double(RecordedReference.sampleRate)), estimate.confidence >= 0.75 else { return nil }
            return estimate.frequency
        }
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private func round(_ context: MelodyRhythmContext, times: [Double]? = nil) -> MelodyRhythmTiming {
        var timing = MelodyRhythmTiming(startTime: 100, context: context)
        for time in times ?? context.expectedTapTimes.map({ $0 + 0.04 }) {
            timing.recordTap(at: timing.practiceStartTime + time)
        }
        return timing
    }

    private func replacing(_ context: MelodyPracticeContext, events: [MelodyEvent]) -> MelodyPracticeContext {
        MelodyPracticeContext(pieceID: context.pieceID, scoreVersion: context.scoreVersion,
            register: context.register, referenceKey: context.referenceKey, tuningA4Hz: context.tuningA4Hz,
            tempoBPM: context.tempoBPM, section: context.section, expectedEvents: events,
            durationBeats: context.durationBeats, gradingVersion: context.gradingVersion)
    }

    private func session(context: MelodyPracticeContext, rating: MelodyRating, at index: Int) -> PracticeSession {
        PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: Double(index)), exercise: .listen,
            duration: context.duration, notes: "", pitchSamples: [], videoFilename: "fixture.mov",
            melodyContext: context, melodyRating: rating)
    }
}
