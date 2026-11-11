import SwiftUI

@MainActor
struct MelodyHummingView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    let piece: MelodyPiece
    /// The step this screen was opened as. It stays fixed while the section
    /// menu moves around, so the step bar always leads to a different screen.
    private let step: PathStep
    @State private var section: MelodySection

    init(store: SessionStore, capture: CaptureController, piece: MelodyPiece, section: MelodySection = .phrase1) {
        self.store = store
        self.capture = capture
        self.piece = piece
        step = section == .whole ? .wholeMelody(piece) : .hum(piece)
        _section = State(initialValue: section)
    }

    private var context: MelodyPracticeContext { piece.humming(register: .lowVoice, section: section) }

    var body: some View {
        VoicePracticeView(store: store, capture: capture, mode: .phrase(context),
                          nextPhrase: section.next.map { next in (next.title, { section = next }) }) { locked in
            VStack(alignment: .leading, spacing: 17) {
                StepHeader(step: step, subtitle: piece.hummingIntro,
                           collapsesSubtitle: store.melodyProgress(for: context).successfulAttempts > 0)
                HStack {
                    SectionMenu(selection: $section) {
                        store.melodyProgress(for: piece.humming(register: .lowVoice, section: $0)).completed
                    }.disabled(locked).accessibilityIdentifier("melodyHummingSectionPicker")
                    Spacer()
                    Text("\(Int(context.duration)) seconds · \(context.tempoBPM) BPM")
                        .font(.caption).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("melodyTakeDuration")
                }
                MelodyNotesView(context: context,
                                elapsed: capture.isRecording ? capture.elapsed
                                    : capture.isPlayingReference ? capture.referenceElapsed : nil)
            }.id("practiceTop")
        }.id("\(piece.rawValue)|\(section.rawValue)")
            .background(Palette.paper).screenTitle(piece.title)
    }
}
