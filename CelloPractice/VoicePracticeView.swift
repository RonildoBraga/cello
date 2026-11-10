import SwiftUI
import AVFoundation
import UIKit

/// Recording lifecycle stays scoped to one frozen lesson/reference. SessionStore
/// owns the durable result after this screen disappears.
@MainActor
struct VoicePracticeView<Header: View>: View {
    private enum Phase: Equatable {
        case idle, preparing, previewing, counting, startingRecording, recording
    }

    @ObservedObject var store: SessionStore
    @ObservedObject private var capture: CaptureController
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var phase: Phase = .idle
    @State private var pendingRecord = false
    @State private var flowToken = UUID()
    @State private var cameraExpanded = false
    @State private var countInSeconds = 0
    @State private var countInTask: Task<Void, Never>?
    @State private var restSeconds = 0
    @State private var restTask: Task<Void, Never>?
    @State private var timedRecording = false
    @State private var stopRequested = false
    @State private var saving = false
    @State private var saved = false
    @State private var referenceWasHeard = false
    @State private var latestSession: PracticeSession?
    private var hasResult: Bool { latestSession?.rating != nil || latestSession?.melodyRating != nil }

    let exercise: Exercise
    let section: PracticeSection
    private let targetFrequency: Double
    private let melodyContext: MelodyPracticeContext?
    private let onNextPhrase: (() -> Void)?
    private let nextLesson: PracticeLesson?
    private let onStartLesson: (PracticeLesson) -> Void
    private let onShowLessons: () -> Void
    private let header: (Bool) -> Header

    init(store: SessionStore, capture: CaptureController, exercise: Exercise,
         nextLesson: PracticeLesson?, onStartLesson: @escaping (PracticeLesson) -> Void,
         onShowLessons: @escaping () -> Void, @ViewBuilder header: @escaping (Bool) -> Header) {
        guard let section = exercise.section else {
            preconditionFailure("A guided recording must have a voice or cello target")
        }
        self.store = store
        self.capture = capture
        self.exercise = exercise
        self.section = section
        self.targetFrequency = section.effectiveTarget(for: exercise)
        self.melodyContext = nil
        self.onNextPhrase = nil
        self.nextLesson = nextLesson
        self.onStartLesson = onStartLesson
        self.onShowLessons = onShowLessons
        self.header = header
    }

    init(store: SessionStore, capture: CaptureController, context: MelodyPracticeContext,
         onNextPhrase: (() -> Void)?, @ViewBuilder header: @escaping (Bool) -> Header) {
        precondition(context.isValid && context.gradingVersion == MelodyRating.currentVersion)
        self.store = store
        self.capture = capture
        self.exercise = .listen
        self.section = .humming
        self.targetFrequency = context.expectedEvents.compactMap { context.frequency(for: $0) }.first ?? context.tuningA4Hz
        self.melodyContext = context
        self.onNextPhrase = onNextPhrase
        self.nextLesson = nil
        self.onStartLesson = { _ in }
        self.onShowLessons = {}
        self.header = header
    }

    private var echoSelection: (level: EchoLevel, patternIndex: Int)? {
        melodyContext.flatMap { EchoLevel.selection(for: $0) }
    }
    private var isEcho: Bool { echoSelection != nil }
    private var needsEchoReference: Bool { isEcho && !referenceWasHeard && phase == .idle && !capture.isRecording }

