import SwiftUI

/// Every screen the Music tab can push. Practice is one of them: you choose a
/// lesson on the path, practise, and go back.
enum MusicRoute: Hashable {
    /// The idea a lesson introduces, shown before it the first time.
    case primer(PracticeLesson)
    case lesson(PracticeLesson)
    case practice(PracticeLesson)
    /// The instrument's parts and strings, opened from a lesson's cello side.
    case celloIntroduction
    case echo
    /// Humming a melody, opened at a phrase or at the whole melody.
    case pieceHumming(MelodyPiece, MelodySection)
    case pieceRhythm(MelodyPiece)
    case pieceNotes(MelodyPiece)
    case pieceReference(MelodyPiece)
}

extension MusicRoute {
    /// The lesson whose screen this is. Primers and lesson pages lead into a
    /// lesson and show no lesson bar.
    var pathLesson: PathLesson? {
        switch self {
        case .primer, .lesson, .celloIntroduction: return nil
        case .practice(let lesson): return .lesson(lesson)
        case .echo: return .echo
        case .pieceHumming(let piece, let section): return section == .whole ? .wholeMelody(piece) : .hum(piece)
        case .pieceRhythm(let piece): return .tap(piece)
        case .pieceNotes(let piece): return .meetNotes(piece)
        case .pieceReference(let piece): return .listen(piece)
        }
    }
}

extension PathLesson {
    var route: MusicRoute {
        switch self {
        case .lesson(let lesson): return .lesson(lesson)
        case .listen(let piece): return .pieceReference(piece)
        case .tap(let piece): return .pieceRhythm(piece)
        case .meetNotes(let piece): return .pieceNotes(piece)
        case .hum(let piece): return .pieceHumming(piece, .phrase1)
        case .wholeMelody(let piece): return .pieceHumming(piece, .whole)
        case .echo: return .echo
        }
    }
}

/// The Music tab: one path of levels, from first sounds to melodies.
@MainActor
struct MusicLibraryView: View {
    @ObservedObject var store: SessionStore
    /// Passed on to the lessons. The path shows nothing of a take in progress, so
    /// it does not observe the controller: its ticks must not redraw the path.
    let capture: CaptureController
    @ObservedObject var rhythmStores: RhythmStores
    @ObservedObject var melodyRhythmStore: MelodyRhythmStore
    @State private var path: [MusicRoute] = []
    @AppStorage(StoredIDs.listenedMelodies) private var listened = ""
    @AppStorage(StoredIDs.seenPrimers) private var seenPrimers = ""
    /// The levels showing their lessons. The level holding the next lesson opens
    /// each time the path comes into view.
    @State private var open: Set<String> = []
    /// Voice or cello, once chosen in a lesson. Until then, the way the last take was made.
    @State private var chosenMethod: PracticeMethod?

