import Foundation

/// What happened to one note of a melody take, in a word or two: the thing most worth fixing
/// about it. It reads the rater's saved results with the teacher's note's allowances, so a
/// card and the note's words never disagree.
public struct NoteVerdict: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable { case good, missed, high, low, late, early, short, unclear }

    /// The note's place in the melody's expected events, as the chart counts them.
    public let id: Int
    /// The note's place among the notes, from 0.
    public let position: Int
    public let name: String
    public let kind: Kind
    public let start: Double
    public let end: Double
    /// Where the note began in the take, when it was heard.
    public let observedOnset: Double?
    public let label: String

    public var isGood: Bool { kind == .good }

    /// One verdict per note, in order. A take that was not rated has none.
    public static func verdicts(for rating: MelodyRating) -> [NoteVerdict] {
        guard rating.status == .rated else { return [] }
        return rating.noteResults.filter { $0.expectedFrequency != nil }.enumerated().map { position, note in
            let (kind, label) = judge(note)
            return NoteVerdict(id: note.expectedIndex, position: position,
                               name: NoteName.frequency(note.expectedFrequency), kind: kind,
                               start: note.expectedStart, end: note.expectedStart + note.expectedDuration,
                               observedOnset: note.observedOnset, label: label)
        }
    }

    /// The note the teacher's note talks about first, when it talks about one.
    public static func focus(of verdicts: [NoteVerdict], subject: TeacherNote.Subject) -> NoteVerdict? {
        let kinds: [Kind]
        switch subject {
        case .late: kinds = [.late]
        case .early: kinds = [.early]
        case .cutShort: kinds = [.short]
        case .low: kinds = [.low]
        case .high: kinds = [.high]
        case .pitch: kinds = [.high, .low]
        case .unclear: kinds = [.unclear]
        case .unheard: kinds = [.missed]
        case .allGood, .unscored, .octave, .general: return nil
        }
        return verdicts.first { kinds.contains($0.kind) }
    }

    private static func judge(_ note: MelodyNoteResult) -> (Kind, String) {
        guard let onset = note.observedOnset else { return (.missed, "Not heard") }
        if !note.matched, let observed = note.observedFrequency, let expected = note.expectedFrequency {
            let cents = Measure.cents(observed, from: expected)
            let amount = Int(abs(cents).rounded())
            if cents >= 0 { return (.high, amount < 100 ? "\(amount)¢ sharp" : "Too high") }
            return (.low, amount < 100 ? "\(amount)¢ flat" : "Too low")
        }
        if !note.timed {
            let offset = onset - note.expectedStart
            // The same allowance the teacher's note uses for a note's start.
            let slack = min(0.20, note.expectedDuration * 0.35)
            let seconds = String(format: "%.1f", abs(offset))
            if offset > slack { return (.late, "\(seconds) s late") }
            if offset < -slack { return (.early, "\(seconds) s early") }
            return (.short, "Stopped soon")
        }
        if !note.clear { return (.unclear, "Unclear") }
        return (.good, "Good")
    }
}
