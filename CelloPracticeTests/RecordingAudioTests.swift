import AVFoundation
import CelloPitch
import CoreVideo
import Foundation
import XCTest
@testable import Cello

final class RecordingAudioTests: XCTestCase {
    func testLeadingTrackOffsetStaysSilentAndLosesTimingWithoutMovingNotes() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1,
                                                            gradingVersion: MelodyRating.currentVersion)
        let url = try await audioMovie(in: root, context: context, leadingOffset: 0.4)
        let samples = try await RecordingAudio.read(url: url, maximumDuration: 6)
        XCTAssertGreaterThanOrEqual(Double(samples.count) / RecordingAudio.sampleRate, 4.35)
        XCTAssertLessThanOrEqual(Double(samples.count) / RecordingAudio.sampleRate, 4.5)
        XCTAssertLessThan(rms(samples, from: 0, to: 0.35), 0.00001)
        XCTAssertGreaterThan(rms(samples, from: 0.45, to: 0.55), 0.05)
        let rating = MelodyRecordingRater.rate(samples: samples, sampleRate: RecordingAudio.sampleRate, context: context)
        XCTAssertEqual(rating.status, .rated)
        XCTAssertTrue(rating.notes, "A correct sequence can retain Notes while its original onset remains late")
        XCTAssertFalse(rating.timing)
        XCTAssertFalse(rating.goalReached)
        XCTAssertEqual(try XCTUnwrap(rating.noteResults.first?.observedOnset), 0.4, accuracy: 0.07)
    }

    func testInteriorTrackGapIsPreservedOrRejectedInsteadOfConcatenated() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1,
                                                            gradingVersion: MelodyRating.currentVersion)
        let url = try await audioMovie(in: root, context: context, interiorGap: 0.4)
        do {
            let samples = try await RecordingAudio.read(url: url, maximumDuration: 6)
            XCTAssertGreaterThanOrEqual(Double(samples.count) / RecordingAudio.sampleRate, 4.35)
            XCTAssertLessThan(rms(samples, from: 1.05, to: 1.35), 0.00001)
            XCTAssertGreaterThan(rms(samples, from: 1.45, to: 1.55), 0.05)
            let rating = MelodyRecordingRater.rate(samples: samples, sampleRate: RecordingAudio.sampleRate, context: context)
            XCTAssertFalse(rating.goalReached, "Missing media cannot become a perfectly timed phrase")
        } catch {
            let rating = await MelodyRecordingRater.rate(url: url, context: context)
            XCTAssertEqual(rating.status, .unclear)
            XCTAssertNil(rating.starCount, "A rejected discontinuity must remain unscored")
        }
    }

    func testMissingAudioAndUnreadableMediaRemainUnscored() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let noAudio = try await silentVideo(in: root)
        let unreadable = root.appendingPathComponent("unreadable.mov")
        try Data("not a media file".utf8).write(to: unreadable)
        let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1,
                                                            gradingVersion: MelodyRating.currentVersion)
        for url in [noAudio, unreadable] {
            do {
                _ = try await RecordingAudio.read(url: url, maximumDuration: 6)
                XCTFail("Unreadable or missing audio must not decode as successful empty media")
            } catch { }
            let rating = await MelodyRecordingRater.rate(url: url, context: context)
            XCTAssertEqual(rating.status, .unclear)
            XCTAssertNil(rating.starCount)
        }
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CelloAudioTimelineTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func audioMovie(in root: URL, context: MelodyPracticeContext,
                            leadingOffset: Double = 0, interiorGap: Double = 0) async throws -> URL {
        let wav = root.appendingPathComponent("reference.wav")
        try SyntheticMelodyReference.wavData(context: context).write(to: wav)
        let asset = AVURLAsset(url: wav)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let source = try XCTUnwrap(tracks.first)
        let composition = AVMutableComposition()
        let track = try XCTUnwrap(composition.addMutableTrack(withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid))
        if interiorGap > 0 {
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: time(1)), of: source, at: .zero)
            try track.insertTimeRange(CMTimeRange(start: time(1), duration: time(context.duration - 1)),
                                      of: source, at: time(1 + interiorGap))
        } else {
            try track.insertTimeRange(CMTimeRange(start: .zero, duration: time(context.duration)),
                                      of: source, at: time(leadingOffset))
        }
        let destination = root.appendingPathComponent("timeline.mov")
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        if #available(iOS 18, *) {
            try await exporter.export(to: destination, as: .mov)
        } else {
            exporter.outputURL = destination
            exporter.outputFileType = .mov
            await exporter.export()
            XCTAssertEqual(exporter.status, .completed)
            if let error = exporter.error { throw error }
        }
        return destination
    }

    private func silentVideo(in root: URL) async throws -> URL {
        let destination = root.appendingPathComponent("no-audio.mov")
        let writer = try AVAssetWriter(outputURL: destination, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264, AVVideoWidthKey: 32, AVVideoHeightKey: 32
        ])
        let attributes = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
                          kCVPixelBufferWidthKey as String: 32,
                          kCVPixelBufferHeightKey as String: 32] as [String: Any]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw TestError.videoWriter }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? TestError.videoWriter }
        writer.startSession(atSourceTime: .zero)
        let deadline = Date().addingTimeInterval(5)
        while !input.isReadyForMoreMediaData {
            guard writer.status == .writing, Date() < deadline else { throw TestError.videoWriter }
            try await Task.sleep(nanoseconds: 1_000_000)
        }
        var buffer: CVPixelBuffer?
        XCTAssertEqual(CVPixelBufferCreate(kCFAllocatorDefault, 32, 32, kCVPixelFormatType_32BGRA,
                                         attributes as CFDictionary, &buffer), kCVReturnSuccess)
        let frame = try XCTUnwrap(buffer)
        CVPixelBufferLockBaseAddress(frame, [])
        _ = CVPixelBufferGetBaseAddress(frame)?.initializeMemory(as: UInt8.self, repeating: 0,
                                                                count: CVPixelBufferGetDataSize(frame))
        CVPixelBufferUnlockBaseAddress(frame, [])
        XCTAssertTrue(adaptor.append(frame, withPresentationTime: .zero))
        writer.endSession(atSourceTime: time(1))
        input.markAsFinished()
        await writer.finishWriting()
        XCTAssertEqual(writer.status, .completed)
        if let error = writer.error { throw error }
        return destination
    }

    private func time(_ seconds: Double) -> CMTime { CMTime(seconds: seconds, preferredTimescale: 48_000) }

    private func rms(_ samples: [Float], from start: Double, to end: Double) -> Double {
        let first = min(samples.count, Int(start * RecordingAudio.sampleRate))
        let last = min(samples.count, Int(end * RecordingAudio.sampleRate))
        guard last > first else { return .infinity }
        return sqrt(samples[first..<last].reduce(0.0) { $0 + Double($1 * $1) } / Double(last - first))
    }

    private enum TestError: Error { case videoWriter }
}
