import Foundation

/// Saved-audio observations keep their measured octave, including uncertain frames.
struct MelodyPitchPoint: Codable, Equatable, Sendable {
    let time: Double
    let frequency: Double?
    let confidence: Double
    let rms: Double
    let ambiguous: Bool
}

struct MelodyNoteResult: Codable, Equatable, Sendable {
    let expectedIndex: Int
    let expectedStart: Double
    let expectedDuration: Double
    let expectedFrequency: Double?
    let observedFrequency: Double?
    let observedOnset: Double?
    let matched: Bool
    let timed: Bool
    let clear: Bool
    let octaveMismatch: Bool
}

/// Three independent beginner goals. Uncertain sound never becomes a failed take.
struct MelodyRating: Codable, Equatable, Sendable {
    static let currentVersion = 2

    enum Status: String, Codable, Sendable { case rated, unclear, insufficientSound }

    let version: Int
    let status: Status
    let notes: Bool
    let timing: Bool
    let clarity: Bool
    let voicedDuration: Double
    let matchedNoteFraction: Double?
    let timedNoteFraction: Double?
    let clearNoteFraction: Double?
    let octaveMismatch: Bool
    let noteResults: [MelodyNoteResult]
    let pitchPoints: [MelodyPitchPoint]

    init(version: Int = currentVersion, status: Status, notes: Bool = false,
         timing: Bool = false, clarity: Bool = false, voicedDuration: Double = 0,
         matchedNoteFraction: Double? = nil, timedNoteFraction: Double? = nil,
         clearNoteFraction: Double? = nil, octaveMismatch: Bool = false,
         noteResults: [MelodyNoteResult] = [], pitchPoints: [MelodyPitchPoint] = []) {
        self.version = version
        self.status = status
        self.notes = notes
        self.timing = timing
        self.clarity = clarity
        self.voicedDuration = voicedDuration
        self.matchedNoteFraction = matchedNoteFraction
        self.timedNoteFraction = timedNoteFraction
        self.clearNoteFraction = clearNoteFraction
        self.octaveMismatch = octaveMismatch
        self.noteResults = noteResults
        self.pitchPoints = pitchPoints
    }

    var starCount: Int? {
        status == .rated ? [notes, timing, clarity].filter { $0 }.count : nil
    }

    var goalReached: Bool { starCount == 3 }

    /// One next action, rather than several competing instructions.
    var feedback: String {
        switch status {
        case .insufficientSound:
            return "Hum the whole phrase gently, keeping the longer notes going."
        case .unclear:
            return "The sound was not clear enough to score. Try a gentle hum in a quieter spot."
        case .rated:
            if octaveMismatch { return "Your hum was in a different octave. Choose a comfortable voice register and match its first note." }
            if !notes { return "Listen to this phrase again and follow each note as it changes." }
            if !timing { return "Start when the countdown ends, then follow the note lengths. Separate the quick repeated notes gently." }
            if !clarity { return "Keep a gentle, clear hum going through each note." }
            return "All three goals reached. Try this phrase again, then move to the next one."
        }
    }
}
