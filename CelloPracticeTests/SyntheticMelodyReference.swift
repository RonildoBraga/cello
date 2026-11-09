import Foundation
@testable import Cello

/// Independent synthetic test signal. Never part of the shipped app.
enum SyntheticMelodyReference {
    static let sampleRate = 48_000

    static func wavData(context: MelodyPracticeContext) throws -> Data {
        guard context.isValid else { throw RenderingError.invalidContext }
        // isValid bounds the timeline to at most 192 seconds and 128 events.
        let frameCount = Int((context.duration * Double(sampleRate)).rounded())
        guard frameCount > 0 else { throw RenderingError.invalidContext }
        var pcm = [Int16](repeating: 0, count: frameCount)
        let secondsPerBeat = 60 / Double(context.tempoBPM)
        for event in context.expectedEvents {
            guard let frequency = context.frequency(for: event) else { continue } // Explicit rest.
            let start = min(frameCount, Int((event.onsetBeat * secondsPerBeat * Double(sampleRate)).rounded()))
            let end = min(frameCount, Int((event.endBeat * secondsPerBeat * Double(sampleRate)).rounded()))
            // Leave a small gap even between repeated notes; no beats are shortened.
            let soundingFrames = Int((Double(end - start) * 0.85).rounded())
            let rampFrames = Double(max(1, min(sampleRate / 50, soundingFrames / 2)))
            guard soundingFrames > 0 else { continue }
            for frame in 0..<soundingFrames {
                let edge = Double(min(frame, soundingFrames - 1 - frame))
                let ramp = min(1, edge / rampFrames)
                let envelope = 0.5 - 0.5 * cos(.pi * ramp)
                let phase = 2 * Double.pi * frequency * Double(frame) / Double(sampleRate)
                let sound = envelope * (0.30 * sin(phase) + 0.16 * sin(2 * phase)
                                        + 0.10 * sin(3 * phase) + 0.06 * sin(4 * phase))
                pcm[start + frame] = Int16((sound * Double(Int16.max)).rounded()).littleEndian
            }
        }

        let dataSize = UInt32(frameCount * MemoryLayout<Int16>.size)
        var data = Data(capacity: 44 + Int(dataSize))
        data.append(contentsOf: "RIFF".utf8)
        append(UInt32(36) + dataSize, to: &data)
        data.append(contentsOf: "WAVEfmt ".utf8)
        append(UInt32(16), to: &data)
        append(UInt16(1), to: &data) // Linear PCM.
        append(UInt16(1), to: &data) // Mono.
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

    enum RenderingError: LocalizedError {
        case invalidContext

        var errorDescription: String? { "This melody selection cannot be played. Choose the melody again." }
    }
}
