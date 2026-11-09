import SwiftUI

@MainActor
struct LessonsView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var pulseStore: PulsePracticeStore
    @ObservedObject var twoTapsStore: PulsePracticeStore
    @ObservedObject var mixedRhythmStore: PulsePracticeStore
    let onStartLesson: (PracticeLesson) -> Void
    var onClose: (() -> Void)?
    @State private var section: PracticeSection

    init(store: SessionStore, pulseStore: PulsePracticeStore, twoTapsStore: PulsePracticeStore,
         mixedRhythmStore: PulsePracticeStore,
         initialSection: PracticeSection,
         onStartLesson: @escaping (PracticeLesson) -> Void, onClose: (() -> Void)? = nil) {
        self.store = store
        self.pulseStore = pulseStore
        self.twoTapsStore = twoTapsStore
        self.mixedRhythmStore = mixedRhythmStore
        self.onStartLesson = onStartLesson
        self.onClose = onClose
        _section = State(initialValue: initialSection)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    Picker("Lesson section", selection: $section) {
                        ForEach(PracticeSection.allCases) { section in
                            Text(section.title).tag(section)
                        }
                    }.pickerStyle(.segmented)
                        .accessibilityIdentifier("lessonsSectionPicker")

                    VStack(alignment: .leading, spacing: 7) {
                        Text(section == .humming ? "Voice & listening" : "Your open strings")
                            .font(.system(size: 27, weight: .semibold, design: .serif))
                            .foregroundStyle(Palette.ink)
                        Text("\(completedCount) of \(lessons.count) lessons completed · Choose any lesson")
                            .font(.footnote).foregroundStyle(Palette.muted)
                    }

                    VStack(spacing: 12) {
                        ForEach(lessons) { lesson in
                            let state = LessonState(lesson: lesson, store: store, rhythmStores: rhythmStores)
                            NavigationLink {
                                LessonDetailView(lesson: lesson, store: store, pulseStore: pulseStore, twoTapsStore: twoTapsStore,
                                                 mixedRhythmStore: mixedRhythmStore,
                                                 onStartLesson: onStartLesson, onClose: onClose)
                            } label: {
                                LessonRow(lesson: lesson, state: state)
                            }.buttonStyle(.plain)
                                .accessibilityIdentifier("lesson-\(lesson.id)")
                                .accessibilityLabel("Lesson \(lesson.number), \(lesson.title), \(state.accessibilitySummary)")
                                .accessibilityHint("Opens instructions and saved scores")
                        }
                    }

                    resources.padding(.top, 4)
                }.padding(20).padding(.bottom, 24)
            }.background(Palette.paper)
                .navigationTitle("Lessons")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    if let onClose {
                        ToolbarItem(placement: .topBarTrailing) { Button("Done", action: onClose) }
                    }
                }
        }.tint(Palette.forest)
    }

    private var rhythmStores: [RhythmExercise: PulsePracticeStore] {
        [.pulse: pulseStore, .twoTaps: twoTapsStore, .mixedRhythm: mixedRhythmStore]
    }

    private var lessons: [PracticeLesson] { PracticeLesson.lessons(in: section) }

    private var completedCount: Int {
        lessons.filter { LessonState(lesson: $0, store: store, rhythmStores: rhythmStores).progress.completed }.count
    }

    private var resources: some View {
        DisclosureGroup("Resources & recording credit") {
            VStack(alignment: .leading, spacing: 12) {
                Link("ABRSM · Listening and aural skills", destination: URL(string: "https://teacherhub.abrsm.org/mod/page/view.php?id=2020")!)
                Link("Royal Conservatory · Ear training", destination: URL(string: "https://www.rcmusic.com/learning/digital-learning/rcm-online-ear-training-rcm-online-sight-reading/ear-training")!)
                Link("Frimley Health · Gentle humming", destination: URL(string: "https://www.fhft.nhs.uk/patients-and-visitors/patient-information-library/oral-resonance-bringing-voice-forward")!)
                Divider()
                Link("Deep Humming Noise · retropttam", destination: HummingExample.sourceURL)
                Link("Creative Commons Attribution 3.0", destination: HummingExample.licenseURL)
                Text("Three-second excerpt, shortened and volume adjusted. Original pitch preserved.")
                    .foregroundStyle(Palette.muted)
            }.font(.footnote).padding(.top, 12)
        }.font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
    }
}

@MainActor
private struct LessonState {
    let progress: PracticeProgress
    let bestStars: Int?
    let latestStars: Int?
    let hasAttempts: Bool

    init(lesson: PracticeLesson, store: SessionStore, rhythmStores: [RhythmExercise: PulsePracticeStore]) {
        switch lesson.activity {
        case .recording(let exercise):
            let target = lesson.section.effectiveTarget(for: exercise)
            progress = store.progress(for: exercise, targetFrequency: target)
            let scores = LessonScoreSummary(exercise: exercise, targetFrequency: target,
                                            sessions: store.sessions, completed: progress.completed)
            bestStars = scores.bestStars
            latestStars = scores.latestStars
            hasAttempts = scores.hasAttempts
        case .rhythm(let exercise):
            guard let rhythmStore = rhythmStores[exercise] else {
                preconditionFailure("Every rhythm lesson must have its own practice store")
            }
            progress = rhythmStore.progress
            bestStars = rhythmStore.bestStars
            latestStars = rhythmStore.attempts.compactMap(\.starCount).first
            hasAttempts = !rhythmStore.attempts.isEmpty || progress.completed
        }
    }

