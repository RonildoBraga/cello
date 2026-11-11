import Combine
import CryptoKit
import Foundation

/// One completed melody rhythm round. Its versioned goals are saved with the taps.
struct MelodyRhythmAttempt: Codable, Identifiable, Equatable, Sendable {
    static let scoringVersion = 1
    static let timingTolerance = 0.15
    static let consistencyLimitMilliseconds = 200.0

    let id: UUID
    let createdAt: Date
    let version: Int
    let context: MelodyRhythmContext
    let offsets: [Int: TimeInterval]
    let unexpectedTapCount: Int
    let actualTapTimes: [TimeInterval]
    private let rating: Rating

    init?(timing: MelodyRhythmTiming, finishedAt time: TimeInterval,
          id: UUID = UUID(), createdAt: Date = Date()) {
        guard timing.context.isValid, timing.context.scoringVersion == Self.scoringVersion,
              timing.canTap(at: timing.practiceStartTime), time.isFinite,
              timing.phase(at: time) == .finished,
              createdAt.timeIntervalSince1970.isFinite else { return nil }
        self.id = id
        self.createdAt = createdAt
        version = Self.scoringVersion
        context = timing.context
        offsets = timing.offsets
        unexpectedTapCount = timing.unexpectedTapCount
        actualTapTimes = timing.actualTapTimes
        rating = Self.gradeVersionOne(context: timing.context, offsets: timing.offsets,
                                      extras: timing.unexpectedTapCount, totalTaps: timing.actualTapTimes.count)
        guard isValid else { return nil }
    }

    var expectedTapCount: Int { context.expectedTapTimes.count }
    var totalTaps: Int { actualTapTimes.count }
    var isScored: Bool { rating.isScored }
    var patternGoal: Bool { rating.pattern }
    var timingGoal: Bool { rating.timing }
    var consistencyGoal: Bool { rating.consistency }
    var starCount: Int? {
        isScored ? [patternGoal, timingGoal, consistencyGoal].filter { $0 }.count : nil
    }
    var onTimeFraction: Double { rating.onTimeFraction }
    var spreadMilliseconds: Double? { rating.spreadMilliseconds }
    var medianOffsetMilliseconds: Double? {
        RhythmStatistics.percentile(0.5, in: offsets.values.map { $0 * 1_000 }.sorted())
    }

    var cue: String {
        guard isScored else { return "Tap each note’s start through the whole phrase to get a score." }
        // Only say "one beat late" when the first tap really landed a beat after the first note.
        let beat = context.beatInterval
        let oneBeatLate = zip(actualTapTimes.prefix(1), context.expectedTapTimes.prefix(1))
            .contains { abs($0 - ($1 + beat)) <= beat * 0.3 }
        return TapDiagnosis.feedback(kind: .melody, expected: expectedTapCount, offsets: offsets,
                                     extras: unexpectedTapCount, oneBeatLate: oneBeatLate,
                                     coverage: patternGoal || unexpectedTapCount > 0,
                                     timing: timingGoal, evenness: consistencyGoal)
    }

    /// Keep version-one grading fixed; a changed rubric needs a new version.
    private static func gradeVersionOne(context: MelodyRhythmContext, offsets: [Int: TimeInterval],
                                        extras: Int, totalTaps: Int) -> Rating {
        let required = min(3, context.expectedTapTimes.count)
        let scored = required > 0 && totalTaps >= required
        let enoughMatches = required > 0 && offsets.count >= required
        let fraction = offsets.isEmpty ? 0 : Double(offsets.values.filter {
            abs($0) <= timingTolerance + 1e-9
        }.count) / Double(offsets.count)
        let values = offsets.values.map { $0 * 1_000 }.sorted()
        let spread = enoughMatches ? RhythmStatistics.percentile(0.9, in: values).flatMap { upper in
            RhythmStatistics.percentile(0.1, in: values).map { upper - $0 }
        } : nil
        return Rating(isScored: scored,
                      pattern: scored && offsets.count >= Int(ceil(Double(context.expectedTapTimes.count) * 0.8))
                        && extras == 0,
                      timing: scored && enoughMatches && fraction >= 0.75,
                      consistency: scored && enoughMatches
                        && (spread ?? .infinity) <= consistencyLimitMilliseconds + 1e-6,
                      onTimeFraction: fraction, spreadMilliseconds: spread)
    }

    fileprivate var isValid: Bool {
        guard version == Self.scoringVersion, context.isValid,
              context.scoringVersion == version, createdAt.timeIntervalSince1970.isFinite,
              unexpectedTapCount >= 0,
              actualTapTimes.count == offsets.count + unexpectedTapCount,
              actualTapTimes.count <= Int(ceil(context.duration / 0.05)) + 1,
              actualTapTimes.allSatisfy({ $0.isFinite && $0 >= -context.tapWindow(for: 0) - 1e-9 && $0 < context.duration }),
              zip(actualTapTimes, actualTapTimes.dropFirst()).allSatisfy({ pair in
                  pair.1 - pair.0 + 1e-9 >= MelodyRhythmTiming.duplicateInterval
              }),
              offsets.allSatisfy({ index, offset in
                  context.expectedTapTimes.indices.contains(index) && offset.isFinite
                    && abs(offset) <= context.tapWindow(for: index) + 1e-9
                    && actualTapTimes.contains { abs($0 - context.expectedTapTimes[index] - offset) <= 1e-6 }
              }) else { return false }
        return rating == Self.gradeVersionOne(context: context, offsets: offsets,
                                              extras: unexpectedTapCount, totalTaps: actualTapTimes.count)
    }

