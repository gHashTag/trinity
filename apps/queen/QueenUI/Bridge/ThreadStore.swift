import Foundation

@MainActor
final class ThreadStore: ObservableObject {
    @Published var threads: [ChatThread] = []
    @Published var activeThreadID: UUID?

    private let storeURL: URL

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        storeURL = appSupport.appendingPathComponent("QueenUI/threads", isDirectory: true)
        try? FileManager.default.createDirectory(at: storeURL, withIntermediateDirectories: true)
        load()
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
        threads.removeAll { $0.id == thread.id }
        let url = storeURL.appendingPathComponent("\(thread.id).json")
        try? FileManager.default.removeItem(at: url)
        if activeThreadID == thread.id {
            activeThreadID = threads.first?.id
        }
    }

    func rename(_ id: UUID, title: String) {
        guard let idx = threads.firstIndex(where: { $0.id == id }) else { return }
        threads[idx].title = title
        save(threads[idx])
    }

    func appendMessage(_ msg: ChatMessage, to threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        threads[idx].messages.append(msg)
        threads[idx].updatedAt = Date()
        save(threads[idx])
    }

    func updateLastMessage(text: String, in threadID: UUID) {
        guard let idx = threads.firstIndex(where: { $0.id == threadID }) else { return }
        guard !threads[idx].messages.isEmpty else { return }
        let lastIdx = threads[idx].messages.count - 1
        threads[idx].messages[lastIdx].text = text
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

    /// Export thread as markdown
    func exportAsMarkdown(_ threadID: UUID) -> String? {
        guard let thread = threads.first(where: { $0.id == threadID }) else { return nil }
        var md = "# \(thread.title)\n\n"
        let fmt = DateFormatter()
        fmt.dateFormat = "yyyy-MM-dd HH:mm"
        md += "*\(fmt.string(from: thread.createdAt))*\n\n---\n\n"
        for msg in thread.messages {
            let role = msg.role == .user ? "**You**" : "**Queen** (\(msg.modelID ?? ""))"
            md += "\(role)\n\n\(msg.text)\n\n---\n\n"
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
}
