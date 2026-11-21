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
    /// Takes are sound only; older cello takes also hold video, and keep the video player.
    @State private var hasVideo = false
    @State private var sound: TakeSound?
    @State private var error: String?
    private var noisyRoom: Bool { session.room?.isLoud == true }
    /// The teacher's note for a melody take, worked out once when the recording is opened.
    private let feedback: String
    init(session: PracticeSession, store: SessionStore) {
        self.session = session
        self.store = store
        feedback = session.melodyFeedback(earlier: store.melodyRatings(before: session)) ?? ""
        _player = State(initialValue: AVPlayer(url: store.recordingURL(for: session)))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                ScreenHeader(title: session.title,
                             subtitle: "\(session.createdAt.formatted(date: .long, time: .shortened)) · \(timeString(session.duration))")
                if let rating = session.melodyRating, let context = session.melodyContext {
                    MelodyFeedbackView(rating: rating, feedback: feedback, isEcho: EchoLevel.selection(for: context) != nil)
                    if noisyRoom { RoomNoiseNote() }
                    MelodyTraceView(context: context, rating: rating, duration: session.duration).card()
                } else if let rating = session.rating {
                    PracticeRatingView(rating: rating)
                        .accessibilityIdentifier("archivedRatingCard")
                    if noisyRoom { RoomNoiseNote() }
                }
                if let target = session.effectiveTargetFrequency {
                    PitchTraceView(samples: session.pitchSamples, targetFrequency: target, duration: session.duration).card()
                } else if let context = session.melodyContext, session.melodyRating == nil {
                    MelodyTraceView(context: context, samples: session.pitchSamples, duration: session.duration).card()
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("Playback", systemImage: "waveform")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.forest)
                    Group {
                        if hasVideo {
                            VideoPlayer(player: player).frame(height: 220)
                                .clipShape(RoundedRectangle(cornerRadius: Layout.cardRadius))
                        } else {
                            TakePlayerView(player: player, sound: sound, duration: session.duration)
                        }
                    }.accessibilityIdentifier("sessionPlaybackPlayer")
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
            .task {
                // Heard through the speaker even with the ring switch on silent.
                try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
                let recording = store.recordingURL(for: session)
                let tracks = try? await AVURLAsset(url: recording).loadTracks(withMediaType: .video)
                if let tracks { hasVideo = !tracks.isEmpty }
                guard !hasVideo else { return }
                sound = await TakeSound.load(recording: recording, duration: session.duration, id: session.id)
                if let sound, sound.url != recording { player.replaceCurrentItem(with: AVPlayerItem(url: sound.url)) }
            }
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

