import SwiftUI

struct PulsePracticeView<Header: View>: View {
    @ObservedObject var store: PulsePracticeStore
    let nextLesson: PracticeLesson?
    let onNext: ((PracticeLesson) -> Void)?
    private let header: Header
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var round = RhythmRound<PulseTiming>()
    @State private var finishedAttempt: PulseAttempt?

    init(store: PulsePracticeStore, nextLesson: PracticeLesson? = nil,
         onNext: ((PracticeLesson) -> Void)? = nil, @ViewBuilder header: () -> Header) {
        self.store = store
        self.nextLesson = nextLesson
        self.onNext = onNext
        self.header = header()
    }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header.id("pulseTop")
                    if let finishedAttempt {
                        VStack(spacing: 16) {
                            result(for: finishedAttempt)
                            PracticeProgressView(progress: store.progress, nextLesson: nextLesson,
                                                 onNext: onNext, attemptNoun: "rounds")
                            PulseTimingChartView(attempt: finishedAttempt)
                        }.id("pulseResult")
                    } else {
                        if round.timing == nil {
                            PracticeProgressView(progress: store.progress, nextLesson: nextLesson,
                                                 onNext: onNext, attemptNoun: "rounds")
                        }
                        tapCard
                    }
                }.screenContent()
            }
            .onChange(of: finishedAttempt?.id) { _, id in
                withAnimation(reduceMotion ? nil : .default) {
                    scroll.scrollTo(id == nil ? "pulseTop" : "pulseResult", anchor: .top)
                }
            }
        }.bottomActionBar {
            RhythmStartButton(round: round) {
                if round.running { round.stop() } else { start() }
            }
        }
            .background(Palette.paper)
            .onDisappear { round.stop() }
            .onChange(of: scenePhase) { _, phase in if phase != .active { round.stop() } }
    }

    private var tapCard: some View {
        RhythmTapCard(round: round, tempoBPM: 60, cue: phaseCue, count: roundCount,
                      tapLabel: "Tap on the beat", tapHint: tapHint,
                      identifiers: .init(phase: "pulsePhase", beat: "pulseBeat", tap: "pulseTapButton",
                                         count: "pulseTapCount"),
                      beatLabel: { timing, tap, _ in timing.exercise.beatLabel(forTap: tap) },
                      showsIdle: store.exercise != .pulse) { rhythmInstructions }
    }

    private var rhythmInstructions: some View {
        let mixed = store.exercise == .mixedRhythm
        let tokens = mixed ? ["1", "2 &", "3", "4 &"] : ["1", "&", "2", "&"]
        return VStack(alignment: .leading, spacing: 14) {
            Text(mixed ? "One tap, then two. Keep the same beat." : "One tap on the beat. One between.").font(.headline)
            HStack(spacing: 8) {
                ForEach(0..<4) { index in
                    VStack(spacing: 5) {
                        Text(tokens[index])
                            .font(.system(.title, design: .rounded).weight(.medium))
                            .lineLimit(1).minimumScaleFactor(0.5)
                        Text(mixed ? (index.isMultiple(of: 2) ? "one tap" : "two taps")
                             : (index.isMultiple(of: 2) ? "beat" : "between")).font(.caption2)
                    }.frame(maxWidth: .infinity).padding(.vertical, 10)
                        .background(.white.opacity(index.isMultiple(of: 2) ? 0.16 : 0.07),
                                    in: RoundedRectangle(cornerRadius: Layout.tileRadius))
                }
            }.accessibilityElement(children: .ignore)
                .accessibilityLabel(mixed ? "Count one, two and, three, four and. Tap once on odd numbers and twice on even numbers."
                                    : "Count one and two and. Tap on every number and every and.")
                .accessibilityIdentifier(mixed ? "mixedRhythmCountPattern" : "twoTapsCountPattern")
            Text(mixed ? "Tap with every vibration. Add an ‘and’ halfway after 2, 4, 6 and 8; leave the space after 1, 3, 5 and 7."
                 : "& means “and”. Tap the pad with each vibration on a number, then once halfway to the next vibration.")
                .font(.subheadline).foregroundStyle(.white.opacity(0.85))
            Text(mixed ? "Tap Start, wait for 4–3–2–1, then count through 8 &: 12 taps across 8 beats."
                 : "Tap Start, wait for 4–3–2–1, then keep going to 8 &. No humming needed.")
                .font(.caption).foregroundStyle(.white.opacity(0.70))
        }.fixedSize(horizontal: false, vertical: true).foregroundStyle(.white)
            .accessibilityElement(children: .contain)
            .accessibilityIdentifier(mixed ? "mixedRhythmInstructions" : "twoTapsInstructions")
    }

    private var tapHint: String {
        switch store.exercise {
        case .pulse: return "Tap once with each pulse after the count-in."
        case .twoTaps: return "Tap twice with each pulse after the count-in."
        case .mixedRhythm: return "After the count-in, tap once on odd numbers and twice on even numbers."
        }
    }

    private var roundCount: String {
        guard let timing = round.timing else {
            switch store.exercise {
            case .pulse: return "One beat each second."
            case .twoTaps: return "Two taps each second · 8 beats."
            case .mixedRhythm: return "12 taps · 8 beats · 60 BPM."
            }
        }
        let noun = store.exercise == .pulse ? "beats" : "taps · \(store.exercise.wholeBeats) beats"
        let extra = store.exercise == .mixedRhythm ? " · \(timing.unexpectedTapCount) extra" : ""
        return "\(timing.offsets.count) / \(store.exercise.tapCount) \(noun)\(extra)"
    }

    private var phaseCue: String {
        guard let timing = round.timing, let phase = round.phase else {
            return store.exercise == .pulse ? "Watch four count-in beats, then tap 16 pulses."
                : "Count in four beats, then tap 1 & 2 & across 8 beats."
        }
        switch phase {
        case .countIn: return "Get ready to tap."
        case .tapping:
            return timing.exercise == .pulse ? "Keep an even beat."
                : timing.exercise == .twoTaps ? "Tap on each number and &." : "One tap on odd numbers; two on even numbers."
        case .finished: return "Round complete."
        }
    }

    private func result(for attempt: PulseAttempt) -> some View {
        let mixed = attempt.exercise == .mixedRhythm
        let goalTitle = mixed ? "Pattern" : attempt.exercise == .pulse ? "Beats" : "Taps"
        let noun = mixed ? "places" : attempt.exercise == .pulse ? "beats" : "taps"
        let coverageRule = "\(goalTitle) · Tap at least \(attempt.exercise.coverageTarget) of the \(attempt.exercise.tapCount) \(noun)"
            + (mixed ? ", with no more than one extra tap." : ".")
        let feedback = (attempt.starCount == 3 ? "All three goals reached." : attempt.cue)
            + (mixed ? " \(attempt.unexpectedTapCount) extra taps." : "")
        return PracticeResultCard(starCount: attempt.starCount, goals: [
            PracticeGoal(title: goalTitle, earned: attempt.beatsGoal, identifier: "pulse.beats"),
            PracticeGoal(title: "Timing", earned: attempt.timingGoal, identifier: "pulse.timing"),
            PracticeGoal(title: "Evenness", earned: attempt.evennessGoal, identifier: "pulse.evenness")
        ], feedback: feedback, starRules: [
            coverageRule,
            "Timing · Land within 150 ms of each expected tap for 75% of your taps.",
            "Evenness · Keep the middle 80% of your tap offsets within a 200 ms range."
        ], title: "This round", unscoredLabel: "Couldn’t rate this round", unscoredSystemImage: "hand.tap",
           identifiers: PracticeResultIdentifiers(stars: "pulse.stars", unscored: "pulse.unscored", feedback: "pulse.feedback"),
           errorMessage: store.errorMessage)
        .accessibilityIdentifier("pulse.result")
    }

    private func start() {
        guard scenePhase == .active else { return }
        finishedAttempt = nil
        round.start({ PulseTiming(startTime: $0, exercise: store.exercise) }) { timing, time, id in
            finishedAttempt = store.record(timing: timing, at: time, id: id)
        }
    }
}
