import SwiftUI

/// A tuner for the four open strings. Listening makes no take and changes no progress.
@MainActor
struct TuneCelloView: View {
    @ObservedObject var capture: CaptureController
    @Environment(\.scenePhase) private var scenePhase
    @State private var string = Exercise.openA
    @State private var tuner = StringTuner(target: Exercise.openA.targetFrequency!)

    private var name: String { String(string.targetNote!.dropLast()) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                LessonHeader(title: "Tune your cello", subtitle: "Tune A first, then D, G and C. Play one open string at a time.")
                tunerCard
                howTo
            }.foregroundStyle(Palette.ink).screenContent()
        }.background(Palette.paper)
            .screenTitle("Tune your cello")
            .bottomActionBar {
                Button {
                    if capture.isReady { capture.stop() } else { capture.start(includingCamera: false) }
                } label: {
                    Label(capture.isReady ? "Stop listening" : "Start listening",
                          systemImage: capture.isReady ? "stop.fill" : "mic.fill")
                }.buttonStyle(PrimaryActionButtonStyle()).accessibilityIdentifier("tunerListenButton")
            }
            .onChange(of: capture.frequency) { _, frequency in tuner.hear(frequency) }
            .onDisappear { capture.stop() }
            // The microphone prompt makes the scene inactive; stopping then would cancel the request.
            .onChange(of: scenePhase) { _, phase in if phase == .background { capture.stop() } }
    }

    private var tunerCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 8) {
                ForEach(PracticeMethod.openStrings) { option in
                    let label = String(option.targetNote!.dropLast())
                    let selected = option == string
                    Button(label) { choose(option) }
                        .font(.headline).foregroundStyle(selected ? .white : Palette.forest)
                        .frame(minWidth: 52, minHeight: 44)
                        .background(Palette.forest.opacity(selected ? 1 : 0.07), in: Capsule())
                        .buttonStyle(.plain)
                        .accessibilityLabel("\(label) string")
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityIdentifier("tuneString-\(label)")
                }
                Spacer()
                Button {
                    if capture.isPlayingReference { capture.stop() }
                    else { capture.playCelloReference(frequency: string.targetFrequency!) }
                } label: {
                    Image(systemName: capture.isPlayingReference ? "stop.fill" : "speaker.wave.2")
                        .frame(width: 44, height: 44)
                }.buttonStyle(.plain).foregroundStyle(Palette.forest)
                    .accessibilityLabel(capture.isPlayingReference ? "Stop" : "Hear \(name)")
                    .accessibilityIdentifier("tuneHear")
            }
            VStack(spacing: 6) {
                Text(status).font(.system(.title2, design: .serif).weight(.semibold))
                    .foregroundStyle(tuner.advice == .inTune ? Palette.forest : Palette.ink)
                    .multilineTextAlignment(.center)
                    .accessibilityIdentifier("tunerStatus")
                Text(tuner.cents.map { String(format: "%+.0f cents", $0) } ?? " ")
                    .font(.subheadline).monospacedDigit().foregroundStyle(Palette.muted)
            }.frame(maxWidth: .infinity)
            PitchMeter(cents: tuner.cents ?? 0, active: tuner.cents != nil,
                       tolerance: StringTuner.inTuneCents, onCard: true)
                .frame(height: 30).padding(.horizontal, 6)
            if let message = capture.message {
                Text(message).font(.footnote).foregroundStyle(Palette.muted)
            }
        }.card()
    }

    private var status: String {
        guard capture.isReady else { return "Tap Start listening, then play the \(name) string" }
        switch tuner.advice {
        case nil: return "Play the \(name) string"
        case .inTune: return "\(name) is in tune"
        case .low: return "A little low · tighten slightly"
        case .high: return "A little high · loosen slightly"
        case .farLow: return "Far too low · use the peg"
        case .farHigh: return "Far too high · use the peg"
        }
    }

    private var howTo: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle("How to tune")
            NumberedStep(number: 1, title: "Play the open string",
                         detail: "Pluck or bow it on its own and let it ring while you watch the tuner.")
            NumberedStep(number: 2, title: "Small changes: the fine tuner",
                         detail: "Turn the screw on the tailpiece. Clockwise raises the note, anticlockwise lowers it.")
            NumberedStep(number: 3, title: "Big changes: the peg",
                         detail: "Turn it a little at a time while pressing it into the pegbox so it holds.")
            NumberedStep(number: 4, title: "Come up to the note",
                         detail: "If a string is high, loosen it below the note, then bring it up.")
            Text("Go slowly: a string wound too far can break. If a peg slips, a string is far off, or the bridge starts to lean, ask a teacher or a string shop.")
                .font(.footnote).foregroundStyle(Palette.muted)
        }.card().accessibilityIdentifier("tunerHowTo")
    }

    private func choose(_ option: Exercise) {
        string = option
        tuner = StringTuner(target: option.targetFrequency!)
    }
}
