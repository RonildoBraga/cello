import SwiftUI

@MainActor
struct MelodyRhythmView: View {
    @ObservedObject var store: MelodyRhythmStore
    @ObservedObject var capture: CaptureController
    var piece: MelodyPiece = .hotCrossBuns
    @State private var section = MelodySection.phrase1

    private var context: MelodyRhythmContext { piece.rhythm(section: section) }

    /// The four phrases, then all of them together. That last part is tapped,
    /// so it is not called "Whole melody", which is the lesson where it is hummed.
    private static let parts = MelodySection.phrases + [.whole]
    private static func title(_ section: MelodySection) -> String {
        section == .whole ? "All phrases" : section.title
    }

    var body: some View {
        MelodyRhythmRoundView(store: store, capture: capture, context: context,
                              patternHint: piece.rhythmHint(for: section),
                              parts: LessonParts(Self.parts, current: section, noun: "Part", title: Self.title,
                                                 passed: store.progress(for: context).passed) { section = $0 }) { locked in
            VStack(alignment: .leading, spacing: 12) {
                LessonHeader(subtitle: "Tap once when each note starts. Keep counting while a long note continues.",
                           collapsesSubtitle: store.progress(for: context).successfulAttempts > 0)
                HStack {
                    ChoiceMenu(choices: Self.parts, selection: $section, title: Self.title) {
                        store.progress(for: piece.rhythm(section: $0)).completed
                    }.disabled(locked).accessibilityIdentifier("melodyRhythmSectionPicker")
                    Spacer()
                    Text("\(Int(context.duration)) seconds · \(context.reference.tempoBPM) BPM")
                        .font(.caption).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("melodyRhythmDuration")
                }
                if let best = store.bestStars(for: context) {
                    let latest = store.latestStars(for: context).map { "\($0) / 3" } ?? "unrated"
                    Text("Best \(best) / 3 stars · Latest \(latest)")
                        .font(.caption).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("melodyRhythmSavedScores")
                }
            }
        }.id("\(piece.rawValue)|\(section.rawValue)")
            .screenTitle(piece.title)
    }
}

/// A round owns its clock and frozen score; cancelled rounds never become attempts.
@MainActor
private struct MelodyRhythmRoundView<Header: View>: View {
    @ObservedObject var store: MelodyRhythmStore
    @ObservedObject var capture: CaptureController
    let context: MelodyRhythmContext
    let patternHint: String
    let parts: LessonParts
    @ViewBuilder let header: (Bool) -> Header
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isVisible = false
    @StateObject private var round = RhythmRound<MelodyRhythmTiming>()
    @State private var finishedAttempt: MelodyRhythmAttempt?

    private var running: Bool { round.running }
    private var locked: Bool { running || capture.isPlayingReference }
    private var elapsed: Double? {
        if capture.isPlayingReference { return capture.referenceElapsed }
        guard running, let timing = round.timing, round.now >= timing.practiceStartTime else { return nil }
        return max(0, round.now - timing.practiceStartTime)
    }

