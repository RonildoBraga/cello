import Foundation
import XCTest
@testable import CelloPitch

final class PitchDetectorTests: XCTestCase {
    private let detector = PitchDetector()

    private func tone(_ frequency: Double, sampleRate: Double = 48_000,
                      count: Int = 8_192, amplitude: Double = 0.25,
                      harmonics: [Double] = [1], dc: Double = 0) -> [Float] {
        (0..<count).map { index in
            let phase = 2 * Double.pi * frequency * Double(index) / sampleRate
            let value = harmonics.enumerated().reduce(0.0) { sum, item in
                sum + item.element * sin(phase * Double(item.offset + 1))
            }
            return Float(dc + amplitude * value)
        }
    }

    private func assertPitch(_ samples: [Float], expected: Double,
                             sampleRate: Double = 48_000,
                             accuracyInCents: Double = 3,
                             file: StaticString = #filePath, line: UInt = #line) {
        guard let result = detector.estimate(samples: samples, sampleRate: sampleRate) else {
            return XCTFail("No estimate for \(expected) Hz", file: file, line: line)
        }
        let cents = 1_200 * log2(result.frequency / expected)
        XCTAssertLessThan(abs(cents), accuracyInCents,
                          "\(result.frequency) Hz, error \(cents) cents", file: file, line: line)
        XCTAssertGreaterThan(result.confidence, 0.9, file: file, line: line)
        XCTAssertGreaterThan(result.rms, 0, file: file, line: line)
    }

    func testAllOpenStringsAcrossSampleRates() {
        for rate in [44_100.0, 48_000.0, 96_000.0] {
            for frequency in [65.406391, 97.998859, 146.832384, 220.0] {
                let count = rate == 96_000 ? 16_384 : 8_192
                assertPitch(tone(frequency, sampleRate: rate, count: count),
                            expected: frequency, sampleRate: rate)
            }
        }
    }

    func testSharpAndFlatNotesRetainTheirDeviation() {
        for cents in [-25.0, 25.0] {
            for openString in [65.406391, 97.998859, 146.832384, 220.0] {
                let frequency = openString * pow(2, cents / 1_200)
                assertPitch(tone(frequency), expected: frequency)
            }
        }
    }

    func testDominantSecondHarmonicDoesNotBecomeAnOctaveError() {
        for frequency in [65.406391, 97.998859, 146.832384, 220.0] {
            assertPitch(tone(frequency, amplitude: 0.15, harmonics: [1, 2, 0.6, 0.3]),
                        expected: frequency)
        }
    }

    func testWeakFundamentalBelowStrongSecondHarmonic() {
        assertPitch(tone(65.406391, amplitude: 0.15, harmonics: [0.25, 1]),
                    expected: 65.406391)
        assertPitch(tone(220, amplitude: 0.15, harmonics: [0.25, 1]),
                    expected: 220)
    }

    func testOutOfRangeHighToneIsNotReportedAsALowerNote() {
        for frequency in [1_500.0, 2_000.0, 2_300.0, 3_000.0] {
            XCTAssertNil(detector.estimate(samples: tone(frequency), sampleRate: 48_000))
        }
    }

    func testDCHasNoEffectOnFrequencyAndRMS() {
        let clean = detector.estimate(samples: tone(65.406391), sampleRate: 48_000)!
        let offset = detector.estimate(samples: tone(65.406391, dc: 0.4), sampleRate: 48_000)!
        XCTAssertEqual(clean.frequency, offset.frequency, accuracy: 0.001)
        XCTAssertEqual(clean.rms, offset.rms, accuracy: 0.00001)
    }

    func testSilenceConstantInputAndNearSilentSignalsAreUnvoiced() {
        XCTAssertNil(detector.estimate(samples: [Float](repeating: 0, count: 8_192), sampleRate: 48_000))
        XCTAssertNil(detector.estimate(samples: [Float](repeating: 0.8, count: 8_192), sampleRate: 48_000))
        XCTAssertNil(detector.estimate(samples: tone(220, amplitude: 0.001), sampleRate: 48_000))
    }

    func testQuietPeriodicNotesRemainDetectable() {
        // A sine with amplitude 0.00212 has approximately 0.0015 RMS, the
        // scale of the quiet sustained notes in the physical-phone test.
        for frequency in [65.406391, 90.0, 220.0] {
            assertPitch(tone(frequency, amplitude: 0.00212), expected: frequency)
        }
    }

    func testQuietHarmonicNoteRemainsDetectable() {
        // This harmonic-rich 90 Hz note is also approximately 0.0015 RMS.
        assertPitch(tone(90, amplitude: 0.00158, harmonics: [1, 0.8, 0.4]),
                    expected: 90)
        assertPitch(tone(90, amplitude: 0.0015, harmonics: [0.25, 1]),
                    expected: 90)
    }

    func testQuietBroadbandNoiseAboveSilenceFloorIsRejected() {
        var state: UInt64 = 0x98765432
        let samples: [Float] = (0..<8_192).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return Float(Double(state >> 32) / Double(UInt32.max) * 0.0052 - 0.0026)
        }
        // RMS is approximately 0.0015, so this exercises periodicity rejection
        // rather than relying on the absolute near-silence floor.
        XCTAssertNil(detector.estimate(samples: samples, sampleRate: 48_000))
    }

    func testSeededBroadbandNoiseDoesNotProduceNote() {
        var state: UInt64 = 0x12345678
        let samples: [Float] = (0..<8_192).map { _ in
            state = state &* 6_364_136_223_846_793_005 &+ 1
            return Float(Double(state >> 32) / Double(UInt32.max) * 0.5 - 0.25)
        }
        XCTAssertNil(detector.estimate(samples: samples, sampleRate: 48_000))
    }

    func testRejectsIncompleteAndInvalidInput() {
        XCTAssertNil(detector.estimate(samples: [], sampleRate: 48_000))
        XCTAssertNil(detector.estimate(samples: tone(220, count: 256), sampleRate: 48_000))
        XCTAssertNil(detector.estimate(samples: tone(220), sampleRate: 0))
        XCTAssertNil(detector.estimate(samples: tone(220), sampleRate: .nan))
        var invalid = tone(220)
        invalid[100] = .nan
        XCTAssertNil(detector.estimate(samples: invalid, sampleRate: 48_000))
    }

    func testPeriodicSoundWithMildNoiseAndAmplitudeEnvelope() {
        var state: UInt64 = 0x424242
        let frequency = 65.406391
        var samples = tone(frequency, amplitude: 0.2, harmonics: [1, 0.8, 0.4])
        for index in samples.indices {
            state = state &* 6_364_136_223_846_793_005 &+ 1
            let noise = Double(state >> 32) / Double(UInt32.max) * 0.02 - 0.01
            let envelope = 0.8 + 0.2 * Double(index) / Double(samples.count)
            samples[index] = samples[index] * Float(envelope) + Float(noise)
        }
        assertPitch(samples, expected: frequency, accuracyInCents: 4)
    }
}
