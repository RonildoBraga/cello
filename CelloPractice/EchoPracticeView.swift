import SwiftUI

/// A new score is chosen only between attempts; recording freezes that choice.
@MainActor
struct EchoPracticeView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController

    @State private var level = EchoLevel.twoNotes
    @State private var register = MelodyRegister.lowVoice
    @State private var pattern = EchoLevel.twoNotes.newPattern(register: .lowVoice, excluding: nil)

    private var context: MelodyPracticeContext { pattern.context }

    private var levelSelection: Binding<EchoLevel> {
        Binding(get: { level }, set: { next in
            guard next != level else { return }
            level = next
            pattern = next.newPattern(register: register, excluding: nil)
        })
    }

    private var registerSelection: Binding<MelodyRegister> {
        Binding(get: { register }, set: { next in
            guard next != register else { return }
            register = next
            newPattern()
        })
    }

    var body: some View {
        VoicePracticeView(store: store, capture: capture, mode: .echo(context, level: level),
                          onNextPhrase: newPattern) { locked in
            VStack(alignment: .leading, spacing: 16) {
                ScreenHeader(eyebrow: "Ear training", title: "Listen & Echo",
                             subtitle: "Hear the pattern, then hum it back. Follow the tuning bar as you record.")
                VoiceRegisterPicker(selection: registerSelection).disabled(locked)
                    .accessibilityIdentifier("echoRegisterPicker")
                Picker("Pattern length", selection: levelSelection) {
                    ForEach(EchoLevel.allCases) { level in
                        Text(level.title).tag(level)
                    }
                }.pickerStyle(.segmented).disabled(locked)
                    .accessibilityIdentifier("echoLevelPicker")
                HStack {
                    Text("\(Int(context.duration)) seconds · \(context.tempoBPM) BPM")
                        .font(.caption).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("echoDuration")
                    Spacer()
                    Button(action: newPattern) {
                        Label("New pattern", systemImage: "shuffle")
                    }.buttonStyle(SecondaryActionButtonStyle()).disabled(locked)
                        .accessibilityIdentifier("echoNewPatternButton")
                }
                if level == .twoNotes,
                   store.echoProgress(for: .twoNotes, register: register).completed {
                    Button {
                        levelSelection.wrappedValue = .threeNotes
                    } label: {
                        Label("Try three notes", systemImage: "arrow.right")
                    }.buttonStyle(SecondaryActionButtonStyle()).disabled(locked)
                        .accessibilityIdentifier("echoNextLevelButton")
                }
            }.id("practiceTop")
        }.id("\(level.pieceID)|\(register.rawValue)|\(pattern.index)")
            .background(Palette.paper).screenTitle("Listen & Echo")
    }

    private func newPattern() {
        pattern = level.newPattern(register: register, excluding: pattern.index)
    }
}
