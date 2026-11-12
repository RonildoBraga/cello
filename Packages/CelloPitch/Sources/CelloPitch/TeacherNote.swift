import Foundation

/// What a teacher would say after a melody take: the thing that mattered most, what to try,
/// and at most one more thing worth knowing. Every word comes from what the rater measured,
/// so the same take always gets the same note, and nothing is said that was not heard.
public struct TeacherNote: Equatable {
    public enum Subject: Equatable {
        case allGood, unscored, octave, unheard, late, early, cutShort, low, high, pitch, unclear, general
    }

    /// What the main point is about. Earlier takes with the same subject show a habit.
    public let subject: Subject
    public let paragraphs: [String]

    public var text: String { paragraphs.joined(separator: "\n\n") }

    /// `earlier` holds the ratings of the takes made before this one on the same part, newest first.
    public init(rating: MelodyRating, register: MelodyRegister, earlier: [MelodyRating] = []) {
        let cello = register == .cello
        let findings = Self.findings(in: rating, cello: cello)
        let subject = findings.first?.subject ?? .allGood
        var paragraphs = findings.prefix(2).enumerated().map { $0.offset == 0 ? $0.element.text : "Also: \($0.element.text)" }
        // Only takes scored by the same rules are compared: earlier rules paired notes differently.
        let habit = earlier.prefix {
            $0.version == rating.version && Self.findings(in: $0, cello: cello).first?.subject == subject
        }.count
        if habit >= 2, ![.allGood, .unscored, .general].contains(subject) {
            paragraphs.append("The same was true of your last \(habit) takes.")
        }
        self.subject = subject
        self.paragraphs = paragraphs
    }

    private struct Finding {
        let subject: Subject
        /// How many notes it touched: the finding that touched most comes first.
        let weight: Int
        let text: String
    }

