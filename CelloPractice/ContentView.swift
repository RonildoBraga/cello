import SwiftUI
import AVFoundation
import AVKit
import UIKit

enum Palette {
    static let paper = Color(red: 0.97, green: 0.96, blue: 0.93)
    static let forest = Color(red: 0.16, green: 0.30, blue: 0.26)
    static let ink = Color(red: 0.16, green: 0.20, blue: 0.18)
    static let gold = Color(red: 0.69, green: 0.47, blue: 0.24)
    static let muted = Color(red: 0.40, green: 0.44, blue: 0.41)
}

struct ContentView: View {
    private enum Tab: Hashable { case music, practice, recordings }
    @ObservedObject var store: SessionStore
    @StateObject private var capture = CaptureController()
    @StateObject private var pulseStore = PulsePracticeStore(exercise: .pulse)
    @StateObject private var twoTapsStore = PulsePracticeStore(exercise: .twoTaps)
    @StateObject private var mixedRhythmStore = PulsePracticeStore(exercise: .mixedRhythm)
    @State private var selectedTab = Tab.music
    @State private var selection = PracticeSelection()
    @State private var practiceRevision = UUID()
    @State private var libraryRevision = UUID()

    private var rhythmStores: [RhythmExercise: PulsePracticeStore] {
        [.pulse: pulseStore, .twoTaps: twoTapsStore, .mixedRhythm: mixedRhythmStore]
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            MusicLibraryView(store: store, capture: capture, pulseStore: pulseStore, twoTapsStore: twoTapsStore,
                             mixedRhythmStore: mixedRhythmStore, onStartLesson: startLesson)
                .id(libraryRevision)
                .tabItem { Label("Music", systemImage: "music.note.list") }
                .tag(Tab.music)
            PracticeView(store: store, capture: capture, rhythmStores: rhythmStores, selection: $selection,
                         restartToken: practiceRevision, onStartLesson: startLesson, onShowMusic: showMusic)
                .tabItem { Label("Practice", systemImage: "waveform") }
                .tag(Tab.practice)
            RecordingsView(store: store)
                .tabItem { Label("Recordings", systemImage: "play.rectangle.on.rectangle") }
                .tag(Tab.recordings)
        }
    }

    private func startLesson(_ lesson: PracticeLesson) {
        selection.select(lesson)
        practiceRevision = UUID()
        selectedTab = .practice
    }

    private func showMusic() {
        libraryRevision = UUID()
        selectedTab = .music
    }
}

struct PitchMeter: View {
    let cents: Double
    let active: Bool
    var range: Double = 50
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Capsule().fill(.white.opacity(0.12)).frame(height: 5)
                ForEach(-2...2, id: \.self) { tick in
                    Rectangle().fill(.white.opacity(tick == 0 ? 0.9 : 0.25))
                        .frame(width: tick == 0 ? 2 : 1, height: tick == 0 ? 26 : 12)
                        .offset(x: CGFloat(tick) * geometry.size.width / 4)
                }
                if active {
                    Circle().fill(abs(cents) <= 10 ? Color(red: 0.80, green: 0.90, blue: 0.70) : Color(red: 0.98, green: 0.76, blue: 0.47))
                        .frame(width: 15, height: 15)
                        .offset(x: CGFloat(min(range, max(-range, cents)) / (2 * range)) * geometry.size.width)
                        .animation(.linear(duration: 0.1), value: cents)
                }
            }.frame(width: geometry.size.width, height: geometry.size.height)
        }.accessibilityHidden(true)
    }
}

struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }
    func updateUIView(_ view: PreviewView, context: Context) {}
    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer { layer as! AVCaptureVideoPreviewLayer }
        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}

