import SwiftUI
import QueenUILib

@main
struct QueenApp: App {
    @StateObject private var watcher = StateWatcher()

    var body: some Scene {
        WindowGroup {
            MainView()
                .environmentObject(watcher)
                .preferredColorScheme(.dark)
        }
        .windowStyle(.titleBar)
    }
}
