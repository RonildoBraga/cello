import Foundation

/// The whole beat stays at 60 BPM while each lesson supplies its tap pattern.
enum RhythmExercise: String, Codable, CaseIterable, Hashable {
    case pulse, twoTaps, mixedRhythm

    var title: String {
        switch self {
        case .pulse: return "Pulse"
        case .twoTaps: return "Two taps per beat"
        case .mixedRhythm: return "Mixed rhythm"
        }
    }

    var fileName: String {
        switch self {
        case .pulse: return "PulsePractice.json"
        case .twoTaps: return "TwoTapsPractice.json"
        case .mixedRhythm: return "MixedRhythmPractice.json"
        }
    }

    /// Seconds from the first practice beat, excluding the count-in.
    var tapTimes: [TimeInterval] {
        switch self {
        case .pulse: return (0..<16).map(Double.init)
        case .twoTaps: return (0..<16).map { Double($0) / 2 }
        case .mixedRhythm: return [0, 1, 1.5, 2, 3, 3.5, 4, 5, 5.5, 6, 7, 7.5]
        }
    }

    var tapCount: Int { tapTimes.count }
    var wholeBeats: Int { self == .pulse ? 16 : 8 }
    var tapWindow: TimeInterval { self == .pulse ? 0.45 : 0.225 }
    var practiceDuration: TimeInterval { Double(wholeBeats) * PulseTiming.beatInterval }
    var coverageTarget: Int { Int(ceil(Double(tapCount) * 0.75)) }

    func beatLabel(forTap tap: Int) -> String {
        guard tapTimes.indices.contains(tap - 1) else { return "—" }
        let time = tapTimes[tap - 1]
        return time.rounded(.down) == time ? String(Int(time) + 1) : "&"
    }
}
