import SwiftUI

/// A new score is chosen only between attempts; recording freezes that choice.
@MainActor
struct EchoPracticeView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController

    private struct Choice {
        let level: EchoLevel
        let patternIndex: Int
    }

    @State private var choice = Choice(level: .twoNotes,
                                      patternIndex: EchoLevel.twoNotes.nextPatternIndex(excluding: nil))
    @State private var register = MelodyRegister.lowVoice

    private var context: MelodyPracticeContext {
        try! choice.level.context(patternIndex: choice.patternIndex, register: register)
    }

    private var levelSelection: Binding<EchoLevel> {
        Binding(get: { choice.level }, set: { level in
            guard level != choice.level else { return }
            choice = Choice(level: level, patternIndex: level.nextPatternIndex(excluding: nil))
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
        VoicePracticeView(store: store, capture: capture, context: context,
                          onNextPhrase: newPattern) { locked in
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Listen & Echo")
                        .font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.ink)
                    Text("Hear the pattern, then hum it back. Follow the tuning bar as you record.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                Picker("Voice register", selection: registerSelection) {
                    Text("Low voice").tag(MelodyRegister.lowVoice)
                    Text("Higher voice").tag(MelodyRegister.higherVoice)
                }.pickerStyle(.segmented).disabled(locked)
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
                            .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                    }.buttonStyle(.plain).foregroundStyle(Palette.forest).disabled(locked)
                        .accessibilityIdentifier("echoNewPatternButton")
                }
                if choice.level == .twoNotes,
                   store.echoProgress(for: .twoNotes, register: register).completed {
                    Button {
                        levelSelection.wrappedValue = .threeNotes
                    } label: {
                        Label("Try three notes", systemImage: "arrow.right")
                            .font(.subheadline.weight(.medium)).frame(minHeight: 44)
                    }.buttonStyle(.plain).foregroundStyle(Palette.forest).disabled(locked)
                        .accessibilityIdentifier("echoNextLevelButton")
                }
            }.id("practiceTop")
        }.id("\(choice.level.pieceID)|\(register.rawValue)|\(choice.patternIndex)")
            .background(Palette.paper)
            .navigationTitle("Listen & Echo").navigationBarTitleDisplayMode(.inline)
    }

    private func newPattern() {
        choice = Choice(level: choice.level,
                        patternIndex: choice.level.nextPatternIndex(excluding: choice.patternIndex))
    }
}
