import CelloPitch
import CryptoKit
import Foundation

/// Versioned original patterns for listening, then humming with live pitch feedback.
/// Changing a catalogue or its timing requires a new score version.
enum EchoLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case twoNotes, threeNotes

    /// The voice's patterns are still version 1. Version 2 is the cello's: its four open
    /// strings, four beats each, because Level 1 has not yet taught a finger. The cello's
    /// version 1 (D3–F♯3, two beats each) stays recognisable, so its takes keep their scores.
    static func scoreVersion(for register: MelodyRegister) -> Int { register == .cello ? 2 : 1 }
    static let tempoBPM = 60
    static let tuningA4Hz = 440.0

    var id: String { rawValue }
    var title: String { self == .twoNotes ? "Two notes" : "Three notes" }
    var pieceID: String { self == .twoNotes ? "echoTwoNotes" : "echoThreeNotes" }
    var noteCount: Int { self == .twoNotes ? 2 : 3 }
    /// Every register's catalogue has this many patterns.
    var patternCount: Int { noteCount == 2 ? 6 : 12 }

    /// One frozen catalogue: its source notes, patterns as indices into them, and beats per note.
    /// Pattern names and pitches stay hidden until a take is made.
    private struct Catalogue {
        let pitches: [Int]
        let patterns: [[Int]]
        let beats: Int
    }

    private func catalogue(register: MelodyRegister, scoreVersion: Int) -> Catalogue? {
        switch (register == .cello, scoreVersion) {
        case (true, 2):
            // The open strings C2, G2, D3 and A3. Low C, hardest for a phone to hear, comes only
            // next to G, and every move is to a neighbouring string.
            return Catalogue(pitches: [36, 43, 50, 57], patterns: self == .twoNotes
                ? [[3, 3], [3, 2], [2, 3], [2, 2], [2, 1], [1, 2]]
                : [[3, 2, 1], [1, 2, 3], [2, 1, 0], [0, 1, 2], [3, 2, 3], [2, 3, 2],
                   [1, 2, 1], [2, 1, 2], [3, 3, 2], [2, 2, 3], [1, 1, 2], [3, 2, 2]], beats: 4)
        case (_, 1):
            // A five-note D-major source: the cello's version 1 played it there, and the
            // voice hums it transposed to G major.
            return Catalogue(pitches: [50, 52, 54, 55, 57].map { $0 + register.transpositionSemitones },
                             patterns: self == .twoNotes
                ? [[0, 0], [0, 1], [1, 0], [1, 1], [1, 2], [2, 1]]
                : [[0, 1, 2], [2, 1, 0], [0, 0, 1], [2, 2, 1], [0, 1, 0], [2, 1, 2],
                   [1, 2, 3], [3, 2, 1], [2, 3, 4], [4, 3, 2], [1, 1, 1], [3, 2, 2]], beats: 2)
        default:
            return nil
        }
    }

    func context(patternIndex: Int, register: MelodyRegister) throws -> MelodyPracticeContext {
        try context(patternIndex: patternIndex, register: register,
                    gradingVersion: MelodyRating.currentVersion)
    }

    /// The pattern at a place `nextPatternIndex` gave, in the voice's or the cello's register.
    /// `index` must come from `nextPatternIndex`.
    func pattern(_ index: Int, register: MelodyRegister) -> MelodyPracticeContext {
        try! context(patternIndex: index, register: register)
    }

    fileprivate func context(patternIndex: Int, register: MelodyRegister, gradingVersion: Int,
                             scoreVersion: Int? = nil) throws -> MelodyPracticeContext {
        guard let context = build(patternIndex: patternIndex, register: register,
                                  scoreVersion: scoreVersion ?? Self.scoreVersion(for: register),
                                  gradingVersion: gradingVersion) else { throw ContextError.invalidPattern }
        return context
    }

    private func build(patternIndex: Int, register: MelodyRegister, scoreVersion: Int,
                       gradingVersion: Int) -> MelodyPracticeContext? {
        guard let catalogue = catalogue(register: register, scoreVersion: scoreVersion),
              catalogue.patterns.indices.contains(patternIndex) else { return nil }
        let events = catalogue.patterns[patternIndex].enumerated().map { index, degree in
            MelodyEvent(onsetBeat: Double(index * catalogue.beats), durationBeats: Double(catalogue.beats),
                        midiNote: catalogue.pitches[degree])
        }
        return MelodyPracticeContext(pieceID: pieceID, scoreVersion: scoreVersion,
            register: register, referenceKey: register.keyName, tuningA4Hz: Self.tuningA4Hz,
            tempoBPM: Self.tempoBPM, section: .whole, expectedEvents: events,
            durationBeats: Double(noteCount * catalogue.beats), gradingVersion: gradingVersion)
    }

    func nextPatternIndex(excluding previous: Int?) -> Int {
        var generator = SystemRandomNumberGenerator()
        return nextPatternIndex(excluding: previous, using: &generator)
    }

    /// Choose uniformly from all other patterns; an invalid prior index excludes nothing.
    func nextPatternIndex<Generator: RandomNumberGenerator>(excluding previous: Int?,
                                                            using generator: inout Generator) -> Int {
        guard let previous, (0..<patternCount).contains(previous) else {
            return Int.random(in: 0..<patternCount, using: &generator)
        }
        let candidate = Int.random(in: 0..<(patternCount - 1), using: &generator)
        return candidate >= previous ? candidate + 1 : candidate
    }

    /// Identity includes every frozen field. A matching piece ID alone must not
    /// identify a changed score, tempo, register or arbitrary notes. Known historical
    /// grading versions remain recognisable without becoming current achievements.
    static func selection(for context: MelodyPracticeContext) -> (level: EchoLevel, patternIndex: Int)? {
        guard context.isValid,
              let gradingVersion = context.gradingVersion, (1...MelodyRating.currentVersion).contains(gradingVersion),
              let level = allCases.first(where: { $0.pieceID == context.pieceID }) else { return nil }
        for index in 0..<level.patternCount {
            if let canonical = try? level.context(patternIndex: index, register: context.register,
                                                  gradingVersion: gradingVersion, scoreVersion: context.scoreVersion),
               context == canonical { return (level, index) }
        }
        return nil
    }

    enum ContextError: LocalizedError {
        case invalidPattern

        var errorDescription: String? {
            switch self {
            case .invalidPattern: return "This echo pattern is unavailable. Choose a new pattern."
            }
        }
    }
}

