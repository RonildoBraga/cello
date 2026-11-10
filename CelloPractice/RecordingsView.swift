import SwiftUI

struct RecordingsView: View {
    @ObservedObject var store: SessionStore
    let onOpenMusic: () -> Void
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Recordings").padding(.horizontal, Layout.gutter).padding(.top, 16)
                if store.sessions.isEmpty {
                    ContentUnavailableView {
                        Label("No recordings yet", systemImage: "waveform.path")
                    } description: {
                        Text("Takes you record in a humming or cello lesson are saved here with their score. Tapping rounds keep their scores on the lesson page.")
                        if store.pendingRecordingCount > 0 {
                            Text("\(store.pendingRecordingCount) unsaved recording(s) are preserved in Files → On My iPhone → Cello → PendingTakes.")
                        }
                        if let error = store.errorMessage { Text(error) }
                    } actions: {
                        Button("Open Music", action: onOpenMusic).buttonStyle(.bordered)
                            .accessibilityIdentifier("recordingsOpenMusicButton")
                    }
                } else {
                    List {
                        if let error = store.errorMessage {
                            Text(error).font(.footnote).foregroundStyle(.red)
                                .listRowBackground(Palette.paper)
                        }
                        if store.pendingRecordingCount > 0 {
                            Text("\(store.pendingRecordingCount) unfinished or unsaved recording(s) are preserved in Files → On My iPhone → Cello → PendingTakes.")
                                .font(.footnote).foregroundStyle(Palette.muted)
                        }
                        ForEach(store.sessions) { session in
                            NavigationLink {
                                SessionDetailView(session: session, store: store)
                            } label: {
                                HStack(spacing: 12) {
                                    IconTile { Image(systemName: "play.fill").font(.subheadline) }
                                    VStack(alignment: .leading, spacing: 5) {
                                        Text(session.title).font(.subheadline.weight(.semibold))
                                            .foregroundStyle(Palette.ink)
                                        Text(session.createdAt.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption).foregroundStyle(Palette.muted)
                                    }
                                    Spacer(minLength: 8)
                                    VStack(alignment: .trailing, spacing: 5) {
                                        Text(timeString(session.duration)).font(.caption.monospacedDigit())
                                            .foregroundStyle(Palette.muted)
                                        if let stars = session.starCount {
                                            Stars(count: stars, font: .caption2)
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
                .screenTitle("Recordings")
                .toolbar { if !store.sessions.isEmpty { EditButton() } }
                .onAppear { store.refreshPendingRecordings() }
        }
    }
}
