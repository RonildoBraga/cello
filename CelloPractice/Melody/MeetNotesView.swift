import SwiftUI

/// A melody's notes one at a time: hear a note, then hum it back with the live
/// tuning bar. Two short pairs follow, to hear and feel higher and lower.
@MainActor
struct MeetNotesView: View {
    @ObservedObject var store: SessionStore
    let capture: CaptureController
    let piece: MelodyPiece
    @Environment(\.practiceMethod) private var method
    /// Which of the lesson's notes is on show; the method decides its register.
    @State private var index = 0
    /// A chip was tapped to switch note: the note it shows plays once.
    @State private var hearOnArrival = false

    private var drills: [NoteDrill] { NoteDrill.drills(for: piece, register: method.wrappedValue.register) }
    private var drill: NoteDrill { drills[index] }
    private var context: MelodyPracticeContext { drill.context }
    private var parts: LessonParts {
        LessonParts(drills, current: drill, noun: "Note", title: \.title,
                    passed: store.melodyProgress(for: context).passed) { index = drills.firstIndex(of: $0) ?? 0 }
    }

    var body: some View {
        VoicePracticeView(store: store, capture: capture, mode: .phrase(context), parts: parts,
                          hearOnArrival: $hearOnArrival) { controls in
            VStack(alignment: .leading, spacing: 17) {
                LessonHeader(subtitle: "This melody uses \(NoteDrill.notes(for: piece).count) notes. Tap a note to hear it, then \(method.wrappedValue.verb) it back after the count of 1–2–3–4. The bar shows how close you are.",
                             collapsesSubtitle: store.melodyProgress(for: context).successfulAttempts > 0)
                // The chips name every note and play it, so nothing else on the screen repeats them.
                PartStrip(parts: drills, selection: Binding(get: { drill }, set: { index = drills.firstIndex(of: $0) ?? 0 }), short: \.chipLabel, title: \.title,
                          progress: { store.melodyProgress(for: $0.context) },
                          hear: controls.hearing)
                    .disabled(controls.locked)
            }.id("practiceTop")
        }.id(drill.id)
            .background(Palette.paper).screenTitle(piece.title, methodSwitch: capture)
    }
}
