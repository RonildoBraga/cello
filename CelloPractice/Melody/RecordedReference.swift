import Accelerate
import AVFoundation
import CelloPitch
import Foundation

/// Retunes recorded human humming or cello samples onto the frozen score.
/// Missing recordings are errors; playback never substitutes an oscillator.
enum RecordedReference {
    static let sampleRate = 48_000

    private struct Source: Hashable {
        let name: String
        let frequency: Double
        let isVoice: Bool
    }

    private static let hum = Source(name: "hum-example", frequency: HummingExample.frequency, isVoice: true)
    private static let cellos = [
        Source(name: "cello-c2", frequency: 65.39183095652106, isVoice: false),
        Source(name: "cello-g2", frequency: 97.96663394844622, isVoice: false),
        Source(name: "cello-d3", frequency: 147.04697656093282, isVoice: false),
        Source(name: "cello-a3", frequency: 219.89828166261523, isVoice: false)
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
        /// The voice's recorded cycles, which its notes are rebuilt from; the cello is resampled instead.
        let cycles: Cycles?
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
            let first = source.isVoice ? Int(Double(sampleRate) * 0.15) : 0
            let last = recording.count - Int(Double(sampleRate) * (source.isVoice ? 0.05 : 0.10))
            samples = Array(recording[first..<last])
            frequency = source.frequency
            cycles = try source.isVoice ? Cycles(samples, frequency: frequency) : nil
            loopStart = min(sampleRate / 3, samples.count / 4)
            loopEnd = samples.count
            crossfade = min(sampleRate / 50, (loopEnd - loopStart) / 8)
        }

        /// A note before its fades and level: the cello resampled, the voice rebuilt cycle by cycle.
        func note(frequency: Double, count: Int) -> [Double] {
            guard let cycles else {
                let ratio = frequency / self.frequency
                return (0..<count).map { Double(value(at: Double($0) * ratio)) }
            }
            return voiced(frequency: frequency, count: count, cycles: cycles)
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

        /// Resampling plays a recording faster to raise it, which moves its resonances with the pitch. That suits
        /// the cello, whose nearest recorded string is never more than three and a half semitones away, but a hum
        /// raised to C4 sounded like a voice 2.4 times smaller. So the voice is rebuilt one recorded cycle at a
        /// time (pitch-synchronous overlap-add): each grain blends the two recorded cycles either side of its
        /// moment, is windowed to at most one cycle of the new note, and is laid down at the new note's spacing.
        /// The pitch changes; the resonances stay where they were recorded. The recording plays at its own speed,
        /// going back and forth over its steadier later cycles for a long note, and each note is centred on its
        /// target over the cycles it uses, keeping the voice's own small changes of pitch.
        private func voiced(frequency: Double, count: Int, cycles: Cycles) -> [Double] {
            let starts = cycles.starts
            let loopFrom = Double(starts[starts.count / 4]), loopTo = Double(starts[starts.count - 2])
            func recordedTime(_ time: Double) -> Double {
                guard time > loopTo else { return time }
                let span = loopTo - loopFrom
                let along = (time - loopTo).truncatingRemainder(dividingBy: 2 * span)
                return along < span ? loopTo - along : loopFrom + along - span
            }
            let first = Double(starts[0])
            let lengthsUsed = stride(from: first, to: max(Double(count), first + 1), by: 48).map {
                cycles.locate(recordedTime($0)).length
            }
            let ratio = frequency * lengthsUsed.reduce(0, +) / Double(lengthsUsed.count) / Double(sampleRate)
            var note = [Double](repeating: 0, count: count)
            var grain: [Double] = [], weights: [Double] = []
            var time = first
            while true {
                let (index, progress, length) = cycles.locate(recordedTime(time))
                let half = min(length, length / ratio)
                guard time - half < Double(count) else { break }
                let lower = max(0, Int((time - half).rounded(.up)))
                let upper = min(count - 1, Int((time + half).rounded(.down)))
                if lower <= upper {
                    let before = Double(starts[index]) - time, after = Double(starts[index + 1]) - time
                    grain.removeAll(keepingCapacity: true)
                    weights.removeAll(keepingCapacity: true)
                    var weighted = 0.0, total = 0.0
                    for frame in lower...upper {
                        let position = Double(frame)
                        let value = Double(interpolated(at: before + position)) * (1 - progress)
                            + Double(interpolated(at: after + position)) * progress
                        let weight = 0.5 + 0.5 * cos(.pi * (position - time) / half)
                        grain.append(value)
                        weights.append(weight)
                        weighted += value * weight
                        total += weight
                    }
                    // A grain shorter than a recorded cycle holds part of the cycle's slow swing. Without taking
                    // out its own average, the grains added up to an offset: most of a C4's energy was below 100 Hz.
                    let offset = total > 0 ? weighted / total : 0
                    for k in grain.indices { note[lower + k] += (grain[k] - offset) * weights[k] }
                }
                time += length / ratio
            }
            return note
        }

        private func interpolated(at position: Double) -> Float {
            let position = max(0, position)
            let index = min(Int(position), samples.count - 1)
            let next = min(index + 1, samples.count - 1)
            return samples[index] + (samples[next] - samples[index]) * Float(position - Double(index))
        }
    }

