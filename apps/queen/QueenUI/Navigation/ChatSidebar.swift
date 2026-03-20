import SwiftUI
import AppKit

// MARK: - Date Filter

enum DateFilter: String, CaseIterable {
    case all = "All"
    case today = "Today"
    case thisWeek = "This Week"
    case thisMonth = "This Month"
    case older = "Older"

    func matches(_ date: Date) -> Bool {
        let cal = Calendar.current
        let now = Date()
        let todayStart = cal.startOfDay(for: now)
        switch self {
        case .all: return true
        case .today: return date >= todayStart
        case .thisWeek:
            return date >= cal.date(byAdding: .day, value: -7, to: todayStart)!
        case .thisMonth:
            return date >= cal.date(byAdding: .month, value: -1, to: todayStart)!
        case .older:
            return date < cal.date(byAdding: .month, value: -1, to: todayStart)!
        }
    }
}

// MARK: - Quick Filter

enum QuickFilter: String, CaseIterable {
    case all = "All"
    case unread = "Unread"
    case pinned = "Pinned"
    case today = "Today"

    var icon: String {
        switch self {
        case .all: return "tray.full"
        case .unread: return "circle.badge"
        case .pinned: return "pin.fill"
        case .today: return "sun.max.fill"
        }
    }

    func matches(_ thread: ChatThread, unreadCount: Int) -> Bool {
        switch self {
        case .all: return true
        case .unread: return unreadCount > 0
        case .pinned: return thread.isPinned
        case .today:
            let cal = Calendar.current
            let todayStart = cal.startOfDay(for: Date())
            return thread.updatedAt >= todayStart
        }
    }
}

struct ChatSidebar: View {
    @ObservedObject var store: ThreadStore
    @ObservedObject var modelManager: ModelManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var searchQuery = ""
    @State private var isSearching = false
    @State private var selectedTag: String?
    @State private var hoveredThread: UUID? = nil
    @State private var showNewTagAlert = false
    @State private var newTagName = ""
    @State private var showNewFolderAlert = false
    @State private var newFolderName = ""
    @State private var showImportPicker = false
    @State private var importResult = ""
    @State private var showExportFormat = false
    @State private var exportThread: ChatThread? = nil
    @State private var exportToast = ""
    @State private var shareToast = ""
    @State private var debouncedQuery = ""
    @State private var searchTask: Task<Void, Never>? = nil
    @State private var showArchiveSection = false
    @State private var showBookmarks = false
    @State private var filterDateRange: DateFilter = .all
    @State private var filterModel: String? = nil
    @State private var quickFilter: QuickFilter = .all
    @AppStorage("threadSortOrder") private var sortOrder: String = "date"

    // Realm section collapse states
    @State private var showBrainRealm = true
    @State private var showBodyRealm = true
    @State private var showSpiritRealm = true

    /// Calculate unread messages for a thread (assistant messages after last user view)
    /// For now, count all assistant messages from today as "unread"
    private func unreadCount(for thread: ChatThread) -> Int {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        return thread.messages.filter { msg in
            msg.role == .assistant && msg.timestamp >= todayStart
        }.count
    }

    /// Total unread count across all threads
    private var totalUnreadCount: Int {
        store.threads.reduce(0) { $0 + unreadCount(for: $1) }
    }

    /// Number of active metadata filters
    private var activeFilterCount: Int {
        var count = 0
        if quickFilter != .all { count += 1 }
        if filterDateRange != .all { count += 1 }
        if filterModel != nil { count += 1 }
        return count
    }

    /// Unique model IDs across all threads
    private var availableModels: [String] {
        let allModels = store.threads.flatMap { thread in
            thread.messages.compactMap { $0.modelID }
        }
        return Array(Set(allModels)).sorted()
    }

    private var filteredThreads: [ChatThread] {
        var base = store.sortedThreads.filter { !$0.isArchived }

        // Apply quick filter
        base = base.filter { thread in
            quickFilter.matches(thread, unreadCount: unreadCount(for: thread))
        }
        // Apply sort order
        switch sortOrder {
        case "name":
            base.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case "size":
            base.sort { $0.messages.count > $1.messages.count }
        default: break  // "date" — already sorted by date
        }
        if let tag = selectedTag {
            base = base.filter { $0.tags.contains(tag) }
        }
        // Metadata filters
        if filterDateRange != .all {
            base = base.filter { filterDateRange.matches($0.updatedAt) }
        }
        if let model = filterModel {
            base = base.filter { thread in
                thread.messages.contains { $0.modelID?.contains(model) == true }
            }
        }
        if debouncedQuery.isEmpty { return base }
        // Use fuzzy search for better matching
        let fuzzyResults = store.fuzzySearch(debouncedQuery)
        let matchIDs = Set(fuzzyResults.map { $0.thread.id })
        return base.filter { matchIDs.contains($0.id) }
    }

    /// Group threads by date: Today / Yesterday / This Week / This Month / Older
    private func groupThreadsByDate(_ threads: [ChatThread]) -> [(String, [ChatThread])] {
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

    /// Determine realm for a thread based on its screen property
    private func realm(for thread: ChatThread) -> Kingdom? {
        return thread.screen?.kingdom
    }

    /// Group threads by realm
    private func groupThreadsByRealm(_ threads: [ChatThread]) -> [(Kingdom, [ChatThread])] {
        var brain: [ChatThread] = []
        var body: [ChatThread] = []
        var spirit: [ChatThread] = []
        var uncategorized: [ChatThread] = []

        for thread in threads {
            switch realm(for: thread) {
            case .brain: brain.append(thread)
            case .body: body.append(thread)
            case .spirit: spirit.append(thread)
            case nil: uncategorized.append(thread)
            }
        }

        var groups: [(Kingdom, [ChatThread])] = []
        if !brain.isEmpty { groups.append((.brain, brain)) }
        if !body.isEmpty { groups.append((.body, body)) }
        if !spirit.isEmpty { groups.append((.spirit, spirit)) }
        if !uncategorized.isEmpty { groups.append((.brain, uncategorized)) } // Uncategorized -> Brain
        return groups
    }

    var body: some View {
        // Cortex: Entorhinal Sidebar — Responsive 220-400px
        EntorhinalSidebar {
            sidebarContent
        }
    }

    private var sidebarContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Logo / brand
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: "crown.fill")
                    .font(WernickeTypography.body16)
                    .foregroundStyle(V4Color.accent)
                Text("Queen")
                    .font(WernickeTypography.body16.weight(.semibold))
                    .foregroundStyle(Color.white)
                Spacer()
                Menu {
                    Button { sortOrder = "date" } label: {
                        Label("Date", systemImage: sortOrder == "date" ? "checkmark" : "")
                    }
                    Button { sortOrder = "name" } label: {
                        Label("Name", systemImage: sortOrder == "name" ? "checkmark" : "")
                    }
                    Button { sortOrder = "size" } label: {
                        Label("Messages", systemImage: sortOrder == "size" ? "checkmark" : "")
                    }
                } label: {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                }
                .menuStyle(.borderlessButton)
                .frame(width: ParietalSpacing.buttonSmallWidth)
                .help("Sort threads")
                .accessibilityLabel("Sort threads, currently by \(sortOrder)")

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isSearching.toggle()
                        if !isSearching {
                            searchQuery = ""
                            quickFilter = .all
                            filterDateRange = .all
                            filterModel = nil
                        }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                            .font(WernickeTypography.caption)
                            .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                        if !isSearching && totalUnreadCount > 0 {
                            Text("\(totalUnreadCount)")
                                .font(WernickeTypography.size7.weight(.bold))
                                .foregroundStyle(.black)
                                .frame(width: ParietalSpacing.mediumBadge, height: ParietalSpacing.badgeHeight)
                                .background(V4Color.golden)
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Search threads (Cmd+Shift+F)")
                .accessibilityLabel(isSearching ? "Close search" : "Search threads")
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.top, 16)
            .padding(.bottom, 12)

