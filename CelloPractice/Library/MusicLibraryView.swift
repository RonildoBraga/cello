import SwiftUI

/// Every screen the Music tab can push. Practice is one of them: you choose a
/// step on the path, practise, and go back.
enum MusicRoute: Hashable {
    /// The idea a lesson introduces, shown before it the first time.
    case primer(PracticeLesson)
    case lesson(PracticeLesson)
    case practice(PracticeLesson)
    case celloIntroduction
    case echo
    /// Humming a melody, opened at a phrase or at the whole melody.
    case pieceHumming(MelodyPiece, MelodySection)
    case pieceRhythm(MelodyPiece)
    case pieceNotes(MelodyPiece)
    case pieceReference(MelodyPiece)
}

extension PathStep {
    var route: MusicRoute {
        switch self {
        case .lesson(let lesson): return .lesson(lesson)
        case .listen(let piece): return .pieceReference(piece)
        case .tap(let piece): return .pieceRhythm(piece)
        case .meetNotes(let piece): return .pieceNotes(piece)
        case .hum(let piece): return .pieceHumming(piece, .phrase1)
        case .wholeMelody(let piece): return .pieceHumming(piece, .whole)
        case .celloIntroduction: return .celloIntroduction
        case .echo: return .echo
        }
    }
}

/// The Music tab: one path of levels, from first sounds to melodies.
@MainActor
struct MusicLibraryView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    @ObservedObject var rhythmStores: RhythmStores
    @ObservedObject var melodyRhythmStore: MelodyRhythmStore
    @State private var path: [MusicRoute] = []
    @AppStorage(StoredIDs.listenedMelodies) private var listened = ""
    @AppStorage(StoredIDs.celebratedLevels) private var celebrated = ""
    @AppStorage(StoredIDs.seenPrimers) private var seenPrimers = ""
    /// The level whose completion is being shown. It appears once.
    @State private var celebrating: Level?
    /// The levels showing their steps. The level holding the next step opens
    /// each time the path comes into view.
    @State private var open: Set<String> = []

    /// The first step on the path that has not been passed yet.
    private var next: (level: Level, step: PathStep)? { Level.nextStep(isPassed: isPassed) }

    private func isPassed(_ step: PathStep) -> Bool { state(for: step).progress.passed }

    var body: some View {
        let next = next
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Music", subtitle: "Follow the path. The next step is marked; every step is open.")
                    if let celebrating { completionCard(celebrating, next: next) }
                    ForEach(Level.path) { section($0, next: next) }
                }.screenContent()
            }.background(Palette.paper)
                .accessibilityIdentifier("musicLibraryHome")
                .screenTitle("Music")
                .onAppear {
                    if let level = next?.level { open.insert(level.id) }
                    if let level = Level.newlyCompleted(celebrated: celebrated, isPassed: isPassed) {
                        celebrating = level
                        celebrated = Level.path.filter { $0.isComplete(isPassed: isPassed) }
                            .reduce(celebrated) { StoredIDs.adding($1.id, to: $0) }
                    }
                }
                // A route's screen is rebuilt when the step bar swaps it for another of the
                // same kind, so it never inherits the previous screen's selections.
                .navigationDestination(for: MusicRoute.self) { destination($0).id($0) }
        }.tint(Palette.forest).environment(\.openPathStep, open)
    }

    @ViewBuilder
    private func destination(_ route: MusicRoute) -> some View {
        switch route {
        case .primer(let lesson):
            if let primer = lesson.primer {
                PrimerView(lesson: lesson, primer: primer, capture: capture) {
                    seenPrimers = StoredIDs.adding(lesson.id, to: seenPrimers)
                    path = [.lesson(lesson)]
                }
            }
        case .lesson(let lesson):
            LessonDetailView(lesson: lesson, store: store, rhythmStores: rhythmStores, onStartLesson: practise)
        case .practice(let lesson):
            FoundationPracticeView(lesson: lesson, store: store, capture: capture, rhythmStores: rhythmStores)
        case .celloIntroduction: CelloIntroductionView(capture: capture)
        case .echo: EchoPracticeView(store: store, capture: capture)
        case .pieceHumming(let piece, let section):
            MelodyHummingView(store: store, capture: capture, piece: piece, section: section)
        case .pieceRhythm(let piece): MelodyRhythmView(store: melodyRhythmStore, capture: capture, piece: piece)
        case .pieceNotes(let piece): MeetNotesView(store: store, capture: capture, piece: piece)
        case .pieceReference(let piece): MelodyReferenceView(capture: capture, piece: piece)
        }
    }

    /// Opens a lesson's practice screen directly above the path, so Back
    /// always returns to Music.
    private func practise(_ lesson: PracticeLesson) {
        path = needsPrimer(lesson) ? [.primer(lesson)] : [.practice(lesson)]
    }

    /// Moves to another step from the step bar, replacing the current screen.
    private func open(_ step: PathStep) {
        if case .lesson(let lesson) = step { practise(lesson) } else { path = [step.route] }
    }

    /// A lesson's new idea is explained once, before the lesson is first opened.
    private func needsPrimer(_ lesson: PracticeLesson) -> Bool {
        lesson.primer != nil && !StoredIDs.contains(lesson.id, in: seenPrimers)
    }

    private func route(for step: PathStep) -> MusicRoute {
        if case .lesson(let lesson) = step, needsPrimer(lesson) { return .primer(lesson) }
        return step.route
    }

    // MARK: Path

    /// One level: a compact header, and its steps in a single card when open.
    private func section(_ level: Level, next: (level: Level, step: PathStep)?) -> some View {
        let isOpen = open.contains(level.id)
        let done = level.passedSteps(isPassed: isPassed)
        let complete = done == level.steps.count
        return VStack(alignment: .leading, spacing: 8) {
            Button { open.formSymmetricDifference([level.id]) } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: "Level \(level.number)", color: Palette.goldText)
                        Text(level.title).font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 0)
                    Label("\(done) of \(level.steps.count)", systemImage: complete ? "checkmark.circle.fill" : "circle")
                        .labelStyle(.titleAndIcon).font(.caption.weight(.medium))
                        .foregroundStyle(complete ? Palette.forest : Palette.muted)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Palette.forest)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityIdentifier("level-\(level.id)")
                .accessibilityLabel("Level \(level.number), \(level.title), \(done) of \(level.steps.count) steps done")
                .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
                .accessibilityAddTraits(.isHeader)
            if isOpen {
                VStack(spacing: 0) {
                    ForEach(Array(level.steps.enumerated()), id: \.element) { index, step in
                        let state = state(for: step)
                        let isNext = next?.step == step
                        if index > 0 { Divider() }
                        NavigationLink(value: route(for: step)) {
                            StepRow(step: step, number: index + 1, state: state, isNext: isNext)
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier(step.id)
                            .accessibilityLabel([isNext ? "Continue" : nil, "Step \(index + 1)",
                                                 step.title, state.status, state.spokenScore]
                                .compactMap { $0 }.joined(separator: ", "))
                    }
                }.card(padding: 0)
            }
        }
    }

    private func state(for step: PathStep) -> StepState {
        switch step {
        case .lesson(let lesson):
            let lesson = LessonState(lesson: lesson, store: store, rhythmStores: rhythmStores)
            return StepState(progress: lesson.step, stars: lesson.bestStars ?? 0)
        case .listen(let piece):
            let heard = StoredIDs.contains(piece.rawValue, in: listened)
            return StepState(progress: StepProgress([PracticeProgress(successfulAttempts: 0, completed: false,
                                                                      passed: heard)]),
                             status: heard ? "Listened" : "Not heard yet", stars: nil)
        case .tap(let piece):
            return StepState(progress: StepProgress(MelodySection.phrases.map {
                melodyRhythmStore.progress(for: piece.rhythm(section: $0))
            }))
        case .meetNotes(let piece):
            // Every note needs a passing take; the two pairs are extra practice.
            return StepState(progress: StepProgress(NoteDrill.notes(for: piece).map {
                store.melodyProgress(for: $0.context)
            }, partNoun: "notes"))
        case .hum(let piece):
            return StepState(progress: StepProgress(MelodySection.phrases.map {
                store.melodyProgress(for: piece.humming(register: .lowVoice, section: $0))
            }))
        case .wholeMelody(let piece):
            return StepState(progress: StepProgress([
                store.melodyProgress(for: piece.humming(register: .lowVoice, section: .whole))
            ]))
        case .echo:
            return StepState(progress: StepProgress([store.echoProgress(for: .twoNotes, register: .lowVoice)]))
        case .celloIntroduction:
            let read = StoredIDs.contains(StoredIDs.celloIntroduction, in: seenPrimers)
            return StepState(progress: StepProgress([PracticeProgress(successfulAttempts: 0, completed: false,
                                                                      passed: read)]),
                             status: read ? "Read" : "Not read yet", stars: nil)
        }
    }

    /// Shown once when a level's last step is passed, pointing at what comes next.
    private func completionCard(_ level: Level, next: (level: Level, step: PathStep)?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Level \(level.number) complete", color: Palette.goldText)
            Text(level.title).font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
            Text(next.map { "Every step is passed. Next: \($0.level.title) · \($0.step.title)." }
                 ?? "Every step on the path is passed. More melodies are on the way.")
                .font(.subheadline).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if let next {
                    Button("Continue") {
                        celebrating = nil
                        path.append(next.step.route)
                    }.buttonStyle(SecondaryActionButtonStyle()).accessibilityIdentifier("levelCompleteContinue")
                }
                Button("Close") { celebrating = nil }.buttonStyle(SecondaryActionButtonStyle())
            }
        }.card().overlay {
            RoundedRectangle(cornerRadius: Layout.cardRadius).strokeBorder(Palette.gold, lineWidth: 2)
        }.accessibilityElement(children: .contain).accessibilityIdentifier("levelCompleteCard")
    }
}

