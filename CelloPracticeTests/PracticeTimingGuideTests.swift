import AVFoundation
import CelloPitch
import XCTest
@testable import Cello

final class PracticeTimingGuideTests: XCTestCase {
    func testFirstSoundsUsesItsFrozenVoiceAndCelloTiming() throws {
        for register in [MelodyRegister.lowVoice, .cello] {
            let context = try EchoLevel.twoNotes.context(patternIndex: 4, register: register)
            let guide = VoicePracticeMode.echo(context, level: .twoNotes).timingGuide
            XCTAssertEqual(guide.duration, context.duration)
            XCTAssertEqual(guide.cues.filter(\.accent).map { $0.time - guide.countInDuration },
                           register == .cello ? [0, 4] : [0, 2])
        }
        let openString = VoicePracticeMode.note(.openD)
        XCTAssertFalse(openString.isTimed, "An open-string take still ends when the learner taps Stop")
        XCTAssertEqual(openString.timingGuide.duration, 90)
        XCTAssertEqual(openString.timingGuide.cues.filter(\.accent).map(\.time), [4])
    }

    func testCelloEchoCountsFourBeatsThenChangesAfterFourMore() {
        let guide = PracticeTimingGuide(beatInterval: 1, duration: 8, noteOnsets: [0, 4])
        XCTAssertEqual(guide.countInDuration, 4)
        XCTAssertEqual(guide.totalDuration, 12)
        XCTAssertEqual(guide.cues.map(\.time), (0..<12).map(Double.init))
        XCTAssertEqual(guide.cues.filter(\.accent).map(\.time), [4, 8])
        XCTAssertTrue(guide.cues.prefix(4).allSatisfy { !$0.accent })
    }

    func testVoiceEchoKeepsItsTwoBeatNotesAndEndsWithoutAnotherClick() {
        let guide = PracticeTimingGuide(beatInterval: 1, duration: 4, noteOnsets: [0, 2, 4])
        XCTAssertEqual(guide.cues.map(\.time), (0..<8).map(Double.init))
        XCTAssertEqual(guide.cues.filter(\.accent).map(\.time), [4, 6])
        XCTAssertTrue(guide.cues.allSatisfy { $0.time < guide.totalDuration })
    }

    func testFractionalNoteChangesAccentOnceAndKeepTheWholeBeat() {
        let guide = PracticeTimingGuide(beatInterval: 0.5, duration: 2.25,
                                        noteOnsets: [0, 0.75, 0.75, 1.5, 2.25])
        XCTAssertEqual(guide.cues.map(\.time), [0, 0.5, 1, 1.5, 2, 2.5, 2.75, 3, 3.5, 4])
        XCTAssertEqual(guide.cues.filter(\.accent).map(\.time), [2, 2.75, 3.5])
    }

    func testInvalidNoteOnsetsCannotAddCountInOrTailAccents() {
        let guide = PracticeTimingGuide(beatInterval: 1, duration: 2,
                                        noteOnsets: [-1, .nan, .infinity, 0.5, 2])
        XCTAssertEqual(guide.cues.filter(\.accent).map(\.time), [4, 4.5])
    }

    func testInvalidAndOversizedTracksFailWithoutAllocating() {
        let guides = [
            PracticeTimingGuide(beatInterval: 0, duration: 8, noteOnsets: []),
            PracticeTimingGuide(beatInterval: .nan, duration: 8, noteOnsets: []),
            PracticeTimingGuide(beatInterval: .infinity, duration: 8, noteOnsets: []),
            PracticeTimingGuide(beatInterval: 1, duration: 0, noteOnsets: []),
            PracticeTimingGuide(beatInterval: 1, duration: .infinity, noteOnsets: []),
            PracticeTimingGuide(beatInterval: 1, duration: 91, noteOnsets: []),
            PracticeTimingGuide(beatInterval: 1, duration: 8, noteOnsets: Array(repeating: 0, count: 4_097))
        ]
        for guide in guides {
            XCTAssertTrue(guide.cues.isEmpty)
            XCTAssertNil(guide.audioBuffer())
        }
        let valid = PracticeTimingGuide(beatInterval: 1, duration: 8, noteOnsets: [0, 4])
        for rate in [Double.nan, .infinity, 0, -48_000, 1_000_000] {
            XCTAssertNil(valid.audioBuffer(sampleRate: rate))
        }
        let tooLarge = PracticeTimingGuide(beatInterval: 15, duration: 90, noteOnsets: [0])
        XCTAssertNil(tooLarge.audioBuffer(sampleRate: 192_000))
    }

