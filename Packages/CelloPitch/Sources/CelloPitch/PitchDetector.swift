import Foundation

/// An estimate of a single, approximately periodic sound. Confidence describes
/// periodicity, not certainty that a particular cello string or note was played.
public struct PitchEstimate: Sendable {
    public let frequency: Double
    public let confidence: Double
    /// Root mean square amplitude after removing DC, in the input PCM scale.
    public let rms: Double

    public init(frequency: Double, confidence: Double, rms: Double) {
        self.frequency = frequency
        self.confidence = confidence
        self.rms = rms
    }
}

/// A stateless YIN-style fundamental estimator for monophonic beginner cello
/// practice. Intended for windows of 8,192 mono PCM samples at 44.1 or 48 kHz.
///
/// The supported range is 50–1,000 Hz, which includes the four open strings.
/// Supply consecutive samples without gaps; call on a worker queue, not the UI
/// thread. Silence and insufficiently periodic input return nil. This is not a
/// polyphonic transcription or a measure of musical performance quality.
///
/// Reference: de Cheveigné & Kawahara, JASA 111 (2002), 1917–1930,
/// https://doi.org/10.1121/1.1458024 .
public struct PitchDetector: Sendable {
    public init() {}

    public func estimate(samples: [Float], sampleRate: Double) -> PitchEstimate? {
        guard sampleRate.isFinite, sampleRate >= 4_000, sampleRate <= 192_000,
              samples.count >= 512, samples.allSatisfy({ $0.isFinite }) else {
            return nil
        }

        // A box filter before decimation lowers the work per analysis frame.
        // Its passband includes all beginner notes; resampling is used only for
        // analysis, never to alter the saved practice recording.
        let decimation = max(1, Int(sampleRate / 12_000))
        let analysisRate = sampleRate / Double(decimation)
        let count = samples.count / decimation
        let maximumLag = Int(analysisRate / 50)
        let minimumLag = max(2, Int(analysisRate / 1_000))
        guard count >= maximumLag * 2 + 2, maximumLag > minimumLag else {
            return nil
        }

        let mean = samples.reduce(0.0) { $0 + Double($1) } / Double(samples.count)
        var energy = 0.0
        var reduced = [Double](repeating: 0, count: count)
        for index in 0..<count {
            var sum = 0.0
            for offset in 0..<decimation {
                let centered = Double(samples[index * decimation + offset]) - mean
                sum += centered
                energy += centered * centered
            }
            reduced[index] = sum / Double(decimation)
        }
        let rms = sqrt(energy / Double(count * decimation))
        // Quiet, sustained phone recordings can be periodic below 0.003 RMS.
        // Keep only a near-silence floor here; the periodicity checks below
        // decide whether the remaining signal supports a pitch estimate.
        guard rms >= 0.0008 else { return nil }

        // A fixed comparison length avoids favoring large lags merely because
        // their windows have fewer terms. At least two cycles of low C fit in
        // the usual 8,192-sample input frame.
        let window = count - maximumLag
        var difference = [Double](repeating: 0, count: maximumLag + 1)
        for lag in 1...maximumLag {
            var sum = 0.0
            for index in 0..<window {
                let delta = reduced[index] - reduced[index + lag]
                sum += delta * delta
            }
            difference[lag] = sum
        }

        var normalized = [Double](repeating: 1, count: maximumLag + 1)
        var runningSum = 0.0
        for lag in 1...maximumLag {
            runningSum += difference[lag]
            if runningSum > 0 {
                normalized[lag] = difference[lag] * Double(lag) / runningSum
            }
        }

        // Select the first sufficiently periodic trough. Looking only for the
        // deepest trough can incorrectly choose a multiple of the true period.
        var candidate: Int?
        // Search shorter periods too, so a high out-of-range tone is rejected
        // rather than reported at one of its lower subharmonics.
        var lag = 2
        while lag < maximumLag {
            if normalized[lag] < 0.12 {
                while lag + 1 <= maximumLag && normalized[lag + 1] < normalized[lag] {
                    lag += 1
                }
                candidate = lag
                break
            }
            lag += 1
        }

        // Permit a little aperiodicity (for example a bowed attack), but never
        // manufacture a note from the best lag of unpitched room noise.
        if candidate == nil {
            let best = (2...maximumLag).min { normalized[$0] < normalized[$1] }!
            if normalized[best] <= 0.18 { candidate = best }
        }
        guard var chosen = candidate else { return nil }

        // A weak fundamental beneath a strong second/third harmonic can yield
        // a shallow, apparently acceptable trough too early. Prefer a nearby
        // integer multiple only when it is markedly more periodic. The floor
        // prevents choosing longer periods for an already clean sinusoid.
        let firstPeriod = chosen
        if normalized[firstPeriod] > 0.03 {
            for multiple in 2...3 {
                let center = firstPeriod * multiple
                guard center + 2 <= maximumLag else { continue }
                let lower = max(2, center - 2)
                let upper = min(maximumLag, center + 2)
                let better = (lower...upper).min { normalized[$0] < normalized[$1] }!
                if normalized[better] < normalized[chosen] * 0.25,
                   normalized[chosen] - normalized[better] > 0.03 {
                    chosen = better
                }
            }
        }

        let confidence = max(0, min(1, 1 - normalized[chosen]))
        var refinedLag = Double(chosen)
        if chosen > 1 && chosen < maximumLag {
            let left = normalized[chosen - 1]
            let center = normalized[chosen]
            let right = normalized[chosen + 1]
            let denominator = left - 2 * center + right
            if abs(denominator) > 1e-12 {
                let correction = 0.5 * (left - right) / denominator
                refinedLag += max(-0.5, min(0.5, correction))
            }
        }

        let frequency = analysisRate / refinedLag
        guard frequency.isFinite, frequency >= 50, frequency <= 1_000 else { return nil }
        return PitchEstimate(frequency: frequency, confidence: confidence, rms: rms)
    }
}
