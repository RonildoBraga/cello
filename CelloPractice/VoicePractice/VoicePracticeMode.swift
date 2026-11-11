import Foundation

/// What a voice-practice screen records: one fixed note, a piece phrase, or an
/// echo pattern. The screen asks the mode for everything that differs between
/// them, so its recording flow reads the same for all three.
enum VoicePracticeMode: Equatable {
    case note(Exercise)
    case phrase(MelodyPracticeContext)
    case echo(MelodyPracticeContext, level: EchoLevel)

    /// A melody context is an echo pattern when it matches the echo catalogue.
    init(context: MelodyPracticeContext) {
        if let echo = EchoLevel.selection(for: context) {
            self = .echo(context, level: echo.level)
        } else {
            self = .phrase(context)
        }
    }

    // MARK: What is recorded

    /// Saved with the take. Melody takes are stored as free recordings plus their context.
    var exercise: Exercise {
        if case .note(let exercise) = self { return exercise }
        return .listen
    }

    var melodyContext: MelodyPracticeContext? {
        switch self {
        case .note: return nil
        case .phrase(let context), .echo(let context, _): return context
        }
    }

    private var section: PracticeSection { exercise.section ?? .humming }

    var targetFrequency: Double {
        if let context = melodyContext {
            return context.expectedEvents.compactMap { context.frequency(for: $0) }.first ?? context.tuningA4Hz
        }
        return section.effectiveTarget(for: exercise)
    }

    /// The target sounding at a moment in the take; nil during a melody's silence.
    func target(at elapsed: TimeInterval) -> Double? {
        guard let context = melodyContext else { return targetFrequency }
        guard let index = context.eventIndex(at: elapsed) else { return nil }
        return context.frequency(for: context.expectedEvents[index])
    }

    /// Humming takes stop by themselves; cello takes run until Stop.
    var isTimed: Bool { melodyContext != nil || exercise == .steadyHum || exercise == .matchHum }
    var duration: TimeInterval { melodyContext?.duration ?? 3 }
    var meterRange: Double { exercise.usesComfortableTarget ? 200 : 50 }

    // MARK: The lane

    /// Seconds per count-in beat: the melody's own beat, or one second.
    var beatInterval: TimeInterval { melodyContext.map { 60 / Double($0.tempoBPM) } ?? 1 }

    /// The notes to hum as bars on the lane; empty for a take with no set length.
    /// Echo keeps its bars level and unnamed, so the count-in gives nothing away.
    var laneMarks: [LaneMark] {
        guard let context = melodyContext else {
            guard isTimed else { return [] }
            return [LaneMark(start: 0, length: duration,
                             label: TunerReading(frequency: targetFrequency, targetFrequency: nil).noteName)]
        }
        let notes = context.expectedEvents.compactMap(\.midiNote)
        let low = notes.min() ?? 0
        let span = max(1, (notes.max() ?? 0) - low)
        let names = context.noteNames
        var pitched = 0
        return context.expectedEvents.compactMap { event in
            guard let note = event.midiNote else { return nil }
            defer { pitched += 1 }
            // The reference leaves the last eighth of each note silent; the bar shows that pause.
            return LaneMark(start: event.onsetBeat * beatInterval, length: event.durationBeats * beatInterval * 0.88,
                            label: isEcho ? nil : names[pitched],
                            level: isEcho || notes.min() == notes.max() ? 0.5 : Double(note - low) / Double(span))
        }
    }

    // MARK: How the screen behaves

    var isEcho: Bool {
        if case .echo = self { return true }
        return false
    }

    /// Echo unlocks Record only after its pattern has been heard to the end.
    var requiresHearFirst: Bool { isEcho }
    /// Echo shows no pitch until the take starts, so the pattern is not given away.
    var hidesTunerUntilRecording: Bool { isEcho }
    var offersTunerAfterResult: Bool { !isEcho }
    /// Video helps review posture and bowing; a hummed note needs only the microphone.
    var recordsVideo: Bool {
        if case .note(let exercise) = self { return exercise.section == .cello }
        return false
    }
    /// Echo offers a new pattern only once the current one has a result.
    var nextPartNeedsResult: Bool { isEcho }

    @MainActor
    func progress(in store: SessionStore) -> PracticeProgress {
        switch self {
        case .note(let exercise): return store.progress(for: exercise, targetFrequency: targetFrequency)
        case .phrase(let context): return store.melodyProgress(for: context)
        case .echo(let context, let level): return store.echoProgress(for: level, register: context.register)
        }
    }

