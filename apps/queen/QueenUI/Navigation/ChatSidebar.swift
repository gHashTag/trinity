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
    @AppStorage("threadSortOrder") private var sortOrder: String = "date"

    /// Number of active metadata filters
    private var activeFilterCount: Int {
        var count = 0
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
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .menuStyle(.borderlessButton)
                .frame(width: 20)
                .help("Sort threads")
                .accessibilityLabel("Sort threads, currently by \(sortOrder)")

                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        isSearching.toggle()
                        if !isSearching {
                            searchQuery = ""
                            filterDateRange = .all
                            filterModel = nil
                        }
                    }
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Image(systemName: isSearching ? "xmark" : "magnifyingglass")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.white.opacity(0.4))
                        if !isSearching && activeFilterCount > 0 {
                            Text("\(activeFilterCount)")
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.black)
                                .frame(width: 12, height: 12)
                                .background(TrinityTheme.accent)
                                .clipShape(Circle())
                                .offset(x: 4, y: -4)
                        }
                    }
                }
                .buttonStyle(.plain)
                .help("Search threads (Cmd+Shift+F)")
                .accessibilityLabel(isSearching ? "Close search" : "Search threads")
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
                .padding(.bottom, 4)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))

                // Metadata filter chips
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 4) {
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
                                filterDateRange = .all
                                filterModel = nil
                            } label: {
                                HStack(spacing: 2) {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(.system(size: 9))
                                    Text("Clear")
                                        .font(.system(size: 10, weight: .medium))
                                }
                                .foregroundStyle(TrinityTheme.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 3)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 2)
                }
                .padding(.bottom, 4)
            }

            // New Thread + Import buttons
            HStack(spacing: 4) {
                Button(action: { store.newThread() }) {
                    HStack(spacing: 6) {
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
                .accessibilityLabel("New thread")

                Button { showImportPicker = true } label: {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .help("Import conversations")
                .accessibilityLabel("Import conversations")

                Button { showNewFolderAlert = true } label: {
                    Image(systemName: "folder.badge.plus")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.4))
                        .padding(8)
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
                        .font(.system(size: 11))
                        .foregroundStyle(showBookmarks ? TrinityTheme.golden : Color.white.opacity(store.allBookmarks().isEmpty ? 0.2 : 0.4))
                        .padding(8)
                }
                .buttonStyle(.plain)
                .help(store.allBookmarks().isEmpty ? "No bookmarks" : "Bookmarks (\(store.allBookmarks().count))")
            }
            .padding(.horizontal, 8)
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
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Bookmarks panel
            if showBookmarks {
                bookmarksPanel
            }

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

            // Import result banner
            if !importResult.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(TrinityTheme.statusOK)
                    Text(importResult)
                        .font(.system(size: 10))
                        .foregroundStyle(TrinityTheme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(TrinityTheme.statusOK.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 8)
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
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TrinityTheme.accent)
                    if activeFilterCount > 0 {
                        Text("(\(activeFilterCount) filter\(activeFilterCount == 1 ? "" : "s"))")
                            .font(.system(size: 10))
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
            }

            // Export toast
            if !exportToast.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(TrinityTheme.statusOK)
                    Text(exportToast)
                        .font(.system(size: 10))
                        .foregroundStyle(TrinityTheme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(TrinityTheme.statusOK.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 8)
                .transition(.opacity)
            }

            // Share toast
            if !shareToast.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(TrinityTheme.statusOK)
                    Text(shareToast)
                        .font(.system(size: 10))
                        .foregroundStyle(TrinityTheme.textPrimary)
                    Spacer()
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 4)
                .background(TrinityTheme.statusOK.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 6))
                .padding(.horizontal, 8)
                .transition(.opacity)
            }

            // Archive suggestion banner
            if store.showArchiveSuggestion {
                HStack(spacing: 8) {
                    Text("\u{1F4E6} \(store.staleThreads.count) thread\(store.staleThreads.count == 1 ? "" : "s") older than 90 days")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                    Spacer()
                    Button("Archive All") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.archiveAllStale()
                        }
                    }
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TrinityTheme.accent)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Archive all stale threads")
                    Button("Dismiss") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.showArchiveSuggestion = false
                        }
                    }
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(TrinityTheme.accent.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 8)
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

                    // Uncategorized threads (no folder) — grouped by date
                    let uncategorized = filteredThreads.filter { $0.folderID == nil }
                    if !uncategorized.isEmpty && !store.folders.isEmpty {
                        HStack {
                            Image(systemName: "tray")
                                .font(.system(size: 9))
                                .foregroundStyle(Color.white.opacity(0.3))
                            Text("Uncategorized")
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.3))
                            Spacer()
                            Text("\(uncategorized.count)")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(Color.white.opacity(0.2))
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)
                        .padding(.bottom, 4)
                    }

                    // Date-grouped threads (uncategorized or all if no folders)
                    let threadsToGroup = store.folders.isEmpty ? filteredThreads : uncategorized
                    ForEach(groupThreadsByDate(threadsToGroup), id: \.0) { groupName, threads in
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
                            threadRow(thread)
                        }
                    }

                    // Empty state: no threads at all (after loading)
                    if store.isLoaded && store.threads.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "bubble.left.and.bubble.right")
                                .font(.system(size: 28))
                                .foregroundStyle(TrinityTheme.textMuted)
                            Text("No conversations yet")
                                .font(.system(size: 13))
                                .foregroundStyle(TrinityTheme.textMuted)
                            Button {
                                store.newThread()
                            } label: {
                                HStack(spacing: 4) {
                                    Image(systemName: "plus")
                                        .font(.system(size: 11, weight: .semibold))
                                    Text("New Thread")
                                        .font(.system(size: 12, weight: .medium))
                                }
                                .foregroundStyle(TrinityTheme.accent)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 7)
                                .background(TrinityTheme.accent.opacity(0.12))
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
                        VStack(spacing: 10) {
                            Image(systemName: "magnifyingglass")
                                .font(.system(size: 24))
                                .foregroundStyle(TrinityTheme.textMuted)
                            if !debouncedQuery.isEmpty {
                                Text("No matches for '\(debouncedQuery)'")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TrinityTheme.textMuted)
                                    .multilineTextAlignment(.center)
                                Text("Try broader terms")
                                    .font(.caption2)
                                    .foregroundStyle(Color.white.opacity(0.25))
                            } else if activeFilterCount > 0 {
                                Text("No matches with current filters")
                                    .font(.system(size: 12))
                                    .foregroundStyle(TrinityTheme.textMuted)
                                Button {
                                    filterDateRange = .all
                                    filterModel = nil
                                } label: {
                                    Text("Clear filters")
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(TrinityTheme.accent)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 5)
                                        .background(TrinityTheme.accent.opacity(0.12))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
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
                            HStack(spacing: 6) {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.15)) {
                                        showArchiveSection.toggle()
                                    }
                                } label: {
                                    Image(systemName: showArchiveSection ? "chevron.down" : "chevron.right")
                                        .font(.system(size: 8, weight: .bold))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                }
                                .buttonStyle(.plain)

                                Image(systemName: "archivebox")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                Text("Archive")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                Spacer()
                                Text("\(store.archivedThreads.count)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.2))
                            }
                            .padding(.horizontal, 16)
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
                .padding(.vertical, 2)
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
                HStack(spacing: 10) {
                    Image(systemName: "trash")
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.5))
                    Text("Thread deleted")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                    Spacer()
                    Button("Undo") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            store.undoDelete()
                        }
                    }
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(TrinityTheme.accent)
                    .buttonStyle(.plain)
                    .accessibilityLabel("Undo delete")
                    .accessibilityHint("Restores the deleted thread")
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
                .padding(.horizontal, 8)
                .padding(.bottom, 4)
                .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
            }

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
                if !isSearching {
                    searchQuery = ""; debouncedQuery = ""
                    filterDateRange = .all; filterModel = nil
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
            HStack(spacing: 6) {
                Image(systemName: "bookmark.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(TrinityTheme.golden)
                Text("Bookmarks")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)
                Spacer()
                Text("\(store.allBookmarks().count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TrinityTheme.textMuted)
                Button {
                    withAnimation(.easeInOut(duration: 0.15)) {
                        showBookmarks = false
                    }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)

            let groups = groupedBookmarks()

            if groups.isEmpty {
                // Empty state
                VStack(spacing: 8) {
                    Image(systemName: "bookmark.slash")
                        .font(.system(size: 20))
                        .foregroundStyle(TrinityTheme.textMuted)
                    Text("No bookmarked messages yet")
                        .font(.system(size: 11))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(groups, id: \.thread.id) { group in
                            // Thread header
                            HStack(spacing: 4) {
                                Image(systemName: "bubble.left")
                                    .font(.system(size: 8))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                Text(group.thread.title)
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .lineLimit(1)
                                Spacer()
                                Text("\(group.messages.count)")
                                    .font(.system(size: 9, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.2))
                            }
                            .padding(.horizontal, 12)
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
                                    HStack(alignment: .top, spacing: 6) {
                                        Image(systemName: "bookmark.fill")
                                            .font(.system(size: 8))
                                            .foregroundStyle(TrinityTheme.golden.opacity(0.6))
                                            .padding(.top, 2)
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(String(msg.text.prefix(80)))
                                                .font(.system(size: 11))
                                                .foregroundStyle(TrinityTheme.textPrimary)
                                                .lineLimit(2)
                                                .multilineTextAlignment(.leading)
                                            Text(msg.timestamp, style: .relative)
                                                .font(.system(size: 9))
                                                .foregroundStyle(TrinityTheme.textMuted)
                                        }
                                        Spacer()
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 5)
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
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)
        }
        .background(TrinityTheme.bgCard.opacity(0.5))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func filterPill(label: String, isActive: Bool) -> some View {
        HStack(spacing: 3) {
            Text(label)
                .font(.system(size: 10, weight: isActive ? .bold : .medium))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 7, weight: .bold))
        }
        .foregroundStyle(isActive ? .black : TrinityTheme.textMuted)
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(isActive ? TrinityTheme.accent : Color.white.opacity(0.06))
        .clipShape(Capsule())
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
                HStack(spacing: 6) {
                    Button {
                        store.toggleFolderCollapse(folder.id)
                    } label: {
                        Image(systemName: folder.isCollapsed ? "chevron.right" : "chevron.down")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)

                    Image(systemName: "folder.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(folder.swiftColor)
                    Text(folder.name)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(folder.swiftColor)
                    Spacer()
                    Text("\(folderThreads.count)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.2))
                }
                .padding(.horizontal, 16)
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
}

// MARK: - Export Format Picker

struct ExportFormatPicker: View {
    let thread: ChatThread
    let store: ThreadStore
    let onDismiss: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Export: \(thread.title)")
                .font(.headline)
                .foregroundStyle(TrinityTheme.textPrimary)
                .lineLimit(1)

            HStack(spacing: 12) {
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
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.4))
                .buttonStyle(.plain)
        }
        .padding(24)
        .frame(width: 360)
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
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                Text(label)
                    .font(.system(size: 12, weight: .medium))
            }
            .foregroundStyle(TrinityTheme.accent)
            .frame(width: 80, height: 70)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
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
    @State private var showNetworkTimeline = false

    var body: some View {
        let today = networkLog.todayEntries
        guard !today.isEmpty else { return AnyView(EmptyView()) }

        return AnyView(
            VStack(spacing: 0) {
                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 1)

                // Clickable stats row
                Button(action: {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNetworkTimeline.toggle()
                    }
                }) {
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
                        Image(systemName: showNetworkTimeline ? "chevron.down" : "chevron.right")
                            .font(.system(size: 8, weight: .semibold))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 6)
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
        VStack(alignment: .leading, spacing: 4) {
            // Summary line
            Text(summaryText)
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.4))
                .padding(.horizontal, 16)
                .padding(.top, 4)

            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
                .padding(.horizontal, 12)

            // Timeline rows
            ScrollView(.vertical, showsIndicators: false) {
                VStack(spacing: 2) {
                    ForEach(recentEntries) { entry in
                        timelineRow(entry)
                    }
                }
                .padding(.horizontal, 12)
            }
            .frame(maxHeight: 260)
            .padding(.bottom, 4)
        }
        .background(TrinityTheme.bgCard.opacity(0.5))
    }

    private func timelineRow(_ entry: NetworkLog.Entry) -> some View {
        let barFraction = maxTotalMs > 0 ? CGFloat(entry.totalMs) / CGFloat(maxTotalMs) : 0
        let ttfbFraction = entry.totalMs > 0 ? CGFloat(entry.ttfbMs) / CGFloat(entry.totalMs) : 0
        let barColor = statusColor(entry.status)
        let modelShort = shortModelName(entry.model)
        let providerIcon = providerSymbol(entry.provider)

        return HStack(spacing: 4) {
            // Left label: provider icon + model
            HStack(spacing: 2) {
                Text(providerIcon)
                    .font(.system(size: 8))
                Text(modelShort)
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
            }
            .frame(width: 70, alignment: .leading)

            // Bar chart
            GeometryReader { geo in
                let barWidth = max(geo.size.width * barFraction, 2)
                let ttfbX = barWidth * ttfbFraction

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.04))
                        .frame(width: geo.size.width, height: 12)

                    // Duration bar
                    RoundedRectangle(cornerRadius: 2)
                        .fill(barColor.opacity(0.6))
                        .frame(width: barWidth, height: 12)

                    // TTFB tick mark
                    if entry.ttfbMs > 0 && ttfbX > 2 {
                        Rectangle()
                            .fill(Color.white.opacity(0.8))
                            .frame(width: 1, height: 12)
                            .offset(x: ttfbX)
                    }
                }
            }
            .frame(height: 12)

            // Right label: duration
            Text("\(entry.totalMs)ms")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(Color.white.opacity(0.4))
                .frame(width: 48, alignment: .trailing)
        }
        .frame(height: 20)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "ok": return TrinityTheme.statusOK
        case "timeout": return TrinityTheme.statusWarn
        case "error": return TrinityTheme.statusError
        default: return Color.white.opacity(0.3)
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
            HStack(spacing: 4) {
                // Color label dot
                if let label = thread.colorLabel, let c = Self.labelColors[label] {
                    Circle().fill(c).frame(width: 6, height: 6)
                }

                // Pin indicator
                if thread.isPinned {
                    Image(systemName: "pin.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(TrinityTheme.golden)
                        .rotationEffect(.degrees(45))
                        .accessibilityLabel("Pinned thread")
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

                        // Summary preview (shown when not searching)
                        if searchQuery.isEmpty, let summary = thread.summary {
                            Text(summary)
                                .font(.caption2)
                                .foregroundStyle(TrinityTheme.textMuted)
                                .opacity(0.6)
                                .lineLimit(1)
                                .truncationMode(.tail)
                                .help(summary)
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
                            if !searchQuery.isEmpty && matchCount > 0 {
                                Text("\(matchCount) match\(matchCount == 1 ? "" : "es")")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundStyle(TrinityTheme.accent)
                            }
                            if tokenData.count >= 4 {
                                TokenSparkline(data: tokenData)
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
                    .accessibilityLabel("Rename thread")

                    Button(action: onExport) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(Color.white.opacity(0.4))
                    .help("Export as Markdown")
                    .accessibilityLabel("Export thread")

                    Button(action: onDelete) {
                        Image(systemName: "trash")
                            .font(.system(size: 10))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(TrinityTheme.statusError.opacity(0.6))
                    .accessibilityLabel("Delete thread")
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
                         with: .color(TrinityTheme.accent.opacity(0.6)))
            }
        }
        .frame(width: 30, height: 12)
        .help("Total: \(totalLabel)")
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
        VStack(alignment: .leading, spacing: 6) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color.white.opacity(0.06))
                .frame(height: 12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .scaleEffect(x: titleWidth, y: 1, anchor: .leading)
            HStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.04))
                    .frame(height: 9)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scaleEffect(x: subtitleWidth, y: 1, anchor: .leading)
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color.white.opacity(0.03))
                    .frame(width: 36, height: 9)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
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
