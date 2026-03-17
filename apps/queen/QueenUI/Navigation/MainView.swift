import SwiftUI

public struct MainView: View {
    @State private var selectedScreen: Screen? = nil
    @State private var keyMonitor: Any?
    @State private var showAgentStream = false
    @State private var showShortcuts = false

    /// Cmd+0–9 keyboard shortcuts
    private static let keyboardScreens: [Screen] = [
        .chat, .sevoFarm, .arenaLLM, .faculty, .oracle,
        .build, .deploy, .telegram, .settings,
    ]

    public init() {}

    public var body: some View {
        ZStack(alignment: .trailing) {
            Color.black.ignoresSafeArea()

            if let screen = selectedScreen {
                // Screen content with back button
                VStack(spacing: 0) {
                    // Top bar with back
                    HStack {
                        Button {
                            selectedScreen = nil
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "chevron.left")
                                Text("TRINITY")
                                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(TrinityTheme.accent)
                            .padding(8)
                        }
                        .buttonStyle(.plain)
                        .keyboardShortcut(.escape, modifiers: [])

                        Spacer()

                        Text("\(screen.icon) \(screen.rawValue)")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white)

                        Spacer()
                        // Balance spacer
                        Color.clear.frame(width: 80)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .frame(maxHeight: 32)
                    .background(TrinityTheme.bgCard)

                    ScreenRouter(screen: screen)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.opacity)
            } else {
                // 27-petal logo as main menu
                TriangleLogo(selectedScreen: $selectedScreen)
            }

            // Agent Stream overlay (Cmd+J)
            if showAgentStream {
                AgentStreamView()
                    .frame(width: 350)
                    .background(TrinityTheme.bgSidebar.opacity(0.95))
                    .transition(.move(edge: .trailing))
            }

            // Shortcuts overlay (Cmd+/)
            if showShortcuts {
                ShortcutsOverlay(isPresented: $showShortcuts)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedScreen)
        .animation(.easeInOut(duration: 0.25), value: showAgentStream)
        .animation(.easeInOut(duration: 0.2), value: showShortcuts)
        .onAppear { installKeyboardMonitor() }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.modifierFlags.contains(.command) else { return event }
            guard let chars = event.charactersIgnoringModifiers, let ch = chars.first else { return event }

            if ch == "0" {
                selectedScreen = nil
                return nil
            }

            if ch == "j" || ch == "J" {
                showAgentStream.toggle()
                return nil
            }

            if ch == "/" {
                showShortcuts.toggle()
                return nil
            }

            // Cmd+N = new thread
            if ch == "n" || ch == "N" {
                NotificationCenter.default.post(name: .newThread, object: nil)
                return nil
            }

            // Cmd+Shift+F = toggle thread search
            if (ch == "f" || ch == "F") && event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(name: .toggleThreadSearch, object: nil)
                return nil
            }

            // Cmd+K = command palette
            if ch == "k" || ch == "K" {
                NotificationCenter.default.post(name: .toggleCommandPalette, object: nil)
                return nil
            }

            // Cmd+Shift+S = toggle sidebar
            if (ch == "s" || ch == "S") && event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(name: .toggleSidebar, object: nil)
                return nil
            }

            // Cmd+Shift+; = copy last response
            if ch == ";" && event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(name: .copyLastResponse, object: nil)
                return nil
            }

            // Cmd+O = thinking transcript
            if ch == "o" || ch == "O" {
                NotificationCenter.default.post(name: .showThinkingTranscript, object: nil)
                return nil
            }

            // Cmd+[ = previous thread, Cmd+] = next thread
            if ch == "[" {
                NotificationCenter.default.post(name: .prevThread, object: nil)
                return nil
            }
            if ch == "]" {
                NotificationCenter.default.post(name: .nextThread, object: nil)
                return nil
            }

            // Cmd+F = search within thread
            if (ch == "f" || ch == "F") && !event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(name: .searchInThread, object: nil)
                return nil
            }

            // Cmd+W = close/delete thread (handled in ChatScreen)
            if ch == "w" || ch == "W" {
                // Let ChatScreen handle this via notification
                return event
            }

            if let digit = ch.wholeNumberValue, digit >= 1, digit <= 9 {
                let idx = digit - 1
                if idx < Self.keyboardScreens.count {
                    selectedScreen = Self.keyboardScreens[idx]
                    return nil
                }
            }

            return event
        }
    }
}
