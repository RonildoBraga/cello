import CelloPitch
import Foundation

/// Evaluates the saved audio, including silence and missed detections. Live pitch
/// observations alone cannot establish sustained duration or recording quality.
enum RecordingRater {
    private static let sampleRate = 48_000.0
    private static let maximumDuration = 95.0

    static func rate(url: URL, targetFrequency: Double) async -> PracticeRating {
        await Task.detached(priority: .userInitiated) {
            guard targetFrequency.isFinite, targetFrequency > 0 else {
                return PracticeRating(targetFrequency: 0, status: .unclear)
            }
            do {
                let samples = try await RecordingAudio.read(url: url, maximumDuration: maximumDuration)
                return rate(samples: samples, sampleRate: sampleRate, targetFrequency: targetFrequency)
            } catch {
                return PracticeRating(targetFrequency: targetFrequency, status: .unclear)
            }
        }.value
    }

    /// Pure PCM entry point for signal tests. Production calls the media decoder.
    static func rate(samples: [Float], sampleRate: Double, targetFrequency: Double) -> PracticeRating {
        guard targetFrequency.isFinite, targetFrequency > 0 else {
            return PracticeRating(targetFrequency: 0, status: .unclear)
        }
        guard sampleRate.isFinite, (4_000...192_000).contains(sampleRate),
              !samples.isEmpty, Double(samples.count) / sampleRate <= maximumDuration,
              samples.allSatisfy(\.isFinite) else {
            return PracticeRating(targetFrequency: targetFrequency, status: .unclear)
        }
        let clippedFraction = Double(samples.filter { abs($0) >= 0.999 }.count) / Double(samples.count)
        guard clippedFraction < 0.001 else {
            return PracticeRating(targetFrequency: targetFrequency, status: .unclear)
        }
        let window = max(512, Int(sampleRate * (8_192.0 / 48_000)))
        guard samples.count >= window else {
            return PracticeRating(targetFrequency: targetFrequency, status: .insufficientSound)
        }
        let hop = max(1, Int(sampleRate * 0.1))
        let detector = PitchDetector()
        var frameEnds = Array(stride(from: window, through: samples.count, by: hop))
        if frameEnds.last != samples.count { frameEnds.append(samples.count) }
        var frames: [Frame] = []
        for end in frameEnds {
            let sound = Array(samples[(end - window)..<end])
            let estimate = detector.estimate(samples: sound, sampleRate: sampleRate)
            let accepted = estimate.flatMap { $0.confidence >= 0.75 ? $0 : nil }
            frames.append(Frame(center: Double(end - window / 2) / sampleRate,
                                estimate: accepted,
                                ambiguous: accepted.map { RecordingAudio.octaveIsAmbiguous(sound, sampleRate: sampleRate, frequency: $0.frequency) } ?? false))
        }

        // 10 ms cells preserve real pauses instead of treating the span between
        // successful estimates as continuous sound. A pitch window supports only
        // cells actually inside it, and each cell contributes its own duration.
        let cellSize = max(1, Int(sampleRate * 0.01))
        var activeDuration = 0.0
        var voicedDuration = 0.0
        var ambiguousDuration = 0.0
        var pitches: [WeightedPitch] = []
        var voiceOnset: Double?
        var holdStart: Double?
        var lastVoicedEnd: Double?
        var longestHold = 0.0
        var frameIndex = 0
        var voicedFrameIndices = Set<Int>()
        var previousFrequency: Double?
        var octaveSwitches = 0
        for start in stride(from: 0, to: samples.count, by: cellSize) {
            let end = min(start + cellSize, samples.count)
            let cell = samples[start..<end]
            let mean = cell.reduce(0.0) { $0 + Double($1) } / Double(cell.count)
            let rms = sqrt(cell.reduce(0.0) { $0 + pow(Double($1) - mean, 2) } / Double(cell.count))
            let beginTime = Double(start) / sampleRate
            let endTime = Double(end) / sampleRate
            let time = (beginTime + endTime) / 2
            let weight = endTime - beginTime
            guard rms >= 0.0008 else { continue }
            activeDuration += weight
            while frameIndex + 1 < frames.count,
                  abs(frames[frameIndex + 1].center - time) < abs(frames[frameIndex].center - time) {
                frameIndex += 1
            }
            let frame = frames[frameIndex]
            guard abs(frame.center - time) <= Double(window) / sampleRate / 2 + 0.0001,
                  let estimate = frame.estimate else { continue }
            voicedDuration += weight
            if frame.ambiguous { ambiguousDuration += weight }
            if voiceOnset == nil { voiceOnset = beginTime }
            let cents = 1_200 * log2(estimate.frequency / targetFrequency)
            pitches.append(WeightedPitch(cents: cents, weight: weight, time: time))
            if voicedFrameIndices.insert(frameIndex).inserted {
                if let previousFrequency {
                    let jump = abs(1_200 * log2(estimate.frequency / previousFrequency))
                    if (1_050...1_350).contains(jump) { octaveSwitches += 1 }
                }
                previousFrequency = estimate.frequency
            }
            if let lastVoicedEnd, beginTime - lastVoicedEnd > 0.03 + 1e-8 { holdStart = beginTime }
            if holdStart == nil { holdStart = beginTime }
            lastVoicedEnd = endTime
            longestHold = max(longestHold, endTime - (holdStart ?? beginTime))
        }
        guard voicedDuration >= 0.6, voicedFrameIndices.count >= 4 else {
            return PracticeRating(targetFrequency: targetFrequency,
                                  status: activeDuration >= 0.6 ? .unclear : .insufficientSound,
                                  voicedDuration: voicedDuration, longestHold: longestHold)
        }
        guard activeDuration > 0, voicedDuration / activeDuration >= 0.75,
              ambiguousDuration / voicedDuration < 0.15, octaveSwitches < 2 else {
            return PracticeRating(targetFrequency: targetFrequency, status: .unclear,
                                  voicedDuration: voicedDuration, longestHold: longestHold)
        }
        let nearTargetFraction = pitches.filter { abs($0.cents) <= 25 }.reduce(0.0) { $0 + $1.weight } / voicedDuration
        let settled = pitches.filter { $0.time >= (voiceOnset ?? 0) + 0.3 }
        let settledDuration = settled.reduce(0.0) { $0 + $1.weight }
        let spread = settledDuration >= 0.3
            ? weightedPercentile(0.9, in: settled) - weightedPercentile(0.1, in: settled) : nil
        return PracticeRating(targetFrequency: targetFrequency, status: .rated,
                              match: nearTargetFraction + 1e-9 >= 0.8,
                              steady: spread.map { $0 <= 40 + 1e-9 } ?? false,
                              hold: longestHold + 1e-9 >= 2,
                              voicedDuration: voicedDuration, longestHold: longestHold,
                              nearTargetFraction: nearTargetFraction, settledSpreadCents: spread)
    }

    private struct Frame {
        let center: Double
        let estimate: PitchEstimate?
        let ambiguous: Bool
    }

    private struct WeightedPitch {
        let cents: Double
        let weight: Double
        let time: Double
    }

    private static func weightedPercentile(_ fraction: Double, in pitches: [WeightedPitch]) -> Double {
        let sorted = pitches.sorted { $0.cents < $1.cents }
        let threshold = sorted.reduce(0.0) { $0 + $1.weight } * fraction
        var cumulative = 0.0
        for pitch in sorted {
            cumulative += pitch.weight
            if cumulative >= threshold { return pitch.cents }
        }
        return sorted.last?.cents ?? 0
    }

}
