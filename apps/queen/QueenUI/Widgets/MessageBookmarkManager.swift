import SwiftUI
import AppKit

// MARK: - Bookmark Category

enum BookmarkCategory: String, CaseIterable, Identifiable, Codable {
    case important = "Important"
    case code = "Code"
    case reference = "Reference"
    case todo = "TODO"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .important: return "star.fill"
        case .code: return "chevron.left.forwardslash.chevron.right"
        case .reference: return "book.fill"
        case .todo: return "checkmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .important: return V4Color.golden
        case .code: return V4Color.purple
        case .reference: return V4Color.accent
        case .todo: return V4Color.warning
        }
    }

    var hexColor: String {
        switch self {
        case .important: return "FFD700"
        case .code: return "8B5CF6"
        case .reference: return "00FF88"
        case .todo: return "FFD700"
        }
    }
}

// MARK: - Message Bookmark Model

struct MessageBookmark: Identifiable, Codable, Equatable {
    let id: UUID
    let messageID: UUID
    let threadID: UUID
    let category: BookmarkCategory
    let note: String
    let createdAt: Date
    let messageText: String
    let messageRole: ChatMessage.Role
    let messageModelID: String?

    init(
        messageID: UUID,
        threadID: UUID,
        category: BookmarkCategory,
        note: String = "",
        messageText: String,
        messageRole: ChatMessage.Role,
        messageModelID: String? = nil
    ) {
        self.id = UUID()
        self.messageID = messageID
        self.threadID = threadID
        self.category = category
        self.note = note
        self.createdAt = Date()
        self.messageText = messageText
        self.messageRole = messageRole
        self.messageModelID = messageModelID
    }
}

// MARK: - Bookmark Store

@MainActor
class BookmarkStore: ObservableObject {
    @Published var bookmarks: [MessageBookmark] = []
    private let saveURL: URL

    init() {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!
        let trinityDir = appSupport.appendingPathComponent("Trinity")
        let bookmarksDir = trinityDir.appendingPathComponent("Bookmarks")

        try? FileManager.default.createDirectory(
            at: bookmarksDir,
            withIntermediateDirectories: true
        )

        saveURL = bookmarksDir.appendingPathComponent("bookmarks.json")
        load()
    }

    func load() {
        guard let data = try? Data(contentsOf: saveURL) else { return }
        bookmarks = (try? JSONDecoder().decode([MessageBookmark].self, from: data)) ?? []
    }

    func save() {
        guard let data = try? JSONEncoder().encode(bookmarks) else { return }
        try? data.write(to: saveURL)
    }

    func addBookmark(_ bookmark: MessageBookmark) {
        bookmarks.append(bookmark)
        save()
    }

    func removeBookmark(id: UUID) {
        bookmarks.removeAll { $0.id == id }
        save()
    }

    func updateBookmarkNote(id: UUID, note: String) {
        if let index = bookmarks.firstIndex(where: { $0.id == id }) {
            let bookmark = bookmarks[index]
            bookmarks[index] = MessageBookmark(
                messageID: bookmark.messageID,
                threadID: bookmark.threadID,
                category: bookmark.category,
                note: note,
                messageText: bookmark.messageText,
                messageRole: bookmark.messageRole,
                messageModelID: bookmark.messageModelID
            )
            save()
        }
    }

    func bookmarks(for category: BookmarkCategory?) -> [MessageBookmark] {
        guard let category = category else { return bookmarks }
        return bookmarks.filter { $0.category == category }
    }

    func bookmark(for messageID: UUID) -> MessageBookmark? {
        bookmarks.first { $0.messageID == messageID }
    }

    var categories: [BookmarkCategory] {
        let uniqueCategories = Set(bookmarks.map { $0.category })
        return BookmarkCategory.allCases.filter { uniqueCategories.contains($0) }
    }

