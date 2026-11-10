import AVFoundation
import Combine
import Foundation
import UIKit

@MainActor
final class SessionStore: ObservableObject {
    @Published private(set) var sessions: [PracticeSession] = []
    @Published private(set) var pendingRecordingCount: Int = 0
    @Published var errorMessage: String?

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
                       melodyContext: MelodyPracticeContext? = nil) async -> PracticeSession? {
        errorMessage = progressPersistenceError
        defer { refreshPendingRecordings() }
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
        if melodyContext == nil, exercise.section != nil, let actualTarget {
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
            tuningTargetFrequency: exercise.usesComfortableTarget
                ? actualTarget : nil,
            rating: rating, melodyContext: melodyContext, melodyRating: melodyRating
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
        foundationProgress.ledger.progress(for: exercise, targetFrequency: targetFrequency, sessions: sessions)
    }

    func melodyProgress(for context: MelodyPracticeContext) -> PracticeProgress {
        melodyProgressFile.ledger.progress(for: context, sessions: sessions)
    }

    func echoProgress(for level: EchoLevel, register: MelodyRegister) -> PracticeProgress {
        echoProgressFile.ledger.progress(for: level, register: register, sessions: sessions)
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

    func delete(_ session: PracticeSession) {
        // Rated recordings may be the only durable proof of an earned milestone.
        // Preserve that proof until the separate progress file is safely written.
        persistNewMilestones()
        errorMessage = progressPersistenceError
        guard !foundationProgress.needsSave, !melodyProgressFile.needsSave,
              !echoProgressFile.needsSave else { return }
        do {
            try FileManager.default.removeItem(at: folderURL(for: session))
            sessions.removeAll { $0.id == session.id }
        } catch {
            errorMessage = "This session could not be deleted: \(error.localizedDescription)"
        }
    }

    func export(_ session: PracticeSession) async throws -> URL {
        errorMessage = nil
        let current = sessions.first(where: { $0.id == session.id }) ?? session
        let video = videoURL(for: current)
        return try await Task.detached(priority: .userInitiated) {
            try await Self.createExport(for: current, video: video)
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

    private nonisolated static func writeMetadata(_ session: PracticeSession, to folder: URL) throws {
        let data = try encoder().encode(session)
        try data.write(to: folder.appendingPathComponent("session.json"), options: .atomic)
    }

    private nonisolated static func createExport(for session: PracticeSession, video: URL) async throws -> URL {
        let fileManager = FileManager.default
        let exportFolder = fileManager.temporaryDirectory
            .appendingPathComponent("CelloPracticeExport-\(UUID().uuidString)", isDirectory: true)
        let staging = exportFolder.appendingPathComponent("contents", isDirectory: true)
        try fileManager.createDirectory(at: staging, withIntermediateDirectories: true)
        do {
            let movie = staging.appendingPathComponent("recording.mov")
            try fileManager.copyItem(at: video, to: movie)
            try writeMetadata(session, to: staging)

            var entries: [(name: String, url: URL)] = [
                ("session.json", staging.appendingPathComponent("session.json")),
                ("recording.mov", movie)
            ]

            let csv = "time_seconds,frequency_hz,confidence,rms\n" + session.pitchSamples.map {
                "\($0.time),\($0.frequency),\($0.confidence),\($0.rms)"
            }.joined(separator: "\n") + "\n"
            let csvURL = staging.appendingPathComponent("pitch.csv")
            try Data(csv.utf8).write(to: csvURL, options: .atomic)
            entries.append(("pitch.csv", csvURL))

            let asset = AVURLAsset(url: movie)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 1_280, height: 1_280)
            let loadedDuration = try? await asset.load(.duration)
            let assetDuration = loadedDuration?.seconds ?? session.duration
            let duration = assetDuration.isFinite ? max(0, assetDuration) : 0
            var frameDescriptions: [String] = []
            if duration > 0.1 {
                for index in 1...4 {
                    let seconds = min(duration - 0.05, duration * Double(index) / 5)
                    do {
                        let (image, actualTime) = try await generator.image(
                            at: CMTime(seconds: seconds, preferredTimescale: 600)
                        )
                        guard let jpeg = UIImage(cgImage: image).jpegData(compressionQuality: 0.8) else { continue }
                        let name = "frame-\(index).jpg"
                        let url = staging.appendingPathComponent(name)
                        try jpeg.write(to: url, options: .atomic)
                        entries.append((name, url))
                        frameDescriptions.append("- \(name): approximately \(String(format: "%.2f", actualTime.seconds)) seconds")
                    } catch {
                        // A recording is still worth exporting when a preview frame is unavailable.
                        continue
                    }
                }
            }

            let review = reviewMarkdown(for: session, frames: frameDescriptions)
            let reviewURL = staging.appendingPathComponent("review.md")
            try Data(review.utf8).write(to: reviewURL, options: .atomic)
            entries.append(("review.md", reviewURL))

            let date = ISO8601DateFormatter().string(from: session.createdAt)
                .replacingOccurrences(of: ":", with: "-")
            let zip = exportFolder.appendingPathComponent("CelloPractice-\(date).zip")
            try StoredZIP.write(entries: entries, to: zip)
            try? fileManager.removeItem(at: staging)
            return zip
        } catch {
            try? fileManager.removeItem(at: exportFolder)
            throw error
        }
    }

    private nonisolated static func reviewMarkdown(for session: PracticeSession, frames: [String]) -> String {
        let target = session.effectiveTargetFrequency.map { frequency in
            "\(session.effectiveTargetNote ?? "Target") (\(String(format: "%.3f", frequency)) Hz)"
        } ?? "No fixed note"
        var result = """
        # Cello practice session

        - Recorded: \(ISO8601DateFormatter().string(from: session.createdAt))
        - Exercise: \(session.title)
        - Duration: \(String(format: "%.1f", session.duration)) seconds
        - Target: \(target)
        - Pitch observations: \(session.pitchSamples.count)
        """
        if !session.notes.isEmpty {
            result += "\n\n## Previously saved notes\n\n\(session.notes)"
        }
        if let context = session.melodyContext {
            result += "\n\n## Melody reference\n\n"
            result += "- Piece: \(context.pieceID), score version \(context.scoreVersion)\n"
            result += "- Register: \(context.register.rawValue), key: \(context.referenceKey)\n"
            result += "- Tempo: \(context.tempoBPM) BPM\n"
            result += "- The selected expected events and grading version are frozen in session.json.\n"
        }
        if let rating = session.rating {
            result += "\n\n## Practice rating\n\n"
            result += "- Rating version: \(rating.version)\n"
            result += "- Reference: \(String(format: "%.3f", rating.targetFrequency)) Hz\n"
            if let stars = rating.starCount {
                result += "- Goals reached: \(stars) of 3\n"
                result += "- Match: \(rating.match ? "reached" : "keep practising")\n"
                result += "- Steady: \(rating.steady ? "reached" : "keep practising")\n"
                result += "- Hold: \(rating.hold ? "reached" : "keep practising")\n"
            } else {
                result += "- Result: not rated (\(rating.status.rawValue))\n"
            }
            result += "- Feedback: \(rating.feedback)\n"
            result += "- Longest continuous hold: \(String(format: "%.2f", rating.longestHold)) seconds\n"
            if let fraction = rating.nearTargetFraction {
                result += "- Near target: \(String(format: "%.1f", fraction * 100))% of evaluated voiced time\n"
            }
            if let spread = rating.settledSpreadCents {
                result += "- Settled pitch variation: \(String(format: "%.1f", spread)) cents\n"
            }
        }
        if let rating = session.melodyRating {
            let isEcho = session.melodyContext.flatMap { EchoLevel.selection(for: $0) } != nil
            result += isEcho ? "\n\n## Listen & Echo feedback\n\n" : "\n\n## Melody feedback\n\n"
            result += "- Scoring version: \(rating.version)\n"
            if let stars = rating.starCount {
                result += "- Goals reached: \(stars) of 3\n"
                result += "- Notes: \(rating.notes ? "reached" : "keep practising")\n"
                result += "- Timing: \(rating.timing ? "reached" : "keep practising")\n"
                result += "- Clarity: \(rating.clarity ? "reached" : "keep practising")\n"
            } else {
                result += "- Result: not rated (\(rating.status.rawValue))\n"
            }
            result += "- Feedback: \(isEcho ? rating.echoFeedback : rating.feedback)\n"
            result += "- Octave mismatch: \(rating.octaveMismatch ? "detected; pitches were not shifted" : "not detected")\n"
        }
        result += """


        ## Measurement context

        Pitch values are software estimates, not verified note labels. Confidence is the detector's internal estimate. A fixed target is the recorded human example or the selected open-string frequency; a melody reference instead stores its expected events in session.json. A practice rating checks this exercise's matching, steadiness and hold goals; it does not assess physical technique or overall musicianship. Background sound, bowed attacks and harmonics can cause missing or octave-shifted readings.

        """
        if let median = session.medianCentsFromTarget {
            result += "\nMedian offset among observations with confidence at least 0.75: \(String(format: "%+.1f", median)) cents. A positive value is above the target; a negative value is below it. A cent is one hundredth of a semitone.\n"
        }
        result += """

        ## Files for review

        - recording.mov: the original synchronized camera and microphone recording.
        - session.json: exercise, fixed target or melody reference if selected, duration, pitch measurements and a frozen practice rating when available, plus any notes retained from older recordings.
        - pitch.csv: timestamped pitch measurements for plotting or analysis.

        """
        result += frames.isEmpty
            ? "\nNo preview frames could be generated. Use the original video for visual review.\n"
            : "\nSelected video frames:\n\(frames.joined(separator: "\n"))\n"
        result += """

        ## Suggested review

        Use the stated exercise, measurements and selected frames to suggest one or two manageable next steps. Separate visible observations from hypotheses. Selected frames cannot show every movement, and these files do not establish bow pressure, internal tension, or the cause of an uneven sound. Review the recording only through tools that actually support its media; do not assume access to a live microphone or camera.
        """
        return result + "\n"
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

    /// Adds milestones earned by `sessions`, then writes if anything is unsaved.
    mutating func persist(sessions: [PracticeSession], errorMessage: inout String?) {
        if ledger.update(from: sessions) { needsSave = true }
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

/// Small, streaming ZIP writer using the standard uncompressed (stored) format.
/// Movies are already compressed; streaming avoids loading the recording into RAM.
private enum StoredZIP {
    private struct CentralEntry {
        let name: Data
        let crc: UInt32
        let size: UInt32
        let offset: UInt32
    }

    static func write(entries: [(name: String, url: URL)], to destination: URL) throws {
        guard entries.count <= Int(UInt16.max) else { throw ZIPError.tooLarge }
        guard FileManager.default.createFile(atPath: destination.path, contents: nil) else {
            throw ZIPError.cannotCreate
        }
        let output = try FileHandle(forWritingTo: destination)
        defer { try? output.close() }
        var centralEntries: [CentralEntry] = []
        for entry in entries {
            let name = Data(entry.name.utf8)
            guard name.count <= Int(UInt16.max) else { throw ZIPError.tooLarge }
            let (crc, size) = try checksum(of: entry.url)
            let position = try output.offset()
            guard position <= UInt32.max else { throw ZIPError.tooLarge }
            var header = Data()
            header.littleEndian(UInt32(0x04034b50))
            header.littleEndian(UInt16(20))
            header.littleEndian(UInt16(0x0800)) // UTF-8 file names
            header.littleEndian(UInt16(0)) // stored, no compression
            header.littleEndian(UInt16(0)) // DOS time
            header.littleEndian(UInt16(0x0021)) // 1 January 1980
            header.littleEndian(crc)
            header.littleEndian(size)
            header.littleEndian(size)
            header.littleEndian(UInt16(name.count))
            header.littleEndian(UInt16(0))
            header.append(name)
            try output.write(contentsOf: header)
            let source = try FileHandle(forReadingFrom: entry.url)
            defer { try? source.close() }
            while let chunk = try source.read(upToCount: 256 * 1_024), !chunk.isEmpty {
                try output.write(contentsOf: chunk)
            }
            centralEntries.append(CentralEntry(name: name, crc: crc, size: size, offset: UInt32(position)))
        }
        let centralOffset = try output.offset()
        guard centralOffset <= UInt32.max else { throw ZIPError.tooLarge }
        for entry in centralEntries {
            var header = Data()
            header.littleEndian(UInt32(0x02014b50))
            header.littleEndian(UInt16(20))
            header.littleEndian(UInt16(20))
            header.littleEndian(UInt16(0x0800))
            header.littleEndian(UInt16(0))
            header.littleEndian(UInt16(0))
            header.littleEndian(UInt16(0x0021))
            header.littleEndian(entry.crc)
            header.littleEndian(entry.size)
            header.littleEndian(entry.size)
            header.littleEndian(UInt16(entry.name.count))
            header.littleEndian(UInt16(0)) // extra
            header.littleEndian(UInt16(0)) // comment
            header.littleEndian(UInt16(0)) // start disk
            header.littleEndian(UInt16(0)) // internal attributes
            header.littleEndian(UInt32(0)) // external attributes
            header.littleEndian(entry.offset)
            header.append(entry.name)
            try output.write(contentsOf: header)
        }
        let centralSize = try output.offset() - centralOffset
        guard centralSize <= UInt32.max else { throw ZIPError.tooLarge }
        var end = Data()
        end.littleEndian(UInt32(0x06054b50))
        end.littleEndian(UInt16(0))
        end.littleEndian(UInt16(0))
        end.littleEndian(UInt16(centralEntries.count))
        end.littleEndian(UInt16(centralEntries.count))
        end.littleEndian(UInt32(centralSize))
        end.littleEndian(UInt32(centralOffset))
        end.littleEndian(UInt16(0))
        try output.write(contentsOf: end)
        try output.synchronize()
    }

    private static func checksum(of url: URL) throws -> (UInt32, UInt32) {
        let source = try FileHandle(forReadingFrom: url)
        defer { try? source.close() }
        var crc = UInt32.max
        var size: UInt64 = 0
        while let chunk = try source.read(upToCount: 256 * 1_024), !chunk.isEmpty {
            size += UInt64(chunk.count)
            guard size <= UInt32.max else { throw ZIPError.tooLarge }
            for byte in chunk {
                crc = crcTable[Int((crc ^ UInt32(byte)) & 0xff)] ^ (crc >> 8)
            }
        }
        return (crc ^ UInt32.max, UInt32(size))
    }

    private static let crcTable: [UInt32] = (0..<256).map { index in
        var value = UInt32(index)
        for _ in 0..<8 {
            value = value & 1 == 1 ? 0xedb88320 ^ (value >> 1) : value >> 1
        }
        return value
    }

    private enum ZIPError: LocalizedError {
        case cannotCreate, tooLarge
        var errorDescription: String? {
            switch self {
            case .cannotCreate: return "Could not create the practice export. Check available storage."
            case .tooLarge: return "This recording is too large for this export format."
            }
        }
    }
}

private extension Data {
    mutating func littleEndian<T: FixedWidthInteger>(_ value: T) {
        var number = value.littleEndian
        Swift.withUnsafeBytes(of: &number) { append(contentsOf: $0) }
    }
}
