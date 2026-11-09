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

struct PracticeProgressView: View {
    let progress: PracticeProgress
    var nextLesson: PracticeLesson? = nil
    var onNext: ((PracticeLesson) -> Void)? = nil
    var disabled = false
    var attemptNoun = "takes"

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 4) {
                ForEach(0..<progress.requiredAttempts, id: \.self) { index in
                    Circle().fill(index < progress.successfulAttempts ? Palette.forest : Palette.forest.opacity(0.13))
                        .frame(width: 5, height: 5)
                }
            }.accessibilityHidden(true)
            Text(progress.completed ? "Goal reached" : "\(progress.successfulAttempts) of 3 successful \(attemptNoun)")
                .font(.caption.weight(.medium))
                .foregroundStyle(progress.completed ? Palette.forest : Palette.muted)
                .accessibilityIdentifier("practiceProgressText")
            Spacer(minLength: 0)
            if let next = nextLesson, let onNext {
                Button { onNext(next) } label: {
                    HStack(spacing: 5) {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text("\(progress.completed ? "Continue to" : "Try") lesson \(next.number)")
                                .font(.caption2)
                            Text(next.title).font(.caption.weight(.semibold))
                        }
                        Image(systemName: "arrow.right")
                    }.font(.caption.weight(.semibold)).frame(minHeight: 44)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(Palette.forest)
                    .disabled(disabled).opacity(disabled ? 0.45 : 1)
                    .accessibilityLabel("\(progress.completed ? "Continue to" : "Try") Lesson \(next.number), \(next.title)")
                    .accessibilityIdentifier("nextExerciseButton")
            }
        }.frame(minHeight: 44).padding(.horizontal, 2)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("practiceProgressCard")
    }
}
