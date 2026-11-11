import SwiftUI

/// Practising one foundation lesson: a recorded note or a tapping round.
@MainActor
struct FoundationPracticeView: View {
    let lesson: PracticeLesson
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    let rhythmStores: RhythmStores
    @State private var method: PracticeMethod
    /// The open string on show when the lesson is practised on the cello.
    @State private var string: Exercise
    /// A chip was tapped to switch string: the string it shows plays once.
    @State private var hearOnArrival = false

    /// The lesson opens the way it was last practised: by voice, or on the string last played.
    init(lesson: PracticeLesson, store: SessionStore, capture: CaptureController, rhythmStores: RhythmStores) {
        self.lesson = lesson
        self.store = store
        self.capture = capture
        self.rhythmStores = rhythmStores
        let strings = PracticeMethod.openStrings
        let last = store.sessions.first { $0.exercise == .steadyHum || strings.contains($0.exercise) }?.exercise
        let lastString = last.flatMap { strings.contains($0) ? $0 : nil }
        _method = State(initialValue: lastString == nil ? .voice : .cello)
        _string = State(initialValue: lastString ?? strings[0])
    }

    private var onCello: Bool { lesson.hasCelloSide && method == .cello }

    var body: some View {
        Group {
            switch lesson.activity {
            case .recording(let exercise):
                noteLesson(onCello ? string : exercise)
            case .rhythm(let exercise):
                PulsePracticeView(store: rhythmStores.store(for: exercise)) { header }
            }
        }.background(Palette.paper).screenTitle(screenTitle)
            .toolbar {
                // On the cello, the instrument's parts and strings are one tap away.
                if onCello {
                    ToolbarItem(placement: .topBarTrailing) {
                        NavigationLink(value: MusicRoute.celloIntroduction) {
                            Image(systemName: "info.circle").frame(width: 44, height: 44)
                        }.accessibilityLabel("Meet your cello").accessibilityIdentifier("celloIntroductionLink")
                    }
                }
            }
    }

    /// What the screen is called on the back stack: the kind of practice on show.
    private var screenTitle: String {
        if case .rhythm = lesson.activity { return "Rhythm" }
        return onCello ? "Cello" : "Humming"
    }

    private func progress(_ exercise: Exercise) -> PracticeProgress {
        store.progress(for: exercise, targetFrequency: VoicePracticeMode.note(exercise).targetFrequency)
    }

    /// One note to hum, or the four open strings to play: each a chip, tapped to hear it.
    private func noteLesson(_ exercise: Exercise) -> some View {
        let mode = VoicePracticeMode.note(exercise)
        let strings = PracticeMethod.openStrings
        let parts = onCello ? LessonParts(strings, current: exercise, noun: "String", title: { $0.targetNote ?? "" },
                                          passed: progress(exercise).passed) { string = $0 } : nil
        return VoicePracticeView(store: store, capture: capture, mode: mode, parts: parts,
                                 hearOnArrival: $hearOnArrival) { controls in
            VStack(alignment: .leading, spacing: 17) {
                header
                let hearing = PartHearing(spoken: mode.hearSpoken, identifier: "previewTargetButton") { changed in
                    if changed { hearOnArrival = true } else { controls.hear() }
                }
                // What to hear on the left; how it is practised, a different kind of choice, on the right.
                HStack(spacing: 8) {
                    if onCello {
                        PartStrip(parts: strings, selection: $string, short: { String($0.targetNote?.dropLast() ?? "") },
                                  title: \.title, progress: progress, hear: hearing)
                    } else {
                        let note = TunerReading(frequency: mode.targetFrequency, targetFrequency: nil).noteName
                        PartStrip<String>(parts: [note], selection: .constant(note), short: { $0 }, title: { $0 },
                                          hear: hearing)
                    }
                    if lesson.hasCelloSide { methodPicker }
                }.disabled(controls.locked)
            }
        }.id(exercise)
    }

    /// Voice or cello, each marked once passed (✓) or gold (★).
    private var methodPicker: some View {
        Picker("Practise with", selection: Binding(get: { method }, set: { next in
            // The cello is filmed and the voice is not: release the microphone between them.
            if next != method { capture.stop() }
            method = next
        })) {
            ForEach(PracticeMethod.allCases) { method in
                let parts = method == .cello ? PracticeMethod.openStrings.map(progress) : [progress(.steadyHum)]
                let mark = parts.allSatisfy(\.completed) ? " ★" : parts.allSatisfy(\.passed) ? " ✓" : ""
                Text(method.title + mark).tag(method)
            }
        }.pickerStyle(.segmented).frame(width: 136).accessibilityIdentifier("practiceMethodPicker")
    }

    private var header: some View {
        LessonHeader(subtitle: lesson.practicePrompt(onCello ? .cello : .voice),
                   titleIdentifier: "practiceLessonTitle", eyebrowIdentifier: "practiceLessonArea")
            .id("practiceTop")
    }
}
