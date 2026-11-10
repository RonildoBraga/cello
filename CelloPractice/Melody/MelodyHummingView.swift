import SwiftUI

@MainActor
struct MelodyHummingView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    var piece: MelodyPiece = .hotCrossBuns
    @State private var section = MelodySection.phrase1

    private var context: MelodyPracticeContext { piece.humming(register: .lowVoice, section: section) }

    var body: some View {
        VoicePracticeView(store: store, capture: capture, mode: .phrase(context),
                          nextPhrase: section.next.map { next in (next.title, { section = next }) }) { locked in
            VStack(alignment: .leading, spacing: 17) {
                ScreenHeader(eyebrow: piece.title, title: "Humming", subtitle: piece.hummingIntro,
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
