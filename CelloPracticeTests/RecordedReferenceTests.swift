import AVFoundation
import CelloPitch
import Foundation
import XCTest
@testable import Cello

final class RecordedReferenceTests: XCTestCase {
    func testEveryRegisterProducesRecordedMonoPCMWithExactScoreDuration() throws {
        for register in PracticeMethod.allCases.map(\.register) {
            let context = try MelodyPracticeContext.hotCrossBuns(register: register)
            let data = try RecordedReference.wavData(context: context)
            let player = try AVAudioPlayer(data: data)
            XCTAssertEqual(player.numberOfChannels, 1)
            XCTAssertEqual(player.duration, 16, accuracy: 1 / Double(RecordedReference.sampleRate))
            XCTAssertEqual(data.count, 44 + 16 * RecordedReference.sampleRate * 2)
            XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
            XCTAssertLessThan(pcm(data).map(abs).max() ?? 1, 0.90)
        }
    }

    func testPhraseAndWholeReferencesKeepSelectedTempoIncludingFinalQuietBoundary() throws {
        for tempo in [40, 60, 120] {
            for section in [MelodySection.phrase1, .phrase3, .whole] {
                let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice,
                                                                    section: section, tempoBPM: tempo)
                let data = try RecordedReference.wavData(context: context)
                let player = try AVAudioPlayer(data: data)
                XCTAssertEqual(player.duration, context.duration, accuracy: 1 / Double(RecordedReference.sampleRate))
                XCTAssertEqual(pcm(data).last, 0)
            }
        }
    }

    func testMeasuredMelodyNotesMatchTheFrozenPitchWithoutChangingNaturalVariation() throws {
        for register in PracticeMethod.allCases.map(\.register) {
            let context = try MelodyPracticeContext.hotCrossBuns(register: register, section: .phrase1)
            let sound = pcm(try RecordedReference.wavData(context: context))
            for event in context.expectedEvents {
                let frequencies = measuredFrequencies(sound, times: [0.25, 0.40, 0.55, 0.70].map {
                    event.onsetBeat + $0
                })
                XCTAssertGreaterThanOrEqual(frequencies.count, 3, "\(register), \(String(describing: event.midiNote))")
                let actual = try XCTUnwrap(median(frequencies))
                let expected = try XCTUnwrap(context.frequency(for: event))
                XCTAssertLessThan(abs(1_200 * log2(actual / expected)), 25,
                                  "The sample keeps real variation but its median must match the reference")
            }
        }
    }

    func testAllFourOpenStringsUseRecordedCelloAtTheSelectedFrequency() throws {
        for frequency in [65.40639132514966, 97.99885899543733, 146.8323839587038, 220] {
            let data = try RecordedReference.celloNote(frequency: frequency)
            let sound = pcm(data)
            XCTAssertEqual(sound.count, 2 * RecordedReference.sampleRate)
            let measured = measuredFrequencies(sound, times: [0.4, 0.7, 1, 1.3, 1.6])
            XCTAssertGreaterThanOrEqual(measured.count, 4)
            XCTAssertLessThan(abs(1_200 * log2(try XCTUnwrap(median(measured)) / frequency)), 25)
            XCTAssertEqual(sound.first, 0)
            XCTAssertEqual(sound.last, 0)
        }
    }

    func testHigherVoiceIsNoLongerOfferedOrBundledButStillDecodes() throws {
        XCTAssertEqual(PracticeMethod.allCases.map(\.register), [.lowVoice, .cello])
        let saved = try MelodyPracticeContext.hotCrossBuns(register: .higherVoice, section: .phrase1,
                                                           gradingVersion: MelodyRating.currentVersion)
        let decoded = try JSONDecoder().decode(MelodyPracticeContext.self, from: JSONEncoder().encode(saved))
        XCTAssertEqual(decoded, saved, "Takes saved in the removed register must still open")
        XCTAssertTrue(decoded.isValid)
        XCTAssertThrowsError(try RecordedReference.wavData(context: saved),
                             "Its reference recording is no longer bundled")
    }

    func testRecordedHumanExamplesMatchTheUnchangedMelodyAssessment() throws {
        for register in [MelodyRegister.lowVoice] {
            for section in MelodySection.allCases {
                let context = try MelodyPracticeContext.hotCrossBuns(
                    register: register, section: section, gradingVersion: MelodyRating.currentVersion)
                let sound = pcm(try RecordedReference.wavData(context: context))
                let rating = MelodyRecordingRater.rate(samples: sound,
                    sampleRate: Double(RecordedReference.sampleRate), context: context)
                XCTAssertEqual(rating.status, .rated, "\(register.rawValue), \(section.rawValue)")
                XCTAssertEqual(rating.starCount, 3,
                    "\(register.rawValue), \(section.rawValue): Notes \(String(describing: rating.matchedNoteFraction)), Timing \(String(describing: rating.timedNoteFraction)), Clarity \(String(describing: rating.clearNoteFraction))")
            }
        }
    }

    func testEveryNoteFadesAndLeavesAnExactlyQuietArticulationGap() throws {
        for register in PracticeMethod.allCases.map(\.register) {
            let context = try MelodyPracticeContext.hotCrossBuns(register: register, section: .phrase3)
            let sound = pcm(try RecordedReference.wavData(context: context))
            for event in context.expectedEvents {
                let start = Int(event.onsetBeat * Double(RecordedReference.sampleRate))
                let end = Int(event.endBeat * Double(RecordedReference.sampleRate))
                let audibleEnd = start + Int((Double(end - start) * 0.88).rounded())
                XCTAssertEqual(sound[start], 0)
                XCTAssertEqual(sound[audibleEnd - 1], 0)
                XCTAssertTrue(sound[audibleEnd..<end].allSatisfy { $0 == 0 })
                let attack = rms(sound[start..<(start + 240)])
                let middle = rms(sound[(start + 4_800)..<(start + 5_040)])
                XCTAssertGreaterThan(middle, 0.01)
                XCTAssertLessThan(attack, middle / 4)
            }
        }
    }

    func testExplicitRestsAndUnwrittenGapsRemainSilent() throws {
        let context = snapshot(events: [
            MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 43),
            MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: nil),
            MelodyEvent(onsetBeat: 3, durationBeats: 1, midiNote: 47)
        ])
        let sound = pcm(try RecordedReference.wavData(context: context))
        XCTAssertTrue(sound[48_000..<144_000].allSatisfy { $0 == 0 })
        XCTAssertGreaterThan(rms(sound[4_800..<9_600]), 0.01)
        XCTAssertGreaterThan(rms(sound[148_800..<153_600]), 0.01)
    }

    func testLongRecordedCelloSustainLoopsWithoutClippingOrAnAbruptSeam() throws {
        let frequency = 65.40639132514966
        let sound = pcm(try RecordedReference.celloNote(frequency: frequency, duration: 7))
        XCTAssertEqual(sound.count, 7 * RecordedReference.sampleRate)
        XCTAssertLessThan(sound.map(abs).max() ?? 1, 0.90)
        let jumps = zip(sound, sound.dropFirst()).map { pair in abs(pair.0 - pair.1) }
        XCTAssertLessThan(jumps.max() ?? 1, 0.20)
        for time in [1.0, 3.5, 6.0] {
            let frequencyAtTime = try XCTUnwrap(measuredFrequencies(sound, times: [time]).first)
            XCTAssertLessThan(abs(1_200 * log2(frequencyAtTime / frequency)), 35)
        }
    }

    func testMissingRecordingsThrowInsteadOfSubstitutingSyntheticAudio() throws {
        let emptyBundle = Bundle(for: Self.self)
        XCTAssertNotEqual(emptyBundle.bundleURL, Bundle.main.bundleURL)
        for register in PracticeMethod.allCases.map(\.register) {
            let context = try MelodyPracticeContext.hotCrossBuns(register: register, section: .phrase1)
            XCTAssertThrowsError(try RecordedReference.wavData(context: context, bundle: emptyBundle))
        }
        XCTAssertThrowsError(try RecordedReference.celloNote(frequency: 220, bundle: emptyBundle))
    }

    func testInvalidReferencesAreRejectedBeforeRendering() {
        for frequency in [-1.0, 0, 49.9, 1_000.1, .nan, .infinity] {
            XCTAssertThrowsError(try RecordedReference.celloNote(frequency: frequency))
        }
        for duration in [0.0, -1, 1e-100, 10.1, .nan, .infinity] {
            XCTAssertThrowsError(try RecordedReference.celloNote(frequency: 220, duration: duration))
        }
        for context in [snapshot(events: []), snapshot(duration: .nan), snapshot(duration: 129),
                        snapshot(tempo: 0), snapshot(tuning: .infinity),
                        snapshot(events: [MelodyEvent(onsetBeat: 0, durationBeats: .infinity, midiNote: 43)])] {
            XCTAssertThrowsError(try RecordedReference.wavData(context: context))
        }
    }

    private func snapshot(events: [MelodyEvent] = [MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 43)],
                          duration: Double = 4, tempo: Int = 60, tuning: Double = 440) -> MelodyPracticeContext {
        MelodyPracticeContext(pieceID: "hotCrossBuns", scoreVersion: 1, register: .lowVoice,
                              referenceKey: "G major", tuningA4Hz: tuning, tempoBPM: tempo,
                              section: .phrase1, expectedEvents: events, durationBeats: duration, gradingVersion: nil)
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
            guard start >= 0, start + 8_192 <= samples.count,
                  let estimate = detector.estimate(samples: Array(samples[start..<(start + 8_192)]),
                                                   sampleRate: Double(RecordedReference.sampleRate)),
                  estimate.confidence >= 0.75 else { return nil }
            return estimate.frequency
        }
    }

    private func median(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2) ? (sorted[middle - 1] + sorted[middle]) / 2 : sorted[middle]
    }

    private func rms(_ samples: ArraySlice<Float>) -> Float {
        sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
    }
}