struct RecordingsView: View {
    @ObservedObject var store: SessionStore
    var body: some View {
        NavigationStack {
            Group {
                if store.sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No recordings", systemImage: "waveform.path")
                    } description: {
                        if store.pendingRecordingCount > 0 {
                            Text("\(store.pendingRecordingCount) unsaved recording(s) are preserved in Files → On My iPhone → Cello → PendingTakes.")
                        }
                    }
                } else {
                    List {
                        if store.pendingRecordingCount > 0 {
                            Text("\(store.pendingRecordingCount) unfinished or unsaved recording(s) are preserved in Files → On My iPhone → Cello → PendingTakes.")
                                .font(.footnote).foregroundStyle(Palette.muted)
                        }
                        ForEach(store.sessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session, store: store)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "play.fill").font(.subheadline)
                                        .foregroundStyle(Palette.forest)
                                        .frame(width: 42, height: 42)
                                        .background(Palette.forest.opacity(0.07), in: RoundedRectangle(cornerRadius: 13))
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(session.exercise.title).font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Palette.ink)
                                        Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption).foregroundStyle(Palette.muted)
                                    }
                                    Spacer(minLength: 8)
                                    VStack(alignment: .trailing, spacing: 5) {
                                        Text(timeString(session.duration)).font(.caption.monospacedDigit())
                                            .foregroundStyle(Palette.muted)
                                        if let stars = session.rating?.starCount {
                                            Label("\(stars)/3", systemImage: "star.fill").font(.caption2.weight(.semibold))
                                                .foregroundStyle(Palette.gold)
                                                .accessibilityLabel("\(stars) of 3 stars")
                                        }
                                    }
                                }.padding(.vertical, 8)
                            }.accessibilityIdentifier("recording-\(session.id.uuidString)")
                                .listRowBackground(Palette.paper)
                                .listRowSeparatorTint(Palette.forest.opacity(0.1))
                        }.onDelete { offsets in
                            let sessions = offsets.map { store.sessions[$0] }
                            for session in sessions { store.delete(session) }
                        }
                    }.listStyle(.plain).scrollContentBackground(.hidden)
                }
            }.background(Palette.paper)
                .navigationTitle("Recordings")
                .toolbar { if !store.sessions.isEmpty { EditButton() } }
                .onAppear { store.refreshPendingRecordings() }
        }
    }
}

struct SessionDetailView: View {
    let session: PracticeSession
    @ObservedObject var store: SessionStore
    @State private var player: AVPlayer
    @State private var exporting = false
    @State private var exportURL: URL?
    @State private var error: String?
    init(session: PracticeSession, store: SessionStore) {
        self.session = session
        self.store = store
        _player = State(initialValue: AVPlayer(url: store.videoURL(for: session)))
    }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(session.exercise.title)
                            .font(.system(size: 27, weight: .semibold, design: .serif))
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 8)
                        Text(timeString(session.duration)).font(.subheadline.monospacedDigit())
                            .foregroundStyle(Palette.muted)
                    }
                    Text(session.createdAt.formatted(date: .long, time: .shortened))
                        .font(.caption).foregroundStyle(Palette.muted)
                }
                if let rating = session.rating {
                    PracticeRatingView(rating: rating)
                        .accessibilityIdentifier("archivedRatingCard")
                }
                if let target = session.effectiveTargetFrequency {
                    PitchTraceView(samples: session.pitchSamples, targetFrequency: target, duration: session.duration)
                }
                VStack(alignment: .leading, spacing: 10) {
                    Label("Playback", systemImage: "play.rectangle")
                        .font(.subheadline.weight(.semibold)).foregroundStyle(Palette.forest)
                    VideoPlayer(player: player).frame(height: 220)
                        .accessibilityIdentifier("sessionPlaybackPlayer")
                        .clipShape(RoundedRectangle(cornerRadius: 18))
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
                if exportURL == nil {
                    Button {
                        exporting = true
                        error = nil
                        Task { @MainActor in
                            do {
                                let current = store.sessions.first(where: { $0.id == session.id }) ?? session
                                exportURL = try await store.export(current)
                            } catch { self.error = error.localizedDescription }
                            exporting = false
                        }
                    } label: {
                        HStack {
                            if exporting { ProgressView().tint(.white) } else { Image(systemName: "square.and.arrow.up") }
                            Text(exporting ? "Preparing your session…" : "Prepare session to share")
                        }.font(.subheadline.weight(.semibold)).frame(maxWidth: .infinity).padding(.vertical, 10)
                    }.buttonStyle(.bordered).disabled(exporting)
                }
                if let exportURL {
                    ShareLink(item: exportURL) {
                        Label("Share session", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity).padding(14)
                    }.buttonStyle(.borderedProminent)
                }
                if let error { Text(error).font(.footnote).foregroundStyle(.red) }
                if let error = store.errorMessage { Text(error).font(.footnote).foregroundStyle(.red) }
            }.padding(20).padding(.bottom, 84)
        }.background(Palette.paper).navigationTitle("Your session").navigationBarTitleDisplayMode(.inline)
            .onDisappear { player.pause() }
    }
}

func timeString(_ duration: TimeInterval) -> String {
    let seconds = max(0, Int(exactly: duration.rounded(.towardZero)) ?? 0)
    let remainder = seconds % 60
    return "\(seconds / 60):\(remainder < 10 ? "0" : "")\(remainder)"
}
