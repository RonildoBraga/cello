import Foundation

/// What happened to one note of a melody take, in a word or two: the thing most worth fixing
/// about it. It reads the rater's saved results with the teacher's note's allowances, so a
/// card and the note's words never disagree.
public struct NoteVerdict: Equatable, Sendable, Identifiable {
    public enum Kind: Equatable, Sendable { case good, missed, high, low, wavered, late, early, short, unclear }

    /// One thing that went wrong with a note, in words.
    public struct Issue: Equatable, Sendable {
        public let kind: Kind
        public let label: String
    }

    /// The note's place in the melody's expected events, as the chart counts them.
    public let id: Int
    /// The note's place among the notes, from 0.
    public let position: Int
    public let name: String
    /// Everything that went wrong with the note, the one most worth fixing first.
    public let issues: [Issue]
    public let start: Double
    public let end: Double
    /// Where the note began in the take, when it was heard.
    public let observedOnset: Double?

    public var kind: Kind { issues.first?.kind ?? .good }
    public var label: String { issues.first?.label ?? "Good" }
    public var isGood: Bool { issues.isEmpty }

    /// One verdict per note, in order. A take that was not rated has none.
    public static func verdicts(for rating: MelodyRating) -> [NoteVerdict] {
        guard rating.status == .rated else { return [] }
        return rating.noteResults.filter { $0.expectedFrequency != nil }.enumerated().map { position, note in
            NoteVerdict(id: note.expectedIndex, position: position,
                        name: NoteName.frequency(note.expectedFrequency), issues: issues(of: note),
                        start: note.expectedStart, end: note.expectedStart + note.expectedDuration,
                        observedOnset: note.observedOnset)
        }
    }

    /// The note the teacher's note talks about first, when it talks about one, told by the issue
    /// it talks about, even when that note had a bigger one.
    public static func focus(of verdicts: [NoteVerdict], subject: TeacherNote.Subject) -> NoteVerdict? {
        let kinds: [Kind]
        switch subject {
        case .late: kinds = [.late]
        case .early: kinds = [.early]
        case .cutShort: kinds = [.short]
        case .low: kinds = [.low]
        case .high: kinds = [.high]
        case .pitch: kinds = [.high, .low, .wavered]
        case .unclear: kinds = [.unclear]
        case .unheard: kinds = [.missed]
        case .allGood, .unscored, .octave, .general: return nil
        }
        for verdict in verdicts {
            if let issue = verdict.issues.first(where: { kinds.contains($0.kind) }) {
                return NoteVerdict(id: verdict.id, position: verdict.position, name: verdict.name, issues: [issue],
                                   start: verdict.start, end: verdict.end, observedOnset: verdict.observedOnset)
            }
        }
        return nil
    }

    /// The teacher's note's thresholds: 60 cents or more is high or low; a clear note nearer than
    /// that which still missed moved about. One not clear enough may only have been cut short.
    private static func issues(of note: MelodyNoteResult) -> [Issue] {
        guard let onset = note.observedOnset else { return [Issue(kind: .missed, label: "Not heard")] }
        var found: [Issue] = []
        if !note.matched, let observed = note.observedFrequency, let expected = note.expectedFrequency {
            let cents = Measure.cents(observed, from: expected)
            let amount = Int(abs(cents).rounded())
            if cents >= 60 { found.append(Issue(kind: .high, label: amount < 100 ? "\(amount)¢ sharp" : "Too high")) }
            else if cents <= -60 { found.append(Issue(kind: .low, label: amount < 100 ? "\(amount)¢ flat" : "Too low")) }
            else if note.clear { found.append(Issue(kind: .wavered, label: "Wavered")) }
        }
        if !note.timed {
            let offset = onset - note.expectedStart
            // The same allowance the teacher's note uses for a note's start.
            let slack = min(0.20, note.expectedDuration * 0.35)
            let seconds = String(format: "%.1f", abs(offset))
            if offset > slack { found.append(Issue(kind: .late, label: "\(seconds) s late")) }
            else if offset < -slack { found.append(Issue(kind: .early, label: "\(seconds) s early")) }
            else { found.append(Issue(kind: .short, label: "Stopped soon")) }
        }
        if !note.clear { found.append(Issue(kind: .unclear, label: "Unclear")) }
        return found
    }
}
