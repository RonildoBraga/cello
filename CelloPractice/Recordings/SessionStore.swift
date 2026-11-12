import AVFoundation
import CelloPitch
import Combine
import Foundation

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [PracticeSession] = []
    @Published private(set) var pendingRecordingCount: Int = 0
    @Published var errorMessage: String?
    /// What went wrong saving the most recent take, for the screen that recorded it.
    /// Problems reading older history belong to Recordings, not to a practice screen.
    @Published private(set) var lastSaveError: String?

    private let directory: URL
    private var foundationProgress: LedgerFile<PracticeProgressLedger>
    private var melodyProgressFile: LedgerFile<MelodyProgressLedger>
    private var echoProgressFile: LedgerFile<EchoProgressLedger>

    init(directory overrideDirectory: URL? = nil) {
        directory = overrideDirectory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("PracticeSessions", isDirectory: true)
        let documents = directory.deletingLastPathComponent()
        foundationProgress = LedgerFile(ledger: PracticeProgressLedger(), label: "progress",
                                        url: documents.appendingPathComponent("PracticeProgress.json"))
        melodyProgressFile = LedgerFile(ledger: MelodyProgressLedger(), label: "melody progress",
                                        url: documents.appendingPathComponent("MelodyProgress.json"))
        echoProgressFile = LedgerFile(ledger: EchoProgressLedger(), label: "echo progress",
                                      url: documents.appendingPathComponent("EchoProgress.json"))
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let folders = try FileManager.default.contentsOfDirectory(
                at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles]
            )
            var unreadableCount = 0
            for folder in folders {
                guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                do {
                    let metadata = try Data(contentsOf: folder.appendingPathComponent("session.json"))
                    let session = try Self.decoder().decode(PracticeSession.self, from: metadata)
                    guard session.id.uuidString == folder.lastPathComponent,
                          Self.isSafeFilename(session.videoFilename),
                          session.melodyContext?.isValid != false else {
                        throw StorageError.invalidMetadata
                    }
                    sessions.append(session)
                } catch {
                    // Preserve unrecognised folders and corrupt metadata for recovery.
                    unreadableCount += 1
                }
            }
            sessions.sort { $0.createdAt > $1.createdAt }
            if unreadableCount > 0 {
                errorMessage = "\(unreadableCount) saved session(s) could not be read. Their files have been preserved in PracticeSessions."
            }
        } catch {
            errorMessage = "Could not open your practice history: \(error.localizedDescription)"
        }
        foundationProgress.load(sessions: sessions, errorMessage: &errorMessage)
        melodyProgressFile.load(sessions: sessions, errorMessage: &errorMessage)
        echoProgressFile.load(sessions: sessions, errorMessage: &errorMessage)
        refreshPendingRecordings()
    }

    func saveRecording(from source: URL, samples: [PitchSample], exercise: Exercise,
                       notes: String = "", duration: Double, targetFrequency: Double? = nil,
                       melodyContext: MelodyPracticeContext? = nil, room: RoomNoise? = nil) async -> PracticeSession? {
        errorMessage = progressPersistenceError
        lastSaveError = nil
        defer {
            refreshPendingRecordings()
            lastSaveError = errorMessage
        }
        guard melodyContext?.isValid != false else {
            errorMessage = "Could not save this session because its melody reference is invalid. The original recording is preserved at \(source.lastPathComponent)."
            return nil
        }
        let mediaDuration = try? await AVURLAsset(url: source).load(.duration)
        let measuredDuration = mediaDuration?.seconds
        let savedDuration = measuredDuration.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
            ?? (duration.isFinite ? max(0, duration) : 0)
        let validSamples = samples.filter {
            $0.time.isFinite && $0.time >= 0 && $0.time <= savedDuration &&
                $0.frequency.isFinite && $0.frequency > 0 &&
                $0.confidence.isFinite && (0...1).contains($0.confidence) &&
                $0.rms.isFinite && $0.rms >= 0
        }
        let actualTarget = (melodyContext == nil ? (exercise.targetFrequency ?? targetFrequency) : nil)
            .flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        let rating: PracticeRating?
        if melodyContext == nil, exercise.method != nil, let actualTarget {
            rating = await RecordingRater.rate(url: source, targetFrequency: actualTarget)
        } else {
            rating = nil
        }
        let melodyRating: MelodyRating?
        if let context = melodyContext, context.gradingVersion == MelodyRating.currentVersion {
            melodyRating = await MelodyRecordingRater.rate(url: source, context: context)
        } else {
            melodyRating = nil
        }
        let session = PracticeSession(
            id: UUID(), createdAt: Date(), exercise: exercise,
            duration: savedDuration,
            notes: notes, pitchSamples: validSamples, videoFilename: "recording.mov",
            // A hummed note has no fixed target, so the one it was sung against is kept.
            tuningTargetFrequency: exercise.targetFrequency == nil ? actualTarget : nil,
            rating: rating, melodyContext: melodyContext, melodyRating: melodyRating,
            roomLevel: (room?.level).flatMap { $0.isFinite && $0 >= 0 ? $0 : nil }
        )
        let folder = folderURL(for: session)
        do {
            try await Task.detached(priority: .userInitiated) {
                let fileManager = FileManager.default
                try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
                do {
                    // Copy first: the original recording remains recoverable if metadata saving fails.
                    try fileManager.copyItem(at: source, to: folder.appendingPathComponent(session.videoFilename))
                    try Self.writeMetadata(session, to: folder)
                } catch {
                    try? fileManager.removeItem(at: folder)
                    throw error
                }
            }.value
            sessions.insert(session, at: 0)
            persistNewMilestones()
            // The durable video and metadata now both exist.
            try? FileManager.default.removeItem(at: source)
            return session
        } catch {
            errorMessage = "Could not save this session. The original recording is preserved at \(source.lastPathComponent). \(error.localizedDescription)"
            return nil
        }
    }

    func videoURL(for session: PracticeSession) -> URL {
        folderURL(for: session).appendingPathComponent(session.videoFilename)
    }

    func progress(for exercise: Exercise, targetFrequency: Double) -> PracticeProgress {
        foundationProgress.progress(forKey: PracticeProgressLedger.key(exercise: exercise, targetFrequency: targetFrequency))
    }

    /// The scores of the takes made on the same part before this one, newest first: a
    /// teacher's note uses them to name a habit.
    func melodyRatings(before session: PracticeSession, limit: Int = 3) -> [MelodyRating] {
        guard let part = session.melodyContext?.graded(by: 0) else { return [] }
        return sessions.filter { $0.createdAt < session.createdAt && $0.melodyContext?.graded(by: 0) == part }
            .sorted { $0.createdAt > $1.createdAt }.prefix(limit).compactMap(\.melodyRating)
    }

    func melodyProgress(for context: MelodyPracticeContext) -> PracticeProgress {
        melodyProgressFile.progress(forKey: MelodyProgressLedger.key(for: context))
    }

    func echoProgress(for level: EchoLevel, register: MelodyRegister) -> PracticeProgress {
        echoProgressFile.progress(forKey: EchoProgressLedger.key(for: level, register: register))
    }

    private var progressPersistenceError: String? {
        foundationProgress.persistenceError ?? melodyProgressFile.persistenceError
            ?? echoProgressFile.persistenceError
    }

    private func persistNewMilestones() {
        foundationProgress.persist(sessions: sessions, errorMessage: &errorMessage)
        melodyProgressFile.persist(sessions: sessions, errorMessage: &errorMessage)
        echoProgressFile.persist(sessions: sessions, errorMessage: &errorMessage)
    }

    func delete(_ session: PracticeSession) { delete([session]) }

    /// Removes takes and their files. However many go, the takes are read once
    /// before and once after, and the screens are told once.
    func delete(_ doomed: [PracticeSession]) {
        // Rated recordings may be the only durable proof of an earned milestone.
        // Preserve that proof until the separate progress file is safely written.
        persistNewMilestones()
        errorMessage = progressPersistenceError
        guard !foundationProgress.needsSave, !melodyProgressFile.needsSave,
              !echoProgressFile.needsSave else { return }
        var removed: Set<UUID> = []
        for session in doomed {
            do {
                try FileManager.default.removeItem(at: folderURL(for: session))
                removed.insert(session.id)
            } catch {
                errorMessage = "This session could not be deleted: \(error.localizedDescription)"
            }
        }
        sessions.removeAll { removed.contains($0.id) }
        foundationProgress.index(sessions)
        melodyProgressFile.index(sessions)
        echoProgressFile.index(sessions)
    }

    func export(_ session: PracticeSession) async throws -> URL {
        errorMessage = nil
        let current = sessions.first(where: { $0.id == session.id }) ?? session
        let video = videoURL(for: current)
        return try await Task.detached(priority: .userInitiated) {
            try await SessionExport.create(for: current, video: video)
        }.value
    }

    /// Includes partial files so that an interrupted or failed take stays discoverable.
    /// Recovery files are never removed automatically.
    func refreshPendingRecordings() {
        let pending = directory.deletingLastPathComponent()
            .appendingPathComponent("PendingTakes", isDirectory: true)
        guard FileManager.default.fileExists(atPath: pending.path) else {
            pendingRecordingCount = 0
            return
        }
        do {
            let files = try FileManager.default.contentsOfDirectory(
                at: pending, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]
            )
            pendingRecordingCount = files.filter {
                ["mov", "mp4", "m4v"].contains($0.pathExtension.lowercased()) &&
                    (try? $0.resourceValues(forKeys: [.isRegularFileKey]).isRegularFile) == true
            }.count
        } catch {
            if errorMessage == nil {
                errorMessage = "Pending recordings could not be checked: \(error.localizedDescription)"
            }
        }
    }

    private func folderURL(for session: PracticeSession) -> URL {
        directory.appendingPathComponent(session.id.uuidString, isDirectory: true)
    }

    private nonisolated static func isSafeFilename(_ name: String) -> Bool {
        !name.isEmpty && name != "." && name != ".." &&
            !name.contains("/") && !name.contains("\\")
    }

    private nonisolated static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    private nonisolated static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    nonisolated static func writeMetadata(_ session: PracticeSession, to folder: URL) throws {
        let data = try encoder().encode(session)
        try data.write(to: folder.appendingPathComponent("session.json"), options: .atomic)
    }

    private enum StorageError: LocalizedError {
        case invalidMetadata
        var errorDescription: String? { "The saved session metadata is invalid." }
    }
}

