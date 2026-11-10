import Foundation

/// One thing to do on the path. Every step opens a screen that already exists;
/// the path only puts them in order.
enum PathStep: Hashable, Identifiable {
    case lesson(PracticeLesson)
    case listen(MelodyPiece)
    case tap(MelodyPiece)
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

    /// The path, in order. Adding a melody adds a level with the same four steps.
    static let path: [Level] = [
        Level(id: "firstSounds", number: 1, title: "First sounds",
              subtitle: "Hold a note, match a note and keep a beat",
              steps: [.lesson(.steadyHum), .lesson(.matchHum), .lesson(.pulse), .lesson(.twoTaps)])
    ] + MelodyPiece.allCases.enumerated().map { index, piece in
        Level(id: piece.rawValue, number: index + 2, title: piece.title, subtitle: piece.pathSubtitle,
              steps: [.listen(piece), .tap(piece), .hum(piece), .wholeMelody(piece)])
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

    /// The first step on the path that is not done yet. It is a suggestion:
    /// every step stays open.
    static func nextStep(isDone: (PathStep) -> Bool) -> (level: Level, step: PathStep)? {
        for level in path {
            if let step = level.steps.first(where: { !isDone($0) }) { return (level, step) }
        }
        return nil
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

/// Which melodies have been played on their Listen step, kept as one small
/// preference: listening has no take or round to look up.
enum ListenedMelodies {
    static let key = "listenedMelodies"

    static func contains(_ piece: MelodyPiece, in stored: String) -> Bool {
        stored.split(separator: ",").contains(Substring(piece.rawValue))
    }

    static func adding(_ piece: MelodyPiece, to stored: String) -> String {
        contains(piece, in: stored) ? stored : (stored.isEmpty ? piece.rawValue : "\(stored),\(piece.rawValue)")
    }
}