    func exportAsMarkdown() -> String {
        var output = "# Bookmarked Messages\n\n"
        output += "Exported: \(Date())\n\n"

        for category in BookmarkCategory.allCases {
            let categoryBookmarks = bookmarks(for: category).sorted {
                $0.createdAt > $1.createdAt
            }

            if !categoryBookmarks.isEmpty {
                output += "## \(category.rawValue)\n\n"

                for bookmark in categoryBookmarks {
                    let roleIcon = bookmark.messageRole == .user ? "You" : "Assistant"
                    let date = RelativeDateTimeFormatter().localizedString(
                        for: bookmark.createdAt,
                        relativeTo: Date()
                    )

                    output += "### \(roleIcon) — \(date)\n\n"

                    if !bookmark.note.isEmpty {
                        output += "**Note:** \(bookmark.note)\n\n"
                    }

                    let preview = String(bookmark.messageText.prefix(200))
                    output += "```\n\(preview)\n```\n\n"

                    if bookmark.messageText.count > 200 {
                        output += "*Message truncated. Full content in Queen UI.*\n\n"
                    }

                    output += "---\n\n"
                }
            }
        }

        return output
    }
}

// MARK: - Bookmark Button

struct BookmarkButton: View {
    let message: ChatMessage
    let threadID: UUID
    @ObservedObject var store: BookmarkStore

    @State private var showingCategoryPicker = false
    @State private var showingNoteEditor = false

    private var isBookmarked: Bool {
        store.bookmark(for: message.id) != nil
    }

    var body: some View {
        Button {
            if isBookmarked {
                if let bookmark = store.bookmark(for: message.id) {
                    store.removeBookmark(id: bookmark.id)
                    SoundCueManager.shared.playCopy()
                }
            } else {
                showingCategoryPicker = true
            }
        } label: {
            Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                .font(WernickeTypography.size13)
                .foregroundColor(isBookmarked ? V4Color.golden : V4Color.textSecondary)
        }
        .buttonStyle(.plain)
        .help(isBookmarked ? "Remove bookmark" : "Bookmark message")
        .sheet(isPresented: $showingCategoryPicker) {
            CategoryPickerSheet(
                message: message,
                threadID: threadID,
                store: store,
                isPresented: $showingCategoryPicker,
                showNoteEditor: $showingNoteEditor
            )
        }
        .sheet(isPresented: $showingNoteEditor) {
            if let bookmark = store.bookmark(for: message.id) {
                BookmarkNoteEditor(
                    bookmark: bookmark,
                    store: store,
                    isPresented: $showingNoteEditor
                )
            }
        }
    }
}

// MARK: - Category Picker Sheet

private struct CategoryPickerSheet: View {
    let message: ChatMessage
    let threadID: UUID
    @ObservedObject var store: BookmarkStore
    @Binding var isPresented: Bool
    @Binding var showNoteEditor: Bool

    var body: some View {
        VStack(spacing: ParietalSpacing.md) {
            Text("Bookmark Message")
                .font(.headline)
                .foregroundStyle(V4Color.textPrimary)

            Text("Choose a category for this bookmark")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            Divider()

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ParietalSpacing.md) {
                ForEach(BookmarkCategory.allCases) { category in
                    CategoryCard(category: category) {
                        addBookmark(category: category)
                    }
                }
            }
            .padding()

            Divider()

            Button("Cancel") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: ParietalSpacing.widePanelWidth, height: ParietalSpacing.panelHeight)
        .background(V4Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
    }

    private func addBookmark(category: BookmarkCategory) {
        let bookmark = MessageBookmark(
            messageID: message.id,
            threadID: threadID,
            category: category,
            note: "",
            messageText: message.text,
            messageRole: message.role,
            messageModelID: message.modelID
        )
        store.addBookmark(bookmark)
        SoundCueManager.shared.playSend()
        isPresented = false
        showNoteEditor = true
    }
}

