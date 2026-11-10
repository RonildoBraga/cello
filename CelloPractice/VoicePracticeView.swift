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

    private let mode: VoicePracticeMode
    private let nextLesson: PracticeLesson?
    private let onStartLesson: ((PracticeLesson) -> Void)?
    private let onShowLessons: (() -> Void)?
    private let onNextPhrase: (() -> Void)?
    private let header: (Bool) -> Header

    init(store: SessionStore, capture: CaptureController, mode: VoicePracticeMode,
         nextLesson: PracticeLesson? = nil, onStartLesson: ((PracticeLesson) -> Void)? = nil,
         onShowLessons: (() -> Void)? = nil, onNextPhrase: (() -> Void)? = nil,
         @ViewBuilder header: @escaping (Bool) -> Header) {
        self.store = store
        self.capture = capture
        self.mode = mode
        self.nextLesson = nextLesson
        self.onStartLesson = onStartLesson
        self.onShowLessons = onShowLessons
        self.onNextPhrase = onNextPhrase
        self.header = header
    }

    private var needsReference: Bool {
        mode.requiresHearFirst && !referenceWasHeard && phase == .idle && !capture.isRecording
    }
    /// The pitch meter is hidden while a mode keeps its target secret before the take.
    private var showsMeter: Bool { !mode.hidesTunerUntilRecording || capture.isRecording }

    var body: some View {
        recordingPracticeScreen
            .toolbar {
                if let onShowLessons {
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
                } else if mode.requiresHearFirst && phase == .previewing {
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
                    if mode.requiresHearFirst, capture.message == nil,
                       capture.referenceElapsed >= mode.duration - 0.05 {
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
                if isVisible && timedRecording && !stopRequested && elapsed >= mode.duration {
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
                    header(controlsLocked || (mode.requiresHearFirst && restSeconds > 0))
                    targetControls
                    if let session = latestSession, hasResult, showsIdleContent {
                        VStack(spacing: 16) {
                            if let rating = session.melodyRating, let context = session.melodyContext {
                                MelodyFeedbackView(rating: rating, isEcho: mode.isEcho)
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
                        if mode.offersTunerAfterResult {
                            DisclosureGroup("Live tuner") { statusCard.padding(.top, 10) }
                                .font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
                        }
                    } else {
                        statusCard
                        if showsIdleContent { lessonProgress }
                    }
                    if capture.isReady && mode.offersCameraPreview {
                        DisclosureGroup("Camera preview", isExpanded: $cameraExpanded) {
                            camera.padding(.top, 10)
                        }.font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
                    }
                    if let error = store.errorMessage {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }.screenContent()
            }
            .onChange(of: latestSession?.id) { _, id in
                withAnimation {
                    scroll.scrollTo(id == nil ? "practiceTop" : "latestRating", anchor: .top)
                }
            }
        }
        .bottomActionBar { recordingControls }
    }

    /// Results and progress give way to the status card while anything is in flight.
    private var showsIdleContent: Bool { !isBusy && !capture.isRecording && !saving }

    private var lessonProgress: some View {
        let progress = mode.progress(in: store)
        let onNextLesson: ((PracticeLesson) -> Void)? = onStartLesson == nil ? nil : { startLesson($0) }
        return HStack {
            PracticeProgressView(progress: progress, nextLesson: nextLesson, onNext: onNextLesson,
                                 disabled: restSeconds > 0)
            if let onNextPhrase, !mode.nextStepNeedsResult || hasResult {
                Button(mode.nextStepLabel(completed: progress.completed)) {
                    guard canStartAction else { return }
                    cancelFlow(stopCapture: true)
                    onNextPhrase()
                }.font(.caption.weight(.semibold)).foregroundStyle(Palette.forest)
                    .disabled(controlsLocked || restSeconds > 0)
                    .accessibilityIdentifier(mode.nextStepIdentifier)
            }
        }
    }

    private var targetControls: some View {
        HStack(spacing: 12) {
            if let caption = mode.referenceCaption {
                VStack(alignment: .leading, spacing: 3) {
                    Eyebrow(text: caption.eyebrow)
                    Text(caption.text).font(.subheadline.weight(.medium)).foregroundStyle(Palette.ink)
                        .accessibilityIdentifier("currentTargetLabel")
                        .accessibilityLabel(caption.spoken)
                }
            } else {
                Label("Recorded hum", systemImage: "waveform")
                    .font(.subheadline).foregroundStyle(Palette.muted)
            }
            Spacer(minLength: 0)
            Button { previewReference() } label: {
                Label(mode.hearLabel, systemImage: "speaker.wave.2")
            }.buttonStyle(SecondaryActionButtonStyle())
                .disabled(controlsLocked || restSeconds > 0)
                .accessibilityIdentifier("previewTargetButton")
        }
    }

    private var recordingControls: some View {
        Group {
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
                }
            }.buttonStyle(PrimaryActionButtonStyle(color: capture.isRecording ? .red : Palette.forest))
                .disabled(saving || needsReference || (restSeconds > 0 && !isBusy && !capture.isRecording))
                .accessibilityHint(needsReference ? "Tap Hear pattern and listen to the end first."
                                   : restSeconds > 0 ? "Available after a short rest." : "")
                .accessibilityIdentifier("practiceRecordButton")
        }
    }

    private var statusCard: some View {
        StatusCard(label: saving ? "REVIEWING" : capture.isRecording ? "RECORDING"
                   : phase == .previewing ? "LISTEN" : isBusy ? "GET READY" : mode.idleLabel) {
            if capture.isRecording { Circle().fill(.red).frame(width: 7, height: 7) }
            else if !showsMeter { Image(systemName: "ear") }
        } content: {
            VStack(spacing: 7) {
                if saving {
                    ProgressView().tint(.white).frame(height: 56)
                } else {
                    StatusValue(text: statusTitle, isCount: countInSeconds > 0)
                        .contentTransition(.numericText()).frame(minHeight: 58)
                        .accessibilityIdentifier(showsMeter ? "livePitchNote" : "echoPracticeStatus")
                }
                Text(statusMessage).font(.subheadline).multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85)).frame(minHeight: 22)
                    .accessibilityIdentifier("livePitchFeedback")
            }.padding(.vertical, 4)
            if showsMeter {
                PitchMeter(cents: reading.cents ?? 0,
                           active: currentTarget != nil && reading.cents != nil && !isBusy && !saving,
                           range: mode.meterRange)
                    .frame(height: 30).padding(.horizontal, 6)
                HStack {
                    Text("Low")
                    Spacer()
                    Text(!isBusy && !saving ? reading.cents.map { String(format: "%+.0f cents", $0) } ?? "—" : "—")
                        .monospacedDigit()
                        .accessibilityIdentifier("livePitchCents")
                    Spacer()
                    Text("High")
                }.font(.caption).foregroundStyle(.white.opacity(0.7))
            }
        }.accessibilityElement(children: .contain)
            .accessibilityIdentifier(showsMeter ? mode.tunerIdentifier : "echoPracticeCard")
    }

    private var camera: some View {
        CameraPreview(session: capture.session)
            .overlay(alignment: .bottomTrailing) {
                Button { capture.switchCamera() } label: {
                    Image(systemName: "arrow.triangle.2.circlepath.camera")
                        .frame(width: 44, height: 44).background(.black.opacity(0.5), in: Circle())
                        .foregroundStyle(.white)
                }.disabled(controlsLocked).accessibilityLabel("Switch camera").padding(12)
            }.frame(height: 225).clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius))
    }

    private var statusTitle: String {
        if countInSeconds > 0 { return "\(countInSeconds)" }
        if phase == .previewing { return "Listen" }
        guard showsMeter else { return mode.idleTitle }
        if phase == .preparing || phase == .startingRecording { return "Get ready" }
        if reading.frequency != nil { return reading.noteName }
        return capture.isRecording ? mode.recordingTitle : mode.idleTitle
    }
    private var currentTarget: Double? { mode.target(at: capture.isRecording ? capture.elapsed : 0) }
    private var reading: TunerReading { TunerReading(frequency: capture.frequency, targetFrequency: currentTarget) }
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
    private var statusMessage: String {
        if saving { return mode.reviewingMessage }
        switch phase {
        case .preparing: return mode.preparingMessage
        case .previewing: return mode.listenMessage
        case .counting: return mode.countInMessage
        case .startingRecording: return mode.startingMessage
        case .recording:
            if let message = mode.recordingMessage(target: currentTarget, reading: reading) { return message }
        case .idle:
            if !showsMeter || reading.frequency == nil { return mode.idleMessage(referenceHeard: referenceWasHeard) }
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
        onStartLesson?(lesson)
    }

    private func previewReference() {
        guard canStartAction else { return }
        flowToken = UUID()
        pendingRecord = false
        if mode.requiresHearFirst { referenceWasHeard = false }
        phase = .previewing
        mode.playReference(on: capture)
    }

    private func requestRecording() {
        guard canStartAction, !mode.requiresHearFirst || referenceWasHeard else { return }
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
        let token = flowToken
        countInTask?.cancel()
        countInTask = Task { @MainActor in
            guard await countDown(to: $countInSeconds, token: token), phase == .counting else { return }
            guard scenePhase == .active, capture.isReady else {
                cancelFlow(stopCapture: false)
                return
            }
            timedRecording = mode.isTimed
            stopRequested = false
            phase = .startingRecording
            startRecording()
        }
    }

    /// Counts three seconds down on the monotonic clock. False when cancelled or superseded.
    private func countDown(to seconds: Binding<Int>, token: UUID) async -> Bool {
        seconds.wrappedValue = 3
        let deadline = ProcessInfo.processInfo.systemUptime + 3
        while !Task.isCancelled && token == flowToken {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            if remaining <= 0 {
                seconds.wrappedValue = 0
                return true
            }
            seconds.wrappedValue = Int(ceil(remaining))
            do { try await Task.sleep(nanoseconds: 100_000_000) }
            catch { return false }
        }
        return false
    }

    private func startRecording() {
        // Capture only the frozen lesson, store and individual state bindings.
        // Capturing the whole view would also retain the capture controller.
        // The weak controller avoids a cycle while a late finish still saves.
        capture.startRecording(maximumDuration: timedRecording ? mode.duration : 90) {
            [weak capture = capture, store, exercise = mode.exercise, targetFrequency = mode.targetFrequency,
             melodyContext = mode.melodyContext, saving = $saving, saved = $saved,
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
        let token = flowToken
        restTask = Task { @MainActor in _ = await countDown(to: $restSeconds, token: token) }
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
