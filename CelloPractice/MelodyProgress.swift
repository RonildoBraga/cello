import CryptoKit
import Foundation

/// Melody achievements never inherit a foundation score or another reference.
struct MelodyProgressLedger: Codable {
    let schemaVersion: Int
    private(set) var completedKeys: Set<String>

    init(schemaVersion: Int = 1, completedKeys: Set<String> = []) {
        self.schemaVersion = schemaVersion
        self.completedKeys = completedKeys
    }

    func progress(for context: MelodyPracticeContext, sessions: [PracticeSession]) -> PracticeProgress {
        guard let key = Self.key(for: context) else {
            return PracticeProgress(successfulAttempts: 0, completed: false)
        }
        let recent = sessions.filter { Self.eligibleKey(for: $0) == key }
            .sorted(by: Self.newestFirst).prefix(5)
        let successes = recent.filter { $0.melodyRating?.goalReached == true }.count
        let completed = completedKeys.contains(key) || successes >= 3
        return PracticeProgress(successfulAttempts: completed ? 3 : successes, completed: completed)
    }

    /// Replay all historical windows so an interrupted ledger write is recoverable.
    @discardableResult
    mutating func update(from sessions: [PracticeSession]) -> Bool {
        var windows: [String: [Bool]] = [:]
        var changed = false
        for session in sessions.sorted(by: { Self.newestFirst($1, $0) }) {
            guard let key = Self.eligibleKey(for: session) else { continue }
            var window = windows[key, default: []]
            window.append(session.melodyRating?.goalReached == true)
            if window.count > 5 { window.removeFirst() }
            windows[key] = window
            if window.filter({ $0 }).count >= 3, completedKeys.insert(key).inserted { changed = true }
        }
        return changed
    }

    private static func key(for context: MelodyPracticeContext) -> String? {
        guard context.isValid, context.gradingVersion == MelodyRating.currentVersion,
              !EchoLevel.allCases.contains(where: { $0.pieceID == context.pieceID }) else { return nil }
        // Hash the complete frozen score selection, including events and tuning,
        // rather than just its display labels. Sorted keys make reloads stable.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(context) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func eligibleKey(for session: PracticeSession) -> String? {
        guard let context = session.melodyContext, let rating = session.melodyRating,
              rating.status == .rated, rating.version == context.gradingVersion,
              session.rating == nil else { return nil }
        return key(for: context)
    }

    private static func newestFirst(_ lhs: PracticeSession, _ rhs: PracticeSession) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString > rhs.id.uuidString
    }
}
