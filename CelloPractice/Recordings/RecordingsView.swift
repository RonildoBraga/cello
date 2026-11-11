import SwiftUI

struct RecordingsView: View {
    @ObservedObject var store: SessionStore
    let onOpenMusic: () -> Void
    @State private var editMode = EditMode.inactive
    @State private var confirmsDeleteAll = false
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
                            store.delete(offsets.map { store.sessions[$0] })
                        }
                    }.listStyle(.plain).scrollContentBackground(.hidden)
                }
            }.background(Palette.paper)
                .screenTitle("Recordings")
                .toolbar {
                    if !store.sessions.isEmpty {
                        if editMode.isEditing {
                            ToolbarItem(placement: .topBarLeading) {
                                Button("Delete all", role: .destructive) { confirmsDeleteAll = true }
                                    .accessibilityIdentifier("recordingsDeleteAllButton")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) { EditButton() }
                    }
                }
                .environment(\.editMode, $editMode)
                .confirmationDialog("Delete all \(store.sessions.count) recordings?", isPresented: $confirmsDeleteAll,
                                    titleVisibility: .visible) {
                    Button("Delete all recordings", role: .destructive) {
                        store.delete(store.sessions)
                        editMode = .inactive
                    }
                } message: {
                    Text("This frees their space and cannot be undone. Passed and gold results are kept.")
                }
                .onAppear { store.refreshPendingRecordings() }
        }
    }
}
