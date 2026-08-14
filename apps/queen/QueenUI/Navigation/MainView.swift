import SwiftUI

public struct MainView: View {
    @EnvironmentObject var watcher: StateWatcher
    @StateObject private var navigationState = QueenNavigationState()
    @State private var keyMonitor: Any?
    @State private var showAgentStream = false
    @State private var showShortcuts = false
    @State private var isFirstLaunchShortcuts = false
    @AppStorage("hasSeenShortcuts") private var hasSeenShortcuts = false
    private let hostedRoutesByPetal: [Int: QueenHostedRoute]
    private let surfaceStyle: QueenSurfaceStyle

    public init(
        hostedRoutes: [QueenHostedRoute] = [],
        surfaceStyle: QueenSurfaceStyle = .canonical
    ) {
        hostedRoutesByPetal = Dictionary(
            uniqueKeysWithValues: hostedRoutes.map { ($0.petalIndex, $0) }
        )
        self.surfaceStyle = surfaceStyle
    }

    public var body: some View {
        ZStack(alignment: .trailing) {
            rootBackground

            if let petal = navigationState.selectedHostedPetal,
               let route = hostedRoutesByPetal[petal] {
                VStack(spacing: 0) {
                    navigationHeader(
                        title: route.title,
                        systemImage: route.systemImage
                    )
                    route.content
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.opacity)
            } else if let screen = navigationState.selectedScreen {
                // Screen content with back button
                VStack(spacing: 0) {
                    navigationHeader(
                        title: screen.rawValue,
                        emoji: screen.icon,
                        showsRefresh: true
                    )

                    ScreenRouter(screen: screen)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .transition(.opacity)
            } else {
                // 27-petal logo as main menu
                TriangleLogo(
                    selectedScreen: $navigationState.selectedScreen,
                    hostedRoutes: hostedRoutesByPetal,
                    onSelect: selectPetal
                )
            }

            // Agent Stream overlay (Cmd+J)
            if showAgentStream {
                AgentStreamView()
                    .environmentObject(watcher)
                    .frame(
                        minWidth: LayoutConstants.agentStreamMinWidth,
                        idealWidth: LayoutConstants.agentStreamIdealWidth,
                        maxWidth: LayoutConstants.agentStreamMaxWidth
                    )
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .background(V4Color.sidebar.opacity(0.95))
                    .transition(.move(edge: .trailing))
            }

            // Shortcuts overlay (Cmd+/)
            if showShortcuts {
                ShortcutsOverlay(isPresented: $showShortcuts, isFirstLaunch: isFirstLaunchShortcuts)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.25), value: navigationState.selectedScreen)
        .animation(.easeInOut(duration: 0.25), value: navigationState.selectedHostedPetal)
        .animation(.easeInOut(duration: 0.25), value: showAgentStream)
        .animation(.easeInOut(duration: 0.2), value: showShortcuts)
        .onAppear {
            installKeyboardMonitor()
            if !hasSeenShortcuts {
                isFirstLaunchShortcuts = true
                showShortcuts = true
            }
        }
        .onDisappear {
            if let monitor = keyMonitor {
                NSEvent.removeMonitor(monitor)
                keyMonitor = nil
            }
        }
        .onReceive(
            NotificationCenter.default.publisher(for: QueenHostNavigation.request)
        ) { notification in
            guard let petal = notification.object as? Int else { return }
            if petal < 0 {
                returnToMenu()
            } else {
                selectPetal(petal)
            }
        }
    }

    @ViewBuilder
    private var rootBackground: some View {
        if surfaceStyle.usesTransparentBackground {
            Color.clear
                .ignoresSafeArea()
        } else {
            V4Color.background
                .ignoresSafeArea()
        }
    }

    private func navigationHeader(
        title: String,
        systemImage: String? = nil,
        emoji: String? = nil,
        showsRefresh: Bool = false
    ) -> some View {
        HStack {
            Button(action: returnToMenu) {
                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: "chevron.left")
                    Text("TRINITY")
                        .font(WernickeTypography.captionBold.monospaced())
                }
                .foregroundStyle(V4Color.accent)
                .padding(ParietalSpacing.xs)
            }
            .buttonStyle(.plain)
            .keyboardShortcut(.escape, modifiers: [])

            Spacer()

            HStack(spacing: ParietalSpacing.xs) {
                if let systemImage {
                    Image(systemName: systemImage)
                } else if let emoji {
                    Text(emoji)
                }
                Text(title)
            }
            .font(WernickeTypography.smallBold.monospaced())
            .foregroundStyle(.white)

            Spacer()
            HStack {
                if showsRefresh {
                    Button {
                        NotificationCenter.default.post(
                            name: .queenWorkspaceRefresh,
                            object: "header"
                        )
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(WernickeTypography.captionBold)
                            .foregroundStyle(V4Color.textSecondary)
                            .frame(width: 24, height: 24)
                            .background(V4Color.surfaceElevated)
                            .clipShape(Circle())
                            .overlay {
                                Circle()
                                    .stroke(V4Color.border, lineWidth: 1)
                            }
                    }
                    .buttonStyle(.plain)
                    .help("Refresh workspace")
                }
            }
            .frame(
                width: ParietalSpacing.xLargeFrame,
                alignment: .trailing
            )
        }
        .padding(.horizontal, ParietalSpacing.xs)
        .padding(.vertical, ParietalSpacing.xxs)
        .frame(maxHeight: 32)
        .background(
            surfaceStyle.usesTransparentBackground
                ? V4Color.surface.opacity(0.72)
                : V4Color.surface
        )
    }

    private func returnToMenu() {
        navigationState.selectedHostedPetal = nil
        navigationState.selectedScreen = nil
    }

    private func selectPetal(_ petalIndex: Int) {
        if hostedRoutesByPetal[petalIndex] != nil {
            navigationState.selectedScreen = nil
            navigationState.selectedHostedPetal = petalIndex
            NotificationCenter.default.post(
                name: QueenHostNavigation.didOpen,
                object: petalIndex
            )
        } else {
            navigationState.selectedHostedPetal = nil
            navigationState.selectedScreen = Screen.screenForBlock(petalIndex)
        }
    }

    private func installKeyboardMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let ch = event.charactersIgnoringModifiers?.first

            if let digit = ch?.wholeNumberValue,
               let petalIndex = QueenMenuShortcutPolicy.petalIndex(
                   digit: digit,
                   modifiers: event.modifierFlags,
                   isMainMenuVisible: navigationState.isMainMenuVisible
               ) {
                selectPetal(petalIndex)
                return nil
            }

            // Non-modifier shortcuts: Escape, Up arrow in empty input
            if !event.modifierFlags.contains(.command) {
                // Escape — stop streaming / clear input / close modal
                if event.keyCode == 53 {
                    NotificationCenter.default.post(name: .escapeAction, object: nil)
                    // Don't consume — let .keyboardShortcut(.escape) also work
                    return event
                }
                // Up arrow with no modifiers — navigate history up
                if event.keyCode == 126 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [] {
                    NotificationCenter.default.post(name: .recallLastMessage, object: nil)
                    return event
                }
                // Down arrow with no modifiers — navigate history down
                if event.keyCode == 125 && event.modifierFlags.intersection(.deviceIndependentFlagsMask) == [] {
                    NotificationCenter.default.post(name: .navigateHistoryDown, object: nil)
                    return event
                }
                return event
            }

            guard let ch else { return event }

            if ch == "0" {
                returnToMenu()
                return nil
            }

            if ch == "j" || ch == "J" {
                showAgentStream.toggle()
                return nil
            }

            if ch == "/" {
                isFirstLaunchShortcuts = false
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

            // Cmd+\ = toggle focus mode
            if ch == "\\" {
                NotificationCenter.default.post(name: .toggleFocusMode, object: nil)
                return nil
            }

            // Cmd+Shift+; = copy last response
            if ch == ";" && event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(name: .copyLastResponse, object: nil)
                return nil
            }

            // Cmd+Shift+C = copy last assistant response
            if (ch == "c" || ch == "C") && event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(name: .copyLastResponse, object: nil)
                return nil
            }

            // Cmd+E = export thread as Markdown to clipboard
            if (ch == "e" || ch == "E") && !event.modifierFlags.contains(.shift) {
                NotificationCenter.default.post(name: .exportThreadClipboard, object: nil)
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

            return event
        }
    }
}
