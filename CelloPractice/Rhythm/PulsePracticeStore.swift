import Combine
import Foundation

/// A completed pulse round. These stars describe taps, never vocal pitch.
struct PulseAttempt: Codable, Identifiable {
    static let scoringVersion = 1
    static let timingTolerance = 0.15
    static let evennessLimitMilliseconds = 200.0

    let id: UUID
    let createdAt: Date
    let version: Int
    let bpm: Int
    let totalBeats: Int
    let offsets: [Int: TimeInterval]
    let exercise: RhythmExercise
    let unexpectedTapCount: Int

    init?(timing: PulseTiming, finishedAt time: TimeInterval,
          id: UUID = UUID(), createdAt: Date = Date()) {
        guard time.isFinite, timing.startTime.isFinite,
              timing.phase(at: time) == .finished else { return nil }
        self.id = id
        self.createdAt = createdAt
        version = Self.scoringVersion
        bpm = Int((60 / PulseTiming.beatInterval).rounded())
        totalBeats = timing.exercise.tapCount
        offsets = timing.offsets
        exercise = timing.exercise
        unexpectedTapCount = timing.unexpectedTapCount
    }

    // Old Pulse documents have no exercise field. Their timing and grades stay frozen.
    private enum CodingKeys: String, CodingKey {
        case id, createdAt, version, bpm, totalBeats, offsets, exercise, unexpectedTapCount
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(UUID.self, forKey: .id)
        createdAt = try values.decode(Date.self, forKey: .createdAt)
        version = try values.decode(Int.self, forKey: .version)
        bpm = try values.decode(Int.self, forKey: .bpm)
        totalBeats = try values.decode(Int.self, forKey: .totalBeats)
        offsets = try values.decode([Int: TimeInterval].self, forKey: .offsets)
        exercise = try values.decodeIfPresent(RhythmExercise.self, forKey: .exercise) ?? .pulse
        unexpectedTapCount = try values.decodeIfPresent(Int.self, forKey: .unexpectedTapCount) ?? 0
    }

    var tapCount: Int { offsets.count }
    var isScored: Bool { isValid && tapCount >= 3 }
    var beatsGoal: Bool {
        isScored && tapCount >= exercise.coverageTarget
            && (exercise != .mixedRhythm || unexpectedTapCount <= 1)
    }
    var timingGoal: Bool { isScored && onTimeFraction >= 0.75 }
    var evennessGoal: Bool { isScored && (spreadMilliseconds ?? .infinity) <= Self.evennessLimitMilliseconds + 1e-6 }
    var starCount: Int? {
        guard isScored else { return nil }
        return [beatsGoal, timingGoal, evennessGoal].filter { $0 }.count
    }

    var onTimeFraction: Double {
        guard !offsets.isEmpty else { return 0 }
        return Double(offsets.values.filter { abs($0) <= Self.timingTolerance + 1e-9 }.count) / Double(tapCount)
    }

    /// The middle 80% reduces the influence of one stray tap while detecting drift.
    var spreadMilliseconds: Double? {
        let sorted = offsets.values.sorted()
        guard tapCount >= 3, let upper = RhythmStatistics.percentile(0.9, in: sorted),
              let lower = RhythmStatistics.percentile(0.1, in: sorted) else { return nil }
        return (upper - lower) * 1_000
    }

    var medianDistanceMilliseconds: Double? { median(offsets.values.map { abs($0) * 1_000 }) }
    var medianOffsetMilliseconds: Double? { median(offsets.values.map { $0 * 1_000 }) }

    var cue: String {
        guard isScored else { return "Tap along at least three times to get a score." }
        if exercise == .mixedRhythm && unexpectedTapCount > 1 {
            return "Tap once on odd numbers and twice on even numbers. Leave the space after 1, 3, 5 and 7."
        }
        if !beatsGoal { return "Keep tapping through more of the round." }
        if !timingGoal {
            return (medianOffsetMilliseconds ?? 0) < 0
                ? "Let the pulse arrive before you tap."
                : "Try landing your tap a little earlier, with the pulse."
        }
        if !evennessGoal {
            return exercise == .mixedRhythm ? "Keep the beat steady as you switch between one tap and two."
                : "Keep the same space between each tap."
        }
        return "Your taps stayed close to the pulse. Keep that easy rhythm."
    }

