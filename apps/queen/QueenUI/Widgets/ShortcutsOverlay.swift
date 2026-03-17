import SwiftUI

struct ShortcutsOverlay: View {
    @Binding var isPresented: Bool

    private let sections: [(String, [(String, String)])] = [
        ("Navigation", [
            ("⌘0", "Main Menu"),
            ("⌘1-9", "Switch Screen"),
            ("⌘J", "Agent Stream"),
            ("⌘/", "Shortcuts"),
            ("Esc", "Back"),
        ]),
        ("Chat", [
            ("⌘N", "New Thread"),
            ("⌘K", "Command Palette"),
            ("⌘⇧F", "Search Threads"),
            ("⌘⇧S", "Toggle Sidebar"),
            ("⌘⇧;", "Copy Last Response"),
            ("Enter", "Send Message"),
            ("⇧Enter", "New Line"),
            ("@file:", "Attach File"),
            ("@grep:", "Search Code"),
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