/// What a path row shows about its step.
private struct StepState {
    let progress: StepProgress
    let status: String
    /// The best score out of three; nil for steps that are not scored, such as Listen.
    let stars: Int?

    init(progress: StepProgress, status: String? = nil, stars: Int?) {
        self.progress = progress
        self.status = status ?? progress.status
        self.stars = stars
    }

    /// A scored step shows the weakest best score across its parts.
    init(progress: StepProgress) {
        self.init(progress: progress, stars: progress.bestStars)
    }

    var spokenScore: String? {
        stars.map { $0 > 0 ? "Best score \($0) of 3 stars" : "No score yet" }
    }
}

/// One step on the path. Every step uses this row, whatever it opens: its
/// place in the level, its title, how far it has got and its best score.
private struct StepRow: View {
    let step: PathStep
    let number: Int
    let state: StepState
    let isNext: Bool

    private var lessonID: String {
        if case .lesson(let lesson) = step { return lesson.id }
        return step.id
    }

    var body: some View {
        HStack(spacing: 12) {
            IconTile {
                Text(String(format: "%02d", number)).font(.system(.callout, design: .serif).weight(.semibold))
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(step.title).font(.body.weight(.semibold)).foregroundStyle(Palette.ink)
                HStack(spacing: 6) {
                    if isNext {
                        Text("Continue").font(.caption2.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 8).padding(.vertical, 2)
                            .background(Palette.forest, in: Capsule())
                    }
                    TierLabel(progress: state.progress, text: state.status,
                              goldIdentifier: "lessonCompletion-\(lessonID)")
                }.font(.caption.weight(.medium))
            }
            Spacer(minLength: 4)
            if let stars = state.stars {
                Stars(count: stars, font: .caption2).accessibilityIdentifier("lessonBestScore-\(lessonID)")
            }
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
        }.padding(.horizontal, 14).padding(.vertical, 10).contentShape(Rectangle())
    }
}

