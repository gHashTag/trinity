import SwiftUI

// MARK: - Message Search View

struct MessageSearchView: View {
    let messages: [ChatMessage]
    let onResultSelect: (ChatMessage) -> Void

    @State private var searchText = ""
    @State private var searchScope: SearchScope = .all
    @State private var filteredResults: [MessageSearchResult] = []
    @State private var isSearching = false
    @State private var selectedIndex = 0

    enum SearchScope: String, CaseIterable {
        case all = "All"
        case fromUser = "From You"
        case fromTrinity = "From Trinity"
        case bookmarks = "Bookmarks"
        case recent = "Recent"
    }

    var body: some View {
        VStack(spacing: 0) {
            searchHeader
            scopePicker
            resultsList
        }
        .frame(height: 400)
        .background(TrinityTheme.bgWindow)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
        .cornerRadius(TrinityTheme.cornerMedium)
        .onChange(of: searchText) { _, newValue in
            performSearch(query: newValue)
        }
        .onChange(of: searchScope) { _, _ in
            performSearch(query: searchText)
        }
    }

    private var searchHeader: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(TrinityTheme.textMuted)

            TextField("Search messages...", text: $searchText)
                .textFieldStyle(.plain)
                .font(.system(size: 14))
                .onSubmit {
                    if !filteredResults.isEmpty {
                        onResultSelect(filteredResults[selectedIndex].message)
                    }
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    filteredResults = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }

            if isSearching {
                ProgressView()
                    .scaleEffect(0.8)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(TrinityTheme.bgCard)
    }

