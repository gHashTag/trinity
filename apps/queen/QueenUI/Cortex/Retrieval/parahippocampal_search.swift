//
// Parahippocampal Gyrus — Memory-Based Search
// Search component with suggestions
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Parahippocampal Search

/// Parahippocampal Gyrus — Memory-Based Search
///
/// The parahippocampal gyrus is involved in memory retrieval and search.
/// This component provides an enhanced search with suggestions and history.
///
/// Features:
/// - Search input with icon
/// - Recent searches
/// - Search suggestions
/// - Keyboard shortcuts
public struct ParahippocampalSearch: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let suggestions: [String]
    let recentSearches: [String]
    let onSelectSuggestion: (String) -> Void
    let onClearHistory: () -> Void

    @State private var showSuggestions = false
    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSubmit: @escaping () -> Void = {},
        suggestions: [String] = [],
        recentSearches: [String] = [],
        onSelectSuggestion: @escaping (String) -> Void = { _ in },
        onClearHistory: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.suggestions = suggestions
        self.recentSearches = recentSearches
        self.onSelectSuggestion = onSelectSuggestion
        self.onClearHistory = onClearHistory
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Search input
            inputView

            // Suggestions dropdown
            if showSuggestions && isFocused && (!text.isEmpty || !recentSearches.isEmpty) {
                suggestionsView
            }
        }
    }

    @ViewBuilder
    private var inputView: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textSecondary)
                .frame(width: ParietalSpacing.icon)

            TextField("", text: $text)
                .focused($isFocused)
                .font(WernickeTypography.body)
                .foregroundStyle(V4Color.textPrimary)
                .onChange(of: text) { _, _ in
                    showSuggestions = true
                }
                .onChange(of: isFocused) { _, focused in
                    showSuggestions = focused
                }
                .onSubmit {
                    onSubmit()
                    showSuggestions = false
                }
                .accessibilityLabel(placeholder)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size14)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(V4Color.input)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isFocused ? V4Color.borderFocus : V4Color.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private var suggestionsView: some View {
        VStack(spacing: 0) {
            if !recentSearches.isEmpty && text.isEmpty {
                recentSearchesSection
            }

            if !text.isEmpty {
                suggestionsSection
            }
        }
        .background(V4Color.surfaceElevated)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .shadow(radius: V1Theme.shadowMediumRadius)
        .padding(.top, 4)
    }

    @ViewBuilder
    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("Recent")
                    .font(WernickeTypography.caption)
                    .foregroundStyle(V4Color.textSecondary)

                Spacer()

                Button {
                    onClearHistory()
                } label: {
                    Text("Clear")
                        .font(WernickeTypography.caption)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)

            Divider()

            ForEach(recentSearches, id: \.self) { search in
                suggestionRow(search)
            }
        }
    }

    @ViewBuilder
    private var suggestionsSection: some View {
        let filtered = suggestions.filter { $0.localizedCaseInsensitiveContains(text) }

        if !filtered.isEmpty {
            ForEach(filtered, id: \.self) { suggestion in
                suggestionRow(suggestion)
            }
        } else {
            Text("No results found")
                .font(WernickeTypography.body)
                .foregroundStyle(V4Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.md)
        }
    }

    @ViewBuilder
    private func suggestionRow(_ text: String) -> some View {
        Button {
            onSelectSuggestion(text)
            self.text = text
            showSuggestions = false
            isFocused = false
        } label: {
            HStack(spacing: ParietalSpacing.xs) {
                Image(systemName: "clock.arrow.circlepath")
                    .font(WernickeTypography.caption)
                    .foregroundStyle(V4Color.textTertiary)

                Text(text)
                    .font(WernickeTypography.body)
                    .foregroundStyle(V4Color.textPrimary)
                    .lineLimit(1)

                Spacer()
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
            .background(V4Color.hover)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Inline Search Bar

/// Compact inline search bar
public struct ParahippocampalInlineSearch: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSubmit: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(WernickeTypography.small)
                .foregroundStyle(V4Color.textSecondary)

            TextField("", text: $text)
                .focused($isFocused)
                .font(WernickeTypography.small)
                .foregroundStyle(V4Color.textPrimary)
                .onSubmit(onSubmit)
                .accessibilityLabel(placeholder)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.caption)
                        .foregroundStyle(V4Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ParietalSpacing.xs)
        .padding(.vertical, 6)
        .background(V4Color.input)
        .cornerRadius(V1Theme.cornerSmall)
    }
}

