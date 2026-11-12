import Foundation

/// A note or an explicit rest, measured from the start of a melody selection.
public struct MelodyEvent: Codable, Equatable, Sendable {
    public let onsetBeat: Double
    public let durationBeats: Double
    public let midiNote: Int?

    public init(onsetBeat: Double, durationBeats: Double, midiNote: Int?) {
        self.onsetBeat = onsetBeat
        self.durationBeats = durationBeats
        self.midiNote = midiNote
    }

    public var endBeat: Double { onsetBeat + durationBeats }

    public func frequency(tuningA4Hz: Double = 440) -> Double? {
        guard let midiNote, (0...127).contains(midiNote),
              tuningA4Hz.isFinite, tuningA4Hz > 0 else { return nil }
        let frequency = tuningA4Hz * pow(2, Double(midiNote - 69) / 12)
        return frequency.isFinite ? frequency : nil
    }
}

/// Our teaching arrangement: four bars of 4/4, without lyrics or sampled audio.
public struct MelodyScore: Codable, Equatable, Sendable {
    public let pieceID: String
    public let version: Int
    public let beatsPerBar: Int
    public let events: [MelodyEvent]
    public let phraseBoundaries: [Double]
    public let totalBeats: Double

    public static let hotCrossBuns = fourBars("hotCrossBuns",
        pitches: [54, 52, 50, 54, 52, 50, 50, 50, 50, 50, 52, 52, 52, 52, 54, 52, 50],
        durations: [1, 1, 2, 1, 1, 2, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, 1, 2])

    /// The first four bars of the theme, transposed for our teaching arrangement.
    public static let odeToJoy = fourBars("odeToJoy",
        pitches: [54, 54, 55, 57, 57, 55, 54, 52, 50, 50, 52, 54, 54, 52, 52],
        durations: Array(repeating: 1, count: 12) + [1.5, 0.5, 2])

    /// The tune's first two lines: a jump up of five notes, then steps back down.
    public static let twinkle = fourBars("twinkle",
        pitches: [50, 50, 57, 57, 59, 59, 57, 55, 55, 54, 54, 52, 52, 50],
        durations: [1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2])

    /// The tune's opening line, every length doubled to fill four bars: skips down over a note,
    /// then a climb by step.
    public static let lightlyRow = fourBars("lightlyRow",
        pitches: [57, 54, 54, 55, 52, 52, 50, 52, 54, 55, 57, 57, 57],
        durations: [1, 1, 2, 1, 1, 2, 1, 1, 1, 1, 1, 1, 2])

    /// The tune's first line, in G major on the cello: a drop of a fourth in bar 1, then a leap of a
    /// sixth up into bar 3, and a final note held for the whole bar.
    public static let oldMacDonald = fourBars("oldMacDonald",
        pitches: [55, 55, 55, 50, 52, 52, 50, 59, 59, 57, 57, 55],
        durations: [1, 1, 1, 1, 1, 1, 2, 1, 1, 1, 1, 4])

    /// The tune's first strain, in G major on the cello: notes that run two to a beat and change
    /// pitch as they go, with two one-beat notes ending phrases 2 and 4.
    public static let yankeeDoodle = fourBars("yankeeDoodle",
        pitches: [55, 55, 57, 59, 55, 59, 57, 50, 55, 55, 57, 59, 55, 54,
                  55, 55, 57, 59, 60, 59, 57, 55, 54, 50, 52, 54, 55, 55],
        durations: [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, 1,
                    0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, 1])

    /// One octave of G major, up and back down, from the cello's open G string: the key of Bach's first Prelude.
    public static let gMajorScale = fourBars("gMajorScale",
        pitches: [43, 45, 47, 48, 50, 52, 54, 55, 55, 54, 52, 50, 48, 47, 45, 43],
        durations: Array(repeating: 1, count: 16))

    /// The four chords that open Bach's first Prelude (BWV 1007, bars 1 to 4), one note to a beat: each bar's
    /// lowest, middle and top notes, then the middle again. Every phrase starts from the open G string.
    public static let preludeChords = fourBars("preludeChords",
        pitches: [43, 50, 59, 50, 43, 52, 60, 52, 43, 54, 60, 54, 43, 55, 59, 55],
        durations: Array(repeating: 1, count: 16))

