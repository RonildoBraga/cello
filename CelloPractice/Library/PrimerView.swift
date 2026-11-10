import SwiftUI
import UIKit

/// One screen for one new idea: a few plain sentences, something to hear or
/// feel on request, and Continue into the lesson. Nothing here is recorded.
@MainActor
struct PrimerView: View {
    let lesson: PracticeLesson
    let primer: LessonPrimer
    @ObservedObject var capture: CaptureController
    let onContinue: () -> Void
    @Environment(\.scenePhase) private var scenePhase
    /// The count being shown while a beat demonstration runs.
    @State private var cue: LessonPrimer.BeatCue?
    @State private var beats: Task<Void, Never>?

    private var isPlaying: Bool { capture.isPlayingReference || beats != nil }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                ScreenHeader(eyebrow: "Before \(lesson.title)", title: primer.title, titleIdentifier: "primerTitle")
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(primer.paragraphs, id: \.self) { paragraph in
                        Text(paragraph).font(.body).foregroundStyle(Palette.ink)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }.card().accessibilityElement(children: .contain).accessibilityIdentifier("primerText")
                if case .beats = primer.demo {
                    StatusCard(label: "Count", trailing: { EmptyView() }) {
                        StatusValue(text: cue?.label ?? "–", isCount: true)
                            .opacity(cue?.onBeat == false ? 0.6 : 1)
                            .accessibilityIdentifier("primerCount")
                    }
                }
            }.screenContent()
        }.background(Palette.paper).screenTitle(primer.title)
            .bottomActionBar {
                Button { isPlaying ? stop() : play() } label: {
                    Label(isPlaying ? "Stop" : primer.demoLabel, systemImage: isPlaying ? "stop.fill" : "play.fill")
                }.buttonStyle(SecondaryActionButtonStyle()).accessibilityIdentifier("primerDemoButton")
                Button("Continue to \(lesson.title)") {
                    stop()
                    onContinue()
                }.buttonStyle(PrimaryActionButtonStyle()).accessibilityIdentifier("primerContinueButton")
            }
            .onDisappear(perform: stop)
            .onChange(of: scenePhase) { _, phase in if phase != .active { stop() } }
    }

    private func play() {
        switch primer.demo {
        case .hum: capture.playHummingExample()
        case .twoNotes:
            // The lowest and highest notes of the first melody, a clear step apart.
            let notes = NoteDrill.notes(for: .hotCrossBuns).flatMap(\.midiNotes)
            if let low = notes.first, let high = notes.last {
                capture.playMelodyReference(NoteDrill(piece: .hotCrossBuns, midiNotes: [low, high]).context)
            }
        case .beats(let cues):
            beats = Task {
                for next in cues {
                    cue = next
                    if next.onBeat { UIImpactFeedbackGenerator(style: .soft).impactOccurred() }
                    do { try await Task.sleep(for: .seconds(next.seconds)) } catch { return }
                }
                cue = nil
                beats = nil
            }
        }
    }

    private func stop() {
        beats?.cancel()
        beats = nil
        cue = nil
        if capture.isPlayingReference { capture.stop() }
    }
}
