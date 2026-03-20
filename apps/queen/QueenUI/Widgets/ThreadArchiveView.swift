import SwiftUI
import AppKit
import UniformTypeIdentifiers

// MARK: - Archived Thread Model

struct ArchivedThread: Identifiable, Codable, Equatable {
    let id: UUID
    let originalThreadID: UUID
    let title: String
    let messageCount: Int
    let createdAt: Date
    let archivedAt: Date
    let tags: [String]
    let summary: String?
    let folderID: UUID?
    let colorLabel: String?

    init(from thread: ChatThread) {
        self.id = UUID()
        self.originalThreadID = thread.id
        self.title = thread.title
        self.messageCount = thread.messages.count
        self.createdAt = thread.createdAt
        self.archivedAt = Date()
        self.tags = thread.tags
        self.summary = thread.summary
        self.folderID = thread.folderID
        self.colorLabel = thread.colorLabel
    }

    init(
        id: UUID = UUID(),
        originalThreadID: UUID,
        title: String,
        messageCount: Int,
        createdAt: Date,
        archivedAt: Date = Date(),
        tags: [String] = [],
        summary: String? = nil,
        folderID: UUID? = nil,
        colorLabel: String? = nil
    ) {
        self.id = id
        self.originalThreadID = originalThreadID
        self.title = title
        self.messageCount = messageCount
        self.createdAt = createdAt
        self.archivedAt = archivedAt
        self.tags = tags
        self.summary = summary
        self.folderID = folderID
        self.colorLabel = colorLabel
    }

    /// Check if archive is older than the retention period (default 30 days)
    func isExpired(retentionDays: Int = 30) -> Bool {
        let expiration = Calendar.current.date(
            byAdding: .day,
            value: -retentionDays,
            to: Date()
        ) ?? Date()
        return archivedAt < expiration
    }

    static func == (lhs: ArchivedThread, rhs: ArchivedThread) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Archive Store

@MainActor
class ArchiveStore: ObservableObject {
    @Published var archivedThreads: [ArchivedThread] = []
    private let saveURL: URL
    private let retentionDays = 30

    // UserDefaults keys for quick access
    private let archivedIDsKey = "archivedThreadIDs"

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let trinityDir = appSupport.appendingPathComponent("Trinity")
        let archiveDir = trinityDir.appendingPathComponent("Archives")

        try? FileManager.default.createDirectory(
            at: archiveDir,
            withIntermediateDirectories: true
        )

        saveURL = archiveDir.appendingPathComponent("archive.json")
        load()
        purgeExpired()
    }

    // MARK: - Persistence

    func load() {
        guard let data = try? Data(contentsOf: saveURL) else {
            archivedThreads = []
            return
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        archivedThreads = (try? decoder.decode([ArchivedThread].self, from: data)) ?? []
    }

    func save() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(archivedThreads) else { return }
        try? data.write(to: saveURL)
        syncUserDefaults()
    }

    /// Sync archived thread IDs to UserDefaults for quick lookup
    private func syncUserDefaults() {
        let ids = archivedThreads.map { $0.originalThreadID.uuidString }
        UserDefaults.standard.set(ids, forKey: archivedIDsKey)
    }

    /// Check if a thread is archived (by original thread ID)
    func isArchived(threadID: UUID) -> Bool {
        return archivedThreads.contains { $0.originalThreadID == threadID }
    }

    /// Get archived thread by original thread ID
    func archivedThread(for threadID: UUID) -> ArchivedThread? {
        return archivedThreads.first { $0.originalThreadID == threadID }
    }

    // MARK: - Archive Operations

    /// Archive a thread
    func archive(_ thread: ChatThread) {
        let archived = ArchivedThread(from: thread)
        archivedThreads.append(archived)
        save()
        SoundCueManager.shared.playSend()
    }

    /// Archive multiple threads at once
    func archiveMultiple(_ threads: [ChatThread]) {
        let newArchives = threads.map { ArchivedThread(from: $0) }
        archivedThreads.append(contentsOf: newArchives)
        save()
        SoundCueManager.shared.playSend()
    }

