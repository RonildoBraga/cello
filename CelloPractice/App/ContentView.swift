import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case music, recordings, about }
    @ObservedObject var store: SessionStore
    let capture: CaptureController
    @StateObject private var rhythmStores = RhythmStores()
    @StateObject private var melodyRhythmStore = MelodyRhythmStore()
    @State private var selectedTab = Tab.music

    var body: some View {
        TabView(selection: $selectedTab) {
            MusicLibraryView(store: store, capture: capture, rhythmStores: rhythmStores,
                             melodyRhythmStore: melodyRhythmStore)
                .tabItem { Label("Music", systemImage: "music.note.list") }
                .tag(Tab.music)
            RecordingsView(store: store, onOpenMusic: { selectedTab = .music })
                .tabItem { Label("Recordings", systemImage: "play.rectangle.on.rectangle") }
                .tag(Tab.recordings)
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(Tab.about)
        }
    }
}
