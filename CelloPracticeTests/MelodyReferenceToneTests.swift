import AVFoundation
import CelloPitch
import Foundation
import XCTest
@testable import Cello

final class MelodyReferenceToneTests: XCTestCase {
    func testWholeMelodyIsDecodableMonoPCMWithExactBeatDuration() throws {
        let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice)
        let data = try MelodyReferenceTone.wavData(context: context)
        XCTAssertEqual(String(decoding: data.prefix(4), as: UTF8.self), "RIFF")
        XCTAssertEqual(String(decoding: data[8..<12], as: UTF8.self), "WAVE")
        let player = try AVAudioPlayer(data: data)
        XCTAssertEqual(player.numberOfChannels, 1)
        XCTAssertEqual(player.duration, 16, accuracy: 1 / Double(MelodyReferenceTone.sampleRate))
        XCTAssertEqual(data.count, 44 + 16 * MelodyReferenceTone.sampleRate * 2)
    }

    func testPhraseDurationTracksTempoIncludingLastNotesSilence() throws {
        for tempo in [40, 60, 72, 120] {
            for section in [MelodySection.phrase1, .phrase3, .whole] {
                let context = try MelodyPracticeContext.hotCrossBuns(register: .cello, section: section, tempoBPM: tempo)
                let data = try MelodyReferenceTone.wavData(context: context)
                let player = try AVAudioPlayer(data: data)
                XCTAssertEqual(player.duration, context.duration, accuracy: 1 / Double(MelodyReferenceTone.sampleRate))
                let expectedFrames = Int((context.duration * Double(MelodyReferenceTone.sampleRate)).rounded())
                XCTAssertEqual(data.count, 44 + expectedFrames * 2)
            }
        }
    }

    func testEveryNoteHasQuietEdgesAndAGapWithoutClipping() throws {
        let context = try MelodyPracticeContext.hotCrossBuns(register: .cello)
        let sound = try samples(context: context)
        XCTAssertTrue(sound.allSatisfy(\.isFinite))
        XCTAssertLessThan(sound.map(abs).max() ?? 1, 0.65)
        for event in context.expectedEvents {
            let start = Int(event.onsetBeat * Double(MelodyReferenceTone.sampleRate))
            let end = Int(event.endBeat * Double(MelodyReferenceTone.sampleRate))
            let audibleEnd = start + Int((Double(end - start) * 0.85).rounded())
            XCTAssertEqual(sound[start], 0)
            XCTAssertEqual(sound[audibleEnd - 1], 0)
            let middle = rms(sound[(start + 4_800)..<(start + 5_040)])
            XCTAssertGreaterThan(middle, 0.15)
            XCTAssertLessThan(rms(sound[start..<(start + 240)]), middle / 8)
            XCTAssertLessThan(rms(sound[(audibleEnd - 240)..<audibleEnd]), middle / 8)
            XCTAssertTrue(sound[audibleEnd..<end].allSatisfy { $0 == 0 })
        }
    }

    func testReferenceFundamentalsMatchAllThreeNotesInEveryRegister() throws {
        let detector = PitchDetector()
        for register in MelodyRegister.allCases {
            let context = try MelodyPracticeContext.hotCrossBuns(register: register, section: .phrase1)
            let sound = try samples(context: context)
            for event in context.expectedEvents {
                let start = Int((event.onsetBeat + 0.1) * Double(MelodyReferenceTone.sampleRate))
                let estimate = try XCTUnwrap(detector.estimate(
                    samples: Array(sound[start..<(start + 8_192)]),
                    sampleRate: Double(MelodyReferenceTone.sampleRate)
                ))
                let expected = try XCTUnwrap(context.frequency(for: event))
                XCTAssertLessThan(abs(1_200 * log2(estimate.frequency / expected)), 4)
                XCTAssertGreaterThan(estimate.confidence, 0.95)
            }
        }
    }

    func testExplicitRestAndUnwrittenSilenceRemainExactlySilent() throws {
        let context = snapshot(events: [
            MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 50),
            MelodyEvent(onsetBeat: 1, durationBeats: 1, midiNote: nil),
            MelodyEvent(onsetBeat: 3, durationBeats: 1, midiNote: 54)
        ])
        let sound = try samples(context: context)
        XCTAssertGreaterThan(rms(sound[4_800..<9_600]), 0.15)
        XCTAssertTrue(sound[48_000..<144_000].allSatisfy { $0 == 0 })
        XCTAssertGreaterThan(rms(sound[148_800..<153_600]), 0.15)
        XCTAssertEqual(sound.count, 4 * MelodyReferenceTone.sampleRate)
    }

    func testInvalidOrOversizedSnapshotsCannotAllocateAudio() {
        for context in [
            snapshot(events: []),
            snapshot(durationBeats: .nan),
            snapshot(durationBeats: .infinity),
            snapshot(durationBeats: 129),
            snapshot(tempoBPM: 0),
            snapshot(tempoBPM: Int.max),
            snapshot(tuningA4Hz: .nan),
            snapshot(events: [MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: Int.max)]),
            snapshot(events: [MelodyEvent(onsetBeat: 0, durationBeats: .infinity, midiNote: 50)])
        ] {
            XCTAssertThrowsError(try MelodyReferenceTone.wavData(context: context))
        }
    }

    private func snapshot(events: [MelodyEvent] = [MelodyEvent(onsetBeat: 0, durationBeats: 1, midiNote: 50)],
                          durationBeats: Double = 4, tempoBPM: Int = 60,
                          tuningA4Hz: Double = 440) -> MelodyPracticeContext {
        MelodyPracticeContext(pieceID: "hotCrossBuns", scoreVersion: 1, register: .cello,
                              referenceKey: "D major", tuningA4Hz: tuningA4Hz, tempoBPM: tempoBPM,
                              section: .whole, expectedEvents: events, durationBeats: durationBeats,
                              gradingVersion: nil)
    }

    private func samples(context: MelodyPracticeContext) throws -> [Float] {
        let data = try MelodyReferenceTone.wavData(context: context)
        return stride(from: 44, to: data.count, by: 2).map { offset in
            let bits = UInt16(data[offset]) | (UInt16(data[offset + 1]) << 8)
            return Float(Int16(bitPattern: bits)) / 32_768
        }
    }

    private func rms(_ samples: ArraySlice<Float>) -> Float {
        sqrt(samples.reduce(0) { $0 + $1 * $1 } / Float(samples.count))
    }
}