    /// Restore an archived thread (returns the original thread ID for re-adding to main list)
    func restore(threadID: UUID) -> UUID? {
        if let index = archivedThreads.firstIndex(where: { $0.originalThreadID == threadID }) {
            archivedThreads.remove(at: index)
            save()
            SoundCueManager.shared.playReceive()
            return threadID
        }
        return nil
    }

    /// Permanently delete an archived thread by archive ID
    func permanentlyDelete(id: UUID) {
        archivedThreads.removeAll { $0.id == id }
        save()
        SoundCueManager.shared.playError()
    }

    /// Permanently delete an archived thread by original thread ID
    func permanentlyDelete(threadID: UUID) {
        archivedThreads.removeAll { $0.originalThreadID == threadID }
        save()
        SoundCueManager.shared.playError()
    }

    /// Permanently delete all archived threads
    func deleteAll() {
        archivedThreads.removeAll()
        save()
        SoundCueManager.shared.playError()
    }

    // MARK: - Auto-Purge

    /// Remove archives older than retention period
    @discardableResult
    func purgeExpired() -> Int {
        let before = archivedThreads.count
        archivedThreads.removeAll { $0.isExpired(retentionDays: retentionDays) }
        let removed = before - archivedThreads.count
        if removed > 0 {
            save()
        }
        return removed
    }

    // MARK: - Export

    /// Export archive list as JSON
    func exportAsJSON() -> String {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

        guard let data = try? encoder.encode(archivedThreads) else {
            return "{}"
        }

        var output = "{\n"
        output += "  \"exportDate\": \"\(ISO8601DateFormatter().string(from: Date()))\",\n"
        output += "  \"totalCount\": \(archivedThreads.count),\n"
        if let jsonString = String(data: data, encoding: .utf8) {
            // Remove opening/closing braces from thread array
            let stripped = jsonString.dropFirst().dropLast()
            output += "  \"threads\": \(stripped)\n"
        }
        output += "}"

        return output
    }

    /// Export archive list as markdown
    func exportAsMarkdown() -> String {
        var output = "# Archived Threads\n\n"
        output += "Exported: \(Date())\n"
        output += "Total: \(archivedThreads.count) threads\n\n"

        let sorted = archivedThreads.sorted { $0.archivedAt > $1.archivedAt }

        for archived in sorted {
            let date = RelativeDateTimeFormatter().localizedString(
                for: archived.archivedAt,
                relativeTo: Date()
            )

            output += "## \(archived.title)\n\n"
            output += "- **Archived:** \(date)\n"
            output += "- **Messages:** \(archived.messageCount)\n"

            if !archived.tags.isEmpty {
                output += "- **Tags:** \(archived.tags.joined(separator: ", "))\n"
            }

            if let summary = archived.summary {
                output += "- **Summary:** \(summary)\n"
            }

            output += "\n---\n\n"
        }

        return output
    }

    // MARK: - Statistics

    var totalCount: Int { archivedThreads.count }

    var totalMessages: Int {
        archivedThreads.reduce(0) { $0 + $1.messageCount }
    }

    var oldestArchive: Date? {
        archivedThreads.map { $0.archivedAt }.min()
    }

    var newestArchive: Date? {
        archivedThreads.map { $0.archivedAt }.max()
    }

    func archiveCount(forTag tag: String) -> Int {
        archivedThreads.filter { $0.tags.contains(tag) }.count
    }

    func topTags(limit: Int = 10) -> [(tag: String, count: Int)] {
        let tagCounts = Dictionary(grouping: archivedThreads.flatMap { $0.tags }, by: { $0 })
            .mapValues { $0.count }
        return tagCounts.sorted { $0.value > $1.value }.prefix(limit)
            .map { (tag: $0.key, count: $0.value) }
    }
}

// MARK: - Archive Button (Context Menu Action)