/// A step's progress in words, with a gold star for gold and a tick for passed.
private struct TierLabel: View {
    let progress: StepProgress
    let text: String
    let goldIdentifier: String

    var body: some View {
        if progress.gold {
            Label(text, systemImage: "star.circle.fill").foregroundStyle(Palette.goldText)
                .accessibilityIdentifier(goldIdentifier)
        } else if progress.passed {
            Label(text, systemImage: "checkmark.circle.fill").foregroundStyle(Palette.forest)
        } else {
            Text(text).foregroundStyle(Palette.muted)
        }
    }
}

@MainActor
private struct LessonState {
    let progress: PracticeProgress
    let bestStars: Int?
    let latestStars: Int?
    let hasAttempts: Bool

    init(lesson: PracticeLesson, store: SessionStore, rhythmStores: RhythmStores) {
        switch lesson.activity {
        case .recording(let exercise):
            let target = VoicePracticeMode.note(exercise).targetFrequency
            progress = store.progress(for: exercise, targetFrequency: target)
            let scores = LessonScoreSummary(exercise: exercise, targetFrequency: target,
                                            sessions: store.sessions, completed: progress.completed)
            bestStars = scores.bestStars
            latestStars = scores.latestStars
            hasAttempts = scores.hasAttempts
        case .rhythm(let exercise):
            let rhythmStore = rhythmStores.store(for: exercise)
            progress = rhythmStore.progress
            bestStars = rhythmStore.bestStars
            latestStars = rhythmStore.attempts.compactMap(\.starCount).first
            hasAttempts = !rhythmStore.attempts.isEmpty || progress.completed
        }
    }

    var step: StepProgress { StepProgress([progress], started: hasAttempts) }
}

@MainActor
private struct LessonDetailView: View {
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
            .screenTitle("Lesson \(lesson.number)")
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
                 ? "Gold stays earned. You can return to this lesson any time."
                 : "One two-star score passes this step. Three 3-star \(lesson.attemptNoun) among your last five scored attempts earn gold. Every lesson is available now.")
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
