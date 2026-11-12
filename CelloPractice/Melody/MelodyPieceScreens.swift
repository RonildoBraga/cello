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
        case .lightlyRow: return "Phrases 1 and 2 skip down over a note; phrase 3 climbs one note at a time. Hear the phrase, then record after the count of 1–2–3–4."
        case .oldMacDonald: return "Phrase 1 drops to a low note, and phrase 3 starts high, a big jump up from the end of phrase 2. Hear the phrase, then record after the count of 1–2–3–4."
        case .yankeeDoodle: return "The notes run two to a beat, changing as they go; phrases 2 and 4 end on two longer notes. Hear the phrase, then record after the count of 1–2–3–4."
        }
    }

    var listenIntro: String {
        switch self {
        case .hotCrossBuns: return "Listen first, then gently hum along."
        case .odeToJoy: return "Hear the five-note opening, then gently hum along."
        case .twinkle: return "Hear the jump up at the start, then gently hum along."
        case .lightlyRow: return "Hear the skips at the start, then gently hum along."
        case .oldMacDonald: return "Hear the big jump up in the middle, then gently hum along."
        case .yankeeDoodle: return "Hear the notes run two to a beat, then gently hum along."
        }
    }

    var notesHint: String {
        switch self {
        case .hotCrossBuns: return "Longer tiles hold longer. The quick notes in phrase 3 last half a beat each."
        case .odeToJoy: return "Longer tiles hold longer. Phrase 4 has a long note, a quick note, then a held ending."
        case .twinkle: return "Longer tiles hold longer. Every note sounds twice; phrases 2 and 4 end on a held note."
        case .lightlyRow: return "Longer tiles hold longer. Phrases 1, 2 and 4 end on a held note; phrase 3 has four even notes."
        case .oldMacDonald: return "Longer tiles hold longer. Phrase 2 ends on a held note, and phrase 4 is one note held for all four beats."
        case .yankeeDoodle: return "Longer tiles hold longer. Most notes last half a beat; phrases 2 and 4 end on two notes of one beat each."
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
        case [0.5, 0.5, 0.5, 0.5, 1, 1]: return "Two short notes per beat on 1 and 2: 1 & 2 &. Then tap on 3 and on 4."
        case [4]: return "Tap once on 1. Count 2, 3 and 4 while the note continues."
        default: return "Tap at each new tile."
        }
    }
}
