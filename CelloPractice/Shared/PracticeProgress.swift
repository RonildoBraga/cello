import Foundation

/// Two tiers. `passed` moves the path on: one decent attempt. `completed` is
/// gold. Both are earned milestones: they survive later takes and deleted ones.
struct PracticeProgress: Equatable {
    let successfulAttempts: Int
    let requiredAttempts = CompletionRule.requiredSuccesses
    let completed: Bool
    let passed: Bool
    /// The best saved score; three once gold is earned, nil before any score.
    let bestStars: Int?

    /// Gold always counts as passed, even if its takes were later deleted.
    init(successfulAttempts: Int, completed: Bool, passed: Bool = false, bestStars: Int? = nil) {
        self.successfulAttempts = successfulAttempts
        self.completed = completed
        self.passed = passed || completed
        self.bestStars = completed ? CompletionRule.goldStars : bestStars
    }

    /// Applies both tiers to one activity's scored attempts, newest first.
    init(stars newestFirst: [Int], alreadyCompleted: Bool = false, alreadyPassed: Bool = false) {
        let successes = CompletionRule.recentSuccesses(newestFirst.map { $0 == CompletionRule.goldStars })
        let completed = alreadyCompleted || successes >= CompletionRule.requiredSuccesses
        // A pass whose takes were deleted still shows the score that earned it.
        self.init(successfulAttempts: completed ? CompletionRule.requiredSuccesses : successes,
                  completed: completed, passed: alreadyPassed || CompletionRule.passed(newestFirst),
                  bestStars: (newestFirst + (alreadyPassed ? [CompletionRule.passingStars] : [])).max())
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
    /// Passes, kept so that deleting recordings to free space keeps them. Files
    /// written before passes were kept have no such field and read as nil.
    var passedKeys: Set<String>? { get set }
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
                                alreadyCompleted: completedKeys.contains(key),
                                alreadyPassed: passedKeys?.contains(key) ?? false)
    }

    /// Returns true when a milestone was added and the ledger needs saving.
    @discardableResult
    mutating func update(from sessions: [PracticeSession]) -> Bool {
        let attempts = sessions.sorted { Self.newestFirst($1, $0) }.compactMap { session in
            Self.eligibleKey(for: session).map { (key: $0, success: Self.succeeded(session)) }
        }
        let passes = Set(sessions.compactMap { session in
            (Self.starCount(for: session) ?? 0) >= CompletionRule.passingStars ? Self.eligibleKey(for: session) : nil
        })
        let known = completedKeys.count + (passedKeys?.count ?? 0)
        completedKeys.formUnion(CompletionRule.earnedKeys(attempts))
        if !passes.isSubset(of: passedKeys ?? []) { passedKeys = (passedKeys ?? []).union(passes) }
        return completedKeys.count + (passedKeys?.count ?? 0) != known
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
    var passedKeys: Set<String>?

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