struct ArchiveButton: View {
    let thread: ChatThread
    let onArchive: (UUID) -> Void
    @ObservedObject var store: ArchiveStore

    @State private var showingConfirm = false

    private var isArchived: Bool {
        store.isArchived(threadID: thread.id)
    }

    var body: some View {
        Button {
            showingConfirm = true
        } label: {
            Label("Archive", systemImage: "archivebox")
        }
        .disabled(isArchived)
        .alert("Archive Thread", isPresented: $showingConfirm) {
            Button("Cancel", role: .cancel) {
                NSHapticFeedbackManager.defaultPerformer.perform(
                    .alignment,
                    performanceTime: .default
                )
            }
            Button("Archive", role: .destructive) {
                performArchive()
            }
        } message: {
            Text("Archive \"\(thread.title)\"? It will be moved to the archive and can be restored later.")
        }
    }

    private func performArchive() {
        store.archive(thread)
        onArchive(thread.id)

        // Success haptic
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .default
        )
    }
}

// MARK: - Archive Panel (Sidebar Section)

struct ArchivePanel: View {
    @ObservedObject var store: ArchiveStore
    @Binding var isExpanded: Bool
    let onRestore: (UUID) -> Void
    let onDelete: (UUID) -> Void

    @State private var searchText = ""
    @State private var selectedTag: String?
    @State private var showingDeleteAlert = false
    @State private var threadToDelete: ArchivedThread?
    @State private var selectedThreads: Set<UUID> = []
    @State private var showingExportMenu = false

