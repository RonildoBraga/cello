import Foundation

/// The two measurements of sound shared by the tuner, the raters and the room check.
public enum Measure {
    /// How far a frequency sits from a reference, in cents. Subtracting logs keeps any
    /// finite, positive pair from overflowing the ratio.
    public static func cents(_ frequency: Double, from reference: Double) -> Double {
        1_200 * (log2(frequency) - log2(reference))
    }

    /// The level of a stretch of sound, ignoring any constant offset in the signal.
    public static func level<Samples: Collection>(of samples: Samples) -> Double where Samples.Element == Float {
        guard !samples.isEmpty else { return 0 }
        let mean = samples.reduce(0.0) { $0 + Double($1) } / Double(samples.count)
        return sqrt(samples.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(samples.count))
    }
}
