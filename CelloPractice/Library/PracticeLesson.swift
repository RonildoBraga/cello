import Foundation

enum LessonActivity: Equatable {
    case recording(Exercise)
    case rhythm(RhythmExercise)
}

/// The ordered catalogue supplies every route, lesson number and recommendation.
/// These IDs also identify the existing lesson rows; recording JSON still uses Exercise.
enum PracticeLesson: String, CaseIterable, Identifiable {
    case steadyHum, matchHum, pulse, twoTaps, mixedRhythm
    case openC, openG, openD, openA

    var id: String { rawValue }

    var area: LearningArea {
        switch self {
        case .steadyHum, .matchHum: return .humming
        case .pulse, .twoTaps, .mixedRhythm: return .rhythm
        case .openC, .openG, .openD, .openA: return .cello
        }
    }

    var activity: LessonActivity {
        switch self {
        case .steadyHum: return .recording(.steadyHum)
        case .matchHum: return .recording(.matchHum)
        case .pulse: return .rhythm(.pulse)
        case .twoTaps: return .rhythm(.twoTaps)
        case .mixedRhythm: return .rhythm(.mixedRhythm)
        case .openC: return .recording(.openC)
        case .openG: return .recording(.openG)
        case .openD: return .recording(.openD)
        case .openA: return .recording(.openA)
        }
    }

    static func lessons(in area: LearningArea) -> [PracticeLesson] {
        allCases.filter { $0.area == area }
    }

    /// Retain the original foundation numbers and route across Humming/Rhythm.
    /// Moving a lesson into a navigation area never changes its saved identity.
    private var progression: [PracticeLesson] {
        Self.allCases.filter { ($0.area == .cello) == (area == .cello) }
    }

    var number: Int {
        progression.firstIndex(of: self)! + 1
    }

    var next: PracticeLesson? {
        let lessons = progression
        let index = number
        return lessons.indices.contains(index) ? lessons[index] : nil
    }

    var title: String {
        switch activity {
        case .recording(let exercise): return exercise.title
        case .rhythm(let exercise): return exercise.title
        }
    }

    var attemptNoun: String {
        switch activity {
        case .recording: return "takes"
        case .rhythm: return "rounds"
        }
    }

    var purpose: String {
        switch self {
        case .steadyHum: return "Hold one gentle note and let it settle."
        case .matchHum: return "Listen to a note, remember it, then hum it back."
        case .pulse: return "Find an even beat with your hands."
        case .twoTaps: return "Keep the slow beat and add an even tap between beats."
        case .mixedRhythm: return "Switch between one tap and two taps while the beat stays steady."
        case .openC, .openG, .openD, .openA: return "Play one open string with an even, steady sound."
        }
    }

    var shortPurpose: String {
        switch self {
        case .steadyHum: return "Hold one note"
        case .matchHum: return "Listen, then hum it back"
        case .pulse: return "Keep an even beat"
        case .twoTaps: return "Count 1 & 2 &"
        case .mixedRhythm: return "Count 1, 2 &, 3, 4 &"
        case .openC, .openG, .openD, .openA: return "One string, one steady sound"
        }
    }

    var practicePrompt: String {
        let prompt: String
        switch self {
        case .steadyHum: prompt = "3-second hum"
        case .matchHum: prompt = "Listen, then hum"
        case .pulse: prompt = "Keep an even beat"
        case .twoTaps: prompt = "Count 1 & 2 &"
        case .mixedRhythm: prompt = "Count 1, 2 &, 3, 4 &"
        case .openC, .openG, .openD, .openA: prompt = "Play, then tap Stop"
        }
        return "Lesson \(number) · \(prompt)"
    }

