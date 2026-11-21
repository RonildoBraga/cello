import AVFoundation
import Combine
import Foundation
import QuartzCore
import UIKit
import CelloPitch

/// A pitch observation, measured in seconds from the start of a practice take.
struct PitchSample: Codable, Sendable {
    let time: Double
    let frequency: Double
    let confidence: Double
    let rms: Double
}

/// One audio engine feeds both the saved take and the live tuner. It hears the
/// microphone only: no camera API is used, so none is ever asked for. Engine changes
/// stay off the main thread.
final class CaptureController: NSObject, ObservableObject, @unchecked Sendable {
    private let engine = AVAudioEngine()

    @Published private(set) var isReady = false
    @Published private(set) var isRecording = false
    /// Includes the short quiet tail after playback, while pitch analysis is paused.
    @Published private(set) var isPlayingReference = false
    /// The note being heard. Sound that does not stand clear of the room is not one.
    @Published private(set) var frequency: Double?
    /// The room's own sound, once the microphone has listened for a moment. It is published
    /// when the room turns noisy or quiet, not with every measurement.
    @Published private(set) var room: RoomNoise?
    @Published private(set) var message: String?
    @Published private(set) var elapsed: TimeInterval = 0
    /// Actual player position, independent of the recording timer.
    @Published private(set) var referenceElapsed: TimeInterval = 0

    private let sessionQueue = DispatchQueue(label: "cello.capture.session")
    private let audioQueue = DispatchQueue(label: "cello.capture.audio", qos: .userInitiated)
    private let analysisQueue = DispatchQueue(label: "cello.capture.pitch", qos: .userInitiated)
    private let detector = PitchDetector()

    // Accessed only on sessionQueue.
    private var wantsToRun = false
    private var recordingRequested = false
    private var observerTokens: [NSObjectProtocol] = []
    private var referenceToken: UUID?
    private var referenceCooldown: DispatchWorkItem?
    private var referenceUsesCapture = false
    private var referenceCancelled = false

    // Accessed only on audioQueue.
    private var audioWindow: [Float] = []
    private var audioSampleRate: Double = 0
    private var lastAnalysisTime: Double = 0
    private var analyzing = false
    private var generation = 0
    private var recordingStartHostTime: Double?
    private var pitchSamples: [PitchSample] = []
    private var reportedUnsupportedAudio = false
    private var analysisSuppressed = false
    private var listener = RoomListener()
    /// The take being written: an audio-only QuickTime movie, timed by the frames it holds.
    private var take: Take?

    // Accessed only on the main thread.
    private var displayTimer: Timer?
    private var displayStartTime: Double?
    private var referencePlayer: AVAudioPlayer?
    private var referencePlayerToken: UUID?
    private var referenceTimer: Timer?