    var body: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    header(locked).id("melodyRhythmTop")
                    // Hearing the phrase comes before tapping it, so the button stays in view above the pattern.
                    HStack {
                        Label("Recorded hum", systemImage: "waveform").font(.caption)
                            .foregroundStyle(Palette.muted)
                        Spacer()
                        Button {
                            guard isVisible, !running, scenePhase == .active else { return }
                            capture.playMelodyReference(context.reference)
                        } label: {
                            Label(context.reference.section == .whole ? "Hear melody" : "Hear phrase",
                                  systemImage: "speaker.wave.2")
                        }.buttonStyle(SecondaryActionButtonStyle()).disabled(locked)
                            .accessibilityIdentifier("melodyRhythmHearButton")
                    }
                    if let attempt = finishedAttempt, !capture.isPlayingReference {
                        VStack(spacing: 16) {
                            MelodyRhythmResultView(attempt: attempt, errorMessage: store.errorMessage)
                            progress
                            MelodyRhythmTimingChart(attempt: attempt)
                        }.id("melodyRhythmResult")
                    } else {
                        pattern
                        tapCard
                        if !running { progress }
                    }
                    if finishedAttempt == nil, let error = store.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    if let message = capture.message {
                        Text(message).font(.footnote).foregroundStyle(Palette.muted)
                            .accessibilityIdentifier("melodyRhythmAudioMessage")
                    }
                }.screenContent()
            }.onChange(of: round.running) { _, active in
                if active {
                    withAnimation(reduceMotion ? nil : .default) {
                        scroll.scrollTo("melodyRhythmPattern", anchor: .top)
                    }
                }
            }.onChange(of: capture.isPlayingReference) { _, playing in
                if playing, isVisible {
                    withAnimation(reduceMotion ? nil : .default) {
                        scroll.scrollTo("melodyRhythmPattern", anchor: .top)
                    }
                }
            }.onChange(of: finishedAttempt?.id) { _, id in
                withAnimation(reduceMotion ? nil : .default) {
                    scroll.scrollTo(id == nil ? (running ? "melodyRhythmPattern" : "melodyRhythmTop")
                                    : "melodyRhythmResult", anchor: .top)
                }
            }
        }.background(Palette.paper)
            .bottomActionBar(lessonsLocked: locked, parts: parts) {
                RhythmStartButton(round: round, listening: capture.isPlayingReference) {
                    if running { round.stop() }
                    else if capture.isPlayingReference { capture.stop() }
                    else { start() }
                }.accessibilityIdentifier("melodyRhythmStartButton")
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false; round.stop(); capture.stop() }
            .onChange(of: scenePhase) { _, phase in
                if isVisible, phase != .active { round.stop(); capture.stop() }
            }
    }

    private var progress: some View {
        PracticeProgressView(progress: store.progress(for: context), attemptNoun: "rounds")
    }

    private var pattern: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("Note lengths")
                Spacer()
                Text("in beats").font(.caption).foregroundStyle(Palette.muted)
            }
            MelodyNotesView(context: context.reference, elapsed: elapsed, labelStyle: .rhythm,
                            focusOnCurrentPhrase: running || capture.isPlayingReference)
            Text(patternHint).font(.footnote).foregroundStyle(Palette.muted)
        }.card().accessibilityIdentifier("melodyRhythmPatternInstructions").id("melodyRhythmPattern")
    }

    private var tapCard: some View {
        RhythmTapCard(round: round, tempoBPM: context.reference.tempoBPM, listening: capture.isPlayingReference,
                      cue: capture.isPlayingReference ? "Listen to the pattern."
                        : running ? elapsed == nil ? "Get ready to tap." : "Feel each beat. Tap only when a note starts."
                        : "Count 1–2–3–4, then tap as each dot reaches the line.",
                      count: "\(round.timing?.offsets.count ?? 0) / \(context.expectedTapTimes.count) starts · \(round.timing?.unexpectedTapCount ?? 0) extra",
                      tapLabel: "Tap at each note start",
                      tapHint: running ? "" : "Tap Start, then wait for the count-in.",
                      identifiers: .init(phase: "melodyRhythmPhase", beat: "melodyRhythmBeat",
                                         tap: "melodyRhythmTapButton", count: "melodyRhythmTapCount"),
                      beatLabel: { timing, _, now in
                          "\(Int(max(0, now - timing.practiceStartTime) / timing.beatInterval) + 1)"
                      })
    }

    private func start() {
        guard isVisible, !running, !capture.isPlayingReference, !capture.isRecording,
              scenePhase == .active else { return }
        finishedAttempt = nil
        round.start({ MelodyRhythmTiming(startTime: $0, context: context) }) { timing, time, id in
            finishedAttempt = store.record(timing: timing, at: time, id: id)
        }
    }
}
