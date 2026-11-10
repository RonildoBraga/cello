import SwiftUI
import UIKit

enum RhythmPhase: Equatable {
    /// Count-in beats remaining, counting down to 1.
    case countIn(Int)
    /// The 1-based tap position the round has reached.
    case tapping(Int)
    case finished
}

/// What a round needs from its timing: when taps are due and how one is recorded.
/// Foundation patterns and piece phrases each supply their own.
protocol RhythmRoundTiming {
    var startTime: TimeInterval { get }
    var beatInterval: TimeInterval { get }
    var offsets: [Int: TimeInterval] { get }
    var unexpectedTapCount: Int { get }
    func phase(at time: TimeInterval) -> RhythmPhase
    func canTap(at time: TimeInterval) -> Bool
    @discardableResult mutating func recordTap(at time: TimeInterval) -> Bool
}

enum RhythmStatistics {
    /// Linear interpolation between neighbouring values; nil for an empty list.
    static func percentile(_ fraction: Double, in sorted: [Double]) -> Double? {
        guard !sorted.isEmpty else { return nil }
        let position = Double(sorted.count - 1) * fraction
        let lower = Int(position)
        let upper = min(lower + 1, sorted.count - 1)
        return sorted[lower] + (sorted[upper] - sorted[lower]) * (position - Double(lower))
    }
}

/// One tapping round: its clock, whole-beat haptics and recorded taps. Timing is
/// measured against the monotonic clock; the refresh rate never decides when a
/// beat is due. A round that is stopped early never reaches `onFinished`.
@MainActor
final class RhythmRound<Timing: RhythmRoundTiming>: ObservableObject {
    @Published private(set) var timing: Timing?
    @Published private(set) var now = ProcessInfo.processInfo.systemUptime
    @Published private(set) var running = false

    private var ticker: Task<Void, Never>?
    private var roundID: UUID?
    private var finished = false

    var phase: RhythmPhase? { timing?.phase(at: now) }
    var canTap: Bool { running && (timing?.canTap(at: now) ?? false) }
    var beatIsBright: Bool {
        guard running, let timing else { return false }
        return max(0, now - timing.startTime).truncatingRemainder(dividingBy: timing.beatInterval) < 0.2
    }

    func start(_ makeTiming: (TimeInterval) -> Timing,
               onFinished: @escaping (Timing, TimeInterval, UUID) -> Void) {
        stop()
        let startTime = ProcessInfo.processInfo.systemUptime
        let id = UUID()
        timing = makeTiming(startTime)
        roundID = id
        finished = false
        now = startTime
        running = true
        ticker = Task { @MainActor [weak self] in
            var previousBeat = -1
            while !Task.isCancelled {
                guard let self, self.running, self.roundID == id else { return }
                guard UIApplication.shared.applicationState == .active else {
                    self.stop()
                    return
                }
                let time = ProcessInfo.processInfo.systemUptime
                self.now = time
                guard let timing = self.timing else { return }
                if timing.phase(at: time) == .finished {
                    self.finished = true
                    self.running = false
                    self.ticker = nil
                    onFinished(timing, time, id)
                    return
                }
                let beat = Int(max(0, time - timing.startTime) / timing.beatInterval)
                if beat != previousBeat {
                    previousBeat = beat
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
                do { try await Task.sleep(nanoseconds: 33_000_000) }
                catch { return }
            }
        }
    }

    /// Cancels an unfinished round. A finished round keeps its timing until the next start.
    func stop() {
        ticker?.cancel()
        ticker = nil
        running = false
        roundID = nil
        if !finished { timing = nil }
    }

    func tap() {
        guard running else { return }
        timing?.recordTap(at: ProcessInfo.processInfo.systemUptime)
    }
}

/// The dark card every rhythm activity taps on: phase, beat, cue, tap pad and count.
struct RhythmTapCard<Timing: RhythmRoundTiming, Idle: View>: View {
    struct Identifiers {
        var phase = "rhythmPhase"
        var beat = "rhythmBeat"
        var tap = "rhythmTapButton"
        var count = "rhythmTapCount"
    }

    @ObservedObject var round: RhythmRound<Timing>
    let tempoBPM: Int
    /// True while a reference plays instead of a round.
    var listening = false
    let cue: String
    let count: String
    let tapLabel: String
    let tapHint: String
    var identifiers = Identifiers()
    /// What to show in the beat circle for a 1-based tap position at a given time.
    let beatLabel: (Timing, Int, TimeInterval) -> String
    /// Whether `idle` replaces the beat and cue before a round starts.
    var showsIdle = false
    @ViewBuilder var idle: Idle

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        StatusCard(label: phaseTitle, labelIdentifier: identifiers.phase) {
            Text("\(tempoBPM) BPM")
        } content: {
            if showsIdle, round.timing == nil, !listening {
                idle
            } else {
                HStack(spacing: 18) {
                    StatusValue(text: beat, isCount: true).padding(10)
                        .frame(width: 88, height: 88)
                        .background(.white.opacity(round.beatIsBright ? 0.20 : 0.07), in: Circle())
                        .scaleEffect(round.beatIsBright && !reduceMotion ? 1.035 : 1)
                        .accessibilityIdentifier(identifiers.beat)
                    Text(cue).font(.subheadline).foregroundStyle(.white.opacity(0.85))
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            Button { round.tap() } label: {
                Label("Tap", systemImage: "hand.tap").font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 72)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: Layout.controlRadius))
            }.buttonStyle(.plain).disabled(!round.canTap).opacity(round.canTap ? 1 : 0.45)
                .accessibilityLabel(tapLabel).accessibilityHint(tapHint)
                .accessibilityIdentifier(identifiers.tap)
            Text(count).font(.caption).foregroundStyle(.white.opacity(0.7))
                .accessibilityIdentifier(identifiers.count)
        }.accessibilityElement(children: .contain)
    }

    private var phaseTitle: String {
        if listening { return "Listen" }
        switch round.phase {
        case nil: return "Ready"
        case .countIn: return "Count in"
        case .tapping: return "Tap"
        case .finished: return "Complete"
        }
    }

    private var beat: String {
        if listening { return "♪" }
        guard let timing = round.timing else { return "—" }
        switch timing.phase(at: round.now) {
        case .countIn(let remaining): return "\(remaining)"
        case .tapping(let tap): return beatLabel(timing, tap, round.now)
        case .finished: return "✓"
        }
    }
}

extension RhythmTapCard where Idle == EmptyView {
    init(round: RhythmRound<Timing>, tempoBPM: Int, listening: Bool = false, cue: String, count: String,
         tapLabel: String, tapHint: String, identifiers: Identifiers = Identifiers(),
         beatLabel: @escaping (Timing, Int, TimeInterval) -> String) {
        self.init(round: round, tempoBPM: tempoBPM, listening: listening, cue: cue, count: count,
                  tapLabel: tapLabel, tapHint: tapHint, identifiers: identifiers, beatLabel: beatLabel) { EmptyView() }
    }
}

/// Start, Stop or Try again for a round.
struct RhythmStartButton<Timing: RhythmRoundTiming>: View {
    @ObservedObject var round: RhythmRound<Timing>
    /// True while a reference plays; the button then cancels playback.
    var listening = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(round.running ? "Stop" : listening ? "Cancel" : round.timing == nil ? "Start" : "Try again",
                  systemImage: round.running || listening ? "stop.fill" : "play.fill")
        }.buttonStyle(PrimaryActionButtonStyle())
    }
}