    var instructions: [String] {
        switch self {
        case .steadyHum:
            return [
                "Tap Hear hum to listen to the human voice you’ll match.",
                "Keep your lips softly together and your jaw relaxed. Take an easy breath.",
                "Tap Record, follow 3–2–1, then hum gently for three seconds. Aim towards the centre of the bar; pause between tries."
            ]
        case .matchHum:
            return [
                "Tap Hear hum whenever you want to hear the human example.",
                "Tap Record, follow 3–2–1, then hum the same note for three seconds. Record does not play the example.",
                "Keep your lips softly together and your voice gentle. The bar follows the same note you heard."
            ]
        case .pulse:
            return [
                "Start the pulse and watch four count-in beats.",
                "Tap the large pad for 16 beats. Each beat is one second apart.",
                "Keep the gaps between taps even. This lesson uses taps, so there’s no voice recording."
            ]
        case .twoTaps:
            return [
                "Tap Start and wait through 4–3–2–1 before tapping. This lesson uses the Tap pad, not your voice.",
                "Count 1 and 2 and: & means “and”. Tap with each vibration on a number, then once halfway to the next vibration for “and”.",
                "Continue through 8 and, making 16 evenly spaced taps. The vibrations stay one second apart; your taps are half a second apart."
            ]
        case .mixedRhythm:
            return [
                "Tap Start and wait through 4–3–2–1. Keep the same slow beat as Lesson 4.",
                "Tap once on 1, twice on 2-and, once on 3, twice on 4-and. Repeat with 5, 6-and, 7, 8-and. The vibration marks every number; & means “and”.",
                "Leave space after the odd numbers. Add the halfway tap only after the even numbers. This makes 12 taps across eight beats."
            ]
        case .openC, .openG, .openD, .openA:
            let string: String
            switch self {
            case .openC: string = "C"
            case .openG: string = "G"
            case .openD: string = "D"
            case .openA: string = "A"
            default: preconditionFailure("Only an open-string lesson has string instructions")
            }
            return [
                "Settle your cello and bow using the position your teacher shows you.",
                "Play the \(string) string alone, without pressing it with a finger. Hear string plays its reference note.",
                "Tap Record, follow 3–2–1, then play an even note. Tap Stop to finish."
            ]
        }
    }

    var goals: [(title: String, detail: String)] {
        if self == .mixedRhythm {
            return [("Pattern", "Tap at least nine of the 12 places, with no more than one extra tap."),
                    ("Timing", "Land close to each tap’s place in the pattern."),
                    ("Evenness", "Keep your timing steady as the gaps change.")]
        }
        switch activity {
        case .recording:
            return [("Match", "Stay close to the target note."),
                    ("Steady", "Keep the note even, without wobbling."),
                    ("Hold", "Keep a clear note going for two seconds.")]
        case .rhythm:
            return [("Find the beat", "Land close to each tap’s place in the pulse."),
                    ("Keep it even", "Leave steady gaps between taps."),
                    ("Stay with it", "Tap at least 12 of the 16 taps.")]
        }
    }
}

/// Only saved ratings for this exact lesson, reference and scoring version are scores.
/// Raw tuning measurements and legacy recordings never become star ratings here.
struct LessonScoreSummary {
    let hasAttempts: Bool
    let bestStars: Int?
    let latestStars: Int?

    init(exercise: Exercise, targetFrequency: Double, sessions: [PracticeSession], completed: Bool) {
        let matchingSessions = sessions.filter {
            $0.exercise == exercise && $0.effectiveTargetFrequency == targetFrequency
        }
        hasAttempts = !matchingSessions.isEmpty || completed
        let scores = matchingSessions.filter {
            guard let rating = $0.rating else { return false }
            return rating.version == PracticeRating.currentVersion && rating.status == .rated
                && rating.targetFrequency == $0.effectiveTargetFrequency
        }.sorted {
            if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
            return $0.id.uuidString > $1.id.uuidString
        }.compactMap { $0.rating?.starCount }
        // The persisted milestone proves three-star takes were earned, even if
        // their recordings were later deleted. It does not prove a latest score.
        bestStars = completed ? 3 : scores.max()
        latestStars = scores.first
    }
}