    override init() {
        super.init()
        observeCaptureLifecycle()
    }

    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
        displayTimer?.invalidate()
        referenceTimer?.invalidate()
        referenceCooldown?.cancel()
    }

    /// The microphone permission is requested only after a learner starts an action.
    func start() {
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.referenceToken == nil else {
                self.publish { self.message = "Wait for the target note to finish, then try again." }
                return
            }
            self.wantsToRun = true
            self.requestCaptureStart()
        }
    }

    private func requestCaptureStart() {
        Task { [weak self] in
            guard let self else { return }
            guard await Self.requestMicrophonePermission() else {
                self.publish {
                    self.isReady = false
                    self.message = "Allow Microphone in Settings → Cello, then tap Record again."
                }
                return
            }
            self.sessionQueue.async { [weak self] in
                guard let self, self.wantsToRun else { return }
                do {
                    if !self.engine.isRunning { try self.startEngine() }
                    let running = self.engine.isRunning
                    self.publish {
                        self.isReady = running
                        self.message = running ? nil
                            : "The microphone could not start. Close any other recording app and try again."
                    }
                } catch {
                    self.publish {
                        self.isReady = false
                        self.message = error.localizedDescription
                    }
                }
            }
        }
    }

    /// The practice screen now on show. Choosing another part replaces the screen, and
    /// the old one disappears after the new one has started to play: only the screen
    /// still on show may stop the sound.
    private var owner: UUID?
    func claim(_ screen: UUID) { owner = screen }
    func release(_ screen: UUID) { if owner == screen { stop() } }

    /// Waits for the screen being left to stop its sound, so the next one can play.
    func waitUntilQuiet() async {
        try? await Task.sleep(for: .milliseconds(250))
        for _ in 0..<30 where isPlayingReference { try? await Task.sleep(for: .milliseconds(50)) }
    }

    /// Finishes an active take before releasing the microphone.
    func stop() {
        publish {
            self.isReady = false
            self.frequency = nil
            // Invalidate the pending main-thread playback request immediately.
            // Session cleanup below waits for all player I/O to stop as well.
            self.referencePlayer?.delegate = nil
            self.referencePlayer?.stop()
            self.referencePlayer = nil
            self.referencePlayerToken = nil
            self.referenceTimer?.invalidate()
            self.referenceTimer = nil
            self.referenceElapsed = 0
        }
        sessionQueue.async { [weak self] in
            guard let self else { return }
            self.wantsToRun = false
            if self.recordingRequested {
                self.audioQueue.async { self.finishTake() }
            } else {
                self.stopSession()
            }
        }
    }

    /// The completion belongs to this take, even if its lesson screen disappears.
    /// Called on main; failed saves deliberately retain the original pending file.
    /// It also receives the room as it was heard just before the take.
    func startRecording(maximumDuration: TimeInterval = 90,
                        onFinished: @escaping (URL, [PitchSample], RoomNoise?) -> Void) {
        sessionQueue.async { [weak self] in
            guard let self, !self.recordingRequested else { return }
            guard maximumDuration.isFinite, maximumDuration > 0, maximumDuration <= 90 else {
                self.publish { self.message = "This recording length is unavailable. Choose another exercise." }
                return
            }
            guard self.engine.isRunning, self.wantsToRun else {
                self.publish { self.message = "Recording isn’t ready. Tap Record to try again." }
                return
            }
            guard self.referenceToken == nil else {
                self.publish { self.message = "Wait for the reference note to finish, then try recording again." }
                return
            }
            do {
                let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("PendingTakes", isDirectory: true)
                try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                let url = directory.appendingPathComponent(UUID().uuidString).appendingPathExtension("mov")
                let writer = try AVAssetWriter(outputURL: url, fileType: .mov)
                let input = AVAssetWriterInput(mediaType: .audio, outputSettings: [
                    AVFormatIDKey: kAudioFormatMPEG4AAC, AVSampleRateKey: RecordingAudio.sampleRate,
                    AVNumberOfChannelsKey: 1, AVEncoderBitRateKey: 128_000
                ])
                input.expectsMediaDataInRealTime = true
                guard writer.canAdd(input) else { throw CaptureError.unsupportedConfiguration }
                writer.add(input)
                guard writer.startWriting() else { throw writer.error ?? CaptureError.unsupportedConfiguration }
                writer.startSession(atSourceTime: .zero)
                self.recordingRequested = true
                self.publish {
                    self.elapsed = 0
                    self.message = nil
                }
                self.audioQueue.async {
                    self.generation += 1
                    self.audioWindow.removeAll(keepingCapacity: true)
                    self.pitchSamples.removeAll(keepingCapacity: true)
                    self.lastAnalysisTime = 0
                    self.take = Take(url: url, writer: writer, input: input, maximumDuration: maximumDuration,
                                     completion: onFinished)
                    self.recordingStartHostTime = Self.hostTime
                    self.takeStarted()
                }
            } catch {
                self.publish { self.message = "Could not create a recording: \(error.localizedDescription)" }
            }
        }
    }

    func stopRecording() {
        sessionQueue.async { [weak self] in
            guard let self, self.recordingRequested else { return }
            self.audioQueue.async { self.finishTake() }
        }
    }

    /// Listen first, then hum. Playback is never analysed or saved as the learner's pitch.
    func playCelloReference(frequency: Double) {
        playReference(frequency: frequency, source: .recordedCello)
    }

    func playHummingExample() {
        playReference(frequency: HummingExample.frequency, source: .humanHum)
    }

    /// Uses the same output route and capture suppression as the foundation references.
    func playMelodyReference(_ context: MelodyPracticeContext) {
        guard context.isValid else {
            publish { self.message = "This melody reference is unavailable. Try another phrase." }
            return
        }
        let frequency = context.expectedEvents.compactMap { $0.frequency(tuningA4Hz: context.tuningA4Hz) }.first
            ?? context.tuningA4Hz
        playReference(frequency: frequency, source: .melody(context))
    }

    private enum ReferenceSource: Sendable {
        case recordedCello, humanHum
        case melody(MelodyPracticeContext)
    }

    private func playReference(frequency: Double, source: ReferenceSource) {
        publish {
            guard !self.isPlayingReference, !self.isRecording else {
                self.message = "Wait for the current recording or target note to finish, then try again."
                return
            }
            let token = UUID()
            self.referencePlayerToken = token
            self.referenceElapsed = 0
            self.isPlayingReference = true
            self.message = nil
            self.frequency = nil
            self.sessionQueue.async { [self] in
                self.prepareReference(frequency: frequency, source: source, token: token)
            }
        }
    }

    // Called only on sessionQueue. A preview does not need microphone permission.
    private func prepareReference(frequency: Double, source: ReferenceSource, token: UUID) {
        guard !recordingRequested, referenceToken == nil else {
            publish {
                guard self.referencePlayerToken == token else { return }
                self.referencePlayerToken = nil
                self.isPlayingReference = false
                self.message = "Wait for the current recording or target note to finish, then try again."
            }
            return
        }
        referenceToken = token
        referenceUsesCapture = engine.isRunning && wantsToRun
        referenceCancelled = false
        audioQueue.sync {
            analysisSuppressed = true
            generation += 1
            audioWindow.removeAll(keepingCapacity: true)
            lastAnalysisTime = 0
        }
        do {
            let data: Data
            switch source {
            case .recordedCello: data = try RecordedReference.celloNote(frequency: frequency)
            case .humanHum: data = try HummingExample.wavData()
            case .melody(let context): data = try RecordedReference.wavData(context: context)
            }
            let audioSession = AVAudioSession.sharedInstance()
            if referenceUsesCapture {
                // Measurement mode deliberately lowers speaker playback level.
                // Keep capture available, but use normal output processing while listening.
                try audioSession.setMode(.default)
            } else {
                try audioSession.setCategory(.playback, mode: .default, options: [])
            }
            try audioSession.setActive(true)
            // Player creation and delegates stay on the main run loop. stop()
            // invalidates this token before queued work can start stale playback.
            publish {
                guard self.referenceRequestIsCurrent(token) else { return }
                do {
                    let player = try AVAudioPlayer(data: data)
                    self.referencePlayer = player
                    player.delegate = self
                    let started = player.prepareToPlay() && player.play()
                    if started { self.startReferenceTimer(token: token) }
                    if !started {
                        self.referencePlaybackEnded(token: token,
                            message: "The reference note could not play. Try again.")
                    }
                } catch {
                    self.referencePlaybackEnded(token: token,
                        message: "The reference note could not play: \(error.localizedDescription)")
                }
            }
        } catch {
            publish {
                guard self.referenceRequestIsCurrent(token) else { return }
                self.referencePlaybackEnded(token: token,
                    message: "The reference note could not play: \(error.localizedDescription)")
            }
        }
    }

    // Player position follows the audio clock, so delayed UI ticks never accumulate drift.
    private func startReferenceTimer(token: UUID) {
        referenceTimer?.invalidate()
        let timer = Timer(timeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self, self.referencePlayerToken == token,
                  let player = self.referencePlayer else { return }
            self.referenceElapsed = player.currentTime
        }
        referenceTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    // Called on main. A cancellation can arrive before queued preparation starts.
    private func referenceRequestIsCurrent(_ token: UUID) -> Bool {
        guard referencePlayerToken == token else {
            sessionQueue.async { [weak self] in
                guard let self, self.referenceToken == token else { return }
                self.wantsToRun = false
                self.stopSession()
            }
            return false
        }
        return true
    }

    // Called on the main thread by playback/delegate paths.
    private func referencePlaybackEnded(token: UUID, message: String? = nil) {
        guard referencePlayerToken == token else { return }
        referenceTimer?.invalidate()
        referenceTimer = nil
        if let referencePlayer {
            referenceElapsed = message == nil ? referencePlayer.duration : referencePlayer.currentTime
        }
        referencePlayer?.delegate = nil
        referencePlayer?.stop()
        referencePlayer = nil
        referencePlayerToken = nil
        sessionQueue.async { [weak self] in
            guard let self, self.referenceToken == token, !self.referenceCancelled else { return }
            let cooldown = DispatchWorkItem { [weak self] in
                guard let self, self.referenceToken == token, !self.referenceCancelled else { return }
                self.referenceCooldown = nil
                do {
                    let audioSession = AVAudioSession.sharedInstance()
                    if self.referenceUsesCapture {
                        try audioSession.setMode(.measurement)
                    } else {
                        try audioSession.setActive(false, options: .notifyOthersOnDeactivation)
                    }
                    self.finishReferenceCleanup(message: message)
                } catch {
                    self.wantsToRun = false
                    self.finishStoppingSession()
                    self.finishReferenceCleanup(message: "Audio could not resume: \(error.localizedDescription). Please try again.")
                }
            }
            self.referenceCooldown = cooldown
            // Discard the room/speaker tail, then build a fresh microphone window.
            self.sessionQueue.asyncAfter(deadline: .now() + 0.3, execute: cooldown)
        }
    }

    // Called only after playback has stopped and the session profile is settled.
    private func finishReferenceCleanup(message: String? = nil) {
        referenceToken = nil
        referenceCooldown?.cancel()
        referenceCooldown = nil
        referenceUsesCapture = false
        referenceCancelled = false
        audioQueue.sync {
            generation += 1
            analysisSuppressed = false
            audioWindow.removeAll(keepingCapacity: true)
            lastAnalysisTime = 0
        }
        publish {
            self.referenceTimer?.invalidate()
            self.referenceTimer = nil
            if let message { self.message = message }
            self.isPlayingReference = false
            self.frequency = nil
        }
    }

    /// The engine hears the microphone only. Measurement mode is used instead of voice
    /// processing, which can alter a sustained musical note. No speaker monitoring.
    /// While a reference plays, the audio session is left as playback set it.
    private func startEngine(configuringSession: Bool = true) throws {
        if configuringSession { try activateAudioSession() }
        let input = engine.inputNode
        let format = input.outputFormat(forBus: 0)
        guard format.channelCount > 0, format.sampleRate > 0 else {
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw CaptureError.unavailableMicrophone
        }
        input.removeTap(onBus: 0)
        input.installTap(onBus: 0, bufferSize: 4_096, format: format) { [weak self] buffer, _ in
            // The engine reuses its buffer once this returns, so the audio queue gets a copy.
            guard let self, let copy = Self.copy(buffer) else { return }
            self.audioQueue.async { self.hear(copy) }
        }
        engine.prepare()
        do {
            try engine.start()
        } catch {
            input.removeTap(onBus: 0)
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
            throw error
        }
    }

    private func activateAudioSession() throws {
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.playAndRecord, mode: .measurement, options: [.defaultToSpeaker])
        try audioSession.setPreferredSampleRate(48_000)
        try audioSession.setActive(true)
    }

    private func stopSession() {
        guard let token = referenceToken else {
            finishStoppingSession()
            return
        }
        referenceCancelled = true
        referenceCooldown?.cancel()
        referenceCooldown = nil
        // Stop the player on its run loop before deactivating the audio session.
        // Keep the reference token/Published flag until this continuation settles.
        publish {
            self.referencePlayer?.delegate = nil
            self.referencePlayer?.stop()
            self.referencePlayer = nil
            self.referencePlayerToken = nil
            self.referenceTimer?.invalidate()
            self.referenceTimer = nil
            self.referenceElapsed = 0
            self.sessionQueue.async { [self] in
                guard self.referenceToken == token, self.referenceCancelled else { return }
                self.finishStoppingSession()
                self.finishReferenceCleanup()
            }
        }
    }

    private func finishStoppingSession() {
        engine.inputNode.removeTap(onBus: 0)
        if engine.isRunning { engine.stop() }
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        // Publish after the serial session queue has actually stopped. A Start
        // already in flight may have enqueued a ready update after stop()'s
        // immediate UI update; this final update restores the settled state.
        publish {
            self.isReady = false
            self.frequency = nil
            self.room = nil
        }
        audioQueue.async { [weak self] in
            guard let self else { return }
            self.generation += 1
            self.analysisSuppressed = false
            self.audioWindow.removeAll(keepingCapacity: true)
            self.recordingStartHostTime = nil
            self.pitchSamples.removeAll(keepingCapacity: true)
            // The next time the microphone is on, the room may be a different one.
            self.listener = RoomListener()
        }
    }

    private func observeCaptureLifecycle() {
        let center = NotificationCenter.default
        observerTokens.append(center.addObserver(forName: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance(), queue: nil) { [weak self] note in
            guard let self,
                  let rawType = note.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                  AVAudioSession.InterruptionType(rawValue: rawType) == .began else { return }
            // AVAudioPlayer does not send its finish delegate after interruption.
            // Stop explicitly so a reference note cannot leave analysis paused.
            self.publish {
                self.message = "Audio was interrupted. Any active take will finish; tap Hear target or Record to try again."
            }
            self.stop()
        })
        // A new route or format stops the engine. Between takes it starts again on the new
        // microphone; a take in progress finishes with what it has.
        observerTokens.append(center.addObserver(forName: .AVAudioEngineConfigurationChange, object: engine, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.sessionQueue.async {
                guard self.wantsToRun, !self.engine.isRunning else { return }
                if self.recordingRequested {
                    self.publish { self.message = "The microphone changed. Your take has finished; tap Record when you are ready." }
                    self.stop()
                    return
                }
                do { try self.startEngine(configuringSession: self.referenceToken == nil) } catch {
                    self.publish { self.message = "The microphone changed and could not restart. Tap Record to try again." }
                    self.stop()
                }
            }
        })
        observerTokens.append(center.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: nil) { [weak self] _ in
            guard let self else { return }
            self.publish { self.message = "Practice paused while the app was away. Tap Record to continue." }
            self.stop()
        })
    }

    private static func requestMicrophonePermission() async -> Bool {
        switch AVAudioApplication.shared.recordPermission {
        case .granted: return true
        case .undetermined: return await AVAudioApplication.requestRecordPermission()
        default: return false
        }
    }

    private static var hostTime: Double { CMClockGetTime(CMClockGetHostTimeClock()).seconds }

    private func publish(_ changes: @escaping () -> Void) {
        if Thread.isMainThread { changes() } else { DispatchQueue.main.async(execute: changes) }
    }

    private enum CaptureError: LocalizedError {
        case unavailableMicrophone
        case unsupportedConfiguration
        var errorDescription: String? {
            switch self {
            case .unavailableMicrophone: return "The microphone is unavailable. Use your iPhone to try live practice."
            case .unsupportedConfiguration: return "This device could not set up recording. Please restart the app and try again."
            }
        }
    }
}

