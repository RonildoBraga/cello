import SwiftUI

/// A new score is chosen only between attempts; recording freezes that choice.
@MainActor
struct EchoPracticeView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController

    @State private var level = EchoLevel.twoNotes
    /// Echo patterns are sung in the one voice the app offers.
    private let register = MelodyRegister.lowVoice
    @State private var pattern = EchoLevel.twoNotes.newPattern(register: .lowVoice, excluding: nil)

    private var context: MelodyPracticeContext { pattern.context }

    /// A chip was tapped to switch pattern length: the new pattern plays once.
    @State private var hearOnArrival = false

    private var levelSelection: Binding<EchoLevel> {
        Binding(get: { level }, set: { next in
            guard next != level else { return }
            level = next
            pattern = next.newPattern(register: register, excluding: nil)
        })
    }

    var body: some View {
        let mode = VoicePracticeMode.echo(context, level: level)
        let parts = LessonParts(EchoLevel.allCases, current: level, noun: "Part", title: \.title,
                                passed: store.echoProgress(for: level, register: register).passed) {
            levelSelection.wrappedValue = $0
        }
        VoicePracticeView(store: store, capture: capture, mode: mode, parts: parts,
                          hearOnArrival: $hearOnArrival) { controls in
            VStack(alignment: .leading, spacing: 16) {
                LessonHeader(subtitle: "Tap the pattern to hear it, then hum it back. Follow the tuning bar as you record.",
                           collapsesSubtitle: store.echoProgress(for: level, register: register).successfulAttempts > 0)
                // The pattern's notes stay secret, so its chip is named by its length.
                PartStrip(parts: EchoLevel.allCases, selection: levelSelection, short: \.title, title: \.title,
                          progress: { store.echoProgress(for: $0, register: register) },
                          hear: PartHearing(spoken: mode.hearSpoken, identifier: "previewTargetButton") { changed in
                              if changed { hearOnArrival = true } else { controls.hear() }
                          })
                    .disabled(controls.locked)
                HStack {
                    Text("\(Int(context.duration)) seconds · \(context.tempoBPM) BPM")
                        .font(.caption).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("echoDuration")
                    Spacer()
                    Button(action: newPattern) {
                        Label("New pattern", systemImage: "shuffle")
                    }.buttonStyle(SecondaryActionButtonStyle()).disabled(controls.locked)
                        .accessibilityIdentifier("echoNewPatternButton")
                }
            }.id("practiceTop")
        }.id("\(level.pieceID)|\(register.rawValue)|\(pattern.index)")
            .background(Palette.paper).screenTitle("Listen & Echo")
    }

    private func newPattern() {
        pattern = level.newPattern(register: register, excluding: pattern.index)
    }
}
