import Foundation

@MainActor
final class ThreadStore: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var activeThreadID: UUID?
    @Published var folders: [ThreadFolder] = []
    @Published var isLoaded: Bool = false
    @Published var recentlyDeleted: ChatThread? = nil
    @Published var showUndoToast: Bool = false
    @Published var showArchiveSuggestion: Bool = false

    private var undoTask: Task<Void, Never>? = nil

    private let storeURL: URL
    private var foldersURL: URL {
        storeURL.deletingLastPathComponent().appendingPathComponent("folders.json")
    }

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storeURL = appSupport.appendingPathComponent("QueenUI/threads", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        load()
        loadFolders()
    }

    @discardableResult
    func newThread() -> ChatThread {
        let thread = ChatThread()
        threads.insert(thread, at: 0)
        activeThreadID = thread.id
        save(thread)
        return thread
    }

    func delete(_ thread: ChatThread) {
        // Cancel any pending undo from a previous delete
        commitPendingDelete()

        threads.removeAll { $0.id == thread.id }
        if activeThreadID == thread.id {
            activeThreadID = threads.first?.id
        }

        // Soft-delete: keep on disk, store for undo
        recentlyDeleted = thread
        showUndoToast = true

        // After 5 seconds, permanently delete from disk
        undoTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            self?.commitPendingDelete()
        }
    }

    func undoDelete() {
        undoTask?.cancel()
        undoTask = nil
        guard let thread = recentlyDeleted else { return }
        recentlyDeleted = nil
        showUndoToast = false
        // Re-insert and save
        threads.insert(thread, at: 0)
        save(thread)
        activeThreadID = thread.id
    }

    /// Permanently remove the pending soft-deleted thread from disk
    private func commitPendingDelete() {
        undoTask?.cancel()
        undoTask = nil
        if let deleted = recentlyDeleted {
            let url = storeURL.appendingPathComponent("\(deleted.id).json")
            try? FileManager.default.removeItem(at: url)
            recentlyDeleted = nil
            showUndoToast = false
        }
    }

    func rename(_ id: UUID, title: String) {
        guard let idx = threads.firstIndex(where: { $0.id == id }) else { return }
        threads[idx].title = title
        save(threads[idx])
    }

    func appendMessage(_ msg: ChatMessage, to threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        let countBefore = threads[idx].messages.count
        threads[idx].messages.append(msg)
        threads[idx].updatedAt = Date()
        // Auto-title: on first user message when title is still default
        if msg.role == .user
            && countBefore == 0
            && threads[idx].title == "New Thread" {
            threads[idx].title = Self.autoTitle(from: msg.text)
        }
        save(threads[idx])
    }

    /// Generate a short title from the first user message (max ~60 chars, word-boundary truncation).
    private static func autoTitle(from text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
            .components(separatedBy: .newlines).first ?? ""
        guard !cleaned.isEmpty else { return "New Thread" }
        if cleaned.count <= 60 { return cleaned }
        // Find last space within the first 60 characters for clean word boundary
        let limit = cleaned.index(cleaned.startIndex, offsetBy: 60)
        let truncated = cleaned[cleaned.startIndex..<limit]
        if let lastSpace = truncated.lastIndex(of: " "), lastSpace > cleaned.startIndex {
            return String(truncated[truncated.startIndex..<lastSpace]) + "..."
        }
        return String(truncated) + "..."
    }

    func updateLastMessage(text: String, in threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard !threads[idx].messages.isEmpty else { return }
        let lastIdx = threads[idx].messages.count - 1
        threads[idx].messages[lastIdx].text = text
        threads[idx].updatedAt = Date()
    }

    func setLastMessageError(_ errorKind: MessageErrorKind, in threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard !threads[idx].messages.isEmpty else { return }
        let lastIdx = threads[idx].messages.count - 1
        threads[idx].messages[lastIdx].errorKind = errorKind
        threads[idx].updatedAt = Date()
    }

    func updateLastMessageThinking(text: String, in threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard !threads[idx].messages.isEmpty else { return }
        let lastIdx = threads[idx].messages.count - 1
        threads[idx].messages[lastIdx].thinkingText = text
        threads[idx].updatedAt = Date()
    }

    // MARK: - Memory Persistence

    private var memoriesURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("QueenUI/memories.json")
    }

    func loadMemories() -> [MemoryEntry] {
        guard let data = try? Data(contentsOf: memoriesURL) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return (try? decoder.decode([MemoryEntry].self, from: data)) ?? []
    }

    func saveMemory(_ entry: MemoryEntry) {
        var memories = loadMemories()
        memories.append(entry)
        // Cap at 20 most recent
        if memories.count > 20 { memories = Array(memories.suffix(20)) }
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(memories) {
            try? data.write(to: memoriesURL, options: .atomic)
        }
    }

    func dismissMemory(_ id: UUID) {
        // No-op for dismissed (not saved)
    }

    func updateLastMessage(text: String, imageURLs: [String], in threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard !threads[idx].messages.isEmpty else { return }
        let lastIdx = threads[idx].messages.count - 1
        threads[idx].messages[lastIdx].text = text
        threads[idx].messages[lastIdx].imageURLs = imageURLs
        threads[idx].updatedAt = Date()
    }

    func removeLastAssistantMessage(in threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        if let lastIdx = threads[idx].messages.lastIndex(where: { $0.role == .assistant }) {
            threads[idx].messages.remove(at: lastIdx)
            threads[idx].updatedAt = Date()
            save(threads[idx])
        }
    }

    func deleteMessage(_ messageID: UUID, in threadID: UUID) {
        guard let tIdx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[tIdx].messages.removeAll { $0.id == messageID }
        threads[tIdx].updatedAt = Date()
        save(threads[tIdx])
    }

    func toggleLike(_ messageID: UUID, liked: Bool?, in threadID: UUID) {
        guard let tIdx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard let mIdx = threads[tIdx].messages.firstIndex(where: { $0.id == messageID }) else { return }
        threads[tIdx].messages[mIdx].isLiked = liked
        save(threads[tIdx])
    }

    func appendComment(_ comment: ChatMessage, to messageID: UUID, in threadID: UUID) {
        guard let tIdx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard let mIdx = threads[tIdx].messages.firstIndex(where: { $0.id == messageID }) else { return }
        if threads[tIdx].messages[mIdx].comments == nil {
            threads[tIdx].messages[mIdx].comments = []
        }
        threads[tIdx].messages[mIdx].comments?.append(comment)
        save(threads[tIdx])
    }

    func updateLastComment(text: String, for messageID: UUID, in threadID: UUID) {
        guard let tIdx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard let mIdx = threads[tIdx].messages.firstIndex(where: { $0.id == messageID }) else { return }
        guard let comments = threads[tIdx].messages[mIdx].comments, !comments.isEmpty else { return }
        let lastIdx = comments.count - 1
        threads[tIdx].messages[mIdx].comments?[lastIdx].text = text
    }

    /// Fork conversation from a specific message: save branch, update text, remove everything after
    func forkFromMessage(_ messageID: UUID, newText: String, in threadID: UUID) {
        guard let tIdx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard let mIdx = threads[tIdx].messages.firstIndex(where: { $0.id == messageID }) else { return }

        // Save branch: store old text + subsequent messages for branch navigation
        let branchID = threads[tIdx].messages[mIdx].branchID ?? UUID()
        let oldIndex = threads[tIdx].messages[mIdx].branchIndex ?? 0

        // Store branch data in UserDefaults
        let branchKey = "branch_\(branchID)_\(oldIndex)"
        let oldMessages = Array(threads[tIdx].messages[mIdx...])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(oldMessages) {
            UserDefaults.standard.set(data, forKey: branchKey)
        }

        threads[tIdx].messages[mIdx].branchID = branchID
        threads[tIdx].messages[mIdx].branchIndex = oldIndex + 1
        threads[tIdx].messages[mIdx].text = newText

        // Remove all messages after the edited one
        if mIdx + 1 < threads[tIdx].messages.count {
            threads[tIdx].messages.removeSubrange((mIdx + 1)...)
        }
        threads[tIdx].updatedAt = Date()
        save(threads[tIdx])
    }

    /// Switch to a specific branch version of a message
    func switchBranch(_ messageID: UUID, toIndex: Int, in threadID: UUID) {
        guard let tIdx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard let mIdx = threads[tIdx].messages.firstIndex(where: { $0.id == messageID }) else { return }
        guard let branchID = threads[tIdx].messages[mIdx].branchID else { return }

        // Save current branch
        let currentIndex = threads[tIdx].messages[mIdx].branchIndex ?? 0
        let currentKey = "branch_\(branchID)_\(currentIndex)"
        let currentMessages = Array(threads[tIdx].messages[mIdx...])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(currentMessages) {
            UserDefaults.standard.set(data, forKey: currentKey)
        }

        // Load target branch
        let targetKey = "branch_\(branchID)_\(toIndex)"
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        if let data = UserDefaults.standard.data(forKey: targetKey),
           let restored = try? decoder.decode([ChatMessage].self, from: data) {
            // Replace from mIdx onwards
            threads[tIdx].messages.removeSubrange(mIdx...)
            threads[tIdx].messages.append(contentsOf: restored)
            // Update branch index on the forked message
            threads[tIdx].messages[mIdx].branchIndex = toIndex
        }
        threads[tIdx].updatedAt = Date()
        save(threads[tIdx])
    }

    /// Get total branch count for a message
    func branchCount(for messageID: UUID, in threadID: UUID) -> Int {
        guard let tIdx = threads.firstIndex(where: { $0.id == threadID }) else { return 0 }
        guard let mIdx = threads[tIdx].messages.firstIndex(where: { $0.id == messageID }) else { return 0 }
        guard let branchID = threads[tIdx].messages[mIdx].branchID else { return 0 }
        let currentIndex = threads[tIdx].messages[mIdx].branchIndex ?? 0
        // Count stored branches
        var count = 0
        for i in 0...currentIndex + 5 {
            let key = "branch_\(branchID)_\(i)"
            if UserDefaults.standard.data(forKey: key) != nil || i == currentIndex {
                count = i + 1
            }
        }
        return count
    }

    /// Search across all threads — returns matching (thread, message) pairs
    func search(_ query: String) -> [(thread: ChatThread, message: ChatMessage)] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        var results: [(thread: ChatThread, message: ChatMessage)] = []
        for thread in threads {
            // Match thread title
            if thread.title.lowercased().contains(q) {
                if let first = thread.messages.first {
                    results.append((thread, first))
                }
                continue
            }
            // Match message text
            for msg in thread.messages {
                if msg.text.lowercased().contains(q) {
                    results.append((thread, msg))
                    break // one match per thread is enough
                }
            }
        }
        return results
    }

    /// Fuzzy subsequence search — matches non-contiguous characters
    func fuzzySearch(_ query: String) -> [(thread: ChatThread, matchCount: Int, firstMatch: ChatMessage?)] {
        guard !query.isEmpty else { return [] }
        let q = query.lowercased()
        var results: [(thread: ChatThread, matchCount: Int, firstMatch: ChatMessage?)] = []
        for thread in threads {
            var count = 0
            var first: ChatMessage?
            // Check title
            if fuzzyMatch(q, in: thread.title.lowercased()) {
                count += 1
            }
            // Check messages
            for msg in thread.messages {
                if fuzzyMatch(q, in: msg.text.lowercased()) {
                    count += 1
                    if first == nil { first = msg }
                }
            }
            if count > 0 {
                results.append((thread, count, first))
            }
        }
        return results.sorted { $0.matchCount > $1.matchCount }
    }

    /// Subsequence matching: all chars of query appear in order within text
    private func fuzzyMatch(_ query: String, in text: String) -> Bool {
        var qi = query.startIndex
        var ti = text.startIndex
        while qi < query.endIndex && ti < text.endIndex {
            if query[qi] == text[ti] {
                qi = query.index(after: qi)
            }
            ti = text.index(after: ti)
        }
        return qi == query.endIndex
    }

    /// Count matches in a thread for a given query
    func matchCount(_ query: String, in thread: ChatThread) -> Int {
        guard !query.isEmpty else { return 0 }
        let q = query.lowercased()
        return thread.messages.filter { fuzzyMatch(q, in: $0.text.lowercased()) }.count
    }

    // MARK: - Folders

    func createFolder(name: String, color: String = "00FF88") {
        let folder = ThreadFolder(name: name, color: color)
        folders.append(folder)
        saveFolders()
    }

    func renameFolder(_ id: UUID, name: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].name = name
        saveFolders()
    }

    func recolorFolder(_ id: UUID, color: String) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].color = color
        saveFolders()
    }

    func deleteFolder(_ id: UUID) {
        // Unassign threads from this folder
        for i in threads.indices where threads[i].folderID == id {
            threads[i].folderID = nil
            save(threads[i])
        }
        folders.removeAll { $0.id == id }
        saveFolders()
    }

    func toggleFolderCollapse(_ id: UUID) {
        guard let idx = folders.firstIndex(where: { $0.id == id }) else { return }
        folders[idx].isCollapsed.toggle()
        saveFolders()
    }

    func moveThread(_ threadID: UUID, to folderID: UUID?) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[idx].folderID = folderID
        save(threads[idx])
    }

    func threadsInFolder(_ folderID: UUID?) -> [ChatThread] {
        sortedThreads.filter { $0.folderID == folderID }
    }

    private func loadFolders() {
        guard let data = try? Data(contentsOf: foldersURL) else { return }
        let decoder = JSONDecoder()
        folders = (try? decoder.decode([ThreadFolder].self, from: data)) ?? []
    }

    private func saveFolders() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        if let data = try? encoder.encode(folders) {
            try? data.write(to: foldersURL, options: .atomic)
        }
    }

    // MARK: - Import

    /// Import from OpenAI ChatGPT JSON export format
    func importFromChatGPTJSON(_ data: Data) -> Int {
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] else { return 0 }
        var imported = 0
        for conv in json {
            let title = conv["title"] as? String ?? "Imported Thread"
            var thread = ChatThread(title: title)
            if let mapping = conv["mapping"] as? [String: Any] {
                // ChatGPT uses a mapping dict with nodes
                var nodes: [(Date, ChatMessage)] = []
                for (_, nodeVal) in mapping {
                    guard let node = nodeVal as? [String: Any],
                          let message = node["message"] as? [String: Any],
                          let author = message["author"] as? [String: Any],
                          let role = author["role"] as? String,
                          let content = message["content"] as? [String: Any],
                          let parts = content["parts"] as? [Any] else { continue }
                    let text = parts.compactMap { $0 as? String }.joined()
                    guard !text.isEmpty else { continue }
                    let msgRole: ChatMessage.Role = role == "user" ? .user : .assistant
                    let ts = (message["create_time"] as? Double).map { Date(timeIntervalSince1970: $0) } ?? Date()
                    nodes.append((ts, ChatMessage(role: msgRole, text: text)))
                }
                nodes.sort { $0.0 < $1.0 }
                thread.messages = nodes.map { $0.1 }
            }
            if !thread.messages.isEmpty {
                threads.insert(thread, at: 0)
                save(thread)
                imported += 1
            }
        }
        return imported
    }

    /// Import from Markdown (Queen export format)
    func importFromMarkdown(_ text: String) -> Int {
        let sections = text.components(separatedBy: "\n---\n")
        guard sections.count > 1 else { return 0 }
        // First section is title
        let titleLine = sections[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let title = titleLine.hasPrefix("# ") ? String(titleLine.dropFirst(2)) : titleLine
        var thread = ChatThread(title: title)
        for section in sections.dropFirst() {
            let trimmed = section.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if trimmed.hasPrefix("**You**") {
                let text = trimmed.replacingOccurrences(of: "**You**\n\n", with: "")
                    .replacingOccurrences(of: "**You**", with: "")
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { thread.messages.append(ChatMessage(role: .user, text: text)) }
            } else if trimmed.hasPrefix("**Queen**") {
                let text = trimmed.replacingOccurrences(of: #"^\*\*Queen\*\*.*?\n\n"#, with: "", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty { thread.messages.append(ChatMessage(role: .assistant, text: text)) }
            }
        }
        if !thread.messages.isEmpty {
            threads.insert(thread, at: 0)
            save(thread)
            return 1
        }
        return 0
    }

    /// Import from plain text (split by --- separators)
    func importFromPlainText(_ text: String) -> Int {
        let parts = text.components(separatedBy: "\n---\n")
        guard parts.count >= 2 else {
            // Single block — treat as one user message
            var thread = ChatThread(title: String(text.prefix(40)))
            thread.messages.append(ChatMessage(role: .user, text: text))
            threads.insert(thread, at: 0)
            save(thread)
            return 1
        }
        var thread = ChatThread(title: String(parts[0].prefix(40).trimmingCharacters(in: .whitespacesAndNewlines)))
        for (i, part) in parts.enumerated() {
            let role: ChatMessage.Role = i % 2 == 0 ? .user : .assistant
            let trimmed = part.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                thread.messages.append(ChatMessage(role: role, text: trimmed))
            }
        }
        if !thread.messages.isEmpty {
            threads.insert(thread, at: 0)
            save(thread)
            return 1
        }
        return 0
    }

    // MARK: - Export Formats

    /// Export thread as self-contained HTML
    func exportAsHTML(_ threadID: UUID) -> String? {
        guard let thread = threads.first(where: { $0.id == threadID }) else { return nil }
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        var html = """
        <!DOCTYPE html>
        <html><head><meta charset="utf-8">
        <title>\(thread.title)</title>
        <style>
        body { background: #0a0a0a; color: #d1d1d1; font-family: -apple-system, sans-serif; max-width: 800px; margin: 0 auto; padding: 40px 20px; }
        h1 { color: #00FF88; }
        .meta { color: #888; font-size: 12px; margin-bottom: 32px; }
        .msg { padding: 16px 0; border-bottom: 1px solid #1a1a1a; }
        .user { text-align: right; }
        .user .content { background: #1a1a1a; display: inline-block; padding: 12px 16px; border-radius: 16px; font-weight: 600; }
        .assistant .role { color: #00FF88; font-size: 12px; margin-bottom: 4px; }
        .model { color: #666; font-size: 11px; }
        pre { background: #111; padding: 12px; border-radius: 8px; overflow-x: auto; }
        code { font-family: 'SF Mono', monospace; }
        </style></head><body>
        <h1>\(thread.title)</h1>
        <div class="meta">\(fmt.string(from: thread.createdAt)) | \(thread.messages.count) messages</div>
        """
        for msg in thread.messages {
            let cls = msg.role == .user ? "user" : "assistant"
            html += "<div class=\"msg \(cls)\">"
            if msg.role == .assistant {
                html += "<div class=\"role\">Queen <span class=\"model\">\(msg.modelID ?? "")</span></div>"
            }
            let escaped = msg.text
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
                .replacingOccurrences(of: ">", with: "&gt;")
                .replacingOccurrences(of: "\n", with: "<br>")
            html += "<div class=\"content\">\(escaped)</div>"
            html += "</div>"
        }
        html += "</body></html>"
        return html
    }

    /// Export thread as OpenAI-compatible JSON
    func exportAsJSON(_ threadID: UUID) -> Data? {
        guard let thread = threads.first(where: { $0.id == threadID }) else { return nil }
        let fmt = ISO8601DateFormatter()
        var messages: [[String: Any]] = []
        for msg in thread.messages {
            var dict: [String: Any] = [
                "role": msg.role.rawValue,
                "content": msg.text,
                "timestamp": fmt.string(from: msg.timestamp)
            ]
            if let model = msg.modelID { dict["model"] = model }
            if let tokens = msg.outputTokens { dict["output_tokens"] = tokens }
            messages.append(dict)
        }
        let export: [String: Any] = [
            "title": thread.title,
            "id": thread.id.uuidString,
            "created_at": fmt.string(from: thread.createdAt),
            "updated_at": fmt.string(from: thread.updatedAt),
            "messages": messages
        ]
        return try? JSONSerialization.data(withJSONObject: [export], options: [.prettyPrinted, .sortedKeys])
    }

    /// Export thread as markdown
    func exportAsMarkdown(_ threadID: UUID) -> String? {
        guard let thread = threads.first(where: { $0.id == threadID }) else { return nil }
        var md = "# \(thread.title)\n\n"
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        md += "*\(fmt.string(from: thread.createdAt))*\n\n---\n\n"
        for msg in thread.messages {
            let role = msg.role == .user ? "**You**" : "**Queen** (\(msg.modelID ?? ""))"
            md += "\(role)\n\n"
            // Include thinking text if present
            if let thinking = msg.thinkingText, !thinking.isEmpty {
                md += "<details>\n<summary>Thinking (\(thinking.count) chars)</summary>\n\n\(thinking)\n\n</details>\n\n"
            }
            md += "\(msg.text)\n\n"
            // Include metrics if present
            if let ttfb = msg.ttfbMs, let tps = msg.tokPerSec {
                md += "*TTFB: \(ttfb)ms | \(String(format: "%.0f", tps)) tok/s*\n\n"
            }
            md += "---\n\n"
        }
        return md
    }

    // MARK: - Pin / Tag / Bookmark

    func togglePin(_ threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[idx].isPinned.toggle()
        save(threads[idx])
    }

    func addTag(_ tag: String, to threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        let normalized = tag.lowercased().trimmingCharacters(in: .whitespaces)
        guard !normalized.isEmpty, !threads[idx].tags.contains(normalized) else { return }
        threads[idx].tags.append(normalized)
        save(threads[idx])
    }

    func removeTag(_ tag: String, from threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[idx].tags.removeAll { $0 == tag }
        save(threads[idx])
    }

    func toggleBookmark(_ messageID: UUID, in threadID: UUID) {
        guard let tIdx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard let mIdx = threads[tIdx].messages.firstIndex(where: { $0.id == messageID }) else { return }
        let current = threads[tIdx].messages[mIdx].isBookmarked ?? false
        threads[tIdx].messages[mIdx].isBookmarked = !current
        save(threads[tIdx])
    }

    /// Auto-generate thread summary from first few messages
    func autoSummarize(_ threadID: UUID) -> String? {
        guard let thread = threads.first(where: { $0.id == threadID }) else { return nil }
        let msgs = thread.messages.prefix(6)
        var topics: [String] = []
        for msg in msgs where msg.role == .user {
            let words = msg.text.split(separator: " ").prefix(8).joined(separator: " ")
            if !words.isEmpty { topics.append(words) }
        }
        guard !topics.isEmpty else { return nil }
        let summary = topics.prefix(3).joined(separator: " | ")
        return String(summary.prefix(80))
    }

    /// Get all bookmarked messages across all threads
    func allBookmarks() -> [(thread: ChatThread, message: ChatMessage)] {
        var results: [(thread: ChatThread, message: ChatMessage)] = []
        for thread in threads {
            for msg in thread.messages {
                if msg.isBookmarked == true {
                    results.append((thread, msg))
                }
            }
        }
        return results.sorted { ($0.message.timestamp) > ($1.message.timestamp) }
    }

    /// All unique tags across threads
    var allTags: [String] {
        Array(Set(threads.flatMap(\.tags))).sorted()
    }

    /// Sorted threads: pinned first, then by updatedAt
    var sortedThreads: [ChatThread] {
        threads.sorted { a, b in
            if a.isPinned != b.isPinned { return a.isPinned }
            return a.updatedAt > b.updatedAt
        }
    }

    func updateLastMessageCitations(_ citations: [Citation], in threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard !threads[idx].messages.isEmpty else { return }
        let lastIdx = threads[idx].messages.count - 1
        threads[idx].messages[lastIdx].citations = citations
    }

    func updateMessageMetrics(_ messageID: UUID, ttfbMs: Int, tokPerSec: Double, outputTokens: Int, totalMs: Int, in threadID: UUID) {
        guard let tIdx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard let mIdx = threads[tIdx].messages.firstIndex(where: { $0.id == messageID }) else { return }
        threads[tIdx].messages[mIdx].ttfbMs = ttfbMs
        threads[tIdx].messages[mIdx].tokPerSec = tokPerSec
        threads[tIdx].messages[mIdx].outputTokens = outputTokens
        threads[tIdx].messages[mIdx].totalMs = totalMs
        save(threads[tIdx])
    }

    /// Duplicate a thread: new UUID, title + " (copy)", same messages/tags/persona
    @discardableResult
    func duplicateThread(_ threadID: UUID) -> UUID? {
        guard let original = threads.first(where: { $0.id == threadID }) else { return nil }
        var copy = ChatThread(title: original.title + " (copy)")
        copy.messages = original.messages.map { msg in
            // Create new message IDs so they are independent
            var newMsg = ChatMessage(role: msg.role, text: msg.text, modelID: msg.modelID, imageURLs: msg.imageURLs)
            newMsg.isLiked = msg.isLiked
            newMsg.isBookmarked = msg.isBookmarked
            newMsg.thinkingText = msg.thinkingText
            newMsg.ttfbMs = msg.ttfbMs
            newMsg.tokPerSec = msg.tokPerSec
            newMsg.outputTokens = msg.outputTokens
            newMsg.totalMs = msg.totalMs
            newMsg.citations = msg.citations
            newMsg.errorKind = msg.errorKind
            return newMsg
        }
        copy.tags = original.tags
        copy.personaID = original.personaID
        copy.folderID = original.folderID
        threads.insert(copy, at: 0)
        save(copy)
        activeThreadID = copy.id
        return copy.id
    }

    func saveThread(_ threadID: UUID) {
        guard let thread = threads.first(where: { $0.id == threadID }) else { return }
        save(thread)
    }

    func activeThread() -> ChatThread? {
        threads.first { $0.id == activeThreadID }
    }

    // MARK: - Disk I/O

    private func load() {
        guard let files = try? FileManager.default.contentsOfDirectory(
            at: storeURL, includingPropertiesForKeys: nil
        ) else { return }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        threads = files
            .filter { $0.pathExtension == "json" }
            .compactMap { url -> ChatThread? in
                guard let data = try? Data(contentsOf: url) else { return nil }
                return try? decoder.decode(ChatThread.self, from: data)
            }
            .sorted { $0.updatedAt > $1.updatedAt }

        activeThreadID = threads.first?.id
        isLoaded = true
    }

    private func save(_ thread: ChatThread) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let url = storeURL.appendingPathComponent("\(thread.id).json")
        if let data = try? encoder.encode(thread) {
            try? data.write(to: url, options: .atomic)
        }
    }

    /// Auto-cleanup: suggest archiving threads older than 90 days instead of deleting
    func cleanupOldThreads() {
        if !staleThreads.isEmpty {
            showArchiveSuggestion = true
        }
    }

    // MARK: - Archive

    /// Threads older than 90 days that are not pinned and not already archived
    var staleThreads: [ChatThread] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -90, to: Date()) ?? Date()
        return threads.filter { $0.updatedAt < cutoff && !$0.isPinned && !$0.isArchived }
    }

    /// Archived threads
    var archivedThreads: [ChatThread] {
        threads.filter { $0.isArchived }.sorted { $0.updatedAt > $1.updatedAt }
    }

    func archiveThread(_ threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[idx].isArchived = true
        save(threads[idx])
    }

    func unarchiveThread(_ threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[idx].isArchived = false
        save(threads[idx])
    }

    func archiveAllStale() {
        for thread in staleThreads {
            if let idx = threads.firstIndex(where: { $0.id == thread.id }) {
                threads[idx].isArchived = true
                save(threads[idx])
            }
        }
        showArchiveSuggestion = false
    }
}
