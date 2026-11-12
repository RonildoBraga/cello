import CelloPitch
import Foundation

/// What the path shows about one lesson.
struct LessonSummary {
    let progress: LessonProgress
    let status: String
    /// The best score out of three; nil for lessons that are not scored, such as Listen.
    let stars: Int?
    /// The lesson has got further on the cello than by voice.
    var onCello = false

    init(progress: LessonProgress, status: String? = nil, stars: Int?) {
        self.progress = progress
        self.status = status ?? progress.status
        self.stars = stars
    }

    /// A scored lesson shows the weakest best score across its parts. Either
    /// method passes a lesson, and the path shows the one that has got further.
    init(voice: LessonProgress, cello: LessonProgress? = nil, voiceStars: Int? = nil) {
        if let cello, cello.passed && !voice.gold || cello.started && !voice.started {
            self.init(progress: cello, stars: cello.bestStars)
            onCello = true
        } else {
            self.init(progress: voice, stars: voiceStars ?? voice.bestStars)
        }
    }

    var spokenScore: String? {
        stars.map { $0 > 0 ? "Best score \($0) of 3 stars" : "No score yet" }
    }
}

/// How far every lesson on the path has got. It is read from the stores once
/// for each drawing of the path, and the rows, Today's practice and the lesson
/// bar all share that one reading.
struct PathProgress {
    private let summaries: [PathLesson: LessonSummary]

    @MainActor
    init(store: SessionStore, rhythmStores: RhythmStores, melodyRhythmStore: MelodyRhythmStore, listened: String) {
        func melody(_ parts: (MelodyRegister) -> [MelodyPracticeContext], noun: String = "phrases") -> LessonSummary {
            func progress(_ register: MelodyRegister) -> LessonProgress {
                LessonProgress(parts(register).map(store.melodyProgress), partNoun: noun)
            }
            return LessonSummary(voice: progress(.lowVoice), cello: progress(.cello))
        }
        // The cello's side of a single-note lesson: the four open strings. As for a
        // hummed note, any saved take of a string is a start, whatever it scored.
        let stringStates = PracticeMethod.openStrings.map { LessonState(exercise: $0, store: store) }
        let strings = LessonProgress(stringStates.map(\.progress), started: stringStates.contains(where: \.hasAttempts),
                                     partNoun: "strings")

        summaries = Dictionary(uniqueKeysWithValues: Level.path.flatMap(\.lessons).map { lesson -> (PathLesson, LessonSummary) in
            switch lesson {
            case .lesson(let practice):
                let state = LessonState(lesson: practice, store: store, rhythmStores: rhythmStores)
                return (lesson, LessonSummary(voice: state.step, cello: practice.isRecorded ? strings : nil,
                                              voiceStars: state.bestStars ?? 0))
            case .listen(let piece):
                let heard = StoredIDs.contains(piece.rawValue, in: listened)
                let progress = LessonProgress([PracticeProgress(successfulAttempts: 0, completed: false, passed: heard)])
                return (lesson, LessonSummary(progress: progress, status: heard ? "Listened" : "Not heard yet", stars: nil))
            case .tap(let piece):
                return (lesson, LessonSummary(voice: LessonProgress(MelodySection.phrases.map {
                    melodyRhythmStore.progress(for: piece.rhythm(section: $0))
                })))
            case .meetNotes(let piece):
                // Every note needs a passing take; the two pairs are extra practice.
                return (lesson, melody({ NoteDrill.notes(for: piece, register: $0).map(\.context) }, noun: "notes"))
            case .hum(let piece):
                return (lesson, melody { register in
                    MelodySection.phrases.map { piece.humming(register: register, section: $0) }
                })
            case .wholeMelody(let piece):
                return (lesson, melody { [piece.humming(register: $0, section: .whole)] })
            case .echo:
                return (lesson, LessonSummary(voice: LessonProgress([store.echoProgress(for: .twoNotes, register: .lowVoice)]),
                                              cello: LessonProgress([store.echoProgress(for: .twoNotes, register: .cello)])))
            }
        })
    }

    subscript(lesson: PathLesson) -> LessonSummary {
        summaries[lesson] ?? LessonSummary(progress: LessonProgress([]), stars: nil)
    }

    func isPassed(_ lesson: PathLesson) -> Bool { self[lesson].progress.passed }

    /// The first lesson on the path that has not been passed yet.
    var next: (level: Level, lesson: PathLesson)? { Level.nextLesson(isPassed: isPassed) }

    /// The next lesson, then the passed lessons with the lowest best score.
    var today: [PathLesson] { Level.today(isPassed: isPassed) { self[$0].stars } }
}

/// One foundation lesson's scores, from its recordings or its tapping rounds.
@MainActor
struct LessonState {
    let progress: PracticeProgress
    let bestStars: Int?
    let latestStars: Int?
    let hasAttempts: Bool

    init(lesson: PracticeLesson, store: SessionStore, rhythmStores: RhythmStores) {
        switch lesson.activity {
        case .recording(let exercise):
            self.init(exercise: exercise, store: store)
        case .rhythm(let exercise):
            let rhythmStore = rhythmStores.store(for: exercise)
            let progress = rhythmStore.progress
            self.init(progress: progress, bestStars: rhythmStore.bestStars,
                      latestStars: rhythmStore.attempts.compactMap(\.starCount).first,
                      hasAttempts: !rhythmStore.attempts.isEmpty || progress.completed)
        }
    }

    /// One recorded note's scores: a hummed note, or an open string.
    init(exercise: Exercise, store: SessionStore) {
        let target = VoicePracticeMode.note(exercise).targetFrequency
        let progress = store.progress(for: exercise, targetFrequency: target)
        let scores = LessonScoreSummary(exercise: exercise, targetFrequency: target,
                                        sessions: store.sessions, completed: progress.completed)
        // A pass or gold outlives its takes, so the best score comes from the progress.
        self.init(progress: progress, bestStars: progress.bestStars, latestStars: scores.latestStars,
                  hasAttempts: scores.hasAttempts)
    }

    private init(progress: PracticeProgress, bestStars: Int?, latestStars: Int?, hasAttempts: Bool) {
        self.progress = progress
        self.bestStars = bestStars
        self.latestStars = latestStars
        self.hasAttempts = hasAttempts
    }

    var step: LessonProgress { LessonProgress([progress], started: hasAttempts) }
}
