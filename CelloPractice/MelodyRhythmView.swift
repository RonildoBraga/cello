import SwiftUI
import UIKit

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
                Text("Rhythm").font(.system(size: 27, weight: .semibold, design: .serif))
                    .foregroundStyle(Palette.ink)
                Text("Tap once when each note starts. Keep counting while a long note continues.")
                    .font(.footnote).foregroundStyle(Palette.muted)
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
            .navigationTitle(piece.title).navigationBarTitleDisplayMode(.inline)
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
    @State private var timing: MelodyRhythmTiming?
    @State private var now = ProcessInfo.processInfo.systemUptime
    @State private var running = false
    @State private var ticker: Task<Void, Never>?
    @State private var attemptID: UUID?
    @State private var finishedAttempt: MelodyRhythmAttempt?

    private var locked: Bool { running || capture.isPlayingReference }
    private var elapsed: Double? {
        if capture.isPlayingReference { return capture.referenceElapsed }
        guard running, let timing, now >= timing.practiceStartTime else { return nil }
        return max(0, now - timing.practiceStartTime)
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
                                .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                        }.disabled(locked).foregroundStyle(Palette.forest)
                            .accessibilityIdentifier("melodyRhythmHearButton")
                    }
                    if finishedAttempt == nil, let error = store.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                    if let message = capture.message {
                        Text(message).font(.footnote).foregroundStyle(Palette.muted)
                            .accessibilityIdentifier("melodyRhythmAudioMessage")
                    }
                }.padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 24)
            }.onChange(of: running) { _, active in
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
            .safeAreaInset(edge: .bottom, spacing: 0) { actionControls }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false; stop(); capture.stop() }
            .onChange(of: scenePhase) { _, phase in
                if isVisible, phase != .active { stop(); capture.stop() }
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
                Text("Note lengths").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Spacer()
                Text("in beats").font(.caption).foregroundStyle(Palette.muted)
            }
            MelodyNotesView(context: context.reference, elapsed: elapsed, labelStyle: .rhythm,
                            focusOnCurrentPhrase: running || capture.isPlayingReference)
            Text(patternInstructions)
                .font(.footnote).foregroundStyle(Palette.muted)
        }.padding(17).background(.white, in: RoundedRectangle(cornerRadius: 19))
            .accessibilityIdentifier("melodyRhythmPatternInstructions").id("melodyRhythmPattern")
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
        VStack(spacing: 14) {
            HStack {
                Text(phaseTitle).font(.system(size: 10, weight: .semibold)).tracking(1.6)
                    .accessibilityIdentifier("melodyRhythmPhase")
                Spacer()
                Text("\(context.reference.tempoBPM) BPM").font(.caption)
            }.foregroundStyle(.white.opacity(0.65))
            HStack(spacing: 18) {
                Text(beatLabel).font(.system(size: 54, weight: .light, design: .rounded)).monospacedDigit()
                    .frame(width: 85, height: 85)
                    .background(.white.opacity(pulseIsBright ? 0.20 : 0.07), in: Circle())
                    .accessibilityIdentifier("melodyRhythmBeat")
                Text(capture.isPlayingReference ? "Listen to the pattern."
                     : running ? elapsed == nil ? "Get ready to tap." : "Feel each beat. Tap only when a note starts."
                        : "Wait for 4–3–2–1, then tap the pattern.")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.85))
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Button {
                guard isVisible, running else { return }
                timing?.recordTap(at: ProcessInfo.processInfo.systemUptime)
            } label: {
                Label("Tap", systemImage: "hand.tap").font(.headline)
                    .frame(maxWidth: .infinity, minHeight: 68)
                    .background(.white.opacity(0.14), in: RoundedRectangle(cornerRadius: 16))
            }.buttonStyle(.plain).disabled(!running || !(timing?.canTap(at: now) ?? false))
                .opacity(running && (timing?.canTap(at: now) ?? false) ? 1 : 0.45)
                .accessibilityLabel("Tap at each note start")
                .accessibilityIdentifier("melodyRhythmTapButton")
            Text("\(timing?.offsets.count ?? 0) / \(context.expectedTapTimes.count) starts · \(timing?.unexpectedTapCount ?? 0) extra")
                .font(.caption).foregroundStyle(.white.opacity(0.65))
                .accessibilityIdentifier("melodyRhythmTapCount")
        }.foregroundStyle(.white).padding(20)
            .background(Palette.forest, in: RoundedRectangle(cornerRadius: 24))
    }

    private var actionControls: some View {
        Button {
            if running { stop() }
            else if capture.isPlayingReference { capture.stop() }
            else { start() }
        } label: {
            Label(running ? "Stop" : capture.isPlayingReference ? "Cancel" : timing == nil ? "Start" : "Try again",
                  systemImage: running || capture.isPlayingReference ? "stop.fill" : "play.fill")
                .font(.headline).foregroundStyle(.white).frame(maxWidth: .infinity, minHeight: 56)
                .background(Palette.forest, in: RoundedRectangle(cornerRadius: 18))
        }.buttonStyle(.plain).accessibilityIdentifier("melodyRhythmStartButton")
            .padding(.horizontal, 22).padding(.vertical, 12).background(Palette.paper)
    }

    private var phaseTitle: String {
        if capture.isPlayingReference { return "Listen" }
        guard let timing else { return "Ready" }
        switch timing.phase(at: now) {
        case .countIn: return "Count in"
        case .tapping: return "Tap"
        case .finished: return "Complete"
        }
    }

    private var beatLabel: String {
        guard !capture.isPlayingReference else { return "♪" }
        guard let timing else { return "—" }
        switch timing.phase(at: now) {
        case .countIn(let value): return "\(value)"
        case .tapping: return "\(Int(max(0, now - timing.practiceStartTime) / context.beatInterval) + 1)"
        case .finished: return "✓"
        }
    }

    private var pulseIsBright: Bool {
        guard running, let timing else { return false }
        return max(0, now - timing.startTime).truncatingRemainder(dividingBy: context.beatInterval) < 0.18
    }

    private func start() {
        guard isVisible, !running, !capture.isPlayingReference, !capture.isRecording, scenePhase == .active else { return }
        stop()
        let startTime = ProcessInfo.processInfo.systemUptime
        timing = MelodyRhythmTiming(startTime: startTime, context: context)
        let id = UUID()
        attemptID = id
        finishedAttempt = nil
        now = startTime
        running = true
        ticker = Task { @MainActor in
            var previousBeat = -1
            while !Task.isCancelled {
                guard running, attemptID == id, isVisible, scenePhase == .active,
                      UIApplication.shared.applicationState == .active else { stop(); return }
                now = ProcessInfo.processInfo.systemUptime
                guard let timing else { return }
                if timing.phase(at: now) == .finished {
                    finishedAttempt = store.record(timing: timing, at: now, id: id)
                    running = false
                    ticker = nil
                    return
                }
                let beat = Int(max(0, now - startTime) / context.beatInterval)
                if beat != previousBeat {
                    previousBeat = beat
                    UIImpactFeedbackGenerator(style: .soft).impactOccurred()
                }
                do { try await Task.sleep(nanoseconds: 33_000_000) }
                catch { return }
            }
        }
    }

    private func stop() {
        ticker?.cancel()
        ticker = nil
        running = false
        attemptID = nil
        if finishedAttempt == nil { timing = nil }
    }
}
