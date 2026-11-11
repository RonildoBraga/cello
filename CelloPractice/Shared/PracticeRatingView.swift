import SwiftUI

struct PracticeRatingView: View {
    let rating: PracticeRating

    var body: some View {
        PracticeResultCard(starCount: rating.starCount, goals: [
            PracticeGoal(title: "Match", earned: rating.match, identifier: "ratingMatch"),
            PracticeGoal(title: "Steady", earned: rating.steady, identifier: "ratingSteady"),
            PracticeGoal(title: "Hold", earned: rating.hold, identifier: "ratingHold")
        ], feedback: rating.goalReached ? "All three goals reached." : rating.feedback, starRules: [
            "Match · Stay within 25 cents of the target for 80% of the clear sound.",
            "Steady · Keep pitch variation within 40 cents after the opening settles.",
            "Hold · Sustain the note for at least two seconds."
        ])
    }
}

/// Progress towards this activity's two results, in words.
struct PracticeProgressView: View {
    let progress: PracticeProgress
    var attemptNoun = "takes"

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<progress.requiredAttempts, id: \.self) { index in
                    Circle().fill(index < progress.successfulAttempts ? Palette.forest : Palette.forest.opacity(0.13))
                        .frame(width: 5, height: 5)
                }
            }.accessibilityHidden(true)
            Text(progress.completed ? "Gold · Goal reached"
                 : "\(progress.passed ? "Passed" : "Not passed yet") · Gold: \(progress.successfulAttempts) of 3 three-star \(attemptNoun)")
                .fixedSize(horizontal: false, vertical: true)
                .font(.caption.weight(.medium))
                .foregroundStyle(progress.completed ? Palette.forest : Palette.muted)
                .accessibilityIdentifier("practiceProgressText")
            Spacer(minLength: 0)
        }.frame(minHeight: 44).padding(.horizontal, 2)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("practiceProgressCard")
    }
}