            // Search field
            if isSearching {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "magnifyingglass")
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                    TextField("Search threads...", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .font(WernickeTypography.caption)
                        .foregroundStyle(Color.white)
                }
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, ParietalSpacing.xxxs)
                .background(Color.white.opacity(V2Depth.bgCard))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.bottom, 4)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))

                // Quick filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ParietalSpacing.xs) {
                        ForEach(QuickFilter.allCases, id: \.self) { filter in
                            quickFilterChip(filter)
                        }
                    }
                    .padding(.horizontal, ParietalSpacing.sm)
                    .padding(.vertical, ParietalSpacing.xxxs)
                }

                // Metadata filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: ParietalSpacing.xs) {
                        // Date filter
                        Menu {
                            ForEach(DateFilter.allCases, id: \.self) { df in
                                Button {
                                    filterDateRange = df
                                } label: {
                                    HStack {
                                        Text(df.rawValue)
                                        if filterDateRange == df {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            filterPill(
                                label: "Date: \(filterDateRange.rawValue)",
                                isActive: filterDateRange != .all
                            )
                        }
                        .menuStyle(.borderlessButton)

                        // Model filter
                        Menu {
                            Button {
                                filterModel = nil
                            } label: {
                                HStack {
                                    Text("All")
                                    if filterModel == nil {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                            ForEach(availableModels, id: \.self) { model in
                                Button {
                                    filterModel = model
                                } label: {
                                    HStack {
                                        Text(model)
                                        if filterModel == model {
                                            Image(systemName: "checkmark")
                                        }
                                    }
                                }
                            }
                        } label: {
                            filterPill(
                                label: filterModel.map { "Model: \($0)" } ?? "Model: All",
                                isActive: filterModel != nil
                            )
                        }
                        .menuStyle(.borderlessButton)

                        // Clear all filters
                        if activeFilterCount > 0 {
                            Button {
                                quickFilter = .all
                                filterDateRange = .all
                                filterModel = nil
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(WernickeTypography.micro)
                                    Text("Clear")
                                        .font(WernickeTypography.miniMedium)
                                }
                                .foregroundStyle(V4Color.accent)
                                .padding(.horizontal, ParietalSpacing.xxxs)
                                .padding(.vertical, ParietalSpacing.xxxs)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, ParietalSpacing.sm)
                    .padding(.vertical, ParietalSpacing.xxxs)
                }
                .padding(.bottom, 4)
            }

            // New Thread + Import buttons
            HStack(spacing: ParietalSpacing.xs) {
                Button(action: { store.newThread() }) {
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        Image(systemName: "square.and.pencil")
                            .font(WernickeTypography.small)
                        Text("New Thread")
                            .font(WernickeTypography.smallMedium)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, ParietalSpacing.sm)
                    .padding(.vertical, ParietalSpacing.xxxs)
                    .foregroundStyle(V4Color.white80)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("New thread")

                Button { showImportPicker = true } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(WernickeTypography.caption)
                        .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                        .padding(ParietalSpacing.xs)
                }
                .buttonStyle(.plain)
                .help("Import conversations")
                .accessibilityLabel("Import conversations")

                Button { showNewFolderAlert = true } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(WernickeTypography.caption)
                        .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                        .padding(ParietalSpacing.xs)
                }
                .buttonStyle(.plain)
                .help("New folder")
                .accessibilityLabel("Create new folder")

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showBookmarks.toggle()
                    }
                } label: {
                    Image(systemName: showBookmarks ? "bookmark.fill" : "bookmark")
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(showBookmarks ? V4Color.golden : Color.white.opacity(store.allBookmarks().isEmpty ? 0.2 : 0.4))
                        .padding(ParietalSpacing.xs)
                }
                .buttonStyle(.plain)
                .help(store.allBookmarks().isEmpty ? "No bookmarks" : "Bookmarks (\(store.allBookmarks().count))")
            }
            .padding(.horizontal, ParietalSpacing.xs)
            .padding(.bottom, 8)
            .alert("New Folder", isPresented: $showNewFolderAlert) {
                TextField("Folder name", text: $newFolderName)
                Button("Create") {
                    let name = newFolderName.trimmingCharacters(in: .whitespacesAndNewlines)
                    if !name.isEmpty { store.createFolder(name: name) }
                    newFolderName = ""
                }
                Button("Cancel", role: .cancel) { newFolderName = "" }
            }
            .fileImporter(isPresented: $showImportPicker, allowedContentTypes: [.json, .plainText], allowsMultipleSelection: true) { result in
                handleImport(result)
            }

            Rectangle()
                .fill(Color.white.opacity(V2Depth.bgCard))
                .frame(height: ParietalSpacing.dividerHeight)

            // Bookmarks panel
            if showBookmarks {
                bookmarksPanel
            }

            // Tag filter chips + create
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: ParietalSpacing.xs) {
                    tagChip(nil, label: "All")
                    ForEach(store.allTags, id: \.self) { tag in
                        tagChip(tag, label: "#\(tag)")
                    }
                    Button {
                        showNewTagAlert = true
                    } label: {
                        Image(systemName: "plus.circle")
                            .font(WernickeTypography.caption2)
                            .foregroundStyle(V4Color.accent.opacity(V2Depth.stateDisabled))
                    }
                    .buttonStyle(.plain)
                    .help("Create tag")
                }
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xxs)
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

            // Import result banner
            if !importResult.isEmpty {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(WernickeTypography.mini)
                        .foregroundStyle(V4Color.statusOK)
                    Text(importResult)
                        .font(WernickeTypography.mini)
                        .foregroundStyle(V4Color.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(V4Color.statusOK.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                .padding(.horizontal, ParietalSpacing.xs)
                .onAppear {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(3))
                        importResult = ""
                    }
                }
            }

            // Fuzzy search / filter result count
            if !debouncedQuery.isEmpty || activeFilterCount > 0 {
                let total = filteredThreads.count
                HStack {
                    Text("\(total) result\(total == 1 ? "" : "s")")
                        .font(WernickeTypography.miniBold)
                        .foregroundStyle(V4Color.accent)
                    if activeFilterCount > 0 {
                        Text("(\(activeFilterCount) filter\(activeFilterCount == 1 ? "" : "s"))")
                            .font(WernickeTypography.mini)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.xxs)
            }

            // Export toast
            if !exportToast.isEmpty {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(WernickeTypography.mini)
                        .foregroundStyle(V4Color.statusOK)
                    Text(exportToast)
                        .font(WernickeTypography.mini)
                        .foregroundStyle(V4Color.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(V4Color.statusOK.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                .padding(.horizontal, ParietalSpacing.xs)
                .transition(.opacity)
            }

            // Share toast
            if !shareToast.isEmpty {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(WernickeTypography.mini)
                        .foregroundStyle(V4Color.statusOK)
                    Text(shareToast)
                        .font(WernickeTypography.mini)
                        .foregroundStyle(V4Color.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(V4Color.statusOK.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                .padding(.horizontal, ParietalSpacing.xs)
                .transition(.opacity)
            }

            // Archive suggestion banner
            if store.showArchiveSuggestion {
                HStack(spacing: ParietalSpacing.sm) {
                    Text("\u{1F4E6} \(store.staleThreads.count) thread\(store.staleThreads.count == 1 ? "" : "s") older than 90 days")
                        .font(WernickeTypography.caption2Medium)
                        .foregroundStyle(V4Color.white70)
                    Spacer()
                    Button("Archive All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.archiveAllStale()
                        }
                    }
                    .font(WernickeTypography.caption2Bold)
                    .foregroundStyle(V4Color.accent)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Archive all stale threads")
                    Button("Dismiss") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.showArchiveSuggestion = false
                        }
                    }
                    .font(WernickeTypography.caption2)
                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xs)
                .background(V4Color.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.bottom, 4)
            }

            // Thread list with folder groups + date groups
            ScrollView {
                LazyVStack(spacing: 0) {
                    // Skeleton loading placeholder while threads load
                    if !store.isLoaded {
                        ForEach(0..<5, id: \.self) { index in
                            SkeletonThreadRow(index: index)
                        }
                    }

                    // Folders first
                    ForEach(store.folders) { folder in
                        folderSection(folder)
                    }

                    // Uncategorized threads (no folder) — grouped by realm
                    let uncategorized = filteredThreads.filter { $0.folderID == nil }

                    // Realm-grouped threads
                    let threadsToGroup = store.folders.isEmpty ? filteredThreads : uncategorized
                    ForEach(groupThreadsByRealm(threadsToGroup), id: \.0) { realm, threads in
                        let isExpanded: Binding<Bool> = {
                            switch realm {
                            case .brain: return $showBrainRealm
                            case .body: return $showBodyRealm
                            case .spirit: return $showSpiritRealm
                            }
                        }()

                        RealmHeader(realm: realm, count: threads.count, isExpanded: isExpanded)

                        if isExpanded.wrappedValue {
                            ForEach(threads) { thread in
                                threadRow(thread)
                            }
                        }
                    }

                    // Empty state: no threads at all (after loading)
                    if store.isLoaded && store.threads.isEmpty {
                        VStack(spacing: ParietalSpacing.sm) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(WernickeTypography.size28)
                                .foregroundStyle(V4Color.textSecondary)
                            Text("No conversations yet")
                                .font(WernickeTypography.small)
                                .foregroundStyle(V4Color.textSecondary)
                            Button {
                                store.newThread()
                            } label: {
                                HStack(spacing: ParietalSpacing.xs) {
                                    Image(systemName: "plus")
                                        .font(WernickeTypography.caption2Semibold)
                                    Text("New Thread")
                                        .font(WernickeTypography.captionMedium)
                                }
                                .foregroundStyle(V4Color.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, ParietalSpacing.xxs)
                                .background(V4Color.accent.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 48)
                        .padding(.bottom, 24)
                    }

                    // Empty state: search / filters returned no results
                    if store.isLoaded && !store.threads.isEmpty && filteredThreads.isEmpty {
                        VStack(spacing: ParietalSpacing.sm + 2) {
                            Image(systemName: "magnifyingglass")
                                .font(WernickeTypography.size24)
                                .foregroundStyle(V4Color.textSecondary)
                            if !debouncedQuery.isEmpty {
                                Text("No matches for '\(debouncedQuery)'")
                                    .font(WernickeTypography.caption)
                                    .foregroundStyle(V4Color.textSecondary)
                                    .multilineTextAlignment(.center)
                                Text("Try broader terms")
                                    .font(.caption2)
                                    .foregroundStyle(V2Depth.white(0.25))
                            } else if activeFilterCount > 0 {
                                Text("No matches with current filters")
                                    .font(WernickeTypography.caption)
                                    .foregroundStyle(V4Color.textSecondary)
                                Button {
                                    quickFilter = .all
                                    filterDateRange = .all
                                    filterModel = nil
                                } label: {
                                    Text("Clear filters")
                                        .font(WernickeTypography.caption2Medium)
                                        .foregroundStyle(V4Color.accent)
                                        .padding(.horizontal, ParietalSpacing.sm)
                                        .padding(.vertical, ParietalSpacing.xxs)
                                        .background(V4Color.accent.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 40)
                        .padding(.bottom, 20)
                    }

                    // Archive section (collapsed by default)
                    if !store.archivedThreads.isEmpty {
                        VStack(spacing: 0) {
                            HStack(spacing: ParietalSpacing.sm - 2) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showArchiveSection.toggle()
                                    }
                                } label: {
                                    Image(systemName: showArchiveSection ? "chevron.down" : "chevron.right")
                                        .font(WernickeTypography.size8.weight(.bold))
                                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                                }
                                .buttonStyle(.plain)

                                Image(systemName: "archivebox")
                                    .font(WernickeTypography.mini)
                                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                                Text("Archive")
                                    .font(WernickeTypography.miniSemibold)
                                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                                Spacer()
                                Text("\(store.archivedThreads.count)")
                                    .font(WernickeTypography.micro.monospaced())
                                    .foregroundStyle(V4Color.white20)
                            }
                            .padding(.horizontal, ParietalSpacing.md)
                            .padding(.top, 10)
                            .padding(.bottom, 4)
                            .contentShape(Rectangle())
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.15)) {
                                    showArchiveSection.toggle()
                                }
                            }

                            if showArchiveSection {
                                ForEach(store.archivedThreads) { thread in
                                    threadRow(thread)
                                }
                            }
                        }
                    }
                }
                .padding(.vertical, ParietalSpacing.xxxs)
            }

            // Export format picker
            .sheet(isPresented: $showExportFormat) {
                if let thread = exportThread {
                    ExportFormatPicker(
                        thread: thread,
                        store: store,
                        onDismiss: { showExportFormat = false }
                    )
                }
            }

            Spacer(minLength: 0)

            // Undo delete toast
            if store.showUndoToast {
                HStack(spacing: ParietalSpacing.sm + 2) {
                    Image(systemName: "trash")
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                    Text("Thread deleted")
                        .font(WernickeTypography.captionMedium)
                        .foregroundStyle(V4Color.white70)
                    Spacer()
                    Button("Undo") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.undoDelete()
                        }
                    }
                    .font(WernickeTypography.captionBold)
                    .foregroundStyle(V4Color.accent)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Undo delete")
                    .accessibilityHint("Restores the deleted thread")
                }
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.md)
                .background(V4Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.bottom, 4)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

            // Network stats bar
            NetworkStatsBar()

            // Model badge at bottom
            Rectangle()
                .fill(Color.white.opacity(V2Depth.bgCard))
                .frame(height: ParietalSpacing.dividerHeight)

            HStack(spacing: ParietalSpacing.sm - 2) {
                ProviderDot(provider: modelManager.selectedModel.provider)
                Text(modelManager.selectedModel.displayName)
                    .font(WernickeTypography.caption2Medium)
                    .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                Spacer()
                Text(modelManager.selectedModel.provider.rawValue)
                    .font(WernickeTypography.mini)
                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.md)
        }
        .background(Color(hex: 0x0A0A0A))
        .onReceive(NotificationCenter.default.publisher(for: .toggleThreadSearch)) { _ in
            withAnimation(.easeInOut(duration: 0.15)) {
                isSearching.toggle()
                if !isSearching {
                    searchQuery = ""; debouncedQuery = ""
                    quickFilter = .all; filterDateRange = .all; filterModel = nil
                }
            }
        }
        .onChange(of: searchQuery) { _, newValue in
            // Debounce fuzzy search by 300ms
            searchTask?.cancel()
            if newValue.isEmpty {
                debouncedQuery = ""
            } else {
                searchTask = Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(300))
                    if !Task.isCancelled {
                        debouncedQuery = newValue
                    }
                }
            }
        }
    }

    // MARK: - Bookmarks Panel

    /// Groups bookmarks by thread and returns (thread, messages) pairs sorted by most recent bookmark
    private func groupedBookmarks() -> [(thread: ChatThread, messages: [ChatMessage])] {
        let all = store.allBookmarks()
        var grouped: [UUID: (thread: ChatThread, messages: [ChatMessage])] = [:]
        for item in all {
            if grouped[item.thread.id] != nil {
                grouped[item.thread.id]!.messages.append(item.message)
            } else {
                grouped[item.thread.id] = (thread: item.thread, messages: [item.message])
            }
        }
        return grouped.values
            .sorted { ($0.messages.first?.timestamp ?? .distantPast) > ($1.messages.first?.timestamp ?? .distantPast) }
    }

    private var bookmarksPanel: some View {
        VStack(spacing: 0) {
            // Panel header
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: "bookmark.fill")
                    .font(WernickeTypography.mini)
                    .foregroundStyle(V4Color.golden)
                Text("Bookmarks")
                    .font(WernickeTypography.caption2Semibold)
                    .foregroundStyle(V4Color.textPrimary)
                Spacer()
                Text("\(store.allBookmarks().count)")
                    .font(WernickeTypography.miniMono)
                    .foregroundStyle(V4Color.textSecondary)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showBookmarks = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.microBold)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)

            let groups = groupedBookmarks()

            if groups.isEmpty {
                // Empty state
                VStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: "bookmark.slash")
                        .font(WernickeTypography.size20)
                        .foregroundStyle(V4Color.textSecondary)
                    Text("No bookmarked messages yet")
                        .font(WernickeTypography.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ParietalSpacing.lg)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groups, id: \.thread.id) { group in
                            // Thread header
                            HStack(spacing: ParietalSpacing.xs) {
                                Image(systemName: "bubble.left")
                                    .font(WernickeTypography.size8)
                                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                                Text(group.thread.title)
                                    .font(WernickeTypography.miniSemibold)
                                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(group.messages.count)")
                                    .font(WernickeTypography.micro.monospaced())
                                    .foregroundStyle(V4Color.white20)
                            }
                            .padding(.horizontal, ParietalSpacing.sm)
                            .padding(.top, 8)
                            .padding(.bottom, 2)

                            // Bookmarked messages in this thread
                            ForEach(group.messages) { msg in
                                Button {
                                    store.activeThreadID = group.thread.id
                                    // Post notification to scroll to message
                                    NotificationCenter.default.post(
                                        name: .scrollToMessage,
                                        object: nil,
                                        userInfo: ["messageID": msg.id]
                                    )
                                } label: {
                                    HStack(alignment: .top, spacing: ParietalSpacing.sm - 2) {
                                        Image(systemName: "bookmark.fill")
                                            .font(WernickeTypography.size8)
                                            .foregroundStyle(V4Color.golden.opacity(V1Theme.opacityTextSecondary))
                                            .padding(.top, 2)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(String(msg.text.prefix(80)))
                                                .font(WernickeTypography.caption2)
                                                .foregroundStyle(V4Color.textPrimary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            Text(msg.timestamp, style: .relative)
                                                .font(WernickeTypography.micro)
                                                .foregroundStyle(V4Color.textSecondary)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, ParietalSpacing.sm)
                                    .padding(.vertical, ParietalSpacing.xxs)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .contextMenu {
                                    Button {
                                        store.toggleBookmark(msg.id, in: group.thread.id)
                                    } label: {
                                        Label("Remove Bookmark", systemImage: "bookmark.slash")
                                    }
                                    Button {
                                        store.activeThreadID = group.thread.id
                                    } label: {
                                        Label("Go to Thread", systemImage: "arrow.right.circle")
                                    }
                                }
                            }
                        }
                    }
                }
                .frame(maxHeight: 260)
            }

            Rectangle()
                .fill(Color.white.opacity(V2Depth.bgCard))
                .frame(height: ParietalSpacing.dividerHeight)
        }
        .background(V4Color.surface.opacity(V2Depth.stateDisabled))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func filterPill(label: String, isActive: Bool) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(isActive ? WernickeTypography.miniBold : WernickeTypography.miniMedium)
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(WernickeTypography.size7.weight(.bold))
        }
        .foregroundStyle(isActive ? .black : V4Color.textSecondary)
        .padding(.horizontal, ParietalSpacing.xs)
        .padding(.vertical, ParietalSpacing.xxxs)
        .background(isActive ? V4Color.accent : Color.white.opacity(V2Depth.bgCard))
        .clipShape(SwiftUI.Capsule())
    }

    private func tagChip(_ tag: String?, label: String) -> some View {
        let isActive = selectedTag == tag
        return Button {
            selectedTag = tag
        } label: {
            Text(label)
                .font(isActive ? WernickeTypography.miniBold : WernickeTypography.miniMedium)
                .foregroundStyle(isActive ? .black : Color.white.opacity(V2Depth.stateDisabled))
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, ParietalSpacing.xxxs)
                .background(isActive ? V4Color.accent : Color.white.opacity(V2Depth.bgCard))
                .clipShape(SwiftUI.Capsule())
        }
        .buttonStyle(.plain)
    }

    private func quickFilterChip(_ filter: QuickFilter) -> some View {
        let isActive = quickFilter == filter
        let count: Int = {
            switch filter {
            case .all: return store.threads.count
            case .unread: return totalUnreadCount
            case .pinned: return store.threads.filter { $0.isPinned }.count
            case .today:
                let cal = Calendar.current
                let todayStart = cal.startOfDay(for: Date())
                return store.threads.filter { $0.updatedAt >= todayStart }.count
            }
        }()

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                quickFilter = filter
            }
        } label: {
            HStack(spacing: 3) {
                Image(systemName: filter.icon)
                    .font(WernickeTypography.size7.weight(.bold))
                Text(filter.rawValue)
                    .font(isActive ? WernickeTypography.miniBold : WernickeTypography.miniMedium)
                if count > 0 {
                    Text("\(count)")
                        .font(WernickeTypography.size8.weight(.bold))
                        .foregroundStyle(isActive ? .black.opacity(V1Theme.opacityTextSecondary) : Color.white.opacity(V1Theme.opacityTextTertiary))
                }
            }
            .foregroundStyle(isActive ? .black : V4Color.textSecondary)
            .padding(.horizontal, ParietalSpacing.xs)
            .padding(.vertical, ParietalSpacing.xxxs)
            .background(isActive ? V4Color.accent : Color.white.opacity(V2Depth.bgCard))
            .clipShape(SwiftUI.Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(filter.rawValue) threads, \(count) total")
    }

    private func showExport(_ thread: ChatThread) {
        exportThread = thread
        showExportFormat = true
    }

    @ViewBuilder
    private func folderSection(_ folder: ThreadFolder) -> some View {
        let folderThreads = filteredThreads.filter { $0.folderID == folder.id }
        if !folderThreads.isEmpty || searchQuery.isEmpty {
            VStack(spacing: 0) {
                // Folder header
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Button {
                        store.toggleFolderCollapse(folder.id)
                    } label: {
                        Image(systemName: folder.isCollapsed ? "chevron.right" : "chevron.down")
                            .font(WernickeTypography.size8.weight(.bold))
                            .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "folder.fill")
                        .font(WernickeTypography.mini)
                        .foregroundStyle(folder.swiftColor)
                    Text(folder.name)
                        .font(WernickeTypography.miniSemibold)
                        .foregroundStyle(folder.swiftColor)
                    Spacer()
                    Text("\(folderThreads.count)")
                        .font(WernickeTypography.micro.monospaced())
                        .foregroundStyle(V4Color.white20)
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.top, 10)
                .padding(.bottom, 4)
                .contextMenu {
                    Button("Rename") {
                        // Simple rename via alert
                        newFolderName = folder.name
                        showNewFolderAlert = true
                    }
                    Menu("Color") {
                        Button("Green") { store.recolorFolder(folder.id, color: "00FF88") }
                        Button("Purple") { store.recolorFolder(folder.id, color: "8B5CF6") }
                        Button("Gold") { store.recolorFolder(folder.id, color: "FFD700") }
                        Button("Red") { store.recolorFolder(folder.id, color: "EF4444") }
                        Button("Blue") { store.recolorFolder(folder.id, color: "3B82F6") }
                    }
                    Divider()
                    Button("Delete Folder", role: .destructive) { store.deleteFolder(folder.id) }
                }

                if !folder.isCollapsed {
                    ForEach(folderThreads) { thread in
                        threadRow(thread)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func threadRow(_ thread: ChatThread) -> some View {
        ThreadRow(
            thread: thread,
            isActive: store.activeThreadID == thread.id,
            searchQuery: searchQuery,
            matchCount: searchQuery.isEmpty ? 0 : store.matchCount(searchQuery, in: thread),
            isHoveredForPreview: hoveredThread == thread.id,
            onSelect: { store.activeThreadID = thread.id },
            onDelete: { withAnimation(.easeInOut(duration: 0.2)) { store.delete(thread) } },
            onRename: { store.rename(thread.id, title: $0) },
            onExport: { showExport(thread) },
            onPin: { store.togglePin(thread.id) },
            onAddTag: { store.addTag($0, to: thread.id) },
            onMoveToFolder: { folderID in store.moveThread(thread.id, to: folderID) },
            onQuickExport: { quickExportMarkdown(thread) },
            onQuickExportHTML: { quickExportHTML(thread) },
            onQuickExportJSON: { quickExportJSON(thread) },
            onDuplicate: { store.duplicateThread(thread.id) },
            onShare: { shareThread(thread) },
            onArchive: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if thread.isArchived {
                        store.unarchiveThread(thread.id)
                    } else {
                        store.archiveThread(thread.id)
                    }
                }
            },
            onSetColorLabel: { store.setColorLabel($0, for: thread.id) },
            folders: store.folders
        )
        .onHover { hovering in
            hoveredThread = hovering ? thread.id : nil
        }
    }

    private func shareThread(_ thread: ChatThread) {
        let text = ChatScreen.formatShareText(thread: thread)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        shareToast = "Conversation copied to clipboard"
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            shareToast = ""
        }
    }

    private func quickExportMarkdown(_ thread: ChatThread) {
        guard let md = store.exportAsMarkdown(thread.id) else { return }
        quickSaveToDownloads(thread: thread, content: md, ext: "md")
    }

    private func quickExportHTML(_ thread: ChatThread) {
        guard let html = store.exportAsHTML(thread.id) else { return }
        quickSaveToDownloads(thread: thread, content: html, ext: "html")
    }

    private func quickExportJSON(_ thread: ChatThread) {
        guard let data = store.exportAsJSON(thread.id) else { return }
        let filename = sanitizedFilename(thread.title)
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsURL.appendingPathComponent("\(filename).json")
        do {
            try data.write(to: fileURL)
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: downloadsURL.path)
            exportToast = "Exported to Downloads"
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                exportToast = ""
            }
        } catch {
            exportToast = "Export failed"
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                exportToast = ""
            }
        }
    }

    private func quickSaveToDownloads(thread: ChatThread, content: String, ext: String) {
        let filename = sanitizedFilename(thread.title)
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let fileURL = downloadsURL.appendingPathComponent("\(filename).\(ext)")
        do {
            try content.write(to: fileURL, atomically: true, encoding: .utf8)
            NSWorkspace.shared.selectFile(fileURL.path, inFileViewerRootedAtPath: downloadsURL.path)
            exportToast = "Exported to Downloads"
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                exportToast = ""
            }
        } catch {
            exportToast = "Export failed"
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                exportToast = ""
            }
        }
    }

    private func sanitizedFilename(_ title: String) -> String {
        let sanitized = title
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: ":", with: "-")
            .replacingOccurrences(of: "\\", with: "-")
            .replacingOccurrences(of: "\"", with: "")
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: "?", with: "")
            .replacingOccurrences(of: "<", with: "")
            .replacingOccurrences(of: ">", with: "")
            .replacingOccurrences(of: "|", with: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return sanitized.isEmpty ? "thread" : String(sanitized.prefix(60))
    }

    private func handleImport(_ result: Result<[URL], Error>) {
        guard case .success(let urls) = result else { return }
        var totalImported = 0
        for url in urls {
            guard url.startAccessingSecurityScopedResource() else { continue }
            defer { url.stopAccessingSecurityScopedResource() }
            guard let data = try? Data(contentsOf: url) else { continue }

            if url.pathExtension == "json" {
                totalImported += store.importFromChatGPTJSON(data)
            } else if let text = String(data: data, encoding: .utf8) {
                if url.pathExtension == "md" {
                    totalImported += store.importFromMarkdown(text)
                } else {
                    totalImported += store.importFromPlainText(text)
                }
            }
        }
        if totalImported > 0 {
            importResult = "Imported \(totalImported) thread\(totalImported == 1 ? "" : "s")"
        } else {
            importResult = "No threads found in file"
        }
    }

    private func quickExportPDF(_ thread: ChatThread) {
        guard let markdown = store.exportAsMarkdown(thread.id) else { return }

        let filename = "Thread-\(sanitizedFilename(thread.title)).pdf"
        let panel = NSSavePanel()
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = filename
        panel.directoryURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first

        guard panel.runModal() == .OK, let fileURL = panel.url else {
            return
        }

        do {
            try generatePDF(from: markdown, thread: thread, to: fileURL)
            exportToast = "Exported to PDF"
            NotificationService.shared.notify(
                title: "PDF Export Complete",
                body: thread.title,
                sound: "Glass"
            )
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                exportToast = ""
            }
        } catch {
            exportToast = "PDF export failed"
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                exportToast = ""
            }
        }
    }

    private func generatePDF(from markdown: String, thread: ChatThread, to fileURL: URL) throws {
        // TODO: Implement PDF export without PDFTextView dependency
        // For now, export as markdown with .pdf extension (temporary workaround)
        var markdownWithHeader = "# \(thread.title)\n\n"
        markdownWithHeader += "**Date:** \(DateFormatter.localizedString(from: thread.createdAt, dateStyle: .medium, timeStyle: .short))\n\n---\n\n"
        markdownWithHeader += markdown
        try markdownWithHeader.write(to: fileURL, atomically: true, encoding: .utf8)
    }
}

