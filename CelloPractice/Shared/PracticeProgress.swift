import Foundation

/// Two tiers. `passed` moves the path on: one decent attempt. `completed` is
/// gold: the earned milestone, which survives later takes.
struct PracticeProgress: Equatable {
    let successfulAttempts: Int
    let requiredAttempts = CompletionRule.requiredSuccesses
    let completed: Bool
    let passed: Bool

    /// Gold always counts as passed, even if its takes were later deleted.
    init(successfulAttempts: Int, completed: Bool, passed: Bool = false) {
        self.successfulAttempts = successfulAttempts
        self.completed = completed
        self.passed = passed || completed
    }

    /// Applies both tiers to one activity's scored attempts, newest first.
    init(stars newestFirst: [Int], alreadyCompleted: Bool = false) {
        let successes = CompletionRule.recentSuccesses(newestFirst.map { $0 == CompletionRule.goldStars })
        let completed = alreadyCompleted || successes >= CompletionRule.requiredSuccesses
        self.init(successfulAttempts: completed ? CompletionRule.requiredSuccesses : successes,
                  completed: completed, passed: CompletionRule.passed(newestFirst))
    }
}

/// The one definition of both tiers. Passed: any scored attempt with two stars
/// or more. Gold ("earned"): three 3-star attempts among five consecutive
/// scored attempts. Every activity counts its own attempts and applies these.
enum CompletionRule {
    static let requiredSuccesses = 3
    static let window = 5
    static let goldStars = 3
    static let passingStars = 2

    /// True when any scored attempt reached the passing score.
    static func passed(_ stars: some Sequence<Int>) -> Bool {
        stars.contains { $0 >= passingStars }
    }

    /// Successes among the most recent scored attempts, given newest first.
    static func recentSuccesses(_ newestFirst: some Sequence<Bool>) -> Int {
        newestFirst.prefix(window).filter { $0 }.count
    }

    /// Replays every historical window, given oldest first, so a later miss or an
    /// interrupted write cannot erase a real achievement.
    static func earnedKeys<Key: Hashable>(_ oldestFirst: some Sequence<(key: Key, success: Bool)>) -> Set<Key> {
        var windows: [Key: [Bool]] = [:]
        var earned: Set<Key> = []
        for attempt in oldestFirst {
            var recent = windows[attempt.key, default: []]
            recent.append(attempt.success)
            if recent.count > window { recent.removeFirst() }
            windows[attempt.key] = recent
            if recent.filter({ $0 }).count >= requiredSuccesses { earned.insert(attempt.key) }
        }
        return earned
    }
}

/// A ledger stores earned milestones only; recent attempts are read from durable
/// sessions. Each activity decides which sessions count and under which key.
protocol SessionProgressLedger: Codable {
    var schemaVersion: Int { get }
    var completedKeys: Set<String> { get set }
    /// The achievement a rated session counts towards, or nil when it counts for none.
    static func eligibleKey(for session: PracticeSession) -> String?
    /// The stars an eligible session earned.
    static func starCount(for session: PracticeSession) -> Int?
}

extension SessionProgressLedger {
    static func succeeded(_ session: PracticeSession) -> Bool { starCount(for: session) == CompletionRule.goldStars }

    func progress(forKey key: String?, sessions: [PracticeSession]) -> PracticeProgress {
        guard let key else { return PracticeProgress(successfulAttempts: 0, completed: false) }
        let recent = sessions.filter { Self.eligibleKey(for: $0) == key }.sorted(by: Self.newestFirst)
        return PracticeProgress(stars: recent.map { Self.starCount(for: $0) ?? 0 },
                                alreadyCompleted: completedKeys.contains(key))
    }

    /// Returns true when a milestone was added and the ledger needs saving.
    @discardableResult
    mutating func update(from sessions: [PracticeSession]) -> Bool {
        let attempts = sessions.sorted { Self.newestFirst($1, $0) }.compactMap { session in
            Self.eligibleKey(for: session).map { (key: $0, success: Self.succeeded(session)) }
        }
        let known = completedKeys.count
        completedKeys.formUnion(CompletionRule.earnedKeys(attempts))
        return completedKeys.count != known
    }

    private static func newestFirst(_ lhs: PracticeSession, _ rhs: PracticeSession) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString > rhs.id.uuidString
    }
}

/// Fixed-note foundation lessons, keyed by exercise, exact target and rating version.
struct PracticeProgressLedger: SessionProgressLedger {
    let schemaVersion: Int
    var completedKeys: Set<String>

    init(schemaVersion: Int = 1, completedKeys: Set<String> = []) {
        self.schemaVersion = schemaVersion
        self.completedKeys = completedKeys
    }

    func progress(for exercise: Exercise, targetFrequency: Double,
                  sessions: [PracticeSession]) -> PracticeProgress {
        progress(forKey: Self.key(exercise: exercise, targetFrequency: targetFrequency), sessions: sessions)
    }

    private static func key(exercise: Exercise, targetFrequency: Double) -> String? {
        guard exercise.section != nil, targetFrequency.isFinite, targetFrequency > 0 else { return nil }
        // Codable round-trips this exact reference. Different targets and scoring
        // versions must never silently contribute to the same achievement.
        return "v\(PracticeRating.currentVersion)|\(exercise.rawValue)|\(String(targetFrequency.bitPattern, radix: 16))"
    }

    static func eligibleKey(for session: PracticeSession) -> String? {
        guard let rating = session.rating, rating.status == .rated,
              rating.version == PracticeRating.currentVersion,
              let target = session.effectiveTargetFrequency,
              rating.targetFrequency == target else { return nil }
        return key(exercise: session.exercise, targetFrequency: target)
    }

    static func starCount(for session: PracticeSession) -> Int? { session.rating?.starCount }
}
