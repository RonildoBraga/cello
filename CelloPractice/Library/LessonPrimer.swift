import Foundation

/// One new idea, explained in plain words with something to hear or feel,
/// shown before the first lesson that needs it. A primer is never scored.
struct LessonPrimer: Equatable {
    enum Demo: Equatable {
        /// The recorded hum the first lessons use.
        case hum
        /// A lower note, then a higher one.
        case twoNotes
        /// Counts shown one at a time, each with a vibration.
        case beats([BeatCue])
    }

    struct BeatCue: Equatable {
        let label: String
        /// Time until the next cue.
        let seconds: Double
        /// A whole beat, as opposed to the "and" between beats.
        let onBeat: Bool
    }

    let title: String
    let paragraphs: [String]
    let demoLabel: String
    let demo: Demo
}

extension PracticeLesson {
    /// The idea this lesson introduces, when it is the first to need one.
    var primer: LessonPrimer? {
        switch self {
        case .steadyHum:
            return LessonPrimer(title: "A note", paragraphs: [
                "A note is one sound you can hold, like the “mmm” you make when something tastes good. Every melody is made of notes.",
                "How high or low a note sounds is called its pitch. On the practice screen a bar shows how close your pitch is to the note you are aiming for.",
                "Small distances in pitch are counted in cents. The centre of the bar is 0 cents: exactly on the note."
            ], demoLabel: "Hear a note", demo: .hum)
        case .matchHum:
            return LessonPrimer(title: "Higher and lower", paragraphs: [
                "Notes can be higher or lower, like steps on a ladder. A small bird sings high; a big dog barks low.",
                "You will hear two notes. The second one is higher than the first.",
                "Matching a note means humming at the same height: not higher, not lower. If the bar says you are below the note, hum a little higher."
            ], demoLabel: "Hear two notes", demo: .twoNotes)
        case .pulse:
            return LessonPrimer(title: "A beat", paragraphs: [
                "A beat is a steady pulse, like a clock ticking or even footsteps. Music is counted in beats: 1, 2, 3, 4.",
                "Here the beats are one second apart. That speed is written 60 BPM: 60 beats per minute.",
                "Your phone vibrates on every beat. Feel four of them before you start tapping."
            ], demoLabel: "Feel four beats",
                                demo: .beats((1...4).map { .init(label: "\($0)", seconds: 1, onBeat: true) }))
        case .twoTaps:
            return LessonPrimer(title: "Two taps per beat", paragraphs: [
                "Two even taps fit inside one beat. Count “1 and 2 and”: tap on the number, then again halfway to the next number, on “and”.",
                "The & sign means “and”. The beat itself does not get faster; you only add a tap in the middle.",
                "Watch the count. Your phone vibrates on the numbers, not on the &."
            ], demoLabel: "See the pattern",
                                demo: .beats((1...4).flatMap {
                                    [LessonPrimer.BeatCue(label: "\($0)", seconds: 0.5, onBeat: true),
                                     LessonPrimer.BeatCue(label: "&", seconds: 0.5, onBeat: false)]
                                }))
        case .mixedRhythm, .openC, .openG, .openD, .openA:
            return nil
        }
    }
}
