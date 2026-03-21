import SwiftUI
import QueenUILib

@main
struct QueenApp: App {
    @StateObject private var watcher = StateWatcher()
    @StateObject private var server = ControlServer.shared
    @AppStorage("appearanceMode") private var appearanceModeRaw: String = AppearanceMode.dark.rawValue

    private var isPuppetMode: Bool {
        ProcessInfo.processInfo.environment["PUPPET_MODE"] != nil ||
        ProcessInfo.processInfo.arguments.contains("--puppet")
    }

    private var resolvedScheme: ColorScheme? {
        switch AppearanceMode(rawValue: appearanceModeRaw) ?? .dark {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    var body: some Scene {
        WindowGroup {
            content
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didFinishLaunchingNotification)) { _ in
                    // Start server after app finishes launching
                    server.startIfPuppetMode()
                }
            // Always show AutomationOverlay for GUI mode
                .onAppear {
                    AutomationOverlay()
                }
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
                .keyboardShortcut("c", modifiers: [.command, .shift])

                Button("Clear Chat") {
                    NotificationCenter.default.post(name: .clearChat, object: nil)
                }
                .keyboardShortcut("k", modifiers: [.command, .option])
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

                Button("Focus Input") {
                    NotificationCenter.default.post(name: .focusInput, object: nil)
                }
                .keyboardShortcut("/", modifiers: .command)

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

    @ViewBuilder
    private var content: some View {
        ZStack {
            MainView()
                .environmentObject(watcher)
                .environmentObject(AccessibilityManager.shared)
                .environmentObject(server)
                .preferredColorScheme(resolvedScheme)

            // Show automation overlay only in puppet mode
            if isPuppetMode {
                AutomationOverlay()
                    .allowsHitTesting(false)
            }
        }
        .onAppear {
            // Also try onAppear as fallback
            server.startIfPuppetMode()
        }
    }
}