    var body: some View {
        recordingPracticeScreen
            .toolbar {
                if melodyContext == nil {
                    ToolbarItem(placement: .topBarLeading) {
                        PracticeLessonsButton(disabled: controlsLocked) {
                            cancelFlow(stopCapture: true)
                            onShowLessons()
                        }
                    }
                }
                if capture.isReady {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { cancelFlow(stopCapture: true) } label: {
                            Image(systemName: "power").frame(width: 44, height: 44)
                        }.disabled(capture.isRecording || saving)
                            .accessibilityLabel("Turn off camera and microphone")
                    }
                }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false; referenceWasHeard = false; cancelFlow(stopCapture: true) }
            .onChange(of: scenePhase) { _, newPhase in
                guard isVisible else { return }
                if newPhase == .background {
                    referenceWasHeard = false
                    cancelFlow(stopCapture: true)
                } else if newPhase == .active {
                    if phase == .preparing { dispatchPendingAction() }
                } else if isEcho && phase == .previewing {
                    referenceWasHeard = false
                    cancelFlow(stopCapture: true)
                } else if phase == .counting {
                    // An overlay must not start a recording behind itself. A
                    // permission dialog, while preparing, keeps the user's intent.
                    cancelFlow(stopCapture: false)
                }
            }
            .onChange(of: capture.isReady) { _, ready in
                guard isVisible else { return }
                if ready {
                    dispatchPendingAction()
                } else if phase != .preparing {
                    cancelFlow(stopCapture: false)
                }
            }
            .onChange(of: capture.isPlayingReference) { wasPlaying, playing in
                guard isVisible else { return }
                guard wasPlaying, !playing else { return }
                if phase == .previewing {
                    if isEcho, capture.message == nil, capture.referenceElapsed >= recordingDuration - 0.05 {
                        referenceWasHeard = true
                    }
                    phase = .idle
                }
            }
            .onChange(of: capture.isRecording) { _, recording in
                guard isVisible else { return }
                if recording { phase = .recording }
                else if phase == .recording || phase == .startingRecording {
                    let needsRest = timedRecording && isVisible
                    phase = .idle
                    timedRecording = false
                    stopRequested = false
                    if needsRest { beginRest() }
                }
            }
            .onChange(of: capture.elapsed) { _, elapsed in
                if isVisible && timedRecording && !stopRequested && elapsed >= recordingDuration {
                    stopRequested = true
                    capture.stopRecording()
                }
            }
            .onReceive(capture.$message) { message in
                // Published messages can repeat (for example after a denied
                // permission retry); every failure must release Preparing.
                if isVisible && message != nil && !capture.isRecording { cancelFlow(stopCapture: true) }
            }
    }

    private var recordingPracticeScreen: some View {
        ScrollViewReader { scroll in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header(controlsLocked || (isEcho && restSeconds > 0))
                    targetControls
                    if let session = latestSession, hasResult, !isBusy && !capture.isRecording && !saving {
                        VStack(spacing: 16) {
                            if let rating = session.melodyRating, let context = session.melodyContext {
                                MelodyFeedbackView(rating: rating, isEcho: isEcho)
                                MelodyTraceView(context: context, rating: rating, duration: session.duration)
                            } else if let rating = session.rating {
                                PracticeRatingView(rating: rating)
                                    .accessibilityIdentifier("latestRatingCard")
                                if let target = session.effectiveTargetFrequency {
                                    PitchTraceView(samples: session.pitchSamples, targetFrequency: target, duration: session.duration)
                                }
                            }
                            lessonProgress
                        }.id("latestRating")
                    } else if isEcho {
                        echoCard
                    } else {
                        tuner
                    }
                    if !hasResult && !isBusy && !capture.isRecording && !saving {
                        lessonProgress
                    }
                    if !isEcho && hasResult && !isBusy && !capture.isRecording && !saving {
                        DisclosureGroup("Live tuner") { tuner.padding(.top, 10) }
                            .font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
                    }
                    if capture.isReady && !isEcho {
                        DisclosureGroup("Camera preview", isExpanded: $cameraExpanded) {
                            camera.padding(.top, 10)
                        }.font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
                    }
                    if let error = store.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }.padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 26)
            }
            .onChange(of: latestSession?.id) { _, id in
                withAnimation {
                    scroll.scrollTo(id == nil ? "practiceTop" : "latestRating", anchor: .top)
                }
            }
        }
        .safeAreaInset(edge: .bottom, spacing: 0) { recordingControls }
    }

    @ViewBuilder private var lessonProgress: some View {
        if let context = melodyContext {
            let progress = echoSelection.map { store.echoProgress(for: $0.level, register: context.register) }
                ?? store.melodyProgress(for: context)
            HStack {
                PracticeProgressView(progress: progress)
                if let onNextPhrase, !isEcho || hasResult {
                    Button(isEcho ? "New pattern" : progress.completed ? "Next phrase" : "Try next phrase") {
                        guard canStartAction else { return }
                        cancelFlow(stopCapture: true)
                        onNextPhrase()
                    }.font(.caption.weight(.semibold)).foregroundStyle(Palette.forest)
                        .disabled(controlsLocked || restSeconds > 0)
                        .accessibilityIdentifier(isEcho ? "nextEchoPatternButton" : "nextMelodyPhraseButton")
                }
            }
        } else {
            PracticeProgressView(progress: store.progress(for: exercise, targetFrequency: targetFrequency),
                                 nextLesson: nextLesson, onNext: startLesson, disabled: restSeconds > 0)
        }
    }

    private func referenceRange(for context: MelodyPracticeContext) -> String {
        MelodyPiece(rawValue: context.pieceID)?.rangeLabel(for: context.register) ?? context.rangeLabel
    }

    private var targetControls: some View {
        HStack(spacing: 12) {
            if isEcho {
                Label("Recorded hum", systemImage: "waveform")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            } else {
                VStack(alignment: .leading, spacing: 3) {
                    Text(melodyContext == nil ? "TARGET" : "RECORDED HUM")
                        .font(.system(size: 10, weight: .semibold)).tracking(1.4)
                        .foregroundStyle(Palette.muted)
                    Text(melodyContext.map { "\($0.referenceKey) · \(referenceRange(for: $0))" }
                         ?? String(format: "%@ · %.1f Hz", targetNote, targetFrequency))
                        .font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("currentTargetLabel")
                        .accessibilityLabel(melodyContext.map { "Reference \($0.referenceKey), \(referenceRange(for: $0))" }
                                            ?? String(format: "Target %@ · %.1f Hz", targetNote, targetFrequency))
                }
            }
            Spacer(minLength: 0)
            Button { previewReference() } label: {
                Label(isEcho ? "Hear pattern" : melodyContext.map { $0.section == .whole ? "Hear melody" : "Hear phrase" }
                      ?? (section == .humming ? "Hear hum" : "Hear string"), systemImage: "speaker.wave.2")
                    .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                    .padding(.horizontal, 14)
                    .background(Palette.forest.opacity(0.06), in: Capsule())
            }.buttonStyle(.plain).foregroundStyle(Palette.forest)
                .disabled(controlsLocked || restSeconds > 0)
                .accessibilityIdentifier("previewTargetButton")
        }
    }

    private var recordingControls: some View {
        VStack(spacing: 10) {
            if restSeconds > 0 {
                Text("Rest your voice · \(restSeconds)s").font(.caption).foregroundStyle(Palette.muted)
            }
            if saving { ProgressView("Saving and rating…").font(.caption) }
            if let message = capture.message {
                Text(message).font(.footnote).foregroundStyle(Palette.muted)
                    .multilineTextAlignment(.center).accessibilityIdentifier("captureMessage")
                if permissionsDenied {
                    Button("Open Settings") {
                        if let url = URL(string: UIApplication.openSettingsURLString) { UIApplication.shared.open(url) }
                    }.font(.footnote).frame(minHeight: 44)
                }
            }
            Button(action: recordButtonTapped) {
                HStack(spacing: 10) {
                    if phase == .preparing || phase == .startingRecording {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: capture.isRecording ? "stop.fill" : (isBusy || capture.isPlayingReference) ? "xmark" : "record.circle")
                    }
                    Text(recordButtonTitle)
                    if capture.isRecording { Text(timeString(capture.elapsed)).monospacedDigit() }
                }.font(.headline).foregroundStyle(.white)
                    .frame(maxWidth: .infinity, minHeight: 56)
                    .background(capture.isRecording ? Color.red : Palette.forest,
                                in: RoundedRectangle(cornerRadius: 18))
                    .opacity(saving || restSeconds > 0 || needsEchoReference ? 0.55 : 1)
            }.buttonStyle(.plain)
                .disabled(saving || needsEchoReference || (restSeconds > 0 && !isBusy && !capture.isRecording))
                .accessibilityIdentifier("practiceRecordButton")
        }.padding(.horizontal, 22).padding(.top, 12).padding(.bottom, 12)
            .frame(maxWidth: .infinity)
            .background(Palette.paper)
    }

    private var echoCard: some View {
        VStack(spacing: 22) {
            HStack {
                Text(saving ? "REVIEWING" : capture.isRecording ? "RECORDING" : phase == .previewing ? "LISTEN" : isBusy ? "GET READY" : "READY")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.6)
                Spacer()
                Image(systemName: "ear").font(.subheadline)
            }.foregroundStyle(.white.opacity(0.65))
            if saving {
                ProgressView().tint(.white).frame(height: 62)
            } else {
                Text(countInSeconds > 0 ? "\(countInSeconds)" : phase == .previewing ? "Listen" : capture.isRecording ? "Hum it back" : "Your turn")
                    .font(.system(size: countInSeconds > 0 ? 62 : 36, weight: .light, design: .rounded))
                    .monospacedDigit().frame(minHeight: 62)
                    .accessibilityIdentifier("echoPracticeStatus")
            }
            Text(saving ? "Checking your notes, timing and clarity…"
                 : phase == .previewing ? "Remember the notes and their rhythm."
                 : capture.isRecording ? "Repeat the pattern you heard."
                 : isBusy ? "Start humming when the countdown ends."
                 : referenceWasHeard ? "Tap Record, then hum after 3–2–1."
                 : "Tap Hear pattern first.")
                .font(.subheadline).multilineTextAlignment(.center).foregroundStyle(.white.opacity(0.85))
            if capture.isRecording {
                ProgressView(value: min(capture.elapsed, recordingDuration), total: recordingDuration).tint(.white)
            }
        }.foregroundStyle(.white).padding(22).frame(maxWidth: .infinity, minHeight: 220)
            .background(Palette.forest, in: RoundedRectangle(cornerRadius: 26))
            .accessibilityElement(children: .contain).accessibilityIdentifier("echoPracticeCard")
    }

    private var tuner: some View {
        VStack(spacing: 16) {
            HStack {
                Text(saving ? "REVIEWING" : capture.isRecording ? "RECORDING"
                     : phase == .previewing ? "LISTEN" : isBusy ? "GET READY" : "LIVE TUNER")
                    .font(.system(size: 10, weight: .semibold)).tracking(1.6)
                Spacer()
                if capture.isRecording { Circle().fill(.red).frame(width: 7, height: 7) }
            }.foregroundStyle(.white.opacity(0.6))
            VStack(spacing: 7) {
                if saving {
                    ProgressView().tint(.white).frame(height: 56)
                } else {
                    Text(tunerTitle)
                        .font(.system(size: countInSeconds > 0 ? 62 : 46, weight: .light, design: .rounded))
                        .monospaced().contentTransition(.numericText()).frame(minHeight: 58)
                }
                Text(pitchMessage).font(.subheadline).multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85)).frame(minHeight: 22)
            }.padding(.vertical, 4)
            PitchMeter(cents: reading.cents ?? 0,
                       active: currentTarget != nil && reading.cents != nil && !isBusy && !saving, range: meterRange)
                .frame(height: 30).padding(.horizontal, 6)
            HStack {
                Text("Low")
                Spacer()
                Text(!isBusy && !saving ? reading.cents.map { String(format: "%+.0f cents", $0) } ?? "—" : "—")
                    .monospacedDigit()
                Spacer()
                Text("High")
            }.font(.caption).foregroundStyle(.white.opacity(0.6))
        }.foregroundStyle(.white).padding(22)
            .frame(maxWidth: .infinity)
            .background(Palette.forest, in: RoundedRectangle(cornerRadius: 26))
            .accessibilityElement(children: .contain)
    }

    private var camera: some View {
        CameraPreview(session: capture.session)
            .overlay(alignment: .bottomTrailing) {
                Button { capture.switchCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .frame(width: 44, height: 44).background(.black.opacity(0.5), in: Circle())
                        .foregroundStyle(.white)
                }.disabled(controlsLocked).accessibilityLabel("Switch camera").padding(12)
            }.frame(height: 225).clipShape(RoundedRectangle(cornerRadius: 22))
    }

    private var tunerTitle: String {
        if countInSeconds > 0 { return "\(countInSeconds)" }
        if phase == .previewing { return "Listen" }
        if phase == .preparing || phase == .startingRecording { return "Get ready" }
        if reading.frequency != nil { return reading.noteName }
        return capture.isRecording ? (section == .humming ? "Hum" : "Play") : "Ready"
    }
    private var targetNote: String { TunerReading(frequency: targetFrequency, targetFrequency: nil).noteName }
    private var currentTarget: Double? {
        guard let context = melodyContext else { return targetFrequency }
        guard let index = context.eventIndex(at: capture.isRecording ? capture.elapsed : 0) else { return nil }
        return context.frequency(for: context.expectedEvents[index])
    }
    private var reading: TunerReading { TunerReading(frequency: capture.frequency, targetFrequency: currentTarget) }
    private var meterRange: Double { exercise.usesComfortableTarget ? 200 : 50 }
    private var isGuidedHumming: Bool { melodyContext != nil || exercise == .steadyHum || exercise == .matchHum }
    private var recordingDuration: TimeInterval { melodyContext?.duration ?? 3 }
    private var isBusy: Bool { phase != .idle && phase != .recording }
    private var controlsLocked: Bool { isBusy || capture.isRecording || saving || capture.isPlayingReference }
    private var recordButtonTitle: String {
        if capture.isRecording { return "Stop" }
        if saving { return "Saving…" }
        if isBusy || capture.isPlayingReference { return "Cancel" }
        return saved ? "Record again" : "Record"
    }
    private var permissionsDenied: Bool {
        [AVMediaType.video, .audio].contains { mediaType in
            let status = AVCaptureDevice.authorizationStatus(for: mediaType)
            return status == .denied || status == .restricted
        }
    }
    private var pitchMessage: String {
        if saving { return "Checking your three goals…" }
        switch phase {
        case .preparing: return "Preparing camera & microphone…"
        case .previewing:
            if let context = melodyContext { return context.section == .whole ? "Listen to the melody" : "Listen to the phrase" }
            return section == .humming ? "Listen to the hum" : "Listen to the string note"
        case .counting: return isGuidedHumming ? "Get ready to hum" : "Get ready to play"
        case .startingRecording: return "Starting recording…"
        case .recording:
            if melodyContext != nil {
                return currentTarget.map { "Hum \(TunerReading(frequency: $0, targetFrequency: nil).noteName) · follow the phrase" } ?? "Rest"
            }
            guard reading.frequency != nil else { return isGuidedHumming ? "Hum one gentle note" : "Play one steady note" }
        case .idle:
            guard reading.frequency != nil else {
                return melodyContext.map { "3–2–1, then hum for \(Int($0.duration)) seconds" } ?? "Record starts with 3–2–1"
            }
        }
        guard let cents = reading.cents else { return "Listening…" }
        if abs(cents) <= 10 { return "Close to the target" }
        return cents < 0 ? "Below the target" : "Above the target"
    }

    private func recordButtonTapped() {
        if capture.isRecording { capture.stopRecording() }
        else if isBusy || capture.isPlayingReference { cancelFlow(stopCapture: true) }
        else { requestRecording() }
    }

    private var canStartAction: Bool {
        isVisible && phase == .idle && !capture.isRecording && !capture.isPlayingReference
            && !saving && restSeconds == 0
    }

    private func startLesson(_ lesson: PracticeLesson) {
        guard canStartAction else { return }
        cancelFlow(stopCapture: true)
        onStartLesson(lesson)
    }

    private func previewReference() {
        guard canStartAction else { return }
        flowToken = UUID()
        pendingRecord = false
        if isEcho { referenceWasHeard = false }
        phase = .previewing
        // Hearing a reference needs playback only, without camera or mic setup.
        if let context = melodyContext { capture.playMelodyReference(context) }
        else if section == .humming { capture.playHummingExample() }
        else { capture.playCelloReference(frequency: targetFrequency) }
    }

    private func requestRecording() {
        guard canStartAction, !isEcho || referenceWasHeard else { return }
        flowToken = UUID()
        saved = false
        latestSession = nil
        pendingRecord = true
        phase = .preparing
        if capture.isReady { dispatchPendingAction() }
        else { capture.start() }
    }

    private func dispatchPendingAction() {
        guard phase == .preparing, pendingRecord, capture.isReady,
              scenePhase == .active else { return }
        pendingRecord = false
        beginCountIn()
    }

    private func beginCountIn() {
        guard capture.isReady else { cancelFlow(stopCapture: false); return }
        guard scenePhase == .active else { cancelFlow(stopCapture: false); return }
        phase = .counting
        countInSeconds = 3
        let token = flowToken
        countInTask?.cancel()
        countInTask = Task { @MainActor in
            let deadline = ProcessInfo.processInfo.systemUptime + 3
            while !Task.isCancelled && token == flowToken {
                let remaining = deadline - ProcessInfo.processInfo.systemUptime
                if remaining <= 0 { break }
                countInSeconds = Int(ceil(remaining))
                do { try await Task.sleep(nanoseconds: 100_000_000) }
                catch { return }
            }
            guard !Task.isCancelled, token == flowToken, phase == .counting else { return }
            countInSeconds = 0
            guard scenePhase == .active, capture.isReady else {
                cancelFlow(stopCapture: false)
                return
            }
            timedRecording = isGuidedHumming
            stopRequested = false
            phase = .startingRecording
            startRecording()
        }
    }

    private func startRecording() {
        // Capture only the frozen lesson, store and individual state bindings.
        // Capturing the whole view would also retain the capture controller.
        // The weak controller avoids a cycle while a late finish still saves.
        capture.startRecording(maximumDuration: timedRecording ? recordingDuration : 90) {
            [weak capture = capture, store, exercise, targetFrequency, melodyContext,
                                  saving = $saving, saved = $saved,
                                  latestSession = $latestSession, isVisible = $isVisible] url, samples in
            saving.wrappedValue = true
            let fallbackDuration = capture?.elapsed ?? 0
            Task { @MainActor in
                let result = await store.saveRecording(from: url, samples: samples,
                    exercise: exercise, duration: fallbackDuration, targetFrequency: targetFrequency,
                    melodyContext: melodyContext)
                saving.wrappedValue = false
                saved.wrappedValue = result != nil
                if let result, isVisible.wrappedValue {
                    latestSession.wrappedValue = result
                }
            }
        }
    }

    private func beginRest() {
        restTask?.cancel()
        restSeconds = 3
        let token = flowToken
        restTask = Task { @MainActor in
            let deadline = ProcessInfo.processInfo.systemUptime + 3
            while !Task.isCancelled && token == flowToken {
                let remaining = deadline - ProcessInfo.processInfo.systemUptime
                restSeconds = max(0, Int(ceil(remaining)))
                if remaining <= 0 { return }
                do { try await Task.sleep(nanoseconds: 100_000_000) }
                catch { return }
            }
        }
    }

    private func cancelFlow(stopCapture: Bool) {
        flowToken = UUID()
        pendingRecord = false
        phase = .idle
        countInTask?.cancel()
        countInTask = nil
        countInSeconds = 0
        restTask?.cancel()
        restTask = nil
        restSeconds = 0
        timedRecording = false
        stopRequested = false
        if stopCapture { capture.stop() }
    }

}
