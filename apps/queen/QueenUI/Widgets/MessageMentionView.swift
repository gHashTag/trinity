import SwiftUI

// MARK: - Message Mention View

struct MessageMentionView: View {
    let message: ChatMessage
    let onMentionTap: (String) -> Void

    var body: some View {
        MentionHighlighter(text: message.text, onMentionTap: onMentionTap)
    }
}

// MARK: - Mention Highlighter

struct MentionHighlighter: View {
    let text: String
    let onMentionTap: (String) -> Void

    var body: some View {
        Text(parseMentions())
    }

    private func parseMentions() -> AttributedString {
        var attributed = AttributedString(text)

        // Find and highlight @mentions
        if let range = text.range(of: "@") {
            let afterAt = text[range.upperBound...]
            if let endRange = afterAt.range(of: " ", options: .literal) {
                let mentionRange = range.lowerBound..<endRange.lowerBound
                let mentionString = String(text[mentionRange])

                if let attributedRange = attributed.range(of: mentionString) {
                    attributed[attributedRange].foregroundColor = V4Color.golden
                    attributed[attributedRange].backgroundColor = V4Color.golden.opacity(V2Depth.bgSidebarHover)
                    attributed[attributedRange].font = .system(size: 14, weight: .semibold)
                }
            } else {
                // Mention goes to end of string
                let mentionRange = range.lowerBound..<text.endIndex
                let mentionString = String(text[mentionRange])

                if let attributedRange = attributed.range(of: mentionString) {
                    attributed[attributedRange].foregroundColor = V4Color.golden
                    attributed[attributedRange].backgroundColor = V4Color.golden.opacity(V2Depth.bgSidebarHover)
                    attributed[attributedRange].font = .system(size: 14, weight: .semibold)
                }
            }
        }

        return attributed
    }
}

// MARK: - Mention Autocomplete

struct MentionAutocomplete: View {
    @Binding var text: String
    let onSelect: (String) -> Void

    @State private var suggestions: [MentionUser] = []
    @State private var selectedIndex: Int = 0
    @State private var showAutocomplete: Bool = false
    @State private var triggerPosition: Int = 0

    @FocusState private var isFocused: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Text editor
            TextEditor(text: $text)
                .focused($isFocused)
                .scrollContentBackground(.hidden)
                .background(V4Color.surface)
                .onChange(of: text) { _, newValue in
                    handleTextChange(newValue)
                }

            // Autocomplete popup
            if showAutocomplete && !suggestions.isEmpty {
                MentionSuggestionsPopup(
                    suggestions: suggestions,
                    selectedIndex: selectedIndex,
                    onSelect: selectMention,
                    onDismiss: { showAutocomplete = false }
                )
                .offset(y: 30)
                .padding(.leading, 4)
            }
        }
    }

    private func handleTextChange(_ newValue: String) {
        guard isFocused else {
            showAutocomplete = false
            return
        }

        // Find @ trigger position
        if let range = newValue.range(of: "@", options: .backwards) {
            let afterTrigger = newValue[range.upperBound...]
            let query = String(afterTrigger).components(separatedBy: " ").first ?? ""

            if !query.isEmpty {
                triggerPosition = newValue.distance(from: newValue.startIndex, to: range.lowerBound)
                filterSuggestions(query)
                showAutocomplete = true
                return
            }
        }

        showAutocomplete = false
    }

    private func filterSuggestions(_ query: String) {
        let filtered = MentionStore.shared.allUsers.filter { user in
            user.username.localizedCaseInsensitiveContains(query) ||
            user.displayName.localizedCaseInsensitiveContains(query)
        }
        suggestions = filtered
        selectedIndex = 0
    }

    private func selectMention(_ user: MentionUser) {
        let mention = "@\(user.username)"
        let beforeMention = String(text.prefix(triggerPosition))
        var afterMention = String(text.dropFirst(triggerPosition))

        // Remove the partial query
        if let spaceIndex = afterMention.firstIndex(of: " ") {
            afterMention = String(afterMention[spaceIndex...])
        } else {
            afterMention = ""
        }

        text = beforeMention + mention + " " + afterMention
        showAutocomplete = false
        onSelect(user.username)
    }
}

// MARK: - Mention Suggestions Popup

