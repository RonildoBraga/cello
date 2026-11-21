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

/// Tuning one open string. The reading is steadied over the last half second, and read
/// in any octave: a low string's overtone can sound louder than the string's own note.
struct StringTuner {
    enum Advice: Equatable { case inTune, low, high, farLow, farHigh }

    /// Tighter than a take's tolerance: a string is tuned once, then everything is played against it.
    static let inTuneCents = 5.0
    /// Beyond this, the peg rather than the fine tuner.
    static let farCents = 100.0

    let target: Double
    private var recent: [Double] = []

    init(target: Double) { self.target = target }

    mutating func hear(_ frequency: Double?) {
        guard let cents = TunerReading(frequency: frequency, targetFrequency: target).cents else {
            recent.removeAll()
            return
        }
        recent.append(cents - 1_200 * (cents / 1_200).rounded())
        if recent.count > 5 { recent.removeFirst() }
    }

    /// The median of the recent readings, once three agree enough to judge.
    var cents: Double? {
        guard recent.count >= 3 else { return nil }
        return recent.sorted()[recent.count / 2]
    }

    var advice: Advice? {
        guard let cents else { return nil }
        if abs(cents) <= Self.inTuneCents { return .inTune }
        if cents < -Self.farCents { return .farLow }
        if cents > Self.farCents { return .farHigh }
        return cents < 0 ? .low : .high
    }
}