/// One activity's earned milestones and the file that keeps them. An unreadable
/// file is preserved and never overwritten; recordings can still load and save.
private struct LedgerFile<Ledger: SessionProgressLedger> {
    private(set) var ledger: Ledger
    /// The stars of every counted take under its achievement, so that progress is a
    /// lookup. Screens ask for progress every time they are drawn.
    private var stars: [String: [Int]] = [:]
    let label: String
    let url: URL
    private(set) var persistenceError: String?
    private(set) var needsSave = false
    private var fileIsUnreadable = false

    init(ledger: Ledger, label: String, url: URL) {
        self.ledger = ledger
        self.label = label
        self.url = url
    }

    mutating func load(sessions: [PracticeSession], errorMessage: inout String?) {
        if FileManager.default.fileExists(atPath: url.path) {
            do {
                let saved = try JSONDecoder().decode(Ledger.self, from: Data(contentsOf: url))
                guard saved.schemaVersion == 1 else { throw CocoaError(.fileReadCorruptFile) }
                ledger = saved
            } catch {
                persistenceError = "Saved \(label) could not be read. Its file and all recordings have been preserved."
                fileIsUnreadable = true
                if errorMessage == nil { errorMessage = persistenceError }
            }
        }
        persist(sessions: sessions, errorMessage: &errorMessage)
    }

    /// Progress towards one achievement, from the takes as last read.
    func progress(forKey key: String?) -> PracticeProgress { ledger.progress(forKey: key, stars: stars) }

    /// Reads the takes again. Call after any change to them.
    mutating func index(_ sessions: [PracticeSession]) { stars = Ledger.stars(in: sessions) }

    /// Reads the takes, adds the milestones they earn, then writes if anything is unsaved.
    mutating func persist(sessions: [PracticeSession], errorMessage: inout String?) {
        index(sessions)
        if ledger.update(from: stars) { needsSave = true }
        guard needsSave, !fileIsUnreadable else { return }
        do {
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            try encoder.encode(ledger).write(to: url, options: .atomic)
            needsSave = false
            if errorMessage == persistenceError { errorMessage = nil }
            persistenceError = nil
        } catch {
            persistenceError = "Your recording is saved, but \(label) could not be saved. \(error.localizedDescription)"
            errorMessage = persistenceError
        }
    }
}
