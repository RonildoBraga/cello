import SwiftUI

struct ContentView: View {
    private enum Tab: Hashable { case music, recordings }
    @ObservedObject var store: SessionStore
    @StateObject private var capture = CaptureController()
    @StateObject private var rhythmStores = RhythmStores()
    @StateObject private var melodyRhythmStore = MelodyRhythmStore()
    @State private var selectedTab = Tab.music

    var body: some View {
        TabView(selection: $selectedTab) {
            MusicLibraryView(store: store, capture: capture, rhythmStores: rhythmStores,
                             melodyRhythmStore: melodyRhythmStore)
                .tabItem { Label("Music", systemImage: "music.note.list") }
                .tag(Tab.music)
            RecordingsView(store: store)
                .tabItem { Label("Recordings", systemImage: "play.rectangle.on.rectangle") }
                .tag(Tab.recordings)
        }
    }
}
