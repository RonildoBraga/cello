import CelloPitch
import Foundation

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
