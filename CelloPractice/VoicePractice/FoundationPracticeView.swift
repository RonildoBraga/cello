import SwiftUI

/// Practising one foundation lesson: a recorded note or a tapping round.
@MainActor
struct FoundationPracticeView: View {
    let lesson: PracticeLesson
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    let rhythmStores: RhythmStores

    var body: some View {
        Group {
            switch lesson.activity {
            case .recording(let exercise):
                noteLesson(exercise)
            case .rhythm(let exercise):
                PulsePracticeView(store: rhythmStores.store(for: exercise)) { header }
            }
        }.background(Palette.paper).screenTitle(lesson.area.title)
    }

    /// One note to hum: one chip, tapped to hear it.
    private func noteLesson(_ exercise: Exercise) -> some View {
        let mode = VoicePracticeMode.note(exercise)
        return VoicePracticeView(store: store, capture: capture, mode: mode) { controls in
            noteHeader(mode, controls)
        }
    }

    private func noteHeader(_ mode: VoicePracticeMode,
                            _ controls: PracticeHeaderControls) -> some View {
        let note = TunerReading(frequency: mode.targetFrequency, targetFrequency: nil).noteName
        let hearing = PartHearing(spoken: mode.hearSpoken, identifier: "previewTargetButton") { _ in controls.hear() }
        return VStack(alignment: .leading, spacing: 17) {
            header
            PartStrip<String>(parts: [note], selection: .constant(note), short: { $0 }, title: { $0 }, hear: hearing)
                .disabled(controls.locked)
        }
    }

    private var header: some View {
        LessonHeader(subtitle: lesson.practicePrompt,
                   titleIdentifier: "practiceLessonTitle", eyebrowIdentifier: "practiceLessonArea")
            .id("practiceTop")
    }
}