// MARK: - Export Format Picker

struct ExportFormatPicker: View {
    let thread: ChatThread
    let store: ThreadStore
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: ParietalSpacing.md) {
            Text("Export: \(thread.title)")
                .font(.headline)
                .foregroundStyle(V4Color.textPrimary)
                .lineLimit(1)

            HStack(spacing: ParietalSpacing.sm) {
                exportButton("Markdown", icon: "doc.text", ext: "md") {
                    store.exportAsMarkdown(thread.id)?.data(using: .utf8)
                }
                exportButton("HTML", icon: "globe", ext: "html") {
                    store.exportAsHTML(thread.id)?.data(using: .utf8)
                }
                exportButton("JSON", icon: "curlybraces", ext: "json") {
                    store.exportAsJSON(thread.id)
                }
            }

            Button("Cancel") { onDismiss() }
                .font(WernickeTypography.caption)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                .buttonStyle(.plain)
        }
        .padding(ParietalSpacing.xl)
        .frame(width: ParietalSpacing.xlModalFrame)
        .background(Color(hex: 0x1A1A1A))
    }

    @ViewBuilder
    private func exportButton(_ label: String, icon: String, ext: String, dataProvider: @escaping () -> Data?) -> some View {
        Button {
            guard let data = dataProvider() else { return }
            let panel = NSSavePanel()
            panel.nameFieldStringValue = "\(thread.title.prefix(30)).\(ext)"
            panel.begin { response in
                guard response == .OK, let url = panel.url else { return }
                try? data.write(to: url)
            }
            onDismiss()
        } label: {
            VStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: icon)
                    .font(WernickeTypography.size20)
                Text(label)
                    .font(WernickeTypography.captionMedium)
            }
            .foregroundStyle(V4Color.accent)
            .frame(width: ParietalSpacing.xLargeFrame, height: ParietalSpacing.badgeFrame)
            .background(Color.white.opacity(V2Depth.bgCard))
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Provider Health Dot