// Everything below runs on audioQueue.
extension CaptureController {
    private struct Take {
        let url: URL
        let writer: AVAssetWriter
        let input: AVAssetWriterInput
        let maximumDuration: TimeInterval
        let completion: (URL, [PitchSample], RoomNoise?) -> Void
        /// Frames written so far, at the microphone's own rate: the take's clock.
        var frames: Int64 = 0
        var sampleRate: Double = 0
        var seconds: Double { sampleRate > 0 ? Double(frames) / sampleRate : 0 }
    }

    private func hear(_ pcm: AVAudioPCMBuffer) {
        // A take starts at the first sound after Record, so preparation is never saved.
        let takeTime = take?.seconds
        if take != nil { write(pcm) }
        guard !analysisSuppressed, let mono = Self.monoSamples(from: pcm) else {
            if !analysisSuppressed, !reportedUnsupportedAudio {
                reportedUnsupportedAudio = true
                publish { self.message = "The microphone audio format could not be analysed. Recording is still available." }
            }
            return
        }
        let format = pcm.format
        if audioSampleRate != format.sampleRate {
            audioSampleRate = format.sampleRate
            audioWindow.removeAll(keepingCapacity: true)
        }
        audioWindow.append(contentsOf: mono)
        if audioWindow.count > 8_192 { audioWindow.removeFirst(audioWindow.count - 8_192) }
        let now = Self.hostTime
        guard audioWindow.count == 8_192, !analyzing, now - lastAnalysisTime >= 0.1 else { return }
        analyzing = true
        lastAnalysisTime = now
        let samples = audioWindow
        let sampleRate = audioSampleRate
        let currentGeneration = generation
        let start = recordingStartHostTime
        let capturedTime = takeTime
        analysisQueue.async { [weak self] in
            guard let self else { return }
            let estimate = self.detector.estimate(samples: samples, sampleRate: sampleRate)
            let level = Measure.level(of: samples)
            self.audioQueue.async { [weak self] in
                guard let self else { return }
                self.analyzing = false
                guard self.generation == currentGeneration else { return }
                // The saved take keeps every observation: scoring is not changed by the room.
                if let capturedTime, capturedTime <= 90.5, let estimate {
                    self.pitchSamples.append(PitchSample(time: capturedTime, frequency: estimate.frequency,
                                                        confidence: estimate.confidence, rms: estimate.rms))
                }
                // The room is heard only outside a take, so the learner is not measured as noise.
                let roomChanged = start == nil && self.listener.hear(level)
                let room = self.listener.room
                let heard = estimate.flatMap { room?.isClear($0.rms) ?? true ? $0.frequency : nil }
                self.publish {
                    self.frequency = heard
                    if roomChanged { self.room = room }
                }
            }
        }
    }