    /// A tune's notes and their lengths in beats, laid end to end across four bars.
    private static func fourBars(_ pieceID: String, pitches: [Int], durations: [Double]) -> MelodyScore {
        var beat = 0.0
        let events = zip(pitches, durations).map { pitch, duration in
            defer { beat += duration }
            return MelodyEvent(onsetBeat: beat, durationBeats: duration, midiNote: pitch)
        }
        return MelodyScore(pieceID: pieceID, version: 1, beatsPerBar: 4,
                           events: events, phraseBoundaries: [0, 4, 8, 12, 16], totalBeats: 16)
    }
}

/// Built-in arrangements share the same phrase and assessment flow.
public enum MelodyPiece: String, CaseIterable, Identifiable, Codable, Sendable {
    case hotCrossBuns, odeToJoy, twinkle, lightlyRow, oldMacDonald, yankeeDoodle, gMajorScale, preludeChords

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .hotCrossBuns: return "Hot Cross Buns"
        case .odeToJoy: return "Ode to Joy"
        case .twinkle: return "Twinkle, Twinkle"
        case .lightlyRow: return "Lightly Row"
        case .oldMacDonald: return "Old MacDonald"
        case .yankeeDoodle: return "Yankee Doodle"
        case .gMajorScale: return "G major scale"
        case .preludeChords: return "Prelude chords"
        }
    }

    public var score: MelodyScore {
        switch self {
        case .hotCrossBuns: return .hotCrossBuns
        case .odeToJoy: return .odeToJoy
        case .twinkle: return .twinkle
        case .lightlyRow: return .lightlyRow
        case .oldMacDonald: return .oldMacDonald
        case .yankeeDoodle: return .yankeeDoodle
        case .gMajorScale: return .gMajorScale
        case .preludeChords: return .preludeChords
        }
    }

    /// The key the melody is heard in, in a register: its home note on the cello, moved as the register moves it.
    /// Earlier melodies are all in D major on the cello, so their keys are the register's own (`MelodyRegister.keyName`).
    public func keyName(for register: MelodyRegister) -> String {
        NoteName.pitchClass(celloTonic + transposition(for: register)) + " major"
    }

    /// How many semitones the melody is moved from the cello's notes in a register. The voice hums the
    /// first melodies a fifth below the cello; from the G major scale on, that would start too low to hum,
    /// so the voice sounds the cello's own notes. A melody's saved takes keep the notes they were made on.
    public func transposition(for register: MelodyRegister) -> Int {
        voiceAtCelloPitch ? 0 : register.transpositionSemitones
    }

    private var voiceAtCelloPitch: Bool {
        switch self {
        case .hotCrossBuns, .odeToJoy, .twinkle, .lightlyRow, .oldMacDonald, .yankeeDoodle: return false
        case .gMajorScale, .preludeChords: return true
        }
    }

    /// The melody's home note on the cello, as a MIDI note.
    private var celloTonic: Int {
        switch self {
        case .hotCrossBuns, .odeToJoy, .twinkle, .lightlyRow: return 50 // D3
        case .oldMacDonald, .yankeeDoodle, .gMajorScale, .preludeChords: return 55 // G3
        }
    }

    public func rangeLabel(for register: MelodyRegister) -> String {
        melodyNoteRange(score.events.compactMap(\.midiNote).map { $0 + transposition(for: register) })
    }

    // MARK: Built-in selections. Enum choices at the standard tempo are always valid.

    /// A listen-only selection.
    public func reference(register: MelodyRegister, section: MelodySection) -> MelodyPracticeContext {
        .build(piece: self, register: register, section: section, tempoBPM: 60, gradingVersion: nil)
    }

    /// A humming take graded with the current rubric.
    public func humming(register: MelodyRegister, section: MelodySection) -> MelodyPracticeContext {
        .build(piece: self, register: register, section: section, tempoBPM: 60,
               gradingVersion: MelodyRating.currentVersion)
    }
}

/// Note names describe the score's MIDI pitches, independently of reference tuning.
private func melodyNoteRange(_ notes: [Int]) -> String {
    guard let low = notes.min(), let high = notes.max(),
          (0...127).contains(low), (0...127).contains(high) else { return "—" }
    return low == high ? NoteName.midi(low) : "\(NoteName.midi(low))–\(NoteName.midi(high))"
}