struct ProviderDot: View {
    let provider: AIProvider
    @StateObject private var networkLog = NetworkLog.shared
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var pulse = false

    var body: some View {
        let status = networkLog.providerHealth[provider.rawValue]
        let isUp = status?.isUp ?? true

        ZStack {
            if !isUp && !reduceMotion {
                Circle()
                    .stroke(V4Color.error.opacity(V1Theme.opacityTextTertiary), lineWidth: 1)
                    .frame(width: ParietalSpacing.mediumBadge, height: ParietalSpacing.badgeHeight)
                    .scaleEffect(pulse ? 1.8 : 1.0)
                    .opacity(pulse ? 0 : 0.6)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            pulse = true
                        }
                    }
            }
            Circle()
                .fill(isUp ? V4Color.accent : V4Color.error)
                .frame(width: ParietalSpacing.dotSize, height: 6)
        }
        .frame(width: ParietalSpacing.xSmallFrame, height: ParietalSpacing.subtitleHeight)
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
    @State private var showNetworkTimeline = false

    var body: some View {
        let today = networkLog.todayEntries
        guard !today.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(V2Depth.bgCard))
                    .frame(height: ParietalSpacing.dividerHeight)

                // Clickable stats row
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNetworkTimeline.toggle()
                    }
                }) {
                    HStack(spacing: ParietalSpacing.sm) {
                        miniStat("\(today.count)", "reqs")
                        miniStat("\(networkLog.todayTokens / 1000)K", "tok")
                        if networkLog.avgTTFB > 0 {
                            miniStat("\(networkLog.avgTTFB)ms", "TTFB")
                        }
                        if networkLog.avgTokPerSec > 0 {
                            miniStat(String(format: "%.0f", networkLog.avgTokPerSec), "tok/s")
                        }
                        Spacer()
                        Image(systemName: showNetworkTimeline ? "chevron.down" : "chevron.right")
                            .font(WernickeTypography.size8.weight(.semibold))
                            .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                    }
                    .padding(.horizontal, ParietalSpacing.md)
                    .padding(.vertical, ParietalSpacing.xxxs)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                // Expandable timeline
                if showNetworkTimeline {
                    NetworkTimelineView(networkLog: networkLog)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        )
    }

    private func miniStat(_ value: String, _ label: String) -> some View {
        VStack(spacing: ParietalSpacing.xxxxs) {
            Text(value)
                .font(WernickeTypography.mini.monospaced())
                .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
            Text(label)
                .font(WernickeTypography.size8)
                .foregroundStyle(V2Depth.white(0.25))
        }
    }
}

