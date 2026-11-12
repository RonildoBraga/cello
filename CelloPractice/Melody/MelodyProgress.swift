import CelloPitch
import CryptoKit
import Foundation

/// Melody achievements never inherit a foundation score or another reference.
struct MelodyProgressLedger: SessionProgressLedger {
    let schemaVersion: Int
    var completedKeys: Set<String>
    var passedKeys: Set<String>?

    init(schemaVersion: Int = 1, completedKeys: Set<String> = []) {
        self.schemaVersion = schemaVersion
        self.completedKeys = completedKeys
    }

    static func key(for context: MelodyPracticeContext) -> String? {
        guard context.isValid, context.gradingVersion.map(MelodyRating.progressVersions.contains) == true,
              !EchoLevel.allCases.contains(where: { $0.pieceID == context.pieceID }) else { return nil }
        // Hash the complete frozen score selection, including events and tuning,
        // rather than just its display labels. Sorted keys make reloads stable.
        // The scoring version is hashed as the first that counts, so a pass earned
        // under earlier rules is still this lesson's pass.
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(context.graded(by: MelodyRating.progressVersions.lowerBound)) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    static func eligibleKey(for session: PracticeSession) -> String? {
        guard let context = session.melodyContext, let rating = session.melodyRating,
              rating.status == .rated, rating.version == context.gradingVersion,
              session.rating == nil else { return nil }
        return key(for: context)
    }

    static func starCount(for session: PracticeSession) -> Int? { session.melodyRating?.starCount }
}
