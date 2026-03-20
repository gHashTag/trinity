import SwiftUI

// MARK: - Command History

/// Stores recent commands and their frequency for learning
struct CommandHistory: Codable, Identifiable {
    let id = UUID()
    let command: String      // e.g., "@grep:func ", "@tri:build"
    let prompt: String       // Short label for display
    let timestamp: Date

    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode([self]),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }

    static func fromJSON(_ json: String) -> [CommandHistory] {
        guard let data = json.data(using: .utf8),
              let cmds = try? JSONDecoder().decode([CommandHistory].self, from: data) else {
            return []
        }
        return cmds
    }
}

extension Array where Element == CommandHistory {
    func toJSON() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else {
            return "[]"
        }
        return json
    }
}

/// Manages command history with learning from usage
@MainActor
class CommandHistoryManager: ObservableObject {
    static let shared = CommandHistoryManager()

    @AppStorage("recentCommands") private var recentCommandsRaw: String = "[]"
    @AppStorage("frequentPatterns") private var frequentPatternsRaw: String = "{}"

    private var recentCommandsCache: [CommandHistory] = []
    private var frequentPatternsCache: [String: Int] = [:]

    var recentCommands: [CommandHistory] {
        if recentCommandsCache.isEmpty {
            recentCommandsCache = CommandHistory.fromJSON(recentCommandsRaw)
        }
        return recentCommandsCache
    }

    var frequentPatterns: [String: Int] {
        if frequentPatternsCache.isEmpty {
            guard let data = frequentPatternsRaw.data(using: .utf8),
                  let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Int] else {
                return [:]
            }
            frequentPatternsCache = dict
        }
        return frequentPatternsCache
    }

    /// Record a command execution
    func record(_ command: String, label: String) {
        var cmds = recentCommands
        let newCmd = CommandHistory(command: command, prompt: label, timestamp: Date())

        // Remove duplicates and add to front
        cmds.removeAll { $0.command == newCmd.command }
        cmds.insert(newCmd, at: 0)
        if cmds.count > 20 { cmds = Array(cmds.prefix(20)) }

        // Save
        let json = cmds.toJSON()
        recentCommandsRaw = json
        recentCommandsCache = cmds

        // Update frequency patterns
        var patterns = frequentPatterns
        patterns[command, default: 0] += 1

        if let data = try? JSONSerialization.data(withJSONObject: patterns, options: []),
            let jsonStr = String(data: data, encoding: .utf8) {
            frequentPatternsRaw = jsonStr
            frequentPatternsCache = patterns
        }
    }

    /// Get suggestions based on query
    func suggestions(matching query: String, limit: Int = 5) -> [CommandHistory] {
        let q = query.lowercased()
        return recentCommands
            .filter { $0.command.lowercased().contains(q) || $0.prompt.lowercased().contains(q) }
            .prefix(limit)
            .map { $0 }
    }

    /// Time ago formatter
    func timeAgo(_ date: Date) -> String {
        let secs = Int(-date.timeIntervalSinceNow)
        if secs < 60 { return "just now" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        if secs < 86400 { return "\(secs / 3600)h ago" }
        return "\(secs / 86400)d ago"
    }
}

// MARK: - Proactive Suggestion Bar

/// Horizontal suggestion bar that appears above input area
/// Shows contextual actions based on Trinity state
struct SmartSuggestionBar: View {
    @StateObject private var trinityCtx = TrinityContext.shared
    var onSuggestion: (String) -> Void