    private var filteredThreads: [ArchivedThread] {
        var result = store.archivedThreads

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.title.lowercased().contains(query) ||
                $0.summary?.lowercased().contains(query) == true ||
                $0.tags.contains { $0.lowercased().contains(query) }
            }
        }

        if let tag = selectedTag {
            result = result.filter { $0.tags.contains(tag) }
        }

        return result.sorted { $0.archivedAt > $1.archivedAt }
    }

    private var uniqueTags: [String] {
        let allTags = store.archivedThreads.flatMap { $0.tags }
        return Array(Set(allTags)).sorted()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded {
                Divider()
                    .background(V4Color.border)

                if store.archivedThreads.isEmpty {
                    emptyState
                } else {
                    archiveContent
                }
            }
        }
        .background(V4Color.sidebar)
    }

    private var header: some View {
        HStack(spacing: ParietalSpacing.sm) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: isExpanded ? "archivebox.fill" : "archivebox")
                        .font(WernickeTypography.size11)
                        .foregroundStyle(V4Color.purple)

                    Text("Archive")
                        .font(WernickeTypography.caption2Semibold)

                    if !store.archivedThreads.isEmpty {
                        Text("\(store.archivedThreads.count)")
                            .font(WernickeTypography.size10Mono.weight(.medium))
                            .foregroundStyle(V4Color.textSecondary)
                    }

                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(WernickeTypography.size9)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
            .buttonStyle(.plain)

            Spacer()

            if isExpanded && !store.archivedThreads.isEmpty {
                Menu {
                    if !selectedThreads.isEmpty {
                        Button("Restore Selected") {
                            restoreSelected()
                        }

                        Button("Delete Selected", role: .destructive) {
                            deleteSelected()
                        }

                        Divider()
                    }

                    Button("Export as JSON") {
                        exportArchive(format: .json)
                    }

                    Button("Export as Markdown") {
                        exportArchive(format: .markdown)
                    }

                    Divider()

                    Button("Purge Expired") {
                        let removed = store.purgeExpired()
                        if removed > 0 {
                            SoundCueManager.shared.playSend()
                        }
                    }
                    .disabled(store.purgeExpired() == 0)

                    Divider()

                    Button("Clear All", role: .destructive) {
                        showingDeleteAlert = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .font(WernickeTypography.size10)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .menuStyle(.borderlessButton)
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm)
        .contentShape(Rectangle())
        .alert("Clear All Archives", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                selectedThreads.removeAll()
            }
            Button("Clear All", role: .destructive) {
                store.deleteAll()
                selectedThreads.removeAll()
            }
        } message: {
            Text("This will permanently delete all archived threads. This action cannot be undone.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: ParietalSpacing.md) {
            Image(systemName: "archivebox")
                .font(WernickeTypography.size28)
                .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateHover))

            Text("No archived threads")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            Text("Archive threads to keep your main list clean")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 32)
        .padding(.horizontal, ParietalSpacing.lg)
    }

    private var archiveContent: some View {
        VStack(spacing: 0) {
            searchBar

            if !searchText.isEmpty || selectedTag != nil {
                filterReset
            }

            Divider()
                .background(V4Color.border)

            if !uniqueTags.isEmpty {
                tagFilter
                Divider()
                    .background(V4Color.border)
            }

            if filteredThreads.isEmpty {
                noResultsView
            } else {
                archiveList
            }
        }
    }

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .font(WernickeTypography.size10)
                .foregroundStyle(V4Color.textSecondary)

            TextField("Search archive...", text: $searchText)
                .textFieldStyle(.plain)
                .font(WernickeTypography.size11)
                .foregroundStyle(V4Color.textPrimary)
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.xs + 2)
        .background(V4Color.surface.opacity(V2Depth.stateDisabled))
    }

    private var filterReset: some View {
        HStack {
            if !selectedThreads.isEmpty {
                Text("\(selectedThreads.count) selected")
                    .font(.caption2)
                    .foregroundStyle(V4Color.accent)

                Button("Clear") {
                    withAnimation {
                        selectedThreads.removeAll()
                    }
                }
                .font(.caption2)
                .buttonStyle(.plain)

                Spacer()
            } else {
                Text("Filtered: \(filteredThreads.count)")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)

                Spacer()

                Button {
                    withAnimation {
                        searchText = ""
                        selectedTag = nil
                    }
                } label: {
                    HStack(spacing: ParietalSpacing.xs) {
                        Image(systemName: "xmark.circle.fill")
                            .font(WernickeTypography.size8)
                        Text("Clear")
                            .font(.caption2)
                    }
                    .foregroundStyle(V4Color.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.xs)
    }

    private var tagFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ParietalSpacing.sm - 2) {
                ArchiveTagChip(
                    tag: nil,
                    isSelected: selectedTag == nil
                ) {
                    withAnimation {
                        selectedTag = nil
                    }
                }

                ForEach(uniqueTags, id: \.self) { tag in
                    ArchiveTagChip(
                        tag: tag,
                        isSelected: selectedTag == tag
                    ) {
                        withAnimation {
                            selectedTag = selectedTag == tag ? nil : tag
                        }
                    }
                }
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.xs + 2)
        }
    }

    private var noResultsView: some View {
        VStack(spacing: ParietalSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(WernickeTypography.size20)
                .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateHover))

            Text("No archives match")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    private var archiveList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredThreads) { thread in
                    ArchiveThreadRow(
                        thread: thread,
                        isSelected: selectedThreads.contains(thread.id),
                        onSelect: {
                            withAnimation {
                                if selectedThreads.contains(thread.id) {
                                    selectedThreads.remove(thread.id)
                                } else {
                                    selectedThreads.insert(thread.id)
                                }
                            }
                        },
                        onRestore: {
                            restoreThread(thread)
                        },
                        onDelete: {
                            threadToDelete = thread
                            showingDeleteAlert = true
                        }
                    )
                    .contextMenu {
                        Button("Restore") {
                            restoreThread(thread)
                        }

                        Divider()

                        Button("Permanently Delete", role: .destructive) {
                            threadToDelete = thread
                            showingDeleteAlert = true
                        }
                    }

                    Divider()
                        .background(V4Color.border)
                        .padding(.leading, 44)
                }
            }
        }
        .alert("Delete Archived Thread", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                threadToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let thread = threadToDelete {
                    deleteThread(thread)
                }
            }
        } message: {
            Text("Are you sure you want to permanently delete \"\(threadToDelete?.title ?? "")\"?")
        }
    }

    private func restoreThread(_ thread: ArchivedThread) {
        let threadID = store.restore(threadID: thread.originalThreadID)
        if threadID != nil {
            onRestore(thread.originalThreadID)
            SoundCueManager.shared.playReceive()
            selectedThreads.remove(thread.id)
        }
    }

    private func deleteThread(_ thread: ArchivedThread) {
        store.permanentlyDelete(id: thread.id)
        onDelete(thread.originalThreadID)
        SoundCueManager.shared.playError()
        selectedThreads.remove(thread.id)
        threadToDelete = nil
    }

    private func restoreSelected() {
        for id in selectedThreads {
            if let thread = store.archivedThreads.first(where: { $0.id == id }) {
                _ = store.restore(threadID: thread.originalThreadID)
                onRestore(thread.originalThreadID)
            }
        }
        SoundCueManager.shared.playReceive()
        selectedThreads.removeAll()
    }

    private func deleteSelected() {
        for id in selectedThreads {
            store.permanentlyDelete(id: id)
        }
        SoundCueManager.shared.playError()
        selectedThreads.removeAll()
    }

    private enum ExportFormat {
        case json
        case markdown
    }

    private func exportArchive(format: ExportFormat) {
        let content: String
        let defaultName: String
        let fileType: UTType

        switch format {
        case .json:
            content = store.exportAsJSON()
            defaultName = "archive-\(Int(Date().timeIntervalSince1970)).json"
            fileType = .json
        case .markdown:
            content = store.exportAsMarkdown()
            defaultName = "archive-\(Int(Date().timeIntervalSince1970)).md"
            fileType = .plainText
        }

        let panel = NSSavePanel()
        panel.allowedContentTypes = [fileType]
        panel.nameFieldStringValue = defaultName
        panel.begin { result in
            if result == .OK, let url = panel.url {
                try? content.write(to: url, atomically: true, encoding: .utf8)
                SoundCueManager.shared.playSend()
            }
        }
    }
}