    private static func findings(in rating: MelodyRating, cello: Bool) -> [Finding] {
        switch rating.status {
        case .insufficientSound:
            return [Finding(subject: .unscored, weight: 0, text: "Go through the whole phrase gently, keeping the longer notes going.")]
        case .unclear:
            return [Finding(subject: .unscored, weight: 0, text: "The sound was not clear enough to score. Try again gently, in a quieter spot.")]
        case .rated: break
        }
        if rating.octaveMismatch {
            return [Finding(subject: .octave, weight: 0, text: "That was in a different octave. Hear the reference again and match its first note.")]
        }
        let notes = rating.noteResults.filter { $0.expectedFrequency != nil }
        let heard = notes.indices.filter { notes[$0].observedOnset != nil }
        func offset(_ index: Int) -> Double { (notes[index].observedOnset ?? 0) - notes[index].expectedStart }
        func slack(_ index: Int) -> Double { min(0.20, notes[index].expectedDuration * 0.35) }
        var found: [Finding] = []

        if !heard.isEmpty, heard.count < notes.count, !rating.notes || !rating.timing {
            found.append(Finding(subject: .unheard, weight: notes.count - heard.count,
                text: "\(heard.count) of the \(notes.count) notes were heard. Give each note a clear start of its own."))
        }

        if !rating.timing {
            let late = heard.filter { offset($0) > slack($0) }, early = heard.filter { offset($0) < -slack($0) }
            let short = heard.filter { !notes[$0].timed && abs(offset($0)) <= slack($0) }
            if !late.isEmpty {
                let slide = slide(before: late, notes: notes, heard: heard, strays: rating.strays ?? [], cello: cello)
                // "before it", "before each", or the notes it came before when not all of the late ones.
                let slideWords = slide.map { slide -> String in
                    let place = slide.notes == late ? (late.count == 1 ? "it" : "each")
                        : name(slide.notes, of: notes.count).replacingOccurrences(of: "Note", with: "note")
                    return ", and before \(place) \(slide.words)"
                }
                let subject = name(late, of: notes.count), amount = seconds(late.map(offset))
                let remedy = late == [0] ? "Start as its bar reaches the line, right after the count of 4."
                    : slide != nil ? "Move straight to the next note as its bar reaches the line."
                    : late.count == 1 ? "Change as its bar reaches the line." : "Change note as each bar reaches the line."
                found.append(Finding(subject: .late, weight: late.count,
                    text: "\(subject) began \(late.count == 1 ? "" : "about ")\(amount) s late"
                        + (slideWords ?? "") + ". " + remedy))
            }
            if !early.isEmpty {
                found.append(Finding(subject: .early, weight: early.count,
                    text: "\(name(early, of: notes.count)) began \(early.count == 1 ? "" : "about ")\(seconds(early.map(offset))) s early. "
                        + (early.count == 1 ? "Wait for its bar to reach the line." : "Wait for each bar to reach the line.")))
            }
            if !short.isEmpty {
                found.append(Finding(subject: .cutShort, weight: short.count,
                    text: "\(name(short, of: notes.count)) stopped too soon. Hold \(short.count == 1 ? "it" : "each") until its bar has passed the line."))
            }
        }

        if !rating.notes, let pitch = pitchFinding(notes: notes, heard: heard, cello: cello) { found.append(pitch) }

        if !rating.clarity {
            let unclear = heard.filter { !notes[$0].clear }
            found.append(Finding(subject: .unclear, weight: unclear.count, text: unclear.isEmpty
                ? "Keep a gentle, clear sound going through each note."
                : "\(name(unclear, of: notes.count)) \(unclear.count == 1 ? "was" : "were") not clear enough to hear. Keep a gentle, steady sound through each note."))
        }

        // The finding that touched the most notes leads; equal ones keep the order above.
        found = found.enumerated().sorted { ($1.element.weight, $0.offset) < ($0.element.weight, $1.offset) }.map(\.element)
        if found.isEmpty {
            let text = !rating.notes ? "Listen to this phrase again and follow each note as it changes."
                : !rating.timing ? "Start as the first bar reaches the line, then follow the note lengths."
                : "All three goals reached. Try this phrase again, then move to the next one."
            found = [Finding(subject: rating.goalReached ? .allGood : .general, weight: 0, text: text)]
        }
        // A slide that made nothing late cost no star, and is still worth a word.
        if !found.contains(where: { $0.subject == .late }),
           let slide = slide(before: heard, notes: notes, heard: heard, strays: rating.strays ?? [], cello: cello) {
            found.insert(Finding(subject: .general, weight: 0, text: "Before a change \(slide.words). Move straight to the next note."),
                         at: min(1, found.count))
        }
        return found
    }

    /// The notes that missed their pitch: which way, how far, and which were right.
    private static func pitchFinding(notes: [MelodyNoteResult], heard: [Int], cello: Bool) -> Finding? {
        func cents(_ index: Int) -> Double? {
            guard let observed = notes[index].observedFrequency, let expected = notes[index].expectedFrequency else { return nil }
            return 1_200 * log2(observed / expected)
        }
        let missed = heard.filter { !notes[$0].matched && cents($0) != nil }
        guard !missed.isEmpty else { return nil }
        let low = missed.filter { (cents($0) ?? 0) <= -60 }, high = missed.filter { (cents($0) ?? 0) >= 60 }
        let named = names(of: notes)
        func label(_ indices: [Int]) -> String {
            guard let named else { return name(indices, of: notes.count) + (indices.count == 1 ? " (\(NoteName.frequency(notes[indices[0]].expectedFrequency)))" : "") }
            return list(indices.map { named[$0] })
        }
        func was(_ indices: [Int]) -> String { indices.count == 1 ? "was" : "were" }
        guard !low.isEmpty || !high.isEmpty else {
            // Near enough on the whole. A note heard clearly for most of its length missed because it
            // moved about; one that was not may only have been cut short, and the take cannot tell.
            let wavering = missed.filter { notes[$0].clear }
            return wavering.isEmpty ? nil : Finding(subject: .pitch, weight: wavering.count,
                text: "\(label(wavering)) wavered. Find the note, then keep it steady.")
        }
        guard low.isEmpty || high.isEmpty else {
            return Finding(subject: .pitch, weight: low.count + high.count,
                text: "\(label(low)) \(was(low)) low and \(label(high)) \(was(high)) high. Hear the phrase again and follow each note.")
        }
        let off = low.isEmpty ? high : low, way = low.isEmpty ? "high" : "low"
        let little = off.allSatisfy { abs(cents($0) ?? 0) < 120 } ? "a little " : ""
        let right = heard.filter { notes[$0].matched }
        // In a short phrase, what went well is said too, after the thing to mend.
        let rightText = named != nil && notes.count <= 4 && !right.isEmpty ? " \(label(right)) \(was(right)) right." : ""
        let open = cello && off.allSatisfy { Self.openStrings.contains(NoteName.frequency(notes[$0].expectedFrequency)) }
        let remedy = open ? (off.count == 1 ? "It is an open string: check its tuning." : "They are open strings: check their tuning.")
            : off == [0] ? "Hear the start again and begin on its pitch."
            : "Aim \(low.isEmpty ? "lower" : "higher") on \(off.count == 1 ? "it" : "them")."
        return Finding(subject: low.isEmpty ? .high : .low, weight: off.count,
                       text: "\(label(off)) \(was(off)) \(little)\(way). \(remedy)\(rightText)")
    }