public enum MelodyRegister: String, CaseIterable, Identifiable, Codable, Sendable {
    /// The voice hums in `lowVoice` and the cello plays in `cello`. `higherVoice` is
    /// no longer offered; it stays so takes saved in that register by earlier
    /// builds still open with their scores and completion.
    case lowVoice, higherVoice, cello

    public var id: String { rawValue }

    /// The key of a melody centred on D on the cello, heard in this register. Listen & Echo uses it;
    /// a melody names its own key (`MelodyPiece.keyName(for:)`).
    public var keyName: String { self == .cello ? "D major" : "G major" }

    public var rangeLabel: String {
        switch self {
        case .lowVoice: return "G2–B2"
        case .higherVoice: return "G3–B3"
        case .cello: return "D3–F♯3"
        }
    }

    /// How far this register sits from the cello in Listen & Echo and the first melodies; a melody may
    /// place the voice elsewhere (`MelodyPiece.transposition(for:)`).
    public var transpositionSemitones: Int {
        switch self {
        case .lowVoice: return -7
        case .higherVoice: return 5
        case .cello: return 0
        }
    }
}

public enum MelodySection: String, CaseIterable, Identifiable, Codable, Sendable {
    case whole, phrase1, phrase2, phrase3, phrase4

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .whole: return "Whole melody"
        case .phrase1: return "Phrase 1"
        case .phrase2: return "Phrase 2"
        case .phrase3: return "Phrase 3"
        case .phrase4: return "Phrase 4"
        }
    }

    /// On a chip: the phrase number, or "All" for the whole melody.
    public var chipLabel: String { self == .whole ? "All" : String(title.suffix(1)) }

    /// Practice order: the four phrases, then the whole melody.
    /// The four phrases, without the whole melody.
    public static let phrases: [MelodySection] = [.phrase1, .phrase2, .phrase3, .phrase4]

    public var next: MelodySection? {
        switch self {
        case .phrase1: return .phrase2
        case .phrase2: return .phrase3
        case .phrase3: return .phrase4
        case .phrase4: return .whole
        case .whole: return nil
        }
    }

    public var beatRange: Range<Double> {
        switch self {
        case .whole: return 0..<16
        case .phrase1: return 0..<4
        case .phrase2: return 4..<8
        case .phrase3: return 8..<12
        case .phrase4: return 12..<16
        }
    }
}

/// A frozen selection, so future recordings never depend on changed app settings.
/// A nil grading version identifies reference-only selections from the first release.
public struct MelodyPracticeContext: Codable, Equatable, Sendable {
    public let pieceID: String
    public let scoreVersion: Int
    public let register: MelodyRegister
    public let referenceKey: String
    public let tuningA4Hz: Double
    public let tempoBPM: Int
    public let section: MelodySection
    public let expectedEvents: [MelodyEvent]
    public let durationBeats: Double
    public let gradingVersion: Int?

    public init(pieceID: String, scoreVersion: Int, register: MelodyRegister, referenceKey: String,
                tuningA4Hz: Double, tempoBPM: Int, section: MelodySection, expectedEvents: [MelodyEvent],
                durationBeats: Double, gradingVersion: Int?) {
        self.pieceID = pieceID
        self.scoreVersion = scoreVersion
        self.register = register
        self.referenceKey = referenceKey
        self.tuningA4Hz = tuningA4Hz
        self.tempoBPM = tempoBPM
        self.section = section
        self.expectedEvents = expectedEvents
        self.durationBeats = durationBeats
        self.gradingVersion = gradingVersion
    }

    public static let supportedTempoRange = 40...120

    public var duration: TimeInterval { durationBeats * 60 / Double(tempoBPM) }

    public var displayPieceTitle: String { MelodyPiece(rawValue: pieceID)?.title ?? "Melody" }
    public var rangeLabel: String { melodyNoteRange(expectedEvents.compactMap(\.midiNote)) }

