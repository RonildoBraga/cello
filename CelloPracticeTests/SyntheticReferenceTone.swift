import Foundation

/// Independent synthetic test signal. Never part of the shipped app.
enum SyntheticReferenceTone {
    static let sampleRate = 48_000
    static let duration = 2.0

    static func wavData(frequency: Double) throws -> Data {
        guard frequency.isFinite, (50...1_000).contains(frequency) else {
            throw ToneError.invalidFrequency
        }
        let frameCount = Int(Double(sampleRate) * duration)
        let rampFrames = Double(sampleRate) * 0.025
        var pcm = [Int16]()
        pcm.reserveCapacity(frameCount)
        for frame in 0..<frameCount {
            let edge = min(Double(frame), Double(frameCount - 1 - frame))
            let ramp = min(1, edge / rampFrames)
            let envelope = 0.5 - 0.5 * cos(.pi * ramp)
            let phase = 2 * Double.pi * frequency * Double(frame) / Double(sampleRate)
            let sound = envelope * (0.30 * sin(phase) + 0.16 * sin(2 * phase)
                                    + 0.10 * sin(3 * phase) + 0.06 * sin(4 * phase))
            pcm.append(Int16((sound * Double(Int16.max)).rounded()).littleEndian)
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

    enum ToneError: LocalizedError {
        case invalidFrequency
        var errorDescription: String? { "Choose a comfortable note between 50 and 1,000 Hz." }
    }
}
