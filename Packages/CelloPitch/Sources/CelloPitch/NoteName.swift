import Foundation

/// How notes are named, in one place: "A2", "F♯3".
public enum NoteName {
    private static let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    /// The name of a MIDI note number.
    public static func midi(_ midi: Int) -> String {
        "\(pitchClass(midi))\(Int(floor(Double(midi) / 12)) - 1)"
    }

    /// A MIDI note's name without its octave, as a key is named: "D", "F♯".
    public static func pitchClass(_ midi: Int) -> String {
        names[(midi % 12 + 12) % 12]
    }

    /// The nearest note to a frequency at A4 = 440 Hz; a dash for anything that is not a pitch.
    public static func frequency(_ frequency: Double?) -> String {
        guard let frequency, frequency.isFinite, frequency > 0 else { return "—" }
        return midi(Int((69 + 12 * (log2(frequency) - log2(440))).rounded()))
    }
}
