import SwiftUI

/// Every screen the Music tab can push. Practice is one of them: you choose in
/// the library, practise, and go back.
enum MusicRoute: Hashable {
    case area(LearningArea)
    case lesson(PracticeLesson)
    case practice(PracticeLesson)
    case celloIntroduction
    case echo
    case piece(MusicPiece)
    case pieceHumming(MelodyPiece)
    case pieceRhythm(MelodyPiece)
    case pieceReference(MelodyPiece)
}

/// Shared foundations and piece goals live in one visible music library.
@MainActor
struct MusicLibraryView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    @ObservedObject var rhythmStores: RhythmStores
    @ObservedObject var melodyRhythmStore: MelodyRhythmStore
    @State private var path: [MusicRoute] = []
    /// The foundation lesson practised most recently, for a quick way back in.
    @AppStorage("lastFoundationLesson") private var lastLessonID = ""

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    ScreenHeader(title: "Music", subtitle: "Build your way to the music you want to play.")
                    if let lesson = PracticeLesson(rawValue: lastLessonID) {
                        VStack(alignment: .leading, spacing: 12) {
                            SectionTitle("Continue")
                            Button { practise(lesson) } label: {
                                LibraryRow(leading: .number(lesson.number), title: lesson.title,
                                           subtitle: "\(lesson.area.title) · Lesson \(lesson.number)") { EmptyView() }
                            }.buttonStyle(.plain).accessibilityIdentifier("continueLessonButton")
                                .accessibilityLabel("Continue \(lesson.title), \(lesson.area.title) lesson \(lesson.number)")
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Foundations")
                        ForEach(LearningArea.allCases) { area in
                            let lessons = PracticeLesson.lessons(in: area)
                            let completed = lessons.filter {
                                LessonState(lesson: $0, store: store, rhythmStores: rhythmStores).progress.completed
                            }.count
                            NavigationLink(value: MusicRoute.area(area)) {
                                LibraryRow(symbol: areaSymbol(area), title: area.title, subtitle: areaPurpose(area),
                                           footer: "\(completed) of \(lessons.count) lessons completed")
                            }.buttonStyle(.plain)
                                .accessibilityIdentifier("foundation-\(area.id)")
                                .accessibilityLabel("\(area.title), \(completed) of \(lessons.count) lessons completed")
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Pieces")
                        ForEach(MusicPiece.allCases) { piece in
                            NavigationLink(value: MusicRoute.piece(piece)) {
                                LibraryRow(symbol: "music.note.list", title: piece.title, subtitle: piece.subtitle,
                                           footer: piece.statusLabel)
                            }.buttonStyle(.plain)
                                .accessibilityIdentifier("piece-\(piece.id)")
                                .accessibilityLabel("\(piece.title), \(piece.subtitle), \(piece.statusLabel)")
                        }
                    }
                    resources
                }.screenContent()
            }.background(Palette.paper)
                .accessibilityIdentifier("musicLibraryHome")
                .screenTitle("Music")
                .navigationDestination(for: MusicRoute.self) { destination($0) }
        }.tint(Palette.forest)
    }

    @ViewBuilder
    private func destination(_ route: MusicRoute) -> some View {
        switch route {
        case .area(let area):
            FoundationLessonsView(area: area, store: store, rhythmStores: rhythmStores)
        case .lesson(let lesson):
            LessonDetailView(lesson: lesson, store: store, rhythmStores: rhythmStores, onStartLesson: practise)
        case .practice(let lesson):
            FoundationPracticeView(lesson: lesson, store: store, capture: capture, rhythmStores: rhythmStores,
                                   onStartLesson: practise).id(lesson)
        case .celloIntroduction: CelloIntroductionView(capture: capture)
        case .echo: EchoPracticeView(store: store, capture: capture)
        case .piece(let piece): piecePath(piece)
        case .pieceHumming(let piece): MelodyHummingView(store: store, capture: capture, piece: piece)
        case .pieceRhythm(let piece): MelodyRhythmView(store: melodyRhythmStore, capture: capture, piece: piece)
        case .pieceReference(let piece): MelodyReferenceView(capture: capture, piece: piece)
        }
    }

    /// Opens a lesson's practice screen above its own area and lesson page, so Back
    /// always leads somewhere that matches what is on screen.
    private func practise(_ lesson: PracticeLesson) {
        lastLessonID = lesson.id
        let trail: [MusicRoute] = [.area(lesson.area), .lesson(lesson), .practice(lesson)]
        if path.suffix(2) == [.area(lesson.area), .lesson(lesson)] {
            path.append(.practice(lesson))
        } else {
            // Keep whatever led to the foundations, such as a piece page.
            let lead = path.prefix { if case .area = $0 { return false } else { return true } }
            path = Array(lead) + trail
        }
    }

    private func piecePath(_ piece: MusicPiece) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                ScreenHeader(eyebrow: piece.statusLabel, title: piece.title, subtitle: piece.summary,
                             titleIdentifier: "pieceDetailTitle", eyebrowIdentifier: "pieceStatus")
                if let melody = piece.melodyPiece {
                    NavigationLink(value: MusicRoute.pieceHumming(melody)) {
                        LibraryRow(symbol: "waveform", title: "Humming",
                                   subtitle: "Record phrases and earn Notes, Timing and Clarity stars",
                                   footer: "Four phrases, then the whole melody")
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("melodyHummingLink")
                    NavigationLink(value: MusicRoute.pieceRhythm(melody)) {
                        LibraryRow(symbol: "metronome", title: "Rhythm",
                                   subtitle: "Tap the melody’s note starts and follow its longer notes",
                                   footer: "Four phrases, then the whole melody")
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("melodyRhythmLink")
                    NavigationLink(value: MusicRoute.pieceReference(melody)) {
                        LibraryRow(symbol: "play.circle.fill", title: "Listen & follow",
                                   subtitle: "Hear the melody or one short phrase",
                                   footer: "Recorded hum & cello · 60 BPM")
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("melodyReferenceLink")
                }
                VStack(alignment: .leading, spacing: 18) {
                    SectionTitle("Learning path")
                    ForEach(Array(piece.milestones.enumerated()), id: \.offset) { index, milestone in
                        NumberedStep(number: index + 1, title: milestone.title, detail: milestone.detail)
                    }
                }.card().accessibilityIdentifier("pieceMilestones")
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Practise foundations")
                    Text(piece.melodyPiece != nil ? "Build the skills behind the melody." : "These shared skills are available now. Piece-specific exercises are planned.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    ForEach(LearningArea.allCases) { area in
                        NavigationLink(value: MusicRoute.area(area)) {
                            LibraryRow(symbol: areaSymbol(area), title: area.title, subtitle: areaPurpose(area))
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("pieceFoundation-\(area.id)")
                    }
                }
            }.screenContent()
        }.background(Palette.paper).screenTitle(piece.title)
    }

    private func areaPurpose(_ area: LearningArea) -> String {
        switch area {
        case .humming: return "Hear and match a note"
        case .rhythm: return "Feel the beat and learn tap patterns"
        case .cello: return "Build a steady sound on open strings"
        }
    }

    private func areaSymbol(_ area: LearningArea) -> String {
        switch area {
        case .humming: return "waveform"
        case .rhythm: return "metronome"
        case .cello: return "music.note"
        }
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

@MainActor
private struct FoundationLessonsView: View {
    let area: LearningArea
    @ObservedObject var store: SessionStore
    @ObservedObject var rhythmStores: RhythmStores

    private var lessons: [PracticeLesson] { PracticeLesson.lessons(in: area) }
    private var completedCount: Int {
        lessons.filter { LessonState(lesson: $0, store: store, rhythmStores: rhythmStores).progress.completed }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(title: area.title,
                             subtitle: "\(completedCount) of \(lessons.count) lessons completed · Choose any lesson",
                             titleIdentifier: "foundationAreaTitle",
                             subtitleIdentifier: "foundationCompletionSummary")
                if area == .cello {
                    NavigationLink(value: MusicRoute.celloIntroduction) {
                        LibraryRow(symbol: "music.note", title: "Meet your cello",
                                   subtitle: "Explore the parts and hear the four strings",
                                   footer: "Start here · Listen and explore")
                    }.buttonStyle(.plain).accessibilityIdentifier("celloIntroductionLink")
                }
                VStack(spacing: 12) {
                    ForEach(lessons) { lesson in
                        let state = LessonState(lesson: lesson, store: store, rhythmStores: rhythmStores)
                        NavigationLink(value: MusicRoute.lesson(lesson)) {
                            LessonRow(lesson: lesson, state: state)
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("lesson-\(lesson.id)")
                            .accessibilityLabel("Lesson \(lesson.number), \(lesson.title), \(state.accessibilitySummary)")
                            .accessibilityHint("Opens instructions and saved scores")
                    }
                }
                if area == .humming {
                    VStack(alignment: .leading, spacing: 12) {
                        SectionTitle("Ear training")
                        NavigationLink(value: MusicRoute.echo) {
                            LibraryRow(symbol: "ear", title: "Listen & Echo",
                                       subtitle: "Remember a short pattern and hum it back",
                                       footer: "Two notes, then three")
                        }.buttonStyle(.plain).accessibilityIdentifier("echoPracticeLink")
                    }
                }
            }.screenContent()
        }.background(Palette.paper).screenTitle(area.title)
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
        LibraryRow(leading: .number(lesson.number), title: lesson.title, subtitle: lesson.shortPurpose) {
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
                        Stars(count: best, font: .caption2)
                    }.accessibilityIdentifier("lessonBestScore-\(lesson.id)")
                } else {
                    Text("No score yet").foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("lessonBestScore-\(lesson.id)")
                }
            }.font(.caption.weight(.medium))
        }
    }
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

                progressCard

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
        }.card()
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
