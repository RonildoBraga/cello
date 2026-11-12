import Foundation
import XCTest
@testable import Cello

final class MelodyRatingTests: XCTestCase {
    private let sampleRate = 48_000.0

    func testCorrectThreeNotePhraseEarnsThreeIndependentStars() throws {
        let context = try snapshot()
        let rating = rate(signal(context: context), context)
        XCTAssertEqual(rating.status, .rated)
        XCTAssertEqual(rating.starCount, 3)
        XCTAssertTrue(rating.goalReached)
        XCTAssertEqual(rating.noteResults.count, 3)
        XCTAssertEqual(rating.noteResults.map(\.matched), [true, true, true])
        for (event, result) in zip(context.expectedEvents, rating.noteResults) {
            XCTAssertEqual(try XCTUnwrap(result.observedFrequency), try XCTUnwrap(event.frequency()), accuracy: 0.5)
            XCTAssertEqual(try XCTUnwrap(result.observedOnset), event.onsetBeat, accuracy: 0.06)
        }
    }

    func testEveryVoiceRegisterAndPhraseUsesItsOwnAbsoluteNotes() throws {
        for register in [MelodyRegister.lowVoice, .higherVoice] {
            for section in [MelodySection.phrase1, .phrase2, .phrase3, .phrase4, .whole] {
                let context = try snapshot(register: register, section: section)
                XCTAssertEqual(rate(signal(context: context), context).starCount, 3,
                               "\(register.rawValue), \(section.rawValue)")
            }
        }
    }

    func testWrongNotesKeepTimingAndClarityButLoseNotesStar() throws {
        let context = try snapshot()
        let rating = rate(signal(context: context, transpose: 3), context)
        XCTAssertEqual(rating.status, .rated)
        XCTAssertFalse(rating.notes)
        XCTAssertTrue(rating.timing)
        XCTAssertTrue(rating.clarity)
        XCTAssertEqual(rating.starCount, 2)
        XCTAssertFalse(rating.feedback.isEmpty)
    }

    func testAttackPitchSettlingDoesNotInventNotesOrHideLaterLegatoChanges() throws {
        let context = try snapshot(register: .higherVoice)
        let settled = rate(signal(context: context, initialAttackCents: -300), context)
        XCTAssertEqual(settled.starCount, 3)
        XCTAssertEqual(settled.noteResults.filter { $0.observedOnset != nil }.count, 3)
        let quick = try snapshot(register: .higherVoice, tempoBPM: 120)
        let legato = rate(signal(context: quick, gate: 1), quick)
        XCTAssertEqual(legato.starCount, 3, "Real later pitch changes must still create their own onsets")
        XCTAssertEqual(try XCTUnwrap(legato.noteResults[1].observedOnset), 0.5, accuracy: 0.15)
        XCTAssertEqual(try XCTUnwrap(legato.noteResults[2].observedOnset), 1, accuracy: 0.15)
    }

    func testWithinNoteSettlingDoesNotInventAnExtraNote() throws {
        let context = twoNoteSnapshot()
        let rating = rate(settlingSignal(secondOnset: 2.10), context)
        XCTAssertEqual(rating.status, .rated)
        XCTAssertEqual(rating.starCount, 3)
        XCTAssertEqual(rating.matchedNoteFraction, 1)
        XCTAssertEqual(rating.timedNoteFraction, 1)
        XCTAssertEqual(rating.clearNoteFraction, 1)
        XCTAssertEqual(try XCTUnwrap(rating.noteResults[1].observedOnset), 2.10, accuracy: 0.02)
        XCTAssertEqual(try XCTUnwrap(rating.noteResults[1].observedFrequency), 112, accuracy: 0.5)
    }

    func testSettlingCorrectionDoesNotMoveALateOnsetOntoTheScore() throws {
        let context = twoNoteSnapshot()
        let rating = rate(settlingSignal(secondOnset: 2.21), context)
        XCTAssertEqual(rating.status, .rated)
        XCTAssertTrue(rating.notes)
        XCTAssertTrue(rating.clarity)
        XCTAssertFalse(rating.timing)
        XCTAssertEqual(rating.starCount, 2)
        XCTAssertEqual(try XCTUnwrap(rating.noteResults[1].observedOnset), 2.21, accuracy: 0.02)
    }

