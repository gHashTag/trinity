import SwiftUI

/// Full-text search overlay for message history within the current thread.
/// Features: real-time filtering, term highlighting, keyboard navigation, match count.
struct SearchableMessageHistory: View {
    // MARK: - Bindings

    /// Search query text
    @Binding var searchText: String

    /// Whether search UI is visible
    @Binding var isSearching: Bool

    /// All messages in the current thread
    let messages: [ChatMessage]

    /// Callback when a match is selected (navigate to message)
    var onSelectMatch: (ChatMessage) -> Void = { _ in }

    // MARK: - State

    @State private var selectedMatchIndex: Int = 0
    @State private var localQuery: String = ""
    @FocusState private var isSearchFocused: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // MARK: - Computed Properties

    /// All messages matching the current search query
    private var matchingMessages: [ChatMessage] {
        guard !localQuery.isEmpty else { return [] }
        let query = localQuery.lowercased()
        return messages.filter { message in
            message.text.lowercased().contains(query)
        }
    }

    /// Current match count display (e.g., "3/12")
    private var matchCountDisplay: String {
        let total = matchingMessages.count
        guard total > 0 else { return "0 matches" }
        return "\(selectedMatchIndex + 1)/\(total)"
    }

    /// Highlighted ranges for a given text
    private func highlightedRanges(in text: String, query: String) -> [Range<String.Index>] {
        guard !query.isEmpty else { return [] }
        var ranges: [Range<String.Index>] = []
        var searchStartIndex = text.startIndex

        while searchStartIndex < text.endIndex {
            let searchRange = searchStartIndex..<text.endIndex
            if let range = text.range(of: query, options: [.caseInsensitive], range: searchRange) {
                ranges.append(range)
                searchStartIndex = range.upperBound
            } else {
                break
            }
        }
        return ranges
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Dim backdrop
            if isSearching {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .transition(.opacity)
                    .onTapGesture {
                        dismissSearch()
                    }
            }

            if isSearching {
                searchSheet
                    .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? .none : TrinityTheme.springAnimation(), value: isSearching)
        .onChange(of: searchText) { _, newValue in
            localQuery = newValue
        }
        .onChange(of: localQuery) { _, _ in
            // Reset selection when query changes
            selectedMatchIndex = 0
            searchText = localQuery
            // Auto-select first match
            if let first = matchingMessages.first {
                onSelectMatch(first)
            }
        }
        .onAppear {
            localQuery = searchText
        }
    }

    // MARK: - Search Sheet