    /// Where each cycle of the recorded voice begins, and how long its cycles are there.
    private struct Cycles {
        let starts: [Int]
        let lengths: [Double]

        /// The first cycle starts at the strongest sample of the first cycle after 5 ms, and each next one
        /// where the waveform best repeats the cycle before, 0.85 to 1.15 cycles on.
        init(_ samples: [Float], frequency: Double) throws {
            var length = Double(sampleRate) / frequency
            let opening = (sampleRate / 200)..<(sampleRate / 200 + Int(length))
            var starts = [opening.max { samples[$0] < samples[$1] } ?? opening.lowerBound]
            while true {
                let previous = starts[starts.count - 1], half = Int(length / 2)
                let candidates = (previous + Int(0.85 * length))...(previous + Int(1.15 * length))
                guard previous >= half, candidates.upperBound + half < samples.count else { break }
                let cycle = samples[(previous - half)...(previous + half)]
                let energy = vDSP.sumOfSquares(cycle)
                var best = candidates.lowerBound, bestMatch = -Float.infinity
                for candidate in candidates {
                    let next = samples[(candidate - half)...(candidate + half)]
                    let match = vDSP.dot(cycle, next) / (energy * vDSP.sumOfSquares(next)).squareRoot()
                    if match > bestMatch { best = candidate; bestMatch = match }
                }
                length = Double(best - previous)
                starts.append(best)
            }
            guard starts.count >= 8 else { throw ReferenceError.invalidRecording }
            self.starts = starts
            // A cycle's length is the median of the gaps around it, so one uneven start cannot jolt the pitch.
            let gaps = zip(starts, starts.dropFirst()).map { Double($1 - $0) }
            lengths = starts.indices.map { index in
                let nearby = gaps[max(0, index - 3)..<min(gaps.count, index + 3)].sorted()
                return nearby[nearby.count / 2]
            }
        }

        /// The cycle a moment of the recording falls in, how far through it, and the cycle length there.
        func locate(_ time: Double) -> (index: Int, progress: Double, length: Double) {
            var low = 0, high = starts.count - 1
            while high - low > 1 {
                let middle = (low + high) / 2
                if Double(starts[middle]) <= time { low = middle } else { high = middle }
            }
            let progress = max(0, min(1, (time - Double(starts[low])) / Double(starts[low + 1] - starts[low])))
            return (low, progress, lengths[low] * (1 - progress) + lengths[low + 1] * progress)
        }
    }

    private static func render(_ recording: Recording, frequency: Double, range: Range<Int>,
                               gate: Double, into pcm: inout [Int16]) {
        let count = Int((Double(range.count) * gate).rounded())
        guard count > 0 else { return }
        let ramp = Double(max(1, min(sampleRate / 50, count / 2)))
        let note = recording.note(frequency: frequency, count: count).enumerated().map { frame, value -> Double in
            let edge = Double(min(frame, count - 1 - frame))
            return value * (0.5 - 0.5 * cos(.pi * min(1, edge / ramp)))
        }
        let gain = noteGain(note)
        for (frame, value) in note.enumerated() {
            pcm[range.lowerBound + frame] = Int16((max(-1, min(1, value * gain)) * Double(Int16.max)).rounded()).littleEndian
        }
    }

    /// Every note is brought to the same loudness over the part of a recording it plays, without letting its
    /// loudest moment pass 0.89 of full scale. The four cello strings were recorded at different strengths and
    /// each begins with a bow's slow attack, so a short note cut from the D3 recording played up to 8 dB quieter
    /// than the same length from the A3 one; and the voice's grains overlap less the higher a note goes, so its
    /// high notes came out up to 13 dB quieter than its low ones.
    private static func noteGain(_ note: [Double]) -> Double {
        let rms = (note.reduce(0) { $0 + $1 * $1 } / Double(note.count)).squareRoot()
        let peak = note.map(abs).max() ?? 0
        guard rms > 0, peak > 0 else { return 1 }
        return min(noteLevel / rms, 0.89 / peak)
    }

    /// The loudness every note is brought to: -15 dBFS, about where a long note from the A3 cello recording sits.
    private static let noteLevel = pow(10, -15.0 / 20)

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
