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
                VoicePracticeView(store: store, capture: capture, mode: .note(exercise)) { locked in
                    header.disabled(locked)
                }
            case .rhythm(let exercise):
                PulsePracticeView(store: rhythmStores.store(for: exercise)) { header }
            }
        }.background(Palette.paper).screenTitle(lesson.area.title)
    }

    private var header: some View {
        StepHeader(step: .lesson(lesson), subtitle: lesson.practicePrompt,
                   titleIdentifier: "practiceLessonTitle", eyebrowIdentifier: "practiceLessonArea")
            .id("practiceTop")
    }
}
