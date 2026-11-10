import CryptoKit
import Foundation

/// Versioned original patterns for listening, then humming without a live guide.
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

    // Indices into a five-note D-major source, transposed with the existing
    // voice registers to G major. Pattern names/pitches stay hidden in practice.
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
        guard register != .cello else { return "—" }
        switch (self, register) {
        case (.twoNotes, .lowVoice): return "G2–B2"
        case (.twoNotes, .higherVoice): return "G3–B3"
        case (.threeNotes, .lowVoice): return "G2–D3"
        case (.threeNotes, .higherVoice): return "G3–D4"
        default: return "—"
        }
    }

    func context(patternIndex: Int, register: MelodyRegister) throws -> MelodyPracticeContext {
        guard register != .cello else { throw ContextError.voiceRegisterRequired }
        guard patterns.indices.contains(patternIndex) else { throw ContextError.invalidPattern }
        let pitches = [50, 52, 54, 55, 57]
        let events = patterns[patternIndex].enumerated().map { index, degree in
            MelodyEvent(onsetBeat: Double(index * 2), durationBeats: 2,
                        midiNote: pitches[degree] + register.transpositionSemitones)
        }
        return MelodyPracticeContext(pieceID: pieceID, scoreVersion: Self.scoreVersion,
            register: register, referenceKey: register.keyName, tuningA4Hz: Self.tuningA4Hz,
            tempoBPM: Self.tempoBPM, section: .whole, expectedEvents: events,
            durationBeats: Double(noteCount * 2), gradingVersion: MelodyRating.currentVersion)
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
    /// credit a changed score, tempo, register, grading version or arbitrary notes.
    static func selection(for context: MelodyPracticeContext) -> (level: EchoLevel, patternIndex: Int)? {
        guard context.isValid, context.register != .cello,
              let level = allCases.first(where: { $0.pieceID == context.pieceID }) else { return nil }
        for index in 0..<level.patternCount {
            if let canonical = try? level.context(patternIndex: index, register: context.register),
               context == canonical { return (level, index) }
        }
        return nil
    }

    enum ContextError: LocalizedError {
        case voiceRegisterRequired, invalidPattern

        var errorDescription: String? {
            switch self {
            case .voiceRegisterRequired: return "Choose a low or higher voice for Listen & Echo."
            case .invalidPattern: return "This echo pattern is unavailable. Choose a new pattern."
            }
        }
    }
}

/// Echo completion spans fresh patterns within one exact level and voice register.
/// This ledger is separate from the fixed-note and piece melody achievements.
struct EchoProgressLedger: Codable {
    let schemaVersion: Int
    private(set) var completedKeys: Set<String>

    init(schemaVersion: Int = 1, completedKeys: Set<String> = []) {
        self.schemaVersion = schemaVersion
        self.completedKeys = completedKeys
    }

    func progress(for level: EchoLevel, register: MelodyRegister,
                  sessions: [PracticeSession]) -> PracticeProgress {
        guard let key = Self.key(for: level, register: register) else {
            return PracticeProgress(successfulAttempts: 0, completed: false)
        }
        let recent = sessions.filter { Self.eligibleKey(for: $0) == key }
            .sorted(by: Self.newestFirst).prefix(5)
        let successes = recent.filter { $0.melodyRating?.goalReached == true }.count
        let completed = completedKeys.contains(key) || successes >= 3
        return PracticeProgress(successfulAttempts: completed ? 3 : successes, completed: completed)
    }

    @discardableResult
    mutating func update(from sessions: [PracticeSession]) -> Bool {
        var windows: [String: [Bool]] = [:]
        var changed = false
        for session in sessions.sorted(by: { Self.newestFirst($1, $0) }) {
            guard let key = Self.eligibleKey(for: session) else { continue }
            var window = windows[key, default: []]
            window.append(session.melodyRating?.goalReached == true)
            if window.count > 5 { window.removeFirst() }
            windows[key] = window
            if window.filter({ $0 }).count >= 3, completedKeys.insert(key).inserted { changed = true }
        }
        return changed
    }

    private static func eligibleKey(for session: PracticeSession) -> String? {
        guard session.exercise == .listen, session.rating == nil,
              let context = session.melodyContext, let rating = session.melodyRating,
              rating.status == .rated, rating.version == context.gradingVersion,
              let selection = EchoLevel.selection(for: context) else { return nil }
        return key(for: selection.level, register: context.register)
    }

    private static func key(for level: EchoLevel, register: MelodyRegister) -> String? {
        guard register != .cello else { return nil }
        // Full canonical catalogue captures level, voice, pitch/timing, key,
        // tuning and both versions, while deliberately aggregating its patterns.
        let contexts = (0..<level.patternCount).compactMap {
            try? level.context(patternIndex: $0, register: register)
        }
        guard contexts.count == level.patternCount else { return nil }
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(contexts) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    private static func newestFirst(_ lhs: PracticeSession, _ rhs: PracticeSession) -> Bool {
        if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
        return lhs.id.uuidString > rhs.id.uuidString
    }
}

/// Feedback describes the observed performance, not a measurement of memory.
extension MelodyRating {
    var echoFeedback: String {
        switch status {
        case .insufficientSound: return "Hum the whole pattern after the countdown."
        case .unclear: return "The sound was not clear enough to score. Try a gentle hum in a quieter spot."
        case .rated:
            if octaveMismatch { return "Choose a comfortable voice register, then hear the pattern again." }
            if !notes { return "Hear the pattern again and follow its repeated, rising or falling notes." }
            if !timing { return "Start after 3–2–1 and match the note lengths. Separate repeated notes gently." }
            if !clarity { return "Keep a gentle, clear hum going through each note." }
            return "All three goals reached. Try a fresh pattern."
        }
    }
}
