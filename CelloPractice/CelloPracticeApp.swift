import SwiftUI
import UIKit

@main
struct CelloPracticeApp: App {
    @StateObject private var store = SessionStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .tint(Palette.forest)
                .preferredColorScheme(.light)
                .onChange(of: scenePhase, initial: true) { _, phase in
                    UIApplication.shared.isIdleTimerDisabled = phase == .active
                }
                .onDisappear { UIApplication.shared.isIdleTimerDisabled = false }
        }
    }
}
