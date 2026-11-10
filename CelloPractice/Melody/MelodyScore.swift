import Foundation

/// A note or an explicit rest, measured from the start of a melody selection.
struct MelodyEvent: Codable, Equatable, Sendable {
    let onsetBeat: Double
    let durationBeats: Double
    let midiNote: Int?

    var endBeat: Double { onsetBeat + durationBeats }

    func frequency(tuningA4Hz: Double = 440) -> Double? {
        guard let midiNote, (0...127).contains(midiNote),
              tuningA4Hz.isFinite, tuningA4Hz > 0 else { return nil }
        let frequency = tuningA4Hz * pow(2, Double(midiNote - 69) / 12)
        return frequency.isFinite ? frequency : nil
    }
}

/// Our teaching arrangement: four bars of 4/4, without lyrics or sampled audio.
struct MelodyScore: Codable, Equatable, Sendable {
    let pieceID: String
    let version: Int
    let beatsPerBar: Int
    let events: [MelodyEvent]
    let phraseBoundaries: [Double]
    let totalBeats: Double

    static let hotCrossBuns: MelodyScore = {
        let pitches = [54, 52, 50, 54, 52, 50, 50, 50, 50, 50, 52, 52, 52, 52, 54, 52, 50]
        let durations = [1.0, 1, 2, 1, 1, 2, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 1, 1, 2]
        var beat = 0.0
        let events = zip(pitches, durations).map { pitch, duration in
            defer { beat += duration }
            return MelodyEvent(onsetBeat: beat, durationBeats: duration, midiNote: pitch)
        }
        return MelodyScore(pieceID: "hotCrossBuns", version: 1, beatsPerBar: 4,
                           events: events, phraseBoundaries: [0, 4, 8, 12, 16], totalBeats: 16)
    }()

    /// The first four bars of the theme, transposed for our teaching arrangement.
    static let odeToJoy: MelodyScore = {
        let pitches = [54, 54, 55, 57, 57, 55, 54, 52, 50, 50, 52, 54, 54, 52, 52]
        let durations = Array(repeating: 1.0, count: 12) + [1.5, 0.5, 2]
        var beat = 0.0
        let events = zip(pitches, durations).map { pitch, duration in
            defer { beat += duration }
            return MelodyEvent(onsetBeat: beat, durationBeats: duration, midiNote: pitch)
        }
        return MelodyScore(pieceID: "odeToJoy", version: 1, beatsPerBar: 4,
                           events: events, phraseBoundaries: [0, 4, 8, 12, 16], totalBeats: 16)
    }()
}

/// Built-in arrangements share the same phrase and assessment flow.
enum MelodyPiece: String, CaseIterable, Identifiable, Codable, Sendable {
    case hotCrossBuns, odeToJoy

    var id: String { rawValue }
    var title: String { self == .hotCrossBuns ? "Hot Cross Buns" : "Ode to Joy" }
    var score: MelodyScore { self == .hotCrossBuns ? .hotCrossBuns : .odeToJoy }

    func rangeLabel(for register: MelodyRegister) -> String {
        melodyNoteRange(score.events.compactMap(\.midiNote).map { $0 + register.transpositionSemitones })
    }

    // MARK: Built-in selections. Enum choices at the standard tempo are always valid.

    /// A listen-only selection.
    func reference(register: MelodyRegister, section: MelodySection) -> MelodyPracticeContext {
        .build(piece: self, register: register, section: section, tempoBPM: 60, gradingVersion: nil)
    }

    /// A humming take graded with the current rubric.
    func humming(register: MelodyRegister, section: MelodySection) -> MelodyPracticeContext {
        .build(piece: self, register: register, section: section, tempoBPM: 60,
               gradingVersion: MelodyRating.currentVersion)
    }

    /// Rhythm progress ignores the playback register, so it always uses the low voice.
    func rhythm(section: MelodySection) -> MelodyRhythmContext {
        MelodyRhythmContext(reference: reference(register: .lowVoice, section: section))
    }

    // MARK: Wording for this piece's practice screens

    var hummingIntro: String {
        switch self {
        case .hotCrossBuns: return "Hear the phrase, then record the same notes and rhythm. Start humming after 3–2–1."
        case .odeToJoy: return "Follow five notes moving up and down. Hear the phrase, then record after 3–2–1."
        }
    }

    var listenIntro: String {
        switch self {
        case .hotCrossBuns: return "Listen first, then gently hum along. Choose a register that feels easy."
        case .odeToJoy: return "Hear the five-note opening, then gently hum along. Choose a register that feels easy."
        }
    }

    var notesHint: String {
        switch self {
        case .hotCrossBuns: return "Longer tiles hold longer. The quick notes in phrase 3 last half a beat each."
        case .odeToJoy: return "Longer tiles hold longer. Phrase 4 has a long note, a quick note, then a held ending."
        }
    }

    func rhythmHint(for section: MelodySection) -> String {
        switch (self, section) {
        case (_, .whole): return "Tap at each new tile. Keep counting through the longer tiles."
        case (.odeToJoy, .phrase4): return "Tap on 1, the & after 2, and 3. Count 4 while the last note continues."
        case (.odeToJoy, _): return "Tap on each beat: 1, 2, 3, 4."
        case (.hotCrossBuns, .phrase3): return "Two short notes per beat: 1 & 2 & 3 & 4 &."
        case (.hotCrossBuns, _): return "Tap on 1, 2 and 3. Count 4 while the last note continues."
        }
    }
}