// MARK: - Network Timeline View

struct NetworkTimelineView: View {
    @ObservedObject var networkLog: NetworkLog

    private var recentEntries: [NetworkLog.Entry] {
        Array(networkLog.todayEntries.suffix(20).reversed())
    }

    private var maxTotalMs: Int {
        recentEntries.map(\.totalMs).max() ?? 1
    }

    private var summaryText: String {
        let today = networkLog.todayEntries
        let totalTokens = networkLog.todayTokens
        let avgMs = today.isEmpty ? 0 : today.reduce(0) { $0 + $1.totalMs } / today.count
        let cost = networkLog.todayCostEstimate()
        return "Today: \(today.count) requests \u{00B7} \(totalTokens / 1000)K tokens \u{00B7} avg \(formatDuration(avgMs)) \u{00B7} $\(String(format: "%.2f", cost))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            // Summary line
            Text(summaryText)
                .font(WernickeTypography.microMono)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.top, 4)

            Rectangle()
                .fill(Color.white.opacity(V2Depth.bgCardLight))
                .frame(height: ParietalSpacing.dividerHeight)
                .padding(.horizontal, ParietalSpacing.sm)

            // Timeline rows
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(recentEntries) { entry in
                        timelineRow(entry)
                    }
                }
                .padding(.horizontal, ParietalSpacing.sm)
            }
            .frame(maxHeight: 260)
            .padding(.bottom, 4)
        }
        .background(V4Color.surface.opacity(V2Depth.stateDisabled))
    }

    private func timelineRow(_ entry: NetworkLog.Entry) -> some View {
        let barFraction = maxTotalMs > 0 ? CGFloat(entry.totalMs) / CGFloat(maxTotalMs) : 0
        let ttfbFraction = entry.totalMs > 0 ? CGFloat(entry.ttfbMs) / CGFloat(entry.totalMs) : 0
        let barColor = statusColor(entry.status)
        let modelShort = shortModelName(entry.model)
        let providerIcon = providerSymbol(entry.provider)

        return HStack(spacing: ParietalSpacing.xs) {
            // Left label: provider icon + model
            HStack(spacing: 2) {
                Text(providerIcon)
                    .font(WernickeTypography.size8)
                Text(modelShort)
                    .font(WernickeTypography.microMono)
                    .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
            }
            .frame(width: ParietalSpacing.badgeFrame, alignment: .leading)

            // Bar chart
            GeometryReader { geo in
                let barWidth = max(geo.size.width * barFraction, 2)
                let ttfbX = barWidth * ttfbFraction

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(V2Depth.bgCardLight))
                        .frame(width: geo.size.width, height: ParietalSpacing.badgeHeight)

                    // Duration bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor.opacity(V1Theme.opacityTextSecondary))
                        .frame(width: barWidth, height: ParietalSpacing.badgeHeight)

                    // TTFB tick mark
                    if entry.ttfbMs > 0 && ttfbX > 2 {
                        Rectangle()
                            .fill(V4Color.white80)
                            .frame(width: ParietalSpacing.hairline, height: ParietalSpacing.badgeHeight)
                            .offset(x: ttfbX)
                    }
                }
            }
            .frame(height: ParietalSpacing.badgeHeight)

            // Right label: duration
            Text("\(entry.totalMs)ms")
                .font(WernickeTypography.microMono)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                .frame(width: ParietalSpacing.avatarMediumFrame, alignment: .trailing)
        }
        .frame(height: ParietalSpacing.iconHeight)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "ok": return V4Color.statusOK
        case "timeout": return V4Color.warning
        case "error": return V4Color.error
        default: return Color.white.opacity(V2Depth.stateHover)
        }
    }

    private func providerSymbol(_ provider: String) -> String {
        switch provider.lowercased() {
        case "anthropic": return "A"
        case "z.ai": return "Z"
        case "perplexity": return "P"
        case "xai": return "X"
        case "openai": return "O"
        default: return String(provider.prefix(1)).uppercased()
        }
    }

    private func shortModelName(_ model: String) -> String {
        // Shorten common model names
        var s = model
        s = s.replacingOccurrences(of: "claude-", with: "c-")
        s = s.replacingOccurrences(of: "sonnet", with: "son")
        s = s.replacingOccurrences(of: "opus", with: "ops")
        s = s.replacingOccurrences(of: "haiku", with: "hku")
        s = s.replacingOccurrences(of: "gpt-4o", with: "4o")
        if s.count > 10 { s = String(s.prefix(10)) }
        return s
    }

    private func formatDuration(_ ms: Int) -> String {
        if ms >= 1000 {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }
        return "\(ms)ms"
    }
}