    func testSemitoneStepsRemainDistinctEvenInQuarterSecondLegatoNotes() throws {
        for register in [MelodyRegister.lowVoice, .higherVoice] {
            for duration in [0.5, 2.0] {
                // A half beat at 120 BPM lasts 250ms. No silent reattacks
                // identify these notes: the pitch steps must remain detectable.
                let pitches = [47, 48, 47, 48]
                let transpose = register == .lowVoice ? 0 : 12
                let context = MelodyPracticeContext(pieceID: "semitoneControl", scoreVersion: 1,
                    register: register, referenceKey: "G major", tuningA4Hz: 440, tempoBPM: 120,
                    section: .whole, expectedEvents: pitches.enumerated().map {
                        MelodyEvent(onsetBeat: Double($0.offset) * duration, durationBeats: duration,
                                    midiNote: $0.element + transpose)
                    }, durationBeats: Double(pitches.count) * duration,
                    gradingVersion: MelodyRating.currentVersion)
                let rating = rate(signal(context: context, gate: 1), context)
                XCTAssertEqual(rating.status, .rated)
                XCTAssertEqual(rating.starCount, 3, "\(register), \(duration) beat semitones")
                for (event, result) in zip(context.expectedEvents, rating.noteResults) {
                    XCTAssertEqual(try XCTUnwrap(result.observedOnset), event.onsetBeat / 2, accuracy: 0.12)
                }
            }
        }
    }

    func testSustainedSingleNoteCannotPassMovingMelodyOrRepeatedRhythm() throws {
        for section in [MelodySection.phrase1, .phrase3] {
            let context = try snapshot(section: section)
            let frequency = try XCTUnwrap(context.expectedEvents.last?.frequency())
            let count = Int(context.duration * sampleRate)
            let samples = (0..<count).map { Float(0.2 * sin(2 * .pi * frequency * Double($0) / sampleRate)) }
            let rating = rate(samples, context)
            XCTAssertEqual(rating.status, .rated)
            XCTAssertFalse(rating.notes)
            XCTAssertFalse(rating.timing)
            XCTAssertFalse(rating.goalReached)
            XCTAssertEqual(rating.noteResults.filter { $0.observedOnset != nil }.count, 1)
        }
    }

    // MARK: Version 3: fresh starts, settled pitch and quick notes

    /// Hot Cross Buns' third phrase: four quick G's, then four quick A's.
    private var quickPhrase: MelodyPracticeContext { MelodyPiece.hotCrossBuns.humming(register: .lowVoice, section: .phrase3) }

    /// Notes sung "doo-doo": each `sounding` of its slot, on a quieter hum that never stops,
    /// so the level between notes dips to `floor` of the note's instead of falling silent.
    private func articulated(_ context: MelodyPracticeContext, floor: Double, sounding: Double = 0.78,
                             slideCents: Double = 0, offsetCents: Double = 0) -> [Float] {
        var sound = [Float](repeating: 0, count: Int(context.duration * sampleRate))
        var phase = 0.0
        for event in context.expectedEvents {
            guard let target = context.frequency(for: event) else { continue }
            let start = Int(event.onsetBeat * sampleRate), length = Int(event.durationBeats * sampleRate)
            for frame in 0..<length where start + frame < sound.count {
                let elapsed = Double(frame) / sampleRate, position = Double(frame) / Double(length)
                // The note swells in over 30 ms and falls away at the end of its sounding part.
                let rise = min(1, elapsed / 0.03), fall = min(1, max(0, (sounding - position) * Double(length) / sampleRate / 0.03))
                let level = floor + (1 - floor) * min(rise, fall)
                // A slide begins off the note and reaches it a third of the way through.
                let cents = offsetCents + slideCents * max(0, 1 - position / 0.33)
                phase += 2 * Double.pi * target * pow(2, cents / 1_200) / sampleRate
                sound[start + frame] = Float(0.2 * level * (sin(phase) + 0.5 * sin(2 * phase) + 0.25 * sin(3 * phase)))
            }
        }
        return sound
    }