struct MentionSuggestionsPopup: View {
    let suggestions: [MentionUser]
    let selectedIndex: Int
    let onSelect: (MentionUser) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, user in
                MentionSuggestionRow(
                    user: user,
                    isSelected: index == selectedIndex
                )
                .onTapGesture {
                    onSelect(user)
                }
            }
        }
        .frame(maxWidth: 250, maxHeight: 200)
        .background(V4Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .cornerRadius(V1Theme.cornerMedium)
        .shadow(color: .black.opacity(V2Depth.stateHover), radius: 15)
    }
}

// MARK: - Mention Suggestion Row

struct MentionSuggestionRow: View {
    let user: MentionUser
    let isSelected: Bool

    var body: some View {
        HStack(spacing: ParietalSpacing.sm + 2) {
            // Avatar
            Circle()
                .fill(avatarColor)
                .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)
                .overlay(
                    Text(String(user.displayName.prefix(1)).uppercased())
                        .font(WernickeTypography.body14Semibold)
                        .foregroundStyle(.white)
                )

            // Name and username
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(WernickeTypography.smallMedium)
                    .foregroundStyle(V4Color.textPrimary)

                Text("@\(user.username)")
                    .font(WernickeTypography.size11)
                    .foregroundStyle(V4Color.textSecondary)
            }

            Spacer()

            // Status indicator
            Circle()
                .fill(statusColor)
                .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm)
        .background(isSelected ? V4Color.accent.opacity(0.2) : Color.clear)
    }

    private var avatarColor: Color {
        let colors: [Color] = [.purple, .blue, .green, .orange, .pink]
        let index = abs(user.username.hashValue) % colors.count
        return colors[index]
    }

    private var statusColor: Color {
        switch user.onlineStatus {
        case .online: return .green
        case .away: return .yellow
        case .offline: return V4Color.textSecondary
        }
    }
}

// MARK: - Mention User Model

struct MentionUser: Identifiable, Equatable, Codable {
    let id: UUID
    let username: String
    let displayName: String
    var onlineStatus: OnlineStatus = .offline

    enum OnlineStatus: String, Codable {
        case online
        case away
        case offline
    }
}

// MARK: - Mention Store

@MainActor
class MentionStore: ObservableObject {
    static let shared = MentionStore()

    @Published var allUsers: [MentionUser] = []
    @Published var recentUsers: [MentionUser] = []

    private let recentKey = "recentMentions"

    init() {
        loadRecent()
        loadDefaultUsers()
    }

    private func loadDefaultUsers() {
        allUsers = [
            MentionUser(id: UUID(), username: "trinity", displayName: "Trinity AI", onlineStatus: .online),
            MentionUser(id: UUID(), username: "assistant", displayName: "Assistant", onlineStatus: .online),
            MentionUser(id: UUID(), username: "user", displayName: "You", onlineStatus: .online),
            MentionUser(id: UUID(), username: "fpga", displayName: "FPGA Expert", onlineStatus: .away),
            MentionUser(id: UUID(), username: "compiler", displayName: "Zig Compiler", onlineStatus: .offline),
        ]
    }

    private func loadRecent() {
        if let data = UserDefaults.standard.data(forKey: recentKey),
           let decoded = try? JSONDecoder().decode([MentionUser].self, from: data) {
            recentUsers = Array(decoded.prefix(10))
        }
    }

    private func saveRecent() {
        if let encoded = try? JSONEncoder().encode(recentUsers) {
            UserDefaults.standard.set(encoded, forKey: recentKey)
        }
    }

    func addToRecent(_ user: MentionUser) {
        recentUsers = [user] + recentUsers.filter { $0.id != user.id }
        recentUsers = Array(recentUsers.prefix(10))
        saveRecent()
    }
}

// MARK: - Preview

struct MessageMentionView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
            // Mention highlighter
            MentionHighlighter(
                text: "Hey @trinity, can you help with this? Also cc @assistant",
                onMentionTap: { print("Tapped: \($0)") }
            )
            .padding()
            .background(V4Color.surface)

            // Suggestion rows
            VStack(spacing: ParietalSpacing.xs) {
                MentionSuggestionRow(
                    user: MentionUser(
                        id: UUID(),
                        username: "trinity",
                        displayName: "Trinity AI",
                        onlineStatus: .online
                    ),
                    isSelected: true
                )
                MentionSuggestionRow(
                    user: MentionUser(
                        id: UUID(),
                        username: "fpga",
                        displayName: "FPGA Expert",
                        onlineStatus: .away
                    ),
                    isSelected: false
                )
            }
            .padding()
            .background(V4Color.surface)
        }
        .padding()
        .background(V4Color.background)
    }
}
