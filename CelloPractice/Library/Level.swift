import Foundation

/// One thing to do on the path. Every step opens a screen that already exists;
/// the path only puts them in order.
enum PathStep: Hashable, Identifiable {
    case lesson(PracticeLesson)
    case listen(MelodyPiece)
    case tap(MelodyPiece)
    case meetNotes(MelodyPiece)
    case hum(MelodyPiece)
    case wholeMelody(MelodyPiece)
    case celloIntroduction
    case echo

    /// Also the row's accessibility identifier.
    var id: String {
        switch self {
        case .lesson(let lesson): return "lesson-\(lesson.id)"
        case .listen(let piece): return "step-\(piece.rawValue)-listen"
        case .tap(let piece): return "step-\(piece.rawValue)-tap"
        case .meetNotes(let piece): return "step-\(piece.rawValue)-notes"
        case .hum(let piece): return "step-\(piece.rawValue)-hum"
        case .wholeMelody(let piece): return "step-\(piece.rawValue)-whole"
        case .celloIntroduction: return "celloIntroductionLink"
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
        case .celloIntroduction: return "Meet your cello"
        case .echo: return "Listen & Echo"
        }
    }
}

/// A numbered, titled, ordered group of steps. The levels form the path, and
/// every step in the app belongs to one of them.
struct Level: Identifiable {
    let id: String
    let number: Int
    let title: String
    let steps: [PathStep]

    /// The path, in order. Adding a melody adds a level with the same five steps.
    static let path: [Level] = {
        let firstSounds = Level(id: "firstSounds", number: 1, title: "First sounds",
                                steps: [.lesson(.steadyHum), .lesson(.matchHum), .lesson(.pulse),
                                        .lesson(.twoTaps), .lesson(.mixedRhythm), .echo])
        let melodies = MelodyPiece.allCases.enumerated().map { index, piece in
            Level(id: piece.rawValue, number: index + 2, title: piece.title,
                  steps: [.listen(piece), .tap(piece), .meetNotes(piece), .hum(piece), .wholeMelody(piece)])
        }
        // Last, because it needs an instrument; like every step it can be opened at any time.
        let cello = Level(id: "cello", number: melodies.count + 2, title: "Cello · open strings",
                          steps: [.celloIntroduction] + PracticeLesson.lessons(in: .cello).map(PathStep.lesson))
        return [firstSounds] + melodies + [cello]
    }()

    /// The first step on the path that has not been passed yet. It is a
    /// suggestion: every step stays open.
    static func nextStep(isPassed: (PathStep) -> Bool) -> (level: Level, step: PathStep)? {
        for level in path {
            if let step = level.steps.first(where: { !isPassed($0) }) { return (level, step) }
        }
        return nil
    }

    /// Where a step sits in its level, and its neighbours there.
    static func position(of step: PathStep) -> StepPosition? {
        for level in path {
            guard let index = level.steps.firstIndex(of: step) else { continue }
            return StepPosition(level: level, index: index,
                                previous: index > 0 ? level.steps[index - 1] : nil,
                                next: index + 1 < level.steps.count ? level.steps[index + 1] : nil)
        }
        return nil
    }

    func passedSteps(isPassed: (PathStep) -> Bool) -> Int { steps.filter(isPassed).count }

    /// A level is complete when every one of its steps has been passed.
    func isComplete(isPassed: (PathStep) -> Bool) -> Bool { steps.allSatisfy(isPassed) }

    /// The furthest complete level whose completion has not been shown yet.
    static func newlyCompleted(celebrated: String, isPassed: (PathStep) -> Bool) -> Level? {
        path.last { $0.isComplete(isPassed: isPassed) && !StoredIDs.contains($0.id, in: celebrated) }
    }
}

/// A step's place in its level. Previous and next stay inside the level.
struct StepPosition {
    let level: Level
    let index: Int
    let previous: PathStep?
    let next: PathStep?

    var label: String { "Step \(index + 1) of \(level.steps.count)" }
}

/// How far a step has got, rolled up from its parts: one part for a lesson or
/// the whole melody, four for a step practised phrase by phrase.
struct StepProgress: Equatable {
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
/// the end, which finished levels have been celebrated and which primers and
/// introductions have been read.
enum StoredIDs {
    static let listenedMelodies = "listenedMelodies"
    static let celebratedLevels = "celebratedLevels"
    static let seenPrimers = "seenPrimers"
    /// Stored with the read primers: Meet your cello is read once, like them.
    static let celloIntroduction = "celloIntroduction"

    static func contains(_ id: String, in stored: String) -> Bool {
        stored.split(separator: ",").contains(Substring(id))
    }

    static func adding(_ id: String, to stored: String) -> String {
        contains(id, in: stored) ? stored : (stored.isEmpty ? id : "\(stored),\(id)")
    }
}