    var body: some View {
        let suggestions = buildProactiveSuggestions()
        if suggestions.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    ForEach(suggestions) { suggestion in
                        Button {
                            onSuggestion(suggestion.prompt)
                        } label: {
                            HStack(spacing: 5) {
                                Text(suggestion.icon)
                                    .font(WernickeTypography.size11)
                                Text(suggestion.text)
                                    .font(WernickeTypography.miniMedium)
                                    .foregroundStyle(suggestion.urgent ? Color.black : V4Color.white70)
                            }
                            .padding(.horizontal, ParietalSpacing.sm + 2)
                            .padding(.vertical, 5)
                            .background(suggestion.urgent ? suggestion.color : suggestion.color.opacity(0.12))
                            .clipShape(SwiftUI.Capsule())
                            .overlay(
                                SwiftUI.Capsule()
                                    .stroke(suggestion.color.opacity(V2Depth.stateHover), lineWidth: suggestion.urgent ? 0 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, ParietalSpacing.xs + 2)
            }
        )
    }

    struct ProactiveSuggestion: Identifiable {
        let id = UUID()
        let icon: String
        let text: String
        let prompt: String
        let color: Color
        let urgent: Bool
    }

    private func buildProactiveSuggestions() -> [ProactiveSuggestion] {
        // Refresh if stale
        if trinityCtx.lastRefresh == nil || Date().timeIntervalSince(trinityCtx.lastRefresh!) > 10 {
            trinityCtx.refresh()
        }
        var result: [ProactiveSuggestion] = []

        // Build broken — urgent
        if trinityCtx.buildOK == false {
            result.append(ProactiveSuggestion(
                icon: "\u{1F6A8}",
                text: "Build broken — diagnose?",
                prompt: "The build is broken. Please analyze the errors and suggest a fix.",
                color: V4Color.error,
                urgent: true
            ))
        }

        // Best PPL improved recently
        if let ppl = trinityCtx.bestPPL, let run = trinityCtx.bestRun, ppl < 5.0 {
            result.append(ProactiveSuggestion(
                icon: "\u{1F3C6}",
                text: "\(run) PPL=\(String(format: "%.1f", ppl)) — deploy?",
                prompt: "Run \(run) has PPL=\(String(format: "%.2f", ppl)). Should we deploy this as the production config? What's the risk?",
                color: V4Color.golden,
                urgent: false
            ))
        }

        // Many dirty files
        if let dirty = trinityCtx.dirtyFiles, dirty > 30 {
            result.append(ProactiveSuggestion(
                icon: "\u{1F9F9}",
                text: "\(dirty) dirty files — review?",
                prompt: "There are \(dirty) dirty files in the working tree. Help me review and organize these changes.",
                color: V4Color.warning,
                urgent: false
            ))
        }

        // Stale arena
        if let battles = trinityCtx.arenaBattles, battles == 0 {
            result.append(ProactiveSuggestion(
                icon: "\u{2694}",
                text: "Arena idle — run battle?",
                prompt: "The arena has no recent battles. Let's run a comparison between trinity-hslm and the latest challenger.",
                color: V4Color.purple,
                urgent: false
            ))
        }

        // Many open issues
        if let issues = trinityCtx.openIssues, issues > 20 {
            result.append(ProactiveSuggestion(
                icon: "\u{1F4CB}",
                text: "\(issues) open issues — triage?",
                prompt: "We have \(issues) open issues. Help me prioritize and triage the most important ones.",
                color: V4Color.accent,
                urgent: false
            ))
        }

        // Low score
        if let score = trinityCtx.ouroborosScore, score < 50 {
            result.append(ProactiveSuggestion(
                icon: "\u{1F4C9}",
                text: "Score \(Int(score)) — improve?",
                prompt: "The Ouroboros score is only \(Int(score))/100. What are the top 3 things we should fix to improve it?",
                color: V4Color.error,
                urgent: false
            ))
        }

        return result
    }
}

// MARK: - Smart Suggestion Item

/// Single suggestion item for display in popup
struct SmartSuggestionItem: Identifiable {
    let id = UUID()
    let icon: String
    let label: String
    let value: String           // What to insert/execute
    let detail: String?         // Optional detail text
    let category: SuggestionCategory
    let isRecent: Bool          // Show "recent" badge

    enum SuggestionCategory: String {
        case mention = "mention"
        case command = "command"
        case file = "file"
        case pattern = "pattern"
        case proactive = "proactive"
        case history = "history"
    }
}

// MARK: - Enhanced Mention Popup with Learning

/// Enhanced mention popup with history learning and context awareness
/// Works with existing ChatScreen mention trigger system
struct EnhancedMentionPopup: View {
    let query: String
    @Binding var isPresented: Bool
    var onSelect: (String) -> Void
    var repoContext: RepoContext? = nil
    var trinityContext: TrinityContext? = nil

    @StateObject private var history = CommandHistoryManager.shared
    @State private var selectedIndex = 0