    var status: String {
        progress.completed ? "Completed" : hasAttempts ? "In progress" : "Not started"
    }

    var accessibilitySummary: String {
        if let bestStars { return "\(status), Best score \(bestStars) of 3 stars" }
        return "\(status), No score yet"
    }
}

@MainActor
private struct LessonRow: View {
    let lesson: PracticeLesson
    let state: LessonState

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 13) {
                Text(String(format: "%02d", lesson.number))
                    .font(.system(size: 19, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.forest)
                    .frame(width: 43, height: 43)
                    .background(Palette.forest.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                VStack(alignment: .leading, spacing: 4) {
                    Text(lesson.title).font(.headline).foregroundStyle(Palette.ink)
                    Text(lesson.shortPurpose).font(.footnote).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right").font(.caption.weight(.semibold))
                    .foregroundStyle(Palette.muted)
            }
            HStack(spacing: 8) {
                if state.progress.completed {
                    Label("Completed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Palette.forest)
                        .accessibilityIdentifier("lessonCompletion-\(lesson.id)")
                } else {
                    Text(state.status).foregroundStyle(Palette.muted)
                }
                Spacer(minLength: 4)
                if let best = state.bestStars {
                    HStack(spacing: 6) {
                        Text("Best").foregroundStyle(Palette.muted)
                        LessonStars(count: best, size: 10)
                    }.accessibilityIdentifier("lessonBestScore-\(lesson.id)")
                } else {
                    Text("No score yet").foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("lessonBestScore-\(lesson.id)")
                }
            }.font(.caption.weight(.medium))
        }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 19))
            .contentShape(Rectangle())
    }
}

@MainActor
private struct LessonDetailView: View {
    let lesson: PracticeLesson
    @ObservedObject var store: SessionStore
    @ObservedObject var pulseStore: PulsePracticeStore
    @ObservedObject var twoTapsStore: PulsePracticeStore
    @ObservedObject var mixedRhythmStore: PulsePracticeStore
    let onStartLesson: (PracticeLesson) -> Void
    var onClose: (() -> Void)?

    private var rhythmStores: [RhythmExercise: PulsePracticeStore] {
        [.pulse: pulseStore, .twoTaps: twoTapsStore, .mixedRhythm: mixedRhythmStore]
    }

    private var state: LessonState { LessonState(lesson: lesson, store: store, rhythmStores: rhythmStores) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("LESSON \(String(format: "%02d", lesson.number)) · \(lesson.section.title.uppercased())")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .tracking(1.5).foregroundStyle(Palette.gold)
                    Text(lesson.title)
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("lessonDetailTitle")
                    Text(lesson.purpose).font(.subheadline).foregroundStyle(Palette.muted)
                }

                progressCard

                VStack(alignment: .leading, spacing: 15) {
                    Text("How to practise").font(.headline).foregroundStyle(Palette.ink)
                    ForEach(Array(lesson.instructions.enumerated()), id: \.offset) { index, instruction in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)")
                                .font(.caption.weight(.semibold)).foregroundStyle(Palette.forest)
                                .frame(width: 23, height: 23)
                                .background(Palette.forest.opacity(0.08), in: Circle())
                            Text(instruction).font(.subheadline).foregroundStyle(Palette.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }.accessibilityElement(children: .contain)
                    .accessibilityIdentifier("lessonInstruction")

                VStack(alignment: .leading, spacing: 12) {
                    Text("Three small goals").font(.headline).foregroundStyle(Palette.ink)
                    ForEach(Array(lesson.goals.enumerated()), id: \.offset) { _, item in
                        goal(item.title, detail: item.detail)
                    }
                }
            }.padding(22).padding(.bottom, 20)
        }.background(Palette.paper)
            .navigationTitle("Lesson \(lesson.number)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if let onClose {
                    ToolbarItem(placement: .topBarTrailing) { Button("Done", action: onClose) }
                }
            }
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    onStartLesson(lesson)
                } label: {
                    Text(state.hasAttempts ? "Practise again" : "Start lesson")
                        .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 17)
                        .foregroundStyle(.white)
                        .background(Palette.forest, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
                    .accessibilityIdentifier("startLessonButton")
                    .padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 10)
                    .background(Palette.paper)
            }
    }

    private var progressCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                if state.progress.completed {
                    Label("Lesson completed", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(Palette.forest)
                        .accessibilityIdentifier("lessonCompletion-\(lesson.id)")
                } else {
                    Text(state.status).foregroundStyle(Palette.ink)
                }
                Spacer(minLength: 5)
                Text("\(state.progress.successfulAttempts)/\(state.progress.requiredAttempts) successful \(lesson.attemptNoun)")
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
                 ? "Your completion stays earned. You can return to this lesson any time."
                 : "Three 3-star \(lesson.attemptNoun) among your last five scored attempts complete this lesson. Every lesson is available now.")
                .font(.footnote).foregroundStyle(Palette.muted)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 19))
    }

    private func score(_ title: String, stars: Int?) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.caption).foregroundStyle(Palette.muted)
            if let stars {
                LessonStars(count: stars, size: 16)
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

private struct LessonStars: View {
    let count: Int
    let size: CGFloat

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<3) { index in
                Image(systemName: index < count ? "star.fill" : "star")
                    .foregroundStyle(index < count ? Palette.gold : Palette.muted.opacity(0.45))
            }
        }.font(.system(size: size, weight: .medium))
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(count) of 3 stars")
    }
}
