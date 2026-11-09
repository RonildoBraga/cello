import SwiftUI

struct PracticeGoal {
    let title: String
    let earned: Bool
    let identifier: String
}

struct PracticeResultIdentifiers {
    var stars = "ratingStarCount"
    var unscored = "ratingUnclear"
    var feedback = "ratingFeedback"
}

/// Shared presentation only. Each exercise supplies its own measured goals.
struct PracticeResultCard: View {
    let starCount: Int?
    let goals: [PracticeGoal]
    let feedback: String
    let starRules: [String]
    var title = "THIS TAKE"
    var unscoredLabel = "Couldn’t rate this take"
    var unscoredSystemImage = "waveform"
    var identifiers = PracticeResultIdentifiers()
    var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            if let starCount {
                HStack(alignment: .firstTextBaseline) {
                    Text(title).font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.5).foregroundStyle(Palette.muted)
                    Spacer()
                    Text("\(starCount) of 3 stars").font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.forest).accessibilityIdentifier(identifiers.stars)
                }
                HStack(spacing: 12) {
                    ForEach(goals.indices, id: \.self) { goal(goals[$0]) }
                }.padding(.vertical, 2)
            } else {
                Label(unscoredLabel, systemImage: unscoredSystemImage)
                    .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.forest)
                    .accessibilityIdentifier(identifiers.unscored)
            }
            Text(feedback).font(.subheadline).foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true).accessibilityIdentifier(identifiers.feedback)
            if starCount == nil { Text("Progress unchanged").font(.caption).foregroundStyle(Palette.muted) }
            DisclosureGroup("How stars work") {
                VStack(alignment: .leading, spacing: 9) {
                    ForEach(starRules.indices, id: \.self) { Text(starRules[$0]) }
                }.font(.caption).foregroundStyle(Palette.muted).padding(.top, 9)
            }.font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
            if let errorMessage { Text(errorMessage).font(.caption).foregroundStyle(.red) }
        }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 20))
            .overlay {
                RoundedRectangle(cornerRadius: 20).strokeBorder(Palette.forest.opacity(0.06), lineWidth: 1)
                    .allowsHitTesting(false)
            }.accessibilityElement(children: .contain)
    }

    private func goal(_ goal: PracticeGoal) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 7) {
                star(goal.earned)
                Text(goal.title).font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
            }.fixedSize()
            VStack(spacing: 6) {
                star(goal.earned)
                Text(goal.title).font(.caption.weight(.medium)).foregroundStyle(Palette.forest)
            }
        }.frame(maxWidth: .infinity, minHeight: 30)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(goal.title): \(goal.earned ? "goal reached" : "keep practising")")
            .accessibilityIdentifier(goal.identifier)
    }

    private func star(_ earned: Bool) -> some View {
        Image(systemName: earned ? "star.fill" : "star").font(.system(size: 19, weight: .medium))
            .foregroundStyle(earned ? Palette.gold : Palette.muted.opacity(0.4))
    }
}
