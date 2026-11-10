import SwiftUI

/// Practising one foundation lesson: a recorded note or a tapping round.
@MainActor
struct FoundationPracticeView: View {
    let lesson: PracticeLesson
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    let rhythmStores: RhythmStores
    /// Moves on to another lesson, such as the suggested next one.
    let onStartLesson: (PracticeLesson) -> Void

    var body: some View {
        Group {
            switch lesson.activity {
            case .recording(let exercise):
                VoicePracticeView(store: store, capture: capture, mode: .note(exercise),
                                  nextLesson: lesson.next, onStartLesson: onStartLesson) { _ in header }
            case .rhythm(let exercise):
                PulsePracticeView(store: rhythmStores.store(for: exercise),
                                  nextLesson: lesson.next, onNext: onStartLesson) { header }
            }
        }.background(Palette.paper).screenTitle(lesson.area.title)
    }

    private var header: some View {
        ScreenHeader(eyebrow: lesson.area.title, title: lesson.title, subtitle: lesson.practicePrompt,
                     titleIdentifier: "practiceLessonTitle", eyebrowIdentifier: "practiceLessonArea")
            .id("practiceTop")
    }
}