// MARK: - Archive Tag Chip

private struct ArchiveTagChip: View {
    let tag: String?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ParietalSpacing.xs) {
                if tag != nil {
                    Image(systemName: "tag.fill")
                        .font(WernickeTypography.size7)
                }
                Text(tag ?? "All")
                    .font(isSelected ? WernickeTypography.microSemibold : WernickeTypography.micro)
            }
            .foregroundStyle(isSelected ? V4Color.purple : V4Color.textSecondary)
            .padding(.horizontal, ParietalSpacing.xs + 2)
            .padding(.vertical, 3)
            .background(
                RoundedRectangle(cornerRadius: 3)
                    .fill(V4Color.purple.opacity(isSelected ? 0.2 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(V4Color.purple.opacity(isSelected ? 1 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Archive Thread Row

private struct ArchiveThreadRow: View {
    let thread: ArchivedThread
    let isSelected: Bool
    let onSelect: () -> Void
    let onRestore: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var archiveDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: thread.archivedAt, relativeTo: Date())
    }

    var body: some View {
        HStack(alignment: .top, spacing: ParietalSpacing.sm + 2) {
            // Selection checkbox
            Button {
                onSelect()
            } label: {
                Image(systemName: isSelected ? "checkmark.square.fill" : "square")
                    .font(WernickeTypography.size12)
                    .foregroundColor(isSelected ? V4Color.accent : V4Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help(isSelected ? "Deselect" : "Select")
            .accessibilityLabel(isSelected ? "Deselect thread" : "Select thread")

            // Archive indicator
            RoundedRectangle(cornerRadius: 2)
                .fill(V4Color.purple.opacity(V1Theme.opacityTextSecondary))
                .frame(width: ParietalSpacing.smallIndicator, height: ParietalSpacing.itemHeight)

            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                // Title row
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Text(thread.title)
                        .font(WernickeTypography.captionMedium)
                        .foregroundStyle(V4Color.textPrimary)
                        .lineLimit(2)

                    Spacer()

                    Text(archiveDate)
                        .font(WernickeTypography.size9)
                        .foregroundStyle(V4Color.textSecondary.opacity(0.7))
                }

                // Metadata row
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "bubble.left.fill")
                        .font(WernickeTypography.size7)
                        .foregroundStyle(V4Color.textSecondary)

                    Text("\(thread.messageCount)")
                        .font(WernickeTypography.size9)
                        .foregroundStyle(V4Color.textSecondary)

                    if !thread.tags.isEmpty {
                        Image(systemName: "tag.fill")
                            .font(WernickeTypography.size7)
                            .foregroundStyle(V4Color.purple.opacity(0.7))

                        Text(thread.tags.prefix(2).joined(separator: ", "))
                            .font(WernickeTypography.size9)
                            .foregroundStyle(V4Color.purple.opacity(0.8))
                            .lineLimit(1)
                    }

                    Spacer()

                    // Action buttons (show on hover)
                    if isHovered {
                        HStack(spacing: ParietalSpacing.xs) {
                            Button {
                                onRestore()
                            } label: {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(WernickeTypography.size9)
                                    .foregroundStyle(V4Color.accent)
                            }
                            .buttonStyle(.plain)
                            .help("Restore thread")
                            .accessibilityLabel("Restore thread")

                            Button {
                                onDelete()
                            } label: {
                                Image(systemName: "trash")
                                    .font(WernickeTypography.size8)
                                    .foregroundStyle(V4Color.error)
                            }
                            .buttonStyle(.plain)
                            .help("Permanently delete")
                            .accessibilityLabel("Permanently delete thread")
                        }
                        .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                    }
                }

                // Summary preview if available
                if let summary = thread.summary, !summary.isEmpty {
                    Text(summary)
                        .font(WernickeTypography.size10)
                        .foregroundStyle(V4Color.textSecondary.opacity(0.8))
                        .lineLimit(1)
                }
            }

            Spacer()
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm)
        .background(isSelected ? V4Color.accent.opacity(V2Depth.bgSubtle) : (isHovered ? V4Color.surface.opacity(V2Depth.stateDisabled) : Color.clear))
        .contentShape(Rectangle())
        .onHover { isHovered in
            withAnimation(reduceMotion ? .none : MTMotion.quickSpring) {
                self.isHovered = isHovered
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(thread.title)
        .accessibilityHint("Archived \(archiveDate), \(thread.messageCount) messages")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Bulk Archive Actions

struct BulkArchiveActions: View {
    let selectedThreads: Set<UUID>
    let threads: [ChatThread]
    let onArchive: (Set<UUID>) -> Void
    let onExport: ([ChatThread]) -> Void

    @ObservedObject var store: ArchiveStore

    @State private var showingConfirm = false

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            if !selectedThreads.isEmpty {
                Text("\(selectedThreads.count) selected")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)

                Button {
                    showingConfirm = true
                } label: {
                    Label("Archive", systemImage: "archivebox")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    exportSelection()
                } label: {
                    Label("Export List", systemImage: "square.and.arrow.up")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
        .alert("Archive Selected Threads", isPresented: $showingConfirm) {
            Button("Cancel", role: .cancel) { }
            Button("Archive", role: .destructive) {
                performBulkArchive()
            }
        } message: {
            Text("Archive \(selectedThreads.count) selected threads? They can be restored from the archive panel.")
        }
    }

    private func performBulkArchive() {
        let threadsToArchive = threads.filter { selectedThreads.contains($0.id) }
        store.archiveMultiple(threadsToArchive)
        onArchive(selectedThreads)
        NSHapticFeedbackManager.defaultPerformer.perform(
            .generic,
            performanceTime: .default
        )
    }

    private func exportSelection() {
        let selected = threads.filter { selectedThreads.contains($0.id) }

        let selectionJSON = """
        {
            "exportedAt": "\(ISO8601DateFormatter().string(from: Date()))",
            "selectedCount": \(selected.count),
            "threadIDs": [
        \(selected.map { "    \"\($0.id.uuidString)\"" }.joined(separator: ",\n"))
            ]
        }
        """

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "selection-\(Int(Date().timeIntervalSince1970)).json"
        panel.begin { result in
            if result == .OK, let url = panel.url {
                try? selectionJSON.write(to: url, atomically: true, encoding: .utf8)
                SoundCueManager.shared.playSend()
            }
        }
    }
}

// MARK: - Archive Status Indicator

struct ArchiveStatusIndicator: View {
    let isArchived: Bool

    var body: some View {
        if isArchived {
            Image(systemName: "archivebox.fill")
                .font(WernickeTypography.size8)
                .foregroundStyle(V4Color.textSecondary.opacity(0.7))
                .help("This thread is archived")
        }
    }
}

// MARK: - Archive Statistics View

struct ArchiveStatisticsView: View {
    @ObservedObject var store: ArchiveStore

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            Text("Archive Statistics")
                .font(.headline)
                .foregroundStyle(V4Color.textPrimary)

            HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                StatItem(
                    label: "Total Threads",
                    value: "\(store.totalCount)",
                    icon: "archivebox.fill",
                    color: V4Color.purple
                )

                StatItem(
                    label: "Total Messages",
                    value: "\(store.totalMessages)",
                    icon: "bubble.left.fill",
                    color: V4Color.accent
                )
            }

            if !store.archivedThreads.isEmpty {
                Divider()
                    .background(V4Color.border)

                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Top Tags")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)

                    let topTags = store.topTags(limit: 5)
                    ForEach(topTags, id: \.tag) { item in
                        HStack {
                            Text(item.tag)
                                .font(.caption2)
                                .foregroundStyle(V4Color.purple)

                            Spacer()

                            Text("\(item.count)")
                                .font(.caption2)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    }
                }
            }
        }
        .padding()
        .background(V4Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
    }
}

private struct StatItem: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: ParietalSpacing.xs) {
            Image(systemName: icon)
                .font(WernickeTypography.size20)
                .foregroundStyle(color)

            Text(value)
                .font(WernickeTypography.size18Medium)
                .foregroundStyle(V4Color.textPrimary)

            Text(label)
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Preview Provider

struct ThreadArchiveView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ArchivePanel(
                store: {
                    let store = ArchiveStore()
                    store.archivedThreads = [
                        ArchivedThread(
                            id: UUID(),
                            originalThreadID: UUID(),
                            title: "FPGA Synthesis Debug",
                            messageCount: 42,
                            createdAt: Date().addingTimeInterval(-172800),
                            archivedAt: Date().addingTimeInterval(-86400),
                            tags: ["fpga", "debug"],
                            summary: "Debugging timing issues in TMU pipeline"
                        )
                    ]
                    return store
                }(),
                isExpanded: .constant(true),
                onRestore: { _ in },
                onDelete: { _ in }
            )
            .frame(width: ParietalSpacing.panelWidth)
            .previewDisplayName("Archive Panel")

            ArchiveButton(
                thread: ChatThread(title: "Sample Thread"),
                onArchive: { _ in },
                store: ArchiveStore()
            )
            .padding()
            .previewDisplayName("Archive Button")

            ArchiveStatisticsView(store: {
                let store = ArchiveStore()
                store.archivedThreads = [
                    ArchivedThread(
                        id: UUID(),
                        originalThreadID: UUID(),
                        title: "Thread 1",
                        messageCount: 10,
                        createdAt: Date(),
                        archivedAt: Date(),
                        tags: ["fpga", "debug"]
                    )
                ]
                return store
            }())
            .frame(width: ParietalSpacing.xl * 12)
            .padding()
            .previewDisplayName("Statistics")
        }
        .preferredColorScheme(.dark)
    }
}
