import AVFoundation
import CelloPitch
import Foundation
import XCTest
@testable import Cello

final class OdeToJoyPracticeTests: XCTestCase {
    func testRecordedPhrasesAndWholeOpeningEarnThreeIndependentStarsHummedAndOnTheCello() throws {
        // Twinkle's jump of five notes, Lightly Row's skips and Yankee Doodle's running notes are scored
        // by the same rater as the steps of Ode to Joy.
        for piece in [MelodyPiece.odeToJoy, .twinkle, .lightlyRow, .oldMacDonald, .yankeeDoodle, .gMajorScale, .preludeChords] {
            for register in PracticeMethod.allCases.map(\.register) {
                for section in MelodySection.allCases {
                    let context = try MelodyPracticeContext.melody(
                        piece: piece, register: register, section: section, gradingVersion: MelodyRating.currentVersion)
                    let data = try RecordedReference.wavData(context: context)
                    let player = try AVAudioPlayer(data: data)
                    XCTAssertEqual(player.numberOfChannels, 1)
                    XCTAssertEqual(player.duration, context.duration, accuracy: 1 / Double(RecordedReference.sampleRate))
                    let sound = pcm(data)
                    XCTAssertEqual(sound.first, 0)
                    XCTAssertEqual(sound.last, 0)
                    XCTAssertLessThan(sound.map(abs).max() ?? 1, 0.90)
                    let rating = rate(sound, for: context)
                    let take = "\(piece.title), \(register.rawValue), \(section.rawValue)"
                    XCTAssertEqual(rating.status, .rated, take)
                    XCTAssertEqual(rating.starCount, 3,
                        "\(take): notes \(String(describing: rating.matchedNoteFraction)), timing \(String(describing: rating.timedNoteFraction)), clarity \(String(describing: rating.clearNoteFraction))")
                    XCTAssertEqual(rating.noteResults.count, context.expectedEvents.count)
                }
            }
        }
    }

    func testEveryRecordedPitchTargetMatchesInTheVoiceAndCelloRegisters() throws {
        // Twinkle reaches one note higher than Ode to Joy in each register: E3 hummed, B3 on the cello.
        let pieces: [(MelodyPiece, [MelodySection], [Int])] = [
            (.odeToJoy, [.phrase1, .phrase3], [50, 52, 54, 55, 57]),
            (.twinkle, MelodySection.phrases, [50, 52, 54, 55, 57, 59]),
            (.lightlyRow, MelodySection.phrases, [50, 52, 54, 55, 57]),
            (.oldMacDonald, MelodySection.phrases, [50, 52, 55, 57, 59]),
            (.yankeeDoodle, MelodySection.phrases, [50, 52, 54, 55, 57, 59, 60]),
            (.gMajorScale, MelodySection.phrases, [43, 45, 47, 48, 50, 52, 54, 55]),
            (.preludeChords, MelodySection.phrases, [43, 50, 52, 54, 55, 59, 60])]
        for (piece, sections, notes) in pieces {
            for register in PracticeMethod.allCases.map(\.register) {
                var heardNotes: Set<Int> = []
                for section in sections {
                    let context = try MelodyPracticeContext.melody(piece: piece, register: register, section: section)
                    let sound = pcm(try RecordedReference.wavData(context: context))
                    for event in context.expectedEvents {
                        heardNotes.insert(try XCTUnwrap(event.midiNote))
                        // Inside the note: a half-beat note is measured over its own half beat.
                        let measured = measuredFrequencies(sound, times: [0.25, 0.40, 0.55, 0.70].map {
                            event.onsetBeat + $0 * min(event.durationBeats, 1)
                        })
                        XCTAssertGreaterThanOrEqual(measured.count, 3)
                        let actual = try XCTUnwrap(median(measured))
                        let expected = try XCTUnwrap(context.frequency(for: event))
                        XCTAssertLessThan(abs(1_200 * log2(actual / expected)), 25,
                                          "\(piece.title), \(register.rawValue), MIDI \(event.midiNote ?? -1)")
                    }
                }
                XCTAssertEqual(heardNotes, Set(notes.map { $0 + piece.transposition(for: register) }))
            }
        }
    }

    func testQuickNotesAreHeardThroughSteadyHissThatFillsTheirPauses() throws {
        let context = MelodyPiece.hotCrossBuns.humming(register: .lowVoice, section: .phrase3)
        let rating = rate(withHiss(pcm(try RecordedReference.wavData(context: context))), for: context)
        XCTAssertEqual(rating.noteResults.filter { $0.observedOnset != nil }.count, 8)
        XCTAssertEqual(rating.starCount, 3)
    }

    func testRunningNotesAreHeardThroughTheSameHissHummedAndOnTheCello() throws {
        for register in PracticeMethod.allCases.map(\.register) {
            for section in MelodySection.allCases {
                let context = MelodyPiece.yankeeDoodle.humming(register: register, section: section)
                let rating = rate(withHiss(pcm(try RecordedReference.wavData(context: context))), for: context)
                let take = "\(register.rawValue), \(section.rawValue)"
                XCTAssertEqual(rating.noteResults.filter { $0.observedOnset != nil }.count, context.expectedEvents.count, take)
                XCTAssertEqual(rating.starCount, 3, take)
            }
        }
    }

