import AVFoundation
import CelloPitch
import Foundation
import XCTest
@testable import Cello

@MainActor
final class EchoSessionStoreTests: XCTestCase {
    func testDifferentPatternsEarnOnlyEchoProgressAndCompletionSurvivesDeletion() throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions")
        _ = try writeHistory(count: 3, in: directory)
        let unchanged: [String: Data] = [
            "PracticeProgress.json": try JSONEncoder().encode(PracticeProgressLedger()),
            "MelodyProgress.json": try JSONEncoder().encode(MelodyProgressLedger()),
            "PulsePractice.json": Data("existing pulse history".utf8),
            "TwoTapsPractice.json": Data("existing subdivision history".utf8),
            "MixedRhythmPractice.json": Data("existing mixed history".utf8),
            "MelodyRhythmPractice.json": Data("existing piece rhythm history".utf8)
        ]
        for (name, data) in unchanged { try data.write(to: root.appendingPathComponent(name)) }

        let store = SessionStore(directory: directory)
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(store.echoProgress(for: .twoNotes, register: .lowVoice).completed)
        XCTAssertFalse(store.echoProgress(for: .threeNotes, register: .lowVoice).completed)
        XCTAssertFalse(store.echoProgress(for: .twoNotes, register: .higherVoice).completed)
        let melody = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase1,
                                                           gradingVersion: MelodyRating.currentVersion)
        XCTAssertFalse(store.melodyProgress(for: melody).completed)
        XCTAssertFalse(store.progress(for: .steadyHum, targetFrequency: HummingExample.frequency).completed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: echoFile(root).path))
        for session in store.sessions { store.delete(session) }

        let restored = SessionStore(directory: directory)
        XCTAssertNil(restored.errorMessage)
        XCTAssertTrue(restored.sessions.isEmpty)
        XCTAssertTrue(restored.echoProgress(for: .twoNotes, register: .lowVoice).completed)
        for (name, data) in unchanged {
            XCTAssertEqual(try Data(contentsOf: root.appendingPathComponent(name)), data, name)
        }
    }

    func testUnreadableOrFutureEchoLedgerPreservesTheOnlyCompletionEvidence() throws {
        let unreadable = [Data("unreadable echo milestones".utf8),
                          try JSONSerialization.data(withJSONObject: ["schemaVersion": 99, "completedKeys": [] as [String]] as [String: Any])]
        for originalLedger in unreadable {
            let root = try temporaryRoot()
            defer { try? FileManager.default.removeItem(at: root) }
            let directory = root.appendingPathComponent("PracticeSessions")
            let history = try writeHistory(count: 3, in: directory)
            try originalLedger.write(to: echoFile(root))
            let store = SessionStore(directory: directory)
            let first = try XCTUnwrap(history.first)
            let metadataURL = directory.appendingPathComponent(first.id.uuidString).appendingPathComponent("session.json")
            let metadata = try Data(contentsOf: metadataURL)
            let media = try Data(contentsOf: store.videoURL(for: first))
            XCTAssertTrue(store.echoProgress(for: .twoNotes, register: .lowVoice).completed)
            XCTAssertNotNil(store.errorMessage)

            // An export or other UI operation clearing the display warning must
            // not permit deletion of the only durable achievement evidence.
            store.errorMessage = nil
            store.delete(first)
            XCTAssertEqual(store.sessions.count, 3)
            XCTAssertNotNil(store.errorMessage)
            XCTAssertEqual(try Data(contentsOf: echoFile(root)), originalLedger)
            XCTAssertEqual(try Data(contentsOf: metadataURL), metadata)
            XCTAssertEqual(try Data(contentsOf: store.videoURL(for: first)), media)

            // A subsequent load reconstructs milestones after external storage
            // recovery. Production never removes an unreadable ledger itself.
            try FileManager.default.removeItem(at: echoFile(root))
            let recovered = SessionStore(directory: directory)
            recovered.delete(first)
            XCTAssertNil(recovered.errorMessage)
            XCTAssertEqual(recovered.sessions.count, 2)
            XCTAssertTrue(SessionStore(directory: directory)
                .echoProgress(for: .twoNotes, register: .lowVoice).completed)
        }
    }

    func testFailedEchoMilestoneWriteKeepsSavedMovieAndRetriesBeforeDeletion() async throws {
        let root = try temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions")
        let history = try writeHistory(count: 2, in: directory)
        let store = SessionStore(directory: directory)
        XCTAssertEqual(store.echoProgress(for: .twoNotes, register: .lowVoice).successfulAttempts, 2)

        // Block this ledger only, after a normal initial load has saved its passes.
        try FileManager.default.removeItem(at: echoFile(root))
        try FileManager.default.createDirectory(at: echoFile(root), withIntermediateDirectories: true)
        try Data("retain this blocker".utf8).write(to: echoFile(root).appendingPathComponent("blocker"))
        let context = try EchoLevel.twoNotes.context(patternIndex: 2, register: .lowVoice)
        let source = try await recordedAudioMovie(context: context, in: root)
        let original = try Data(contentsOf: source)
        let saved = await store.saveRecording(from: source, samples: [], exercise: .listen,
                                              duration: context.duration, melodyContext: context)
        let session = try XCTUnwrap(saved)
        XCTAssertEqual(session.melodyRating?.starCount, 3, "The movie contains the actual recorded-human pattern")
        XCTAssertEqual(session.melodyContext, context)
        XCTAssertNil(session.rating)
        XCTAssertTrue(store.echoProgress(for: .twoNotes, register: .lowVoice).completed)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: store.videoURL(for: session)), original)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))

        let first = try XCTUnwrap(history.first)
        store.delete(first)
        XCTAssertEqual(store.sessions.count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.videoURL(for: first).path))
        XCTAssertNotNil(store.errorMessage)

        try FileManager.default.removeItem(at: echoFile(root))
        store.delete(first)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.sessions.count, 2)
        let restored = SessionStore(directory: directory)
        XCTAssertTrue(restored.echoProgress(for: .twoNotes, register: .lowVoice).completed)
        XCTAssertEqual(restored.sessions.first(where: { $0.id == session.id })?.melodyContext, context)
        XCTAssertEqual(try Data(contentsOf: restored.videoURL(for: session)), original)
    }

    private func temporaryRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent("EchoStore-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    private func echoFile(_ root: URL) -> URL { root.appendingPathComponent("EchoProgress.json") }

    /// Saved-rating fixtures exercise retention/recovery, not acoustic grading.
    /// The save test above and the separate movie integration test use real audio.
    private func writeHistory(count: Int, in directory: URL) throws -> [PracticeSession] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try (0..<count).map { index in
            let context = try EchoLevel.twoNotes.context(patternIndex: index, register: .lowVoice)
            let session = PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: Double(index)),
                exercise: .listen, duration: context.duration, notes: "", pitchSamples: [],
                videoFilename: "recording.mov", melodyContext: context,
                melodyRating: MelodyRating(status: .rated, notes: true, timing: true, clarity: true))
            let folder = directory.appendingPathComponent(session.id.uuidString)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try encoder.encode(session).write(to: folder.appendingPathComponent("session.json"))
            try Data("saved fixture media \(index)".utf8).write(to: folder.appendingPathComponent("recording.mov"))
            return session
        }
    }

    /// An audio-only QuickTime container exercises real AVFoundation decoding
    /// while keeping video-fixture generation in the existing integration suite.
    private func recordedAudioMovie(context: MelodyPracticeContext, in root: URL) async throws -> URL {
        let wav = root.appendingPathComponent("echo.wav")
        try RecordedReference.wavData(context: context).write(to: wav)
        let asset = AVURLAsset(url: wav)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        let source = try XCTUnwrap(tracks.first)
        let composition = AVMutableComposition()
        let audio = try XCTUnwrap(composition.addMutableTrack(withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid))
        try audio.insertTimeRange(CMTimeRange(start: .zero,
            duration: CMTime(seconds: context.duration, preferredTimescale: 600)), of: source, at: .zero)
        let url = root.appendingPathComponent("echo.mov")
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetPassthrough))
        if #available(iOS 18, *) {
            try await exporter.export(to: url, as: .mov)
        } else {
            exporter.outputURL = url
            exporter.outputFileType = .mov
            await exporter.export()
            guard exporter.status == .completed else {
                throw exporter.error ?? NSError(domain: "EchoStoreFixture", code: 1)
            }
        }
        return url
    }
}
