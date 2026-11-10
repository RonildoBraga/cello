import AVFoundation
import Foundation

/// Retunes recorded human humming or cello samples onto the frozen score.
/// Missing recordings are errors; playback never substitutes an oscillator.
enum RecordedReference {
    static let sampleRate = 48_000

    private struct Source: Hashable {
        let name: String
        let frequency: Double
        let trimsHumEdges: Bool
    }

    private static let hum = Source(name: "hum-example", frequency: HummingExample.frequency,
                                    trimsHumEdges: true)
    private static let cellos = [
        Source(name: "cello-c2", frequency: 65.39183095652106, trimsHumEdges: false),
        Source(name: "cello-g2", frequency: 97.96663394844622, trimsHumEdges: false),
        Source(name: "cello-d3", frequency: 147.04697656093282, trimsHumEdges: false),
        Source(name: "cello-a3", frequency: 219.89828166261523, trimsHumEdges: false)
    ]

    static func wavData(context: MelodyPracticeContext, bundle: Bundle = .main) throws -> Data {
        guard context.isValid else { throw ReferenceError.invalidContext }
        let frameCount = Int((context.duration * Double(sampleRate)).rounded())
        guard frameCount > 0 else { throw ReferenceError.invalidContext }
        var pcm = [Int16](repeating: 0, count: frameCount)
        var recordings: [Source: Recording] = [:]
        let secondsPerBeat = 60 / Double(context.tempoBPM)
        for event in context.expectedEvents {
            guard let frequency = context.frequency(for: event) else { continue }
            let source: Source
            switch context.register {
            case .lowVoice: source = hum
            // Its recording is no longer bundled; saved takes do not replay their reference.
            case .higherVoice: throw ReferenceError.missingRecording
            case .cello: source = celloSource(for: frequency)
            }
            if recordings[source] == nil { recordings[source] = try Recording(source: source, bundle: bundle) }
            guard let recording = recordings[source] else { throw ReferenceError.missingRecording }
            let start = Int((event.onsetBeat * secondsPerBeat * Double(sampleRate)).rounded())
            let end = min(frameCount, Int((event.endBeat * secondsPerBeat * Double(sampleRate)).rounded()))
            render(recording, frequency: frequency, range: start..<end, gate: 0.88, into: &pcm)
        }
        return wave(pcm)
    }

    static func celloNote(frequency: Double, duration: TimeInterval = 2, bundle: Bundle = .main) throws -> Data {
        guard frequency.isFinite, (50...1_000).contains(frequency),
              duration.isFinite, duration > 0, duration <= 10 else { throw ReferenceError.invalidContext }
        let recording = try Recording(source: celloSource(for: frequency), bundle: bundle)
        let frameCount = Int((duration * Double(sampleRate)).rounded())
        guard frameCount > 0 else { throw ReferenceError.invalidContext }
        var pcm = [Int16](repeating: 0, count: frameCount)
        render(recording, frequency: frequency, range: 0..<pcm.count, gate: 1, into: &pcm)
        return wave(pcm)
    }

    private static func celloSource(for frequency: Double) -> Source {
        // All sources are actual cello recordings. Choose the smallest pitch edit.
        cellos.min { abs(log2(frequency / $0.frequency)) < abs(log2(frequency / $1.frequency)) }!
    }

    private struct Recording {
        let samples: [Float]
        let frequency: Double
        let loopStart: Int
        let loopEnd: Int
        let crossfade: Int

