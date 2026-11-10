import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case music, practice, recordings }
    @ObservedObject var store: SessionStore
    @StateObject private var capture = CaptureController()
    @StateObject private var rhythmStores = RhythmStores()
    @StateObject private var melodyRhythmStore = MelodyRhythmStore()
    @State private var selectedTab = Tab.music
    @State private var selection = PracticeSelection()
    @State private var practiceRevision = UUID()
    @State private var libraryRevision = UUID()

    var body: some View {
        TabView(selection: $selectedTab) {
            MusicLibraryView(store: store, capture: capture, rhythmStores: rhythmStores,
                             melodyRhythmStore: melodyRhythmStore, onStartLesson: startLesson)
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
