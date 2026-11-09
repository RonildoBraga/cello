import AVFoundation
import Foundation
import XCTest
@testable import Cello

final class PracticeRatingTests: XCTestCase {
    private let rate = 48_000.0
    private let target = 110.64730204182847

    func testClearSustainedTargetEarnsThreeIndependentGoals() {
        let result = evaluate(sound(duration: 2.5) { _ in self.target })
        XCTAssertEqual(result.status, .rated)
        XCTAssertEqual(result.starCount, 3)
        XCTAssertTrue(result.goalReached)
        XCTAssertGreaterThan(result.longestHold, 2.4)
        XCTAssertGreaterThan(result.nearTargetFraction ?? 0, 0.99)
    }

    func testAStableWrongNoteEarnsSteadyAndHoldWithoutMatch() {
        let frequency = target * pow(2, -80.0 / 1_200)
        let result = evaluate(sound(duration: 2.5) { _ in frequency })
        XCTAssertEqual(result.status, .rated)
        XCTAssertFalse(result.match)
        XCTAssertTrue(result.steady)
        XCTAssertTrue(result.hold)
        XCTAssertEqual(result.starCount, 2)
        XCTAssertFalse(result.goalReached)
    }

    func testAUniformOctaveLowerIsNotAutomaticallyMovedTowardTheTarget() {
        let result = evaluate(sound(duration: 2.5) { _ in self.target / 2 })
        XCTAssertEqual(result.status, .rated)
        XCTAssertFalse(result.match)
        XCTAssertTrue(result.steady)
        XCTAssertTrue(result.hold)
    }

    func testARegularToneWithAStrongSecondHarmonicRemainsRateable() {
        let samples: [Float] = (0..<Int(rate * 2.5)).map { index in
            let phase = 2 * Double.pi * target * Double(index) / rate
            return Float(0.05 * sin(phase) + 0.15 * sin(2 * phase))
        }
        let result = evaluate(samples)
        XCTAssertEqual(result.status, .rated)
        XCTAssertEqual(result.starCount, 3)
    }

    func testShortClearHumCannotEarnHold() {
        let result = evaluate(sound(duration: 0.9) { _ in self.target })
        XCTAssertEqual(result.status, .rated)
        XCTAssertTrue(result.match)
        XCTAssertTrue(result.steady)
        XCTAssertFalse(result.hold)
        XCTAssertEqual(result.starCount, 2)
    }

    func testSeparateShortHumsCannotEarnContinuousHoldFromTheirTotalSpan() {
        let note = sound(duration: 0.9) { _ in self.target }
        let silence = [Float](repeating: 0, count: Int(rate * 0.6))
        let result = evaluate(note + silence + note + silence + note)
        XCTAssertEqual(result.status, .rated)
        XCTAssertGreaterThan(result.voicedDuration, 2.5)
        XCTAssertLessThan(result.longestHold, 1)
        XCTAssertFalse(result.hold)
        XCTAssertFalse(result.goalReached)
    }

    func testDriftingPitchCannotHideBehindAnAverageAtTheTarget() {
        let result = evaluate(sound(duration: 3) { time in
            self.target * pow(2, (-120 + 80 * time) / 1_200)
        })
        XCTAssertEqual(result.status, .rated)
        XCTAssertFalse(result.match)
        XCTAssertFalse(result.steady)
        XCTAssertTrue(result.hold)
    }

    func testSettlingAllowanceStartsAtTheHumRatherThanRecordingStart() {
        let note = sound(duration: 2.5) { time in
            self.target * pow(2, (time < 0.15 ? -70 : 0) / 1_200)
        }
        let immediate = evaluate(note)
        let delayed = evaluate([Float](repeating: 0, count: Int(rate * 0.8)) + note)
        XCTAssertEqual(immediate.status, .rated)
        XCTAssertEqual(delayed.status, .rated)
        XCTAssertEqual(immediate.steady, delayed.steady)
        XCTAssertEqual(immediate.hold, delayed.hold)
        XCTAssertEqual(immediate.starCount, delayed.starCount)
    }

