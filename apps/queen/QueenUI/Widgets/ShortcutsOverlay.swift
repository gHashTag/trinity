import SwiftUI

struct ShortcutsOverlay: View {
    @Binding var isPresented: Bool
    @AppStorage("hasSeenShortcuts") private var hasSeenShortcuts = false
    var isFirstLaunch: Bool = false

    private let sections: [(String, [(String, String)])] = [
        ("Navigation", [
            ("⌘0", "Main Menu"),
            ("⌘1-9", "Jump to Screen"),
            ("⌘J", "Agent Stream"),
            ("⌘/", "Focus Input"),
            ("⌘[", "Previous Thread"),
            ("⌘]", "Next Thread"),
            ("⌘⇧S", "Toggle Sidebar"),
            ("⌘⇧F", "Search Threads"),
            ("⌘F", "Search in Thread"),
            ("Esc", "Stop / Close / Clear"),
        ]),
        ("Chat", [
            ("⌘N", "New Thread"),
            ("⌘K", "Command Palette"),
            ("⌘⌥K", "Clear Chat"),
            ("⌘O", "Thinking Transcript"),
            ("⌘⇧C", "Copy Last Response"),
            ("⌘E", "Export to Clipboard"),
            ("↑", "Recall Last Message"),
            ("Enter", "Send Message"),
            ("⇧Enter", "New Line"),
        ]),
        ("Slash Commands", [
            ("/effort", "Set effort level"),
            ("/model", "Switch model"),
            ("/compact", "Compress context"),
            ("/fast", "Fast mode (Haiku)"),
            ("/cost", "Session cost"),
            ("/branch", "Git branch"),
            ("/help", "All commands"),
        ]),
        ("Mentions", [
            ("@file:", "Attach file content"),
            ("@grep:", "Search codebase"),
            ("@build", "Last build output"),
            ("@farm", "Farm status"),
            ("@issues", "Open issues"),
            ("@gitdiff", "HEAD diff"),
        ]),
    ]

    var body: some View {
        ZStack {
            backgroundLayer
            contentLayer
        }
    }

    private var backgroundLayer: some View {
        V2Depth.black70
            .ignoresSafeArea()
            .onTapGesture { dismissOverlay() }
    }

    private var contentLayer: some View {
        VStack(spacing: 0) {
            headerSection
            shortcutsList
            footerSection
        }
        .padding(32)
        .frame(width: 560)
        .background(cardBackground)
    }

    private var headerSection: some View {
        VStack(spacing: 0) {
            if isFirstLaunch {
                welcomeText
                    .padding(.bottom, 16)
            }
            titleRow
                .padding(.bottom, 20)
        }
    }

    private var welcomeText: some View {
        VStack(spacing: ParietalSpacing.xs) {
            Text("Welcome to Queen!")
                .font(.title2.weight(.bold))
                .foregroundStyle(V4Color.golden)
            Text("Here are your shortcuts:")
                .font(.subheadline)
                .foregroundStyle(V4Color.textSecondary)
        }
    }

    private var titleRow: some View {
        HStack {
            if !isFirstLaunch {
                Text("Keyboard Shortcuts")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(V4Color.accent)
            }
            Spacer()
            closeButton
        }
    }

    private var closeButton: some View {
        Button { dismissOverlay() } label: {
            Image(systemName: "xmark.circle.fill")
                .font(.title2)
                .foregroundStyle(V4Color.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var shortcutsList: some View {
        ForEach(sections, id: \.0) { sectionName, shortcuts in
            shortcutSection(name: sectionName, shortcuts: shortcuts)
        }
    }

    private func shortcutSection(name: String, shortcuts: [(String, String)]) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text(name)
                .font(WernickeTypography.captionBold)
                .foregroundStyle(V4Color.textSecondary)
                .padding(.top, 8)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.sm) {
                ForEach(shortcuts, id: \.0) { key, desc in
                    shortcutRow(key: key, desc: desc)
                }
            }
        }
    }

    private func shortcutRow(key: String, desc: String) -> some View {
        HStack(spacing: ParietalSpacing.sm + 2) {
            Text(key)
                .font(WernickeTypography.microBoldMono)
                .foregroundStyle(V4Color.golden)
                .frame(width: 70, alignment: .trailing)
            Text(desc)
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textPrimary)
            Spacer()
        }
        .padding(.vertical, 2)
    }

    private var footerSection: some View {
        Group {
            if isFirstLaunch {
                gotItButton
                    .padding(.top, 20)
            }
        }
    }

    private var gotItButton: some View {
        Button {
            dismissOverlay()
        } label: {
            Text("Got it!")
                .font(.body.weight(.semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, ParietalSpacing.xl + ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm + 2)
                .background(V4Color.golden)
                .clipShape(SwiftUI.Capsule())
        }
        .buttonStyle(.plain)
    }

    private var cardBackground: some View {
        RoundedRectangle(cornerRadius: 16)
            .fill(V4Color.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(V4Color.accent.opacity(V2Depth.stateHover), lineWidth: 1)
            )
    }

    private func dismissOverlay() {
        if isFirstLaunch {
            hasSeenShortcuts = true
        }
        isPresented = false
    }
}