    func testQuickNotesSeparatedByADipAreHeardAsNotesOfTheirOwn() throws {
        // The level between the notes falls to a third, about 10 dB, as a real "doo-doo" does.
        let rating = rate(articulated(quickPhrase, floor: 0.33), quickPhrase)
        XCTAssertEqual(rating.status, .rated)
        XCTAssertEqual(rating.noteResults.filter { $0.observedOnset != nil }.count, 8, "Every fresh start is heard")
        XCTAssertEqual(rating.starCount, 3, "notes \(rating.matchedNoteFraction ?? -1) timing \(rating.timedNoteFraction ?? -1) clarity \(rating.clearNoteFraction ?? -1)")
        XCTAssertNil(rating.heardAdvice)
        for note in rating.noteResults {
            XCTAssertEqual(try XCTUnwrap(note.observedOnset), note.expectedStart, accuracy: 0.08, "A start sits at the bottom of its dip")
        }
    }

    func testOneNoteHeldThroughQuickNotesIsStillOneNote() throws {
        // No dips at all: the same pitch held where eight starts were asked for.
        let held = rate(articulated(quickPhrase, floor: 1), quickPhrase)
        XCTAssertLessThan(held.noteResults.filter { $0.observedOnset != nil }.count, 4)
        XCTAssertFalse(held.timing)
        XCTAssertLessThan(held.starCount ?? 3, 2)
        XCTAssertEqual(held.feedback, held.heardAdvice, "The advice says the notes were not heard apart")
        // A waver too shallow to be a fresh start is not one either.
        let wavering = rate(articulated(quickPhrase, floor: 0.7), quickPhrase)
        XCTAssertLessThan(wavering.noteResults.filter { $0.observedOnset != nil }.count, 4)
    }

    func testADipInsideAHeldNoteIsNotANewNote() throws {
        // Phrase 1 ends on a two-beat note. Its level sags to a third for a moment at 2.9 s,
        // where the score has no note starting.
        let context = try snapshot()
        var sound = signal(context: context)
        for index in Int(2.85 * sampleRate)..<Int(2.95 * sampleRate) { sound[index] *= 0.3 }
        let rating = rate(sound, context)
        XCTAssertEqual(rating.noteResults.filter { $0.observedOnset != nil }.count, 3)
        XCTAssertEqual(rating.starCount, 3)
        XCTAssertEqual(rating, rate(sound, context), "The same sound always scores the same")
    }

    func testANoteIsJudgedOnWhereItSettlesNotOnTheSlideIntoIt() throws {
        // Every note starts a whole tone high and reaches its pitch a third of the way through.
        let slid = rate(articulated(quickPhrase, floor: 0.2, slideCents: 200), quickPhrase)
        XCTAssertTrue(slid.notes, "matched \(slid.matchedNoteFraction ?? -1)")
        XCTAssertEqual(slid.starCount, 3)
        // Settling in the wrong place is still wrong: 90 cents sharp throughout misses Notes
        // and keeps the other two goals, which is a pass.
        let sharp = rate(articulated(quickPhrase, floor: 0.2, offsetCents: 90), quickPhrase)
        XCTAssertFalse(sharp.notes)
        XCTAssertTrue(sharp.timing && sharp.clarity)
        XCTAssertEqual(sharp.starCount, 2)
        XCTAssertEqual(sharp.feedback, "The first note (G2) was a little too high. Hear the start again and begin on its pitch.")
    }

    func testQuickNotesHaveRoomForTheirStartsAndLongNotesDoNot() throws {
        // Each quick note sounds for 55% of its half second: detached, as beginners sing them.
        let detached = rate(articulated(quickPhrase, floor: 0, sounding: 0.55), quickPhrase)
        XCTAssertTrue(detached.timing && detached.clarity, "timing \(detached.timedNoteFraction ?? -1) clarity \(detached.clearNoteFraction ?? -1)")
        // A one-beat note cut as short still loses its timing: it was not held.
        let context = try snapshot()
        let clipped = rate(articulated(context, floor: 0, sounding: 0.55), context)
        XCTAssertFalse(clipped.timing)
    }

