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
                Color.black.opacity(V1Theme.opacityTextTertiary)
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
        .animation(reduceMotion ? .none : MTMotion.standardSpring, value: isSearching)
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
            HStack(spacing: ParietalSpacing.md) {
                // Search icon
                Image(systemName: "magnifyingglass")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textSecondary)

                // Text field
                TextField("Search messages...", text: $localQuery)
                    .textFieldStyle(.plain)
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textPrimary)
                    .focused($isSearchFocused)
                    .onSubmit {
                        navigateToNext()
                    }

                // Match count badge
                Text(matchCountDisplay)
                    .font(WernickeTypography.caption2MediumMono)
                    .foregroundStyle(matchCountForeground)
                    .padding(.horizontal, ParietalSpacing.sm)
                    .padding(.vertical, ParietalSpacing.xs)
                    .background(matchCountBackground)
                    .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))

                // Close button
                Button {
                    dismissSearch()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size16)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close search")
            }
            .padding(.horizontal, ParietalSpacing.lg)
            .padding(.vertical, ParietalSpacing.md)
            .background(V4Color.surface)
            .overlay(
                Rectangle()
                    .fill(V4Color.accent.opacity(isSearchFocused ? 1 : 0))
                    .frame(height: 2),
                alignment: .bottom
            )

            Divider()
                .background(V4Color.border)

            // Navigation controls
            HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                // Previous match
                Button {
                    navigateToPrevious()
                } label: {
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        Image(systemName: "chevron.up")
                        Text("Previous")
                    }
                    .font(WernickeTypography.size12)
                    .foregroundStyle(canNavigatePrevious ? V4Color.textPrimary : V4Color.textSecondary)
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
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        Text("Next")
                        Image(systemName: "chevron.down")
                    }
                    .font(WernickeTypography.size12)
                    .foregroundStyle(canNavigateNext ? V4Color.textPrimary : V4Color.textSecondary)
                }
                .buttonStyle(.plain)
                .disabled(!canNavigateNext)
                .accessibilityLabel("Next match")
                .accessibilityHint("Navigate to next search result")
            }
            .padding(.horizontal, ParietalSpacing.lg)
            .padding(.vertical, ParietalSpacing.sm)
            .background(V4Color.surface.opacity(V2Depth.stateDisabled))

            Divider()
                .background(V4Color.border)

            // Results list
            if matchingMessages.isEmpty && !localQuery.isEmpty {
                emptyState
            } else if matchingMessages.isEmpty {
                recentSearchesPlaceholder
            } else {
                resultsList
            }

            // Keyboard shortcuts footer
            HStack(spacing: ParietalSpacing.lg) {
                keyboardHint("↑", "Previous")
                keyboardHint("↓", "Next")
                keyboardHint("⎋", "Close")
                Spacer()
            }
            .padding(.horizontal, ParietalSpacing.lg)
            .padding(.vertical, ParietalSpacing.xs + 2)
            .background(V4Color.surface.opacity(V2Depth.stateHover))
            .font(WernickeTypography.size10)
            .foregroundStyle(V4Color.textSecondary)
        }
        .background(V4Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .shadow(color: .black.opacity(V1Theme.shadowLargeOpacity), radius: V1Theme.shadowLargeRadius)
        .padding(.horizontal, ParietalSpacing.md + ParietalSpacing.md)
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
        VStack(spacing: ParietalSpacing.md) {
            Image(systemName: "questionmark.circle")
                .font(WernickeTypography.size32)
                .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateDisabled))

            Text("No matches found")
                .font(WernickeTypography.body14Medium)
                .foregroundStyle(V4Color.textSecondary)

            Text("Try a different search term")
                .font(WernickeTypography.size12)
                .foregroundStyle(V4Color.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, ParietalSpacing.xxl)
        .accessibilityLabel("No search results found")
    }

    private var recentSearchesPlaceholder: some View {
        VStack(spacing: ParietalSpacing.md) {
            Image(systemName: "magnifyingglass")
                .font(WernickeTypography.size28)
                .foregroundStyle(V4Color.accent.opacity(V2Depth.stateDisabled))

            Text("Search in conversation")
                .font(WernickeTypography.body14Medium)
                .foregroundStyle(V4Color.textSecondary)

            Text("Type to search all messages in this thread")
                .font(WernickeTypography.size12)
                .foregroundStyle(V4Color.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.vertical, ParietalSpacing.xxl)
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

        return HStack(alignment: .top, spacing: ParietalSpacing.md) {
            // Role icon
            Image(systemName: message.role == .user ? "person.circle.fill" : "cpu")
                .font(WernickeTypography.size14)
                .foregroundStyle(isSelected ? V4Color.accent : V4Color.textSecondary)
                .frame(width: ParietalSpacing.buttonSmallWidth)

            // Content
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                // Message header
                HStack(spacing: ParietalSpacing.sm) {
                    Text(message.role == .user ? "You" : (message.modelID ?? "Assistant"))
                        .font(WernickeTypography.caption2Semibold)
                        .foregroundStyle(isSelected ? V4Color.textPrimary : V4Color.textSecondary)

                    Text(timestampString(for: message.timestamp))
                        .font(WernickeTypography.size10)
                        .foregroundStyle(V4Color.textSecondary.opacity(V1Theme.opacityTextSecondary))
                }

                // Highlighted preview
                highlightedText(previewText, query: localQuery)
                    .font(WernickeTypography.size13)
                    .lineLimit(2)
                    .foregroundStyle(isSelected ? V4Color.textPrimary : V4Color.textSecondary)
            }

            Spacer()
        }
        .padding(.horizontal, ParietalSpacing.lg)
        .padding(.vertical, ParietalSpacing.sm + 2)
        .background(isSelected ? V4Color.accent.opacity(V2Depth.bgSubtle) : Color.clear)
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
                .foregroundStyle(V4Color.accent)
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
        HStack(spacing: ParietalSpacing.xs) {
            Text(keys)
                .font(WernickeTypography.microBoldMono)
                .foregroundStyle(V4Color.textSecondary.opacity(V1Theme.opacityTextSecondary))
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(V4Color.border)
                .clipShape(RoundedRectangle(cornerRadius: 4))
            Text(label)
                .font(WernickeTypography.size9)
                .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateDisabled))
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
            return V4Color.textSecondary
        }
        return V4Color.accent
    }

    private var matchCountBackground: Color {
        if matchingMessages.isEmpty {
            return V4Color.border
        }
        return V4Color.accent.opacity(V2Depth.bgSidebarHover)
    }
}

// MARK: - Array Safe Subscript Extension

private extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
    }
}
