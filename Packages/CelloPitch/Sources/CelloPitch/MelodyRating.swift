import Foundation

/// Saved-audio observations keep their measured octave, including uncertain frames.
public struct MelodyPitchPoint: Codable, Equatable, Sendable {
    public let time: Double
    public let frequency: Double?
    public let confidence: Double
    public let rms: Double
    public let ambiguous: Bool

    public init(time: Double, frequency: Double?, confidence: Double, rms: Double, ambiguous: Bool) {
        self.time = time
        self.frequency = frequency
        self.confidence = confidence
        self.rms = rms
        self.ambiguous = ambiguous
    }
}

public struct MelodyNoteResult: Codable, Equatable, Sendable {
    public let expectedIndex: Int
    public let expectedStart: Double
    public let expectedDuration: Double
    public let expectedFrequency: Double?
    public let observedFrequency: Double?
    public let observedOnset: Double?
    public let matched: Bool
    public let timed: Bool
    public let clear: Bool
    public let octaveMismatch: Bool

    public init(expectedIndex: Int, expectedStart: Double, expectedDuration: Double,
                expectedFrequency: Double?, observedFrequency: Double?, observedOnset: Double?,
                matched: Bool, timed: Bool, clear: Bool, octaveMismatch: Bool) {
        self.expectedIndex = expectedIndex
        self.expectedStart = expectedStart
        self.expectedDuration = expectedDuration
        self.expectedFrequency = expectedFrequency
        self.observedFrequency = observedFrequency
        self.observedOnset = observedOnset
        self.matched = matched
        self.timed = timed
        self.clear = clear
        self.octaveMismatch = octaveMismatch
    }
}

/// A sound in a take that was no note of the melody and too short to be one: the voice
/// sliding the wrong way before a change, or a knock. It costs no star.
public struct MelodyStray: Codable, Equatable, Sendable {
    public let time: Double
    /// Where its pitch was, when it had one.
    public let frequency: Double?

    public init(time: Double, frequency: Double?) {
        self.time = time
        self.frequency = frequency
    }
}

/// Three independent beginner goals. Uncertain sound never becomes a failed take.
public struct MelodyRating: Codable, Equatable, Sendable {
    /// Version 3 hears a fresh start in a dip, judges pitch once a note has settled and
    /// gives quick notes room for their starts. Earlier takes keep the scores they were given.
    /// Version 4 pairs each heard note with the asked note it was, so a stray sound or a missed
    /// note no longer sets every later note against the wrong one.
    public static let currentVersion = 4
    /// Progress belongs to the lesson, not to the rules of the day. Takes scored under these
    /// versions count towards the same passes and gold, kept under the key version 2 wrote.
    public static let progressVersions = 2...4

    public enum Status: String, Codable, Sendable { case rated, unclear, insufficientSound }

    public let version: Int
    public let status: Status
    public let notes: Bool
    public let timing: Bool
    public let clarity: Bool
    public let voicedDuration: Double
    public let matchedNoteFraction: Double?
    public let timedNoteFraction: Double?
    public let clearNoteFraction: Double?
    public let octaveMismatch: Bool
    public let noteResults: [MelodyNoteResult]
    public let pitchPoints: [MelodyPitchPoint]
    /// Takes scored before version 4, and takes without a stray, have none.
    public let strays: [MelodyStray]?

    public init(version: Int = currentVersion, status: Status, notes: Bool = false,
         timing: Bool = false, clarity: Bool = false, voicedDuration: Double = 0,
         matchedNoteFraction: Double? = nil, timedNoteFraction: Double? = nil,
         clearNoteFraction: Double? = nil, octaveMismatch: Bool = false,
         noteResults: [MelodyNoteResult] = [], pitchPoints: [MelodyPitchPoint] = [],
         strays: [MelodyStray]? = nil) {
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
        self.strays = strays
    }

    public var starCount: Int? {
        status == .rated ? [notes, timing, clarity].filter { $0 }.count : nil
    }

    public var goalReached: Bool { starCount == 3 }

    /// Names the first note whose timing was off, how far, and what to do. Listen & Echo's
    /// wording uses it; every other take gets a `TeacherNote`.
    public var timingAdvice: String? {
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
}