    /// Bounded timelines also make decoded snapshots safe to use for audio rendering.
    public var isValid: Bool {
        guard !pieceID.isEmpty, scoreVersion > 0, !referenceKey.isEmpty,
              tuningA4Hz.isFinite, (400...480).contains(tuningA4Hz),
              Self.supportedTempoRange.contains(tempoBPM),
              durationBeats.isFinite, durationBeats > 0, durationBeats <= 128,
              !expectedEvents.isEmpty, expectedEvents.count <= 128,
              gradingVersion.map({ $0 > 0 }) ?? true else { return false }
        var previousEnd = 0.0
        for event in expectedEvents {
            guard event.onsetBeat.isFinite, event.durationBeats.isFinite,
                  event.onsetBeat >= previousEnd, event.durationBeats > 0,
                  event.endBeat.isFinite, event.endBeat <= durationBeats else { return false }
            if event.midiNote != nil {
                guard let frequency = frequency(for: event), (50...1_000).contains(frequency) else { return false }
            }
            previousEnd = event.endBeat
        }
        return true
    }

    public static func hotCrossBuns(register: MelodyRegister, section: MelodySection = .whole,
                             tempoBPM: Int = 60, gradingVersion: Int? = nil) throws -> MelodyPracticeContext {
        try melody(piece: .hotCrossBuns, register: register, section: section,
                   tempoBPM: tempoBPM, gradingVersion: gradingVersion)
    }

    public static func odeToJoy(register: MelodyRegister, section: MelodySection = .whole,
                          tempoBPM: Int = 60, gradingVersion: Int? = nil) throws -> MelodyPracticeContext {
        try melody(piece: .odeToJoy, register: register, section: section,
                   tempoBPM: tempoBPM, gradingVersion: gradingVersion)
    }

    public static func melody(piece: MelodyPiece, register: MelodyRegister, section: MelodySection = .whole,
                        tempoBPM: Int = 60, gradingVersion: Int? = nil) throws -> MelodyPracticeContext {
        guard supportedTempoRange.contains(tempoBPM) else { throw ContextError.invalidTempo }
        guard gradingVersion.map({ $0 > 0 }) ?? true else { throw ContextError.invalidGradingVersion }
        return build(piece: piece, register: register, section: section, tempoBPM: tempoBPM,
                     gradingVersion: gradingVersion)
    }

    /// Assembles a selection without validating tempo or grading version.
    fileprivate static func build(piece: MelodyPiece, register: MelodyRegister, section: MelodySection,
                                  tempoBPM: Int, gradingVersion: Int?) -> MelodyPracticeContext {
        let score = piece.score
        let range = section.beatRange
        let events = score.events.filter { range.contains($0.onsetBeat) }.map {
            MelodyEvent(onsetBeat: $0.onsetBeat - range.lowerBound,
                        durationBeats: $0.durationBeats,
                        midiNote: $0.midiNote.map { $0 + piece.transposition(for: register) })
        }
        return MelodyPracticeContext(pieceID: score.pieceID, scoreVersion: score.version,
                                     register: register, referenceKey: piece.keyName(for: register),
                                     tuningA4Hz: 440, tempoBPM: tempoBPM, section: section,
                                     expectedEvents: events, durationBeats: range.upperBound - range.lowerBound,
                                     gradingVersion: gradingVersion)
    }

    public func frequency(for event: MelodyEvent) -> Double? {
        event.frequency(tuningA4Hz: tuningA4Hz)
    }

    /// The same selection under another scoring version.
    public func graded(by version: Int) -> MelodyPracticeContext {
        MelodyPracticeContext(pieceID: pieceID, scoreVersion: scoreVersion, register: register,
                              referenceKey: referenceKey, tuningA4Hz: tuningA4Hz, tempoBPM: tempoBPM,
                              section: section, expectedEvents: expectedEvents, durationBeats: durationBeats,
                              gradingVersion: version)
    }

    /// Event endpoints are exclusive; silence between events has no active index.
    public func eventIndex(at seconds: TimeInterval) -> Int? {
        guard isValid, seconds.isFinite, seconds >= 0, seconds < duration else { return nil }
        let beat = seconds * Double(tempoBPM) / 60
        return expectedEvents.firstIndex { beat >= $0.onsetBeat && beat < $0.endBeat }
    }

    public enum ContextError: LocalizedError {
        case invalidTempo
        case invalidGradingVersion

        public var errorDescription: String? {
            self == .invalidTempo ? "Choose a tempo from 40 to 120 beats per minute." : "This scoring version is unavailable."
        }
    }
}
