import AVFoundation
import Foundation

/// Decodes saved media on its original movie timeline, including leading silence.
public enum RecordingAudio {
    public static let sampleRate = 48_000.0

    public static func read(url: URL, maximumDuration: Double) async throws -> [Float] {
        guard maximumDuration.isFinite, (0...200).contains(maximumDuration) else { throw AudioError.unreadable }
        let asset = AVURLAsset(url: url)
        guard let track = try await asset.loadTracks(withMediaType: .audio).first else { throw AudioError.unreadable }
        let reader = try AVAssetReader(asset: asset)
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM, AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: 1, AVLinearPCMBitDepthKey: 32,
            AVLinearPCMIsFloatKey: true, AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw AudioError.unreadable }
        reader.add(output)
        guard reader.startReading() else { throw AudioError.unreadable }
        var samples: [Float] = []
        var expectedTime: Double?
        while let buffer = output.copyNextSampleBuffer() {
            let time = CMSampleBufferGetPresentationTimeStamp(buffer).seconds
            guard time.isFinite, time >= -0.05, time <= maximumDuration,
                  let block = CMSampleBufferGetDataBuffer(buffer) else { throw AudioError.unreadable }
            let bytes = CMBlockBufferGetDataLength(block)
            guard bytes > 0, bytes % MemoryLayout<Float>.size == 0 else { throw AudioError.unreadable }
            if let expectedTime {
                // Never concatenate missing audio into a sustained note.
                guard abs(time - expectedTime) <= 0.05 else { reader.cancelReading(); throw AudioError.unreadable }
            } else {
                samples.append(contentsOf: repeatElement(0, count: Int((max(0, time) * sampleRate).rounded())))
            }
            let samplePosition = Int((time * sampleRate).rounded())
            if samplePosition > samples.count {
                samples.append(contentsOf: repeatElement(0, count: samplePosition - samples.count))
            }
            var chunk = [Float](repeating: 0, count: bytes / MemoryLayout<Float>.size)
            let copied = chunk.withUnsafeMutableBytes {
                CMBlockBufferCopyDataBytes(block, atOffset: 0, dataLength: bytes, destination: $0.baseAddress!)
            }
            guard copied == kCMBlockBufferNoErr else { throw AudioError.unreadable }
            // Do not duplicate an overlap or move negative codec preroll onto
            // time zero. Keep each retained sample on its original timeline.
            let overlap = max(0, samples.count - samplePosition)
            samples.append(contentsOf: chunk.dropFirst(min(overlap, chunk.count)))
            expectedTime = time + Double(chunk.count) / sampleRate
            guard Double(samples.count) / sampleRate <= maximumDuration else {
                reader.cancelReading(); throw AudioError.unreadable
            }
        }
        guard reader.status == .completed, !samples.isEmpty else { throw AudioError.unreadable }
        return samples
    }

    /// A strong second component can make a long period win despite a clear
    /// shorter-period interpretation. Flag uncertainty; never shift it toward
    /// the requested note. The target frequency is deliberately not an input.
    public static func octaveIsAmbiguous(_ sound: [Float], sampleRate: Double, frequency: Double) -> Bool {
        let period = Int((sampleRate / frequency).rounded())
        guard period >= 4, period < sound.count / 2, frequency * 2 <= 1_000 else { return false }
        let full = normalizedCorrelation(sound, lag: period)
        let half = normalizedCorrelation(sound, lag: max(2, period / 2))
        guard half >= 0.90, full - half >= 0.015, full - half <= 0.12 else { return false }
        let fundamental = amplitude(sound, frequency: frequency, sampleRate: sampleRate)
        let octave = amplitude(sound, frequency: frequency * 2, sampleRate: sampleRate)
        return octave > max(0.0002, fundamental * 1.4)
    }

    private static func normalizedCorrelation(_ sound: [Float], lag: Int) -> Double {
        let mean = sound.reduce(0.0) { $0 + Double($1) } / Double(sound.count)
        var cross = 0.0, left = 0.0, right = 0.0
        for index in 0..<(sound.count - lag) {
            let a = Double(sound[index]) - mean
            let b = Double(sound[index + lag]) - mean
            cross += a * b
            left += a * a
            right += b * b
        }
        return cross / max(1e-20, sqrt(left * right))
    }

    private static func amplitude(_ sound: [Float], frequency: Double, sampleRate: Double) -> Double {
        let angle = 2 * Double.pi * frequency / sampleRate
        let cosine = cos(angle), sine = sin(angle)
        var phaseCosine = 1.0, phaseSine = 0.0, real = 0.0, imaginary = 0.0
        for sample in sound {
            real += Double(sample) * phaseCosine
            imaginary += Double(sample) * phaseSine
            let nextCosine = phaseCosine * cosine - phaseSine * sine
            phaseSine = phaseSine * cosine + phaseCosine * sine
            phaseCosine = nextCosine
        }
        return 2 * hypot(real, imaginary) / Double(sound.count)
    }

    private enum AudioError: Error { case unreadable }
}
