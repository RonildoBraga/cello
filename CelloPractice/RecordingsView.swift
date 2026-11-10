import SwiftUI

struct RecordingsView: View {
    @ObservedObject var store: SessionStore
    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                ScreenHeader(title: "Recordings").padding(.horizontal, Layout.gutter).padding(.top, 16)
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
                                        .frame(width: Layout.tileSize, height: Layout.tileSize)
                                        .background(Palette.forest.opacity(0.07),
                                                    in: RoundedRectangle(cornerRadius: Layout.tileRadius))
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
                                            Stars(count: stars, size: 10)
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
