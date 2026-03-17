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
        .commands {
            // File menu
            CommandGroup(after: .newItem) {
                Button("New Thread") {
                    NotificationCenter.default.post(name: .newThread, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Divider()

                Button("Export Thread...") {
                    NotificationCenter.default.post(name: .toggleCommandPalette, object: nil)
                }
                .keyboardShortcut("e", modifiers: [.command, .shift])
            }

            // Edit menu additions
            CommandGroup(after: .pasteboard) {
                Divider()

                Button("Find in Thread...") {
                    NotificationCenter.default.post(name: .searchInThread, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)

                Button("Search Threads...") {
                    NotificationCenter.default.post(name: .toggleThreadSearch, object: nil)
                }
                .keyboardShortcut("f", modifiers: [.command, .shift])

                Button("Copy Last Response") {
                    NotificationCenter.default.post(name: .copyLastResponse, object: nil)
                }
                .keyboardShortcut(";", modifiers: [.command, .shift])
            }

            // View menu
            CommandGroup(after: .toolbar) {
                Button("Toggle Sidebar") {
                    NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])

                Button("Command Palette") {
                    NotificationCenter.default.post(name: .toggleCommandPalette, object: nil)
                }
                .keyboardShortcut("k", modifiers: .command)

                Divider()

                Button("Previous Thread") {
                    NotificationCenter.default.post(name: .prevThread, object: nil)
                }
                .keyboardShortcut("[", modifiers: .command)

                Button("Next Thread") {
                    NotificationCenter.default.post(name: .nextThread, object: nil)
                }
                .keyboardShortcut("]", modifiers: .command)
            }
        }
    }
}