        init(source: Source, bundle: Bundle) throws {
            guard let url = bundle.url(forResource: source.name, withExtension: "wav") else {
                throw ReferenceError.missingRecording
            }
            let file = try AVAudioFile(forReading: url, commonFormat: .pcmFormatFloat32, interleaved: false)
            guard file.processingFormat.channelCount == 1,
                  file.processingFormat.sampleRate == Double(sampleRate),
                  (sampleRate / 2...sampleRate * 10).contains(Int(file.length)),
                  let buffer = AVAudioPCMBuffer(pcmFormat: file.processingFormat,
                                               frameCapacity: AVAudioFrameCount(file.length)) else {
                throw ReferenceError.invalidRecording
            }
            try file.read(into: buffer)
            guard Int(buffer.frameLength) == Int(file.length), let channel = buffer.floatChannelData?[0] else {
                throw ReferenceError.invalidRecording
            }
            let recording = Array(UnsafeBufferPointer(start: channel, count: Int(buffer.frameLength)))
            guard recording.allSatisfy({ $0.isFinite && abs($0) <= 1 }) else {
                throw ReferenceError.invalidRecording
            }
            let first = source.trimsHumEdges ? Int(Double(sampleRate) * 0.15) : 0
            let last = recording.count - Int(Double(sampleRate) * (source.trimsHumEdges ? 0.05 : 0.10))
            samples = Array(recording[first..<last])
            frequency = source.frequency
            loopStart = source.trimsHumEdges ? 0 : min(sampleRate / 3, samples.count / 4)
            loopEnd = samples.count
            crossfade = min(sampleRate / 50, (loopEnd - loopStart) / 8)
        }

        func value(at sourcePosition: Double) -> Float {
            let end = Double(loopEnd)
            let overlap = Double(crossfade)
            let cycle = Double(loopEnd - loopStart - crossfade)
            let position = sourcePosition < end ? sourcePosition
                : Double(loopStart + crossfade) + (sourcePosition - end).truncatingRemainder(dividingBy: cycle)
            if position < end - overlap { return interpolated(at: position) }
            // Crossfade the recorded waveform into its sustain, avoiding a click
            // or replaying a cello bow attack when a slower note needs a loop.
            let progress = position - (end - overlap)
            let mix = Float(progress / overlap)
            return interpolated(at: position) * (1 - mix)
                + interpolated(at: Double(loopStart) + progress) * mix
        }

        private func interpolated(at position: Double) -> Float {
            let index = min(Int(position), samples.count - 1)
            let next = min(index + 1, samples.count - 1)
            return samples[index] + (samples[next] - samples[index]) * Float(position - Double(index))
        }
    }

    private static func render(_ recording: Recording, frequency: Double, range: Range<Int>,
                               gate: Double, into pcm: inout [Int16]) {
        let count = Int((Double(range.count) * gate).rounded())
        guard count > 0 else { return }
        let ramp = Double(max(1, min(sampleRate / 50, count / 2)))
        let ratio = frequency / recording.frequency
        for frame in 0..<count {
            let edge = Double(min(frame, count - 1 - frame))
            let fade = 0.5 - 0.5 * cos(.pi * min(1, edge / ramp))
            let value = Double(recording.value(at: Double(frame) * ratio)) * fade
            pcm[range.lowerBound + frame] = Int16((max(-1, min(1, value)) * Double(Int16.max)).rounded()).littleEndian
        }
    }

    private static func wave(_ pcm: [Int16]) -> Data {
        let dataSize = UInt32(pcm.count * MemoryLayout<Int16>.size)
        var data = Data(capacity: 44 + Int(dataSize))
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36) + dataSize, to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data)
        append(UInt16(1), to: &data)
        append(UInt32(sampleRate), to: &data)
        append(UInt32(sampleRate * 2), to: &data)
        append(UInt16(2), to: &data)
        append(UInt16(16), to: &data)
        data.append(contentsOf: "data".utf8)
        append(dataSize, to: &data)
        pcm.withUnsafeBytes { data.append(contentsOf: $0) }
        return data
    }

    private static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        var value = value.littleEndian
        withUnsafeBytes(of: &value) { data.append(contentsOf: $0) }
    }

    private enum ReferenceError: LocalizedError {
        case invalidContext, missingRecording, invalidRecording
        var errorDescription: String? { "The recorded example could not load. Choose another phrase or try again." }
    }
}
