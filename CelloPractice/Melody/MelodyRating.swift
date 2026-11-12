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
    /// Version 3 hears a fresh start in a dip, judges pitch once a note has settled and
    /// gives quick notes room for their starts. Earlier takes keep the scores they were given.
    static let currentVersion = 3
    /// Progress belongs to the lesson, not to the rules of the day. Takes scored under these
    /// versions count towards the same passes and gold, kept under the key version 2 wrote.
    static let progressVersions = 2...3

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

    /// Names the first note whose timing was off, how far, and what to do.
    var timingAdvice: String? {
        guard let note = noteResults.first(where: { $0.expectedFrequency != nil && !$0.timed }),
              let frequency = note.expectedFrequency, let onset = note.observedOnset else { return nil }
        let position = noteResults.filter { $0.expectedFrequency != nil }.firstIndex(of: note) ?? 0
        let name = "\(position == 0 ? "The first note" : "Note \(position + 1)") "
            + "(\(NoteName.frequency(frequency)))"
        let offset = onset - note.expectedStart
        // The same allowance the rating uses for a note's start.
        guard abs(offset) > min(0.20, note.expectedDuration * 0.35) else {
            return "\(name) stopped too soon. Hold it until its bar has passed the line."
        }
        let amount = String(format: "%.1f", abs(offset))
        return "\(name) started \(amount) s \(offset > 0 ? "late" : "early"). "
            + (position == 0 ? "Start as its bar reaches the line, right after the count of 4."
               : "Change as its bar reaches the line.")
    }

    /// Names the first note whose pitch was off and which way to move it.
    var notesAdvice: String? {
        guard let note = noteResults.first(where: { $0.expectedFrequency != nil && !$0.matched }),
              let expected = note.expectedFrequency, let observed = note.observedFrequency else { return nil }
        let position = noteResults.filter { $0.expectedFrequency != nil }.firstIndex(of: note) ?? 0
        let name = "\(position == 0 ? "The first note" : "Note \(position + 1)") (\(NoteName.frequency(expected)))"
        let cents = 1_200 * log2(observed / expected)
        guard abs(cents) >= 60 else {
            // Near enough on the whole. A note heard clearly for most of its length missed
            // because it moved about; one that was not may only have been cut short, and
            // the saved result cannot tell, so the general advice stays.
            return note.clear ? "\(name) wavered. Find it, then keep it steady." : nil
        }
        let amount = abs(cents) < 120 ? "a little too" : "too"
        return "\(name) was \(amount) \(cents < 0 ? "low" : "high"). "
            + (position == 0 ? "Hear the start again and begin on its pitch." : "Aim \(cents < 0 ? "higher" : "lower") on that note.")
    }

    /// Says so when some notes were not heard as notes of their own, which no pitch advice can mend.
    var heardAdvice: String? {
        let asked = noteResults.filter { $0.expectedFrequency != nil }
        let heard = asked.filter { $0.observedOnset != nil }.count
        guard heard > 0, heard < asked.count else { return nil }
        return "\(heard) of the \(asked.count) notes were heard. Give each note a clear start of its own."
    }

    /// One next action, rather than several competing instructions.
    var feedback: String {
        switch status {
        case .insufficientSound:
            return "Go through the whole phrase gently, keeping the longer notes going."
        case .unclear:
            return "The sound was not clear enough to score. Try again gently, in a quieter spot."
        case .rated:
            if octaveMismatch { return "That was in a different octave. Hear the reference again and match its first note." }
            if !notes || !timing, let heardAdvice { return heardAdvice }
            if !notes { return notesAdvice ?? "Listen to this phrase again and follow each note as it changes." }
            if !timing {
                return timingAdvice ?? "Start as the first bar reaches the line, then follow the note lengths. Give each quick note a clear start and keep it going until the next."
            }
            if !clarity { return "Keep a gentle, clear sound going through each note." }
            return "All three goals reached. Try this phrase again, then move to the next one."
        }
    }
}
