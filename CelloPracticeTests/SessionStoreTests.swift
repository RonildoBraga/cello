import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import UIKit
import XCTest
@testable import Cello

final class SessionStoreTests: XCTestCase {
    @MainActor
    func testRecordingPersistsReloadsExportsAndDeletes() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let source = try await makeMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true))
        let originalVideo = try Data(contentsOf: source)
        let samples = [
            sample(time: 0.1), sample(time: 0.3, frequency: 221),
            sample(time: -0.1), sample(time: 50), sample(time: .nan),
            sample(time: 0.2, frequency: .infinity), sample(time: 0.2, frequency: -1),
            sample(time: 0.2, confidence: .nan), sample(time: 0.2, confidence: 1.5),
            sample(time: 0.2, rms: .nan)
        ]
        let store = SessionStore(directory: directory)
        XCTAssertEqual(store.pendingRecordingCount, 1)
        store.errorMessage = "An old operation failed"
        let saved = await store.saveRecording(
            from: source, samples: samples, exercise: .openA, notes: "First observation", duration: 999
        )
        let session = try XCTUnwrap(saved)
        XCTAssertNil(store.errorMessage)
        XCTAssertEqual(store.sessions.count, 1)
        XCTAssertEqual(store.pendingRecordingCount, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
        XCTAssertEqual(try Data(contentsOf: store.videoURL(for: session)), originalVideo)
        XCTAssertGreaterThan(session.duration, 0.5)
        XCTAssertLessThan(session.duration, 2)
        XCTAssertEqual(session.pitchSamples.count, 2)
        XCTAssertTrue(session.pitchSamples.allSatisfy { $0.time >= 0 && $0.time <= session.duration })
        // This fixture has video only. Lack of usable audio produces no grade,
        // while the original movie and metadata still save normally.
        XCTAssertNotNil(session.rating)
        XCTAssertNil(session.rating?.starCount)

        let reloaded = SessionStore(directory: directory)
        let restored = try XCTUnwrap(reloaded.sessions.first)
        XCTAssertEqual(restored.id, session.id)
        XCTAssertEqual(restored.notes, "First observation")
        XCTAssertEqual(restored.pitchSamples.count, 2)
        XCTAssertEqual(restored.rating, session.rating)

        // Historical written notes remain readable, and export is read-only.
        let metadataURL = directory.appendingPathComponent(session.id.uuidString)
            .appendingPathComponent("session.json")
        let metadataBeforeExport = try Data(contentsOf: metadataURL)
        let archive = try await store.export(session)
        XCTAssertEqual(try Data(contentsOf: metadataURL), metadataBeforeExport)
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        let files = try readStoredZIP(at: archive)
        XCTAssertEqual(files["recording.mov"], originalVideo)
        let json = try XCTUnwrap(files["session.json"])
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(PracticeSession.self, from: json)
        XCTAssertEqual(exported.notes, "First observation")
        XCTAssertEqual(exported.pitchSamples.count, 2)
        XCTAssertEqual(exported.rating, session.rating)
        XCTAssertNotNil(files["pitch.csv"])
        let review = try XCTUnwrap(files["review.md"]).utf8String
        XCTAssertTrue(review.contains("Previously saved notes"))
        XCTAssertTrue(review.contains("First observation"))
        XCTAssertTrue(review.contains("## Practice rating"))
        XCTAssertTrue(review.contains("not rated"))
        let frames = files.filter { $0.key.hasSuffix(".jpg") }
        XCTAssertGreaterThanOrEqual(frames.count, 1)
        XCTAssertLessThanOrEqual(frames.count, 4)
        for frame in frames.values { XCTAssertNotNil(UIImage(data: frame)) }

        reloaded.delete(restored)
        XCTAssertNil(reloaded.errorMessage)
        XCTAssertTrue(reloaded.sessions.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath: reloaded.videoURL(for: restored).path))
        XCTAssertTrue(SessionStore(directory: directory).sessions.isEmpty)
    }

    @MainActor
    func testRealHummingMovieIsRatedSavedExportedAndEarnsDurableProgress() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let fixture = try await makeHummingMovie(in: root.appendingPathComponent("Fixtures", isDirectory: true))
        let pending = root.appendingPathComponent("PendingTakes", isDirectory: true)
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: true)
        let store = SessionStore(directory: directory)
        let target = HummingExample.frequency
        var savedSessions: [PracticeSession] = []
        for index in 0..<3 {
            let source = pending.appendingPathComponent("take-\(index).mov")
            try FileManager.default.copyItem(at: fixture, to: source)
            let result = await store.saveRecording(from: source, samples: [], exercise: .steadyHum,
                duration: 3, targetFrequency: target)
            let session = try XCTUnwrap(result)
            let rating = try XCTUnwrap(session.rating)
            XCTAssertEqual(rating.starCount, 3)
            XCTAssertEqual(rating.targetFrequency, target)
            XCTAssertFalse(FileManager.default.fileExists(atPath: source.path))
            XCTAssertEqual(store.progress(for: .steadyHum, targetFrequency: target).successfulAttempts, index + 1)
            savedSessions.append(session)
        }
        XCTAssertTrue(store.progress(for: .steadyHum, targetFrequency: target).completed)
        let restoredStore = SessionStore(directory: directory)
        let restored = try XCTUnwrap(restoredStore.sessions.first)
        XCTAssertEqual(restored.rating, savedSessions.last?.rating)
        let metadata = directory.appendingPathComponent(restored.id.uuidString).appendingPathComponent("session.json")
        let before = try Data(contentsOf: metadata)
        let archive = try await store.export(restored)
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        XCTAssertEqual(try Data(contentsOf: metadata), before)
        let files = try readStoredZIP(at: archive)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(PracticeSession.self, from: XCTUnwrap(files["session.json"]))
        XCTAssertEqual(exported.rating, restored.rating)
        XCTAssertTrue(try XCTUnwrap(files["review.md"]).utf8String.contains("Goals reached: 3 of 3"))

        // Preserve genuine production-rated fixtures outside this test's cleanup
        // folder for root's simulator-only visual QA. They never enter real history.
        let evidence = FileManager.default.temporaryDirectory
            .appendingPathComponent("CelloRatedVisualFixtures", isDirectory: true)
        try? FileManager.default.removeItem(at: evidence)
        try FileManager.default.createDirectory(at: evidence, withIntermediateDirectories: true)
        for session in savedSessions {
            try FileManager.default.copyItem(
                at: directory.appendingPathComponent(session.id.uuidString),
                to: evidence.appendingPathComponent(session.id.uuidString))
        }
        print("RATING_VISUAL_FIXTURES: \(evidence.path)")

        for session in restoredStore.sessions { restoredStore.delete(session) }
        let afterDeletion = SessionStore(directory: directory)
        XCTAssertTrue(afterDeletion.sessions.isEmpty)
        XCTAssertTrue(afterDeletion.progress(for: .steadyHum, targetFrequency: target).completed)
        XCTAssertEqual(afterDeletion.progress(for: .steadyHum, targetFrequency: target).successfulAttempts, 3)
    }

    @MainActor
    func testUnreadableMetadataAndPartialPendingTakesArePreserved() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let corrupt = directory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: corrupt, withIntermediateDirectories: true)
        let badMetadata = Data("not valid JSON".utf8)
        try badMetadata.write(to: corrupt.appendingPathComponent("session.json"))
        let pending = root.appendingPathComponent("PendingTakes", isDirectory: true)
        try FileManager.default.createDirectory(at: pending, withIntermediateDirectories: true)
        let partial = pending.appendingPathComponent("interrupted.mov")
        try Data().write(to: partial)

        let store = SessionStore(directory: directory)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(store.pendingRecordingCount, 1)
        XCTAssertEqual(try Data(contentsOf: corrupt.appendingPathComponent("session.json")), badMetadata)
        store.refreshPendingRecordings()
        XCTAssertEqual(store.pendingRecordingCount, 1)
        XCTAssertTrue(FileManager.default.fileExists(atPath: partial.path))
    }

    @MainActor
    func testUnreadableProgressDoesNotHideOrRewriteRecordings() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let id = UUID()
        let folder = directory.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let session = PracticeSession(id: id, createdAt: Date(), exercise: .steadyHum,
            duration: 3, notes: "", pitchSamples: [], videoFilename: "recording.mov",
            tuningTargetFrequency: HummingExample.frequency)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let originalMetadata = try encoder.encode(session)
        let metadataURL = folder.appendingPathComponent("session.json")
        try originalMetadata.write(to: metadataURL)
        let progressURL = root.appendingPathComponent("PracticeProgress.json")
        let unreadable = Data("not valid progress JSON".utf8)
        try unreadable.write(to: progressURL)
        let store = SessionStore(directory: directory)
        XCTAssertEqual(store.sessions.map(\.id), [id])
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: progressURL), unreadable)
        XCTAssertEqual(try Data(contentsOf: metadataURL), originalMetadata)
        XCTAssertFalse(store.progress(for: .steadyHum, targetFrequency: HummingExample.frequency).completed)
    }

    @MainActor
    func testDeletionWaitsForPendingProgressAndRetriesAfterStorageRecovers() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let historical = try writeSuccessfulHistory(count: 2, in: directory)
        let store = SessionStore(directory: directory)
        let target = HummingExample.frequency
        XCTAssertFalse(store.progress(for: .steadyHum, targetFrequency: target).completed)

        // Block only the milestone write, after the store has loaded normally.
        let progressURL = root.appendingPathComponent("PracticeProgress.json")
        // The first load has already saved the passes; block the file from here on.
        try? FileManager.default.removeItem(at: progressURL)
        try FileManager.default.createDirectory(at: progressURL, withIntermediateDirectories: true)
        let source = try await makeHummingMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true))
        let saved = await store.saveRecording(from: source, samples: [], exercise: .steadyHum,
                                              duration: 3, targetFrequency: target)
        XCTAssertEqual(try XCTUnwrap(saved).rating?.starCount, 3)
        XCTAssertTrue(store.progress(for: .steadyHum, targetFrequency: target).completed)
        XCTAssertNotNil(store.errorMessage)

        let first = try XCTUnwrap(historical.first)
        let folder = directory.appendingPathComponent(first.id.uuidString)
        let metadata = try Data(contentsOf: folder.appendingPathComponent("session.json"))
        let movie = try Data(contentsOf: store.videoURL(for: first))
        store.delete(first)
        XCTAssertEqual(store.sessions.count, 3)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("session.json")), metadata)
        XCTAssertEqual(try Data(contentsOf: store.videoURL(for: first)), movie)
        XCTAssertNotNil(store.errorMessage)

        // The same store retries the ledger write before allowing deletion.
        try FileManager.default.removeItem(at: progressURL)
        store.delete(first)
        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertFalse(FileManager.default.fileExists(atPath: folder.path))
        XCTAssertNil(store.errorMessage)
        let restored = SessionStore(directory: directory)
        XCTAssertEqual(restored.sessions.count, 2)
        XCTAssertTrue(restored.progress(for: .steadyHum, targetFrequency: target).completed)
    }

    @MainActor
    func testUnreadableLedgerBlocksDeletionOfTheOnlyEarnedProgressEvidence() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let historical = try writeSuccessfulHistory(count: 3, in: directory)
        let progressURL = root.appendingPathComponent("PracticeProgress.json")
        let corruptLedger = Data("unreadable progress evidence".utf8)
        try corruptLedger.write(to: progressURL)
        let store = SessionStore(directory: directory)
        let target = HummingExample.frequency
        XCTAssertTrue(store.progress(for: .steadyHum, targetFrequency: target).completed)
        let first = try XCTUnwrap(historical.first)
        let folder = directory.appendingPathComponent(first.id.uuidString)
        let metadata = try Data(contentsOf: folder.appendingPathComponent("session.json"))
        let movie = try Data(contentsOf: store.videoURL(for: first))

        // Even if another operation cleared its display, restore the warning.
        store.errorMessage = nil
        store.delete(first)
        XCTAssertEqual(store.sessions.count, 3)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: progressURL), corruptLedger)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("session.json")), metadata)
        XCTAssertEqual(try Data(contentsOf: store.videoURL(for: first)), movie)

        // Once the unreadable file is resolved, reload reconstructs the milestone
        // before any historical take is deleted. Production never removes it.
        try FileManager.default.removeItem(at: progressURL)
        let recovered = SessionStore(directory: directory)
        recovered.delete(first)
        XCTAssertNil(recovered.errorMessage)
        XCTAssertEqual(recovered.sessions.count, 2)
        XCTAssertTrue(SessionStore(directory: directory).progress(for: .steadyHum, targetFrequency: target).completed)
    }

    @MainActor
    func testDurationFormattingHandlesInvalidAndExtremeValuesAndPreservesNormalOutput() {
        for invalid in [Double.nan, .infinity, -.infinity, .greatestFiniteMagnitude,
                        -.greatestFiniteMagnitude, Double(Int.max), -1] {
            XCTAssertEqual(timeString(invalid), "0:00")
        }
        let ordinary: [(Double, String)] = [
            (0, "0:00"), (0.9, "0:00"), (1.9, "0:01"), (9.9, "0:09"),
            (59.99, "0:59"), (60, "1:00"), (61.9, "1:01"), (90, "1:30"),
            (3_600, "60:00"), (128_849_018_880, "2147483648:00")
        ]
        for (duration, expected) in ordinary {
            XCTAssertEqual(timeString(duration), expected)
        }
    }

    @MainActor
    func testSaveFailurePreservesOriginalRecording() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let source = try await makeMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true))
        let original = try Data(contentsOf: source)
        let blocked = root.appendingPathComponent("PracticeSessions")
        // A file in place of the directory reliably simulates a storage failure.
        try Data("not a directory".utf8).write(to: blocked)
        let store = SessionStore(directory: blocked)
        let saved = await store.saveRecording(
            from: source, samples: [sample(time: 0.1)], exercise: .listen, notes: "", duration: 1
        )
        XCTAssertNil(saved)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(store.pendingRecordingCount, 1)
        XCTAssertEqual(try Data(contentsOf: source), original)
        XCTAssertFalse(store.progress(for: .steadyHum, targetFrequency: HummingExample.frequency).completed)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("PracticeProgress.json").path))
    }

    @MainActor
    func testFreePracticeTargetPersistsAndExplainsExportedOffsets() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let source = try await makeMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true))
        let target = 87.30705785825097
        let samples = [-20.0, 0, 20].enumerated().map { index, cents in
            sample(time: Double(index + 1) / 10, frequency: target * pow(2, cents / 1_200))
        }
        let store = SessionStore(directory: directory)
        let saved = await store.saveRecording(
            from: source, samples: samples, exercise: .listen, notes: "Held one note", duration: 1,
            targetFrequency: target
        )
        let session = try XCTUnwrap(saved)
        let restored = try XCTUnwrap(SessionStore(directory: directory).sessions.first)
        XCTAssertEqual(restored.tuningTargetFrequency, target)
        XCTAssertEqual(restored.effectiveTargetFrequency, target)
        XCTAssertEqual(restored.effectiveTargetNote, "F2")
        XCTAssertEqual(try XCTUnwrap(restored.medianCentsFromTarget), 0, accuracy: 1e-8)
        XCTAssertEqual(restored.pitchSamples.map(\.frequency), samples.map(\.frequency))

        let archive = try await store.export(session)
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        let files = try readStoredZIP(at: archive)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(PracticeSession.self, from: XCTUnwrap(files["session.json"]))
        XCTAssertEqual(exported.tuningTargetFrequency, target)
        XCTAssertEqual(exported.pitchSamples.map(\.frequency), samples.map(\.frequency))
        let review = try XCTUnwrap(files["review.md"]).utf8String
        XCTAssertTrue(review.contains("Target: F2 (87.307 Hz)"))
        XCTAssertTrue(review.contains("Median offset"))
    }

    @MainActor
    func testGuidedHummingLessonsRetainTheirComfortableTargetAndExerciseInExports() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let store = SessionStore(directory: directory)
        let target = 97.99885899543733
        let samples = [-15.0, 0, 15].enumerated().map { index, cents in
            sample(time: Double(index + 1) / 10, frequency: target * pow(2, cents / 1_200))
        }
        for exercise in [Exercise.steadyHum, .matchHum] {
            let source = try await makeMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true))
            let saved = await store.saveRecording(
                from: source, samples: samples, exercise: exercise, duration: 1,
                targetFrequency: target
            )
            let session = try XCTUnwrap(saved)
            let restored = try XCTUnwrap(SessionStore(directory: directory).sessions.first { $0.id == session.id })
            XCTAssertEqual(restored.exercise, exercise)
            XCTAssertEqual(restored.tuningTargetFrequency, target)
            XCTAssertEqual(restored.effectiveTargetNote, "G2")
            XCTAssertEqual(restored.notes, "")
            XCTAssertEqual(restored.pitchSamples.map(\.frequency), samples.map(\.frequency))
            let archive = try await store.export(session)
            defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
            let files = try readStoredZIP(at: archive)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            let exported = try decoder.decode(PracticeSession.self, from: XCTUnwrap(files["session.json"]))
            XCTAssertEqual(exported.exercise, exercise)
            XCTAssertEqual(exported.tuningTargetFrequency, target)
            XCTAssertEqual(exported.notes, "")
            let review = try XCTUnwrap(files["review.md"]).utf8String
            XCTAssertTrue(review.contains("Exercise: \(exercise.title)"))
            XCTAssertTrue(review.contains("Target: G2 (97.999 Hz)"))
            XCTAssertFalse(review.contains("Previously saved notes"))
            XCTAssertFalse(review.contains("Learner observations"))
            XCTAssertFalse(review.contains("No observations added"))
        }
    }

    @MainActor
    func testMelodySnapshotPersistsReloadsAndExportsWithoutFoundationCredit() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let source = try await makeHummingMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true))
        let originalVideo = try Data(contentsOf: source)
        let context = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase3, tempoBPM: 72)
        let store = SessionStore(directory: directory)
        // Even if a caller retains a foundation exercise, a changing melody must
        // never receive a single-note rating or contribute to its milestones.
        let saved = await store.saveRecording(from: source, samples: [sample(time: 0.1)],
            exercise: .steadyHum, duration: 3, targetFrequency: HummingExample.frequency,
            melodyContext: context)
        let session = try XCTUnwrap(saved)
        XCTAssertEqual(session.melodyContext, context)
        XCTAssertNil(session.melodyRating, "Issue 3's nil grading version stays ungraded")
        XCTAssertNil(session.rating)
        XCTAssertNil(session.tuningTargetFrequency)
        XCTAssertNil(session.effectiveTargetFrequency)
        XCTAssertNil(session.medianCentsFromTarget)
        XCTAssertEqual(store.progress(for: .steadyHum, targetFrequency: HummingExample.frequency).successfulAttempts, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("PracticeProgress.json").path))

        let metadata = directory.appendingPathComponent(session.id.uuidString).appendingPathComponent("session.json")
        let before = try Data(contentsOf: metadata)
        let restored = try XCTUnwrap(SessionStore(directory: directory).sessions.first)
        XCTAssertEqual(restored.melodyContext, context)
        XCTAssertNil(restored.rating)
        XCTAssertNil(restored.melodyRating)
        let archive = try await store.export(restored)
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        XCTAssertEqual(try Data(contentsOf: metadata), before)
        let files = try readStoredZIP(at: archive)
        XCTAssertEqual(files["recording.mov"], originalVideo)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(PracticeSession.self, from: XCTUnwrap(files["session.json"]))
        XCTAssertEqual(exported.melodyContext, context)
        XCTAssertNil(exported.rating)
        XCTAssertNil(exported.melodyRating)
        XCTAssertTrue(try XCTUnwrap(files["review.md"]).utf8String.contains("## Melody reference"))

        let stringTake = PracticeSession(id: UUID(), createdAt: Date(), exercise: .openA,
            duration: 3, notes: "", pitchSamples: [], videoFilename: "recording.mov", melodyContext: context)
        XCTAssertNil(stringTake.effectiveTargetFrequency)
    }

    @MainActor
    func testMelodyAudioFeedbackPersistsReloadsAndExportsWithFrozenContext() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let source = try await makeHummingMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true))
        let original = try Data(contentsOf: source)
        let context = try scoredMelodyContext()
        let store = SessionStore(directory: directory)
        let saved = await store.saveRecording(from: source, samples: [sample(time: 0.2)],
            exercise: .steadyHum, duration: 3, targetFrequency: HummingExample.frequency, melodyContext: context)
        let session = try XCTUnwrap(saved)
        let rating = try XCTUnwrap(session.melodyRating)
        XCTAssertEqual(rating.version, MelodyRating.currentVersion)
        XCTAssertNotEqual(rating.starCount, 3, "The real single-note human hum cannot complete a moving melody")
        XCTAssertNil(session.rating)
        XCTAssertNil(session.effectiveTargetFrequency)
        XCTAssertEqual(session.title, "Hot Cross Buns · Phrase 1")
        XCTAssertEqual(session.starCount, rating.starCount)
        XCTAssertEqual(store.melodyProgress(for: context).successfulAttempts, 0)
        XCTAssertEqual(store.progress(for: .steadyHum, targetFrequency: HummingExample.frequency).successfulAttempts, 0)
        let restored = try XCTUnwrap(SessionStore(directory: directory).sessions.first)
        XCTAssertEqual(restored.melodyContext, context)
        XCTAssertEqual(restored.melodyRating, rating)
        let archive = try await store.export(restored)
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        let files = try readStoredZIP(at: archive)
        XCTAssertEqual(files["recording.mov"], original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(PracticeSession.self, from: XCTUnwrap(files["session.json"]))
        XCTAssertEqual(exported.melodyContext, context)
        XCTAssertEqual(exported.melodyRating, rating)
        XCTAssertTrue(try XCTUnwrap(files["review.md"]).utf8String.contains("## Melody feedback"))
    }

    @MainActor
    func testOdeToJoyRecordedAudioSavesReloadsAndExportsItsOwnFrozenScore() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let context = try MelodyPracticeContext.odeToJoy(register: .lowVoice, section: .phrase4,
                                                        gradingVersion: MelodyRating.currentVersion)
        let source = try await makeAudioMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true),
            audioData: RecordedReference.wavData(context: context), duration: context.duration)
        let original = try Data(contentsOf: source)
        let store = SessionStore(directory: directory)
        let saved = await store.saveRecording(from: source, samples: [], exercise: .steadyHum,
            duration: context.duration, targetFrequency: HummingExample.frequency, melodyContext: context)
        let session = try XCTUnwrap(saved)
        XCTAssertEqual(session.title, "Ode to Joy · Phrase 4")
        XCTAssertEqual(session.starCount, 3, "The saved movie's decoded audio must match the dotted ending")
        XCTAssertEqual(session.melodyContext, context)
        XCTAssertNil(session.rating)
        XCTAssertNil(session.effectiveTargetFrequency)
        XCTAssertEqual(store.melodyProgress(for: context).successfulAttempts, 1)
        let hot = try MelodyPracticeContext.hotCrossBuns(register: .lowVoice, section: .phrase4,
                                                        gradingVersion: MelodyRating.currentVersion)
        XCTAssertEqual(store.melodyProgress(for: hot).successfulAttempts, 0)
        XCTAssertEqual(store.progress(for: .steadyHum, targetFrequency: HummingExample.frequency).successfulAttempts, 0)

        let reloaded = SessionStore(directory: directory)
        let restored = try XCTUnwrap(reloaded.sessions.first)
        XCTAssertEqual(restored.melodyContext, context)
        XCTAssertEqual(restored.melodyRating, session.melodyRating)
        XCTAssertEqual(reloaded.melodyProgress(for: context).successfulAttempts, 1)
        let archive = try await reloaded.export(restored)
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        let files = try readStoredZIP(at: archive)
        XCTAssertEqual(files["recording.mov"], original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(PracticeSession.self, from: XCTUnwrap(files["session.json"]))
        XCTAssertEqual(exported.melodyContext, context)
        XCTAssertEqual(exported.melodyRating, session.melodyRating)
        XCTAssertEqual(exported.title, "Ode to Joy · Phrase 4")
        let review = try XCTUnwrap(files["review.md"]).utf8String
        XCTAssertTrue(review.contains("odeToJoy"))
        XCTAssertTrue(review.contains("## Melody feedback"))
    }

    @MainActor
    func testEchoRecordedMovieKeepsFrozenPatternRatingAndSeparateProgressThroughExport() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let context = try EchoLevel.twoNotes.context(patternIndex: 1, register: .lowVoice)
        let source = try await makeAudioMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true),
            audioData: RecordedReference.wavData(context: context), duration: context.duration)
        let original = try Data(contentsOf: source)
        let store = SessionStore(directory: directory)
        let saved = await store.saveRecording(from: source, samples: [], exercise: .listen,
                                              duration: context.duration, melodyContext: context)
        let session = try XCTUnwrap(saved)
        XCTAssertEqual(session.title, "Listen & Echo · Two notes")
        XCTAssertEqual(session.starCount, 3)
        XCTAssertEqual(session.melodyContext, context)
        XCTAssertNil(session.rating)
        XCTAssertNil(session.effectiveTargetFrequency)
        XCTAssertEqual(store.echoProgress(for: .twoNotes, register: .lowVoice).successfulAttempts, 1)
        XCTAssertEqual(store.echoProgress(for: .twoNotes, register: .higherVoice).successfulAttempts, 0)
        XCTAssertEqual(store.echoProgress(for: .threeNotes, register: .lowVoice).successfulAttempts, 0)
        XCTAssertEqual(store.melodyProgress(for: context).successfulAttempts, 0)
        XCTAssertEqual(store.progress(for: .steadyHum, targetFrequency: HummingExample.frequency).successfulAttempts, 0)
        XCTAssertFalse(FileManager.default.fileExists(atPath: root.appendingPathComponent("MelodyProgress.json").path))

        let reloaded = SessionStore(directory: directory)
        let restored = try XCTUnwrap(reloaded.sessions.first)
        XCTAssertEqual(restored.melodyContext, context)
        XCTAssertEqual(restored.melodyRating, session.melodyRating)
        XCTAssertEqual(reloaded.echoProgress(for: .twoNotes, register: .lowVoice).successfulAttempts, 1)
        let archive = try await reloaded.export(restored)
        defer { try? FileManager.default.removeItem(at: archive.deletingLastPathComponent()) }
        let files = try readStoredZIP(at: archive)
        XCTAssertEqual(files["recording.mov"], original)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let exported = try decoder.decode(PracticeSession.self, from: XCTUnwrap(files["session.json"]))
        XCTAssertEqual(exported.melodyContext, context)
        XCTAssertEqual(exported.melodyRating, session.melodyRating)
        XCTAssertEqual(exported.title, "Listen & Echo · Two notes")
        let review = try XCTUnwrap(files["review.md"]).utf8String
        XCTAssertTrue(review.contains("## Listen & Echo feedback"))
        XCTAssertTrue(review.contains("echoTwoNotes"))
        // Keep a real production-rated fixture for external Simulator UI review.
        // No app fixture mode or fabricated rating is involved.
        let metadataAttachment = XCTAttachment(data: try XCTUnwrap(files["session.json"]),
                                               uniformTypeIdentifier: "public.json")
        metadataAttachment.name = "Echo production-rated session.json"
        metadataAttachment.lifetime = .keepAlways
        add(metadataAttachment)
        let movieAttachment = XCTAttachment(data: original, uniformTypeIdentifier: "com.apple.quicktime-movie")
        movieAttachment.name = "Echo production-rated recording.mov"
        movieAttachment.lifetime = .keepAlways
        add(movieAttachment)
    }

    @MainActor
    func testUnsupportedMelodyGradingVersionSavesOriginalWithoutInventingFeedback() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let source = try await makeHummingMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true))
        let original = try Data(contentsOf: source)
        let context = try scoredMelodyContext(gradingVersion: MelodyRating.currentVersion + 1)
        let store = SessionStore(directory: directory)
        let saved = await store.saveRecording(from: source, samples: [], exercise: .listen,
            duration: 3, melodyContext: context)
        let session = try XCTUnwrap(saved)
        XCTAssertEqual(session.melodyContext, context)
        XCTAssertNil(session.melodyRating)
        XCTAssertNil(session.rating)
        XCTAssertEqual(try Data(contentsOf: store.videoURL(for: session)), original)
        XCTAssertFalse(store.melodyProgress(for: context).completed)
    }

    @MainActor
    func testMelodyMilestoneSurvivesDeletionWithoutChangingFoundationLedger() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let context = try scoredMelodyContext()
        _ = try writeMelodyHistory(count: 3, context: context, in: directory)
        let foundationURL = root.appendingPathComponent("PracticeProgress.json")
        let foundationData = try JSONEncoder().encode(PracticeProgressLedger())
        try foundationData.write(to: foundationURL)
        let store = SessionStore(directory: directory)
        XCTAssertTrue(store.melodyProgress(for: context).completed)
        XCTAssertTrue(FileManager.default.fileExists(atPath: root.appendingPathComponent("MelodyProgress.json").path))
        for session in store.sessions { store.delete(session) }
        let reloaded = SessionStore(directory: directory)
        XCTAssertTrue(reloaded.sessions.isEmpty)
        XCTAssertTrue(reloaded.melodyProgress(for: context).completed)
        XCTAssertEqual(try Data(contentsOf: foundationURL), foundationData)
        XCTAssertFalse(reloaded.progress(for: .steadyHum, targetFrequency: HummingExample.frequency).completed)
    }

    @MainActor
    func testUnreadableMelodyLedgerPreservesHistoryAndBlocksLosingCompletionEvidence() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let context = try scoredMelodyContext()
        let history = try writeMelodyHistory(count: 3, context: context, in: directory)
        let progressURL = root.appendingPathComponent("MelodyProgress.json")
        let unreadable = Data("unreadable melody milestone".utf8)
        try unreadable.write(to: progressURL)
        let store = SessionStore(directory: directory)
        XCTAssertTrue(store.melodyProgress(for: context).completed)
        XCTAssertNotNil(store.errorMessage)
        let first = try XCTUnwrap(history.first)
        let folder = directory.appendingPathComponent(first.id.uuidString)
        let metadata = try Data(contentsOf: folder.appendingPathComponent("session.json"))
        store.errorMessage = nil
        store.delete(first)
        XCTAssertEqual(store.sessions.count, 3)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertEqual(try Data(contentsOf: progressURL), unreadable)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("session.json")), metadata)
        try FileManager.default.removeItem(at: progressURL)
        let recovered = SessionStore(directory: directory)
        recovered.delete(first)
        XCTAssertNil(recovered.errorMessage)
        XCTAssertEqual(recovered.sessions.count, 2)
        XCTAssertTrue(SessionStore(directory: directory).melodyProgress(for: context).completed)
    }

    @MainActor
    func testMelodyDeletionRetriesPendingMilestoneAfterStorageRecovers() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let context = try scoredMelodyContext()
        let history = try writeMelodyHistory(count: 2, context: context, in: directory)
        let store = SessionStore(directory: directory)
        let progressURL = root.appendingPathComponent("MelodyProgress.json")
        // The first load has already saved the passes; block the file from here on.
        try? FileManager.default.removeItem(at: progressURL)
        try FileManager.default.createDirectory(at: progressURL, withIntermediateDirectories: true)
        let source = try await makeAudioMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true),
            audioData: SyntheticMelodyReference.wavData(context: context), duration: context.duration)
        let saved = await store.saveRecording(from: source, samples: [], exercise: .listen,
            duration: context.duration, melodyContext: context)
        XCTAssertEqual(try XCTUnwrap(saved).melodyRating?.starCount, 3)
        XCTAssertTrue(store.melodyProgress(for: context).completed)
        XCTAssertNotNil(store.errorMessage)
        let first = try XCTUnwrap(history.first)
        store.delete(first)
        XCTAssertEqual(store.sessions.count, 3)
        XCTAssertTrue(FileManager.default.fileExists(atPath: store.videoURL(for: first).path))
        try FileManager.default.removeItem(at: progressURL)
        store.delete(first)
        XCTAssertEqual(store.sessions.count, 2)
        XCTAssertNil(store.errorMessage)
        XCTAssertTrue(SessionStore(directory: directory).melodyProgress(for: context).completed)
    }

    @MainActor
    func testInvalidMelodyReferencePreservesPendingAndArchivedRecordings() async throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let source = try await makeMovie(in: root.appendingPathComponent("PendingTakes", isDirectory: true))
        let originalVideo = try Data(contentsOf: source)
        let context = try MelodyPracticeContext.hotCrossBuns(register: .cello)
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(context)) as? [String: Any])
        json["tempoBPM"] = 0
        let invalidContext = try JSONDecoder().decode(MelodyPracticeContext.self,
            from: JSONSerialization.data(withJSONObject: json))
        XCTAssertFalse(invalidContext.isValid)
        let store = SessionStore(directory: directory)
        let saved = await store.saveRecording(from: source, samples: [], exercise: .listen,
            duration: 1, melodyContext: invalidContext)
        XCTAssertNil(saved)
        XCTAssertNotNil(store.errorMessage)
        XCTAssertTrue(store.sessions.isEmpty)
        XCTAssertEqual(store.pendingRecordingCount, 1)
        XCTAssertEqual(try Data(contentsOf: source), originalVideo)

        // Invalid imported metadata stays on disk for recovery instead of being
        // accepted as a playable, gradeable score or silently rewritten.
        let invalidSession = PracticeSession(id: UUID(), createdAt: Date(), exercise: .listen,
            duration: 1, notes: "", pitchSamples: [], videoFilename: "recording.mov", melodyContext: invalidContext)
        let folder = directory.appendingPathComponent(invalidSession.id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let metadata = try encoder.encode(invalidSession)
        try metadata.write(to: folder.appendingPathComponent("session.json"))
        try originalVideo.write(to: folder.appendingPathComponent("recording.mov"))
        let reloaded = SessionStore(directory: directory)
        XCTAssertTrue(reloaded.sessions.isEmpty)
        XCTAssertNotNil(reloaded.errorMessage)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("session.json")), metadata)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("recording.mov")), originalVideo)
    }

    @MainActor
    func testLegacyFreePracticeHasNoInventedTargetAndStringTargetsStayAuthoritative() throws {
        let root = try makeRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let directory = root.appendingPathComponent("PracticeSessions", isDirectory: true)
        let id = UUID()
        let folder = directory.appendingPathComponent(id.uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let legacy = PracticeSession(
            id: id, createdAt: Date(), exercise: .listen, duration: 1, notes: "Old recording",
            pitchSamples: [sample(time: 0.1), sample(time: 0.2), sample(time: 0.3)],
            videoFilename: "recording.mov"
        )
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: encoder.encode(legacy)) as? [String: Any])
        json.removeValue(forKey: "tuningTargetFrequency")
        json.removeValue(forKey: "rating")
        json.removeValue(forKey: "melodyContext")
        json.removeValue(forKey: "melodyRating")
        let originalMetadata = try JSONSerialization.data(withJSONObject: json)
        try originalMetadata.write(to: folder.appendingPathComponent("session.json"))
        let store = SessionStore(directory: directory)
        XCTAssertNil(store.errorMessage)
        let restored = try XCTUnwrap(store.sessions.first)
        XCTAssertNil(restored.rating)
        XCTAssertNil(restored.melodyContext)
        XCTAssertNil(restored.melodyRating)
        XCTAssertNil(restored.tuningTargetFrequency)
        XCTAssertNil(restored.effectiveTargetFrequency)
        XCTAssertNil(restored.effectiveTargetNote)
        XCTAssertNil(restored.medianCentsFromTarget)
        XCTAssertEqual(try Data(contentsOf: folder.appendingPathComponent("session.json")), originalMetadata)

        for invalid in [Double.nan, .infinity, -.infinity, 0, -1] {
            let invalidFree = PracticeSession(
                id: UUID(), createdAt: Date(), exercise: .listen, duration: 1, notes: "",
                pitchSamples: legacy.pitchSamples, videoFilename: "recording.mov", tuningTargetFrequency: invalid
            )
            XCTAssertNil(invalidFree.effectiveTargetFrequency)
            XCTAssertNil(invalidFree.medianCentsFromTarget)
        }
        let string = PracticeSession(
            id: UUID(), createdAt: Date(), exercise: .openA, duration: 1, notes: "",
            pitchSamples: legacy.pitchSamples, videoFilename: "recording.mov", tuningTargetFrequency: 87.307
        )
        XCTAssertEqual(string.effectiveTargetFrequency, 220)
        XCTAssertEqual(string.effectiveTargetNote, "A3")
        XCTAssertEqual(try XCTUnwrap(string.medianCentsFromTarget), 0, accuracy: 1e-8)
    }

    private func makeRoot() throws -> URL {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("CelloSessionTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        return root
    }

    /// A previously rated history fixture; these media bytes must remain untouched.
    private func writeSuccessfulHistory(count: Int, in directory: URL) throws -> [PracticeSession] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try (0..<count).map { index in
            let session = PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: Double(index)),
                exercise: .steadyHum, duration: 3, notes: "", pitchSamples: [], videoFilename: "recording.mov",
                tuningTargetFrequency: HummingExample.frequency,
                rating: PracticeRating(targetFrequency: HummingExample.frequency, status: .rated,
                                       match: true, steady: true, hold: true))
            let folder = directory.appendingPathComponent(session.id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try encoder.encode(session).write(to: folder.appendingPathComponent("session.json"))
            try Data("historical movie \(index)".utf8).write(to: folder.appendingPathComponent(session.videoFilename))
            return session
        }
    }

    private func sample(time: Double, frequency: Double = 220,
                        confidence: Double = 0.9, rms: Double = 0.1) -> PitchSample {
        PitchSample(time: time, frequency: frequency, confidence: confidence, rms: rms)
    }

    private func scoredMelodyContext(gradingVersion: Int = MelodyRating.currentVersion) throws -> MelodyPracticeContext {
        try .hotCrossBuns(register: .lowVoice, section: .phrase1, gradingVersion: gradingVersion)
    }

    /// Archived-feedback fixture for ledger recovery; it is not an audio-rater test.
    private func writeMelodyHistory(count: Int, context: MelodyPracticeContext,
                                    in directory: URL) throws -> [PracticeSession] {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        return try (0..<count).map { index in
            let session = PracticeSession(id: UUID(), createdAt: Date(timeIntervalSince1970: Double(index)),
                exercise: .listen, duration: context.duration, notes: "", pitchSamples: [],
                videoFilename: "recording.mov", melodyContext: context,
                melodyRating: MelodyRating(status: .rated, notes: true, timing: true, clarity: true))
            let folder = directory.appendingPathComponent(session.id.uuidString, isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            try encoder.encode(session).write(to: folder.appendingPathComponent("session.json"))
            try Data("historical melody movie \(index)".utf8).write(to: folder.appendingPathComponent(session.videoFilename))
            return session
        }
    }

    private func makeHummingMovie(in folder: URL) async throws -> URL {
        try await makeAudioMovie(in: folder, audioData: HummingExample.wavData(), duration: 3)
    }

    private func makeAudioMovie(in folder: URL, audioData: Data, duration: Double) async throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let silentVideo = try await makeMovie(in: folder, duration: duration)
        let wav = folder.appendingPathComponent("human-hum.wav")
        try audioData.write(to: wav)
        let videoAsset = AVURLAsset(url: silentVideo)
        let audioAsset = AVURLAsset(url: wav)
        let videoTracks = try await videoAsset.loadTracks(withMediaType: .video)
        let audioTracks = try await audioAsset.loadTracks(withMediaType: .audio)
        let videoSource = try XCTUnwrap(videoTracks.first)
        let audioSource = try XCTUnwrap(audioTracks.first)
        let composition = AVMutableComposition()
        let video = try XCTUnwrap(composition.addMutableTrack(withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid))
        let audio = try XCTUnwrap(composition.addMutableTrack(withMediaType: .audio,
            preferredTrackID: kCMPersistentTrackID_Invalid))
        let range = CMTimeRange(start: .zero, duration: CMTime(seconds: duration, preferredTimescale: 600))
        try video.insertTimeRange(range, of: videoSource, at: .zero)
        try audio.insertTimeRange(range, of: audioSource, at: .zero)
        let url = folder.appendingPathComponent("human-hum.mov")
        let exporter = try XCTUnwrap(AVAssetExportSession(asset: composition,
            presetName: AVAssetExportPresetHighestQuality))
        if #available(iOS 18, *) {
            try await exporter.export(to: url, as: .mov)
        } else {
            exporter.outputURL = url
            exporter.outputFileType = .mov
            await exporter.export()
            guard exporter.status == .completed else {
                throw exporter.error ?? FixtureError.movie("Cannot export humming fixture")
            }
        }
        return url
    }

    /// Generates real H.264 media without camera permissions or a physical device.
    private func makeMovie(in folder: URL, duration: Double = 1) async throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("\(UUID().uuidString).mov")
        let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
        let input = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: 64,
            AVVideoHeightKey: 64
        ])
        input.expectsMediaDataInRealTime = false
        let attributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: 64,
            kCVPixelBufferHeightKey as String: 64,
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(assetWriterInput: input, sourcePixelBufferAttributes: attributes)
        guard writer.canAdd(input) else { throw FixtureError.movie("Cannot add video input") }
        writer.add(input)
        guard writer.startWriting() else { throw writer.error ?? FixtureError.movie("Cannot start writing") }
        writer.startSession(atSourceTime: .zero)
        let frameCount = Int(duration * 10)
        for frame in 0..<frameCount {
            let deadline = Date().addingTimeInterval(5)
            while !input.isReadyForMoreMediaData {
                guard writer.status == .writing, Date() < deadline else {
                    throw writer.error ?? FixtureError.movie("Video writer stalled")
                }
                try await Task.sleep(nanoseconds: 1_000_000)
            }
            var buffer: CVPixelBuffer?
            let result = CVPixelBufferCreate(kCFAllocatorDefault, 64, 64, kCVPixelFormatType_32BGRA,
                                             attributes as CFDictionary, &buffer)
            guard result == kCVReturnSuccess, let buffer else { throw FixtureError.movie("No pixel buffer") }
            CVPixelBufferLockBaseAddress(buffer, [])
            let context = CGContext(
                data: CVPixelBufferGetBaseAddress(buffer), width: 64, height: 64,
                bitsPerComponent: 8, bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
                space: CGColorSpaceCreateDeviceRGB(),
                bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
            )
            guard let context else {
                CVPixelBufferUnlockBaseAddress(buffer, [])
                throw FixtureError.movie("No drawing context")
            }
            context.setFillColor(red: CGFloat(frame) / CGFloat(frameCount), green: 0.4, blue: 0.7, alpha: 1)
            context.fill(CGRect(x: 0, y: 0, width: 64, height: 64))
            CVPixelBufferUnlockBaseAddress(buffer, [])
            guard adaptor.append(buffer, withPresentationTime: CMTime(value: Int64(frame), timescale: 10)) else {
                throw writer.error ?? FixtureError.movie("Cannot append frame")
            }
        }
        writer.endSession(atSourceTime: CMTime(seconds: duration, preferredTimescale: 600))
        input.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else { throw writer.error ?? FixtureError.movie("Cannot finish movie") }
        return url
    }

    /// An independent reader for the standard stored entries used by the export format.
    private func readStoredZIP(at url: URL) throws -> [String: Data] {
        let bytes = [UInt8](try Data(contentsOf: url))
        func integer(at offset: Int, count: Int) throws -> Int {
            guard offset >= 0, count > 0, offset + count <= bytes.count else { throw FixtureError.zip }
            return (0..<count).reduce(0) { $0 | (Int(bytes[offset + $1]) << ($1 * 8)) }
        }
        var files: [String: Data] = [:]
        var offset = 0
        while try integer(at: offset, count: 4) == 0x04034b50 {
            let flags = try integer(at: offset + 6, count: 2)
            let method = try integer(at: offset + 8, count: 2)
            guard flags & 0x0008 == 0, method == 0 else { throw FixtureError.zip }
            let size = try integer(at: offset + 18, count: 4)
            let nameLength = try integer(at: offset + 26, count: 2)
            let extraLength = try integer(at: offset + 28, count: 2)
            let nameStart = offset + 30
            let dataStart = nameStart + nameLength + extraLength
            guard dataStart + size <= bytes.count,
                  let name = String(bytes: bytes[nameStart..<(nameStart + nameLength)], encoding: .utf8) else {
                throw FixtureError.zip
            }
            files[name] = Data(bytes[dataStart..<(dataStart + size)])
            offset = dataStart + size
        }
        guard try integer(at: offset, count: 4) == 0x02014b50 else { throw FixtureError.zip }
        return files
    }

    private enum FixtureError: Error {
        case movie(String), zip
    }
}

private extension Data {
    var utf8String: String { String(decoding: self, as: UTF8.self) }
}
