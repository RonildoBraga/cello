import CelloPitch
import SwiftUI

/// A manual listening page sharing the same recorded references as phrase practice.
@MainActor
struct MelodyReferenceView: View {
    @ObservedObject var capture: CaptureController
    let piece: MelodyPiece
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.practiceMethod) private var method
    @State private var section = MelodySection.whole
    @State private var hasRequestedPlayback = false
    @State private var isVisible = false
    /// Counts chip taps: each one plays the part it shows, as on every other lesson.
    @State private var hearRequest = 0
    @AppStorage(StoredIDs.listenedMelodies) private var listened = ""

    private var register: MelodyRegister { method.wrappedValue.register }
    private var context: MelodyPracticeContext { piece.reference(register: register, section: section) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LessonHeader(subtitle: piece.listenIntro)
                Text("\(register == .cello ? "Recorded cello" : "Recorded hum") · \(piece.keyName(for: register)) · \(piece.rangeLabel(for: register)) · 60 BPM")
                    .font(.caption).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("melodyReferenceKey")
                VStack(alignment: .leading, spacing: 12) {
                    SectionTitle("Follow the notes")
                    PartStrip(parts: MelodySection.allCases, selection: $section, leading: "Phrase",
                              short: \.chipLabel, title: \.title,
                              hear: PartHearing(spoken: section == .whole ? "Hear melody" : "Hear phrase",
                                                identifier: "melodyHearChip") { _ in hearRequest += 1 })
                    MelodyNotesView(context: context,
                                    elapsed: capture.isPlayingReference ? capture.referenceElapsed : nil)
                    Text(piece.notesHint).font(.caption).foregroundStyle(Palette.muted)
                }.card()
                if hasRequestedPlayback, !capture.isPlayingReference, let message = capture.message {
                    Text(message).font(.footnote).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("melodyPlaybackMessage")
                }
            }.foregroundStyle(Palette.ink).screenContent()
        }.id(piece).background(Palette.paper)
            .screenTitle("Listen", methodSwitch: capture)
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
            .task(id: hearRequest) {
                guard hearRequest > 0 else { return }
                await capture.waitUntilQuiet()
                guard isVisible, scenePhase == .active else { return }
                hasRequestedPlayback = true
                capture.playMelodyReference(context)
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
