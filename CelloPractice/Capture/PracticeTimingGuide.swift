import AVFoundation
import Foundation

/// One clock for the count-in, beat clicks and the starts of the recorded notes.
struct PracticeTimingGuide: Sendable {
    struct Cue: Equatable, Sendable {
        let time: TimeInterval
        let accent: Bool
    }

    static let countInBeats = 4
    let beatInterval: TimeInterval
    let duration: TimeInterval
    private let noteOnsets: [TimeInterval]

    init(beatInterval: TimeInterval, duration: TimeInterval, noteOnsets: [TimeInterval]) {
        self.beatInterval = beatInterval
        self.duration = duration
        self.noteOnsets = noteOnsets
    }

    var countInDuration: TimeInterval { Double(Self.countInBeats) * beatInterval }
    var totalDuration: TimeInterval { countInDuration + duration }

    private var isValid: Bool {
        beatInterval.isFinite && (0.05...15).contains(beatInterval)
            && duration.isFinite && duration > 0 && duration <= 90 && noteOnsets.count <= 4_096
    }

    /// The first note and each new note have an accent, even between whole beats.
    var cues: [Cue] {
        guard isValid else { return [] }
        var points = (0..<Self.countInBeats).map { Cue(time: Double($0) * beatInterval, accent: false) }
        for beat in 0..<Int(ceil(duration / beatInterval)) {
            points.append(Cue(time: countInDuration + Double(beat) * beatInterval, accent: beat == 0))
        }
        points += noteOnsets.filter { $0.isFinite && $0 >= 0 && $0 < duration }
            .map { Cue(time: countInDuration + $0, accent: true) }
        var result: [Cue] = []
        for cue in points.sorted(by: { $0.time < $1.time }) {
            if let last = result.last, abs(last.time - cue.time) < 1e-9 {
                result[result.count - 1] = Cue(time: last.time, accent: last.accent || cue.accent)
            } else if cue.time < totalDuration {
                result.append(cue)
            }
        }
        return result
    }

    /// Brief, unpitched noise clicks. The complete track is scheduled once, so
    /// a delayed screen redraw cannot move a beat or a note-change cue.
    func audioBuffer(sampleRate: Double = 48_000) -> AVAudioPCMBuffer? {
        guard isValid, sampleRate.isFinite, (8_000...192_000).contains(sampleRate) else { return nil }
        let count = ceil(totalDuration * sampleRate)
        // Bound one track to 32 MB, including unexpectedly slow or corrupt input.
        guard count > 0, count <= 8_000_000,
              let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: AVAudioFrameCount(count)),
              let samples = buffer.floatChannelData?[0] else { return nil }
        buffer.frameLength = buffer.frameCapacity
        samples.initialize(repeating: 0, count: Int(count))
        let clickFrames = Int((0.008 * sampleRate).rounded())
        var seed: UInt32 = 0x6D2B79F5
        for cue in cues {
            let start = Int((cue.time * sampleRate).rounded())
            guard start < Int(count) else { continue }
            let amplitude: Float = cue.accent ? 0.20 : 0.10
            var previous: Float = 0
            for frame in 0..<min(clickFrames, Int(count) - start) {
                seed = seed &* 1_664_525 &+ 1_013_904_223
                let noise = Float(Double(seed) / Double(UInt32.max) * 2 - 1)
                let highPass = (noise - previous) * 0.5
                previous = noise
                let seconds = Double(frame) / sampleRate
                let envelope = min(1, seconds / 0.0005) * exp(-seconds / 0.002)
                samples[start + frame] += amplitude * highPass * Float(envelope)
            }
        }
        return buffer
    }

    /// Removes only frames before the scheduled take, including a buffer that
    /// straddles its start. A bad timestamp must not save count-in audio.
    static func trimFrameCount(bufferStart: TimeInterval, recordingStart: TimeInterval,
                               sampleRate: Double, frameCount: Int) -> Int {
        guard frameCount > 0 else { return 0 }
        guard bufferStart.isFinite, recordingStart.isFinite, sampleRate.isFinite, sampleRate > 0 else {
            return frameCount
        }
        let offset = (recordingStart - bufferStart) * sampleRate
        guard offset > 0 else { return 0 }
        guard offset < Double(frameCount) else { return frameCount }
        // Host clocks can be large; subtraction can move an exact frame boundary
        // by a few ulps. Snap only inside that representational uncertainty.
        let nearest = offset.rounded()
        let uncertainty = 2 * max(bufferStart.ulp, recordingStart.ulp) * sampleRate + 2 * offset.ulp
        return Int(ceil(abs(offset - nearest) <= uncertainty ? nearest : offset))
    }
}
