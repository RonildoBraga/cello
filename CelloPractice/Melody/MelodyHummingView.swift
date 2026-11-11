import SwiftUI

@MainActor
struct MelodyHummingView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    let piece: MelodyPiece
    @State private var section: MelodySection
    /// A chip was tapped to switch phrase: the phrase it shows plays once.
    @State private var hearOnArrival = false
    @Environment(\.practiceMethod) private var method

    init(store: SessionStore, capture: CaptureController, piece: MelodyPiece, section: MelodySection = .phrase1) {
        self.store = store
        self.capture = capture
        self.piece = piece
        _section = State(initialValue: section)
    }

    private var context: MelodyPracticeContext { piece.humming(register: method.wrappedValue.register, section: section) }

    /// Hum it steps through the four phrases; Whole melody is one part and a lesson of its own.
    private var parts: LessonParts? {
        guard section != .whole else { return nil }
        return LessonParts(MelodySection.phrases, current: section, noun: "Phrase", title: \.title,
                           passed: store.melodyProgress(for: context).passed) { section = $0 }
    }

    var body: some View {
        VoicePracticeView(store: store, capture: capture, mode: .phrase(context), parts: parts,
                          hearOnArrival: $hearOnArrival) { controls in
            VStack(alignment: .leading, spacing: 17) {
                LessonHeader(subtitle: piece.hummingIntro,
                           collapsesSubtitle: store.melodyProgress(for: context).successfulAttempts > 0)
                PartStrip(parts: section == .whole ? [.whole] : MelodySection.phrases, selection: $section,
                          leading: section == .whole ? nil : "Phrase",
                          short: { $0 == .whole ? $0.title : $0.chipLabel }, title: \.title,
                          progress: { store.melodyProgress(for: piece.humming(register: method.wrappedValue.register, section: $0)) },
                          hear: controls.hearing)
                    .disabled(controls.locked)
                Text("\(Int(context.duration)) seconds · \(context.tempoBPM) BPM")
                    .font(.caption).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("melodyTakeDuration")
                MelodyNotesView(context: context,
                                elapsed: capture.isRecording ? capture.elapsed
                                    : capture.isPlayingReference ? capture.referenceElapsed : nil)
            }.id("practiceTop")
        }.id("\(piece.rawValue)|\(section.rawValue)|\(method.wrappedValue.rawValue)")
            .background(Palette.paper).screenTitle(piece.title, methodSwitch: capture)
    }
}
