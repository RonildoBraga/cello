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
    @AppStorage(StoredIDs.listenedMelodies) private var listened = ""

    private var context: MelodyPracticeContext { piece.reference(register: register, section: section) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LessonHeader(step: .listen(piece), subtitle: piece.listenIntro)
                VStack(alignment: .leading, spacing: 12) {
                    Picker("Reference register", selection: $register) {
                        ForEach(MelodyRegister.offered) { item in
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
                        SectionMenu(selection: $section).accessibilityIdentifier("melodySectionPicker")
                    }
                    MelodyNotesView(context: context,
                                    elapsed: capture.isPlayingReference ? capture.referenceElapsed : nil)
                    Text(piece.notesHint).font(.caption).foregroundStyle(Palette.muted)
                }.card()
                VStack(alignment: .leading, spacing: 7) {
                    Label(register == .cello ? "Recorded cello" : "Recorded hum", systemImage: "waveform")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.forest)
                    Text(register == .cello
                         ? "Recorded bowed cello notes, tuned and arranged into the melody."
                         : "A recorded human hum, with pitch and timing edited into the melody. Open Hum it to record and earn stars.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                if hasRequestedPlayback, !capture.isPlayingReference, let message = capture.message {
                    Text(message).font(.footnote).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("melodyPlaybackMessage")
                }
            }.foregroundStyle(Palette.ink).screenContent()
        }.id(piece).background(Palette.paper)
            .screenTitle("Listen")
            .bottomActionBar { playbackControl }
            .onChange(of: piece) { _, _ in hasRequestedPlayback = false; capture.stop() }
            .onChange(of: register) { _, _ in hasRequestedPlayback = false; capture.stop() }
            .onChange(of: section) { _, _ in hasRequestedPlayback = false; capture.stop() }
            .onChange(of: scenePhase) { _, phase in
                if isVisible, phase != .active { hasRequestedPlayback = false; capture.stop() }
            }
            .onChange(of: capture.isPlayingReference) { _, playing in
                // Playback that reaches the end leaves the clock at the full length;
                // stopping it early resets the clock. Only the whole melody counts.
                if !playing, hasRequestedPlayback, section == .whole, capture.referenceElapsed >= context.duration - 0.1 {
                    listened = StoredIDs.adding(piece.rawValue, to: listened)
                }
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