    func testCorrectSequenceStartedLateIsNotSilentlyAlignedToScore() throws {
        let context = try snapshot()
        let rating = rate(signal(context: context, delay: 0.4), context)
        XCTAssertEqual(rating.status, .rated)
        XCTAssertTrue(rating.notes, "Correct sequence remains distinct from its late timing")
        XCTAssertFalse(rating.timing)
        XCTAssertFalse(rating.goalReached)
        XCTAssertEqual(try XCTUnwrap(rating.noteResults.first?.observedOnset), 0.4, accuracy: 0.06)
        XCTAssertTrue(rating.pitchPoints.contains { $0.time < 0.3 && $0.frequency == nil })
    }

    func testWrongOrderAndMissingNotesDoNotEarnNotesOrCompletion() throws {
        let context = try snapshot()
        for sound in [signal(context: context, reverse: true), signal(context: context, missing: [1])] {
            let rating = rate(sound, context)
            XCTAssertEqual(rating.status, .rated)
            XCTAssertFalse(rating.notes)
            XCTAssertFalse(rating.goalReached)
        }
    }

    func testShortenedHoldsAndFastPhraseLoseTiming() throws {
        let context = try snapshot()
        for sound in [signal(context: context, gate: 0.30), signal(context: context, scale: 0.5)] {
            let rating = rate(sound, context)
            XCTAssertEqual(rating.status, .rated)
            XCTAssertFalse(rating.timing)
            XCTAssertFalse(rating.clarity)
            XCTAssertFalse(rating.goalReached)
        }
    }

