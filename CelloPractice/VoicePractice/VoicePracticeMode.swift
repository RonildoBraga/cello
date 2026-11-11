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

    /// Voice or cello, read from what is recorded.
    private var method: PracticeMethod { PracticeMethod(exercise: exercise, melody: melodyContext) }

    var targetFrequency: Double {
        if let context = melodyContext {
            return context.expectedEvents.compactMap { context.frequency(for: $0) }.first ?? context.tuningA4Hz
        }
        // An open string is its own target; a hummed note matches the human example.
        return exercise.targetFrequency ?? HummingExample.frequency
    }

    /// The target sounding at a moment in the take; nil during a melody's silence.
    func target(at elapsed: TimeInterval) -> Double? {
        guard let context = melodyContext else { return targetFrequency }
        guard let index = context.eventIndex(at: elapsed) else { return nil }
        return context.frequency(for: context.expectedEvents[index])
    }

    /// The take's different notes in the order they first sound, when it has more than one.
    /// Echo offers none: its tuner stays hidden so the notes are not given away.
    var tunerTargets: [Double] {
        guard !isEcho, let context = melodyContext else { return [] }
        var targets: [Double] = []
        for target in context.expectedEvents.compactMap({ context.frequency(for: $0) })
        where !targets.contains(target) { targets.append(target) }
        return targets.count > 1 ? targets : []
    }

    /// Humming takes stop by themselves; cello takes run until Stop.
    var isTimed: Bool { melodyContext != nil || exercise == .steadyHum || exercise == .matchHum }
    var duration: TimeInterval { melodyContext?.duration ?? 3 }
    /// A voice finding its note needs a wider meter than a string being tuned.
    var meterRange: Double { exercise.targetFrequency == nil ? 200 : 50 }

    // MARK: The lane

    /// Seconds per count-in beat: the melody's own beat, or one second.
    var beatInterval: TimeInterval { melodyContext.map { 60 / Double($0.tempoBPM) } ?? 1 }

    /// The notes to hum as bars on the lane; empty for a take with no set length.
    /// Echo keeps its bars level and unnamed, so the count-in gives nothing away.
    var laneMarks: [LaneMark] {
        guard let context = melodyContext else {
            guard isTimed else { return [] }
            return [LaneMark(start: 0, length: duration,
                             label: NoteName.frequency(targetFrequency))]
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
    /// Video helps review posture and bowing; a hummed note needs only the microphone.
    var recordsVideo: Bool { method == .cello }

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
        else if method == .voice { capture.playHummingExample() }
        else { capture.playCelloReference(frequency: targetFrequency) }
    }

    // MARK: Wording

    /// What is being heard, for the chip that plays it; echo names no notes.
    var referenceSpoken: String? {
        switch self {
        case .note:
            let note = NoteName.frequency(targetFrequency)
            return String(format: "Target %@ · %.1f Hz", note, targetFrequency)
        case .phrase(let context) where context.noteDrillPiece != nil:
            if let repeated = context.repeatedNote { return "Reference \(repeated.name), \(repeated.count) quick notes" }
            return "Reference \(context.noteNames.joined(separator: " then "))"
        case .phrase(let context):
            let range = MelodyPiece(rawValue: context.pieceID)?.rangeLabel(for: context.register) ?? context.rangeLabel
            return "Reference \(context.referenceKey), \(range)"
        case .echo: return nil
        }
    }

    /// What the chip on show says when spoken: how to hear it and what it is.
    var hearSpoken: String { [hearLabel, referenceSpoken].compactMap { $0 }.joined(separator: ", ") }

    var hearLabel: String {
        switch self {
        case .note: return method == .voice ? "Hear hum" : "Hear string"
        case .phrase(let context) where context.noteDrillPiece != nil:
            return context.expectedEvents.count == 1 ? "Hear note" : "Hear notes"
        case .phrase(let context): return context.section == .whole ? "Hear melody" : "Hear phrase"
        case .echo: return "Hear pattern"
        }
    }

    var idleLabel: String { isEcho ? "READY" : "LIVE TUNER" }
    var idleTitle: String { isEcho ? "Your turn" : "Ready" }
    /// Shown while recording before any pitch is heard.
    var recordingTitle: String { method.verb.capitalized }

    func idleMessage(referenceHeard: Bool) -> String {
        switch self {
        case .note: return "Record counts 1–2–3–4 first"
        case .phrase(let context): return "1–2–3–4, then \(method.verb) for \(Int(context.duration)) seconds"
        case .echo: return referenceHeard ? "Tap Record, then \(method.verb) after 1–2–3–4." : "Tap the pattern above to hear it first."
        }
    }

    var listenMessage: String {
        switch self {
        case .note: return method == .voice ? "Listen to the hum" : "Listen to the string note"
        case .phrase(let context) where context.noteDrillPiece != nil:
            if context.repeatedNote != nil { return "Listen to the quick notes" }
            return context.expectedEvents.count == 1 ? "Listen to the note" : "Listen to the two notes"
        case .phrase(let context): return context.section == .whole ? "Listen to the melody" : "Listen to the phrase"
        case .echo: return "Remember the notes and their rhythm."
        }
    }

    /// Shown with a take that repeats a note quickly. A closed-lip hum has nothing
    /// to restart a note with, and gaps between the notes cost their timing and clarity.
    var quickNotesHint: String? {
        guard !isEcho, melodyContext?.repeatsQuickNotes == true else { return nil }
        return method == .voice
            ? "Quick notes: sing “doo-doo-doo-doo” instead of humming, and keep each note going until the next one starts."
            : "Quick notes: play each one separately, and let it sound until the next one starts."
    }

    private var echoCountdownMessage: String { "Start \(method == .cello ? "playing" : "humming") when the countdown ends." }
    var preparingMessage: String {
        isEcho ? echoCountdownMessage : recordsVideo ? "Preparing camera & microphone…" : "Preparing microphone…"
    }
    var countInMessage: String {
        isEcho ? echoCountdownMessage : "Get ready to \(method.verb)"
    }
    var startingMessage: String { isEcho ? echoCountdownMessage : "Starting recording…" }
    var reviewingMessage: String {
        isEcho ? "Checking your notes, timing and clarity…" : "Checking your three goals…"
    }

    /// Guidance during a take. Nil means the generic above/below-target wording applies.
    func recordingMessage(target: Double?, reading: TunerReading) -> String? {
        let note = target.map(NoteName.frequency)
        switch self {
        case .note:
            return reading.frequency == nil ? (isTimed ? "Hum one gentle note" : "Play one steady note") : nil
        case .phrase(let context):
            let hint = context.noteDrillPiece == nil ? " · follow the phrase" : ""
            return note.map { "\(method.verb.capitalized) \($0)\(hint)" } ?? "Rest"
        case .echo:
            guard let note else { return "Pattern finished" }
            guard let cents = reading.cents else { return "\(method.verb.capitalized) \(note) · aim for the centre" }
            if abs(cents) <= 10 { return "Close to \(note)" }
            return cents < 0 ? "Below \(note) · \(method.verb) higher" : "Above \(note) · \(method.verb) lower"
        }
    }

    /// Identifiers stay stable for the UI tests.
    var tunerIdentifier: String { isEcho ? "echoLiveTuner" : "liveTuner" }
}
