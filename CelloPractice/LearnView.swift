import SwiftUI

/// Shared foundations and piece goals live in one visible music library.
@MainActor
struct MusicLibraryView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    @ObservedObject var rhythmStores: RhythmStores
    @ObservedObject var melodyRhythmStore: MelodyRhythmStore
    let onStartLesson: (PracticeLesson) -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 26) {
                    Text("Build your way to the music you want to play.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Foundations").font(.headline).foregroundStyle(Palette.ink)
                        ForEach(LearningArea.allCases) { area in
                            let lessons = PracticeLesson.lessons(in: area)
                            let completed = lessons.filter {
                                LessonState(lesson: $0, store: store, rhythmStores: rhythmStores).progress.completed
                            }.count
                            NavigationLink {
                                foundationLessons(area)
                            } label: {
                                MusicLibraryRow(title: area.title, subtitle: areaPurpose(area),
                                                systemImage: areaSymbol(area),
                                                footer: "\(completed) of \(lessons.count) lessons completed")
                            }.buttonStyle(.plain)
                                .accessibilityIdentifier("foundation-\(area.id)")
                                .accessibilityLabel("\(area.title), \(completed) of \(lessons.count) lessons completed")
                        }
                    }
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Pieces").font(.headline).foregroundStyle(Palette.ink)
                        ForEach(MusicPiece.allCases) { piece in
                            NavigationLink {
                                piecePath(piece)
                            } label: {
                                MusicLibraryRow(title: piece.title, subtitle: piece.subtitle,
                                                systemImage: "music.note.list", footer: piece.statusLabel)
                            }.buttonStyle(.plain)
                                .accessibilityIdentifier("piece-\(piece.id)")
                                .accessibilityLabel("\(piece.title), \(piece.subtitle), \(piece.statusLabel)")
                        }
                    }
                    resources
                }.padding(20).padding(.bottom, 24)
            }.background(Palette.paper)
                .accessibilityIdentifier("musicLibraryHome")
                .navigationTitle("Music")
        }.tint(Palette.forest)
    }

    private func foundationLessons(_ area: LearningArea) -> some View {
        FoundationLessonsView(area: area, store: store, capture: capture, rhythmStores: rhythmStores,
                              onStartLesson: onStartLesson)
    }

    private func piecePath(_ piece: MusicPiece) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                VStack(alignment: .leading, spacing: 10) {
                    Text(piece.statusLabel).font(.caption.weight(.semibold)).foregroundStyle(Palette.gold)
                        .accessibilityIdentifier("pieceStatus")
                    Text(piece.title).font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.ink).accessibilityIdentifier("pieceDetailTitle")
                    Text(piece.summary).font(.subheadline).foregroundStyle(Palette.muted)
                }
                if let melody = piece.melodyPiece {
                    NavigationLink {
                        MelodyHummingView(store: store, capture: capture, piece: melody)
                    } label: {
                        MusicLibraryRow(title: "Humming", subtitle: "Record phrases and earn Notes, Timing and Clarity stars",
                                        systemImage: "waveform", footer: "Four phrases, then the whole melody")
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("melodyHummingLink")
                    NavigationLink {
                        MelodyRhythmView(store: melodyRhythmStore, capture: capture, piece: melody)
                    } label: {
                        MusicLibraryRow(title: "Rhythm", subtitle: "Tap the melody’s note starts and follow its longer notes",
                                        systemImage: "metronome", footer: "Four phrases, then the whole melody")
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("melodyRhythmLink")
                    NavigationLink {
                        MelodyReferenceView(capture: capture, piece: melody)
                    } label: {
                        MusicLibraryRow(title: "Listen & follow", subtitle: "Hear the melody or one short phrase",
                                        systemImage: "play.circle.fill", footer: "Recorded hum & cello · 60 BPM")
                    }.buttonStyle(.plain)
                        .accessibilityIdentifier("melodyReferenceLink")
                }
                VStack(alignment: .leading, spacing: 18) {
                    Text("Learning path").font(.headline).foregroundStyle(Palette.ink)
                    ForEach(Array(piece.milestones.enumerated()), id: \.offset) { index, milestone in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(index + 1)").font(.caption.weight(.semibold))
                                .foregroundStyle(Palette.forest).frame(width: 25, height: 25)
                                .background(Palette.forest.opacity(0.08), in: Circle())
                            VStack(alignment: .leading, spacing: 5) {
                                Text(milestone.title).font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                                Text(milestone.detail).font(.footnote).foregroundStyle(Palette.muted)
                            }
                        }
                    }
                }.padding(18).frame(maxWidth: .infinity, alignment: .leading)
                    .background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityIdentifier("pieceMilestones")
                VStack(alignment: .leading, spacing: 12) {
                    Text("Practise foundations").font(.headline).foregroundStyle(Palette.ink)
                    Text(piece.melodyPiece != nil ? "Build the skills behind the melody." : "These shared skills are available now. Piece-specific exercises are planned.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                    ForEach(LearningArea.allCases) { area in
                        NavigationLink {
                            foundationLessons(area)
                        } label: {
                            MusicLibraryRow(title: area.title, subtitle: areaPurpose(area),
                                            systemImage: areaSymbol(area))
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("pieceFoundation-\(area.id)")
                    }
                }
            }.padding(22).padding(.bottom, 24)
        }.background(Palette.paper)
            .navigationTitle(piece.title).navigationBarTitleDisplayMode(.inline)
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
    @ObservedObject var capture: CaptureController
    @ObservedObject var rhythmStores: RhythmStores
    let onStartLesson: (PracticeLesson) -> Void

    private var lessons: [PracticeLesson] { PracticeLesson.lessons(in: area) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(area.title).font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.ink).accessibilityIdentifier("foundationAreaTitle")
                    let completed = lessons.filter {
                        LessonState(lesson: $0, store: store, rhythmStores: rhythmStores).progress.completed
                    }.count
                    Text("\(completed) of \(lessons.count) lessons completed · Choose any lesson")
                        .font(.footnote).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("foundationCompletionSummary")
                }
                if area == .cello {
                    NavigationLink {
                        CelloIntroductionView(capture: capture)
                    } label: {
                        MusicLibraryRow(title: "Meet your cello", subtitle: "Explore the parts and hear the four strings",
                                        systemImage: "music.note", footer: "Start here · Listen and explore")
                    }.buttonStyle(.plain).accessibilityIdentifier("celloIntroductionLink")
                }
                VStack(spacing: 12) {
                    ForEach(lessons) { lesson in
                        let state = LessonState(lesson: lesson, store: store, rhythmStores: rhythmStores)
                        NavigationLink {
                            LessonDetailView(lesson: lesson, store: store, rhythmStores: rhythmStores,
                                             onStartLesson: onStartLesson)
                        } label: {
                            LessonRow(lesson: lesson, state: state)
                        }.buttonStyle(.plain)
                            .accessibilityIdentifier("lesson-\(lesson.id)")
                            .accessibilityLabel("Lesson \(lesson.number), \(lesson.title), \(state.accessibilitySummary)")
                            .accessibilityHint("Opens instructions and saved scores")
                    }
                }
                if area == .humming {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Ear training").font(.headline).foregroundStyle(Palette.ink)
                        NavigationLink {
                            EchoPracticeView(store: store, capture: capture)
                        } label: {
                            MusicLibraryRow(title: "Listen & Echo", subtitle: "Remember a short pattern and hum it back",
                                            systemImage: "ear", footer: "Two notes, then three")
                        }.buttonStyle(.plain).accessibilityIdentifier("echoPracticeLink")
                    }
                }
            }.padding(20).padding(.bottom, 24)
        }.background(Palette.paper)
            .navigationTitle(area.title).navigationBarTitleDisplayMode(.inline)
    }
}

private struct MusicLibraryRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var footer: String? = nil

    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            Image(systemName: systemImage).font(.title3).foregroundStyle(Palette.forest)
                .frame(width: 43, height: 43)
                .background(Palette.forest.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.headline).foregroundStyle(Palette.ink)
                Text(subtitle).font(.footnote).foregroundStyle(Palette.muted)
                if let footer { Text(footer).font(.caption).foregroundStyle(Palette.forest) }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.caption.weight(.semibold)).foregroundStyle(Palette.muted)
        }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 19))
            .contentShape(Rectangle())
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
            guard let section = exercise.section else {
                preconditionFailure("A recording lesson must have a pitch-target section")
            }
            let target = section.effectiveTarget(for: exercise)
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
    @ObservedObject var rhythmStores: RhythmStores
    let onStartLesson: (PracticeLesson) -> Void

    private var state: LessonState { LessonState(lesson: lesson, store: store, rhythmStores: rhythmStores) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 25) {
                VStack(alignment: .leading, spacing: 10) {
                    Text("LESSON \(String(format: "%02d", lesson.number)) · \(lesson.area.title.uppercased())")
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
