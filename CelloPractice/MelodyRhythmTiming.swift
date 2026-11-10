import Foundation

/// Rhythm uses the shared frozen score, with its own assessment version.
/// The reference's vocal register is playback metadata, not a rhythm achievement.
struct MelodyRhythmContext: Codable, Equatable, Sendable {
    static let currentScoringVersion = 1
    static let countInBeats = 4

    let reference: MelodyPracticeContext
    let scoringVersion: Int

    init(reference: MelodyPracticeContext, scoringVersion: Int = currentScoringVersion) {
        self.reference = reference
        self.scoringVersion = scoringVersion
    }

    static func hotCrossBuns(section: MelodySection = .phrase1,
                             tempoBPM: Int = 60) throws -> MelodyRhythmContext {
        try melody(piece: .hotCrossBuns, section: section, tempoBPM: tempoBPM)
    }

    static func melody(piece: MelodyPiece, section: MelodySection = .phrase1,
                       tempoBPM: Int = 60) throws -> MelodyRhythmContext {
        MelodyRhythmContext(reference: try .melody(piece: piece, register: .lowVoice,
                                                  section: section, tempoBPM: tempoBPM))
    }

    var isValid: Bool {
        reference.isValid && reference.gradingVersion == nil && scoringVersion > 0
            && reference.expectedEvents.contains(where: { $0.midiNote != nil })
    }

    var beatInterval: TimeInterval { 60 / Double(reference.tempoBPM) }
    var countInDuration: TimeInterval { Double(Self.countInBeats) * beatInterval }
    var duration: TimeInterval { reference.duration }
    var expectedTapTimes: [TimeInterval] {
        reference.expectedEvents.compactMap { event in
            event.midiNote == nil ? nil : event.onsetBeat * beatInterval
        }
    }

    /// A narrow gap between adjacent windows keeps a halfway touch from being
    /// silently assigned to either of two quick notes.
    func tapWindow(for index: Int) -> TimeInterval {
        let times = expectedTapTimes
        guard isValid, times.indices.contains(index) else { return 0 }
        var intervals: [TimeInterval] = []
        if index > 0 { intervals.append(times[index] - times[index - 1]) }
        if index + 1 < times.count { intervals.append(times[index + 1] - times[index]) }
        return min(0.45, (intervals.min() ?? duration) * 0.45)
    }
}

/// Taps are measured against absolute monotonic time, never UI refresh ticks.
struct MelodyRhythmTiming {
    enum Phase: Equatable {
        case countIn(Int)
        case tapping(Int)
        case finished
    }

    static let duplicateInterval: TimeInterval = 0.05

    let startTime: TimeInterval
    let context: MelodyRhythmContext
    private(set) var offsets: [Int: TimeInterval] = [:]
    private(set) var unexpectedTapCount = 0
    /// Relative to the first practice beat; includes unmatched deliberate taps.
    private(set) var actualTapTimes: [TimeInterval] = []

    init(startTime: TimeInterval, context: MelodyRhythmContext) {
        self.startTime = startTime
        self.context = context
    }

    var practiceStartTime: TimeInterval { startTime + context.countInDuration }
    var endTime: TimeInterval { practiceStartTime + context.duration }

    private var hasValidClock: Bool {
        context.isValid && startTime.isFinite && startTime >= 0
            && practiceStartTime.isFinite && practiceStartTime > startTime
            && endTime.isFinite && endTime > practiceStartTime
    }

    func phase(at time: TimeInterval) -> Phase {
        guard hasValidClock, time.isFinite else { return .finished }
        if time >= endTime { return .finished }
        if time < practiceStartTime {
            let beat = Int(max(0, time - startTime) / context.beatInterval)
            return .countIn(max(1, MelodyRhythmContext.countInBeats - beat))
        }
        let elapsed = time - practiceStartTime
        let note = context.expectedTapTimes.lastIndex(where: { $0 <= elapsed }) ?? 0
        return .tapping(note + 1)
    }

    /// Keep the pad active through the whole phrase, including continuing long
    /// notes and rests. An unwanted touch there must remain observable.
    func canTap(at time: TimeInterval) -> Bool {
        hasValidClock && time.isFinite && time >= practiceStartTime && time < endTime
    }

    @discardableResult
    mutating func recordTap(at time: TimeInterval) -> Bool {
        guard canTap(at: time) else { return false }
        let elapsed = time - practiceStartTime
        // Coalesced callbacks from one touch do not create two mistakes. Later
        // presses, including another press near an already filled slot, do.
        if let last = actualTapTimes.last,
           elapsed - last + 1e-9 < Self.duplicateInterval { return false }
        actualTapTimes.append(elapsed)
        let times = context.expectedTapTimes
        guard let index = times.indices.min(by: { abs(times[$0] - elapsed) < abs(times[$1] - elapsed) }) else {
            return false
        }
        let offset = elapsed - times[index]
        guard abs(offset) <= context.tapWindow(for: index) + 1e-9,
              offsets[index] == nil else {
            unexpectedTapCount += 1
            return false
        }
        offsets[index] = offset
        return true
    }
}
