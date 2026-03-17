import SwiftUI

struct ShortcutsOverlay: View {
    @Binding var isPresented: Bool

    private let shortcuts: [(String, String)] = [
        ("⌘0", "Main Menu"),
        ("⌘1", "Chat"),
        ("⌘2", "SEVO Farm"),
        ("⌘3", "Arena LLM"),
        ("⌘4", "Faculty"),
        ("⌘5", "Oracle"),
        ("⌘6", "Build"),
        ("⌘7", "Deploy"),
        ("⌘8", "Telegram"),
        ("⌘9", "Settings"),
        ("⌘J", "Agent Stream"),
        ("⌘/", "Shortcuts"),
        ("Esc", "Back"),
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.7)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            VStack(spacing: 0) {
                HStack {
                    Text("⌨️ Keyboard Shortcuts")
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

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    ForEach(shortcuts, id: \.0) { key, desc in
                        HStack(spacing: 12) {
                            Text(key)
                                .font(.system(size: 14, weight: .bold, design: .monospaced))
                                .foregroundStyle(TrinityTheme.golden)
                                .frame(width: 50, alignment: .trailing)
                            Text(desc)
                                .font(.system(size: 14))
                                .foregroundStyle(TrinityTheme.textPrimary)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .padding(32)
            .frame(width: 500)
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
