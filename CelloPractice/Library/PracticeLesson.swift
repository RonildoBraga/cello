import Foundation

enum LessonActivity: Equatable {
    case recording(Exercise)
    case rhythm(RhythmExercise)
}

/// The ordered catalogue supplies every route, lesson number and recommendation.
/// These IDs also identify the existing lesson rows; recording JSON still uses Exercise.
enum PracticeLesson: String, CaseIterable, Identifiable {
    case steadyHum, matchHum, pulse, twoTaps, mixedRhythm

    var id: String { rawValue }

    /// A lesson with a cello side can be practised by voice or on the cello.
    var hasCelloSide: Bool { self == .steadyHum }

    var activity: LessonActivity {
        switch self {
        case .steadyHum: return .recording(.steadyHum)
        case .matchHum: return .recording(.matchHum)
        case .pulse: return .rhythm(.pulse)
        case .twoTaps: return .rhythm(.twoTaps)
        case .mixedRhythm: return .rhythm(.mixedRhythm)
        }
    }

    /// Steady note is one lesson for voice and cello; its recordings keep the
    /// names of what was recorded (Steady hum, Open G string).
    var title: String {
        switch activity {
        case .recording(let exercise): return self == .steadyHum ? "Steady note" : exercise.title
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
        case .steadyHum: return "Hold one gentle note and let it settle, with your voice or on an open string."
        case .matchHum: return "Listen to a note, remember it, then hum it back."
        case .pulse: return "Find an even beat with your hands."
        case .twoTaps: return "Keep the slow beat and add an even tap between beats."
        case .mixedRhythm: return "Switch between one tap and two taps while the beat stays steady."
        }
    }

    /// One plain line under the title of the practice screen.
    func practicePrompt(_ method: PracticeMethod = .voice) -> String {
        switch self {
        case .steadyHum: return method == .cello ? "Play one open string steadily, then tap Stop."
            : "Hum one note for three seconds."
        case .matchHum: return "Listen, then hum the same note."
        case .pulse: return "Tap an even beat."
        case .twoTaps: return "Count 1 & 2 & and tap on each."
        case .mixedRhythm: return "Count 1, 2 &, 3, 4 & and tap on each."
        }
    }

    var instructions: [String] {
        switch self {
        case .steadyHum:
            return [
                "Tap the note at the top to hear the human voice you’ll match.",
                "Keep your lips softly together and your jaw relaxed. Take an easy breath.",
                "Tap Record, count 1–2–3–4, then hum gently for three seconds. Aim towards the centre of the bar; pause between tries.",
                "With a cello, choose Cello on the practice screen and play each open string instead."
            ]
        case .matchHum:
            return [
                "Tap the note at the top whenever you want to hear the human example.",
                "Tap Record, count 1–2–3–4, then hum the same note for three seconds. Record does not play the example.",
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
                "Tap Start and count 1–2–3–4 with the app; your first tap is on the next 1. This lesson uses the Tap pad, not your voice.",
                "Count 1 and 2 and: & means “and”. Tap with each vibration on a number, then once halfway to the next vibration for “and”.",
                "Continue through 8 and, making 16 evenly spaced taps. The vibrations stay one second apart; your taps are half a second apart."
            ]
        case .mixedRhythm:
            return [
                "Tap Start and count 1–2–3–4 with the app; your first tap is on the next 1. Keep the same slow beat as Lesson 4.",
                "Tap once on 1, twice on 2-and, once on 3, twice on 4-and. Repeat with 5, 6-and, 7, 8-and. The vibration marks every number; & means “and”.",
                "Leave space after the odd numbers. Add the halfway tap only after the even numbers. This makes 12 taps across eight beats."
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
