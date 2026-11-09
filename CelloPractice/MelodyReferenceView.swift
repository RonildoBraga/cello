import SwiftUI

/// Manual listening only; melody recording and assessment belong to the next delivery.
@MainActor
struct MelodyReferenceView: View {
    @ObservedObject var capture: CaptureController
    @Environment(\.scenePhase) private var scenePhase
    @State private var register = MelodyRegister.lowVoice
    @State private var section = MelodySection.whole
    @State private var hasRequestedPlayback = false
    @State private var isVisible = false

    // Enum selections and the fixed supported tempo make this built-in context valid.
    private var context: MelodyPracticeContext {
        try! .hotCrossBuns(register: register, section: section, tempoBPM: 60)
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Hot Cross Buns")
                        .font(.system(size: 30, weight: .semibold, design: .serif))
                        .foregroundStyle(Palette.ink)
                    Text("Listen first, then gently hum along. Choose a register that feels easy.")
                        .font(.subheadline).foregroundStyle(Palette.muted)
                }
                VStack(alignment: .leading, spacing: 12) {
                    Text("Reference register").font(.subheadline.weight(.semibold))
                    Picker("Reference register", selection: $register) {
                        ForEach(MelodyRegister.allCases) { item in
                            Text(item.title).tag(item)
                        }
                    }.pickerStyle(.segmented).accessibilityIdentifier("melodyRegisterPicker")
                    Text("\(register.keyName) · \(register.rangeLabel) · 60 BPM")
                        .font(.footnote).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("melodyReferenceKey")
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text("Follow the notes").font(.headline)
                        Spacer()
                        Picker("Melody section", selection: $section) {
                            ForEach(MelodySection.allCases) { item in
                                Text(item.title).tag(item)
                            }
                        }.tint(Palette.forest).accessibilityIdentifier("melodySectionPicker")
                    }
                    ForEach(visiblePhrases, id: \.self) { phrase in
                        phraseRow(phrase)
                    }
                    Text("Longer tiles hold longer. The quick notes in phrase 3 last half a beat each.")
                        .font(.caption).foregroundStyle(Palette.muted)
                }.padding(18).background(.white, in: RoundedRectangle(cornerRadius: 20))
                    .accessibilityIdentifier("melodyNoteDisplay")
                VStack(alignment: .leading, spacing: 7) {
                    Label("Reference tones", systemImage: "waveform")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.forest)
                    Text("Generated notes for listening and humming along. Phrase recording and stars come next.")
                        .font(.footnote).foregroundStyle(Palette.muted)
                }
                if hasRequestedPlayback, !capture.isPlayingReference, let message = capture.message {
                    Text(message).font(.footnote).foregroundStyle(Palette.muted)
                        .accessibilityIdentifier("melodyPlaybackMessage")
                }
            }.foregroundStyle(Palette.ink).padding(20).padding(.bottom, 12)
        }.background(Palette.paper)
            .navigationTitle("Listen & follow").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) { playbackControl }
            .onChange(of: register) { _, _ in hasRequestedPlayback = false; capture.stop() }
            .onChange(of: section) { _, _ in hasRequestedPlayback = false; capture.stop() }
            .onChange(of: scenePhase) { _, phase in
                if isVisible, phase != .active { hasRequestedPlayback = false; capture.stop() }
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false; hasRequestedPlayback = false; capture.stop() }
    }

    private var visiblePhrases: [Int] {
        section == .whole ? Array(0..<4) : [0]
    }

    private func phraseRow(_ phrase: Int) -> some View {
        let events = context.expectedEvents.enumerated().filter {
            Int($0.element.onsetBeat / 4) == phrase
        }
        let current = capture.isPlayingReference ? context.eventIndex(at: capture.referenceElapsed) : nil
        return VStack(alignment: .leading, spacing: 8) {
            Text(section == .whole ? "Phrase \(phrase + 1)" : section.title)
                .font(.caption.weight(.medium)).foregroundStyle(Palette.muted)
            GeometryReader { geometry in
                HStack(spacing: 4) {
                    ForEach(events, id: \.offset) { index, event in
                        let highlighted = current == index
                        Text(event.frequency(tuningA4Hz: context.tuningA4Hz).map {
                            TunerReading(frequency: $0, targetFrequency: nil).noteName
                        } ?? "Rest")
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .minimumScaleFactor(0.7).lineLimit(1)
                            .frame(width: max(0, (geometry.size.width - CGFloat(events.count - 1) * 4)
                                * event.durationBeats / 4), height: 48)
                            .foregroundStyle(highlighted ? .white : Palette.forest)
                            .background(highlighted ? Palette.forest : Palette.forest.opacity(0.07),
                                        in: RoundedRectangle(cornerRadius: 9))
                            .accessibilityLabel("\(event.frequency(tuningA4Hz: context.tuningA4Hz).map { TunerReading(frequency: $0, targetFrequency: nil).noteName } ?? "Rest"), \(event.durationBeats.formatted()) beats")
                    }
                }
            }.frame(height: 48)
        }
    }

    private var playbackControl: some View {
        VStack(spacing: 10) {
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
                    .font(.headline).frame(maxWidth: .infinity).padding(.vertical, 13)
            }.buttonStyle(.borderedProminent).tint(Palette.forest)
                .accessibilityIdentifier("melodyPlayButton")
        }.padding(.horizontal, 20).padding(.vertical, 14).background(Palette.paper)
    }
}
