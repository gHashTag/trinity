import SwiftUI

// MARK: - Message Reaction Picker

struct MessageReactionPicker: View {
    let messageID: UUID
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    @State private var searchText: String = ""
    @State private var recentEmojis: [String] = []

    private let presetEmojis = ["👍", "❤️", "🎉", "🚀", "💡", "🤔", "🔥", "✅"]
    private let allEmojis = [
        "😀", "😂", "🥰", "😎", "🤔", "😅", "🙏", "👍",
        "❤️", "🔥", "✨", "💯", "🚀", "💡", "🎯", "⭐",
        "👀", "👌", "✅", "❌", "⚠️", "💪", "🤝", "🎉"
    ]

    var filteredEmojis: [String] {
        if searchText.isEmpty {
            return allEmojis
        }
        return allEmojis.filter { emoji in
            emojiName(emoji).localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Add Reaction")
                    .font(.headline)
                    .foregroundStyle(V4Color.textPrimary)

                Spacer()

                Button { onDismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()
                .background(V4Color.border)

            // Search
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(V4Color.textSecondary)

                TextField("Search emojis", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.vertical, ParietalSpacing.sm)

            // Recent emojis
            if !recentEmojis.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ParietalSpacing.sm) {
                        ForEach(recentEmojis, id: \.self) { emoji in
                            emojiButton(emoji)
                        }
                    }
                    .padding(.horizontal)
                }

                Divider()
                    .background(V4Color.border)
            }

            // Emoji grid
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 50))], spacing: ParietalSpacing.md) {
                    ForEach(filteredEmojis, id: \.self) { emoji in
                        emojiButton(emoji)
                    }
                }
                .padding()
            }
        }
        .frame(width: ParietalSpacing.panelWidth, height: 350)
        .background(V4Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .cornerRadius(V1Theme.cornerMedium)
        .shadow(color: .black.opacity(V2Depth.stateHover), radius: 20)
        .onAppear {
            loadRecentEmojis()
        }
    }

    private func emojiButton(_ emoji: String) -> some View {
        Button {
            onSelect(emoji)
            saveRecentEmoji(emoji)
        } label: {
            Text(emoji)
                .font(WernickeTypography.size28)
                .frame(width: ParietalSpacing.mediumFrame, height: ParietalSpacing.mediumFrame)
                .background(
                    Circle()
                        .fill(V4Color.surface.opacity(V2Depth.stateDisabled))
                )
                .scaleEffect(1.0)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            // Scale effect could be added here
        }
    }

    private func emojiName(_ emoji: String) -> String {
        // Simple mapping for search
        let names: [String: String] = [
            "👍": "thumbs up",
            "❤️": "love heart",
            "🎉": "party celebration",
            "🚀": "rocket",
            "💡": "idea lightbulb",
            "🤔": "thinking",
            "🔥": "fire hot",
            "✅": "check done"
        ]
        return names[emoji] ?? ""
    }

    private func loadRecentEmojis() {
        if let data = UserDefaults.standard.data(forKey: "recentEmojis"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            recentEmojis = Array(decoded.prefix(8))
        }
    }

    private func saveRecentEmoji(_ emoji: String) {
        recentEmojis = [emoji] + recentEmojis.filter { $0 != emoji }
        recentEmojis = Array(recentEmojis.prefix(8))
        if let encoded = try? JSONEncoder().encode(recentEmojis) {
            UserDefaults.standard.set(encoded, forKey: "recentEmojis")
        }
    }
}

// MARK: - Reaction Badge

struct ReactionBadge: View {
    let reactions: [Reaction]
    let onTap: () -> Void

    var body: some View {
        if reactions.isEmpty {
            emptyReactButton
        } else {
            populatedBadge
        }
    }

    private var emptyReactButton: some View {
        Button(action: onTap) {
            Image(systemName: "hand.tap")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateDisabled))
                .frame(width: ParietalSpacing.icon + 4, height: ParietalSpacing.icon + 4)
        }
        .buttonStyle(.plain)
    }

    private var populatedBadge: some View {
        HStack(spacing: ParietalSpacing.xs) {
            ForEach(reactions.prefix(3), id: \.emoji) { reaction in
                HStack(spacing: 2) {
                    Text(reaction.emoji)
                        .font(.caption2)
                    Text("\(reaction.count)")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .padding(.horizontal, ParietalSpacing.xs + 2)
                .padding(.vertical, 3)
                .background(
                    SwiftUI.Capsule()
                        .fill(V4Color.surface.opacity(V2Depth.stateDisabled))
                )
            }

            if reactions.count > 3 {
                Text("+\(reactions.count - 3)")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .onTapGesture(perform: onTap)
    }
}

// MARK: - Reaction Model

struct Reaction: Identifiable, Equatable, Codable {
    let id: UUID
    let emoji: String
    var count: Int
    var users: [String]

    init(emoji: String, user: String) {
        self.id = UUID()
        self.emoji = emoji
        self.count = 1
        self.users = [user]
    }
}

// MARK: - Preview

struct MessageReactionPicker_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            ReactionBadge(
                reactions: [
                    Reaction(emoji: "👍", user: "user1"),
                    Reaction(emoji: "❤️", user: "user2")
                ],
                onTap: {}
            )

            MessageReactionPicker(
                messageID: UUID(),
                onSelect: { _ in },
                onDismiss: {}
            )
        }
        .background(V4Color.background)
    }
}
