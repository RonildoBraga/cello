import Foundation

/// One item of a level's Meet the notes lesson: a single note to hum back, or two
/// of the melody's notes to compare. Each is a small frozen melody context, so
/// the recorder, rater, chart and ledger are the ones phrases already use.
struct NoteDrill: Hashable, Identifiable {
    static let scoreVersion = 1
    /// A single note is held for three beats; a pair gives each note two.
    static let singleBeats = 3.0
    static let pairBeats = 2.0

    let piece: MelodyPiece
    /// The pitches to hum, in order, in the low voice.
    let midiNotes: [Int]

    var id: String { "\(piece.rawValue)-\(midiNotes.map(String.init).joined(separator: "-"))" }
    var isSingleNote: Bool { midiNotes.count == 1 }

    /// The piece's distinct notes, lowest first.
    static func notes(for piece: MelodyPiece) -> [NoteDrill] {
        Set(piece.score.events.compactMap(\.midiNote)).sorted().map {
            NoteDrill(piece: piece, midiNotes: [$0 + MelodyRegister.lowVoice.transpositionSemitones])
        }
    }

    /// The notes, then the lowest and highest together: up, then down.
    static func drills(for piece: MelodyPiece) -> [NoteDrill] {
        let singles = notes(for: piece)
        guard let low = singles.first?.midiNotes[0], let high = singles.last?.midiNotes[0], low != high else {
            return singles
        }
        return singles + [NoteDrill(piece: piece, midiNotes: [low, high]),
                          NoteDrill(piece: piece, midiNotes: [high, low])]
    }

    var context: MelodyPracticeContext {
        let beats = isSingleNote ? Self.singleBeats : Self.pairBeats
        let events = midiNotes.enumerated().map { index, note in
            MelodyEvent(onsetBeat: Double(index) * beats, durationBeats: beats, midiNote: note)
        }
        return MelodyPracticeContext(pieceID: Self.pieceID(for: piece), scoreVersion: Self.scoreVersion,
                                     register: .lowVoice, referenceKey: MelodyRegister.lowVoice.keyName,
                                     tuningA4Hz: 440, tempoBPM: 60, section: .phrase1, expectedEvents: events,
                                     durationBeats: Double(midiNotes.count) * beats,
                                     gradingVersion: MelodyRating.currentVersion)
    }

    var title: String {
        let names = context.noteNames
        guard names.count == 2 else { return names.first ?? "Note" }
        return midiNotes[0] < midiNotes[1] ? "\(names[0]) then \(names[1]) · going higher"
            : "\(names[0]) then \(names[1]) · going lower"
    }

    /// On a chip: "G2", or "G2→B2" for a pair.
    var chipLabel: String { context.noteNames.joined(separator: "→") }

    static func pieceID(for piece: MelodyPiece) -> String { "\(piece.rawValue).notes" }
}

extension MelodyPracticeContext {
    /// The piece whose notes this take practises, when it is a Meet the notes take.
    var noteDrillPiece: MelodyPiece? {
        MelodyPiece.allCases.first { NoteDrill.pieceID(for: $0) == pieceID }
    }

    /// The names of the notes to hum, in order.
    var noteNames: [String] {
        expectedEvents.compactMap { frequency(for: $0) }.map {
            TunerReading(frequency: $0, targetFrequency: nil).noteName
        }
    }
}
