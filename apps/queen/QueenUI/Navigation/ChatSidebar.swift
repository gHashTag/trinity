import SwiftUI
import AppKit

struct ChatSidebar: View {
    @ObservedObject var store: ThreadStore
    @ObservedObject var modelManager: ModelManager
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var selectedTag: String?
    @State private var hoveredThread: UUID? = nil
    @State private var showNewTagAlert = false
    @State private var newTagName = ""

    private var filteredThreads: [ChatThread] {
        var base = store.sortedThreads
        if let tag = selectedTag {
            base = base.filter { $0.tags.contains(tag) }
        }
        if searchQuery.isEmpty { return base }
        let q = searchQuery.lowercased()
        return base.filter { thread in
            thread.title.lowercased().contains(q) ||
            thread.messages.contains { $0.text.lowercased().contains(q) }
        }
    }

    /// Group threads by date: Today / Yesterday / This Week / This Month / Older
    private var groupedThreads: [(String, [ChatThread])] {
        let threads = filteredThreads
        guard !threads.isEmpty else { return [] }

        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        let yesterdayStart = cal.date(byAdding: .day, value: -1, to: todayStart)!
        let weekStart = cal.date(byAdding: .day, value: -7, to: todayStart)!
        let monthStart = cal.date(byAdding: .month, value: -1, to: todayStart)!

        var today: [ChatThread] = []
        var yesterday: [ChatThread] = []
        var week: [ChatThread] = []
        var month: [ChatThread] = []
        var older: [ChatThread] = []

        for thread in threads {
            let date = thread.updatedAt
            if date >= todayStart { today.append(thread) }
            else if date >= yesterdayStart { yesterday.append(thread) }
            else if date >= weekStart { week.append(thread) }
            else if date >= monthStart { month.append(thread) }
            else { older.append(thread) }
        }

        var groups: [(String, [ChatThread])] = []
        if !today.isEmpty { groups.append(("Today", today)) }
        if !yesterday.isEmpty { groups.append(("Yesterday", yesterday)) }
        if !week.isEmpty { groups.append(("This Week", week)) }
        if !month.isEmpty { groups.append(("This Month", month)) }
        if !older.isEmpty { groups.append(("Older", older)) }
        return groups
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo / brand
            HStack(spacing: 8) {
                Image(systemName: "crown.fill")
                    .font(.system(size: 16))
                    .foregroundStyle(TrinityTheme.accent)
                Text("Queen")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.white)
                Spacer()
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isSearching.toggle()
                        if !isSearching { searchQuery = "" }
                    }
                } label: {
                    Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Search threads (Cmd+Shift+F)")
            }
            .padding(.horizontal, 16)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search field
            if isSearching {
                HStack(spacing: 6) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.3))
                    TextField("Search threads...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.white.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
                .padding(.bottom, 8)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            // New Thread button
            Button(action: { store.newThread() }) {
                HStack(spacing: 8) {
                    Image(systemName: "square.and.pencil")
                        .font(.system(size: 13))
                    Text("New Thread")
                        .font(.system(size: 13, weight: .medium))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12)
                .padding(.vertical, 9)
                .foregroundStyle(Color.white.opacity(0.8))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 8)
            .padding(.bottom, 8)
            .accessibilityLabel("New thread")
            .accessibilityHint("Creates a new conversation")

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Tag filter chips + create
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 4) {
                    tagChip(nil, label: "All")
                    ForEach(store.allTags, id: \.self) { tag in
                        tagChip(tag, label: "#\(tag)")
                    }
                    Button {
                        showNewTagAlert = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(.system(size: 11))
                            .foregroundStyle(TrinityTheme.accent.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                    .help("Create tag")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
            }
            .alert("New Tag", isPresented: $showNewTagAlert) {
                TextField("Tag name", text: $newTagName)
                Button("Add") {
                    let tag = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !tag.isEmpty, let threadID = store.activeThreadID {
                        store.addTag(tag, to: threadID)
                    }
                    newTagName = ""
                }
                Button("Cancel", role: .cancel) { newTagName = "" }
            } message: {
                Text("Enter a tag name for the current thread")
            }

            // Thread list with date groups
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(groupedThreads, id: \.0) { groupName, threads in
                        // Date group header
                        HStack {
                            Text(groupName)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.3))
                            Spacer()
                            Text("\(threads.count)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.2))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)

                        ForEach(threads) { thread in
                            ThreadRow(
                                thread: thread,
                                isActive: store.activeThreadID == thread.id,
                                searchQuery: searchQuery,
                                isHoveredForPreview: hoveredThread == thread.id,
                                onSelect: { store.activeThreadID = thread.id },
                                onDelete: { store.delete(thread) },
                                onRename: { store.rename(thread.id, title: $0) },
                                onExport: { exportThread(thread) },
                                onPin: { store.togglePin(thread.id) },
                                onAddTag: { store.addTag($0, to: thread.id) }
                            )
                            .onHover { hovering in
                                hoveredThread = hovering ? thread.id : nil
                            }
                        }
                    }
                }
                .padding(.vertical, 2)
            }

            Spacer(minLength: 0)

            // Network stats bar
            NetworkStatsBar()

            // Model badge at bottom
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            HStack(spacing: 6) {
                ProviderDot(provider: modelManager.selectedModel.provider)
                Text(modelManager.selectedModel.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.5))
                Spacer()
                Text(modelManager.selectedModel.provider.rawValue)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(hex: 0x0A0A0A))
        .onReceive(NotificationCenter.default.publisher(for: .toggleThreadSearch)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                isSearching.toggle()
                if !isSearching { searchQuery = "" }
            }
        }
    }

    private func tagChip(_ tag: String?, label: String) -> some View {
        let isActive = selectedTag == tag
        return Button {
            selectedTag = tag
        } label: {
            Text(label)
                .font(.system(size: 10, weight: isActive ? .bold : .medium))
                .foregroundStyle(isActive ? .black : Color.white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(isActive ? TrinityTheme.accent : Color.white.opacity(0.06))
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func exportThread(_ thread: ChatThread) {
        guard let md = store.exportAsMarkdown(thread.id) else { return }
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "\(thread.title.prefix(30)).md"
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            try? md.data(using: .utf8)?.write(to: url)
        }
    }
}

// MARK: - Provider Health Dot

struct ProviderDot: View {
    let provider: AIProvider
    @StateObject private var networkLog = NetworkLog.shared
    @State private var pulse = false

    var body: some View {
        let status = networkLog.providerHealth[provider.rawValue]
        let isUp = status?.isUp ?? true

        ZStack {
            if !isUp {
                Circle()
                    .stroke(TrinityTheme.statusError.opacity(0.4), lineWidth: 1)
                    .frame(width: 12, height: 12)
                    .scaleEffect(pulse ? 1.8 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
            }
            Circle()
                .fill(isUp ? TrinityTheme.accent : TrinityTheme.statusError)
                .frame(width: 6, height: 6)
        }
        .frame(width: 14, height: 14)
        .help(statusHelp(status, isUp))
        .accessibilityLabel("\(provider.rawValue) \(isUp ? "online" : "offline")")
    }

    private func statusHelp(_ status: NetworkLog.ProviderStatus?, _ isUp: Bool) -> String {
        var text = "\(provider.rawValue): \(isUp ? "OK" : "DOWN")"
        if let latency = status?.latencyMs, latency > 0 {
            text += " (\(latency)ms)"
        }
        if let remaining = status?.remainingRequests {
            text += " [\(remaining) req left]"
        }
        return text
    }
}

// MARK: - Network Stats Bar

struct NetworkStatsBar: View {
    @StateObject private var networkLog = NetworkLog.shared

    var body: some View {
        let today = networkLog.todayEntries
        guard !today.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                HStack(spacing: 12) {
                    miniStat("\(today.count)", "reqs")
                    miniStat("\(networkLog.todayTokens / 1000)K", "tok")
                    if networkLog.avgTTFB > 0 {
                        miniStat("\(networkLog.avgTTFB)ms", "TTFB")
                    }
                    if networkLog.avgTokPerSec > 0 {
                        miniStat(String(format: "%.0f", networkLog.avgTokPerSec), "tok/s")
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
            }
        )
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.5))
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(Color.white.opacity(0.25))
        }
    }
}

