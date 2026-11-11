import SwiftUI
import AVFoundation
import UIKit

/// Recording lifecycle stays scoped to one frozen lesson/reference. SessionStore
/// owns the durable result after this screen disappears.
/// What a lesson's header needs from the practice screen: whether to hold its
/// controls still, and how its chips play. The chip on show plays again; a tap
/// on another switches to it, and the part it shows plays once it arrives.
struct PracticeHeaderControls {
    let locked: Bool
    let hearing: PartHearing
}

@MainActor
struct VoicePracticeView<Header: View>: View {
    private enum Phase: Equatable {
        case idle, preparing, previewing, counting, startingRecording, recording
    }

    @ObservedObject var store: SessionStore
    @ObservedObject private var capture: CaptureController
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.practiceMethod) private var method
    @State private var isVisible = false
    @State private var screen = UUID()
    @State private var phase: Phase = .idle
    @State private var pendingRecord = false
    @State private var flowToken = UUID()
    @State private var cameraExpanded = false
    /// Count-in beats still to come; shown counting up as 1 2 3 4.
    @State private var countInSeconds = 0
    /// The moment, on the system uptime clock, when the lane's time is zero:
    /// the end of the count-in, then the true start of the recording.
    @State private var laneZero: TimeInterval?
    @State private var countInTask: Task<Void, Never>?
    @State private var restSeconds = 0
    @State private var restTask: Task<Void, Never>?
    @State private var timedRecording = false
    @State private var stopRequested = false
    @State private var saving = false
    @State private var saved = false
    @State private var referenceWasHeard = false
    @State private var latestSession: PracticeSession?
    /// The note the idle tuner listens for; nil is the take's first note.
    @State private var tunerTarget: Double?
    private var hasResult: Bool { latestSession?.rating != nil || latestSession?.melodyRating != nil }

    private let mode: VoicePracticeMode
    /// The take's notes as bars on the lane. Worked out once: the lane is redrawn on every frame.
    private let laneMarks: [LaneMark]
    /// Where this take sits among the lesson's phrases or notes, if it has several.
    private let parts: LessonParts?
    /// Set by a chip that has just switched to this take: play it once on arrival.
    @Binding private var hearOnArrival: Bool
    private let header: (PracticeHeaderControls) -> Header

    init(store: SessionStore, capture: CaptureController, mode: VoicePracticeMode,
         parts: LessonParts? = nil, hearOnArrival: Binding<Bool> = .constant(false),
         @ViewBuilder header: @escaping (PracticeHeaderControls) -> Header) {
        self.store = store
        self.capture = capture
        self.mode = mode
        laneMarks = mode.laneMarks
        self.parts = parts
        _hearOnArrival = hearOnArrival
        self.header = header
    }

    private var needsReference: Bool {
        mode.requiresHearFirst && !referenceWasHeard && phase == .idle && !capture.isRecording
    }
    /// Echo shows no pitch until the take starts, so the pattern is not given away.
    private var showsMeter: Bool { !mode.isEcho || capture.isRecording }

    var body: some View {
        recordingPracticeScreen
            .toolbar {
                // On the cello, the instrument's parts and strings are one tap away.
                if method.wrappedValue == .cello {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: MusicRoute.celloIntroduction) {
                            Image(systemName: "info.circle").frame(width: 44, height: 44)
                        }.accessibilityLabel("Meet your cello").accessibilityIdentifier("celloIntroductionLink")
                    }
                }
                if capture.isReady {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { cancelFlow(stopCapture: true) } label: {
                            Image(systemName: "power").frame(width: 44, height: 44)
                        }.disabled(capture.isRecording || saving)
                            .accessibilityLabel(mode.recordsVideo ? "Turn off camera and microphone" : "Turn off microphone")
                    }
                }
            }
            .onAppear { isVisible = true; capture.claim(screen) }
            .task {
                guard hearOnArrival else { return }
                hearOnArrival = false
                await capture.waitUntilQuiet()
                previewReference()
            }
            .onDisappear {
                isVisible = false
                referenceWasHeard = false
                cancelFlow(stopCapture: false)
                capture.release(screen)
            }
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
                if recording {
                    phase = .recording
                    laneZero = ProcessInfo.processInfo.systemUptime - capture.elapsed
                }
                else if phase == .recording || phase == .startingRecording {
                    let needsRest = timedRecording && isVisible
                    phase = .idle
                    laneZero = nil
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
                    header(PracticeHeaderControls(locked: controlsLocked || restSeconds > 0, hearing: PartHearing(
                        spoken: mode.hearSpoken, identifier: "previewTargetButton") { changed in
                            if changed { hearOnArrival = true } else { previewReference() }
                        }))
                    if let session = latestSession, hasResult, showsIdleContent {
                        VStack(spacing: 16) {
                            if let rating = session.melodyRating {
                                MelodyFeedbackView(rating: rating, isEcho: mode.isEcho)
                            } else if let rating = session.rating {
                                PracticeRatingView(rating: rating)
                                    .accessibilityIdentifier("latestRatingCard")
                            }
                            // The chart of the take and the tuner share a card: look, then try again live.
                            VStack(alignment: .leading, spacing: 14) {
                                if let rating = session.melodyRating, let context = session.melodyContext {
                                    MelodyTraceView(context: context, rating: rating, duration: session.duration)
                                } else if let target = session.effectiveTargetFrequency {
                                    PitchTraceView(samples: session.pitchSamples, targetFrequency: target, duration: session.duration)
                                }
                                if !mode.isEcho {
                                    Divider()
                                    liveTuner
                                }
                            }.card()
                            lessonProgress
                        }.id("latestRating")
                    } else {
                        statusCard.id("statusCard")
                        if showsIdleContent { lessonProgress }
                    }
                    if capture.isReady && mode.recordsVideo {
                        DisclosureGroup("Camera preview", isExpanded: $cameraExpanded) {
                            camera.padding(.top, 10)
                        }.font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
                    }
                    if let error = store.lastSaveError {
                        Text(error).font(.footnote).foregroundStyle(.red)
                    }
                }.screenContent()
            }
            // Bring the lane, the note and the tuning bar into view together for the take.
            .onChange(of: laneZero != nil) { _, showsLane in
                if showsLane { withAnimation { scroll.scrollTo("statusCard", anchor: .top) } }
            }
            .onChange(of: latestSession?.id) { _, id in
                withAnimation {
                    scroll.scrollTo(id == nil ? "practiceTop" : "latestRating", anchor: .top)
                }
            }
        }
        .bottomActionBar(lessonsLocked: controlsLocked || restSeconds > 0, parts: parts) { recordingControls }
    }

    /// Results and progress give way to the status card while anything is in flight.
    private var showsIdleContent: Bool { !isBusy && !capture.isRecording && !saving }

    private var lessonProgress: some View {
        PracticeProgressView(progress: mode.progress(in: store))
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
                .accessibilityHint(needsReference ? "Tap the pattern and listen to the end first."
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
            if let laneZero, !saving, !laneMarks.isEmpty {
                // The notes travel to the line through the count-in and the take. Between
                // the count-in ending and the recorder starting, the first note waits at the line.
                TimelineView(.animation) { _ in
                    let elapsed = ProcessInfo.processInfo.systemUptime - laneZero
                    BeatLane(elapsed: capture.isRecording ? elapsed : min(0, elapsed), beatInterval: mode.beatInterval,
                             duration: mode.duration, marks: laneMarks)
                }.frame(height: 66)
            }
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

    /// After a take the tuner sits under its chart, so a correction can be tried at once.
    private var liveTuner: some View {
        VStack(spacing: 10) {
            HStack {
                Text("Live tuner").font(.subheadline.weight(.semibold)).foregroundStyle(Palette.ink)
                Spacer()
                if capture.isReady {
                    Text(reading.cents.map { "\(reading.noteName) · " + String(format: "%+.0f cents", $0) }
                         ?? "\(method.wrappedValue.verb.capitalized) \(TunerReading(frequency: currentTarget, targetFrequency: nil).noteName)")
                        .font(.subheadline).monospacedDigit().foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("livePitchCents")
                } else {
                    Button("Turn on") { capture.start(includingCamera: mode.recordsVideo) }
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.forest)
                        .accessibilityLabel("Turn on live tuner")
                }
            }.frame(minHeight: 30)
            PitchMeter(cents: reading.cents ?? 0, active: reading.cents != nil, range: mode.meterRange, onCard: true)
                .frame(height: 30).padding(.horizontal, 6)
            // With several notes in the take, the learner picks which one the tuner listens for.
            if mode.tunerTargets.count > 1 {
                HStack(spacing: 8) {
                    Text("Tune to").font(.caption).foregroundStyle(Palette.muted)
                    ForEach(mode.tunerTargets, id: \.self) { target in
                        let name = TunerReading(frequency: target, targetFrequency: nil).noteName
                        let selected = target == currentTarget
                        Button(name) { tunerTarget = target }
                            .font(.subheadline.weight(.semibold)).foregroundStyle(selected ? .white : Palette.forest)
                            .padding(.horizontal, 13).frame(minWidth: 44, minHeight: 44)
                            .background(Palette.forest.opacity(selected ? 1 : 0.07), in: Capsule())
                            .buttonStyle(.plain)
                            .accessibilityLabel("Tune to \(name)")
                            .accessibilityAddTraits(selected ? .isSelected : [])
                            .accessibilityIdentifier("tunerTarget-\(name)")
                    }
                }
            }
        }.accessibilityElement(children: .contain).accessibilityIdentifier(mode.tunerIdentifier)
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
        if countInSeconds > 0 { return "\(Self.countInBeats + 1 - countInSeconds)" }
        if phase == .previewing { return "Listen" }
        guard showsMeter else { return mode.idleTitle }
        if phase == .preparing || phase == .startingRecording { return "Get ready" }
        if reading.frequency != nil { return reading.noteName }
        return capture.isRecording ? mode.recordingTitle : mode.idleTitle
    }
    private var currentTarget: Double? {
        capture.isRecording ? mode.target(at: capture.elapsed) : tunerTarget ?? mode.target(at: 0)
    }
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
        let needed: [AVMediaType] = mode.recordsVideo ? [.video, .audio] : [.audio]
        return needed.contains { mediaType in
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
        else { capture.start(includingCamera: mode.recordsVideo) }
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
            laneZero = ProcessInfo.processInfo.systemUptime + Double(Self.countInBeats) * mode.beatInterval
            guard await countDown(to: $countInSeconds, beats: Self.countInBeats, beatInterval: mode.beatInterval,
                                  token: token), phase == .counting else { return }
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

    /// Like tapping, a take counts in four beats at its own tempo: 1 2 3 4.
    private static var countInBeats: Int { 4 }

    /// Counts beats down on the monotonic clock. False when cancelled or superseded.
    private func countDown(to beats: Binding<Int>, beats total: Int = 3, beatInterval: TimeInterval = 1,
                           token: UUID) async -> Bool {
        beats.wrappedValue = total
        let deadline = ProcessInfo.processInfo.systemUptime + Double(total) * beatInterval
        while !Task.isCancelled && token == flowToken {
            let remaining = deadline - ProcessInfo.processInfo.systemUptime
            if remaining <= 0 {
                beats.wrappedValue = 0
                return true
            }
            beats.wrappedValue = Int(ceil(remaining / beatInterval))
            do { try await Task.sleep(nanoseconds: 50_000_000) }
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
        laneZero = nil
        restTask?.cancel()
        restTask = nil
        restSeconds = 0
        timedRecording = false
        stopRequested = false
        if stopCapture { capture.stop() }
    }
}
