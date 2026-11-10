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
                VStack(alignment: .leading, spacing: 26) {
                    ScreenHeader(title: "Music", subtitle: "One path, from first sounds to melodies. The next step is marked; every step is open.")
                    if let celebrating { completionCard(celebrating, next: next) }
                    ForEach(Level.path) { section($0, next: next) }
                    destinationNote
                    ForEach(Level.extras) { section($0, next: next) }
                    resources
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
                .navigationDestination(for: MusicRoute.self) { destination($0) }
        }.tint(Palette.forest)
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
            FoundationPracticeView(lesson: lesson, store: store, capture: capture, rhythmStores: rhythmStores,
                                   onStartLesson: practise).id(lesson)
        case .celloIntroduction: CelloIntroductionView(capture: capture)
        case .echo: EchoPracticeView(store: store, capture: capture)
        case .pieceHumming(let piece, let section):
            MelodyHummingView(store: store, capture: capture, piece: piece, section: section)
        case .pieceRhythm(let piece): MelodyRhythmView(store: melodyRhythmStore, capture: capture, piece: piece)
        case .pieceNotes(let piece): MeetNotesView(store: store, capture: capture, piece: piece)
        case .pieceReference(let piece): MelodyReferenceView(capture: capture, piece: piece)
        }
    }

    /// Opens a lesson's practice screen above its own lesson page, so Back
    /// always leads somewhere that matches what is on screen.
    private func practise(_ lesson: PracticeLesson) {
        path = needsPrimer(lesson) ? [.primer(lesson)] : [.lesson(lesson), .practice(lesson)]
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

    private func section(_ level: Level, next: (level: Level, step: PathStep)?) -> some View {
        let isOpen = open.contains(level.id)
        let done = level.passedSteps(isPassed: isPassed)
        // Only the numbered levels are counted: the others are not a course to finish.
        let count = level.number == nil ? nil : "\(done) of \(level.steps.count) steps done"
        return VStack(alignment: .leading, spacing: 12) {
            Button { open.formSymmetricDifference([level.id]) } label: {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 5) {
                        if let number = level.number {
                            Eyebrow(text: "Level \(number)", color: Palette.goldText)
                        }
                        Text(level.title).font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
                        Text(level.subtitle).font(.footnote).foregroundStyle(Palette.muted)
                        if let count { Text(count).font(.caption).foregroundStyle(Palette.forest) }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Palette.forest)
                        .frame(minWidth: 44, minHeight: 44)
                }.contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityIdentifier("level-\(level.id)")
                .accessibilityLabel([level.number.map { "Level \($0)" }, level.title, level.subtitle, count]
                    .compactMap { $0 }.joined(separator: ", "))
                .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
                .accessibilityAddTraits(.isHeader)
            if isOpen {
                ForEach(Array(level.steps.enumerated()), id: \.element) { index, step in
                    let state = state(for: step)
                    let isNext = next?.step == step
                    NavigationLink(value: route(for: step)) {
                        StepRow(step: step, number: level.number == nil ? nil : index + 1,
                                state: state, isNext: isNext)
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier(step.id)
                        .accessibilityLabel(([isNext ? "Continue" : nil,
                                              level.number == nil ? nil : "Step \(index + 1)",
                                              step.title, state.status, state.spokenScore])
                            .compactMap { $0 }.joined(separator: ", "))
                }
            }
        }
    }

    private func state(for step: PathStep) -> StepState {
        switch step {
        case .lesson(let lesson):
            let lesson = LessonState(lesson: lesson, store: store, rhythmStores: rhythmStores)
            return StepState(progress: lesson.step, bestStars: lesson.bestStars, showsScore: true)
        case .listen(let piece):
            let heard = StoredIDs.contains(piece.rawValue, in: listened)
            return StepState(progress: StepProgress([PracticeProgress(successfulAttempts: 0, completed: false,
                                                                      passed: heard)]),
                             status: heard ? "Listened" : "Not heard yet")
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
        case .celloIntroduction, .echo:
            return StepState(progress: StepProgress([]), tracksProgress: false)
        }
    }

    /// Shown once when a level's last step is passed, pointing at what comes next.
    private func completionCard(_ level: Level, next: (level: Level, step: PathStep)?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Eyebrow(text: "Level \(level.number ?? 0) complete", color: Palette.goldText)
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

    private var destinationNote: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionTitle("Where this is heading")
            Text("Bach’s Cello Suite No. 1 is the long-term goal. Each level builds the listening, rhythm and note skills it needs; more melodies will join the path on the way there.")
                .font(.footnote).foregroundStyle(Palette.muted).fixedSize(horizontal: false, vertical: true)
        }.card().accessibilityElement(children: .combine).accessibilityIdentifier("pathDestinationNote")
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
                Text("Foundation example: shortened and volume adjusted, with original pitch preserved. Melody examples: pitch and timing edited from the same human recording.")
                    .foregroundStyle(Palette.muted)
                Divider()
                Link("VSCO 2 Community Edition · recorded cello", destination: URL(string: "https://github.com/sgossner/VSCO-2-CE")!)
                Link("Creative Commons CC0 1.0", destination: URL(string: "https://creativecommons.org/publicdomain/zero/1.0/")!)
                Text("Bowed cello-section excerpts from Versilian Studios and Ivy Audio, shortened, volume adjusted and tuned for reference playback.")
                    .foregroundStyle(Palette.muted)
            }.font(.footnote).padding(.top, 12)
        }.font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
    }
}