/// Echo completion spans fresh patterns within one exact level and voice register.
/// This ledger is separate from the fixed-note and piece melody achievements.
struct EchoProgressLedger: SessionProgressLedger {
    let schemaVersion: Int
    var completedKeys: Set<String>
    var passedKeys: Set<String>?

    init(schemaVersion: Int = 1, completedKeys: Set<String> = []) {
        self.schemaVersion = schemaVersion
        self.completedKeys = completedKeys
    }

    static func starCount(for session: PracticeSession) -> Int? { session.melodyRating?.starCount }

    static func eligibleKey(for session: PracticeSession) -> String? {
        guard session.exercise == .listen, session.rating == nil,
              let context = session.melodyContext, let rating = session.melodyRating,
              context.gradingVersion.map(MelodyRating.progressVersions.contains) == true,
              rating.status == .rated, rating.version == context.gradingVersion,
              let selection = EchoLevel.selection(for: context) else { return nil }
        return key(for: selection.level, register: context.register)
    }

    static func key(for level: EchoLevel, register: MelodyRegister) -> String? {
        keys["\(level.rawValue)|\(register.rawValue)"]
    }

    /// Every level and register's key, derived once: each hashes a whole catalogue.
    /// The full canonical catalogue captures level, voice, pitch/timing, key, tuning
    /// and both versions, while deliberately aggregating its patterns.
    private static let keys: [String: String] = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var keys: [String: String] = [:]
        for level in EchoLevel.allCases {
            for register in MelodyRegister.allCases {
                // Hashed under the first scoring version that counts, and the first score version,
                // so earlier passes still stand: the cello's open strings carry on its first patterns.
                let contexts = (0..<level.patternCount).compactMap {
                    try? level.context(patternIndex: $0, register: register,
                                       gradingVersion: MelodyRating.progressVersions.lowerBound, scoreVersion: 1)
                }
                guard contexts.count == level.patternCount, let data = try? encoder.encode(contexts) else { continue }
                keys["\(level.rawValue)|\(register.rawValue)"] = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
            }
        }
        return keys
    }()
}

/// Feedback describes the observed performance, not a measurement of memory.
extension MelodyRating {
    var echoFeedback: String {
        switch status {
        case .insufficientSound: return "Start after the countdown and go through the whole pattern."
        case .unclear: return "The sound was not clear enough to score. Try again gently, in a quieter spot."
        case .rated:
            if octaveMismatch { return "That was in a different octave. Hear the pattern again and match its first note." }
            if !notes { return "Hear the pattern again and follow its repeated, rising or falling notes." }
            if !timing { return timingAdvice ?? "Start as the first bar reaches the line and match the note lengths. Separate repeated notes gently." }
            if !clarity { return "Keep a gentle, clear sound going through each note." }
            return "All three goals reached. Try a fresh pattern."
        }
    }
}