    func testTheTeacherNoteOnRunningNotesThatAreLateRushedOrRunTogether() throws {
        let context = MelodyPiece.yankeeDoodle.humming(register: .lowVoice, section: .phrase1)
        func note(sung events: [MelodyEvent]) throws -> (MelodyRating, [String]) {
            let rating = rate(pcm(try RecordedReference.wavData(context: replacing(context, events: events))), for: context)
            return (rating, TeacherNote(rating: rating, register: .lowVoice).paragraphs)
        }
        let asked = context.expectedEvents
        // The whole run a quarter of a beat late: it started late and kept going at the right speed.
        let late = asked.enumerated().map { index, event in
            MelodyEvent(onsetBeat: event.onsetBeat + 0.25, durationBeats: index == asked.count - 1 ? 0.25 : 0.5,
                        midiNote: event.midiNote)
        }
        let (lateRating, lateNote) = try note(sung: late)
        XCTAssertFalse(lateRating.timing)
        XCTAssertTrue(lateRating.notes)
        XCTAssertEqual(lateNote.first, "All the notes began about 0.2 s late. Change note as each bar reaches the line.")
        // Rushed: at fifteen sixteenths of the time, each note a little sooner than the last.
        let rushed = asked.map { MelodyEvent(onsetBeat: $0.onsetBeat * 15 / 16, durationBeats: 0.5 * 15 / 16, midiNote: $0.midiNote) }
        let (rushedRating, rushedNote) = try note(sung: rushed)
        XCTAssertFalse(rushedRating.timing)
        XCTAssertEqual(rushedNote.first, "Notes 7 and 8 began about 0.2 s early. Wait for each bar to reach the line.")
        // The two G's that open the phrase run together as one long note: the second is not heard apart.
        let together = [MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: asked[0].midiNote)] + asked.dropFirst(2)
        let (togetherRating, togetherNote) = try note(sung: Array(together))
        XCTAssertNil(togetherRating.noteResults[1].observedOnset)
        XCTAssertTrue(togetherRating.goalReached, "One note in eight may go unheard")
        XCTAssertEqual(togetherNote, ["All three goals reached. Try this phrase again, then move to the next one.",
                                      "Also: 7 of the 8 notes were heard. Give each note a clear start of its own."])
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
        XCTAssertEqual(incorrect.offsets.count, 2)
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
        let context = try MelodyPracticeContext.odeToJoy(register: .lowVoice, section: .phrase4,
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

    func testAPhraseOfOneHeldNoteNeedsOneTapAndNoMoreWhileItContinues() throws {
        // Old MacDonald's last phrase is one note held for four beats.
        let context = try MelodyRhythmContext.melody(piece: .oldMacDonald, section: .phrase4)
        XCTAssertEqual(context.expectedTapTimes, [0])
        let held = round(context)
        XCTAssertEqual(try XCTUnwrap(MelodyRhythmAttempt(timing: held, finishedAt: held.endTime)).starCount, 3)
        var tapped = round(context)
        tapped.recordTap(at: tapped.practiceStartTime + 2)
        let extra = try XCTUnwrap(MelodyRhythmAttempt(timing: tapped, finishedAt: tapped.endTime))
        XCTAssertEqual(extra.unexpectedTapCount, 1)
        XCTAssertFalse(extra.patternGoal, "A tap while the note continues is one too many")
        XCTAssertEqual(extra.starCount, 2)
        for section in MelodySection.allCases {
            let timing = round(try MelodyRhythmContext.melody(piece: .oldMacDonald, section: section))
            XCTAssertEqual(try XCTUnwrap(MelodyRhythmAttempt(timing: timing, finishedAt: timing.endTime)).starCount, 3, section.rawValue)
        }
    }

    func testTheTeacherNoteNamesAJumpThatFellShortOrWentTooFar() throws {
        // Bach's first chord, G2 D3 B3 D3, with the jump to the top note sung a whole tone short, then a
        // whole tone too far. D3 comes twice, so notes go by number, with their name.
        let context = MelodyPiece.preludeChords.humming(register: .lowVoice, section: .phrase1)
        for (shift, expected) in [(-2, "Note 3 (B3) was low. Aim higher on it."), (2, "Note 3 (B3) was high. Aim lower on it.")] {
            let sung = context.expectedEvents.enumerated().map { index, event in
                MelodyEvent(onsetBeat: event.onsetBeat, durationBeats: event.durationBeats,
                            midiNote: event.midiNote.map { index == 2 ? $0 + shift : $0 })
            }
            let rating = rate(pcm(try RecordedReference.wavData(context: replacing(context, events: sung))), for: context)
            XCTAssertFalse(rating.notes, "One note in four is more than the Notes goal allows")
            XCTAssertEqual(TeacherNote(rating: rating, register: .lowVoice).paragraphs.first, expected)
        }
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

    /// The example at a real hum's level (loud parts near -47 dBFS) with hiss 13 dB below it.
    /// The hiss alone is above the level that counts as sound, so no pause between the notes
    /// falls silent: the fresh starts are heard as dips.
    private func withHiss(_ clean: [Float]) -> [Float] {
        let cells = stride(from: 0, to: clean.count - 480, by: 480).map { start in
            (clean[start..<(start + 480)].reduce(0.0) { $0 + Double($1) * Double($1) } / 480).squareRoot()
        }.sorted()
        let gain = Float(pow(10, -47.0 / 20) / cells[cells.count * 9 / 10])
        var state: UInt64 = 1234
        func uniform() -> Double {
            state = state &* 6364136223846793005 &+ 1442695040888963407
            return Double(state >> 11) / Double(UInt64(1) << 53)
        }
        let hiss = pow(10, -60.0 / 20)
        return clean.map { $0 * gain + Float(hiss * (-2 * log(max(uniform(), 1e-12))).squareRoot() * cos(2 * .pi * uniform())) }
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
