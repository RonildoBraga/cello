import SwiftUI

/// Practising one foundation lesson: a recorded note or a tapping round.
@MainActor
struct FoundationPracticeView: View {
    let lesson: PracticeLesson
    @ObservedObject var store: SessionStore
    let capture: CaptureController
    let rhythmStores: RhythmStores
    @Environment(\.practiceMethod) private var method
    /// The open string on show when the lesson is practised on the cello.
    @State private var string = PracticeMethod.openStrings[0]
    /// A chip was tapped to switch string: the string it shows plays once.
    @State private var hearOnArrival = false

    private var onCello: Bool { lesson.isRecorded && method.wrappedValue == .cello }

    var body: some View {
        Group {
            switch lesson.activity {
            case .recording(let exercise):
                noteLesson(onCello ? string : exercise)
            case .rhythm(let exercise):
                PulsePracticeView(store: rhythmStores.store(for: exercise)) { header }
            }
        }.background(Palette.paper).screenTitle(screenTitle, methodSwitch: lesson.isRecorded ? capture : nil)
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
                Group {
                    if onCello {
                        PartStrip(parts: strings, selection: $string, short: { String($0.targetNote?.dropLast() ?? "") },
                                  title: \.title, progress: progress, hear: controls.hearing)
                    } else {
                        let note = NoteName.frequency(mode.targetFrequency)
                        PartStrip<String>(parts: [note], selection: .constant(note), short: { $0 }, title: { $0 },
                                          hear: controls.hearing)
                    }
                }.disabled(controls.locked)
            }
        }.id(exercise)
    }

    private var header: some View {
        LessonHeader(subtitle: lesson.practicePrompt(onCello ? .cello : .voice),
                   titleIdentifier: "practiceLessonTitle", eyebrowIdentifier: "practiceLessonArea")
            .id("practiceTop")
    }
}