    private var scopePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(SearchScope.allCases, id: \.self) { scope in
                    scopeButton(scope)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
        }
        .background(TrinityTheme.bgCard.opacity(0.5))
    }

    private func scopeButton(_ scope: SearchScope) -> some View {
        Button {
            withAnimation {
                searchScope = scope
            }
        } label: {
            Text(scope.rawValue)
                .font(.caption)
                .foregroundStyle(searchScope == scope ? TrinityTheme.bgWindow : TrinityTheme.textMuted)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    SwiftUI.Capsule()
                        .fill(searchScope == scope ? TrinityTheme.accent : TrinityTheme.bgCard)
                )
        }
        .buttonStyle(.plain)
    }

    private var resultsList: some View {
        Group {
            if searchText.isEmpty && filteredResults.isEmpty {
                emptyState
            } else if filteredResults.isEmpty {
                noResultsState
            } else {
                resultsContent
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(TrinityTheme.textMuted.opacity(0.5))

            Text("Search Messages")
                .font(.headline)
                .foregroundStyle(TrinityTheme.textPrimary)

            Text("Type to search across all conversations")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: 12) {
            Image(systemName: "exclamationmark.magnifyingglass")
                .font(.system(size: 40))
                .foregroundStyle(TrinityTheme.textMuted.opacity(0.5))

            Text("No Results")
                .font(.headline)
                .foregroundStyle(TrinityTheme.textPrimary)

            Text("No messages match \"\(searchText)\"")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var resultsContent: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(filteredResults.enumerated()), id: \.element.id) { index, result in
                    resultRow(result, index: index)
                        .onTapGesture {
                            selectedIndex = index
                            onResultSelect(result.message)
                        }
                }
            }
        }
    }

    private func resultRow(_ result: MessageSearchResult, index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar
            Circle()
                .fill(result.message.role == .assistant ? TrinityTheme.accent : TrinityTheme.purple)
                .frame(width: 28, height: 28)
                .overlay(
                    Image(systemName: result.message.role == .assistant ? "triangle.fill" : "person.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                )

            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 8) {
                    Text(result.message.role == .assistant ? "Trinity" : "You")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(TrinityTheme.textPrimary)

                    Text(formatDate(result.message.timestamp))
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)

                    Spacer()

                    if result.highlightRanges.count > 0 {
                        Text("\(result.highlightRanges.count) matches")
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.accent)
                    }
                }

                // Content with highlights
                highlightedText(result)
                    .font(.caption)
                    .lineLimit(3)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(selectedIndex == index ? TrinityTheme.accent.opacity(0.1) : Color.clear)
        .overlay(
            Rectangle()
                .fill(selectedIndex == index ? TrinityTheme.accent : Color.clear)
                .frame(width: 3),
            alignment: .leading
        )
    }

    private func highlightedText(_ result: MessageSearchResult) -> some View {
        Text(attributedHighlight(result))
    }

    private func attributedHighlight(_ result: MessageSearchResult) -> AttributedString {
        var attributed = AttributedString(String(result.message.text.prefix(150)))

        for range in result.highlightRanges {
            // Convert NSRange to AttributedString range
            let startStr = attributed.characters.index(attributed.characters.startIndex, offsetBy: min(range.location, attributed.characters.count))
            let endStr = attributed.characters.index(attributed.characters.startIndex, offsetBy: min(range.location + range.length, attributed.characters.count))

            if startStr < attributed.characters.endIndex && endStr <= attributed.characters.endIndex {
                attributed[startStr..<endStr].backgroundColor = TrinityTheme.accent.opacity(0.3)
                attributed[startStr..<endStr].foregroundColor = TrinityTheme.textPrimary
            }
        }

        return attributed
    }

    // MARK: - Search Logic

    private func performSearch(query: String) {
        guard !query.isEmpty else {
            filteredResults = []
            return
        }

        isSearching = true

        // Simulate async search
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            let results = messages.compactMap { message -> MessageSearchResult? in
                guard matchesScope(message) else { return nil }

                let ranges = findMatches(query: query, in: message.text)
                guard !ranges.isEmpty else { return nil }

                return MessageSearchResult(message: message, highlightRanges: ranges, score: ranges.count)
            }
            .sorted { $0.score > $1.score }

            filteredResults = Array(results.prefix(50))
            isSearching = false
        }
    }

    private func matchesScope(_ message: ChatMessage) -> Bool {
        switch searchScope {
        case .all:
            return true
        case .fromUser:
            return message.role == .user
        case .fromTrinity:
            return message.role == .assistant
        case .bookmarks:
            return message.isBookmarked == true
        case .recent:
            let oneWeekAgo = Date().addingTimeInterval(-7 * 24 * 60 * 60)
            return message.timestamp > oneWeekAgo
        }
    }

    private func findMatches(query: String, in text: String) -> [NSRange] {
        var ranges: [NSRange] = []
        let nsString = text as NSString
        var searchRange = NSRange(location: 0, length: nsString.length)

        while searchRange.location < nsString.length {
            let range = nsString.range(of: query, options: .caseInsensitive, range: searchRange)
            if range.location == NSNotFound {
                break
            }
            ranges.append(range)
            searchRange = NSRange(location: range.location + range.length, length: nsString.length - (range.location + range.length))
            if ranges.count > 100 {
                break
            }
        }

        return ranges
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Search Result Model

struct MessageSearchResult: Identifiable {
    let id = UUID()
    let message: ChatMessage
    let highlightRanges: [NSRange]
    let score: Int
}

// MARK: - Compact Search Bar

struct MessageSearchBar: View {
    let messages: [ChatMessage]
    let onResultSelect: (ChatMessage) -> Void

    @State private var showSearch = false
    @State private var searchText = ""

    var body: some View {
        HStack {
            if showSearch {
                MessageSearchView(
                    messages: messages,
                    onResultSelect: { message in
                        onResultSelect(message)
                        showSearch = false
                    }
                )
            } else {
                Button {
                    showSearch = true
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                        Text("Search...")
                    }
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                            .fill(TrinityTheme.bgCard)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.easeInOut, value: showSearch)
    }
}

// MARK: - Search Suggestions

struct SearchSuggestions: View {
    let recentQueries: [String]
    let onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Recent Searches")
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)
                .padding(.horizontal, 12)
                .padding(.top, 8)

            ForEach(recentQueries, id: \.self) { query in
                Button {
                    onSelect(query)
                } label: {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.textMuted)

                        Text(query)
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

// MARK: - Preview

struct MessageSearchView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            MessageSearchView(
                messages: sampleMessages,
                onResultSelect: { _ in }
            )
            .frame(height: 400)

            MessageSearchBar(
                messages: sampleMessages,
                onResultSelect: { _ in }
            )
            .padding()
        }
        .background(TrinityTheme.bgWindow)
    }
}

private let sampleMessages = [
    ChatMessage(role: .assistant, text: "The TMU pipeline uses ternary weights for efficient inference."),
    ChatMessage(role: .user, text: "How does the BRAM utilization work?"),
    ChatMessage(role: .assistant, text: "Wide BRAM allows K=32 with distributed RAM organization."),
]
