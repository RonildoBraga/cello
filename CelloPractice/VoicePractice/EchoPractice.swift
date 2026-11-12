import CryptoKit
import Foundation

/// Versioned original patterns for listening, then humming with live pitch feedback.
/// Changing a catalogue or its timing requires a new score version.
enum EchoLevel: String, CaseIterable, Identifiable, Codable, Sendable {
    case twoNotes, threeNotes

    static let scoreVersion = 1
    static let tempoBPM = 60
    static let tuningA4Hz = 440.0

    var id: String { rawValue }
    var title: String { self == .twoNotes ? "Two notes" : "Three notes" }
    var pieceID: String { self == .twoNotes ? "echoTwoNotes" : "echoThreeNotes" }
    var noteCount: Int { self == .twoNotes ? 2 : 3 }
    var patternCount: Int { patterns.count }

    // Indices into a five-note D-major source: the cello plays it there, and the
    // voice hums it transposed to G major. Pattern names/pitches stay hidden in practice.
    private var patterns: [[Int]] {
        switch self {
        case .twoNotes:
            return [[0, 0], [0, 1], [1, 0], [1, 1], [1, 2], [2, 1]]
        case .threeNotes:
            return [[0, 1, 2], [2, 1, 0], [0, 0, 1], [2, 2, 1],
                    [0, 1, 0], [2, 1, 2], [1, 2, 3], [3, 2, 1],
                    [2, 3, 4], [4, 3, 2], [1, 1, 1], [3, 2, 2]]
        }
    }

    func rangeLabel(for register: MelodyRegister) -> String {
        switch (self, register) {
        case (.twoNotes, .lowVoice): return "G2–B2"
        case (.twoNotes, .higherVoice): return "G3–B3"
        case (.threeNotes, .lowVoice): return "G2–D3"
        case (.threeNotes, .higherVoice): return "G3–D4"
        case (.twoNotes, .cello): return "D3–F♯3"
        case (.threeNotes, .cello): return "D3–A3"
        }
    }

    func context(patternIndex: Int, register: MelodyRegister) throws -> MelodyPracticeContext {
        try context(patternIndex: patternIndex, register: register,
                    gradingVersion: MelodyRating.currentVersion)
    }

    /// The pattern at a place `nextPatternIndex` gave, in the voice's or the cello's register.
    func pattern(_ index: Int, register: MelodyRegister) -> MelodyPracticeContext {
        build(patternIndex: index, register: register, gradingVersion: MelodyRating.currentVersion)
    }

    fileprivate func context(patternIndex: Int, register: MelodyRegister,
                             gradingVersion: Int) throws -> MelodyPracticeContext {
        guard patterns.indices.contains(patternIndex) else { throw ContextError.invalidPattern }
        return build(patternIndex: patternIndex, register: register, gradingVersion: gradingVersion)
    }

    /// `patternIndex` must come from this level's catalogue.
    private func build(patternIndex: Int, register: MelodyRegister, gradingVersion: Int) -> MelodyPracticeContext {
        let pitches = [50, 52, 54, 55, 57]
        let events = patterns[patternIndex].enumerated().map { index, degree in
            MelodyEvent(onsetBeat: Double(index * 2), durationBeats: 2,
                        midiNote: pitches[degree] + register.transpositionSemitones)
        }
        return MelodyPracticeContext(pieceID: pieceID, scoreVersion: Self.scoreVersion,
            register: register, referenceKey: register.keyName, tuningA4Hz: Self.tuningA4Hz,
            tempoBPM: Self.tempoBPM, section: .whole, expectedEvents: events,
            durationBeats: Double(noteCount * 2), gradingVersion: gradingVersion)
    }

    func nextPatternIndex(excluding previous: Int?) -> Int {
        var generator = SystemRandomNumberGenerator()
        return nextPatternIndex(excluding: previous, using: &generator)
    }

    /// Choose uniformly from all other patterns; an invalid prior index excludes nothing.
    func nextPatternIndex<Generator: RandomNumberGenerator>(excluding previous: Int?,
                                                            using generator: inout Generator) -> Int {
        guard let previous, patterns.indices.contains(previous) else {
            return Int.random(in: patterns.indices, using: &generator)
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
                                                  gradingVersion: gradingVersion),
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
                // Hashed under the first scoring version that counts, so earlier passes still stand.
                let contexts = (0..<level.patternCount).compactMap {
                    try? level.context(patternIndex: $0, register: register, gradingVersion: MelodyRating.progressVersions.lowerBound)
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
