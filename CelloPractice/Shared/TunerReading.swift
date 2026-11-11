import Foundation

/// How notes are named, in one place: "A2", "F♯3".
enum NoteName {
    private static let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]

    /// The name of a MIDI note number.
    static func midi(_ midi: Int) -> String {
        "\(names[(midi % 12 + 12) % 12])\(Int(floor(Double(midi) / 12)) - 1)"
    }

    /// The nearest note to a frequency at A4 = 440 Hz; a dash for anything that is not a pitch.
    static func frequency(_ frequency: Double?) -> String {
        guard let frequency, frequency.isFinite, frequency > 0 else { return "—" }
        return midi(Int((69 + 12 * (log2(frequency) - log2(440))).rounded()))
    }
}

/// A display interpretation of a raw pitch estimate against an explicit target.
struct TunerReading {
    let frequency: Double?
    private let targetFrequency: Double?

    init(frequency: Double?, targetFrequency: Double?) {
        self.frequency = frequency.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.targetFrequency = targetFrequency.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    var noteName: String { NoteName.frequency(frequency) }

    var cents: Double? {
        guard let frequency, let targetFrequency else { return nil }
        // Log differences avoid ratio underflow/overflow for valid finite inputs.
        return 1_200 * (log2(frequency) - log2(targetFrequency))
    }
}
