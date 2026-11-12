import CelloPitch
import Foundation

/// One item of a level's Meet the notes lesson: a single note to hum back, two
/// of the melody's notes to compare, or a note the melody repeats quickly. Each
/// is a small frozen melody context, so the recorder, rater, chart and ledger
/// are the ones phrases already use.
struct NoteDrill: Hashable, Identifiable {
    static let scoreVersion = 1
    /// A single note is held for three beats; a pair gives each note two.
    static let singleBeats = 3.0
    static let pairBeats = 2.0
    /// A quick note is repeated for a phrase's four beats. Each goal allows one
    /// note in five to miss, so eight notes leave room for a slip where four would not.
    static let quickBeats = 4.0

    let piece: MelodyPiece
    /// The pitches to hum or play, in order, in this drill's register.
    let midiNotes: [Int]
    var register = MelodyRegister.lowVoice
    /// How long each note lasts, in beats.
    var noteBeats = NoteDrill.singleBeats

    var id: String { "\(piece.rawValue)-\(register.rawValue)-\(midiNotes.map(String.init).joined(separator: "-"))" }
    var isSingleNote: Bool { midiNotes.count == 1 }

    /// The piece's distinct notes, lowest first.
    static func notes(for piece: MelodyPiece, register: MelodyRegister = .lowVoice) -> [NoteDrill] {
        Set(piece.score.events.compactMap(\.midiNote)).sorted().map {
            NoteDrill(piece: piece, midiNotes: [$0 + register.transpositionSemitones], register: register)
        }
    }

    /// The notes the piece repeats at less than a beat each, in the order it meets
    /// them: each sounded again and again at that speed. Starting a note afresh is
    /// a skill of its own, met here before a phrase asks for it along with a change of note.
    static func quickRepeats(for piece: MelodyPiece, register: MelodyRegister = .lowVoice) -> [NoteDrill] {
        let events = piece.score.events
        return zip(events, events.dropFirst()).reduce(into: []) { drills, pair in
            guard let note = pair.1.midiNote, note == pair.0.midiNote,
                  pair.1.durationBeats < 1, pair.1.durationBeats == pair.0.durationBeats else { return }
            let drill = NoteDrill(piece: piece, midiNotes: Array(repeating: note + register.transpositionSemitones,
                                                                 count: Int(quickBeats / pair.1.durationBeats)),
                                  register: register, noteBeats: pair.1.durationBeats)
            if !drills.contains(drill) { drills.append(drill) }
        }
    }

    /// The two notes of the melody's widest jump, lower first, in the score's own pitches.
    /// A jump is two notes in a row more than a whole tone apart; a melody that only steps has none.
    private static func jump(in piece: MelodyPiece) -> [Int]? {
        let notes = piece.score.events.compactMap(\.midiNote)
        return zip(notes, notes.dropFirst()).filter { abs($0 - $1) > 2 }
            .max { abs($0.0 - $0.1) < abs($1.0 - $1.1) }.map { [min($0, $1), max($0, $1)] }
    }

    /// The notes, then two of them together (up, then down), then any quick repeats. The two are
    /// the melody's jump, so it is met before a phrase asks for it, or else its lowest and highest notes.
    static func drills(for piece: MelodyPiece, register: MelodyRegister = .lowVoice) -> [NoteDrill] {
        let singles = notes(for: piece, register: register)
        guard let low = singles.first?.midiNotes[0], let high = singles.last?.midiNotes[0], low != high else {
            return singles
        }
        let pair = jump(in: piece)?.map { $0 + register.transpositionSemitones } ?? [low, high]
        return singles + [NoteDrill(piece: piece, midiNotes: pair, register: register, noteBeats: pairBeats),
                          NoteDrill(piece: piece, midiNotes: pair.reversed(), register: register, noteBeats: pairBeats)]
            + quickRepeats(for: piece, register: register)
    }

    var context: MelodyPracticeContext {
        let events = midiNotes.enumerated().map { index, note in
            MelodyEvent(onsetBeat: Double(index) * noteBeats, durationBeats: noteBeats, midiNote: note)
        }
        return MelodyPracticeContext(pieceID: Self.pieceID(for: piece), scoreVersion: Self.scoreVersion,
                                     register: register, referenceKey: register.keyName,
                                     tuningA4Hz: 440, tempoBPM: 60, section: .phrase1, expectedEvents: events,
                                     durationBeats: Double(midiNotes.count) * noteBeats,
                                     gradingVersion: MelodyRating.currentVersion)
    }

    var title: String {
        let names = context.noteNames
        if let repeated = context.repeatedNote { return "\(repeated.name) · \(repeated.count) quick notes" }
        guard names.count == 2 else { return names.first ?? "Note" }
        return midiNotes[0] < midiNotes[1] ? "\(names[0]) then \(names[1]) · going higher"
            : "\(names[0]) then \(names[1]) · going lower"
    }

    /// On a chip: "G2", "G2→B2" for a pair, or "G2 ×8" for a quick note.
    var chipLabel: String {
        context.repeatedNote.map { "\($0.name) ×\($0.count)" } ?? context.noteNames.joined(separator: "→")
    }

    static func pieceID(for piece: MelodyPiece) -> String { "\(piece.rawValue).notes" }
}

extension MelodyPracticeContext {
    /// The piece whose notes this take practises, when it is a Meet the notes take.
    var noteDrillPiece: MelodyPiece? {
        MelodyPiece.allCases.first { NoteDrill.pieceID(for: $0) == pieceID }
    }

    /// The names of the notes to hum, in order.
    var noteNames: [String] {
        expectedEvents.compactMap { frequency(for: $0) }.map(NoteName.frequency)
    }

    /// One note sounded again and again, as in a quick-notes drill: its name and how many times.
    var repeatedNote: (name: String, count: Int)? {
        let names = noteNames
        guard names.count > 2, Set(names).count == 1 else { return nil }
        return (names[0], names.count)
    }

    /// Whether the take repeats a note at less than a beat each, so that it has to be started afresh.
    var repeatsQuickNotes: Bool {
        zip(expectedEvents, expectedEvents.dropFirst()).contains {
            $0.midiNote != nil && $0.midiNote == $1.midiNote && $0.durationBeats < 1 && $1.durationBeats < 1
        }
    }
}
