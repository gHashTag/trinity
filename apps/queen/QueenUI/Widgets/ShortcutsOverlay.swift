import SwiftUI

struct ShortcutsOverlay: View {
    @Binding var isPresented: Bool

    private let sections: [(String, [(String, String)])] = [
        ("Navigation", [
            ("⌘0", "Main Menu"),
            ("⌘1-9", "Jump to Screen"),
            ("⌘J", "Agent Stream"),
            ("⌘/", "Shortcuts"),
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
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                HStack {
                    Text("Keyboard Shortcuts")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)
                    Spacer()
                    Button { isPresented = false } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.bottom, 20)

                ForEach(sections, id: \.0) { sectionName, shortcuts in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(sectionName)
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(TrinityTheme.textMuted)
                            .padding(.top, 8)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(shortcuts, id: \.0) { key, desc in
                                HStack(spacing: 10) {
                                    Text(key)
                                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                                        .foregroundStyle(TrinityTheme.golden)
                                        .frame(width: 70, alignment: .trailing)
                                    Text(desc)
                                        .font(.system(size: 13))
                                        .foregroundStyle(TrinityTheme.textPrimary)
                                    Spacer()
                                }
                                .padding(.vertical, 2)
                            }
                        }
                    }
                }
            }
            .padding(32)
            .frame(width: 560)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(Color(hex: 0x1A1A1A))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(TrinityTheme.accent.opacity(0.3), lineWidth: 1)
                    )
            )
        }
    }
}
