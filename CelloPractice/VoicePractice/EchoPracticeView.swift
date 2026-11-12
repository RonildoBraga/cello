import CelloPitch
import SwiftUI

/// A new score is chosen only between attempts; recording freezes that choice.
@MainActor
struct EchoPracticeView: View {
    @ObservedObject var store: SessionStore
    let capture: CaptureController

    @State private var level = EchoLevel.twoNotes
    @Environment(\.practiceMethod) private var method
    /// The pattern on show, by its place in the level's catalogue; the method decides its register.
    @State private var patternIndex = EchoLevel.twoNotes.nextPatternIndex(excluding: nil)
    /// A chip was tapped to switch pattern length: the new pattern plays once.
    @State private var hearOnArrival = false

    private var register: MelodyRegister { method.wrappedValue.register }
    private var context: MelodyPracticeContext { level.pattern(patternIndex, register: register) }

    private var levelSelection: Binding<EchoLevel> {
        Binding(get: { level }, set: { next in
            guard next != level else { return }
            level = next
            patternIndex = next.nextPatternIndex(excluding: nil)
        })
    }

    var body: some View {
        let parts = LessonParts(EchoLevel.allCases, current: level, noun: "Part", title: \.title,
                                passed: store.echoProgress(for: level, register: register).passed) {
            levelSelection.wrappedValue = $0
        }
        VoicePracticeView(store: store, capture: capture, mode: .echo(context, level: level), parts: parts,
                          hearOnArrival: $hearOnArrival) { controls in
            VStack(alignment: .leading, spacing: 16) {
                LessonHeader(subtitle: "Tap the pattern to hear it, then \(method.wrappedValue.verb) it back. Follow the tuning bar as you record.",
                           collapsesSubtitle: store.echoProgress(for: level, register: register).successfulAttempts > 0)
                // The pattern's notes stay secret, so its chip is named by its length.
                HStack(spacing: 8) {
                    PartStrip(parts: EchoLevel.allCases, selection: levelSelection, short: \.title, title: \.title,
                              progress: { store.echoProgress(for: $0, register: register) },
                              hear: controls.hearing)
                    Button(action: newPattern) {
                        Label("New pattern", systemImage: "shuffle").labelStyle(.iconOnly)
                    }.buttonStyle(SecondaryActionButtonStyle())
                        .accessibilityIdentifier("echoNewPatternButton")
                }.disabled(controls.locked)
                Text("\(Int(context.duration)) seconds · \(context.tempoBPM) BPM")
                    .font(.caption).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("echoDuration")
            }.id("practiceTop")
        }.id("\(level.pieceID)|\(register.rawValue)|\(patternIndex)")
            .background(Palette.paper).screenTitle("Listen & Echo", methodSwitch: capture)
    }

    private func newPattern() {
        patternIndex = level.nextPatternIndex(excluding: patternIndex)
    }
}