// MARK: - Command Palette Style Search

/// Full-width command palette style search
public struct ParahippocampalCommandPalette: View {
    @Binding var text: String
    let placeholder: String
    let commands: [Command]
    let onSelect: (Command) -> Void
    let onCancel: () -> Void

    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    public struct Command: Identifiable {
        public let id: String
        let title: String
        let subtitle: String?
        let icon: String?
        let shortcut: String?
        let action: () -> Void

        public init(
            id: String,
            title: String,
            subtitle: String? = nil,
            icon: String? = nil,
            shortcut: String? = nil,
            action: @escaping () -> Void
        ) {
            self.id = id
            self.title = title
            self.subtitle = subtitle
            self.icon = icon
            self.shortcut = shortcut
            self.action = action
        }
    }

    public init(
        text: Binding<String>,
        placeholder: String = "Type a command...",
        commands: [Command] = [],
        onSelect: @escaping (Command) -> Void = { _ in },
        onCancel: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.commands = commands
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Search input
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: "magnifyingglass")
                    .font(WernickeTypography.body16)
                    .foregroundStyle(V4Color.textSecondary)

                TextField("", text: $text)
                    .focused($isFocused)
                    .font(WernickeTypography.body)
                    .foregroundStyle(V4Color.textPrimary)
                    .onSubmit {
                        if let first = filteredCommands.first {
                            onSelect(first)
                        }
                    }
                    .accessibilityLabel(placeholder)

                if !text.isEmpty {
                    Button {
                        text = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(WernickeTypography.body16)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    onCancel()
                } label: {
                    Text("ESC")
                        .font(WernickeTypography.caption)
                        .foregroundStyle(V4Color.textTertiary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm)

            Divider()

            // Command list
            if !filteredCommands.isEmpty {
                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(filteredCommands.enumerated()), id: \.element.id) { index, command in
                            commandRow(command, isSelected: index == selectedIndex)
                                .onTapGesture {
                                    onSelect(command)
                                }
                        }
                    }
                }
                .frame(maxHeight: 300)
            } else {
                VStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: "exclamationmark.magnifyingglass")
                        .font(WernickeTypography.size32)
                        .foregroundStyle(V4Color.textTertiary)

                    Text("No commands found")
                        .font(WernickeTypography.body)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .frame(maxHeight: 200)
                .frame(maxWidth: .infinity)
            }
        }
        .background(V4Color.surfaceElevated)
        .cornerRadius(V1Theme.cornerLarge)
        .shadow(radius: ParietalSpacing.xl)
        .onAppear {
            isFocused = true
        }
    }

    private var filteredCommands: [Command] {
        guard !text.isEmpty else { return commands }
        return commands.filter {
            $0.title.localizedCaseInsensitiveContains(text) ||
            $0.subtitle?.localizedCaseInsensitiveContains(text) == true
        }
    }

    @ViewBuilder
    private func commandRow(_ command: Command, isSelected: Bool) -> some View {
        HStack(spacing: ParietalSpacing.sm) {
            if let icon = command.icon {
                Image(systemName: icon)
                    .font(WernickeTypography.body16)
                    .foregroundStyle(V4Color.accent)
                    .frame(width: ParietalSpacing.iconLarge)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(command.title)
                    .font(WernickeTypography.body)

                if let subtitle = command.subtitle {
                    Text(subtitle)
                        .font(WernickeTypography.caption)
                }
            }

            Spacer()

            if let shortcut = command.shortcut {
                Text(shortcut)
                    .font(WernickeTypography.caption)
                    .foregroundStyle(V4Color.textTertiary)
                    .padding(.horizontal, ParietalSpacing.xxxs)
                    .padding(.vertical, 2)
                    .background(V4Color.border)
                    .cornerRadius(V1Theme.cornerTiny)
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm)
        .background(isSelected ? V4Color.selected : Color.clear)
        .contentShape(Rectangle())
    }
}

// MARK: - Preview
// NOTE: Preview blocks removed for CLI build compatibility