    private var searchSheet: some View {
        VStack(spacing: 0) {
            // Search bar header
            HStack(spacing: 12) {
                // Search icon
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textMuted)

                // Text field
                TextField("Search messages...", text: $localQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .focused($isSearchFocused)
                    .onSubmit {
                        navigateToNext()
                    }

                // Match count badge
                Text(matchCountDisplay)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(matchCountForeground)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(matchCountBackground)
                    .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall))

                // Close button
                Button {
                    dismissSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close search")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(TrinityTheme.bgCard)
            .overlay(
                Rectangle()
                    .fill(TrinityTheme.accent.opacity(isSearchFocused ? 1 : 0))
                    .frame(height: 2),
                alignment: .bottom
            )

            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Navigation controls
            HStack(spacing: 20) {
                // Previous match
                Button {
                    navigateToPrevious()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.up")
                        Text("Previous")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(canNavigatePrevious ? TrinityTheme.textPrimary : TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(!canNavigatePrevious)
                .accessibilityLabel("Previous match")
                .accessibilityHint("Navigate to previous search result, use up arrow key")

                Spacer()

                // Next match
                Button {
                    navigateToNext()
                } label: {
                    HStack(spacing: 6) {
                        Text("Next")
                        Image(systemName: "chevron.down")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(canNavigateNext ? TrinityTheme.textPrimary : TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
                .disabled(!canNavigateNext)
                .accessibilityLabel("Next match")
                .accessibilityHint("Navigate to next search result")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(TrinityTheme.bgCard.opacity(0.5))

            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Results list
            if matchingMessages.isEmpty && !localQuery.isEmpty {
                emptyState
            } else if matchingMessages.isEmpty {
                recentSearchesPlaceholder
            } else {
                resultsList
            }

            // Keyboard shortcuts footer
            HStack(spacing: 16) {
                keyboardHint("↑", "Previous")
                keyboardHint("↓", "Next")
                keyboardHint("⎋", "Close")
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(TrinityTheme.bgCard.opacity(0.3))
            .font(.system(size: 10))
            .foregroundStyle(TrinityTheme.textMuted)
        }
        .background(TrinityTheme.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerLarge)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerLarge))
        .shadow(color: .black.opacity(TrinityTheme.shadowLargeOpacity), radius: TrinityTheme.shadowLargeRadius)
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .frame(maxHeight: 400)
        .onAppear {
            isSearchFocused = true
        }
        .onKeyPress(.escape) {
            dismissSearch()
            return .handled
        }
        .onKeyPress(.upArrow) {
            navigateToPrevious()
            return .handled
        }
        .onKeyPress(.downArrow) {
            navigateToNext()
            return .handled
        }
        .onKeyPress(.return) {
            navigateToNext()
            return .handled
        }
    }

    // MARK: - Subviews

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 32))
                .foregroundStyle(TrinityTheme.textMuted.opacity(0.5))

            Text("No matches found")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TrinityTheme.textMuted)

            Text("Try a different search term")
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.textMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
        .accessibilityLabel("No search results found")
    }

    private var recentSearchesPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 28))
                .foregroundStyle(TrinityTheme.accent.opacity(0.5))

            Text("Search in conversation")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(TrinityTheme.textMuted)

            Text("Type to search all messages in this thread")
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.textMuted.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, 40)
        .accessibilityLabel("Enter search query to find messages")
    }

    private var resultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(matchingMessages.enumerated()), id: \.element.id) { index, message in
                    resultRow(message: message, index: index)
                        .onTapGesture {
                            selectedMatchIndex = index
                            onSelectMatch(message)
                        }
                }
            }
        }
        .frame(maxHeight: 280)
    }

    private func resultRow(message: ChatMessage, index: Int) -> some View {
        let isSelected = index == selectedMatchIndex
        let previewText = messageTextPreview(message.text)

        return HStack(alignment: .top, spacing: 12) {
            // Role icon
            Image(systemName: message.role == .user ? "person.circle.fill" : "cpu")
                .font(.system(size: 14))
                .foregroundStyle(isSelected ? TrinityTheme.accent : TrinityTheme.textMuted)
                .frame(width: 20)

            // Content
            VStack(alignment: .leading, spacing: 4) {
                // Message header
                HStack(spacing: 8) {
                    Text(message.role == .user ? "You" : (message.modelID ?? "Assistant"))
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isSelected ? TrinityTheme.textPrimary : TrinityTheme.textMuted)

                    Text(timestampString(for: message.timestamp))
                        .font(.system(size: 10))
                        .foregroundStyle(TrinityTheme.textMuted.opacity(0.6))
                }

                // Highlighted preview
                highlightedText(previewText, query: localQuery)
                    .font(.system(size: 13))
                    .lineLimit(2)
                    .foregroundStyle(isSelected ? TrinityTheme.textPrimary : TrinityTheme.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(isSelected ? TrinityTheme.accent.opacity(0.1) : Color.clear)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Message \(index + 1) of \(matchingMessages.count)")
        .accessibilityHint(previewText)
        .accessibilityAddTraits(isSelected ? [.isSelected] : [])
    }

    // MARK: - Helper Views

    private func highlightedText(_ text: String, query: String) -> some View {
        guard !query.isEmpty else {
            return AnyView(Text(text))
        }

        let ranges = highlightedRanges(in: text, query: query)
        guard !ranges.isEmpty else {
            return AnyView(Text(text))
        }

        var result: Text = Text("")
        var lastIndex = text.startIndex

        for range in ranges {
            // Text before highlight
            if lastIndex < range.lowerBound {
                result = result + Text(String(text[lastIndex..<range.lowerBound]))
            }
            // Highlighted text
            result = result + Text(String(text[range]))
                .foregroundStyle(TrinityTheme.accent)
                .fontWeight(.semibold)
            lastIndex = range.upperBound
        }

        // Remaining text
        if lastIndex < text.endIndex {
            result = result + Text(String(text[lastIndex..<text.endIndex]))
        }

        return AnyView(result)
    }

    private func keyboardHint(_ keys: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(keys)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(TrinityTheme.textMuted.opacity(0.6))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(TrinityTheme.bgCardBorder)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(TrinityTheme.textMuted.opacity(0.5))
        }
    }

    // MARK: - Navigation

    private var canNavigatePrevious: Bool {
        selectedMatchIndex > 0
    }

    private var canNavigateNext: Bool {
        selectedMatchIndex < matchingMessages.count - 1
    }

    private func navigateToPrevious() {
        guard canNavigatePrevious else { return }
        selectedMatchIndex -= 1
        if let message = matchingMessages[safe: selectedMatchIndex] {
            onSelectMatch(message)
        }
    }

    private func navigateToNext() {
        guard canNavigateNext else { return }
        selectedMatchIndex += 1
        if let message = matchingMessages[safe: selectedMatchIndex] {
            onSelectMatch(message)
        }
    }

    private func dismissSearch() {
        withAnimation {
            isSearching = false
            searchText = ""
            localQuery = ""
            selectedMatchIndex = 0
        }
    }

    // MARK: - Helper Functions

    private func messageTextPreview(_ text: String) -> String {
        // Strip markdown for cleaner preview
        let stripped = text
            .replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "`(.+?)`", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "```[\\s\\S]*?```", with: "[code]", options: .regularExpression)
            .replacingOccurrences(of: "\\n", with: " ", options: .regularExpression)

        return String(stripped.prefix(120))
    }

    private func timestampString(for date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    // MARK: - Style Helpers

    private var matchCountForeground: Color {
        if matchingMessages.isEmpty {
            return TrinityTheme.textMuted
        }
        return TrinityTheme.accent
    }

    private var matchCountBackground: Color {
        if matchingMessages.isEmpty {
            return TrinityTheme.bgCardBorder
        }
        return TrinityTheme.accent.opacity(0.15)
    }
}

// MARK: - Array Safe Subscript Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
