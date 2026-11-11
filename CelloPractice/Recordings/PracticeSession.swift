import Foundation

enum Exercise: String, Codable, CaseIterable, Identifiable {
    case listen, openC, openG, openD, openA, steadyHum, matchHum

    var id: String { rawValue }

    /// How the exercise is practised. A free recording is neither: a legacy one
    /// stays unrated, and a melody take says how through its register.
    var method: PracticeMethod? {
        switch self {
        case .steadyHum, .matchHum: return .voice
        case .openC, .openG, .openD, .openA: return .cello
        case .listen: return nil
        }
    }

    var title: String {
        switch self {
        case .listen: return "Free recording"
        case .steadyHum: return "Steady hum"
        case .matchHum: return "Listen & match"
        case .openC: return "Open C string"
        case .openG: return "Open G string"
        case .openD: return "Open D string"
        case .openA: return "Open A string"
        }
    }

    var targetNote: String? {
        switch self {
        case .listen, .steadyHum, .matchHum: return nil
        case .openC: return "C2"
        case .openG: return "G2"
        case .openD: return "D3"
        case .openA: return "A3"
        }
    }

    var targetFrequency: Double? {
        switch self {
        case .listen, .steadyHum, .matchHum: return nil
        case .openC: return 65.40639132514966
        case .openG: return 97.99885899543733
        case .openD: return 146.8323839587038
        case .openA: return 220
        }
    }

}

struct PracticeSession: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let exercise: Exercise
    let duration: Double
    /// Retained for older recordings; current practice does not ask for typed input.
    let notes: String
    let pitchSamples: [PitchSample]
    let videoFilename: String
    /// The fixed note chosen for this voice-practice take. Older sessions omit it.
    let tuningTargetFrequency: Double?
    /// Frozen feedback from this recording's audio. Older recordings remain unrated.
    let rating: PracticeRating?
    /// A melody take keeps the score, register and tempo selected before recording.
    /// Existing single-note recordings omit this field.
    let melodyContext: MelodyPracticeContext?
    /// Melody feedback is frozen with the take and never replaces foundation feedback.
    let melodyRating: MelodyRating?

    init(id: UUID, createdAt: Date, exercise: Exercise, duration: Double, notes: String,
         pitchSamples: [PitchSample], videoFilename: String, tuningTargetFrequency: Double? = nil,
         rating: PracticeRating? = nil, melodyContext: MelodyPracticeContext? = nil,
         melodyRating: MelodyRating? = nil) {
        self.id = id
        self.createdAt = createdAt
        self.exercise = exercise
        self.duration = duration
        self.notes = notes
        self.pitchSamples = pitchSamples
        self.videoFilename = videoFilename
        self.tuningTargetFrequency = tuningTargetFrequency
        self.rating = rating
        self.melodyContext = melodyContext
        self.melodyRating = melodyRating
    }

    var title: String {
        guard let context = melodyContext else { return exercise.title }
        if let echo = EchoLevel.selection(for: context) { return "Listen & Echo · \(echo.level.title)" }
        if let piece = context.noteDrillPiece {
            let notes = context.repeatedNote.map { "\($0.name) ×\($0.count)" } ?? context.noteNames.joined(separator: ", ")
            return "\(piece.title) · Meet the notes · \(notes)"
        }
        return "\(context.displayPieceTitle) · \(context.section.title)"
    }

    var starCount: Int? { melodyContext == nil ? rating?.starCount : melodyRating?.starCount }

    var effectiveTargetFrequency: Double? {
        guard melodyContext == nil else { return nil }
        return exercise.targetFrequency ?? tuningTargetFrequency.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    var effectiveTargetNote: String? {
        effectiveTargetFrequency.map(NoteName.frequency)
    }

    /// Estimates relative to equal-tempered targets at A4 = 440 Hz, not musical grades.
    var confidentCentsFromTarget: [Double] {
        guard let target = effectiveTargetFrequency else { return [] }
        return pitchSamples.compactMap { sample in
            guard sample.frequency.isFinite, sample.frequency > 0,
                  sample.confidence.isFinite, sample.confidence >= 0.75 else { return nil }
            return 1_200 * (log2(sample.frequency) - log2(target))
        }
    }

    var medianCentsFromTarget: Double? {
        median(confidentCentsFromTarget)
    }

    private func median(_ values: [Double]) -> Double? {
        guard values.count >= 3 else { return nil }
        let sorted = values.sorted()
        let middle = sorted.count / 2
        return sorted.count.isMultiple(of: 2)
            ? (sorted[middle - 1] + sorted[middle]) / 2
            : sorted[middle]
    }
}
