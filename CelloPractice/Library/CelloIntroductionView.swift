import SwiftUI

/// Listening and orientation do not create a performance attempt or completion.
@MainActor
struct CelloIntroductionView: View {
    @ObservedObject var capture: CaptureController
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var isVisible = false
    @State private var selectedString: Exercise?

    private let strings: [Exercise] = [.openC, .openG, .openD, .openA]
    private let nextSteps = [
        ("Get set up", "Find a comfortable setup with a teacher."),
        ("Open strings", "Build an even sound on one string."),
        ("First notes", "Learn finger placement and string choices with a teacher."),
        ("Short phrases", "Bring the notes and rhythm of Hot Cross Buns together."),
        ("The whole melody", "Join the phrases into a complete cello performance.")
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: "Meet your cello",
                             subtitle: "Learn the parts and hear the four strings, from low to high.")
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        SectionTitle("Find the parts")
                        Spacer()
                        Text("Front view").font(.caption).foregroundStyle(Palette.muted)
                    }
                    CelloDiagramView()
                }.card()
                stringExamples
                lessonPath
            }.foregroundStyle(Palette.ink).screenContent()
        }.background(Palette.paper)
            .screenTitle("Meet your cello")
            .bottomActionBar {
                Button {
                    capture.stop()
                    dismiss()
                } label: {
                    Label("View open-string lessons", systemImage: "arrow.right")
                }.buttonStyle(PrimaryActionButtonStyle()).accessibilityIdentifier("celloIntroBrowseLessons")
            }
            .onAppear { isVisible = true }
            .onDisappear { isVisible = false; selectedString = nil; capture.stop() }
            .onChange(of: scenePhase) { _, phase in
                if isVisible, phase != .active { selectedString = nil; capture.stop() }
            }
    }

    private var stringExamples: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                SectionTitle("Hear the strings")
                Spacer()
                Text("Low → high").font(.caption).foregroundStyle(Palette.muted)
            }
            Text("An open string sounds without a left-hand finger pressing it.")
                .font(.footnote).foregroundStyle(Palette.muted)
            ForEach(strings) { string in
                HStack(spacing: 12) {
                    Text(string.targetNote!.dropLast()).font(.system(.title2, design: .serif).weight(.semibold))
                        .foregroundStyle(Palette.forest).frame(width: 30)
                    Text(string.targetNote!).font(.subheadline).foregroundStyle(Palette.muted)
                    Spacer()
                    let playing = selectedString == string && capture.isPlayingReference
                    Button {
                        guard isVisible, scenePhase == .active, !capture.isRecording else { return }
                        if playing { capture.stop() }
                        else {
                            guard !capture.isPlayingReference else { return }
                            selectedString = string
                            capture.playCelloReference(frequency: string.targetFrequency!)
                        }
                    } label: {
                        Label(playing ? "Stop" : "Hear \(string.targetNote!.dropLast())",
                              systemImage: playing ? "stop.fill" : "speaker.wave.2")
                            .font(.subheadline.weight(.medium)).frame(minWidth: 90, minHeight: 44)
                    }.buttonStyle(.plain).foregroundStyle(Palette.forest)
                        .disabled(capture.isRecording || (capture.isPlayingReference && selectedString != string))
                        .accessibilityIdentifier("celloIntroHear-\(string.rawValue)")
                }
                if string != .openA { Divider().overlay(Palette.paper) }
            }
            if let string = selectedString, capture.isPlayingReference {
                Text("Playing \(string.targetNote!)")
                    .font(.caption).foregroundStyle(Palette.forest)
                    .accessibilityIdentifier("celloIntroPlaybackStatus")
            }
            Text("Recorded cello pitch examples. String technique comes with your playing lessons.")
                .font(.caption).foregroundStyle(Palette.muted)
            if selectedString != nil, !capture.isPlayingReference, let message = capture.message {
                Text(message).font(.footnote).foregroundStyle(Palette.muted)
                    .accessibilityIdentifier("celloIntroPlaybackMessage")
            }
        }.card()
    }

    private var lessonPath: some View {
        VStack(alignment: .leading, spacing: 16) {
            SectionTitle("Your next steps")
            Text("With your cello, build these skills one at a time.")
                .font(.footnote).foregroundStyle(Palette.muted)
            ForEach(nextSteps.indices, id: \.self) { index in
                NumberedStep(number: index + 1, title: nextSteps[index].0, detail: nextSteps[index].1)
            }
        }.card().accessibilityIdentifier("celloIntroNextSteps")
    }
}
