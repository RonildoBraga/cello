import AVKit
import SwiftUI
import UIKit

struct SessionDetailView: View {
    let session: PracticeSession
    @ObservedObject var store: SessionStore
    @State private var player: AVPlayer
    @State private var exporting = false
    @State private var exportURL: URL?
    @State private var sharing = false
    @State private var error: String?
    init(session: PracticeSession, store: SessionStore) {
        self.session = session
        self.store = store
        _player = State(initialValue: AVPlayer(url: store.videoURL(for: session)))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: session.title,
                             subtitle: "\(session.createdAt.formatted(date: .long, time: .shortened)) · \(timeString(session.duration))")
                if let rating = session.melodyRating, let context = session.melodyContext {
                    MelodyFeedbackView(rating: rating, isEcho: EchoLevel.selection(for: context) != nil)
                    MelodyTraceView(context: context, rating: rating, duration: session.duration)
                } else if let rating = session.rating {
                    PracticeRatingView(rating: rating)
                        .accessibilityIdentifier("archivedRatingCard")
                }
                if let target = session.effectiveTargetFrequency {
                    PitchTraceView(samples: session.pitchSamples, targetFrequency: target, duration: session.duration)
                } else if let context = session.melodyContext, session.melodyRating == nil {
                    MelodyTraceView(context: context, samples: session.pitchSamples, duration: session.duration)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("Playback", systemImage: "play.rectangle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.forest)
                    VideoPlayer(player: player).frame(height: 220)
                        .accessibilityIdentifier("sessionPlaybackPlayer")
                        .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius))
                }
                DisclosureGroup("Recording details") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(session.pitchSamples.count) pitch readings")
                        if let offset = session.medianCentsFromTarget {
                            Text(String(format: "%+.0f cents · %@", offset, session.effectiveTargetNote ?? "target"))
                            Text("Zero matches the target. Positive is above it; negative is below it.")
                        }
                    }.font(.caption).foregroundStyle(Palette.muted)
                        .padding(.top, 8).frame(maxWidth: .infinity, alignment: .leading)
                }.font(.subheadline.weight(.medium)).foregroundStyle(Palette.forest)
                Button(action: share) {
                    HStack {
                        if exporting { ProgressView() } else { Image(systemName: "square.and.arrow.up") }
                        Text(exporting ? "Preparing your session…" : "Share session")
                    }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                }.buttonStyle(.bordered).disabled(exporting)
                    .accessibilityIdentifier("shareSessionButton")
                if let message = error ?? store.errorMessage {
                    Text(message).font(.footnote).foregroundStyle(.red)
                }
            }.screenContent()
        }.background(Palette.paper).screenTitle("Your session")
            .onDisappear { player.pause() }
            .sheet(isPresented: $sharing) {
                if let exportURL { ActivitySheet(items: [exportURL]) }
            }
    }

    /// One tap: build the archive if needed, then hand it to the system share sheet.
    /// The prepared file is kept so sharing again is immediate.
    private func share() {
        error = nil
        guard exportURL == nil else {
            sharing = true
            return
        }
        exporting = true
        Task { @MainActor in
            do {
                let current = store.sessions.first(where: { $0.id == session.id }) ?? session
                exportURL = try await store.export(current)
                sharing = true
            } catch { self.error = error.localizedDescription }
            exporting = false
        }
    }
}

private struct ActivitySheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
