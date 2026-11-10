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

/// The suggested step after this activity: the next lesson, phrase or pattern.
/// It is a suggestion only; every activity stays available.
struct NextStep {
    /// "Try" before the current goal is reached, "Continue to" after.
    let caption: String
    let title: String
    let spokenLabel: String
    let identifier: String
    let action: () -> Void

    static func lesson(_ lesson: PracticeLesson, completed: Bool, action: @escaping () -> Void) -> NextStep {
        let verb = completed ? "Continue to" : "Try"
        return NextStep(caption: "\(verb) lesson \(lesson.number)", title: lesson.title,
                        spokenLabel: "\(verb) Lesson \(lesson.number), \(lesson.title)",
                        identifier: "nextExerciseButton", action: action)
    }

    static func item(_ title: String, completed: Bool, identifier: String, action: @escaping () -> Void) -> NextStep {
        let verb = completed ? "Continue to" : "Try"
        return NextStep(caption: verb, title: title, spokenLabel: "\(verb) \(title)",
                        identifier: identifier, action: action)
    }
}

/// Progress towards this activity's goal, with the suggested next step beside it.
struct PracticeProgressView: View {
    let progress: PracticeProgress
    var next: NextStep? = nil
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
            Text(progress.completed ? "Gold · Goal reached"
                 : progress.passed ? "Passed · \(progress.successfulAttempts) of 3 for gold"
                 : "\(progress.successfulAttempts) of 3 successful \(attemptNoun)")
                .font(.caption.weight(.medium))
                .foregroundStyle(progress.completed ? Palette.forest : Palette.muted)
                .accessibilityIdentifier("practiceProgressText")
            Spacer(minLength: 0)
            if let next {
                Button(action: next.action) {
                    HStack(spacing: 5) {
                        VStack(alignment: .trailing, spacing: 3) {
                            Text(next.caption).font(.caption2)
                            Text(next.title).font(.caption.weight(.semibold))
                        }
                        Image(systemName: "arrow.right")
                    }.font(.caption.weight(.semibold)).frame(minHeight: 44)
                        .contentShape(Rectangle())
                }.buttonStyle(.plain).foregroundStyle(Palette.forest)
                    .disabled(disabled).opacity(disabled ? 0.45 : 1)
                    .accessibilityLabel(next.spokenLabel)
                    .accessibilityIdentifier(next.identifier)
            }
        }.frame(minHeight: 44).padding(.horizontal, 2)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier("practiceProgressCard")
    }
}
