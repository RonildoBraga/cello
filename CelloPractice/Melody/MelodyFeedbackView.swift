import SwiftUI

struct MelodyFeedbackView: View {
    let rating: MelodyRating
    /// What to say about the take, worked out when it was saved or opened.
    let feedback: String
    var isEcho = false

    var body: some View {
        PracticeResultCard(starCount: rating.starCount, goals: [
            PracticeGoal(title: "Notes", earned: rating.notes, identifier: "melodyGoal-notes"),
            PracticeGoal(title: "Timing", earned: rating.timing, identifier: "melodyGoal-timing"),
            PracticeGoal(title: "Clarity", earned: rating.clarity, identifier: "melodyGoal-clarity")
        ], feedback: feedback, starRules: [
            isEcho ? "Notes · Repeat the pattern’s pitches in the same voice register." : "Notes · Match the phrase’s notes in their original register.",
            isEcho ? "Timing · Match the pattern’s note starts and lengths, including repeated notes." : "Timing · Begin each note near its place in the phrase, including repeated notes.",
            "Clarity · Give each note enough clear sound to hear its pitch."
        ], unscoredLabel: rating.status == .insufficientSound ? "Not enough sound to rate" : "Pitch wasn’t clear enough to rate",
                           identifiers: PracticeResultIdentifiers(stars: "melodyRatingStars",
                                                                  unscored: "melodyRatingUnclear",
                                                                  feedback: "melodyFeedback"))
    }
}
