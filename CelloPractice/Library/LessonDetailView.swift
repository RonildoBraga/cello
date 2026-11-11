import SwiftUI

/// A foundation lesson's own page: what it is for, how far it has got and how to practise it.
@MainActor
struct LessonDetailView: View {
    let lesson: PracticeLesson
    @ObservedObject var store: SessionStore
    @ObservedObject var rhythmStores: RhythmStores
    let onStartLesson: (PracticeLesson) -> Void

    private var state: LessonState { LessonState(lesson: lesson, store: store, rhythmStores: rhythmStores) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                ScreenHeader(eyebrow: Level.position(of: .lesson(lesson)).map { "Level \($0.level.number) · \($0.label)" },
                             title: lesson.title, subtitle: lesson.purpose, titleIdentifier: "lessonDetailTitle")

                if let primer = lesson.primer {
                    NavigationLink(value: MusicRoute.primer(lesson)) {
                        Label("New to this? \(primer.title)", systemImage: "lightbulb")
                    }.buttonStyle(SecondaryActionButtonStyle()).accessibilityIdentifier("lessonPrimerLink")
                }
                progressCard
                recentRounds

                VStack(alignment: .leading, spacing: 15) {
                    SectionTitle("How to practise")
                    ForEach(Array(lesson.instructions.enumerated()), id: \.offset) { index, instruction in
                        NumberedStep(number: index + 1, detail: instruction)
                    }
                }.accessibilityElement(children: .contain)
                    .accessibilityIdentifier("lessonInstruction")

                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Three small goals")
                    ForEach(Array(lesson.goals.enumerated()), id: \.offset) { _, item in
                        goal(item.title, detail: item.detail)
                    }
                }
            }.screenContent()
        }.background(Palette.paper)
            .screenTitle(lesson.title)
            .bottomActionBar {
                Button(state.hasAttempts ? "Practise again" : "Start lesson") { onStartLesson(lesson) }
                    .buttonStyle(PrimaryActionButtonStyle())
                    .accessibilityIdentifier("startLessonButton")
            }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                TierLabel(progress: state.step, text: state.step.status,
                          goldIdentifier: "lessonCompletion-\(lesson.id)")
                Spacer(minLength: 5)
                Text("Gold: \(state.progress.successfulAttempts) of \(state.progress.requiredAttempts)")
                    .font(.caption).foregroundStyle(Palette.muted)
            }.font(.subheadline.weight(.semibold))

            HStack(alignment: .top, spacing: 24) {
                score("Best score", stars: state.bestStars)
                    .accessibilityIdentifier("lessonBestScore-\(lesson.id)")
                Spacer(minLength: 0)
                score("Latest score", stars: state.latestStars)
                    .accessibilityIdentifier("lessonLatestScore")
                Spacer(minLength: 0)
            }

            Text(state.progress.completed
                 ? "Gold stays earned. You can return to this lesson any time."
                 : "One two-star score passes this lesson. Three 3-star \(lesson.attemptNoun) among your last five scored attempts earn gold. Every lesson is available now.")
                .font(.footnote).foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }.card()
    }

    /// Tapping rounds have no recording, so their history lives here.
    @ViewBuilder private var recentRounds: some View {
        if case .rhythm(let exercise) = lesson.activity {
            let rounds = rhythmStores.store(for: exercise).attempts.prefix(5)
            if !rounds.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Recent rounds")
                    ForEach(rounds) { round in
                        HStack {
                            Text(round.createdAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.subheadline).foregroundStyle(Palette.muted)
                            Spacer()
                            if let stars = round.starCount { Stars(count: stars, font: .caption) }
                            else { Text("Not rated").font(.caption).foregroundStyle(Palette.muted) }
                        }
                    }
                }.card().accessibilityIdentifier("lessonRecentRounds")
            }
        }
    }

    private func score(_ title: String, stars: Int?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(Palette.muted)
            if let stars {
                Stars(count: stars)
            } else {
                Text("No score yet").font(.footnote).foregroundStyle(Palette.muted)
            }
        }.accessibilityElement(children: .ignore)
            .accessibilityLabel("\(title), \(stars.map { "\($0) of 3 stars" } ?? "No score yet")")
    }

    private func goal(_ title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "star").font(.footnote).foregroundStyle(Palette.gold).padding(.top, 2)
            Text("\(title). ").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.forest)
                + Text(detail).font(.subheadline).foregroundStyle(Palette.muted)
        }
    }
}
