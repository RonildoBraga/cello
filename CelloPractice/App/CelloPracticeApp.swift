import SwiftUI
import UIKit

@main
struct CelloPracticeApp: App {
    @StateObject private var store = SessionStore()
    /// The one capture session. It ticks many times a second while it plays or
    /// records, so it is owned here unobserved: only a screen that shows a take
    /// in progress observes it.
    private let capture = CaptureController()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(store: store, capture: capture)
                .tint(Palette.forest)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    UIApplication.shared.isIdleTimerDisabled = phase == .active
                }
                .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }
}