/// What a path row shows about its step.
private struct StepState {
    let progress: StepProgress
    /// Words for the step's progress; nil for steps that keep none, such as Meet your cello.
    let status: String?
    var bestStars: Int?
    /// Lessons show a best score, or say there is none yet.
    var showsScore: Bool

    init(progress: StepProgress, status: String? = nil, bestStars: Int? = nil, showsScore: Bool = false,
         tracksProgress: Bool = true) {
        self.progress = progress
        self.status = tracksProgress ? (status ?? progress.status) : nil
        self.bestStars = bestStars
        self.showsScore = showsScore
    }

    var spokenScore: String? {
        showsScore ? (bestStars.map { "Best score \($0) of 3 stars" } ?? "No score yet") : nil
    }
}

private struct StepRow: View {
    let step: PathStep
    let number: Int?
    let state: StepState
    let isNext: Bool

    private var lessonID: String? {
        if case .lesson(let lesson) = step { return lesson.id }
        return nil
    }

    var body: some View {
        LibraryRow(leading: number.map { .number($0) } ?? .symbol(step.symbol),
                   title: step.title, subtitle: step.subtitle) {
            if isNext || state.status != nil {
                HStack(spacing: 8) {
                    if isNext {
                        Text("Continue").font(.caption.weight(.semibold)).foregroundStyle(.white)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Palette.forest, in: Capsule())
                    }
                    if let status = state.status {
                        TierLabel(progress: state.progress, text: status,
                                  goldIdentifier: "lessonCompletion-\(lessonID ?? step.id)")
                    }
                    Spacer(minLength: 4)
                    if state.showsScore {
                        Group {
                            if let best = state.bestStars {
                                HStack(spacing: 6) {
                                    Text("Best").foregroundStyle(Palette.muted)
                                    Stars(count: best, font: .caption2)
                                }
                            } else {
                                Text("No score yet").foregroundStyle(Palette.muted)
                            }
                        }.accessibilityIdentifier("lessonBestScore-\(lessonID ?? step.id)")
                    }
                }.font(.caption.weight(.medium))
            }
        }.overlay {
            if isNext {
                RoundedRectangle(cornerRadius: Layout.cardRadius).strokeBorder(Palette.forest, lineWidth: 2)
            }
        }
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
                ScreenHeader(eyebrow: "Lesson \(String(format: "%02d", lesson.number)) · \(lesson.area.title)",
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
