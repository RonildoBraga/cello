import AVFoundation
import CelloPitch
import Foundation
import XCTest
@testable import Cello

final class ReferenceToneTests: XCTestCase {
    func testReferenceIsDecodableMonoPCMWithExpectedDuration() throws {
        let data = try ReferenceTone.wavData(frequency: 97.99885899543733)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        let player = try AVAudioPlayer(data: data)
        XCTAssertEqual(player.numberOfChannels, 1)
        XCTAssertEqual(player.duration, 2, accuracy: 1.0 / Double(ReferenceTone.sampleRate))
        XCTAssertEqual(data.count, 44 + ReferenceTone.sampleRate * 2 * 2)
    }

    func testReferenceFundamentalMatchesSelectedComfortableNote() throws {
        let detector = PitchDetector()
        for frequency in [65.40639132514966, 97.99885899543733, 103.82617439498628, 146.8323839587038, 220, 440] {
            let samples = try samples(frequency: frequency)
            let start = ReferenceTone.sampleRate / 3
            let estimate = try XCTUnwrap(detector.estimate(
                samples: Array(samples[start..<(start + 8_192)]),
                sampleRate: Double(ReferenceTone.sampleRate)
            ))
            XCTAssertLessThan(abs(1_200 * log2(estimate.frequency / frequency)), 4)
            XCTAssertGreaterThan(estimate.confidence, 0.95)
        }
    }

    func testReferenceHasQuietEdgesAndNoClipping() throws {
        let samples = try samples(frequency: 97.99885899543733)
        XCTAssertTrue(samples.allSatisfy(\.isFinite))
        XCTAssertEqual(samples.first, 0)
        XCTAssertEqual(samples.last, 0)
        XCTAssertLessThan(samples.map(abs).max() ?? 1, 0.65)
        let edgeRMS = rms(Array(samples.prefix(240)))
        let middleRMS = rms(Array(samples[10_000..<10_240]))
        XCTAssertLessThan(edgeRMS, middleRMS / 10)
        XCTAssertGreaterThan(middleRMS, 0.15)
    }

    func testLowReferenceHasClearUpperHarmonicsForPhonePlayback() throws {
        let frequency = 103.82617439498628
        let sound = try samples(frequency: frequency)
        let window = Array(sound[24_000..<72_000])
        func amplitude(at hz: Double) -> Double {
            var real = 0.0
            var imaginary = 0.0
            for (index, sample) in window.enumerated() {
                let angle = 2 * Double.pi * hz * Double(index) / Double(ReferenceTone.sampleRate)
                real += Double(sample) * cos(angle)
                imaginary += Double(sample) * sin(angle)
            }
            return 2 * hypot(real, imaginary) / Double(window.count)
        }
        let fundamental = amplitude(at: frequency)
        let second = amplitude(at: 2 * frequency)
        let third = amplitude(at: 3 * frequency)
        XCTAssertGreaterThan(fundamental, second)
        XCTAssertGreaterThan(second, 0.10)
        XCTAssertGreaterThan(third, 0.07)
    }

    func testInvalidReferencesCannotProduceAudio() {
        for frequency in [Double.nan, .infinity, -.infinity, -1, 0, 49, 1_001] {
            XCTAssertThrowsError(try ReferenceTone.wavData(frequency: frequency))
        }
    }

    func testHumanHumIsBundledDecodableAndHasPlaybackHeadroom() throws {
        let data = try HummingExample.wavData()
        let player = try AVAudioPlayer(data: data)
        XCTAssertEqual(player.numberOfChannels, 1)
        XCTAssertEqual(player.duration, HummingExample.duration, accuracy: 0.001)
        let sound = try humanSamples()
        XCTAssertTrue(sound.allSatisfy(\.isFinite))
        XCTAssertLessThan(sound.map(abs).max() ?? 1, 0.8)
        XCTAssertGreaterThan(rms(sound), 0.15)
        XCTAssertLessThan(rms(Array(sound.prefix(240))), rms(sound) / 5)
        XCTAssertLessThan(rms(Array(sound.suffix(240))), rms(sound) / 5)
    }

    func testHumanHumMatchesItsDeclaredPracticeTarget() throws {
        let sound = try humanSamples()
        let detector = PitchDetector()
        let estimates = stride(from: 0, through: sound.count - 8_192, by: 4_800).compactMap { start in
            detector.estimate(samples: Array(sound[start..<(start + 8_192)]), sampleRate: 48_000)
        }
        XCTAssertGreaterThanOrEqual(estimates.count, 25)
        XCTAssertTrue(estimates.allSatisfy { $0.confidence > 0.95 })
        let cents = estimates.map { 1_200 * log2($0.frequency / HummingExample.frequency) }.sorted()
        let median = try XCTUnwrap(cents.dropFirst(cents.count / 2).first)
        XCTAssertLessThan(abs(median), 8)
        XCTAssertLessThan(cents[Int(Double(cents.count - 1) * 0.9)] - cents[Int(Double(cents.count - 1) * 0.1)], 45)
    }

    private func humanSamples() throws -> [Float] {
        let data = try HummingExample.wavData()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("wav")
        defer { try? FileManager.default.removeItem(at: url) }
        try data.write(to: url)
        let file = try AVAudioFile(forReading: url)
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                                   frameCapacity: AVAudioFrameCount(file.length)))
        try file.read(into: buffer)
        let channel = try XCTUnwrap(buffer.floatChannelData?[0])
        return Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
    }

    private func samples(frequency: Double) throws -> [Float] {
        let data = try ReferenceTone.wavData(frequency: frequency)
        return stride(from: 44, to: data.count, by: 2).map { offset in
            let bits = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            return Float(Int16(bitPattern: bits)) / 32_768
        }
    }

    private func rms(_ samples: [Float]) -> Float {
        sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
    }
}