// MARK: - Thread Row

struct ThreadRow: View {
    let thread: ChatThread
    let isActive: Bool
    let searchQuery: String
    var matchCount: Int = 0
    var isHoveredForPreview: Bool = false
    let onSelect: () -> Void
    let onDelete: () -> Void
    let onRename: (String) -> Void
    let onExport: () -> Void
    let onPin: () -> Void
    let onAddTag: (String) -> Void
    var onMoveToFolder: ((UUID?) -> Void)? = nil
    var onQuickExport: (() -> Void)? = nil
    var onQuickExportHTML: (() -> Void)? = nil
    var onQuickExportJSON: (() -> Void)? = nil
    var onDuplicate: (() -> Void)? = nil
    var onShare: (() -> Void)? = nil
    var onArchive: (() -> Void)? = nil
    var onSetColorLabel: ((String?) -> Void)? = nil
    var folders: [ThreadFolder] = []

    @State private var isHovered = false
    @State private var isRenaming = false
    @State private var renameText = ""
    @State private var showDeleteConfirm = false

    static let labelColors: [String: Color] = [
        "red": .red, "orange": .orange, "yellow": .yellow,
        "green": .green, "blue": .blue, "purple": .purple,
    ]
    static let labelColorNames: [(String, Color)] = [
        ("red", .red), ("orange", .orange), ("yellow", .yellow),
        ("green", .green), ("blue", .blue), ("purple", .purple),
    ]

