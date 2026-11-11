import SwiftUI

/// A melody's notes one at a time: hear a note, then hum it back with the live
/// tuning bar. Two short pairs follow, to hear and feel higher and lower.
@MainActor
struct MeetNotesView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    let piece: MelodyPiece
    @State private var drill: NoteDrill
    /// A chip was tapped to switch note: the note it shows plays once.
    @State private var hearOnArrival = false

    init(store: SessionStore, capture: CaptureController, piece: MelodyPiece) {
        self.store = store
        self.capture = capture
        self.piece = piece
        _drill = State(initialValue: NoteDrill.drills(for: piece)[0])
    }

    private var drills: [NoteDrill] { NoteDrill.drills(for: piece) }
    private var context: MelodyPracticeContext { drill.context }
    private var parts: LessonParts {
        LessonParts(drills, current: drill, noun: "Note", title: \.title,
                    passed: store.melodyProgress(for: context).passed) { drill = $0 }
    }

    var body: some View {
        let mode = VoicePracticeMode.phrase(context)
        VoicePracticeView(store: store, capture: capture, mode: mode, parts: parts,
                          hearOnArrival: $hearOnArrival) { controls in
            VStack(alignment: .leading, spacing: 17) {
                LessonHeader(subtitle: "This melody uses \(NoteDrill.notes(for: piece).count) notes. Tap a note to hear it, then hum it back after the count of 1–2–3–4. The bar shows how close you are.",
                             collapsesSubtitle: store.melodyProgress(for: context).successfulAttempts > 0)
                // The chips name every note and play it, so nothing else on the screen repeats them.
                PartStrip(parts: drills, selection: $drill, short: \.chipLabel, title: \.title,
                          progress: { store.melodyProgress(for: $0.context) },
                          hear: PartHearing(spoken: mode.hearSpoken, identifier: "previewTargetButton") { changed in
                              if changed { hearOnArrival = true } else { controls.hear() }
                          })
                    .disabled(controls.locked)
            }.id("practiceTop")
        }.id(drill.id)
            .background(Palette.paper).screenTitle(piece.title)
    }
}
