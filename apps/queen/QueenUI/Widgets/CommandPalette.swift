import SwiftUI

/// Cmd+K Command Palette — Spotlight/Raycast-style quick actions.
/// Fuzzy search over commands, threads, files, and models.
struct CommandPalette: View {
    @Binding var isPresented: Bool
    @ObservedObject var store: ThreadStore
    @ObservedObject var modelManager: ModelManager
    var onAction: (PaletteAction) -> Void

    @State private var query = ""
    @State private var selectedIndex = 0
    @FocusState private var isFocused: Bool

    enum PaletteAction {
        case switchThread(UUID)
        case newThread
        case switchModel(AIModel)
        case switchMode(ChatMode)
        case exportThread
        case toggleSearch
        case runCommand(String)  // arbitrary prompt
    }

    private var filteredItems: [PaletteItem] {
        let q = query.lowercased()
        var items: [PaletteItem] = []

        // Commands (always shown)
        let commands: [(String, String, PaletteAction)] = [
            ("square.and.pencil", "New Thread", .newThread),
            ("square.and.arrow.up", "Export Thread", .exportThread),
            ("magnifyingglass", "Search Threads", .toggleSearch),
        ]

        for (icon, label, action) in commands {
            if q.isEmpty || label.lowercased().contains(q) {
                items.append(PaletteItem(icon: icon, title: label, subtitle: "Command", action: action))
            }
        }

        // Slash commands
        for cmd in SlashCommand.allCases {
            if q.isEmpty || cmd.rawValue.lowercased().contains(q) || cmd.description.lowercased().contains(q) {
                items.append(PaletteItem(
                    icon: cmd.icon,
                    title: cmd.rawValue,
                    subtitle: cmd.description,
                    action: .runCommand(cmd.rawValue)
                ))
            }
        }

        // Chat modes
        for mode in ChatMode.allCases {
            if q.isEmpty || mode.rawValue.lowercased().contains(q) {
                items.append(PaletteItem(
                    icon: mode.icon,
                    title: "Mode: \(mode.rawValue)",
                    subtitle: "Switch chat mode",
                    action: .switchMode(mode)
                ))
            }
        }

        // Models
        for model in modelManager.availableModels {
            if q.isEmpty || model.displayName.lowercased().contains(q) || model.provider.rawValue.lowercased().contains(q) {
                items.append(PaletteItem(
                    icon: "cpu",
                    title: model.displayName,
                    subtitle: model.provider.rawValue,
                    action: .switchModel(model)
                ))
            }
        }

        // Recent threads (title match)
        for thread in store.sortedThreads.prefix(q.isEmpty ? 5 : 20) {
            if q.isEmpty || thread.title.lowercased().contains(q) {
                items.append(PaletteItem(
                    icon: thread.isPinned ? "pin.fill" : "bubble.left",
                    title: thread.title,
                    subtitle: "\(thread.messages.count) msgs",
                    action: .switchThread(thread.id)
                ))
            }
        }

        // Message content search (only when query is non-empty, search across all threads)
        if q.count >= 3 {
            let contentMatches = store.search(q)
            for match in contentMatches.prefix(5) {
                // Skip if thread already in results from title match
                if items.contains(where: {
                    if case .switchThread(let id) = $0.action { return id == match.thread.id }
                    return false
                }) { continue }
                let snippet = String(match.message.text.prefix(60))
                items.append(PaletteItem(
                    icon: "text.magnifyingglass",
                    title: match.thread.title,
                    subtitle: snippet,
                    action: .switchThread(match.thread.id)
                ))
            }
        }

        // If query looks like a prompt, offer to run it
        if !q.isEmpty && q.count > 5 {
            items.append(PaletteItem(
                icon: "paperplane",
                title: "Ask: \(query)",
                subtitle: "Send as message",
                action: .runCommand(query)
            ))
        }

        return items
    }

    struct PaletteItem: Identifiable {
        let icon: String
        let title: String
        let subtitle: String
        let action: PaletteAction
        var id: String { "\(icon)-\(title)" }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Backdrop
            Color.black.opacity(0.5)
                .ignoresSafeArea()
                .onTapGesture { isPresented = false }

            Spacer()

            // Palette card
            VStack(spacing: 0) {
                // Search input
                HStack(spacing: 10) {
                    Image(systemName: "command")
                        .font(.system(size: 14))
                        .foregroundStyle(TrinityTheme.accent)

                    TextField("Type a command...", text: $query)
                        .textFieldStyle(.plain)
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white)
                        .focused($isFocused)
                        .onSubmit { executeSelected() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.1))

                // Results list
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(Array(filteredItems.prefix(15).enumerated()), id: \.element.id) { idx, item in
                            paletteRow(item, isSelected: idx == selectedIndex)
                                .onTapGesture {
                                    onAction(item.action)
                                    isPresented = false
                                }
                        }
                    }
                }
                .frame(maxHeight: 300)

                // Footer
                HStack(spacing: 16) {
                    keyHint("↑↓", "Navigate")
                    keyHint("↵", "Select")
                    keyHint("esc", "Close")
                    Spacer()
                    Text("\(filteredItems.count) results")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.2))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.02))
            }
            .frame(width: 500)
            .background(Color(hex: 0x1A1A1A))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.5), radius: 30)
            .padding(.bottom, 100)

            Spacer()
        }
        .onAppear {
            isFocused = true
            selectedIndex = 0
        }
        .onChange(of: query) { _, _ in selectedIndex = 0 }
        .onKeyPress(.upArrow) {
            if selectedIndex > 0 { selectedIndex -= 1 }
            return .handled
        }
        .onKeyPress(.downArrow) {
            let max = min(filteredItems.count, 15) - 1
            if selectedIndex < max { selectedIndex += 1 }
            return .handled
        }
        .onKeyPress(.escape) {
            isPresented = false
            return .handled
        }
        .onKeyPress(.return) {
            executeSelected()
            return .handled
        }
    }

    private func paletteRow(_ item: PaletteItem, isSelected: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: item.icon)
                .font(.system(size: 13))
                .foregroundStyle(isSelected ? TrinityTheme.accent : Color.white.opacity(0.4))
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 1) {
                Text(item.title)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.7))
                    .lineLimit(1)
                Text(item.subtitle)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.3))
            }

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? TrinityTheme.accent.opacity(0.1) : Color.clear)
    }

    private func keyHint(_ key: String, _ label: String) -> some View {
        HStack(spacing: 4) {
            Text(key)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.4))
                .padding(.horizontal, 4)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 3))
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(Color.white.opacity(0.2))
        }
    }

    private func executeSelected() {
        let items = filteredItems
        guard selectedIndex < items.count else { return }
        onAction(items[selectedIndex].action)
        isPresented = false
    }
}
