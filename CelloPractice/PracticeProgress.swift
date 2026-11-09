import Foundation

/// Earned completion survives later takes. Navigation belongs to the lesson catalogue.
struct PracticeProgress {
    let successfulAttempts: Int
    let requiredAttempts = 3
    let completed: Bool
}

/// Stores earned milestones only; recent attempts are read from durable sessions.
struct PracticeProgressLedger: Codable {
    let schemaVersion: Int
    private(set) var completedKeys: Set<String>

    init(schemaVersion: Int = 1, completedKeys: Set<String> = []) {
        self.schemaVersion = schemaVersion
        self.completedKeys = completedKeys
    }

    func progress(for exercise: Exercise, targetFrequency: Double,
                  sessions: [PracticeSession]) -> PracticeProgress {
        guard let key = Self.key(exercise: exercise, targetFrequency: targetFrequency) else {
            return PracticeProgress(successfulAttempts: 0, completed: false)
        }
        let recent = sessions.filter { Self.eligibleKey(for: $0) == key }
            .sorted(by: Self.newestFirst).prefix(5)
        let successes = recent.filter { $0.rating?.goalReached == true }.count
        let completed = completedKeys.contains(key) || successes >= 3
        return PracticeProgress(successfulAttempts: completed ? 3 : successes,
                                completed: completed)
    }

    /// Rebuilds every historical five-attempt window, including a milestone whose
    /// file write was interrupted before newer attempts were saved.
    @discardableResult
    mutating func update(from sessions: [PracticeSession]) -> Bool {
        var windows: [String: [Bool]] = [:]
        var changed = false
        for session in sessions.sorted(by: { Self.newestFirst($1, $0) }) {
            guard let key = Self.eligibleKey(for: session) else { continue }
            var window = windows[key, default: []]
            window.append(session.rating?.goalReached == true)
            if window.count > 5 { window.removeFirst() }
            windows[key] = window
            if window.filter({ $0 }).count >= 3, completedKeys.insert(key).inserted {
                changed = true
            }
        }
        return changed
    }

    private static func key(exercise: Exercise, targetFrequency: Double) -> String? {
        guard exercise.section != nil, targetFrequency.isFinite, targetFrequency > 0 else { return nil }
        // Codable round-trips this exact reference. Different targets and scoring
        // versions must never silently contribute to the same achievement.
        return "v\(PracticeRating.currentVersion)|\(exercise.rawValue)|\(String(targetFrequency.bitPattern, radix: 16))"
    }

    private static func eligibleKey(for session: PracticeSession) -> String? {
        guard let rating = session.rating, rating.status == .rated,
              rating.version == PracticeRating.currentVersion,
              let target = session.effectiveTargetFrequency,
              rating.targetFrequency == target else { return nil }
        return key(exercise: session.exercise, targetFrequency: target)
    }

    private static func newestFirst(_ lhs: PracticeSession, _ rhs: PracticeSession) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString > rhs.id.uuidString
    }

}
