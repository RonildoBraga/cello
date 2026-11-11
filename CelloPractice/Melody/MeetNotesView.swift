import SwiftUI

/// A melody's notes one at a time: hear a note, then hum it back with the live
/// tuning bar. Two short pairs follow, to hear and feel higher and lower.
@MainActor
struct MeetNotesView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    let piece: MelodyPiece
    @State private var drill: NoteDrill

    init(store: SessionStore, capture: CaptureController, piece: MelodyPiece) {
        self.store = store
        self.capture = capture
        self.piece = piece
        _drill = State(initialValue: NoteDrill.drills(for: piece)[0])
    }

    private var drills: [NoteDrill] { NoteDrill.drills(for: piece) }
    private var context: MelodyPracticeContext { drill.context }
    private var next: NoteDrill? {
        drills.firstIndex(of: drill).flatMap { drills.indices.contains($0 + 1) ? drills[$0 + 1] : nil }
    }

    var body: some View {
        VoicePracticeView(store: store, capture: capture, mode: .phrase(context),
                          nextPhrase: next.map { next in (next.title, { drill = next }) }) { locked in
            VStack(alignment: .leading, spacing: 17) {
                LessonHeader(step: .meetNotes(piece),
                             subtitle: "This melody uses \(NoteDrill.notes(for: piece).count) notes. Hear one, then hum it back after 3–2–1. The bar shows how close you are.",
                             collapsesSubtitle: store.melodyProgress(for: context).successfulAttempts > 0)
                HStack {
                    ChoiceMenu(choices: drills, selection: $drill, name: "Note", title: \.title) {
                        store.melodyProgress(for: $0.context).completed
                    }.disabled(locked).accessibilityIdentifier("meetNotesPicker")
                    Spacer()
                    Text("\(Int(context.duration)) seconds")
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                MelodyNotesView(context: context,
                                elapsed: capture.isRecording ? capture.elapsed
                                    : capture.isPlayingReference ? capture.referenceElapsed : nil)
            }.id("practiceTop")
        }.id(drill.id)
            .background(Palette.paper).screenTitle(piece.title)
    }
}