    fileprivate var isValid: Bool {
        version == Self.scoringVersion && bpm == 60 && totalBeats == exercise.tapCount &&
        unexpectedTapCount >= 0 && (exercise == .mixedRhythm || unexpectedTapCount == 0) &&
        createdAt.timeIntervalSince1970.isFinite && offsets.allSatisfy {
            (0..<totalBeats).contains($0.key) && $0.value.isFinite &&
            abs($0.value) <= exercise.tapWindow + 1e-9
        }
    }

    private func median(_ values: [Double]) -> Double? {
        values.count >= 3 ? RhythmStatistics.percentile(0.5, in: values.sorted()) : nil
    }
}

@MainActor
final class PulsePracticeStore: ObservableObject {
    let exercise: RhythmExercise
    @Published private(set) var attempts: [PulseAttempt] = []
    @Published private(set) var errorMessage: String?

    private let fileURL: URL
    private var completed = false
    private var fileIsUnreadable = false

    init(directory: URL? = nil, exercise: RhythmExercise = .pulse) {
        self.exercise = exercise
        let directory = directory ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        fileURL = directory.appendingPathComponent(exercise.fileName)
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            let document = try JSONDecoder().decode(Document.self, from: Data(contentsOf: fileURL))
            guard document.schemaVersion == 1,
                  document.attempts.allSatisfy({ $0.isValid && $0.exercise == exercise }),
                  Set(document.attempts.map(\.id)).count == document.attempts.count else {
                throw StorageError.invalidHistory
            }
            attempts = document.attempts
            completed = document.completed || Self.hasEarnedCompletion(in: attempts)
        } catch {
            fileIsUnreadable = true
            errorMessage = "Saved rhythm progress could not be read. Its file has been preserved."
        }
    }

    var bestStars: Int? { attempts.compactMap(\.starCount).max() }
    var latestStars: Int? { attempts.first?.starCount }
    var progress: PracticeProgress {
        let successes = CompletionRule.recentSuccesses(attempts.lazy.filter(\.isScored).map { $0.starCount == 3 })
        return PracticeProgress(successfulAttempts: completed ? CompletionRule.requiredSuccesses : successes,
                                completed: completed)
    }

    /// Called at the real end of a round. Stopping early cannot create an attempt.
    /// The round ID also makes a repeated finish callback harmless.
    @discardableResult
    func record(timing: PulseTiming, at time: TimeInterval = ProcessInfo.processInfo.systemUptime,
                id: UUID = UUID()) -> PulseAttempt? {
        guard timing.exercise == exercise else { return nil }
        if let existing = attempts.first(where: { $0.id == id }) { return existing }
        guard let attempt = PulseAttempt(timing: timing, finishedAt: time, id: id) else { return nil }
        guard !fileIsUnreadable else { return attempt }
        let updated = [attempt] + attempts
        let earned = completed || Self.hasEarnedCompletion(in: updated)
        do {
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(),
                                                    withIntermediateDirectories: true)
            let document = Document(schemaVersion: 1, attempts: updated, completed: earned)
            try JSONEncoder().encode(document).write(to: fileURL, options: .atomic)
            attempts = updated
            completed = earned
            errorMessage = nil
        } catch {
            errorMessage = "This rhythm result could not be saved. Please try again."
        }
        return attempt
    }

    /// Attempts are stored newest first; the rule replays them in recorded order.
    private static func hasEarnedCompletion(in attempts: [PulseAttempt]) -> Bool {
        !CompletionRule.earnedKeys(attempts.reversed().lazy.filter(\.isScored)
            .map { (key: 0, success: $0.starCount == 3) }).isEmpty
    }

    private struct Document: Codable {
        let schemaVersion: Int
        let attempts: [PulseAttempt]
        let completed: Bool
    }

    private enum StorageError: Error { case invalidHistory }
}
