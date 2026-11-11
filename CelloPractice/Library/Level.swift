import Foundation

/// One thing to do on the path. Every lesson opens a screen that already exists;
/// the path only puts them in order.
enum PathLesson: Hashable, Identifiable {
    case lesson(PracticeLesson)
    case listen(MelodyPiece)
    case tap(MelodyPiece)
    case meetNotes(MelodyPiece)
    case hum(MelodyPiece)
    case wholeMelody(MelodyPiece)
    case echo

    /// Also the row's accessibility identifier.
    var id: String {
        switch self {
        case .lesson(let lesson): return "lesson-\(lesson.id)"
        case .listen(let piece): return "lesson-\(piece.rawValue)-listen"
        case .tap(let piece): return "lesson-\(piece.rawValue)-tap"
        case .meetNotes(let piece): return "lesson-\(piece.rawValue)-notes"
        case .hum(let piece): return "lesson-\(piece.rawValue)-hum"
        case .wholeMelody(let piece): return "lesson-\(piece.rawValue)-whole"
        case .echo: return "echoPracticeLink"
        }
    }

    var title: String {
        switch self {
        case .lesson(let lesson): return lesson.title
        case .listen: return "Listen"
        case .tap: return "Tap it"
        case .meetNotes: return "Meet the notes"
        case .hum: return "Hum it"
        case .wholeMelody: return "Whole melody"
        case .echo: return "Listen & Echo"
        }
    }
}

/// A numbered, titled, ordered group of lessons. The levels form the path, and
/// every lesson in the app belongs to one of them.
struct Level: Identifiable {
    let id: String
    let number: Int
    let title: String
    let lessons: [PathLesson]

    /// The path, in order. Adding a melody adds a level with the same five lessons.
    static let path: [Level] = {
        let firstSounds = Level(id: "firstSounds", number: 1, title: "First sounds",
                                lessons: [.lesson(.steadyHum), .lesson(.matchHum), .lesson(.pulse),
                                        .lesson(.twoTaps), .lesson(.mixedRhythm), .echo])
        let melodies = MelodyPiece.allCases.enumerated().map { index, piece in
            Level(id: piece.rawValue, number: index + 2, title: piece.title,
                  lessons: [.listen(piece), .tap(piece), .meetNotes(piece), .hum(piece), .wholeMelody(piece)])
        }
        return [firstSounds] + melodies
    }()

    /// The first lesson on the path that has not been passed yet. It is a
    /// suggestion: every lesson stays open.
    static func nextLesson(isPassed: (PathLesson) -> Bool) -> (level: Level, lesson: PathLesson)? {
        for level in path {
            if let step = level.lessons.first(where: { !isPassed($0) }) { return (level, step) }
        }
        return nil
    }

    /// Today's practice: the next lesson, then the passed lessons with the lowest best
    /// score, earliest first. A lesson leaves the list once it reaches three stars,
    /// so the list changes as the practice is done. Unscored lessons are never reviewed.
    static func today(isPassed: (PathLesson) -> Bool, stars: (PathLesson) -> Int?, reviews: Int = 2) -> [PathLesson] {
        let weakest = path.flatMap(\.lessons).enumerated().compactMap { index, lesson in
            stars(lesson).flatMap { $0 < CompletionRule.goldStars && isPassed(lesson) ? (lesson, $0, index) : nil }
        }.sorted { ($0.1, $0.2) < ($1.1, $1.2) }.prefix(reviews).map(\.0)
        return [nextLesson(isPassed: isPassed)?.lesson].compactMap { $0 } + weakest
    }

    /// Where a lesson sits in its level, and its neighbours there.
    static func position(of step: PathLesson) -> LessonPosition? {
        for level in path {
            guard let index = level.lessons.firstIndex(of: step) else { continue }
            let nextLevel = path.first { $0.number == level.number + 1 }
            return LessonPosition(level: level, index: index,
                                  previous: index > 0 ? level.lessons[index - 1] : nil,
                                  next: index + 1 < level.lessons.count ? level.lessons[index + 1] : nil,
                                  nextLevel: index + 1 < level.lessons.count ? nil : nextLevel)
        }
        return nil
    }

    func passedLessons(isPassed: (PathLesson) -> Bool) -> Int { lessons.filter(isPassed).count }
}

/// A lesson's place in its level. Previous and next stay inside the level.
struct LessonPosition {
    let level: Level
    let index: Int
    let previous: PathLesson?
    let next: PathLesson?
    /// Set at the last lesson of a level: the level that follows, if any.
    let nextLevel: Level?

    /// Where Next leads: the next lesson here, or the first lesson of the next level.
    var onward: PathLesson? { next ?? nextLevel?.lessons.first }
    /// What Next is called: a lesson's title, or the level it starts.
    var onwardTitle: String? { next?.title ?? nextLevel?.title }
    var onwardSpoken: String? {
        next.map { "Next lesson, \($0.title)" } ?? nextLevel.map { "Next level, \($0.title)" }
    }

    var label: String { "Lesson \(index + 1) of \(level.lessons.count)" }
}

/// How far a lesson has got, rolled up from its parts: one part for a lesson or
/// the whole melody, four for a lesson practised phrase by phrase or string by string.
struct LessonProgress: Equatable {
    private let parts: [PracticeProgress]
    var passedParts: Int { parts.filter(\.passed).count }
    var goldParts: Int { parts.filter(\.completed).count }
    var totalParts: Int { parts.count }
    /// What the parts are called when there are several: phrases or notes.
    let partNoun: String
    /// Something has been tried, even if nothing has passed yet.
    let started: Bool

    init(_ parts: [PracticeProgress], started: Bool = false, partNoun: String = "phrases") {
        self.partNoun = partNoun
        self.parts = parts
        self.started = started || parts.contains { $0.passed || $0.successfulAttempts > 0 }
    }

    /// Passed moves the path on; gold is every part's earned milestone.
    var passed: Bool { totalParts > 0 && passedParts == totalParts }
    var gold: Bool { totalParts > 0 && goldParts == totalParts }

    /// The score to show: a single part's best, or the weakest best across
    /// several parts, so three stars means every phrase reached three.
    var bestStars: Int { parts.map { $0.bestStars ?? 0 }.min() ?? 0 }

    var status: String {
        if gold { return "Gold" }
        if passed { return "Passed" }
        if totalParts > 1 { return "\(passedParts) of \(totalParts) \(partNoun) passed" }
        return started ? "In progress" : "Not started"
    }
}

/// A small set of identifiers kept as one preference string. The path uses it
/// for the things no take or round records: which melodies have been heard to
/// the end, and which primers have been read.
enum StoredIDs {
    static let listenedMelodies = "listenedMelodies"
    static let seenPrimers = "seenPrimers"

    static func contains(_ id: String, in stored: String) -> Bool {
        stored.split(separator: ",").contains(Substring(id))
    }

    static func adding(_ id: String, to stored: String) -> String {
        contains(id, in: stored) ? stored : (stored.isEmpty ? id : "\(stored),\(id)")
    }
}