    private static let openStrings: Set<String> = ["C2", "G2", "D3", "A3"]

    /// The notes among these that a pitched stray sound came just before, and what it was: the
    /// voice going the wrong way before a change, or past the note it was going to. A sound
    /// between the two notes is only the voice on its way, and is not mentioned. Unpitched
    /// strays (a knock) are not the learner's to mend.
    private static func slide(before targets: [Int], notes: [MelodyNoteResult], heard: [Int],
                              strays: [MelodyStray], cello: Bool) -> (notes: [Int], words: String)? {
        var up = 0, down = 0, slid: [Int] = []
        for index in targets where index > 0 {
            guard let onset = notes[index].observedOnset, let expected = notes[index].expectedFrequency else { continue }
            let last = heard.last { $0 < index }
            let previous = last.flatMap { notes[$0].observedOnset } ?? 0
            // Where the voice came from: the note before as it was sung, or else as it was asked.
            let from = last.flatMap { notes[$0].observedFrequency ?? notes[$0].expectedFrequency } ?? expected
            // Outside the stretch from one note to the next, with half a semitone of room at each end.
            let room = pow(2, 50.0 / 1_200)
            let detours = strays.filter { $0.time > previous && $0.time < onset }.compactMap(\.frequency)
                .filter { $0 > max(from, expected) * room || $0 < min(from, expected) / room }
            guard !detours.isEmpty else { continue }
            slid.append(index)
            up += detours.filter { $0 > expected }.count
            down += detours.filter { $0 <= expected }.count
        }
        guard !slid.isEmpty else { return nil }
        let higher = up >= down
        return (slid, cello ? "a \(higher ? "higher" : "lower") note sounded first" : "your voice \(higher ? "slid up" : "dipped") first")
    }

    /// Each asked note's name, when no two asked notes share one; otherwise notes go by number.
    private static func names(of notes: [MelodyNoteResult]) -> [String]? {
        let names = notes.map { NoteName.frequency($0.expectedFrequency) }
        return Set(names).count == names.count ? names : nil
    }

    /// "The first note", "Note 2", "Notes 2 and 3", "Notes 2 to 4", "All the notes".
    private static func name(_ indices: [Int], of total: Int) -> String {
        if indices == [0] { return "The first note" }
        if indices.count == 1 { return "Note \(indices[0] + 1)" }
        if indices.count == total { return "All the notes" }
        if indices.count >= 3, indices.last! - indices[0] == indices.count - 1 { return "Notes \(indices[0] + 1) to \(indices.last! + 1)" }
        return "Notes " + list(indices.map { String($0 + 1) })
    }

    private static func list(_ items: [String]) -> String {
        items.count <= 1 ? items.joined() : items.dropLast().joined(separator: ", ") + " and " + items.last!
    }

    /// The middle of several offsets, to a tenth of a second.
    private static func seconds(_ offsets: [Double]) -> String {
        let sorted = offsets.map(abs).sorted()
        return String(format: "%.1f", sorted[sorted.count / 2])
    }
}