    var body: some View {
        // Read once per drawing: every row, Today's practice and the lesson bar share it.
        let progress = PathProgress(store: store, rhythmStores: rhythmStores,
                                    melodyRhythmStore: melodyRhythmStore, listened: listened)
        let next = progress.next
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    ScreenHeader(title: "Music")
                    today(progress, next: next)
                    ForEach(Level.path) { section($0, progress, next: next) }
                }.screenContent()
            }.background(Palette.paper)
                .accessibilityIdentifier("musicLibraryHome")
                .screenTitle("Music")
                .onAppear { if let level = next?.level { open.insert(level.id) } }
                // A route's screen is rebuilt when the lesson bar swaps it for another of the
                // same kind, so it never inherits the previous screen's selections.
                .navigationDestination(for: MusicRoute.self) {
                    destination($0).id($0).environment(\.currentPathLesson, $0.pathLesson)
                }
        }.tint(Palette.forest).environment(\.openPathLesson, open)
            .environment(\.practiceMethod, Binding(get: { chosenMethod ?? store.sessions.first.map { PracticeMethod(exercise: $0.exercise, melody: $0.melodyContext) } ?? .voice },
                                                   set: { chosenMethod = $0 }))
            .environment(\.pathLessonIsPassed, progress.isPassed)
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

    /// Moves to another lesson from the lesson bar, replacing the current screen.
    private func open(_ step: PathLesson) {
        if case .lesson(let lesson) = step { practise(lesson) } else { path = [step.route] }
    }

    /// A lesson's new idea is explained once, before the lesson is first opened.
    private func needsPrimer(_ lesson: PracticeLesson) -> Bool {
        lesson.primer != nil && !StoredIDs.contains(lesson.id, in: seenPrimers)
    }

    private func route(for step: PathLesson, _ progress: PathProgress) -> MusicRoute {
        guard case .lesson(let lesson) = step else { return step.route }
        if needsPrimer(lesson) { return .primer(lesson) }
        // The lesson page describes humming; a lesson practised on the cello opens straight into practice.
        return progress[step].onCello ? .practice(lesson) : step.route
    }

    // MARK: Path

    /// One level: a compact header, and its lessons in a single card when open.
    private func section(_ level: Level, _ progress: PathProgress, next: (level: Level, lesson: PathLesson)?) -> some View {
        let isOpen = open.contains(level.id)
        let done = level.passedLessons(isPassed: progress.isPassed)
        let complete = done == level.lessons.count
        return VStack(alignment: .leading, spacing: 8) {
            Button { open.formSymmetricDifference([level.id]) } label: {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Eyebrow(text: "Level \(level.number)", color: Palette.goldText)
                        Text(level.title).font(.title3.weight(.semibold)).foregroundStyle(Palette.ink)
                    }
                    Spacer(minLength: 0)
                    Label("\(done) of \(level.lessons.count)", systemImage: complete ? "checkmark.circle.fill" : "circle")
                        .labelStyle(.titleAndIcon).font(.caption.weight(.medium))
                        .foregroundStyle(complete ? Palette.forest : Palette.muted)
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.footnote.weight(.semibold)).foregroundStyle(Palette.forest)
                }.frame(minHeight: 44).contentShape(Rectangle())
            }.buttonStyle(.plain)
                .accessibilityIdentifier("level-\(level.id)")
                .accessibilityLabel("Level \(level.number), \(level.title), \(done) of \(level.lessons.count) lessons done")
                .accessibilityValue(isOpen ? "Expanded" : "Collapsed")
                .accessibilityAddTraits(.isHeader)
            if isOpen {
                VStack(spacing: 0) {
                    ForEach(Array(level.lessons.enumerated()), id: \.element) { index, step in
                        let state = progress[step]
                        let isNext = next?.lesson == step
                        if index > 0 { Divider() }
                        NavigationLink(value: route(for: step, progress)) {
                            PathRow(step: step, number: index + 1, state: state, isNext: isNext)
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier(step.id)
                            .accessibilityLabel([isNext ? "Continue" : nil, "Lesson \(index + 1)",
                                                 step.title, state.status, state.spokenScore]
                                .compactMap { $0 }.joined(separator: ", "))
                    }
                }.card(padding: 0)
            }
        }
    }

    /// A few minutes of practice chosen for today: the next lesson and the weakest passed ones.
    @ViewBuilder
    private func today(_ progress: PathProgress, next: (level: Level, lesson: PathLesson)?) -> some View {
        let lessons = progress.today
        if !lessons.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Eyebrow(text: "Today’s practice", color: Palette.goldText).accessibilityAddTraits(.isHeader)
                VStack(spacing: 0) {
                    ForEach(Array(lessons.enumerated()), id: \.element) { index, step in
                        let state = progress[step]
                        if let position = Level.position(of: step) {
                            if index > 0 { Divider() }
                            NavigationLink(value: route(for: step, progress)) {
                                PathRow(step: step, number: position.index + 1,
                                        state: LessonSummary(progress: state.progress,
                                                            status: "\(next?.lesson == step ? "Next" : "Again") · \(position.level.title)",
                                                            stars: state.stars),
                                        isNext: false)
                            }.buttonStyle(.plain)
                                .accessibilityIdentifier("today-\(step.id)")
                                .accessibilityLabel([next?.lesson == step ? "Continue" : "Practise again", step.title,
                                                     position.level.title, state.status, state.spokenScore]
                                    .compactMap { $0 }.joined(separator: ", "))
                        }
                    }
                }.card(padding: 0)
            }
        }
    }
}

/// One lesson on the path. Every lesson uses this row, whatever it opens: its
/// place in the level, its title, how far it has got and its best score.
private struct PathRow: View {
    let step: PathLesson
    let number: Int
    let state: LessonSummary
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

/// A lesson's progress in words, with a gold star for gold and a tick for passed.
struct TierLabel: View {
    let progress: LessonProgress
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
