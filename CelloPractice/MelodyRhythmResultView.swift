import SwiftUI

struct MelodyRhythmResultView: View {
    let attempt: MelodyRhythmAttempt
    var errorMessage: String? = nil

    var body: some View {
        PracticeResultCard(starCount: attempt.starCount, goals: [
            PracticeGoal(title: "Pattern", earned: attempt.patternGoal, identifier: "melodyRhythmPattern"),
            PracticeGoal(title: "Timing", earned: attempt.timingGoal, identifier: "melodyRhythmTiming"),
            PracticeGoal(title: "Consistency", earned: attempt.consistencyGoal, identifier: "melodyRhythmConsistency")
        ], feedback: attempt.cue, starRules: [
            "Pattern · Tap at least \(Int(ceil(Double(attempt.expectedTapCount) * 0.8))) of the \(attempt.expectedTapCount) note starts, with no extra taps.",
            "Timing · Land within 150 ms of the expected start for at least 75% of your matched taps.",
            "Consistency · Keep the middle 80% of your tap offsets within a 200 ms range, following the pattern’s long and short notes."
        ], title: "THIS ROUND", unscoredLabel: "Not enough taps to rate", unscoredSystemImage: "hand.tap",
           identifiers: PracticeResultIdentifiers(stars: "melodyRhythmStars", unscored: "melodyRhythmUnscored",
                                                  feedback: "melodyRhythmFeedback"),
           errorMessage: errorMessage)
    }
}
