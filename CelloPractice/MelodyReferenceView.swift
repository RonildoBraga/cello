import SwiftUI

/// A manual listening page sharing the same recorded references as phrase practice.
@MainActor
struct MelodyReferenceView: View {
    @ObservedObject var capture: CaptureController
    var piece: MelodyPiece = .hotCrossBuns
    @Environment(\.scenePhase) private var scenePhase
    @State private var register = MelodyRegister.lowVoice
    @State private var section = MelodySection.whole
    @State private var hasRequestedPlayback = false
    @State private var isVisible = false

    // Enum selections and the fixed supported tempo make this built-in context valid.
    private var context: MelodyPracticeContext {
        try! .melody(piece: piece, register: register, section: section, tempoBPM: 60)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(eyebrow: piece.title, title: "Listen & follow", subtitle: piece == .odeToJoy
                             ? "Hear the five-note opening, then gently hum along. Choose a register that feels easy."
                             : "Listen first, then gently hum along. Choose a register that feels easy.")
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Reference register", selection: $register) {
                        ForEach(MelodyRegister.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }.pickerStyle(.segmented).accessibilityIdentifier("melodyRegisterPicker")
                    Text("\(register == .cello ? "Recorded cello" : "Recorded hum") · \(register.keyName) · \(piece.rangeLabel(for: register)) · 60 BPM")
                        .font(.caption).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("melodyReferenceKey")
                }
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionTitle("Follow the notes")
                        Spacer()
                        Menu {
                            ForEach(MelodySection.allCases) { item in
                                Button { section = item } label: {
                                    if item == section { Label(item.title, systemImage: "checkmark") }
                                    else { Text(item.title) }
                                }
                            }
                        } label: {
                            HStack(spacing: 5) {
                                Text(section.title)
                                Image(systemName: "chevron.down").font(.caption.weight(.semibold))
                            }.font(.subheadline)
                        }.tint(Palette.forest)
                            .accessibilityLabel("Section: \(section.title)")
                            .accessibilityIdentifier("melodySectionPicker")
                    }
                    MelodyNotesView(context: context,
                                    elapsed: capture.isPlayingReference ? capture.referenceElapsed : nil)
                    Text(piece == .odeToJoy
                         ? "Longer tiles hold longer. Phrase 4 has a long note, a quick note, then a held ending."
                         : "Longer tiles hold longer. The quick notes in phrase 3 last half a beat each.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }.card()
                VStack(alignment: .leading, spacing: 7) {
                    Label(register == .cello ? "Recorded cello" : "Recorded hum", systemImage: "waveform")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.forest)
                    Text(register == .cello
                         ? "Recorded bowed cello notes, tuned and arranged into the melody."
                         : "A recorded human hum, with pitch and timing edited into the melody. Open Humming to record and earn stars.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                if hasRequestedPlayback, !capture.isPlayingReference, let message = capture.message {
                    Text(message).font(.footnote).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("melodyPlaybackMessage")
                }
            }.foregroundStyle(Palette.ink).screenContent()
        }.id(piece).background(Palette.paper)
            .screenTitle("Listen & follow")
            .bottomActionBar { playbackControl }
            .onChange(of: piece) { _, _ in hasRequestedPlayback = false; capture.stop() }
            .onChange(of: register) { _, _ in hasRequestedPlayback = false; capture.stop() }
            .onChange(of: section) { _, _ in hasRequestedPlayback = false; capture.stop() }
            .onChange(of: scenePhase) { _, phase in
                if isVisible, phase != .active { hasRequestedPlayback = false; capture.stop() }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false; hasRequestedPlayback = false; capture.stop() }
    }

    private var playbackControl: some View {
        Group {
            if capture.isPlayingReference {
                HStack {
                    Text("Playing \(section == .whole ? "melody" : section.title.lowercased())")
                    Spacer()
                    Text("\(timeString(capture.referenceElapsed)) / \(timeString(context.duration))")
                        .monospacedDigit()
                }.font(.caption).foregroundStyle(Palette.muted)
                    .accessibilityElement(children: .combine)
                    .accessibilityIdentifier("melodyPlaybackStatus")
            }
            Button {
                if capture.isPlayingReference { capture.stop() }
                else {
                    hasRequestedPlayback = true
                    capture.playMelodyReference(context)
                }
            } label: {
                Label(capture.isPlayingReference ? "Stop" : section == .whole ? "Hear melody" : "Hear phrase",
                      systemImage: capture.isPlayingReference ? "stop.fill" : "play.fill")
            }.buttonStyle(PrimaryActionButtonStyle()).accessibilityIdentifier("melodyPlayButton")
        }
    }
}
