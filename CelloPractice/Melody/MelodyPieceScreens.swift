import CelloPitch
import Foundation

/// What each melody's practice screens say. The score itself lives in the shared package.
extension MelodyPiece {
    /// Rhythm progress ignores the playback register, so it always uses the low voice.
    func rhythm(section: MelodySection) -> MelodyRhythmContext {
        MelodyRhythmContext(reference: reference(register: .lowVoice, section: section))
    }

    // MARK: Wording for this piece's practice screens

    var hummingIntro: String {
        switch self {
        case .hotCrossBuns: return "Hear the phrase, then record the same notes and rhythm. Start as the first bar reaches the line."
        case .odeToJoy: return "Follow five notes moving up and down. Hear the phrase, then record after the count of 1–2–3–4."
        case .twinkle: return "Phrase 1 jumps up; the other phrases step back down. Hear the phrase, then record after the count of 1–2–3–4."
        }
    }

    var listenIntro: String {
        switch self {
        case .hotCrossBuns: return "Listen first, then gently hum along."
        case .odeToJoy: return "Hear the five-note opening, then gently hum along."
        case .twinkle: return "Hear the jump up at the start, then gently hum along."
        }
    }

    var notesHint: String {
        switch self {
        case .hotCrossBuns: return "Longer tiles hold longer. The quick notes in phrase 3 last half a beat each."
        case .odeToJoy: return "Longer tiles hold longer. Phrase 4 has a long note, a quick note, then a held ending."
        case .twinkle: return "Longer tiles hold longer. Every note sounds twice; phrases 2 and 4 end on a held note."
        }
    }

    /// How to count a selection, from the lengths of its notes: tunes that share a rhythm share its hint.
    func rhythmHint(for section: MelodySection) -> String {
        guard section != .whole else { return "Tap at each new tile. Keep counting through the longer tiles." }
        switch score.events.filter({ section.beatRange.contains($0.onsetBeat) }).map(\.durationBeats) {
        case [1, 1, 1, 1]: return "Tap on each beat: 1, 2, 3, 4."
        case [1, 1, 2]: return "Tap on 1, 2 and 3. Count 4 while the last note continues."
        case [1.5, 0.5, 2]: return "Tap on 1, the & after 2, and 3. Count 4 while the last note continues."
        case Array(repeating: 0.5, count: 8): return "Two short notes per beat: 1 & 2 & 3 & 4 &."
        default: return "Tap at each new tile."
        }
    }
}
