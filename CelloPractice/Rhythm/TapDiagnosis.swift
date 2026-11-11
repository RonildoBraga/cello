import Foundation

/// What went wrong in a tapping round, in plain words, and how to fix it. It
/// names the first problem that explains the lost star, in the order a learner
/// should fix them: start, pattern, coverage, timing, evenness.
enum TapDiagnosis {
    enum Kind { case pulse, twoTaps, mixed, melody }

    /// `oneBeatLate` is true when the first tap really did land a beat after the first note.
    static func feedback(kind: Kind, expected: Int, offsets: [Int: TimeInterval], extras: Int,
                         oneBeatLate: Bool = false, coverage: Bool, timing: Bool, evenness: Bool) -> String {
        let missedFirst = offsets[0] == nil
        if missedFirst, oneBeatLate {
            return "You started one beat late: the first note was missed and a tap landed where no note starts. "
                + "The first tap comes on the beat right after the count of 4."
        }
        if missedFirst {
            return "You missed the first \(kind == .melody ? "note" : "tap"). "
                + "It comes on the beat right after the count of 4, as if the count went on to 1 again."
        }
        if extras > 0, kind == .melody {
            return "\(count(extras, "tap")) landed where no note starts. "
                + "Tap once when a note begins, then keep counting while it holds."
        }
        if extras > 1, kind == .mixed {
            return "\(count(extras, "tap")) landed in the gaps. Beats 1, 3, 5 and 7 get one tap; "
                + "only 2, 4, 6 and 8 get a second tap halfway."
        }
        if !coverage {
            return "You missed \(expected - offsets.count) of \(expected) taps. Keep tapping to the end, even after a slip."
        }
        if !timing { return timingAdvice(offsets) }
        if !evenness { return evennessAdvice(kind: kind, offsets: offsets) }
        return "All three goals reached. Your taps stayed with the beat."
    }

    private static func timingAdvice(_ offsets: [Int: TimeInterval]) -> String {
        let median = RhythmStatistics.percentile(0.5, in: offsets.values.sorted()) ?? 0
        let amount = String(format: "%.2f", abs(median))
        if median > 0.06 {
            return "Most taps were about \(amount) s late. Tap with the beat, as if clapping along, not after you feel it."
        }
        if median < -0.06 {
            return "Most taps were about \(amount) s early. Let each beat arrive: count it in your head and tap as you say the number."
        }
        return "Your taps landed on both sides of the beat. Count out loud and keep your hand moving in time between taps."
    }

    private static func evennessAdvice(kind: Kind, offsets: [Int: TimeInterval]) -> String {
        if kind == .twoTaps {
            // Even positions are the numbers; odd positions are the "and" between them.
            let between = offsets.filter { !$0.key.isMultiple(of: 2) }.values.sorted()
            let onBeat = offsets.filter { $0.key.isMultiple(of: 2) }.values.sorted()
            if let between = RhythmStatistics.percentile(0.5, in: between),
               let onBeat = RhythmStatistics.percentile(0.5, in: onBeat), abs(between - onBeat) > 0.06 {
                return "The taps between beats came \(between > onBeat ? "late" : "early"). "
                    + "Put each ‘&’ exactly halfway between two numbers."
            }
        }
        switch kind {
        case .melody: return "The gaps drifted as the note lengths changed. Keep counting the steady beat under the notes."
        case .mixed: return "The beat drifted as you switched between one tap and two. Keep the numbers steady; only the ‘&’ is extra."
        case .pulse, .twoTaps: return "The gaps between taps changed. Keep the same space between every tap."
        }
    }

    private static func count(_ number: Int, _ noun: String) -> String {
        number == 1 ? "1 \(noun)" : "\(number) \(noun)s"
    }
}
