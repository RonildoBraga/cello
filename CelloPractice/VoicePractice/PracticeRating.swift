import Foundation

/// A versioned practice result. Unclear audio never becomes a failed attempt.
struct PracticeRating: Codable, Equatable, Sendable {
    /// Version 2 hears a cello note in any octave, because a cello's overtone can sound
    /// louder than its note, and counts as sound only what stands clear of the room the
    /// microphone heard before the take. Earlier takes keep the scores they were given.
    static let currentVersion = 2
    /// Progress belongs to the lesson, not to the rules of the day. Takes scored under these
    /// versions count towards the same passes and gold, kept under the key version 1 wrote.
    static let progressVersions = 1...2

    enum Status: String, Codable, Sendable {
        case rated, unclear, insufficientSound
    }

    let version: Int
    let targetFrequency: Double
    let status: Status
    let match: Bool
    let steady: Bool
    let hold: Bool
    let voicedDuration: Double
    let longestHold: Double
    let nearTargetFraction: Double?
    let settledSpreadCents: Double?

    init(version: Int = currentVersion, targetFrequency: Double, status: Status,
         match: Bool = false, steady: Bool = false, hold: Bool = false,
         voicedDuration: Double = 0, longestHold: Double = 0,
         nearTargetFraction: Double? = nil, settledSpreadCents: Double? = nil) {
        self.version = version
        self.targetFrequency = targetFrequency
        self.status = status
        self.match = match
        self.steady = steady
        self.hold = hold
        self.voicedDuration = voicedDuration
        self.longestHold = longestHold
        self.nearTargetFraction = nearTargetFraction
        self.settledSpreadCents = settledSpreadCents
    }

    var starCount: Int? {
        guard status == .rated else { return nil }
        return [match, steady, hold].filter { $0 }.count
    }

    var goalReached: Bool { starCount == 3 }

    var feedback: String {
        switch status {
        case .insufficientSound:
            return "Hold one gentle note a little longer."
        case .unclear:
            return "The pitch wasn’t clear enough to rate. Try again with one clear note."
        case .rated:
            if goalReached { return "Matched, steady and held. All three goals reached." }
            if !hold { return "Keep the note going gently for two seconds." }
            if !match { return "Listen again and aim closer to the target." }
            return "Keep one gentle note as even as you can."
        }
    }
}