    /// Appends the microphone's sound to the take, timed by the frames already written.
    private func write(_ pcm: AVAudioPCMBuffer) {
        guard var current = take else { return }
        let rate = pcm.format.sampleRate
        if current.sampleRate == 0 { current.sampleRate = rate }
        let remaining = Int64((current.maximumDuration * current.sampleRate).rounded()) - current.frames
        let count = min(Int64(pcm.frameLength), max(0, remaining))
        guard rate == current.sampleRate, count > 0 else {
            take = current
            finishTake()
            return
        }
        pcm.frameLength = AVAudioFrameCount(count)
        if current.input.isReadyForMoreMediaData,
           let buffer = Self.sampleBuffer(pcm, at: CMTime(value: current.frames, timescale: CMTimeScale(rate))),
           current.input.append(buffer) {
            current.frames += count
        } else {
            // A gap would join two moments of a note together; end the take instead.
            take = current
            finishTake()
            return
        }
        take = current
        if current.frames >= Int64((current.maximumDuration * rate).rounded()) { finishTake() }
    }

    // Called on audioQueue once the writer has begun.
    private func takeStarted() {
        // Serial ordering keeps a countdown pitch publication from arriving
        // after the new take's clear and appearing as a recorded reading.
        publish {
            self.frequency = nil
            self.isRecording = true
            self.displayTimer?.invalidate()
            self.displayStartTime = CACurrentMediaTime()
            let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
                guard let self, let start = self.displayStartTime else { return }
                self.elapsed = min(90, CACurrentMediaTime() - start)
            }
            self.displayTimer = timer
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    /// Closes the file and hands it, with its pitch observations and the room heard just
    /// before it, to the take's owner. A take with no sound keeps its partial file.
    private func finishTake() {
        guard let finished = take else { return }
        take = nil
        generation += 1
        recordingStartHostTime = nil
        let observations = pitchSamples
        pitchSamples.removeAll(keepingCapacity: true)
        // The room is not measured during a take, so this is the room just before it.
        let room = listener.room
        finished.input.markAsFinished()
        finished.writer.finishWriting { [weak self] in
            guard let self else { return }
            let error = finished.writer.error
            let saved = finished.writer.status == .completed && finished.frames > 0
            self.publish {
                self.displayTimer?.invalidate()
                self.displayTimer = nil
                self.displayStartTime = nil
                self.isRecording = false
                if saved {
                    finished.completion(finished.url, observations, room)
                } else {
                    self.message = "Recording could not finish: \(error?.localizedDescription ?? "nothing was captured"). Any partial file has been kept on this device."
                }
            }
            self.sessionQueue.async {
                self.recordingRequested = false
                if !self.wantsToRun { self.stopSession() }
            }
        }
    }

    private static func copy(_ buffer: AVAudioPCMBuffer) -> AVAudioPCMBuffer? {
        guard let copy = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else { return nil }
        copy.frameLength = buffer.frameLength
        let source = UnsafeMutableAudioBufferListPointer(UnsafeMutablePointer(mutating: buffer.audioBufferList))
        let destination = UnsafeMutableAudioBufferListPointer(copy.mutableAudioBufferList)
        for (from, to) in zip(source, destination) {
            guard let fromData = from.mData, let toData = to.mData else { return nil }
            memcpy(toData, fromData, Int(min(from.mDataByteSize, to.mDataByteSize)))
        }
        return copy
    }

    private static func sampleBuffer(_ pcm: AVAudioPCMBuffer, at time: CMTime) -> CMSampleBuffer? {
        var timing = CMSampleTimingInfo(duration: CMTime(value: 1, timescale: time.timescale),
                                        presentationTimeStamp: time, decodeTimeStamp: .invalid)
        var buffer: CMSampleBuffer?
        guard CMSampleBufferCreate(allocator: kCFAllocatorDefault, dataBuffer: nil, dataReady: false,
                                   makeDataReadyCallback: nil, refcon: nil,
                                   formatDescription: pcm.format.formatDescription,
                                   sampleCount: CMItemCount(pcm.frameLength), sampleTimingEntryCount: 1,
                                   sampleTimingArray: &timing, sampleSizeEntryCount: 0, sampleSizeArray: nil,
                                   sampleBufferOut: &buffer) == noErr, let buffer,
              CMSampleBufferSetDataBufferFromAudioBufferList(buffer, blockBufferAllocator: kCFAllocatorDefault,
                                                             blockBufferMemoryAllocator: kCFAllocatorDefault,
                                                             flags: 0, bufferList: pcm.audioBufferList) == noErr
        else { return nil }
        return buffer
    }

    private static func monoSamples(from pcm: AVAudioPCMBuffer) -> [Float]? {
        let frames = Int(pcm.frameLength)
        let channels = Int(pcm.format.channelCount)
        guard frames > 0, channels > 0 else { return nil }
        let interleaved = pcm.format.isInterleaved
        var mono = [Float](repeating: 0, count: frames)
        for channel in 0..<channels {
            for frame in 0..<frames {
                let index = interleaved ? frame * channels + channel : frame
                let pointerIndex = interleaved ? 0 : channel
                let value: Float
                if let data = pcm.floatChannelData { value = data[pointerIndex][index] }
                else if let data = pcm.int16ChannelData { value = Float(data[pointerIndex][index]) / 32_768 }
                else if let data = pcm.int32ChannelData { value = Float(data[pointerIndex][index]) / 2_147_483_648 }
                else { return nil }
                mono[frame] += value / Float(channels)
            }
        }
        return mono
    }
}

extension CaptureController: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard player === referencePlayer, let token = referencePlayerToken else { return }
        referencePlaybackEnded(token: token, message: flag ? nil : "The reference note was interrupted. Try again.")
    }

    func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
        guard player === referencePlayer, let token = referencePlayerToken else { return }
        referencePlaybackEnded(token: token, message: "The reference note could not play: \(error?.localizedDescription ?? "audio decoding failed")")
    }
}
