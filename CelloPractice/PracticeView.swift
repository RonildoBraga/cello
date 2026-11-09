import SwiftUI

/// Shared navigation chooses a complete lesson; each activity owns its own runtime.
@MainActor
struct PracticeView: View {
    @ObservedObject var store: SessionStore
    @StateObject private var capture = CaptureController()
    let rhythmStores: [RhythmExercise: PulsePracticeStore]
    @Binding var selection: PracticeSelection
    @State private var showingLessons = false
    @State private var restartToken = UUID()

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
                .navigationTitle(selection.section.title)
                .navigationBarTitleDisplayMode(.inline)
                .sheet(isPresented: $showingLessons) {
                    LessonsView(store: store, pulseStore: rhythmStore(for: .pulse), twoTapsStore: rhythmStore(for: .twoTaps),
                                mixedRhythmStore: rhythmStore(for: .mixedRhythm),
                                initialSection: selection.section,
                                onStartLesson: selectLesson, onClose: { showingLessons = false })
                }
        }
    }

    @ViewBuilder
    private var activityScreen: some View {
        switch lesson.activity {
        case .recording(let exercise):
            VoicePracticeView(store: store, capture: capture, exercise: exercise, section: lesson.section,
                              nextLesson: lesson.next, onStartLesson: selectLesson,
                              onShowLessons: { showingLessons = true }) { locked in
                practiceHeader(disabled: locked)
            }.id(activityIdentity)
        case .rhythm(let exercise):
            PulsePracticeView(store: rhythmStore(for: exercise), isActive: !showingLessons,
                              nextLesson: lesson.next, onNext: selectLesson) {
                practiceHeader(disabled: false)
            }.id(activityIdentity)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        PracticeLessonsButton { showingLessons = true }
                    }
                }
        }
    }

    private func practiceHeader(disabled: Bool) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Picker("Practice section", selection: $selection.section) {
                ForEach(PracticeSection.allCases) { section in
                    Text(section.title).tag(section)
                }
            }.pickerStyle(.segmented)
                .accessibilityIdentifier("practiceSectionPicker")
            Menu {
                ForEach(PracticeLesson.lessons(in: selection.section)) { item in
                    Button { selectLesson(item) } label: {
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

    private func selectLesson(_ lesson: PracticeLesson) {
        selection.select(lesson)
        restartToken = UUID()
        showingLessons = false
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
                Image(systemName: "books.vertical")
                Text("Lessons")
            }.font(.subheadline.weight(.medium))
        }.accessibilityLabel("Lessons")
            .accessibilityIdentifier("hummingLearnButton")
            .disabled(disabled)
    }
}
