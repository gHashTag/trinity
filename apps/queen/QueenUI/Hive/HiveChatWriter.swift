import Foundation

/// Opens a real Queen chat for every hive task and streams the bee's work into
/// it, so "the Queen opened a chat for this task" is literally true: the thread
/// appears in the chat sidebar next to the user's own conversations.
///
/// Writes into the same Application Support directory `ThreadStore` reads, in
/// the same encoding, rather than reaching into `ThreadStore` itself - the
/// store is constructed per-view and there is no shared instance to mutate.
@MainActor
final class HiveChatWriter {

    private let threadsDirectory: URL
    private var thread: ChatThread
    private var assistantIndex: Int?
    private var buffer = ""
    private var lastFlush = Date.distantPast
    /// Streaming events are frequent; the thread file is rewritten whole, so
    /// flushes are debounced instead of running per event.
    private let flushInterval: TimeInterval = 2.0

    init?(task: HiveTask, sessionID: String, directory: URL? = nil) {
        let resolved = directory ?? Self.defaultThreadsDirectory()
        guard let resolved else { return nil }
        self.threadsDirectory = resolved
        try? FileManager.default.createDirectory(at: resolved, withIntermediateDirectories: true)

        var thread = ChatThread(title: "🐝 \(task.title)")
        thread.tags = ["hive", task.module, task.signalKind]
        thread.colorLabel = "FFD700"
        thread.summary = task.reason
        thread.customSystemPrompt = "Hive bee session \(sessionID) - resume with: claude --resume \(sessionID)"
        thread.messages = [
            ChatMessage(role: .user, text: task.prompt)
        ]
        self.thread = thread
        persist()
    }

    static func defaultThreadsDirectory() -> URL? {
        let fm = FileManager.default
        guard let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fm.urls(for: .documentDirectory, in: .userDomainMask).first else { return nil }
        return appSupport.appendingPathComponent("QueenUI/threads", isDirectory: true)
    }

    var threadID: UUID { thread.id }

    // MARK: - Streaming

    func append(_ event: BeeEvent) {
        switch event.kind {
        case .assistant where !event.text.isEmpty:
            buffer += (buffer.isEmpty ? "" : "\n\n") + event.text
        case .tool(let name):
            buffer += (buffer.isEmpty ? "" : "\n") + "`\(name)`"
        case .system, .toolResult, .raw, .result, .assistant:
            return
        }
        writeBuffer()
        flushIfDue()
    }

    func finish(_ outcome: BeeOutcome) {
        let verdict: String
        switch outcome.status {
        case .succeeded: verdict = "✅ done"
        case .failed: verdict = "❌ failed"
        case .timedOut: verdict = "⏱ timed out"
        case .cancelled: verdict = "⛔️ cancelled"
        case .starting, .working: verdict = "..."
        }

        var footer = "\n\n---\n**\(verdict)**"
        if !outcome.summary.isEmpty {
            footer += "\n\n\(outcome.summary)"
        }
        if let cost = outcome.costUSD {
            footer += String(format: "\n\ncost $%.3f", cost)
        }
        if let ms = outcome.durationMs {
            footer += String(format: " - %.1f min", Double(ms) / 60_000.0)
        }
        buffer += footer
        writeBuffer()
        flush(force: true)
    }

    // MARK: - Persistence

    private func writeBuffer() {
        let message: ChatMessage
        if let index = assistantIndex, thread.messages.indices.contains(index) {
            thread.messages[index].text = buffer
            thread.updatedAt = Date()
            return
        }
        message = ChatMessage(role: .assistant, text: buffer)
        thread.messages.append(message)
        assistantIndex = thread.messages.count - 1
        thread.updatedAt = Date()
    }

    private func flushIfDue() {
        guard Date().timeIntervalSince(lastFlush) >= flushInterval else { return }
        flush(force: true)
    }

    private func flush(force: Bool) {
        guard force else { return }
        lastFlush = Date()
        persist()
    }

    private func persist() {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = .prettyPrinted
        let url = threadsDirectory.appendingPathComponent("\(thread.id).json")
        guard let data = try? encoder.encode(thread) else { return }
        try? data.write(to: url, options: .atomic)
    }
}