/// Note names describe the score's MIDI pitches, independently of reference tuning.
private func melodyNoteRange(_ notes: [Int]) -> String {
    guard let low = notes.min(), let high = notes.max(),
          (0...127).contains(low), (0...127).contains(high) else { return "—" }
    let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
    func name(_ midi: Int) -> String { "\(names[midi % 12])\(midi / 12 - 1)" }
    return low == high ? name(low) : "\(name(low))–\(name(high))"
}

enum MelodyRegister: String, CaseIterable, Identifiable, Codable, Sendable {
    /// `higherVoice` is no longer offered. It stays so takes saved in that
    /// register by earlier builds still open with their scores and completion.
    case lowVoice, higherVoice, cello

    /// The registers a learner can choose for reference playback.
    static let offered: [MelodyRegister] = [.lowVoice, .cello]

    var id: String { rawValue }

    var title: String {
        switch self {
        case .lowVoice: return "Low voice"
        case .higherVoice: return "Higher voice"
        case .cello: return "Cello"
        }
    }

    var keyName: String { self == .cello ? "D major" : "G major" }

    var rangeLabel: String {
        switch self {
        case .lowVoice: return "G2–B2"
        case .higherVoice: return "G3–B3"
        case .cello: return "D3–F♯3"
        }
    }

    var transpositionSemitones: Int {
        switch self {
        case .lowVoice: return -7
        case .higherVoice: return 5
        case .cello: return 0
        }
    }
}

enum MelodySection: String, CaseIterable, Identifiable, Codable, Sendable {
    case whole, phrase1, phrase2, phrase3, phrase4

    var id: String { rawValue }

    var title: String {
        switch self {
        case .whole: return "Whole melody"
        case .phrase1: return "Phrase 1"
        case .phrase2: return "Phrase 2"
        case .phrase3: return "Phrase 3"
        case .phrase4: return "Phrase 4"
        }
    }

    /// Practice order: the four phrases, then the whole melody.
    var next: MelodySection? {
        switch self {
        case .phrase1: return .phrase2
        case .phrase2: return .phrase3
        case .phrase3: return .phrase4
        case .phrase4: return .whole
        case .whole: return nil
        }
    }

    var beatRange: Range<Double> {
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
struct MelodyPracticeContext: Codable, Equatable, Sendable {
    let pieceID: String
    let scoreVersion: Int
    let register: MelodyRegister
    let referenceKey: String
    let tuningA4Hz: Double
    let tempoBPM: Int
    let section: MelodySection
    let expectedEvents: [MelodyEvent]
    let durationBeats: Double
    let gradingVersion: Int?

    static let supportedTempoRange = 40...120

    var duration: TimeInterval { durationBeats * 60 / Double(tempoBPM) }

    var displayPieceTitle: String { MelodyPiece(rawValue: pieceID)?.title ?? "Melody" }
    var rangeLabel: String { melodyNoteRange(expectedEvents.compactMap(\.midiNote)) }

    /// Bounded timelines also make decoded snapshots safe to use for audio rendering.
    var isValid: Bool {
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

    static func hotCrossBuns(register: MelodyRegister, section: MelodySection = .whole,
                             tempoBPM: Int = 60, gradingVersion: Int? = nil) throws -> MelodyPracticeContext {
        try melody(piece: .hotCrossBuns, register: register, section: section,
                   tempoBPM: tempoBPM, gradingVersion: gradingVersion)
    }

    static func odeToJoy(register: MelodyRegister, section: MelodySection = .whole,
                          tempoBPM: Int = 60, gradingVersion: Int? = nil) throws -> MelodyPracticeContext {
        try melody(piece: .odeToJoy, register: register, section: section,
                   tempoBPM: tempoBPM, gradingVersion: gradingVersion)
    }

    static func melody(piece: MelodyPiece, register: MelodyRegister, section: MelodySection = .whole,
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
                        midiNote: $0.midiNote.map { $0 + register.transpositionSemitones })
        }
        return MelodyPracticeContext(pieceID: score.pieceID, scoreVersion: score.version,
                                     register: register, referenceKey: register.keyName,
                                     tuningA4Hz: 440, tempoBPM: tempoBPM, section: section,
                                     expectedEvents: events, durationBeats: range.upperBound - range.lowerBound,
                                     gradingVersion: gradingVersion)
    }

    func frequency(for event: MelodyEvent) -> Double? {
        event.frequency(tuningA4Hz: tuningA4Hz)
    }

    /// Event endpoints are exclusive; silence between events has no active index.
    func eventIndex(at seconds: TimeInterval) -> Int? {
        guard isValid, seconds.isFinite, seconds >= 0, seconds < duration else { return nil }
        let beat = seconds * Double(tempoBPM) / 60
        return expectedEvents.firstIndex { beat >= $0.onsetBeat && beat < $0.endBeat }
    }

    enum ContextError: LocalizedError {
        case invalidTempo
        case invalidGradingVersion

        var errorDescription: String? {
            self == .invalidTempo ? "Choose a tempo from 40 to 120 beats per minute." : "This scoring version is unavailable."
        }
    }
}