    func testExtraNotesCannotDisappearAfterExpectedSequence() throws {
        let context = try snapshot()
        let extra = MelodyPracticeContext(pieceID: context.pieceID, scoreVersion: context.scoreVersion,
            register: context.register, referenceKey: context.referenceKey, tuningA4Hz: 440, tempoBPM: 60,
            section: .phrase1, expectedEvents: [
                MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 47),
                MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: 45),
                MelodyEvent(onsetBeat: 2, durationBeats: 1.5, midiNote: 43),
                MelodyEvent(onsetBeat: 3.5, durationBeats: 0.5, midiNote: 45)
            ], durationBeats: 4, gradingVersion: MelodyRating.currentVersion)
        let rating = rate(signal(context: extra), context)
        XCTAssertEqual(rating.status, .rated)
        XCTAssertFalse(rating.notes)
        XCTAssertFalse(rating.timing)
        XCTAssertFalse(rating.goalReached)
    }

    func testAutomaticStopPostRollDoesNotChangeFrozenExerciseRating() throws {
        let context = try snapshot()
        let phrase = signal(context: context)
        let tail = (0..<Int(0.4 * sampleRate)).map { Float(0.2 * sin(2 * .pi * 330 * Double($0) / sampleRate)) }
        let expected = rate(phrase, context)
        XCTAssertEqual(expected.starCount, 3)
        XCTAssertEqual(rate(phrase + tail, context), expected)
        let silentPhrase = [Float](repeating: 0, count: phrase.count)
        XCTAssertEqual(rate(silentPhrase + tail, context).status, .insufficientSound)
    }

    func testPureOctaveMismatchIsMeasuredAndNeverFoldedOntoTarget() throws {
        let context = try snapshot()
        let rating = rate(signal(context: context, transpose: 12), context)
        XCTAssertEqual(rating.status, .rated)
        XCTAssertFalse(rating.notes)
        XCTAssertTrue(rating.octaveMismatch)
        XCTAssertTrue(rating.feedback.contains("octave"))
        let first = try XCTUnwrap(rating.noteResults.first)
        XCTAssertEqual(try XCTUnwrap(first.observedFrequency) / XCTUnwrap(first.expectedFrequency), 2, accuracy: 0.01)
    }

    func testAFadingNotesOvertoneIsNotANewNote() throws {
        // A real take: G2 held, its octave read for one 50 ms frame as the hum faded, silence, then B2.
        let held = [Double?](repeating: 98, count: 37)
        let take = held + [198, nil, nil, nil] + [Double?](repeating: 123.5, count: 38)
        XCTAssertEqual(MelodyRecordingRater.octaveSlips(in: take), [37])
        // The same misreading at the start of a note, for three frames.
        XCTAssertEqual(MelodyRecordingRater.octaveSlips(in: [196, 197, 196] + held), [0, 1, 2])
        // A note that really is an octave away, held, is left alone; so is an ordinary step.
        XCTAssertTrue(MelodyRecordingRater.octaveSlips(in: held + [Double?](repeating: 196, count: 6)).isEmpty)
        XCTAssertTrue(MelodyRecordingRater.octaveSlips(in: held + [123.5, 123.5] + held).isEmpty)
        XCTAssertTrue(MelodyRecordingRater.octaveSlips(in: [nil, 98, nil]).isEmpty)
    }

    func testSilenceAndUnpitchedNoiseStayUnscored() throws {
        let context = try snapshot()
        let count = Int(context.duration * sampleRate)
        let silence = rate([Float](repeating: 0, count: count), context)
        XCTAssertEqual(silence.status, .insufficientSound)
        XCTAssertNil(silence.starCount)
        var random: UInt64 = 42
        let noise = (0..<count).map { _ -> Float in
            random = random &* 6_364_136_223_846_793_005 &+ 1
            return (Float(random >> 40) / Float(1 << 24) - 0.5) * 0.1
        }
        let unclear = rate(noise, context)
        XCTAssertEqual(unclear.status, .unclear)
        XCTAssertNil(unclear.starCount)
        XCTAssertFalse(unclear.goalReached)
    }

    func testClippedAndInvalidSignalsStayUnscored() throws {
        let context = try snapshot()
        for sound: [Float] in [[.nan], [.infinity], [Float](repeating: 1, count: 10_000)] {
            XCTAssertNil(rate(sound, context).starCount)
        }
        XCTAssertNil(MelodyRecordingRater.rate(samples: [0], sampleRate: 0, context: context).starCount)
        let ungraded = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1)
        XCTAssertNil(rate(signal(context: context), ungraded).starCount)
    }

    func testCompetingOctaveComponentsRemainUnscored() throws {
        let context = try snapshot()
        let sound = (0..<Int(context.duration * sampleRate)).map { index -> Float in
            let time = Double(index) / sampleRate
            let low = 0.018 * sin(2 * .pi * 55.9 * time)
            let voice = time < 0.35 ? 0 : 0.08 * sin(2 * .pi * 112.8 * time)
            let harmonic = time < 0.35 ? 0 : 0.02 * sin(2 * .pi * 225.6 * time)
            return Float(low + voice + harmonic)
        }
        let rating = rate(sound, context)
        XCTAssertEqual(rating.status, .unclear)
        XCTAssertNil(rating.starCount)
        XCTAssertFalse(rating.goalReached)
    }

    func testExplicitRestMustRemainQuietAndIsNotARepeatedPitch() throws {
        let base = try snapshot()
        let context = MelodyPracticeContext(pieceID: base.pieceID, scoreVersion: base.scoreVersion,
            register: base.register, referenceKey: base.referenceKey, tuningA4Hz: 440, tempoBPM: 60,
            section: .phrase1, expectedEvents: [
                MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 47),
                MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: nil),
                MelodyEvent(onsetBeat: 2, durationBeats: 2, midiNote: 43)
            ], durationBeats: 4, gradingVersion: MelodyRating.currentVersion)
        let rating = rate(signal(context: context), context)
        XCTAssertEqual(rating.starCount, 3)
        XCTAssertNil(rating.noteResults[1].expectedFrequency)
        XCTAssertNil(rating.noteResults[1].observedFrequency)
        XCTAssertTrue(rating.pitchPoints.filter { $0.time > 1.1 && $0.time < 1.9 }.allSatisfy { $0.frequency == nil })
    }

    func testFrozenRatingRoundTripKeepsMetricsAndUnshiftedObservations() throws {
        let context = try snapshot()
        let rating = rate(signal(context: context), context)
        let decoded = try JSONDecoder().decode(MelodyRating.self, from: JSONEncoder().encode(rating))
        XCTAssertEqual(decoded, rating)
        XCTAssertEqual(decoded.version, MelodyRating.currentVersion)
        XCTAssertFalse(decoded.pitchPoints.isEmpty)
    }

    private func snapshot(register: MelodyRegister = .lowVoice, section: MelodySection = .phrase1,
                          tempoBPM: Int = 60) throws -> MelodyPracticeContext {
        let base = try MelodyPracticeContext.hotCrossBuns(register: register, section: section, tempoBPM: tempoBPM)
        return MelodyPracticeContext(pieceID: base.pieceID, scoreVersion: base.scoreVersion,
            register: base.register, referenceKey: base.referenceKey, tuningA4Hz: base.tuningA4Hz,
            tempoBPM: base.tempoBPM, section: base.section, expectedEvents: base.expectedEvents,
            durationBeats: base.durationBeats, gradingVersion: MelodyRating.currentVersion)
    }

    private func rate(_ samples: [Float], _ context: MelodyPracticeContext) -> MelodyRating {
        MelodyRecordingRater.rate(samples: samples, sampleRate: sampleRate, context: context)
    }

    private func twoNoteSnapshot() -> MelodyPracticeContext {
        MelodyPracticeContext(pieceID: "settlingControl", scoreVersion: 1,
            register: .lowVoice, referenceKey: "G major", tuningA4Hz: 440, tempoBPM: 60,
            section: .whole, expectedEvents: [
                MelodyEvent(onsetBeat: 0, durationBeats: 2, midiNote: 43),
                MelodyEvent(onsetBeat: 2, durationBeats: 2, midiNote: 45)
            ], durationBeats: 4, gradingVersion: MelodyRating.currentVersion)
    }

    /// A quiet continuous second hum settles from 105 to 112Hz after its attack.
    /// The ramp crosses 100 cents from its early baseline without a third note.
    private func settlingSignal(secondOnset: Double) -> [Float] {
        var sound = [Float](repeating: 0, count: Int(4 * sampleRate))
        for (start, end, first) in [(0.10, 1.70, true), (secondOnset, 3.90, false)] {
            var phase = 0.0
            for index in Int(start * sampleRate)..<Int(end * sampleRate) {
                let elapsed = Double(index) / sampleRate - start
                let remaining = end - Double(index) / sampleRate
                let envelope = min(1, min(elapsed, remaining) / 0.01)
                let frequency = first ? 97.998859 : 105 + 7 * min(1, max(0, (elapsed - 0.25) / 0.25))
                phase += 2 * .pi * frequency / sampleRate
                sound[index] = Float(envelope * (0.005 * sin(phase) + 0.002 * sin(2 * phase)))
            }
        }
        return sound
    }

    /// Synthetic signal with independent frequency, order, attack and duration controls.
    private func signal(context: MelodyPracticeContext, transpose: Int = 0, delay: Double = 0,
                        gate: Double = 0.85, scale: Double = 1, reverse: Bool = false,
                        missing: Set<Int> = [], initialAttackCents: Double = 0) -> [Float] {
        var sound = [Float](repeating: 0, count: Int(context.duration * sampleRate))
        let pitches = context.expectedEvents.map(\.midiNote)
        for (index, event) in context.expectedEvents.enumerated() where !missing.contains(index) {
            guard let pitch = (reverse ? Array(pitches.reversed())[index] : event.midiNote) else { continue }
            let frequency = context.tuningA4Hz * pow(2, Double(pitch + transpose - 69) / 12)
            let start = Int((delay + event.onsetBeat * 60 / Double(context.tempoBPM) * scale) * sampleRate)
            let length = Int(event.durationBeats * 60 / Double(context.tempoBPM) * scale * gate * sampleRate)
            guard start < sound.count, length > 0 else { continue }
            var phase = 0.0
            for frame in 0..<min(length, sound.count - start) {
                let envelope = min(1, Double(min(frame, length - 1 - frame)) / (sampleRate * 0.01))
                let settlingCents = index == 0 ? initialAttackCents * max(0, 1 - Double(frame) / (sampleRate * 0.15)) : 0
                phase += 2 * Double.pi * frequency * pow(2, settlingCents / 1_200) / sampleRate
                sound[start + frame] = Float(envelope * (0.20 * sin(phase) + 0.08 * sin(2 * phase) + 0.04 * sin(3 * phase)))
            }
        }
        return sound
    }
}
