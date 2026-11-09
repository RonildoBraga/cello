import SwiftUI

/// Shared navigation chooses a complete lesson; each activity owns its own runtime.
@MainActor
struct PracticeView: View {
    @ObservedObject var store: SessionStore
    @StateObject private var capture = CaptureController()
    let rhythmStores: [RhythmExercise: PulsePracticeStore]
    @Binding var selection: PracticeSelection
    let restartToken: UUID
    let onStartLesson: (PracticeLesson) -> Void
    let onShowMusic: () -> Void

    private struct ActivityIdentity: Hashable {
        let lesson: PracticeLesson
        let restartToken: UUID
    }

    private var lesson: PracticeLesson { selection.lesson }
    private var activityIdentity: ActivityIdentity {
        ActivityIdentity(lesson: lesson, restartToken: restartToken)
    }

    var body: some View {
        NavigationStack {
            activityScreen
                .background(Palette.paper)
                .navigationTitle(selection.area.title)
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private var activityScreen: some View {
        switch lesson.activity {
        case .recording(let exercise):
            VoicePracticeView(store: store, capture: capture, exercise: exercise,
                              nextLesson: lesson.next, onStartLesson: onStartLesson,
                              onShowLessons: onShowMusic) { locked in
                practiceHeader(disabled: locked)
            }.id(activityIdentity)
        case .rhythm(let exercise):
            PulsePracticeView(store: rhythmStore(for: exercise), isActive: true,
                              nextLesson: lesson.next, onNext: onStartLesson) {
                practiceHeader(disabled: false)
            }.id(activityIdentity)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        PracticeLessonsButton(onTap: onShowMusic)
                    }
                }
        }
    }

    private func practiceHeader(disabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Practice area", selection: $selection.area) {
                ForEach(LearningArea.allCases) { area in
                    Text(area.title).tag(area)
                }
            }.pickerStyle(.segmented)
                .accessibilityIdentifier("practiceAreaPicker")
            Menu {
                ForEach(PracticeLesson.lessons(in: selection.area)) { item in
                    Button { onStartLesson(item) } label: {
                        if item == lesson { Label(item.title, systemImage: "checkmark") }
                        else { Text(item.title) }
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text(lesson.title)
                            .font(.system(size: 27, weight: .semibold, design: .serif))
                            .foregroundStyle(Palette.ink)
                        Text(lesson.practicePrompt).font(.footnote).foregroundStyle(Palette.muted)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.forest).frame(width: 34, height: 34)
                        .background(Palette.forest.opacity(0.06), in: Circle())
                }.frame(minHeight: 52).contentShape(Rectangle())
            }.disabled(disabled)
                .accessibilityIdentifier("exercisePicker")
                .accessibilityLabel("Exercise: \(lesson.title)")
        }.id("practiceTop")
    }

    private func rhythmStore(for exercise: RhythmExercise) -> PulsePracticeStore {
        guard let store = rhythmStores[exercise] else {
            preconditionFailure("Every rhythm lesson must have its own practice store")
        }
        return store
    }
}

struct PracticeLessonsButton: View {
    var disabled = false
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 6) {
                Image(systemName: "music.note.list")
                Text("Music")
            }.font(.subheadline.weight(.medium))
        }.accessibilityLabel("Music library")
            .accessibilityIdentifier("musicLibraryButton")
            .disabled(disabled)
    }
}
