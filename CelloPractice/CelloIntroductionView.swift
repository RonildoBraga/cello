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
                Text("Learn the parts and hear the four strings, from low to high.")
                    .font(.subheadline).foregroundStyle(Palette.muted)
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Find the parts").font(.headline)
                        Spacer()
                        Text("Front view").font(.caption).foregroundStyle(Palette.muted)
                    }
                    CelloDiagramView()
                }.padding(17).background(.white, in: RoundedRectangle(cornerRadius: 19))
                stringExamples
                lessonPath
            }.foregroundStyle(Palette.ink).padding(.horizontal, 22).padding(.vertical, 18)
        }.background(Palette.paper)
            .navigationTitle("Meet your cello").navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom, spacing: 0) {
                Button {
                    capture.stop()
                    dismiss()
                } label: {
                    Label("View open-string lessons", systemImage: "arrow.right")
                        .font(.headline).foregroundStyle(.white)
                        .frame(maxWidth: .infinity, minHeight: 56)
                        .background(Palette.forest, in: RoundedRectangle(cornerRadius: 18))
                }.buttonStyle(.plain).accessibilityIdentifier("celloIntroBrowseLessons")
                    .padding(.horizontal, 22).padding(.vertical, 12).background(Palette.paper)
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
                Text("Hear the strings").font(.headline)
                Spacer()
                Text("Low → high").font(.caption).foregroundStyle(Palette.muted)
            }
            Text("An open string sounds without a left-hand finger pressing it.")
                .font(.footnote).foregroundStyle(Palette.muted)
            ForEach(strings) { string in
                HStack(spacing: 12) {
                    Text(string.targetNote!.dropLast()).font(.system(size: 24, weight: .semibold, design: .serif))
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
        }.padding(17).background(.white, in: RoundedRectangle(cornerRadius: 19))
    }

    private var lessonPath: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Your next steps").font(.headline)
            Text("With your cello, build these skills one at a time.")
                .font(.footnote).foregroundStyle(Palette.muted)
            ForEach(nextSteps.indices, id: \.self) { index in
                HStack(alignment: .top, spacing: 12) {
                    Text("\(index + 1)").font(.caption.weight(.semibold))
                        .foregroundStyle(Palette.forest).frame(width: 25, height: 25)
                        .background(Palette.forest.opacity(0.08), in: Circle())
                    VStack(alignment: .leading, spacing: 4) {
                        Text(nextSteps[index].0).font(.subheadline.weight(.semibold))
                        Text(nextSteps[index].1).font(.footnote).foregroundStyle(Palette.muted)
                    }
                }
            }
        }.padding(17).frame(maxWidth: .infinity, alignment: .leading)
            .background(.white, in: RoundedRectangle(cornerRadius: 19))
            .accessibilityIdentifier("celloIntroNextSteps")
    }
}