// MARK: - Thread Row

struct ThreadRow: View {
    let thread: ChatThread
    let isActive: Bool
    let searchQuery: String
    var isHoveredForPreview: Bool = false
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onExport: () -> Void
    let onPin: () -> Void
    let onAddTag: (String) -> Void

    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var renameText = ""

    /// Preview text: first user message (truncated)
    private var previewText: String? {
        guard let first = thread.messages.first(where: { $0.role == .user }) else { return nil }
        let text = first.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(120))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 4) {
                // Pin indicator
                if thread.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(TrinityTheme.golden)
                        .rotationEffect(.degrees(45))
                }

                if isRenaming {
                    TextField("Thread name", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(.white)
                        .onSubmit {
                            onRename(renameText)
                            isRenaming = false
                        }
                        .onAppear { renameText = thread.title }
                } else {
                    VStack(alignment: .leading, spacing: 2) {
                        // Title with search highlighting
                        if !searchQuery.isEmpty, let range = thread.title.lowercased().range(of: searchQuery.lowercased()) {
                            let before = String(thread.title[thread.title.startIndex..<range.lowerBound])
                            let match = String(thread.title[range])
                            let after = String(thread.title[range.upperBound...])
                            (Text(before) + Text(match).foregroundColor(TrinityTheme.accent).bold() + Text(after))
                                .font(.system(size: 13))
                                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.6))
                                .lineLimit(1)
                        } else {
                            Text(thread.title)
                                .font(.system(size: 13))
                                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.6))
                                .lineLimit(1)
                        }

                        HStack(spacing: 4) {
                            ForEach(thread.tags.prefix(2), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(.system(size: 8, weight: .medium))
                                    .foregroundStyle(TrinityTheme.purple)
                                    .padding(.horizontal, 3)
                                    .padding(.vertical, 1)
                                    .background(TrinityTheme.purple.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                            if !searchQuery.isEmpty {
                                let matchCount = thread.messages.filter { $0.text.lowercased().contains(searchQuery.lowercased()) }.count
                                if matchCount > 0 {
                                    Text("\(matchCount) match\(matchCount == 1 ? "" : "es")")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(TrinityTheme.accent)
                                }
                            }
                            Text("\(thread.messages.count) msgs")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.25))
                            Text(relativeDate(thread.updatedAt))
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.2))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isHovered && !isRenaming {
                    Button(action: { isRenaming = true }) {
                        Image(systemName: "pencil")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.4))

                    Button(action: onExport) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .help("Export as Markdown")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TrinityTheme.statusError.opacity(0.6))
                }
            }

            // Thread preview on hover (first message snippet)
            if isHoveredForPreview && !isActive && !isRenaming, let preview = previewText {
                Text(preview)
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.35))
                    .lineLimit(2)
                    .padding(.top, 3)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isActive ? TrinityTheme.accent.opacity(0.1) :
                    isHovered ? Color.white.opacity(0.04) : Color.clear
                )
        )
        .padding(.horizontal, 8)
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(thread.isPinned ? "Unpin" : "Pin") { onPin() }
            Button("Rename") { isRenaming = true }
            Button("Export as Markdown") { onExport() }
            Menu("Add Tag") {
                ForEach(["hslm", "fpga", "patent", "research", "sevo", "arena", "bug", "feature"], id: \.self) { tag in
                    Button("#\(tag)") { onAddTag(tag) }
                }
            }
            Divider()
            Button("Delete", role: .destructive) { onDelete() }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(thread.title), \(thread.messages.count) messages, \(relativeDate(thread.updatedAt))")
        .accessibilityHint("Double-tap to open thread")
    }

    private func relativeDate(_ date: Date) -> String {
        let delta = Int(Date().timeIntervalSince(date))
        if delta < 60 { return "now" }
        if delta < 3600 { return "\(delta / 60)m" }
        if delta < 86400 { return "\(delta / 3600)h" }
        return "\(delta / 86400)d"
    }
}
