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
}

enum MelodyRegister: String, CaseIterable, Identifiable, Codable, Sendable {
    case lowVoice, higherVoice, cello

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
/// Grading is deliberately absent until melody assessment is implemented.
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
                             tempoBPM: Int = 60) throws -> MelodyPracticeContext {
        guard supportedTempoRange.contains(tempoBPM) else { throw ContextError.invalidTempo }
        let score = MelodyScore.hotCrossBuns
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
                                     gradingVersion: nil)
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

        var errorDescription: String? { "Choose a tempo from 40 to 120 beats per minute." }
    }
}