    func testSilenceAndTinyFragmentsHaveNoRating() {
        let silence = evaluate([Float](repeating: 0, count: Int(rate * 3)))
        XCTAssertEqual(silence.status, .insufficientSound)
        XCTAssertNil(silence.starCount)
        let fragment = evaluate(sound(duration: 0.2) { _ in self.target })
        XCTAssertEqual(fragment.status, .insufficientSound)
        XCTAssertNil(fragment.starCount)
        XCTAssertFalse(fragment.goalReached)
    }

    func testUnpitchedNoiseAndClippingDoNotBecomeLowGrades() {
        var seed: UInt64 = 17
        let noise: [Float] = (0..<Int(rate * 2)).map { _ in
            seed = seed &* 6_364_136_223_846_793_005 &+ 1
            return Float(Double(seed >> 32) / Double(UInt32.max) - 0.5) * 0.2
        }
        let noisy = evaluate(noise)
        XCTAssertEqual(noisy.status, .unclear)
        XCTAssertNil(noisy.starCount)
        let clipped = evaluate(sound(duration: 2.5) { _ in self.target }.map { max(-1, min(1, $0 * 30)) })
        XCTAssertEqual(clipped.status, .unclear)
        XCTAssertNil(clipped.starCount)
    }

    func testCompetingOctaveComponentsDoNotProduceAFailingGrade() {
        let samples: [Float] = (0..<Int(rate * 3)).map { index in
            let t = Double(index) / rate
            // Both period interpretations remain strongly periodic, while the
            // higher component appears separately from the existing low sound.
            let low = 0.018 * sin(2 * .pi * 55.9 * t)
            let voice = t < 0.35 ? 0 : 0.08 * sin(2 * .pi * 112.8 * t)
            let harmonic = t < 0.35 ? 0 : 0.02 * sin(2 * .pi * 225.6 * t)
            return Float(low + voice + harmonic)
        }
        let result = evaluate(samples)
        XCTAssertEqual(result.status, .unclear)
        XCTAssertNil(result.starCount)
        XCTAssertFalse(result.goalReached)
    }

    func testSavedMediaDecoderAndRatingRoundTrip() async throws {
        let samples = sound(duration: 2.5) { _ in self.target }
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 1))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format,
                                                   frameCapacity: AVAudioFrameCount(samples.count)))
        buffer.frameLength = AVAudioFrameCount(samples.count)
        samples.withUnsafeBufferPointer { source in
            buffer.floatChannelData![0].update(from: source.baseAddress!, count: samples.count)
        }
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("caf")
        defer { try? FileManager.default.removeItem(at: url) }
        do {
            let file = try AVAudioFile(forWriting: url, settings: format.settings)
            try file.write(from: buffer)
        }
        let result = await RecordingRater.rate(url: url, targetFrequency: target)
        XCTAssertEqual(result.starCount, 3)
        XCTAssertEqual(try JSONDecoder().decode(PracticeRating.self, from: JSONEncoder().encode(result)), result)
        let missing = await RecordingRater.rate(url: url.appendingPathExtension("missing"), targetFrequency: target)
        XCTAssertEqual(missing.status, .unclear)
        XCTAssertNil(missing.starCount)
    }

    private func evaluate(_ samples: [Float]) -> PracticeRating {
        RecordingRater.rate(samples: samples, sampleRate: rate, targetFrequency: target)
    }

    private func sound(duration: Double, frequency: (Double) -> Double) -> [Float] {
        var phase = 0.0
        return (0..<Int(rate * duration)).map { index in
            let time = Double(index) / rate
            phase += 2 * .pi * frequency(time) / rate
            return Float(0.18 * sin(phase) + 0.04 * sin(2 * phase))
        }
    }
}
