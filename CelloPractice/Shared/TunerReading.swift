import Foundation

/// A display interpretation of a raw pitch estimate against an explicit target.
struct TunerReading {
    let frequency: Double?
    private let targetFrequency: Double?

    init(frequency: Double?, targetFrequency: Double?) {
        self.frequency = frequency.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
        self.targetFrequency = targetFrequency.flatMap { $0.isFinite && $0 > 0 ? $0 : nil }
    }

    var noteName: String {
        guard let frequency else { return "—" }
        let midi = Int((69 + 12 * (log2(frequency) - log2(440))).rounded())
        let names = ["C", "C♯", "D", "E♭", "E", "F", "F♯", "G", "A♭", "A", "B♭", "B"]
        let octave = Int(floor(Double(midi) / 12)) - 1
        return "\(names[(midi % 12 + 12) % 12])\(octave)"
    }

    var cents: Double? {
        guard let frequency, let targetFrequency else { return nil }
        // Log differences avoid ratio underflow/overflow for valid finite inputs.
        return 1_200 * (log2(frequency) - log2(targetFrequency))
    }

    var isDifferentNote: Bool {
        guard let cents else { return false }
        return abs(cents) > 100
    }
}