private struct CategoryCard: View {
    let category: BookmarkCategory
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: ParietalSpacing.md) {
                Image(systemName: category.icon)
                    .font(WernickeTypography.size28)
                    .foregroundStyle(category.color)

                Text(category.rawValue)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(V4Color.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ParietalSpacing.lg)
            .background(
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .fill(category.color.opacity(isHovered ? 0.15 : 0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .stroke(category.color.opacity(isHovered ? 1 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel("Add to \(category.rawValue)")
    }
}

// MARK: - Bookmark Note Editor

private struct BookmarkNoteEditor: View {
    let bookmark: MessageBookmark
    @ObservedObject var store: BookmarkStore
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    @State private var noteText: String

    init(bookmark: MessageBookmark, store: BookmarkStore, isPresented: Binding<Bool>) {
        self.bookmark = bookmark
        self.store = store
        self._isPresented = isPresented
        self._noteText = State(initialValue: bookmark.note)
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.md) {
            HStack {
                Image(systemName: bookmark.category.icon)
                    .foregroundStyle(bookmark.category.color)

                Text("Add Note")
                    .font(.headline)
                    .foregroundStyle(V4Color.textPrimary)

                Spacer()

                Button("Done") {
                    saveAndClose()
                }
                .keyboardShortcut(.defaultAction)
            }

            Divider()

            Text("Add an optional note to this bookmark")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            TextEditor(text: $noteText)
                .font(.body)
                .foregroundStyle(V4Color.textPrimary)
                .background(V4Color.surface)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                        .stroke(V4Color.border, lineWidth: 1)
                )

            Divider()

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Save") {
                    saveAndClose()
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: ParietalSpacing.sheetWidth, height: ParietalSpacing.mediumModalFrame)
        .background(V4Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
    }

    private func saveAndClose() {
        store.updateBookmarkNote(id: bookmark.id, note: noteText)
        SoundCueManager.shared.playSend()
        isPresented = false
    }
}

// MARK: - Bookmarks Panel (Sidebar)

struct BookmarksPanel: View {
    @ObservedObject var store: BookmarkStore
    @Binding var isExpanded: Bool

    @State private var selectedCategory: BookmarkCategory?
    @State private var searchText = ""
    @State private var editingBookmarkID: UUID?
    @State private var showingExport = false
    @State private var showingDeleteAlert = false
    @State private var bookmarkToDelete: MessageBookmark?

    private var filteredBookmarks: [MessageBookmark] {
        var result = store.bookmarks

        if let category = selectedCategory {
            result = result.filter { $0.category == category }
        }

        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter {
                $0.messageText.lowercased().contains(query) ||
                $0.note.lowercased().contains(query)
            }
        }

        return result.sorted { $0.createdAt > $1.createdAt }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if isExpanded {
                Divider()
                    .background(V4Color.border)

                if store.bookmarks.isEmpty {
                    emptyState
                } else {
                    bookmarksContent
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
                    Image(systemName: isExpanded ? "bookmark.fill" : "bookmark")
                        .font(WernickeTypography.size11)
                        .foregroundStyle(V4Color.golden)

                    Text("Bookmarks")
                        .font(WernickeTypography.caption2Semibold)

                    if !store.bookmarks.isEmpty {
                        Text("\(store.bookmarks.count)")
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

            if isExpanded && !store.bookmarks.isEmpty {
                Menu {
                    Button("Export as Markdown") {
                        exportBookmarks()
                    }

                    Divider()

                    Button("Clear All") {
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
        .alert("Clear All Bookmarks", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Clear", role: .destructive) {
                store.bookmarks.removeAll()
                store.save()
            }
        } message: {
            Text("This will remove all bookmarks. This action cannot be undone.")
        }
    }

    private var emptyState: some View {
        VStack(spacing: ParietalSpacing.md) {
            Image(systemName: "bookmark")
                .font(WernickeTypography.size28)
                .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateHover))

            Text("No bookmarks yet")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            Text("Click the bookmark icon on any message to save it")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ParietalSpacing.xxl)
        .padding(.horizontal, ParietalSpacing.lg)
    }

    private var bookmarksContent: some View {
        VStack(spacing: 0) {
            categoryFilter

            if !searchText.isEmpty || selectedCategory != nil {
                filterReset
            }

            Divider()
                .background(V4Color.border)

            if filteredBookmarks.isEmpty {
                noResultsView
            } else {
                bookmarksList
            }
        }
    }

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ParietalSpacing.sm - 2) {
                CategoryChip(
                    category: nil,
                    isSelected: selectedCategory == nil
                ) {
                    withAnimation {
                        selectedCategory = nil
                    }
                }

                ForEach(store.categories) { category in
                    CategoryChip(
                        category: category,
                        isSelected: selectedCategory == category
                    ) {
                        withAnimation {
                            selectedCategory = category
                        }
                    }
                }
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm)
        }
    }

    private var filterReset: some View {
        HStack {
            Image(systemName: "line.3.horizontal.decrease.circle")
                .font(WernickeTypography.size10)
                .foregroundStyle(V4Color.textSecondary)

            TextField("Search bookmarks...", text: $searchText)
                .textFieldStyle(.plain)
                .font(WernickeTypography.size11)
                .foregroundStyle(V4Color.textPrimary)

            if !searchText.isEmpty {
                Button {
                    withAnimation {
                        searchText = ""
                        selectedCategory = nil
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size10)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.xs + 2)
        .background(V4Color.surface.opacity(V2Depth.stateDisabled))
    }

    private var noResultsView: some View {
        VStack(spacing: ParietalSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(WernickeTypography.size20)
                .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateHover))

            Text("No bookmarks match")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, ParietalSpacing.xl)
    }

    private var bookmarksList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredBookmarks) { bookmark in
                    BookmarkRow(
                        bookmark: bookmark,
                        onDelete: {
                            bookmarkToDelete = bookmark
                            showingDeleteAlert = true
                        },
                        onEdit: {
                            editingBookmarkID = bookmark.id
                        }
                    )
                    .contextMenu {
                        Button("Edit Note") {
                            editingBookmarkID = bookmark.id
                        }

                        Divider()

                        Button("Delete", role: .destructive) {
                            bookmarkToDelete = bookmark
                            showingDeleteAlert = true
                        }
                    }

                    Divider()
                        .background(V4Color.border)
                        .padding(.leading, 44)
                }
            }
        }
        .sheet(isPresented: Binding(
            get: { editingBookmarkID != nil },
            set: { if !$0 { editingBookmarkID = nil } }
        )) {
            if let id = editingBookmarkID,
               let bookmark = store.bookmark(for: id) {
                BookmarkNoteEditor(
                    bookmark: bookmark,
                    store: store,
                    isPresented: Binding(
                        get: { editingBookmarkID != nil },
                        set: { if !$0 { editingBookmarkID = nil } }
                    )
                )
            }
        }
        .alert("Delete Bookmark", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) {
                bookmarkToDelete = nil
            }
            Button("Delete", role: .destructive) {
                if let bookmark = bookmarkToDelete {
                    store.removeBookmark(id: bookmark.id)
                    bookmarkToDelete = nil
                }
            }
        } message: {
            Text("Are you sure you want to delete this bookmark?")
        }
    }

    private func exportBookmarks() {
        let markdown = store.exportAsMarkdown()

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.plainText]
        panel.nameFieldStringValue = "bookmarks-\(Date().timeIntervalSince1970).md"
        panel.begin { result in
            if result == .OK, let url = panel.url {
                try? markdown.write(to: url, atomically: true, encoding: .utf8)
                SoundCueManager.shared.playSend()
            }
        }
    }
}

