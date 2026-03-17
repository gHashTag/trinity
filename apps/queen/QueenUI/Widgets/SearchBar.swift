// Search Bar — Enhanced Search with Filters, History, Suggestions
import SwiftUI

// MARK: - Search Bar

struct SearchBar: View {
    @Binding var text: String
    let placeholder: String
    let showsSuggestions: Bool
    let suggestions: [String]
    let onSearch: () -> Void
    let onClear: () -> Void

    @State private var isFocused = false
    @State private var showSuggestions = false
    @FocusState private var focus: Bool

    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        showsSuggestions: Bool = false,
        suggestions: [String] = [],
        onSearch: @escaping () -> Void = {},
        onClear: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.showsSuggestions = showsSuggestions
        self.suggestions = suggestions
        self.onSearch = onSearch
        self.onClear = onClear
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textMuted)

                TextField(placeholder, text: $text)
                    .focused($focus)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        onSearch()
                        showSuggestions = false
                    }
                    .onChange(of: text) { _, newValue in
                        showSuggestions = showsSuggestions && !newValue.isEmpty
                    }
                    .onChange(of: focus) { _, newValue in
                        isFocused = newValue
                        if !newValue {
                            showSuggestions = false
                        }
                    }

                if !text.isEmpty {
                    Button {
                        text = ""
                        onClear()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerMedium)
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .stroke(isFocused ? TrinityTheme.accent : TrinityTheme.bgCardBorder, lineWidth: 1)
            )

            // Suggestions dropdown
            if showSuggestions && !suggestions.isEmpty {
                suggestionsList
            }
        }
    }

    private var suggestionsList: some View {
        VStack(spacing: 0) {
            ForEach(filteredSuggestions, id: \.self) { suggestion in
                Button {
                    text = suggestion
                    showSuggestions = false
                    onSearch()
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(TrinityTheme.textMuted)
                            .frame(width: 16)

                        Text(suggestion)
                            .font(.system(size: 13))
                            .foregroundStyle(TrinityTheme.textPrimary)

                        Spacer()

                        Image(systemName: "arrow.turn.down.left")
                            .font(.system(size: 10))
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if suggestion != filteredSuggestions.last {
                    Divider()
                        .background(TrinityTheme.bgCardBorder)
                }
            }
        }
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.1), radius: 8, y: 4)
        .padding(.top, 4)
    }

    private var filteredSuggestions: [String] {
        if text.isEmpty {
            return suggestions
        }
        return suggestions.filter { $0.localizedCaseInsensitiveContains(text) }
    }
}

// MARK: - Search Field with Filter

struct SearchFieldWithFilter: View {
    @Binding var text: String
    let placeholder: String
    let filterOptions: [String]
    @Binding var selectedFilter: String

    var body: some View {
        HStack(spacing: 8) {
            // Filter dropdown
            Menu {
                ForEach(filterOptions, id: \.self) { option in
                    Button {
                        selectedFilter = option
                    } label: {
                        HStack {
                            Text(option)
                            if selectedFilter == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Text(selectedFilter)
                        .font(.system(size: 13))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 10, weight: .semibold))
                }
                .foregroundStyle(TrinityTheme.textPrimary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(TrinityTheme.bgCardBorder)
                .cornerRadius(6)
            }
            .menuStyle(.borderlessButton)

            // Search input
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 13))
                    .foregroundStyle(TrinityTheme.textMuted)

                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(TrinityTheme.bgCard)
            .cornerRadius(6)
        }
    }
}

// MARK: - Inline Search

struct InlineSearch: View {
    @Binding var text: String
    let placeholder: String
    let isEditing: Binding<Bool>?

    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        isEditing: Binding<Bool>? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.isEditing = isEditing
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(TrinityTheme.textMuted)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(.system(size: 11))

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(TrinityTheme.bgCardBorder.opacity(0.5))
        .cornerRadius(4)
    }
}

// MARK: - Search History

struct SearchHistory: View {
    let history: [String]
    let onSelect: (String) -> Void
    let onClear: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Recent Searches")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textMuted)

                Spacer()

                Button {
                    onClear()
                } label: {
                    Text("Clear")
                        .font(.system(size: 10))
                }
                .buttonStyle(.plain)
            }

            SearchFlowLayout(spacing: 6) {
                ForEach(history, id: \.self) { item in
                    Button {
                        onSelect(item)
                    } label: {
                        Text(item)
                            .font(.system(size: 11))
                            .foregroundStyle(TrinityTheme.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(TrinityTheme.bgCardBorder)
                            .cornerRadius(4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
    }
}

// MARK: - Flow Layout (for tags)

struct SearchFlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 6) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: rows.reduce(0) { $0 + $1.height + spacing })
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for (item, size) in row.items {
                subviews[item].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }

            y += row.height + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentItems: [(Int, CGSize)] = []
        var currentX: CGFloat = 0
        var currentHeight: CGFloat = 0

        let maxWidth = proposal.width ?? 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && !currentItems.isEmpty {
                rows.append(Row(items: currentItems, height: currentHeight))
                currentItems = []
                currentX = 0
                currentHeight = 0
            }

            currentItems.append((index, size))
            currentX += size.width + spacing
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, height: currentHeight))
        }

        return rows
    }

    struct Row {
        let items: [(Int, CGSize)]
        let height: CGFloat
    }
}

// MARK: - Preview

struct SearchBar_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            SearchBar(
                text: .constant("query"),
                placeholder: "Search...",
                showsSuggestions: true,
                suggestions: ["Recent item 1", "Recent item 2", "Recent item 3", "Suggestion 4"]
            )
            .frame(width: 300)
            .padding()
            .background(TrinityTheme.bgWindow)

            SearchFieldWithFilter(
                text: .constant(""),
                placeholder: "Search...",
                filterOptions: ["All", "Title", "Content", "Author"],
                selectedFilter: .constant("All")
            )
            .frame(width: 400)
            .padding()
            .background(TrinityTheme.bgWindow)
        }
    }
}