    private struct Rating: Codable, Equatable, Sendable {
        let isScored: Bool
        let pattern: Bool
        let timing: Bool
        let consistency: Bool
        let onTimeFraction: Double
        let spreadMilliseconds: Double?
    }

}

/// All melody rhythm phrases share one document, separate from every foundation history.
@MainActor
final class MelodyRhythmStore: ObservableObject {
    @Published private(set) var attempts: [MelodyRhythmAttempt] = []
    @Published private(set) var errorMessage: String?

    private let fileURL: URL
    private var completedKeys: Set<String> = []
    private var fileIsUnreadable = false

    init(directory: URL? = nil) {
        let directory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = directory.appendingPathComponent("MelodyRhythmPractice.json")
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: fileURL))
            guard document.schemaVersion == 1,
                  document.attempts.allSatisfy(\.isValid),
                  Set(document.attempts.map(\.id)).count == document.attempts.count,
                  document.completedKeys.allSatisfy({ $0.count == 64 && $0.allSatisfy { $0.isHexDigit } }) else {
                throw StorageError.invalidHistory
            }
            let earned = Self.earnedKeys(in: document.attempts)
            guard document.completedKeys.isSubset(of: earned) else { throw StorageError.invalidHistory }
            attempts = document.attempts
            completedKeys = earned
        } catch {
            fileIsUnreadable = true
            errorMessage = "Saved melody rhythm progress could not be read. Its file has been preserved."
        }
    }

    func progress(for context: MelodyRhythmContext) -> PracticeProgress {
        guard let key = Self.key(for: context) else {
            return PracticeProgress(successfulAttempts: 0, completed: false)
        }
        return PracticeProgress(stars: recentAttempts(for: context).map { $0.starCount ?? 0 },
                                alreadyCompleted: completedKeys.contains(key))
    }

    func bestStars(for context: MelodyRhythmContext) -> Int? {
        recentAttempts(for: context).compactMap(\.starCount).max()
    }

    func latestStars(for context: MelodyRhythmContext) -> Int? {
        guard let key = Self.key(for: context) else { return nil }
        return attempts.first { Self.key(for: $0.context) == key }?.starCount
    }

    @discardableResult
    func record(timing: MelodyRhythmTiming, at time: TimeInterval = ProcessInfo.processInfo.systemUptime,
                id: UUID = UUID()) -> MelodyRhythmAttempt? {
        guard let attempt = MelodyRhythmAttempt(timing: timing, finishedAt: time, id: id) else { return nil }
        if let existing = attempts.first(where: { $0.id == id }) {
            return existing.context == attempt.context && existing.offsets == attempt.offsets
                && existing.actualTapTimes == attempt.actualTapTimes ? existing : nil
        }
        guard !fileIsUnreadable else { return attempt }
        // Recorded order survives wall-clock corrections. Dates are metadata,
        // so a clock rollback cannot move a new round into an old score window.
        let updated = [attempt] + attempts
        let earned = completedKeys.union(Self.earnedKeys(in: updated))
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let document = Document(schemaVersion: 1, attempts: updated, completedKeys: earned)
            try JSONEncoder().encode(document).write(to: fileURL, options: .atomic)
            attempts = updated
            completedKeys = earned
            errorMessage = nil
        } catch {
            errorMessage = "This rhythm result could not be saved. Please try again."
        }
        return attempt
    }

    private func recentAttempts(for context: MelodyRhythmContext) -> [MelodyRhythmAttempt] {
        guard let key = Self.key(for: context) else { return [] }
        return attempts.filter { $0.isScored && Self.key(for: $0.context) == key }
    }

    /// Attempts are stored newest first; the rule replays them in recorded order.
    private static func earnedKeys(in attempts: [MelodyRhythmAttempt]) -> Set<String> {
        CompletionRule.earnedKeys(attempts.reversed().compactMap { attempt in
            guard attempt.isScored, let key = key(for: attempt.context) else { return nil }
            return (key: key, success: attempt.starCount == 3)
        })
    }

    private static func key(for context: MelodyRhythmContext) -> String? {
        guard context.isValid, context.scoringVersion == MelodyRhythmAttempt.scoringVersion else { return nil }
        let reference = context.reference
        let selection = RhythmKey(pieceID: reference.pieceID, scoreVersion: reference.scoreVersion,
                                  section: reference.section, tempoBPM: reference.tempoBPM,
                                  scoringVersion: context.scoringVersion, durationBeats: reference.durationBeats,
                                  events: reference.expectedEvents.map {
            RhythmKey.Event(onsetBeat: $0.onsetBeat, durationBeats: $0.durationBeats, isRest: $0.midiNote == nil)
        })
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(selection) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private struct RhythmKey: Encodable {
        let pieceID: String
        let scoreVersion: Int
        let section: MelodySection
        let tempoBPM: Int
        let scoringVersion: Int
        let durationBeats: Double
        let events: [Event]
        struct Event: Encodable {
            let onsetBeat: Double
            let durationBeats: Double
            let isRest: Bool
        }
    }

    private struct Document: Codable {
        let schemaVersion: Int
        let attempts: [MelodyRhythmAttempt]
        let completedKeys: Set<String>
    }

    private enum StorageError: Error { case invalidHistory }
}