    func testRenderedClicksAreBriefMonoDeterministicAndAccented() throws {
        let guide = PracticeTimingGuide(beatInterval: 0.25, duration: 0.75, noteOnsets: [0, 0.5])
        let buffer = try XCTUnwrap(guide.audioBuffer(sampleRate: 8_000))
        let again = try XCTUnwrap(guide.audioBuffer(sampleRate: 8_000))
        XCTAssertEqual(buffer.format.sampleRate, 8_000)
        XCTAssertEqual(buffer.format.channelCount, 1)
        XCTAssertEqual(buffer.format.commonFormat, .pcmFormatFloat32)
        XCTAssertFalse(buffer.format.isInterleaved)
        XCTAssertEqual(buffer.frameLength, 14_000)
        let samples = Array(UnsafeBufferPointer(start: try XCTUnwrap(buffer.floatChannelData?[0]),
                                                count: Int(buffer.frameLength)))
        let repeated = Array(UnsafeBufferPointer(start: try XCTUnwrap(again.floatChannelData?[0]),
                                                 count: Int(again.frameLength)))
        XCTAssertEqual(samples, repeated)
        XCTAssertTrue(samples.allSatisfy { $0.isFinite && abs($0) <= 0.20 })
        XCTAssertTrue(samples[80..<2_000].allSatisfy { $0 == 0 }, "No sustained tone between clicks")
        XCTAssertTrue(samples[13_000..<14_000].allSatisfy { $0 == 0 }, "No cue at the end of the take")
        let quietEnergy = samples[0..<64].reduce(0.0) { $0 + Double($1 * $1) }
        let accentEnergy = samples[8_000..<8_064].reduce(0.0) { $0 + Double($1 * $1) }
        XCTAssertGreaterThan(quietEnergy, 0)
        XCTAssertGreaterThan(accentEnergy, quietEnergy * 2)
    }

    func testRecordingBoundaryTrimsOnlyCountInFrames() {
        XCTAssertEqual(PracticeTimingGuide.trimFrameCount(bufferStart: 10, recordingStart: 10.125,
                                                         sampleRate: 48_000, frameCount: 8_192), 6_000)
        XCTAssertEqual(PracticeTimingGuide.trimFrameCount(bufferStart: 10, recordingStart: 11,
                                                         sampleRate: 48_000, frameCount: 8_192), 8_192)
        XCTAssertEqual(PracticeTimingGuide.trimFrameCount(bufferStart: 10, recordingStart: 9,
                                                         sampleRate: 48_000, frameCount: 8_192), 0)
        XCTAssertEqual(PracticeTimingGuide.trimFrameCount(bufferStart: 10, recordingStart: 10,
                                                         sampleRate: 48_000, frameCount: 8_192), 0)
        XCTAssertEqual(PracticeTimingGuide.trimFrameCount(bufferStart: 10, recordingStart: 10 + 2.25 / 48_000,
                                                         sampleRate: 48_000, frameCount: 8_192), 3)
    }

    func testLargeHostClockDoesNotTrimAnExtraFrameAtAnExactBoundary() {
        XCTAssertEqual(PracticeTimingGuide.trimFrameCount(bufferStart: 1_234_567,
                                                         recordingStart: 1_234_567.125,
                                                         sampleRate: 48_000, frameCount: 8_192), 6_000)
    }

    func testInvalidRecordingClockCannotLeakCountInIntoTheTake() {
        for clock in [(Double.nan, 10.0, 48_000.0), (10, .infinity, 48_000),
                      (10, 10.1, 0), (10, 10.1, .nan)] {
            XCTAssertEqual(PracticeTimingGuide.trimFrameCount(bufferStart: clock.0, recordingStart: clock.1,
                                                             sampleRate: clock.2, frameCount: 100), 100)
        }
        XCTAssertEqual(PracticeTimingGuide.trimFrameCount(bufferStart: 10, recordingStart: 11,
                                                         sampleRate: 48_000, frameCount: 0), 0)
    }
}
