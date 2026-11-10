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

    var subtitle: String {
        switch self {
        case .lesson(let lesson): return lesson.shortPurpose
        case .listen: return "Hear the melody and follow its notes"
        case .tap: return "Tap the rhythm, one phrase at a time"
        case .meetNotes: return "Hear each note and hum it back"
        case .hum: return "Record each phrase and earn stars"
        case .wholeMelody: return "Join the four phrases and hum it through"
        case .celloIntroduction: return "Explore the parts and hear the four strings"
        case .echo: return "Remember a short pattern and hum it back"
        }
    }

    var symbol: String {
        switch self {
        case .lesson(let lesson):
            switch lesson.area {
            case .humming: return "waveform"
            case .rhythm: return "metronome"
            case .cello: return "music.note"
            }
        case .listen: return "play.circle.fill"
        case .tap: return "metronome"
        case .meetNotes: return "music.note"
        case .hum: return "waveform"
        case .wholeMelody: return "music.note.list"
        case .celloIntroduction: return "music.note"
        case .echo: return "ear"
        }
    }
}

/// A titled, ordered group of steps. Numbered levels form the path; the others
/// sit below it and never decide what comes next.
struct Level: Identifiable {
    let id: String
    let number: Int?
    let title: String
    let subtitle: String
    let steps: [PathStep]

    /// The path, in order. Adding a melody adds a level with the same five steps.
    static let path: [Level] = [
        Level(id: "firstSounds", number: 1, title: "First sounds",
              subtitle: "Hold a note, match a note and keep a beat",
              steps: [.lesson(.steadyHum), .lesson(.matchHum), .lesson(.pulse), .lesson(.twoTaps)])
    ] + MelodyPiece.allCases.enumerated().map { index, piece in
        Level(id: piece.rawValue, number: index + 2, title: piece.title, subtitle: piece.pathSubtitle,
              steps: [.listen(piece), .tap(piece), .meetNotes(piece), .hum(piece), .wholeMelody(piece)])
    }

    /// Open to everyone, but off the path: the cello waits for an instrument,
    /// and the extras are for when you want more of something.
    static let extras: [Level] = [
        Level(id: "cello", number: nil, title: "Cello · open strings",
              subtitle: "For when you have a cello in your hands",
              steps: [.celloIntroduction] + PracticeLesson.lessons(in: .cello).map(PathStep.lesson)),
        Level(id: "more", number: nil, title: "More practice",
              subtitle: "Extra rhythm and ear training",
              steps: [.lesson(.mixedRhythm), .echo])
    ]

    /// The first step on the path that has not been passed yet. It is a
    /// suggestion: every step stays open.
    static func nextStep(isPassed: (PathStep) -> Bool) -> (level: Level, step: PathStep)? {
        for level in path {
            if let step = level.steps.first(where: { !isPassed($0) }) { return (level, step) }
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

/// How far a step has got, rolled up from its parts: one part for a lesson or
/// the whole melody, four for a step practised phrase by phrase.
struct StepProgress: Equatable {
    let passedParts: Int
    let goldParts: Int
    let totalParts: Int
    /// What the parts are called when there are several: phrases or notes.
    let partNoun: String
    /// Something has been tried, even if nothing has passed yet.
    let started: Bool

    init(_ parts: [PracticeProgress], started: Bool = false, partNoun: String = "phrases") {
        self.partNoun = partNoun
        passedParts = parts.filter(\.passed).count
        goldParts = parts.filter(\.completed).count
        totalParts = parts.count
        self.started = started || parts.contains { $0.passed || $0.successfulAttempts > 0 }
    }

    /// Passed moves the path on; gold is every part's earned milestone.
    var passed: Bool { totalParts > 0 && passedParts == totalParts }
    var gold: Bool { totalParts > 0 && goldParts == totalParts }

    var status: String {
        if gold { return "Gold" }
        if passed { return "Passed" }
        if totalParts > 1 { return "\(passedParts) of \(totalParts) \(partNoun) passed" }
        return started ? "In progress" : "Not started"
    }
}

private extension MelodyPiece {
    var pathSubtitle: String {
        switch self {
        case .hotCrossBuns: return "A first three-note melody"
        case .odeToJoy: return "A five-note opening · Beethoven"
        }
    }
}

/// A small set of identifiers kept as one preference string. The path uses it
/// for the things no take or round records: which melodies have been heard to
/// the end, which finished levels have been celebrated and which primers read.
enum StoredIDs {
    static let listenedMelodies = "listenedMelodies"
    static let celebratedLevels = "celebratedLevels"
    static let seenPrimers = "seenPrimers"

    static func contains(_ id: String, in stored: String) -> Bool {
        stored.split(separator: ",").contains(Substring(id))
    }

    static func adding(_ id: String, to stored: String) -> String {
        contains(id, in: stored) ? stored : (stored.isEmpty ? id : "\(stored),\(id)")
    }
}