    /// Generate suggestions based on query
    private var suggestions: [SmartSuggestionItem] {
        let q = query.lowercased()
        var items: [SmartSuggestionItem] = []

        // @file: path suggestions
        if q.isEmpty || q.hasPrefix("file") {
            let fileQuery = q.hasPrefix("file:") ? String(q.dropFirst(5)) : q
            if !fileQuery.isEmpty || q.isEmpty {
                let files = repoContext?.fileSuggestions(matching: fileQuery, limit: 5) ?? []
                for file in files {
                    items.append(SmartSuggestionItem(
                        icon: fileIcon(for: file),
                        label: file,
                        value: "file:\(file)",
                        detail: "Attach file content",
                        category: .file,
                        isRecent: false
                    ))
                }
            }
        }

        // @grep: pattern suggestions with history
        if q.isEmpty || q.hasPrefix("grep") {
            let grepQuery = q.hasPrefix("grep:") ? String(q.dropFirst(5)) : q

            // Built-in patterns
            let builtins: [(String, String)] = [
                ("func ", "Function definitions"),
                ("struct ", "Struct definitions"),
                ("class ", "Class definitions"),
                ("TODO", "TODO comments"),
                ("FIXME", "FIXME comments"),
                ("error", "Error declarations"),
                ("test ", "Test declarations"),
                ("import ", "Import statements"),
                ("pub ", "Public declarations"),
                ("const ", "Constants"),
            ]

            for (pattern, desc) in builtins {
                if grepQuery.isEmpty || pattern.lowercased().contains(grepQuery) || desc.lowercased().contains(grepQuery) {
                    items.append(SmartSuggestionItem(
                        icon: "magnifyingglass",
                        label: pattern,
                        value: "grep:\(pattern)",
                        detail: desc,
                        category: .pattern,
                        isRecent: false
                    ))
                }
            }

            // Recent grep patterns from history
            let recentGrep = history.recentCommands
                .filter { $0.command.hasPrefix("@grep:") }
                .filter { h in grepQuery.isEmpty || h.command.lowercased().contains(grepQuery) }
                .prefix(3)

            for h in recentGrep {
                let pattern = String(h.command.dropFirst(6)) // Remove "@grep:"
                items.append(SmartSuggestionItem(
                    icon: "clock.arrow.circlepath",
                    label: pattern,
                    value: "grep:\(pattern)",
                    detail: "Recent \(history.timeAgo(h.timestamp))",
                    category: .pattern,
                    isRecent: true
                ))
            }
        }

        // @tri: command suggestions
        if q.isEmpty || q.hasPrefix("tri") {
            let triCommands = [
                ("build", "Build Trinity binary", "hammer"),
                ("test", "Run tests", "checkmark.circle"),
                ("git status", "Working tree status", "branch"),
                ("issue list", "List GitHub issues", "list.bullet"),
                ("farm status", "Farm status", "chart.bar"),
                ("cloud status", "Cloud services", "cloud"),
                ("doctor", "Health check", "stethoscope"),
                ("pipeline run", "Run pipeline", "arrow.triangle.2.circlepath"),
            ]

            let triQuery = q.hasPrefix("tri:") ? String(q.dropFirst(4)) : q
            for (cmd, desc, icon) in triCommands {
                if triQuery.isEmpty || cmd.lowercased().contains(triQuery) || desc.lowercased().contains(triQuery) {
                    items.append(SmartSuggestionItem(
                        icon: icon,
                        label: cmd,
                        value: "tri:\(cmd)",
                        detail: desc,
                        category: .command,
                        isRecent: false
                    ))
                }
            }
        }

        // Context-aware @ suggestions with live badges
        if q.isEmpty || !q.hasPrefix("file:") && !q.hasPrefix("grep:") && !q.hasPrefix("tri:") {
            items.append(contentsOf: contextMentions(query: q))
        }

        // Sort by category and limit
        return Array(items.prefix(10))
    }