// MARK: - Category Chip

private struct CategoryChip: View {
    let category: BookmarkCategory?
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ParietalSpacing.xs) {
                if let category = category {
                    Image(systemName: category.icon)
                        .font(WernickeTypography.size8)
                }

                Text(category?.rawValue ?? "All")
                    .font(isSelected ? WernickeTypography.miniSemibold : WernickeTypography.size10)
            }
            .foregroundStyle(isSelected ? category?.color ?? V4Color.textPrimary : V4Color.textSecondary)
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .fill((category?.color ?? V4Color.accent).opacity(isSelected ? 0.2 : 0))
            )
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .stroke((category?.color ?? V4Color.border).opacity(isSelected ? 1 : 0.3), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Bookmark Row

private struct BookmarkRow: View {
    let bookmark: MessageBookmark
    let onDelete: () -> Void
    let onEdit: () -> Void

    @State private var isExpanded = false

    private var previewText: String {
        let stripped = bookmark.messageText
            .replacingOccurrences(of: "\\*\\*(.+?)\\*\\*", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "\\*(.+?)\\*", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "`(.+?)`", with: "$1", options: .regularExpression)
            .replacingOccurrences(of: "```[\\s\\S]*?```", with: "[code]", options: .regularExpression)
            .replacingOccurrences(of: "\\n", with: " ", options: .regularExpression)
        return String(stripped.prefix(isExpanded ? 500 : 80))
    }

    var body: some View {
        HStack(alignment: .top, spacing: ParietalSpacing.sm) {
            categoryIndicator

            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                header

                if !bookmark.note.isEmpty {
                    noteView
                }

                messagePreview
            }

            Spacer()
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm)
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.easeInOut(duration: 0.2)) {
                isExpanded.toggle()
            }
        }
    }

    private var categoryIndicator: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(bookmark.category.color)
            .frame(width: ParietalSpacing.smallIndicator, height: ParietalSpacing.itemHeight)
    }

    private var header: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            Image(systemName: bookmark.messageRole == .user ? "person.circle.fill" : "cpu")
                .font(WernickeTypography.size9)
                .foregroundStyle(V4Color.textSecondary)

            Text(bookmark.messageRole == .user ? "You" : (bookmark.messageModelID ?? "Assistant"))
                .font(WernickeTypography.miniMedium)
                .foregroundStyle(V4Color.textPrimary)

            Spacer()

            Text(relativeDate)
                .font(WernickeTypography.size9)
                .foregroundStyle(V4Color.textSecondary.opacity(V1Theme.opacityTextSecondary))

            Button {
                onEdit()
            } label: {
                Image(systemName: "pencil.circle")
                    .font(WernickeTypography.size11)
                    .foregroundStyle(V4Color.textSecondary)
            }
            .buttonStyle(.plain)
            .help("Edit note")

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(WernickeTypography.size9)
                    .foregroundStyle(V4Color.error)
            }
            .buttonStyle(.plain)
            .help("Delete bookmark")
        }
    }

    private var noteView: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: "note.text")
                .font(WernickeTypography.size8)
                .foregroundStyle(bookmark.category.color)

            Text(bookmark.note)
                .font(WernickeTypography.size10)
                .foregroundStyle(V4Color.textPrimary)
                .lineLimit(2)
        }
    }

    private var messagePreview: some View {
        Text(previewText + (previewText.count >= 80 && !isExpanded ? "..." : ""))
            .font(WernickeTypography.size11)
            .foregroundStyle(V4Color.textSecondary)
            .lineLimit(isExpanded ? nil : 2)
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: bookmark.createdAt, relativeTo: Date())
    }
}

// MARK: - Preview Provider

struct MessageBookmarkManager_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            BookmarksPanel(
                store: BookmarkStore(),
                isExpanded: .constant(true)
            )
            .frame(width: ParietalSpacing.panelWidth)
            .previewDisplayName("Bookmarks Panel")

            BookmarkButton(
                message: ChatMessage(role: .assistant, text: "Here's the code you requested:"),
                threadID: UUID(),
                store: BookmarkStore()
            )
            .padding()
            .previewDisplayName("Bookmark Button")
        }
        .preferredColorScheme(.dark)
    }
}
