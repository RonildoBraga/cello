import SwiftUI

@MainActor
struct MelodyHummingView: View {
    @ObservedObject var store: SessionStore
    @ObservedObject var capture: CaptureController
    var piece: MelodyPiece = .hotCrossBuns
    @State private var register = MelodyRegister.lowVoice
    @State private var section = MelodySection.phrase1

    private var context: MelodyPracticeContext {
        try! .melody(piece: piece, register: register, section: section, gradingVersion: MelodyRating.currentVersion)
    }

    private var nextSection: MelodySection? {
        switch section {
        case .phrase1: return .phrase2
        case .phrase2: return .phrase3
        case .phrase3: return .phrase4
        case .phrase4: return .whole
        case .whole: return nil
        }
    }

    var body: some View {
        VoicePracticeView(store: store, capture: capture, context: context,
                          onNextPhrase: nextSection.map { next in { section = next } }) { locked in
            VStack(alignment: .leading, spacing: 17) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Humming").font(.system(size: 27, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.ink)
                    Text(piece == .odeToJoy
                         ? "Follow five notes moving up and down. Hear the phrase, then record after 3–2–1."
                         : "Hear the phrase, then record the same notes and rhythm. Start humming after 3–2–1.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                Picker("Voice register", selection: $register) {
                    Text("Low voice").tag(MelodyRegister.lowVoice)
                    Text("Higher voice").tag(MelodyRegister.higherVoice)
                }.pickerStyle(.segmented).disabled(locked)
                    .accessibilityIdentifier("melodyHummingRegisterPicker")
                HStack {
                    Menu {
                        ForEach(MelodySection.allCases) { item in
                            Button { section = item } label: {
                                let choice = try! MelodyPracticeContext.melody(
                                    piece: piece, register: register, section: item, gradingVersion: MelodyRating.currentVersion)
                                if store.melodyProgress(for: choice).completed {
                                    Label("\(item.title) · completed", systemImage: "checkmark.circle.fill")
                                } else if item == section {
                                    Label(item.title, systemImage: "checkmark")
                                } else { Text(item.title) }
                            }
                        }
                    } label: {
                        HStack(spacing: 7) {
                            Text(section.title).font(.headline)
                            Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                        }.foregroundStyle(Palette.forest).frame(minHeight: 44)
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
        }.id("\(piece.rawValue)|\(register.rawValue)|\(section.rawValue)")
            .background(Palette.paper)
            .navigationTitle(piece.title).navigationBarTitleDisplayMode(.inline)
    }
}