    private func contextMentions(query: String) -> [SmartSuggestionItem] {
        var items: [SmartSuggestionItem] = []

        // @build — with build status badge
        let buildBadge: String? = {
            guard let ctx = trinityContext else { return nil }
            if let ok = ctx.buildOK { return ok ? "PASS" : "FAIL" }
            return nil
        }()
        if query.isEmpty || "build".contains(query) {
            items.append(SmartSuggestionItem(
                icon: "hammer",
                label: "build",
                value: "build",
                detail: buildBadge.map { "Last build: \($0)" } ?? "Last build output",
                category: .mention,
                isRecent: false
            ))
        }

        // @farm — with farm stats
        let farmDetail: String? = {
            guard let ctx = trinityContext else { return nil }
            var parts: [String] = []
            if let n = ctx.farmServices { parts.append("\(n) active") }
            if let ppl = ctx.bestPPL { parts.append("PPL=\(String(format: "%.1f", ppl))") }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        }()
        if query.isEmpty || "farm".contains(query) {
            items.append(SmartSuggestionItem(
                icon: "chart.bar",
                label: "farm",
                value: "farm",
                detail: farmDetail ?? "Farm events snapshot",
                category: .mention,
                isRecent: false
            ))
        }

        // @issues — with issue count
        let issuesDetail: String? = {
            guard let ctx = trinityContext else { return nil }
            if let n = ctx.openIssues { return "\(n) open issues" }
            return nil
        }()
        if query.isEmpty || "issues".contains(query) {
            items.append(SmartSuggestionItem(
                icon: "list.bullet",
                label: "issues",
                value: "issues",
                detail: issuesDetail ?? "Open GitHub issues",
                category: .mention,
                isRecent: false
            ))
        }

        // @gitdiff
        if query.isEmpty || "gitdiff".contains(query) {
            items.append(SmartSuggestionItem(
                icon: "arrow.triangle.branch",
                label: "gitdiff",
                value: "gitdiff",
                detail: "Current HEAD diff",
                category: .mention,
                isRecent: false
            ))
        }

        // @arena
        if query.isEmpty || "arena".contains(query) {
            items.append(SmartSuggestionItem(
                icon: "figure.fencing",
                label: "arena",
                value: "arena",
                detail: "Arena battles & ELO",
                category: .mention,
                isRecent: false
            ))
        }

        return items
    }

    private func fileIcon(for path: String) -> String {
        let ext = (path as NSString).pathExtension.lowercased()
        switch ext {
        case "swift": return "swift"
        case "zig": return "cpu"
        case "md": return "doc.richtext"
        case "json", "toml", "yaml": return "doc.text"
        case "v", "sv": return "waveform.path"
        case "tri": return "doc.plaintext"
        default: return "doc"
        }
    }

    var body: some View {
        let items = suggestions
        if !items.isEmpty {
            popupContent(items: items)
        }
    }

    private func popupContent(items: [SmartSuggestionItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.element.id) { idx, item in
                suggestionRow(for: item, index: idx, total: items.count)
            }
        }
        .frame(width: ParietalSpacing.wideModalFrame)
        .background(V4Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(V2Depth.bgSubtle), lineWidth: 1)
        )
        .shadow(color: .black.opacity(V1Theme.opacityTextTertiary), radius: 12)
        .focusable()
        .onKeyPress(phases: .down) { keyPress in
            if keyPress.key == .upArrow {
                selectedIndex = max(0, selectedIndex - 1)
                return .handled
            } else if keyPress.key == .downArrow {
                selectedIndex = min(items.count - 1, selectedIndex + 1)
                return .handled
            } else if keyPress.key == .return {
                if selectedIndex < items.count {
                    let item = items[selectedIndex]
                    onSelect(item.value)
                    isPresented = false
                }
                return .handled
            }
            return .ignored
        }
    }

    func suggestionRow(for item: SmartSuggestionItem, index: Int, total: Int) -> some View {
        Button {
            onSelect(item.value)
            isPresented = false
        } label: {
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: item.icon)
                    .font(WernickeTypography.size11)
                    .foregroundStyle(iconColor(for: item.category))
                    .frame(width: ParietalSpacing.icon)

                VStack(alignment: .leading, spacing: ParietalSpacing.xxxxs) {
                    Text(item.label)
                        .font(WernickeTypography.size12)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .lineLimit(1)

                    if let detail = item.detail {
                        HStack(spacing: ParietalSpacing.xs) {
                            Text(detail)
                                .font(WernickeTypography.size10)
                                .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                                .lineLimit(1)

                            if item.isRecent {
                                Text("· recent")
                                    .font(WernickeTypography.size9)
                                    .foregroundStyle(V4Color.accent.opacity(0.7))
                            }
                        }
                    }
                }

                Spacer()
            }
            .padding(.horizontal, ParietalSpacing.sm + 2)
            .padding(.vertical, ParietalSpacing.xs + 2)
            .contentShape(Rectangle())
            .background(index == selectedIndex ? Color.white.opacity(0.08) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func iconColor(for category: SmartSuggestionItem.SuggestionCategory) -> Color {
        switch category {
        case .mention: return V4Color.accent
        case .command: return V4Color.purple
        case .file: return V4Color.textSecondary
        case .pattern: return V4Color.warning
        case .proactive: return V4Color.golden
        case .history: return V4Color.textSecondary
        }
    }
}

// MARK: - Legacy Compatibility