    /// Preview text: first user message (truncated)
    private var previewText: String? {
        guard let first = thread.messages.first(where: { $0.role == .user }) else { return nil }
        let text = first.text.trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : String(text.prefix(120))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: ParietalSpacing.xs) {
                // Color label dot
                if let label = thread.colorLabel, let c = Self.labelColors[label] {
                    Circle().fill(c).frame(width: ParietalSpacing.dotSize, height: 6)
                }

                // Pin indicator
                if thread.isPinned {
                    Image(systemName: "pin.fill")
                        .font(WernickeTypography.size8)
                        .foregroundStyle(V4Color.golden)
                        .rotationEffect(.degrees(45))
                        .accessibilityLabel("Pinned thread")
                }

                if isRenaming {
                    TextField("Thread name", text: $renameText)
                        .textFieldStyle(.plain)
                        .font(WernickeTypography.small)
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
                            (Text(before) + Text(match).foregroundColor(V4Color.accent).bold() + Text(after))
                                .font(WernickeTypography.small)
                                .foregroundStyle(isActive ? Color.white : Color.white.opacity(V1Theme.opacityTextSecondary))
                                .lineLimit(1)
                        } else {
                            Text(thread.title)
                                .font(WernickeTypography.small)
                                .foregroundStyle(isActive ? Color.white : Color.white.opacity(V1Theme.opacityTextSecondary))
                                .lineLimit(1)
                        }

                        // Summary preview (shown when not searching)
                        if searchQuery.isEmpty, let summary = thread.summary {
                            Text(summary)
                                .font(.caption2)
                                .foregroundStyle(V4Color.textSecondary)
                                .opacity(V1Theme.opacityTextSecondary)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .help(summary)
                        }

                        HStack(spacing: ParietalSpacing.xs) {
                            ForEach(thread.tags.prefix(2), id: \.self) { tag in
                                Text("#\(tag)")
                                    .font(WernickeTypography.size8.weight(.medium))
                                    .foregroundStyle(V4Color.purple)
                                    .padding(.horizontal, ParietalSpacing.xxxs)
                                    .padding(.vertical, 1)
                                    .background(V4Color.purple.opacity(V2Depth.bgSubtle))
                                    .clipShape(SwiftUI.Capsule())
                            }
                            if !searchQuery.isEmpty && matchCount > 0 {
                                Text("\(matchCount) match\(matchCount == 1 ? "" : "es")")
                                    .font(WernickeTypography.size8.weight(.bold))
                                    .foregroundStyle(V4Color.accent)
                            }
                            if tokenData.count >= 4 {
                                TokenSparkline(data: tokenData)
                            }
                            Text("\(thread.messages.count) msgs")
                                .font(WernickeTypography.micro)
                                .foregroundStyle(V2Depth.white(0.25))
                            Text(relativeDate(thread.updatedAt))
                                .font(WernickeTypography.micro)
                                .foregroundStyle(V4Color.white20)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                if isHovered && !isRenaming {
                    Button(action: { isRenaming = true }) {
                        Image(systemName: "pencil")
                            .font(WernickeTypography.mini)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                    .accessibilityLabel("Rename thread")

                    Button(action: onExport) {
                        Image(systemName: "square.and.arrow.up")
                            .font(WernickeTypography.mini)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                    .help("Export as Markdown")
                    .accessibilityLabel("Export thread")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(WernickeTypography.mini)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(V4Color.error.opacity(V1Theme.opacityTextSecondary))
                    .accessibilityLabel("Delete thread")
                }
            }

            // Thread preview on hover (first message snippet)
            if isHoveredForPreview && !isActive && !isRenaming, let preview = previewText {
                Text(preview)
                    .font(WernickeTypography.mini)
                    .foregroundStyle(V4Color.white35)
                    .lineLimit(2)
                    .padding(.top, 3)
                    .transition(.opacity)
            }
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(
                    isActive ? V4Color.accent.opacity(V2Depth.bgSubtle) :
                    isHovered ? Color.white.opacity(V2Depth.bgCardLight) : Color.clear
                )
        )
        .padding(.horizontal, ParietalSpacing.xs)
        .onTapGesture { onSelect() }
        .onHover { isHovered = $0 }
        .contextMenu {
            Button(thread.isPinned ? "Unpin" : "Pin") { onPin() }
            Button("Rename") { isRenaming = true }
            Button("Export...") { onExport() }
            Menu("Quick Export") {
                Button("Markdown") { onQuickExport?() }
                Button("HTML") { onQuickExportHTML?() }
                Button("JSON") { onQuickExportJSON?() }
            }
            Button {
                onShare?()
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }
            Button("Duplicate") { onDuplicate?() }
            Menu("Add Tag") {
                ForEach(["hslm", "fpga", "patent", "research", "sevo", "arena", "bug", "feature"], id: \.self) { tag in
                    Button("#\(tag)") { onAddTag(tag) }
                }
            }
            Menu("Label") {
                ForEach(Self.labelColorNames, id: \.0) { name, color in
                    Button {
                        onSetColorLabel?(name)
                    } label: {
                        Label(name.capitalized, systemImage: thread.colorLabel == name ? "checkmark.circle.fill" : "circle.fill")
                    }
                    .tint(color)
                }
                Divider()
                Button("None") { onSetColorLabel?(nil) }
            }
            if !folders.isEmpty {
                Menu("Move to Folder") {
                    ForEach(folders) { folder in
                        Button(folder.name) { onMoveToFolder?(folder.id) }
                    }
                    Divider()
                    Button("Uncategorized") { onMoveToFolder?(nil) }
                }
            }
            if let onArchive = onArchive {
                Button(thread.isArchived ? "Unarchive" : "Archive") { onArchive() }
            }
            Divider()
            Button("Delete", role: .destructive) { showDeleteConfirm = true }
        }
        .alert("Delete Thread?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) { onDelete() }
        } message: {
            Text("Delete \"\(thread.title)\"? This cannot be undone.")
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(thread.title), \(thread.messages.count) messages, \(relativeDate(thread.updatedAt))")
        .accessibilityHint("Double-tap to open thread")
    }

    private var tokenData: [Int] {
        thread.messages.compactMap { $0.role == .assistant ? $0.outputTokens : nil }
    }

    private func relativeDate(_ date: Date) -> String {
        let delta = Int(Date().timeIntervalSince(date))
        if delta < 60 { return "now" }
        if delta < 3600 { return "\(delta / 60)m" }
        if delta < 86400 { return "\(delta / 3600)h" }
        return "\(delta / 86400)d"
    }
}

// MARK: - Token Sparkline

private struct TokenSparkline: View {
    let data: [Int]

    private var totalLabel: String {
        let sum = data.reduce(0, +)
        return sum >= 1000 ? "\(String(format: "%.1f", Double(sum) / 1000))K tokens" : "\(sum) tokens"
    }

    var body: some View {
        let maxVal = data.max() ?? 1
        Canvas { ctx, size in
            let barW: CGFloat = 2
            let gap: CGFloat = 1
            let count = data.count
            let totalW = CGFloat(count) * barW + CGFloat(count - 1) * gap
            let offsetX = max(0, (size.width - totalW) / 2)
            for (i, val) in data.enumerated() {
                let h = size.height * CGFloat(val) / CGFloat(maxVal)
                let x = offsetX + CGFloat(i) * (barW + gap)
                let rect = CGRect(x: x, y: size.height - h, width: barW, height: max(1, h))
                ctx.fill(Path(roundedRect: rect, cornerRadius: 0.5),
                         with: .color(V4Color.accent.opacity(V1Theme.opacityTextSecondary)))
            }
        }
        .frame(width: ParietalSpacing.touchFrame, height: ParietalSpacing.touchFrame)
        .help("Total: \(totalLabel)")
    }
}

// MARK: - Realm Section Header

struct RealmHeader: View {
    let realm: Kingdom
    let count: Int
    @Binding var isExpanded: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var realmColor: Color {
        switch realm {
        case .brain: return V4Color.purple
        case .body: return V4Color.accent
        case .spirit: return V4Color.golden
        }
    }

    private var realmIcon: String {
        switch realm {
        case .brain: return "brain.head.profile"
        case .body: return "figure.strengthtraining.traditional"
        case .spirit: return "sparkles"
        }
    }

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: reduceMotion ? 0 : 0.2)) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(WernickeTypography.size8.weight(.bold))
                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))

                Text(realm.icon)
                    .font(WernickeTypography.caption2)

                Text("\(realm.rawValue.uppercased())")
                    .font(WernickeTypography.title3Bold)
                    .foregroundStyle(realmColor)

                Spacer()

                Text("\(count)")
                    .font(WernickeTypography.micro.monospaced())
                    .foregroundStyle(V4Color.white20)
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.top, 12)
            .padding(.bottom, 6)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(realm.rawValue) realm, \(count) threads")
        .accessibilityHint(isExpanded ? "Tap to collapse" : "Tap to expand")

        RealmDivider(color: realmColor)
    }
}

