import SwiftUI

@MainActor
struct MelodyRhythmView: View {
    @ObservedObject var store: MelodyRhythmStore
    @ObservedObject var capture: CaptureController
    var piece: MelodyPiece = .hotCrossBuns
    @State private var section = MelodySection.phrase1

    private var context: MelodyRhythmContext { try! .melody(piece: piece, section: section) }
    private var nextSection: MelodySection? {
        switch section {
        case .phrase1: return .phrase2
        case .phrase2: return .phrase3
        case .phrase3: return .phrase4
        case .phrase4: return .whole
        case .whole: return nil
        }
    }

    var body: some View {
        MelodyRhythmRoundView(store: store, capture: capture, context: context,
                              onNext: nextSection.map { next in { section = next } }) { locked in
            VStack(alignment: .leading, spacing: 12) {
                ScreenHeader(eyebrow: piece.title, title: "Rhythm",
                             subtitle: "Tap once when each note starts. Keep counting while a long note continues.")
                HStack {
                    Menu {
                        ForEach(MelodySection.allCases) { item in
                            Button { section = item } label: {
                                let choice = try! MelodyRhythmContext.melody(piece: piece, section: item)
                                if store.progress(for: choice).completed {
                                    Label("\(item.title) · completed", systemImage: "checkmark.circle.fill")
                                } else if item == section { Label(item.title, systemImage: "checkmark") }
                                else { Text(item.title) }
                            }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Text(section.title).font(.headline)
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                        }.foregroundStyle(Palette.forest).frame(minHeight: 44)
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
    let onNext: (() -> Void)?
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
                    if let attempt = finishedAttempt, !capture.isPlayingReference {
                        VStack(spacing: 16) {
                            MelodyRhythmResultView(attempt: attempt, errorMessage: store.errorMessage)
                            progress
                            MelodyRhythmTimingChart(attempt: attempt)
                        }.id("melodyRhythmResult")
                    } else {
                        if !running { progress }
                        pattern
                        tapCard
                    }
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
            .bottomActionBar {
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
        HStack {
            let saved = store.progress(for: context)
            PracticeProgressView(progress: saved, disabled: locked, attemptNoun: "rounds")
            if let onNext {
                Button(saved.completed ? "Next phrase" : "Try next phrase", action: onNext)
                    .font(.caption.weight(.semibold)).foregroundStyle(Palette.forest)
                    .disabled(locked).accessibilityIdentifier("nextRhythmPhraseButton")
            }
        }
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
            Text(patternInstructions)
                .font(.footnote).foregroundStyle(Palette.muted)
        }.card().accessibilityIdentifier("melodyRhythmPatternInstructions").id("melodyRhythmPattern")
    }

    private var patternInstructions: String {
        if context.reference.section == .whole {
            return "Tap at each new tile. Keep counting through the longer tiles."
        }
        if context.reference.pieceID == MelodyPiece.odeToJoy.rawValue {
            return context.reference.section == .phrase4
                ? "Tap on 1, the & after 2, and 3. Count 4 while the last note continues."
                : "Tap on each beat: 1, 2, 3, 4."
        }
        return context.reference.section == .phrase3
            ? "Two short notes per beat: 1 & 2 & 3 & 4 &."
            : "Tap on 1, 2 and 3. Count 4 while the last note continues."
    }

    private var tapCard: some View {
        RhythmTapCard(round: round, tempoBPM: context.reference.tempoBPM, listening: capture.isPlayingReference,
                      cue: capture.isPlayingReference ? "Listen to the pattern."
                        : running ? elapsed == nil ? "Get ready to tap." : "Feel each beat. Tap only when a note starts."
                        : "Wait for 4–3–2–1, then tap the pattern.",
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