/// Proactive suggestion bar — shows contextual actions based on Trinity state.
/// "Build broken -> Fix?", "New PPL record -> Deploy?", "Stale arena -> Run battle?"
@available(*, deprecated, message: "Use SmartSuggestionBar instead")
struct SmartSuggestions: View {
    @StateObject private var trinityCtx = TrinityContext.shared
    var onSuggestion: (String) -> Void

    var body: some View {
        SmartSuggestionBar(onSuggestion: onSuggestion)
    }
}

// MARK: - Suggestion Popup

/// Popup for inline suggestions (mentions, commands)
struct SmartSuggestionPopup: View {
    let input: String
    let cursorPosition: Int?
    @Binding var isPresented: Bool
    var onSelect: (String) -> Void

    @State private var selectedIndex = 0

    private var suggestions: [SmartSuggestionItem] {
        // Extract trigger (@ or /)
        guard let trigger = input.lastIndex(of: "@") ?? input.lastIndex(of: "/") else {
            return []
        }
        let afterTrigger = input[input.index(after: trigger)...]
        let query = String(afterTrigger).lowercased()

        // Generate suggestions based on trigger
        if input[trigger] == "@" {
            return [
                SmartSuggestionItem(icon: "doc", label: "file:", value: "@file:", detail: "Attach file", category: .mention, isRecent: false),
                SmartSuggestionItem(icon: "magnifyingglass", label: "grep:", value: "@grep:", detail: "Search code", category: .mention, isRecent: false),
                SmartSuggestionItem(icon: "hammer", label: "build", value: "@build", detail: "Build status", category: .mention, isRecent: false),
                SmartSuggestionItem(icon: "server.rack", label: "farm", value: "@farm", detail: "Farm status", category: .mention, isRecent: false),
                SmartSuggestionItem(icon: "exclamationmark.bubble", label: "issues", value: "@issues", detail: "GitHub issues", category: .mention, isRecent: false),
            ].filter { query.isEmpty || $0.label.lowercased().contains(query) }
        } else {
            return [
                SmartSuggestionItem(icon: "hammer", label: "/tri build", value: "/tri build", detail: "Build project", category: .command, isRecent: false),
                SmartSuggestionItem(icon: "checkmark", label: "/tri test", value: "/tri test", detail: "Run tests", category: .command, isRecent: false),
                SmartSuggestionItem(icon: "chart.bar", label: "/tri status", value: "/tri status", detail: "System status", category: .command, isRecent: false),
            ].filter { query.isEmpty || $0.label.lowercased().contains(query) }
        }
    }

    var body: some View {
        if !suggestions.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(suggestions.enumerated()), id: \.element.id) { index, item in
                    Button {
                        onSelect(item.label)
                        isPresented = false
                    } label: {
                        HStack(spacing: ParietalSpacing.sm) {
                            Image(systemName: item.icon)
                                .font(WernickeTypography.size10)
                                .foregroundStyle(iconColor(for: item.category))
                            Text(item.label)
                                .font(WernickeTypography.size11)
                                .foregroundStyle(selectedIndex == index ? V4Color.accent : V4Color.textPrimary)
                            Spacer()
                        }
                        .padding(.horizontal, ParietalSpacing.sm + 2)
                        .padding(.vertical, ParietalSpacing.xs + 2)
                        .background(selectedIndex == index ? V4Color.accent.opacity(V2Depth.bgSubtle) : Color.clear)
                    }
                    .buttonStyle(.plain)

                    if index < suggestions.count - 1 {
                        Divider()
                            .background(Color.white.opacity(V2Depth.bgSubtle))
                    }
                }
            }
            .background(V4Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(V2Depth.bgSubtle), lineWidth: 1)
            )
            .shadow(radius: ParietalSpacing.md)
        }
    }

    private func iconColor(for category: SmartSuggestionItem.SuggestionCategory) -> Color {
        switch category {
        case .mention: return V4Color.accent
        case .command: return V4Color.purple
        case .file: return V4Color.textSecondary
        case .pattern: return V4Color.warning
        case .proactive: return V4Color.golden
        case .history: return V4Color.textSecondary
        }
    }

    private func iconName(for category: SmartSuggestionItem.SuggestionCategory) -> String {
        switch category {
        case .mention: return "at"
        case .command: return "command"
        case .file: return "doc"
        case .pattern: return "magnifyingglass"
        case .proactive: return "lightbulb"
        case .history: return "clock"
        }
    }
}