struct RealmDivider: View {
    let color: Color

    var body: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    gradient: Gradient(colors: [
                        color.opacity(0),
                        color.opacity(V2Depth.stateHover),
                        color.opacity(0)
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: ParietalSpacing.dividerHeight)
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.bottom, 4)
    }
}

// MARK: - Skeleton Thread Row (shimmer loading placeholder)

struct SkeletonThreadRow: View {
    let index: Int
    @State private var shimmer = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Vary widths to look natural
    private var titleWidth: CGFloat {
        [0.85, 0.6, 0.75, 0.5, 0.9][index % 5]
    }
    private var subtitleWidth: CGFloat {
        [0.5, 0.35, 0.45, 0.3, 0.55][index % 5]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(V2Depth.bgCard))
                .frame(height: ParietalSpacing.badgeHeight)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(x: titleWidth, y: 1, anchor: .leading)
            HStack(spacing: ParietalSpacing.sm) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(V2Depth.bgCardLight))
                    .frame(height: ParietalSpacing.smallBadgeHeight)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: subtitleWidth, y: 1, anchor: .leading)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.03))
                    .frame(width: ParietalSpacing.cellFrame, height: ParietalSpacing.smallBadgeHeight)
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.md)
        .opacity(shimmer ? 0.7 : 0.3)
        .animation(
            reduceMotion ? nil : .easeInOut(duration: 1.0)
                .repeatForever(autoreverses: true)
                .delay(Double(index) * 0.1),
            value: shimmer
        )
        .onAppear { shimmer = true }
    }
}