    @MainActor
    func playReference(on capture: CaptureController) {
        // Hearing a reference needs playback only, without camera or microphone setup.
        if let context = melodyContext { capture.playMelodyReference(context) }
        else if section == .humming { capture.playHummingExample() }
        else { capture.playCelloReference(frequency: targetFrequency) }
    }

    // MARK: Wording

    /// The reference line beside the Hear button; echo names no notes.
    var referenceCaption: (eyebrow: String, text: String, spoken: String)? {
        switch self {
        case .note:
            let note = TunerReading(frequency: targetFrequency, targetFrequency: nil).noteName
            let text = String(format: "%@ · %.1f Hz", note, targetFrequency)
            return ("Target", text, "Target \(text)")
        case .phrase(let context) where context.noteDrillPiece != nil:
            let notes = context.noteNames.joined(separator: " then ")
            return ("Recorded hum", notes, "Reference \(notes)")
        case .phrase(let context):
            let range = MelodyPiece(rawValue: context.pieceID)?.rangeLabel(for: context.register) ?? context.rangeLabel
            return ("Recorded hum", "\(context.referenceKey) · \(range)", "Reference \(context.referenceKey), \(range)")
        case .echo: return nil
        }
    }

    var hearLabel: String {
        switch self {
        case .note: return section == .humming ? "Hear hum" : "Hear string"
        case .phrase(let context) where context.noteDrillPiece != nil:
            return context.expectedEvents.count == 1 ? "Hear note" : "Hear notes"
        case .phrase(let context): return context.section == .whole ? "Hear melody" : "Hear phrase"
        case .echo: return "Hear pattern"
        }
    }

    var nextPartIdentifier: String { isEcho ? "nextEchoPatternButton" : "nextMelodyPhraseButton" }

    var idleLabel: String { isEcho ? "READY" : "LIVE TUNER" }
    var idleTitle: String { isEcho ? "Your turn" : "Ready" }
    /// Shown while recording before any pitch is heard.
    var recordingTitle: String { section == .humming ? "Hum" : "Play" }

    func idleMessage(referenceHeard: Bool) -> String {
        switch self {
        case .note: return "Record counts 1–2–3–4 first"
        case .phrase(let context): return "1–2–3–4, then hum for \(Int(context.duration)) seconds"
        case .echo: return referenceHeard ? "Tap Record, then hum after 1–2–3–4." : "Tap Hear pattern first."
        }
    }

    var listenMessage: String {
        switch self {
        case .note: return section == .humming ? "Listen to the hum" : "Listen to the string note"
        case .phrase(let context) where context.noteDrillPiece != nil:
            return context.expectedEvents.count == 1 ? "Listen to the note" : "Listen to the two notes"
        case .phrase(let context): return context.section == .whole ? "Listen to the melody" : "Listen to the phrase"
        case .echo: return "Remember the notes and their rhythm."
        }
    }

    private var echoCountdownMessage: String { "Start humming when the countdown ends." }
    var preparingMessage: String {
        isEcho ? echoCountdownMessage : recordsVideo ? "Preparing camera & microphone…" : "Preparing microphone…"
    }
    var countInMessage: String {
        isEcho ? echoCountdownMessage : isTimed ? "Get ready to hum" : "Get ready to play"
    }
    var startingMessage: String { isEcho ? echoCountdownMessage : "Starting recording…" }
    var reviewingMessage: String {
        isEcho ? "Checking your notes, timing and clarity…" : "Checking your three goals…"
    }

    /// Guidance during a take. Nil means the generic above/below-target wording applies.
    func recordingMessage(target: Double?, reading: TunerReading) -> String? {
        let note = target.map { TunerReading(frequency: $0, targetFrequency: nil).noteName }
        switch self {
        case .note:
            return reading.frequency == nil ? (isTimed ? "Hum one gentle note" : "Play one steady note") : nil
        case .phrase(let context):
            let hint = context.noteDrillPiece == nil ? " · follow the phrase" : ""
            return note.map { "Hum \($0)\(hint)" } ?? "Rest"
        case .echo:
            guard let note else { return "Pattern finished" }
            guard let cents = reading.cents else { return "Hum \(note) · aim for the centre" }
            if abs(cents) <= 10 { return "Close to \(note)" }
            return cents < 0 ? "Below \(note) · hum higher" : "Above \(note) · hum lower"
        }
    }

    /// Identifiers stay stable for the UI tests.
    var tunerIdentifier: String { isEcho ? "echoLiveTuner" : "liveTuner" }
}
