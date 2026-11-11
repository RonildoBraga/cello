import SwiftUI
import UIKit

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
    var title = "This take"
    var unscoredLabel = "Couldn’t rate this take"
    var unscoredSystemImage = "waveform"
    var identifiers = PracticeResultIdentifiers()
    var errorMessage: String?
    @Environment(\.celebratesResults) private var celebrates
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// How many goal stars have appeared; fresh results reveal them one by one.
    @State private var revealed = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            if let starCount {
                HStack(alignment: .firstTextBaseline) {
                    Eyebrow(text: title)
                    Spacer()
                    Text("\(starCount) of 3 stars").font(.subheadline.weight(.semibold))
                        .foregroundStyle(Palette.forest).accessibilityIdentifier(identifiers.stars)
                }
                ViewThatFits(in: .horizontal) {
                    goalsRow(stacked: false).fixedSize()
                    goalsRow(stacked: true)
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
        }.card().accessibilityElement(children: .contain)
            .onAppear(perform: revealStars)
    }

    /// A fresh result pops its stars in, with a success tap for all three.
    private func revealStars() {
        guard celebrates, !reduceMotion, starCount != nil else { revealed = goals.count; return }
        for index in goals.indices {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.5).delay(0.2 + Double(index) * 0.22)) {
                revealed = index + 1
            }
        }
        if starCount == CompletionRule.goldStars {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2 + Double(goals.count) * 0.22) {
                UINotificationFeedbackGenerator().notificationOccurred(.success)
            }
        }
    }

    private func goalsRow(stacked: Bool) -> some View {
        HStack(spacing: 12) {
            ForEach(goals.indices, id: \.self) { goal(goals[$0], stacked: stacked, shown: revealed > $0) }
        }
    }

    private func goal(_ goal: PracticeGoal, stacked: Bool, shown: Bool) -> some View {
        Group {
            if stacked {
                VStack(spacing: 6) {
                    star(goal.earned, shown: shown)
                    Text(goal.title).font(.caption.weight(.medium)).foregroundStyle(Palette.forest)
                }
            } else {
                HStack(spacing: 7) {
                    star(goal.earned, shown: shown)
                    Text(goal.title).font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
                }
            }
        }.frame(maxWidth: .infinity, minHeight: 30)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(goal.title): \(goal.earned ? "goal reached" : "keep practising")")
            .accessibilityIdentifier(goal.identifier)
    }

    private func star(_ earned: Bool, shown: Bool) -> some View {
        Image(systemName: earned ? "star.fill" : "star").font(.title3.weight(.medium))
            .foregroundStyle(earned ? Palette.gold : Palette.muted.opacity(0.4))
            .scaleEffect(shown || !earned ? 1 : 0.2).opacity(shown || !earned ? 1 : 0)
    }
}
