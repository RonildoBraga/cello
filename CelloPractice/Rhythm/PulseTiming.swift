import Foundation

/// A small, fixed-tempo exercise. All timing is relative to a monotonic clock;
/// the UI's refresh rate never determines when a beat is due.
struct PulseTiming: RhythmRoundTiming {
    typealias Phase = RhythmPhase

    static let beatInterval: TimeInterval = 1
    static let countInBeats = 4
    var beatInterval: TimeInterval { Self.beatInterval }

    let startTime: TimeInterval
    let exercise: RhythmExercise
    private(set) var offsets: [Int: TimeInterval] = [:]
    private(set) var unexpectedTapCount = 0

    init(startTime: TimeInterval, exercise: RhythmExercise = .pulse) {
        self.startTime = startTime
        self.exercise = exercise
    }

    var practiceStartTime: TimeInterval { startTime + Double(Self.countInBeats) * Self.beatInterval }
    var tapTimes: [TimeInterval] { exercise.tapTimes }

    var endTime: TimeInterval {
        startTime + Double(Self.countInBeats) * Self.beatInterval + exercise.practiceDuration
    }

    func phase(at time: TimeInterval) -> Phase {
        guard time.isFinite, startTime.isFinite else { return .finished }
        let elapsed = max(0, time - startTime)
        if time >= endTime {
            return .finished
        }
        let index = Int(elapsed / Self.beatInterval)
        if index < Self.countInBeats { return .countIn(Self.countInBeats - index) }
        let practiceTime = elapsed - Double(Self.countInBeats) * Self.beatInterval
        let tap = exercise.tapTimes.lastIndex(where: { $0 <= practiceTime }) ?? 0
        return .tapping(tap + 1)
    }

    func canTap(at time: TimeInterval) -> Bool {
        guard time.isFinite, startTime.isFinite else { return false }
        return time >= startTime + Double(Self.countInBeats) * Self.beatInterval - exercise.tapWindow
            && time <= startTime + Double(Self.countInBeats) * Self.beatInterval
                + (exercise.tapTimes.last ?? 0) + exercise.tapWindow
    }

    /// Accept one nearby observation per expected tap. Mixed rhythm also counts
    /// taps in intentional gaps, so repeating all eighth notes cannot pass it.
    @discardableResult
    mutating func recordTap(at time: TimeInterval) -> Bool {
        guard canTap(at: time) else { return false }
        let elapsed = time - startTime - Double(Self.countInBeats) * Self.beatInterval
        let times = exercise.tapTimes
        guard let tap = times.indices.min(by: { abs(times[$0] - elapsed) < abs(times[$1] - elapsed) }) else { return false }
        let expected = startTime + Double(Self.countInBeats) * Self.beatInterval + times[tap]
        let offset = time - expected
        guard abs(offset) <= exercise.tapWindow + 1e-9 else {
            if exercise == .mixedRhythm { unexpectedTapCount += 1 }
            return false
        }
        guard offsets[tap] == nil else { return false }
        offsets[tap] = offset
        return true
    }

    var medianOffsetMilliseconds: Double? { median(offsets.values.map { $0 * 1_000 }) }
    var medianDistanceMilliseconds: Double? { median(offsets.values.map { abs($0) * 1_000 }) }

    private func median(_ values: [Double]) -> Double? {
        values.count >= 3 ? RhythmStatistics.percentile(0.5, in: values.sorted()) : nil
    }
}
