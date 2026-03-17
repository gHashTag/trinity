import Foundation
import SwiftUI
import AppKit

/// Chat mode: determines how the message is routed
enum ChatMode: String, CaseIterable, Codable {
    case search = "Search"
    case trinity = "Trinity"
    case reason = "Reason"
    case compare = "Compare"
    case image = "Image"

    var icon: String {
        switch self {
        case .search: return "magnifyingglass"
        case .trinity: return "crown.fill"
        case .reason: return "lightbulb.max"
        case .compare: return "arrow.left.arrow.right"
        case .image: return "photo"
        }
    }

    var systemSuffix: String {
        switch self {
        case .search: return "\nYou are in web search mode. Ground your answers with real-time web data. Cite sources."
        case .trinity: return ""
        case .reason: return "\nThink step-by-step. Break down complex problems. Show your reasoning chain clearly."
        case .compare: return ""
        case .image: return ""
        }
    }
}

/// Effort level: controls reasoning depth and max tokens
enum EffortLevel: String, CaseIterable, Identifiable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"
    case max = "Max"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .low: return "hare"
        case .medium: return "figure.walk"
        case .high: return "figure.run"
        case .max: return "brain.head.profile"
        }
    }

    var maxTokens: Int {
        switch self {
        case .low: return 1024
        case .medium: return 4096
        case .high: return 8192
        case .max: return 16384
        }
    }

    var thinkingBudget: Int? {
        switch self {
        case .low: return nil
        case .medium: return nil
        case .high: return 4096
        case .max: return 16384
        }
    }

    var systemSuffix: String {
        switch self {
        case .low: return "\nBe extremely brief. One-sentence answers. Skip details."
        case .medium: return ""
        case .high: return "\nBe thorough. Consider edge cases. Provide detailed analysis."
        case .max: return "\nMaximum depth. Exhaustive analysis. Consider all angles. Show full reasoning."
        }
    }

    var color: Color {
        switch self {
        case .low: return Color(hex: 0x8BE9FD)
        case .medium: return Color(hex: 0x00FF88)
        case .high: return Color(hex: 0xFFD700)
        case .max: return Color(hex: 0xFF6B6B)
        }
    }
}

/// Slash command: quick actions from chat input
enum SlashCommand: String, CaseIterable {
    case effort = "/effort"
    case model = "/model"
    case compact = "/compact"
    case cost = "/cost"
    case clear = "/clear"
    case export = "/export"
    case mode = "/mode"
    case fast = "/fast"
    case branch = "/branch"
    case help = "/help"

    var description: String {
        switch self {
        case .effort: return "Set effort level (low/medium/high/max)"
        case .model: return "Switch model"
        case .compact: return "Summarize conversation to free context"
        case .cost: return "Show session cost breakdown"
        case .clear: return "Clear current thread"
        case .export: return "Export thread as markdown"
        case .mode: return "Switch chat mode"
        case .fast: return "Toggle fast mode (Haiku)"
        case .branch: return "Show current git branch"
        case .help: return "Show available commands"
        }
    }

    var icon: String {
        switch self {
        case .effort: return "gauge.with.dots.needle.33percent"
        case .model: return "cpu"
        case .compact: return "arrow.down.right.and.arrow.up.left"
        case .cost: return "dollarsign.circle"
        case .clear: return "trash"
        case .export: return "square.and.arrow.up"
        case .mode: return "switch.2"
        case .fast: return "hare"
        case .branch: return "arrow.triangle.branch"
        case .help: return "questionmark.circle"
        }
    }

    /// Parse a slash command from input text. Returns (command, argument) or nil.
    static func parse(_ input: String) -> (SlashCommand, String?)? {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("/") else { return nil }
        let parts = trimmed.split(separator: " ", maxSplits: 1)
        let cmdStr = String(parts[0]).lowercased()
        let arg = parts.count > 1 ? String(parts[1]) : nil

        for cmd in SlashCommand.allCases {
            if cmd.rawValue == cmdStr { return (cmd, arg) }
        }
        return nil
    }
}

/// Sound cue manager for audio feedback
class SoundCueManager {
    static let shared = SoundCueManager()

    private var enabled: Bool {
        UserDefaults.standard.string(forKey: "soundMode") != "silent"
    }

    func playSend() {
        guard enabled else { return }
        NSSound(named: "Tink")?.play()
    }

    func playReceive() {
        guard enabled else { return }
        NSSound(named: "Pop")?.play()
    }

    func playError() {
        guard enabled else { return }
        NSSound(named: "Basso")?.play()
    }
}

/// Style preset: controls CTO tone
enum StylePreset: String, CaseIterable, Identifiable {
    case concise = "Concise"
    case detailed = "Detailed"
    case codeFirst = "Code First"
    case ctoBlunt = "CTO Blunt"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .concise: return "text.alignleft"
        case .detailed: return "doc.text.magnifyingglass"
        case .codeFirst: return "curlybraces"
        case .ctoBlunt: return "bolt.fill"
        }
    }

    var systemSuffix: String {
        switch self {
        case .concise: return "\nBe extremely brief. One-sentence answers when possible. No preamble."
        case .detailed: return "\nBe thorough and comprehensive. Explain reasoning, trade-offs, and alternatives."
        case .codeFirst: return "\nLead with code. Show the solution first, explain after if needed."
        case .ctoBlunt: return "\nPoint out problems directly. No sugar-coating. Be blunt about risks and bad decisions."
        }
    }
}

/// Memory entry extracted from chat
struct MemoryEntry: Codable, Identifiable {
    var id: UUID
    let text: String
    let source: String  // message snippet that triggered extraction
    let timestamp: Date

    init(text: String, source: String) {
        self.id = UUID()
        self.text = text
        self.source = source
        self.timestamp = Date()
    }
}

/// Typed API error for user-friendly messages
enum APIErrorType {
    case unauthorized       // 401 — bad/expired key
    case rateLimited(retryAfter: Int?)  // 429 — rate limit
    case serverError(Int)   // 5xx
    case timeout            // connection or TTFB timeout
    case connectionFailed   // no network
    case malformedResponse  // 200 but bad JSON
    case unknown(Int, String)

    var userMessage: String {
        switch self {
        case .unauthorized:
            return "API key invalid or expired. Check .env file."
        case .rateLimited(let retry):
            if let s = retry { return "Rate limited. Retry in \(s)s." }
            return "Rate limited. Wait a moment and retry."
        case .serverError(let code):
            return "Server error (\(code)). Provider may be down."
        case .timeout:
            return "Request timed out (>30s). Try a faster model."
        case .connectionFailed:
            return "No connection. Check your network."
        case .malformedResponse:
            return "Received corrupted response. Retry."
        case .unknown(let code, let body):
            return "Error \(code): \(String(body.prefix(200)))"
        }
    }

    var icon: String {
        switch self {
        case .unauthorized: return "key.slash"
        case .rateLimited: return "clock.badge.exclamationmark"
        case .serverError: return "exclamationmark.icloud"
        case .timeout: return "clock.arrow.circlepath"
        case .connectionFailed: return "wifi.slash"
        case .malformedResponse: return "doc.badge.gearshape"
        case .unknown: return "exclamationmark.triangle"
        }
    }

    static func from(statusCode: Int, body: String, headers: HTTPURLResponse?) -> APIErrorType {
        switch statusCode {
        case 401, 403: return .unauthorized
        case 429:
            let retryAfter = headers?.value(forHTTPHeaderField: "Retry-After").flatMap(Int.init)
            return .rateLimited(retryAfter: retryAfter)
        case 500...599: return .serverError(statusCode)
        default: return .unknown(statusCode, body)
        }
    }
}

/// Streaming lifecycle: idle → connecting → streaming → done/error
enum StreamingState: Equatable {
    case idle
    case connecting      // request sent, waiting for first token
    case streaming       // tokens actively flowing
    case done
    case error(String)
}

@MainActor
class ChatClient: ObservableObject {
    @Published var streamingState: StreamingState = .idle
    /// Backward-compatible computed property
    var isStreaming: Bool {
        switch streamingState {
        case .connecting, .streaming: return true
        default: return false
        }
    }
    @Published var streamingText = ""
    @Published var streamingTokensPerSec: Double = 0
    @Published var streamingTTFB: Int = 0          // ms to first token
    @Published var streamingOutputTokens: Int = 0
    @Published var failoverEvent: FailoverEvent? = nil
    @Published var lastError: APIErrorType? = nil
    @Published var isSlowResponse = false          // TTFB > 5s warning
    @Published var streamingThinkingText = ""
    @Published var proposedMemories: [MemoryEntry] = []
    @Published var followUpSuggestions: [String] = []
    @Published var extractedTasks: [String] = []
    @Published var elicitationQuestion: (question: String, options: [String])? = nil
    @Published var showRejectionFeedback: (messageID: UUID, threadID: UUID)? = nil
    @Published var activeToolCalls: [ToolCallStep] = []

    struct ToolCallStep: Identifiable {
        let id = UUID()
        let name: String
        let args: String
        var status: ToolStatus = .running
        let startTime = Date()

        enum ToolStatus {
            case running, success, error
        }
    }

    struct FailoverEvent: Equatable {
        let from: String
        let to: String
        let timestamp: Date
    }

    // MARK: - Stream Timeout
    @Published var streamTimeout: Bool = false
    private var timeoutTask: Task<Void, Never>?
    private var lastTokenTime: Date = .distantPast

    /// Start timeout watchdog: 30s connect (60s reason), 15s inactivity after first token
    func startStreamTimeout(isReasonMode: Bool = false) {
        streamTimeout = false
        lastTokenTime = .distantPast
        let connectTimeout: TimeInterval = isReasonMode ? 60 : 30
        let inactivityTimeout: TimeInterval = 15

        timeoutTask = Task { [weak self] in
            // Phase 1: wait for first token
            try? await Task.sleep(for: .seconds(connectTimeout))
            guard let self, !Task.isCancelled else { return }
            if self.streamingState == .connecting {
                self.handleStreamTimeout("No response after \(Int(connectTimeout))s")
                return
            }
            // Phase 2: inactivity check loop
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                guard !Task.isCancelled, self.isStreaming else { return }
                if Date().timeIntervalSince(self.lastTokenTime) > inactivityTimeout {
                    self.handleStreamTimeout("No tokens for \(Int(inactivityTimeout))s")
                    return
                }
            }
        }
    }

    func recordTokenReceived() {
        lastTokenTime = Date()
        if streamingState == .connecting { streamingState = .streaming }
    }

    private func handleStreamTimeout(_ reason: String) {
        streamTimeout = true
        if streamingOutputTokens > 10 {
            streamingText += "\n\n*[Timed out: \(reason)]*"
        }
        streamingState = .error(reason)
        stop()
    }

    func cancelStreamTimeout() {
        timeoutTask?.cancel()
        timeoutTask = nil
    }

    // MARK: - Batched Store Updates (reduce disk writes from ~100/sec to ~2/sec)
    private var lastStoreWrite: Date = .distantPast
    private let storeWriteInterval: TimeInterval = 0.5

    func bufferedUpdateMessage(store: ThreadStore, threadID: UUID) {
        let now = Date()
        if now.timeIntervalSince(lastStoreWrite) >= storeWriteInterval {
            store.updateLastMessage(text: streamingText, in: threadID)
            lastStoreWrite = now
        }
    }

    func flushToStore(store: ThreadStore, threadID: UUID) {
        store.updateLastMessage(text: streamingText, in: threadID)
        lastStoreWrite = .distantPast
    }

    // MARK: - Offline Queue
    @Published var offlineQueueCount: Int = 0
    @Published var queueDrainedCount: Int = 0  // set when drain succeeds, UI shows toast
    @Published var failoverLog: [FailoverEvent] = []

    struct QueuedMessage: Identifiable, Codable {
        var id = UUID()
        let text: String
        let threadID: UUID
        let mode: ChatMode
    }

    @Published var offlineQueue: [QueuedMessage] = []
    private var offlineDrainTask: Task<Void, Never>?

    private var queueURL: URL {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("QueenUI/offline_queue.json")
    }

    func loadPersistedQueue() {
        guard let data = try? Data(contentsOf: queueURL) else { return }
        let decoder = JSONDecoder()
        if let loaded = try? decoder.decode([QueuedMessage].self, from: data), !loaded.isEmpty {
            offlineQueue = loaded
            offlineQueueCount = loaded.count
        }
    }

    private func persistQueue() {
        let encoder = JSONEncoder()
        if let data = try? encoder.encode(offlineQueue) {
            try? data.write(to: queueURL, options: .atomic)
        }
    }

    private var streamTask: Task<Void, Never>?
    private let repo = RepoContext()
    private var streamStartTime: Date?
    private var firstTokenTime: Date?
    private var lastCheckpointTokens: Int = 0

    var stylePreset: StylePreset = .concise
    var effortLevel: EffortLevel = .medium
    var activePersona: Persona? = nil

    private var systemPrompt: String {
        buildSystemPrompt()
    }

    private func buildSystemPrompt() -> String {
        var prompt = """
            You are Queen — the personal CTO agent of the Trinity project.
            Trinity is a pure Zig autonomous AI agent swarm with ternary {-1,0,+1} computing.
            Answer concisely in the user's language. You are wise, direct, and technically precise.

            ## Your Capabilities
            You HAVE full access to:
            - The Trinity repository (read any file, see git history, search code)
            - Live Trinity state (build status, farm PPL, arena battles, open issues)
            - The `tri` CLI (can execute any `tri` command)
            - MCP tools through the Trinity MCP server

            ## Tools
            To read a file, output: [READ:path/to/file]
            To run a tri command, output: [RUN:tri <command>]
            To search code, output: [GREP:pattern]

            Examples:
            - [READ:src/vsa.zig] — read VSA source
            - [RUN:tri git status] — check working tree
            - [RUN:tri test] — run tests
            - [RUN:tri issue list] — list open issues
            - [RUN:tri faculty] — agent dashboard
            - [GREP:fn bind] — search for function

            After you output a tool tag, the result will be injected and you can continue.
            Always use these tools when the user asks about code, build, tests, or project state.
            Never say "I don't have access" — you DO have access through these tools.
            """

        // Inject CLAUDE.md context (first 2000 chars)
        if let claude = repo.claudeMD() {
            prompt += "\n\n## Project Instructions\n" + String(claude.prefix(2000))
        }

        // Inject live Trinity state (build, farm, arena, issues)
        let trinityCtx = TrinityContext.shared
        trinityCtx.refresh()
        let ctxSummary = trinityCtx.buildContextSummary()
        if !ctxSummary.isEmpty {
            prompt += "\n\n" + ctxSummary
        }

        // Inject recent farm events
        let farmEvents = trinityCtx.recentFarmEvents(count: 3)
        if !farmEvents.isEmpty {
            prompt += "\n\n" + farmEvents
        }

        // Inject persona override
        if let persona = activePersona {
            prompt += "\n\n## Active Persona: \(persona.name)\n" + persona.systemPrompt
        }

        // Inject style preset
        if stylePreset != .concise {
            prompt += stylePreset.systemSuffix
        }

        // Inject effort level
        if effortLevel != .medium {
            prompt += effortLevel.systemSuffix
        }

        // Inject saved memories (capped at 20)
        let store = ThreadStore()
        let memories = store.loadMemories()
        if !memories.isEmpty {
            prompt += "\n\n## Remembered Context\n"
            for mem in memories.suffix(20) {
                prompt += "- \(mem.text)\n"
            }
        }

        return prompt
    }

    /// Map APIErrorType to MessageErrorKind for structured error display
    private func errorKind(from apiError: APIErrorType?) -> MessageErrorKind {
        guard let apiError else { return .serverError }
        switch apiError {
        case .unauthorized: return .unauthorized
        case .rateLimited: return .rateLimited
        case .serverError: return .serverError
        case .timeout: return .timeout
        case .connectionFailed: return .connectionFailed
        case .malformedResponse: return .serverError
        case .unknown: return .serverError
        }
    }

    /// Set structured error on last message
    private func setError(_ kind: MessageErrorKind, text: String, threadID: UUID, store: ThreadStore) {
        store.updateLastMessage(text: text, in: threadID)
        store.setLastMessageError(kind, in: threadID)
    }

    /// Build repo summary as a content block (not system prompt) for first message
    func buildRepoSummary() -> String {
        var summary = "## Repository Structure\n"
        summary += repo.fileTree(depth: 2)
        summary += "\n\n## Recent Commits\n"
        summary += repo.recentCommits(count: 5).joined(separator: "\n")
        return summary
    }

    /// Process all tool tags in AI response: [READ:], [RUN:], [GREP:]
    func processToolTags(_ text: String) -> String? {
        var results: [String] = []
        clearToolCalls()

        // [READ:path/to/file] or [READ:file://path]
        let readPattern = #"\[READ:(?:file://)?([^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: readPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                let path = String(text[r])
                let step = ToolCallStep(name: "READ", args: path)
                activeToolCalls.append(step)
                if let content = repo.readFile(path) {
                    results.append("**\(path)**\n```\n\(String(content.prefix(6000)))\n```")
                    TrinityContext.shared.recordAttachedFile(path, size: content.count)
                    completeToolCall(step.id, success: true)
                } else {
                    results.append("**\(path)**: file not found")
                    completeToolCall(step.id, success: false)
                }
            }
        }

        // [RUN:tri <command>]
        let runPattern = #"\[RUN:(tri [^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: runPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                let cmd = String(text[r])
                let step = ToolCallStep(name: "RUN", args: cmd)
                activeToolCalls.append(step)
                let output = runTriCommand(cmd)
                let success = !output.hasPrefix("[Error") && !output.hasPrefix("[Blocked")
                completeToolCall(step.id, success: success)
                results.append("**$ \(cmd)**\n```\n\(String(output.prefix(4000)))\n```")
            }
        }

        // [GREP:pattern]
        let grepPattern = #"\[GREP:([^\]]+)\]"#
        if let regex = try? NSRegularExpression(pattern: grepPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                let query = String(text[r])
                let step = ToolCallStep(name: "GREP", args: query)
                activeToolCalls.append(step)
                let searchResults = repo.searchCode(query)
                let formatted = searchResults.prefix(10).map { "\($0.file):\($0.line): \($0.content)" }.joined(separator: "\n")
                completeToolCall(step.id, success: !searchResults.isEmpty)
                results.append("**grep: \(query)**\n```\n\(formatted.isEmpty ? "No matches" : formatted)\n```")
            }
        }

        return results.isEmpty ? nil : results.joined(separator: "\n\n")
    }

    /// Execute a tri CLI command safely (read-only commands only)
    private func runTriCommand(_ command: String) -> String {
        // Safety: only allow read-only tri commands
        let args = command.components(separatedBy: " ")
        guard args.first == "tri" else { return "[Error: only tri commands allowed]" }

        // Block destructive commands
        let blocked = ["push", "delete", "kill", "deploy", "redeploy", "cloud spawn"]
        for b in blocked {
            if command.contains(b) {
                return "[Blocked: \(b) is a destructive command. Use the terminal directly.]"
            }
        }

        let pipe = Pipe()
        let errPipe = Pipe()
        let process = Process()
        let triPath = "\(repo.rootPath)/zig-out/bin/tri"

        // Check if tri binary exists
        guard FileManager.default.fileExists(atPath: triPath) else {
            return "[tri binary not found at \(triPath). Run: zig build]"
        }

        process.executableURL = URL(fileURLWithPath: triPath)
        process.arguments = Array(args.dropFirst()) // remove "tri" prefix
        process.currentDirectoryURL = URL(fileURLWithPath: repo.rootPath)
        process.standardOutput = pipe
        process.standardError = errPipe

        do {
            try process.run()
            process.waitUntilExit()
        } catch {
            return "[Error running tri: \(error.localizedDescription)]"
        }

        let stdout = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        let stderr = String(data: errPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

        if process.terminationStatus != 0 {
            return stdout.isEmpty ? stderr : stdout + "\n" + stderr
        }
        return stdout.isEmpty ? "(no output)" : stdout
    }

    /// Auto-detect file paths in user message and attach contents
    func attachFileContext(_ text: String) -> String? {
        var paths = repo.detectPaths(in: text)

        // Parse @file:path mentions
        let mentionPattern = #"@file:([^\s]+)"#
        if let regex = try? NSRegularExpression(pattern: mentionPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                let path = String(text[r])
                if !paths.contains(path) { paths.append(path) }
            }
        }

        // Parse @grep:query mentions
        let grepPattern = #"@grep:([^\s]+)"#
        var grepResults: [String] = []
        if let regex = try? NSRegularExpression(pattern: grepPattern) {
            let range = NSRange(text.startIndex..., in: text)
            for match in regex.matches(in: text, range: range) {
                guard let r = Range(match.range(at: 1), in: text) else { continue }
                let query = String(text[r])
                let results = repo.searchCode(query)
                let formatted = results.prefix(10).map { "\($0.file):\($0.line): \($0.content)" }.joined(separator: "\n")
                if !formatted.isEmpty {
                    grepResults.append("### grep: \(query)\n```\n\(formatted)\n```")
                }
            }
        }

        // Parse @build mention — last build output
        if text.contains("@build") {
            let buildLog = TrinityContext.shared.lastBuildLog()
            if !buildLog.isEmpty {
                grepResults.append("### Build Status\n```\n\(String(buildLog.prefix(4000)))\n```")
            }
        }

        // Parse @farm mention — farm events snapshot
        if text.contains("@farm") {
            let farmSnap = TrinityContext.shared.farmSnapshot()
            if !farmSnap.isEmpty {
                grepResults.append("### Farm Status\n\(farmSnap)")
            }
        }

        // Parse @issues mention — open issues summary
        if text.contains("@issues") {
            let issuesSummary = TrinityContext.shared.openIssuesSummary()
            if !issuesSummary.isEmpty {
                grepResults.append("### Open Issues\n```\n\(String(issuesSummary.prefix(4000)))\n```")
            }
        }

        // Parse @gitdiff mention — HEAD diff
        if text.contains("@gitdiff") {
            let diff = TrinityContext.shared.headDiff()
            if !diff.isEmpty {
                grepResults.append("### Git Diff (HEAD)\n```diff\n\(String(diff.prefix(6000)))\n```")
            }
        }

        guard !paths.isEmpty || !grepResults.isEmpty else { return nil }
        var context: [String] = grepResults
        for path in paths.prefix(3) {
            if let content = repo.readFile(path) {
                context.append("### \(path)\n```\n\(String(content.prefix(4000)))\n```")
                TrinityContext.shared.recordAttachedFile(path, size: content.count)
            }
        }
        return context.isEmpty ? nil : context.joined(separator: "\n\n")
    }

    /// Extract citations from Perplexity API response
    static func extractCitations(from text: String) -> [Citation] {
        // Match [1], [2], etc. and try to pair with URLs in the text
        var citations: [Citation] = []
        let urlPattern = #"https?://[^\s\)\]\"']+"#
        guard let regex = try? NSRegularExpression(pattern: urlPattern) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        for match in regex.matches(in: text, range: range) {
            guard let r = Range(match.range, in: text) else { continue }
            let url = String(text[r])
            let domain = URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "")
            if !citations.contains(where: { $0.url == url }) {
                citations.append(Citation(url: url, title: nil, domain: domain))
            }
        }
        return citations
    }

    func send(_ text: String, threadID: UUID, store: ThreadStore, modelManager: ModelManager, mode: ChatMode = .trinity, modelOverride: AIModel? = nil) {
        // Sound cue on send
        SoundCueManager.shared.playSend()

        // Image mode — route to xAI image generation
        if mode == .image {
            sendImageGeneration(text, threadID: threadID, store: store, modelManager: modelManager)
            return
        }

        // Offline queue: if selected provider is down, queue for later
        let providerName = modelManager.selectedModel.provider.rawValue
        if let status = NetworkLog.shared.providerHealth[providerName], !status.isUp {
            offlineQueue.append(QueuedMessage(text: text, threadID: threadID, mode: mode))
            offlineQueueCount = offlineQueue.count
            persistQueue()
            // Add user message with queued indicator
            let userMsg = ChatMessage(role: .user, text: text)
            store.appendMessage(userMsg, to: threadID)
            let queuedMsg = ChatMessage(role: .assistant, text: "*[Queued — will send when \(providerName) is back online]*", modelID: modelManager.selectedModel.id)
            store.appendMessage(queuedMsg, to: threadID)
            store.saveThread(threadID)
            startOfflineDrain(store: store, modelManager: modelManager)
            return
        }

        // Auto-detect file paths in user message and attach file contents
        var enrichedText = text
        if let fileContext = attachFileContext(text) {
            enrichedText += "\n\n---\n[Attached file contents]\n" + fileContext
        }

        let userMsg = ChatMessage(role: .user, text: text)
        store.appendMessage(userMsg, to: threadID)

        // Resolve model based on mode or override
        let model: AIModel
        if let override = modelOverride {
            model = override
        } else {
            switch mode {
            case .search:
                model = AIModel.allModels.first(where: { $0.id == "sonar-pro" }) ?? modelManager.selectedModel
            case .reason:
                model = AIModel.allModels.first(where: { $0.id == "sonar-reasoning-pro" }) ?? modelManager.selectedModel
            case .trinity, .image, .compare:
                model = modelManager.selectedModel
            }
        }

        let assistantMsg = ChatMessage(role: .assistant, text: "", modelID: model.id)
        store.appendMessage(assistantMsg, to: threadID)

        streamingState = .connecting
        streamingText = ""
        streamingThinkingText = ""
        lastCheckpointTokens = 0
        activeStreamThreadID = threadID
        activeStreamStore = store

        var history: [[String: String]] = store.activeThread()?.messages
            .filter { !$0.text.isEmpty }
            .map { ["role": $0.role.rawValue, "content": $0.text] } ?? []

        let isFirstExchange = (store.activeThread()?.messages.count ?? 0) == 2

        // For first exchange, inject repo summary as context
        if isFirstExchange {
            let repoSummary = buildRepoSummary()
            history.insert(["role": "user", "content": repoSummary], at: 0)
            history.insert(["role": "assistant", "content": "I see the repository structure. How can I help?"], at: 1)
        }

        // Replace the last user message content with enriched version (with file attachments)
        if enrichedText != text, let lastIdx = history.indices.last(where: { history[$0]["role"] == "user" }) {
            history[lastIdx] = ["role": "user", "content": enrichedText]
        }

        let chatMode = mode

        let assistantMsgID = assistantMsg.id
        streamTask = Task {
            do {
                try await streamResponse(
                    history: history,
                    threadID: threadID,
                    store: store,
                    model: model,
                    modelManager: modelManager,
                    mode: chatMode
                )

                // Persist streaming metrics to message
                saveMetrics(messageID: assistantMsgID, threadID: threadID, store: store)

                // Process tool tags in response ([READ:], [RUN:], [GREP:])
                let toolResult = processToolTags(streamingText)
                if let result = toolResult {
                    // Append tool results and get a follow-up response
                    let followUp = streamingText + "\n\n---\n" + result
                    store.updateLastMessage(text: followUp, in: threadID)
                    streamingText = followUp
                }

                if isFirstExchange {
                    let title = generateTitle(from: text)
                    store.rename(threadID, title: title)
                }

                // Auto-memory extraction: 3-second delay then scan for patterns
                let responseText = streamingText
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    let extracted = MemoryExtractor.extract(from: responseText)
                    if !extracted.isEmpty {
                        proposedMemories = extracted
                    }
                }

                // Generate follow-up suggestions based on response content
                let suggestionsText = streamingText
                Task { @MainActor in
                    followUpSuggestions = Self.generateFollowUps(from: suggestionsText, userMessage: text)
                    extractedTasks = Self.extractTasks(from: suggestionsText)
                    elicitationQuestion = Self.extractElicitation(from: suggestionsText)
                }
            } catch {
                if !Task.isCancelled {
                    let kind = errorKind(from: lastError)
                    // Streaming recovery: if we got partial text, try to continue
                    if streamingOutputTokens > 10 {
                        let partial = streamingText
                        store.updateLastMessage(text: partial + "\n\n*[Recovering...]*", in: threadID)
                        var continueHistory = history
                        continueHistory.append(["role": "assistant", "content": partial])
                        continueHistory.append(["role": "user", "content": "Continue from where you left off. Do not repeat what you already said."])
                        streamingText = partial + "\n\n"
                        do {
                            try await streamResponse(
                                history: continueHistory,
                                threadID: threadID,
                                store: store,
                                model: model,
                                modelManager: modelManager,
                                mode: chatMode
                            )
                            saveMetrics(messageID: assistantMsgID, threadID: threadID, store: store)
                        } catch {
                            setError(kind, text: streamingText + "\n[\(kind.label): \(error.localizedDescription)]", threadID: threadID, store: store)
                        }
                    } else {
                        setError(kind, text: "[\(kind.label): \(error.localizedDescription)]", threadID: threadID, store: store)
                    }
                }
            }
            store.saveThread(threadID)
            streamingState = .done
            // Sound cue on receive
            SoundCueManager.shared.playReceive()
        }
    }

    // MARK: - Auto-Compaction

    /// Check if context needs compaction (>80% of 180K) and auto-summarize
    func checkAutoCompaction(threadID: UUID, store: ThreadStore, modelManager: ModelManager) {
        guard let thread = store.threads.first(where: { $0.id == threadID }) else { return }
        let totalChars = thread.messages.reduce(0) { $0 + $1.text.count }
        let estimatedTokens = totalChars / 4 + 200
        let threshold = 144_000 // 80% of 180K

        guard estimatedTokens > threshold else { return }

        // Auto-compact: keep last 4 messages, summarize the rest
        let messagesToKeep = 4
        guard thread.messages.count > messagesToKeep + 2 else { return }

        let toSummarize = thread.messages.prefix(thread.messages.count - messagesToKeep)
        let summary = toSummarize.map { msg in
            let prefix = msg.role == .user ? "User" : "Queen"
            return "\(prefix): \(String(msg.text.prefix(150)))"
        }.joined(separator: "\n")

        let compactedMessage = ChatMessage(
            role: .assistant,
            text: "*[Context compacted: \(toSummarize.count) messages summarized]*\n\n\(String(summary.prefix(2000)))"
        )

        // Replace old messages with compact summary
        let idx = store.threads.firstIndex(where: { $0.id == threadID })!
        let kept = Array(store.threads[idx].messages.suffix(messagesToKeep))
        store.threads[idx].messages = [compactedMessage] + kept
        store.threads[idx].updatedAt = Date()
        store.saveThread(threadID)
    }

    // MARK: - Slash Command Execution

    /// Execute a slash command. Returns true if handled.
    func executeSlashCommand(
        _ input: String,
        store: ThreadStore,
        modelManager: ModelManager,
        effortBinding: inout EffortLevel,
        chatModeBinding: inout ChatMode,
        onResult: @escaping (String) -> Void
    ) -> Bool {
        guard let (cmd, arg) = SlashCommand.parse(input) else { return false }

        switch cmd {
        case .effort:
            if let argStr = arg?.lowercased() {
                if let level = EffortLevel.allCases.first(where: { $0.rawValue.lowercased() == argStr }) {
                    effortLevel = level
                    effortBinding = level
                    onResult("Effort set to \(level.rawValue)")
                } else {
                    onResult("Unknown effort level. Use: low, medium, high, max")
                }
            } else {
                onResult("Current effort: \(effortLevel.rawValue). Use: /effort low|medium|high|max")
            }
        case .model:
            if let argStr = arg {
                if let model = modelManager.availableModels.first(where: {
                    $0.displayName.lowercased().contains(argStr.lowercased()) ||
                    $0.id.lowercased().contains(argStr.lowercased())
                }) {
                    modelManager.selectedModel = model
                    modelManager.persistSelection()
                    onResult("Model switched to \(model.displayName)")
                } else {
                    let available = modelManager.availableModels.map(\.displayName).joined(separator: ", ")
                    onResult("Unknown model. Available: \(available)")
                }
            } else {
                onResult("Current: \(modelManager.selectedModel.displayName). Use: /model <name>")
            }
        case .compact:
            if let threadID = store.activeThreadID {
                let before = store.activeThread()?.messages.count ?? 0
                checkAutoCompaction(threadID: threadID, store: store, modelManager: modelManager)
                let after = store.activeThread()?.messages.count ?? 0
                if before != after {
                    onResult("Compacted \(before - after) messages")
                } else {
                    onResult("Context is within limits, no compaction needed")
                }
            }
        case .cost:
            let cost = NetworkLog.shared.todayCostEstimate()
            onResult(String(format: "Session cost: $%.3f", cost))
        case .clear:
            store.newThread()
            onResult("New thread created")
        case .export:
            if let threadID = store.activeThreadID,
               let md = store.exportAsMarkdown(threadID) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(md, forType: NSPasteboard.PasteboardType.string)
                onResult("Thread exported to clipboard")
            } else {
                onResult("No thread to export")
            }
        case .mode:
            if let argStr = arg?.lowercased() {
                if let mode = ChatMode.allCases.first(where: { $0.rawValue.lowercased() == argStr }) {
                    chatModeBinding = mode
                    onResult("Mode switched to \(mode.rawValue)")
                } else {
                    onResult("Unknown mode. Use: search, trinity, reason, compare, image")
                }
            } else {
                onResult("Current: \(chatModeBinding.rawValue). Use: /mode <name>")
            }
        case .fast:
            if let haiku = modelManager.availableModels.first(where: { $0.id.contains("haiku") }) {
                modelManager.selectedModel = haiku
                modelManager.persistSelection()
                effortLevel = .low
                effortBinding = .low
                onResult("Fast mode: \(haiku.displayName) + Low effort")
            } else {
                onResult("No fast model available")
            }
        case .branch:
            let result = RepoContext().currentBranch()
            onResult("Branch: \(result)")
        case .help:
            let cmds = SlashCommand.allCases.map { "\($0.rawValue) — \($0.description)" }.joined(separator: "\n")
            onResult("Available commands:\n\(cmds)")
        }
        return true
    }

    // MARK: - Follow-up Suggestions

    /// Generate contextual follow-up suggestions from response
    static func generateFollowUps(from response: String, userMessage: String) -> [String] {
        var suggestions: [String] = []
        let lower = response.lowercased()

        // Error-related suggestions
        if lower.contains("error") || lower.contains("failed") || lower.contains("broken") {
            suggestions.append("Fix this error")
            suggestions.append("Show the full error log")
        }

        // Code-related suggestions
        if lower.contains("```") {
            suggestions.append("Explain this code")
            if lower.contains("test") {
                suggestions.append("Run the tests")
            } else {
                suggestions.append("Write tests for this")
            }
        }

        // Build/deploy related
        if lower.contains("build") || lower.contains("compile") {
            suggestions.append("Build and check for warnings")
        }
        if lower.contains("deploy") || lower.contains("railway") {
            suggestions.append("Check deploy status")
        }

        // PPL/training related
        if lower.contains("ppl") || lower.contains("loss") || lower.contains("training") {
            suggestions.append("Show training dashboard")
            suggestions.append("Compare with best run")
        }

        // Issue/PR related
        if lower.contains("issue") || lower.contains("pr ") || lower.contains("pull request") {
            suggestions.append("Create an issue for this")
        }

        // Generic follow-ups if nothing specific matched
        if suggestions.isEmpty {
            suggestions.append("Tell me more")
            suggestions.append("What should I do next?")
        }

        return Array(suggestions.prefix(3))
    }

    // MARK: - Elicitation Extraction

    /// Extract structured questions from response (lines ending with "?", option lists)
    static func extractElicitation(from response: String) -> (question: String, options: [String])? {
        let lines = response.components(separatedBy: "\n").map { $0.trimmingCharacters(in: .whitespaces) }

        // Look for a question followed by options (a), b), c) or 1), 2), 3))
        for (i, line) in lines.enumerated() {
            guard line.hasSuffix("?") && line.count > 10 else { continue }

            var options: [String] = []
            for j in (i+1)..<min(i+8, lines.count) {
                let opt = lines[j]
                if let range = opt.range(of: #"^[a-d\d][\.\)]\s+"#, options: .regularExpression) {
                    let text = String(opt[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    if !text.isEmpty { options.append(text) }
                } else if opt.hasPrefix("- ") && opt.count > 3 {
                    options.append(String(opt.dropFirst(2)))
                } else if !opt.isEmpty && options.isEmpty {
                    continue // skip intermediate text
                } else if opt.isEmpty && !options.isEmpty {
                    break // end of option list
                }
            }

            if options.count >= 2 {
                return (question: line, options: Array(options.prefix(5)))
            }
        }
        return nil
    }

    // MARK: - Task Extraction

    /// Extract actionable tasks from response (numbered lists, checkboxes, "steps:")
    static func extractTasks(from response: String) -> [String] {
        var tasks: [String] = []
        let lines = response.components(separatedBy: "\n")

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            // Match: "1. Do something", "- [ ] Do something", "Step 1: Do something"
            if let range = trimmed.range(of: #"^(\d+[\.\)]\s+|- \[ \] |- \[x\] |Step \d+[:\s])"#, options: .regularExpression) {
                let task = String(trimmed[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                if task.count > 5 && task.count < 200 {
                    tasks.append(task)
                }
            }
        }

        // Only return if there are 2+ tasks (avoid false positives from single numbered items)
        return tasks.count >= 2 ? Array(tasks.prefix(10)) : []
    }

    // MARK: - Rejection Feedback

    /// Resend with user correction after dislike
    func resendWithFeedback(
        _ feedback: String,
        originalMessageID: UUID,
        threadID: UUID,
        store: ThreadStore,
        modelManager: ModelManager
    ) {
        guard !isStreaming else { return }
        guard let thread = store.threads.first(where: { $0.id == threadID }) else { return }

        // Find the original assistant message and the user message before it
        guard let msgIdx = thread.messages.firstIndex(where: { $0.id == originalMessageID }) else { return }
        let userMsg = thread.messages.prefix(msgIdx).last(where: { $0.role == .user })
        let userText = userMsg?.text ?? ""

        // Construct a correction prompt
        let correctionPrompt = """
        The user asked: "\(String(userText.prefix(500)))"
        Your previous response was not satisfactory. The user says: "\(feedback)"
        Please provide a better response.
        """

        // Remove old response and add correction
        let tIdx = store.threads.firstIndex(where: { $0.id == threadID })!
        if msgIdx < store.threads[tIdx].messages.count {
            store.threads[tIdx].messages.removeSubrange(msgIdx...)
        }
        store.threads[tIdx].updatedAt = Date()
        store.saveThread(threadID)

        // Send correction as new message
        send(correctionPrompt, threadID: threadID, store: store, modelManager: modelManager)
        showRejectionFeedback = nil
    }

    // MARK: - Tool Call Tracking

    /// Record a tool call step (for timeline display)
    func recordToolCall(name: String, args: String) {
        let step = ToolCallStep(name: name, args: args)
        activeToolCalls.append(step)
    }

    func completeToolCall(_ id: UUID, success: Bool) {
        if let idx = activeToolCalls.firstIndex(where: { $0.id == id }) {
            activeToolCalls[idx].status = success ? .success : .error
        }
    }

    func clearToolCalls() {
        activeToolCalls.removeAll()
    }

    // MARK: - Image Generation (xAI Grok Aurora)

    private func sendImageGeneration(_ prompt: String, threadID: UUID, store: ThreadStore, modelManager: ModelManager) {
        let userMsg = ChatMessage(role: .user, text: prompt)
        store.appendMessage(userMsg, to: threadID)

        let assistantMsg = ChatMessage(role: .assistant, text: "Generating image...", modelID: "grok-2-image")
        store.appendMessage(assistantMsg, to: threadID)

        streamingState = .connecting
        streamingText = "Generating image..."

        streamTask = Task {
            do {
                guard let key = modelManager.xaiKey else {
                    store.updateLastMessage(text: "[XAI_API_KEY not set in .env]", in: threadID)
                    streamingState = .done
                    return
                }

                let images = try await ImageGenerator.shared.generate(prompt: prompt, count: 1, key: key)

                if images.isEmpty {
                    store.updateLastMessage(text: "[No images generated]", in: threadID)
                } else {
                    let urls = images.map { $0.url }
                    let revisedPrompt = images.first?.revisedPrompt

                    var text = ""
                    if let revised = revisedPrompt {
                        text += "*\(revised)*\n\n"
                    }
                    for url in urls {
                        text += "![Generated Image](\(url))\n"
                    }

                    store.updateLastMessage(text: text, imageURLs: urls, in: threadID)
                }
            } catch {
                store.updateLastMessage(text: "[Image generation error: \(error.localizedDescription)]", in: threadID)
            }
            store.saveThread(threadID)
            streamingState = .done
        }
    }

    /// Last used model/provider for recording on cancel
    private var lastModelID: String = ""
    private var lastProviderName: String = ""

    /// ID of the thread being streamed to (set in send())
    private var activeStreamThreadID: UUID?
    /// Reference to store for saving on stop
    private weak var activeStreamStore: ThreadStore?

    func stop() {
        cancelStreamTimeout()
        streamTask?.cancel()
        streamTask = nil

        // Save partial text before clearing state
        if !streamingText.isEmpty, let threadID = activeStreamThreadID, let store = activeStreamStore {
            var finalText = streamingText
            if finalText.count > 5 {
                finalText += "\n\n*[Stopped by user]*"
            }
            store.updateLastMessage(text: finalText, in: threadID)

            // Save thinking text if any
            if !streamingThinkingText.isEmpty {
                store.updateLastMessageThinking(text: streamingThinkingText, in: threadID)
            }

            store.saveThread(threadID)
        }

        streamingState = .done
        isSlowResponse = false
        SoundCueManager.shared.playReceive()

        // Record cancellation with actual provider/model
        if let start = streamStartTime {
            NetworkLog.shared.record(
                provider: lastProviderName, model: lastModelID,
                inputTokens: 0,
                outputTokens: streamingOutputTokens,
                ttfbMs: streamingTTFB,
                totalMs: Int(Date().timeIntervalSince(start) * 1000),
                status: "cancelled"
            )
        }
    }

    /// Start background drain of offline queue
    private func startOfflineDrain(store: ThreadStore, modelManager: ModelManager) {
        guard offlineDrainTask == nil else { return }
        offlineDrainTask = Task {
            while !offlineQueue.isEmpty {
                try? await Task.sleep(for: .seconds(15))
                // Check if provider is back
                NetworkLog.shared.checkAllProviders()
                try? await Task.sleep(for: .seconds(3))

                var drained: [QueuedMessage] = []
                for queued in offlineQueue {
                    let providerName = modelManager.selectedModel.provider.rawValue
                    if let status = NetworkLog.shared.providerHealth[providerName], !status.isUp {
                        break // Still offline
                    }
                    drained.append(queued)
                }

                for queued in drained {
                    offlineQueue.removeFirst()
                    offlineQueueCount = offlineQueue.count
                    // Remove the queued placeholder
                    store.removeLastAssistantMessage(in: queued.threadID)
                    // Send normally
                    send(queued.text, threadID: queued.threadID, store: store, modelManager: modelManager, mode: queued.mode)
                    // Wait for completion
                    while isStreaming {
                        try? await Task.sleep(for: .milliseconds(500))
                    }
                }
                if !drained.isEmpty {
                    queueDrainedCount = drained.count
                }
            }
            offlineDrainTask = nil
        }
    }

    /// Edit a user message and resend from that point (fork conversation)
    func editAndResend(
        _ messageID: UUID,
        newText: String,
        threadID: UUID,
        store: ThreadStore,
        modelManager: ModelManager,
        mode: ChatMode = .trinity
    ) {
        guard !isStreaming else { return }

        // Fork: remove all messages after the edited one, update its text
        store.forkFromMessage(messageID, newText: newText, in: threadID)

        // Add new assistant message placeholder
        let assistantMsg = ChatMessage(role: .assistant, text: "", modelID: modelManager.selectedModel.id)
        store.appendMessage(assistantMsg, to: threadID)

        streamingState = .connecting
        streamingText = ""

        let history: [[String: String]] = store.activeThread()?.messages
            .filter { !$0.text.isEmpty }
            .map { ["role": $0.role.rawValue, "content": $0.text] } ?? []

        let model = modelManager.selectedModel
        let editAssistantMsgID = assistantMsg.id

        streamTask = Task {
            do {
                try await streamResponse(
                    history: history, threadID: threadID, store: store,
                    model: model, modelManager: modelManager, mode: mode
                )
                saveMetrics(messageID: editAssistantMsgID, threadID: threadID, store: store)
            } catch {
                if !Task.isCancelled {
                    if streamingOutputTokens > 10 {
                        let partial = streamingText
                        store.updateLastMessage(text: partial + "\n\n*[Recovering...]*", in: threadID)
                        var continueHistory = history
                        continueHistory.append(["role": "assistant", "content": partial])
                        continueHistory.append(["role": "user", "content": "Continue from where you left off. Do not repeat what you already said."])
                        streamingText = partial + "\n\n"
                        do {
                            try await streamResponse(
                                history: continueHistory, threadID: threadID, store: store,
                                model: model, modelManager: modelManager, mode: mode
                            )
                            saveMetrics(messageID: editAssistantMsgID, threadID: threadID, store: store)
                        } catch {
                            store.updateLastMessage(
                                text: streamingText + "\n[Error: \(error.localizedDescription)]",
                                in: threadID
                            )
                        }
                    } else {
                        store.updateLastMessage(
                            text: streamingText + "\n[Error: \(error.localizedDescription)]",
                            in: threadID
                        )
                    }
                }
            }
            store.saveThread(threadID)
            streamingState = .done
        }
    }

    private func updateTokensPerSec() {
        guard let first = firstTokenTime else { return }
        let elapsed = Date().timeIntervalSince(first)
        guard elapsed > 0.1 else { return }
        streamingTokensPerSec = Double(streamingOutputTokens) / elapsed

        // Periodic disk checkpoint every ~100 tokens (crash recovery)
        if streamingOutputTokens - lastCheckpointTokens >= 100,
           let threadID = activeStreamThreadID {
            lastCheckpointTokens = streamingOutputTokens
            activeStreamStore?.saveThread(threadID)
        }
    }

    func sendComment(
        _ text: String,
        about originalMessage: ChatMessage,
        threadID: UUID,
        store: ThreadStore,
        modelManager: ModelManager
    ) {
        let userComment = ChatMessage(role: .user, text: text)
        store.appendComment(userComment, to: originalMessage.id, in: threadID)

        let assistantComment = ChatMessage(role: .assistant, text: "", modelID: modelManager.selectedModel.id)
        store.appendComment(assistantComment, to: originalMessage.id, in: threadID)

        streamingState = .connecting
        streamingText = ""

        let contextHistory: [[String: String]] = [
            ["role": "user", "content": "Here is a message I want to discuss:\n\n\(originalMessage.text)"],
            ["role": "assistant", "content": "I see the message. What would you like to discuss about it?"],
            ["role": "user", "content": text]
        ]

        // Include prior comments if any
        var history = contextHistory
        if let comments = originalMessage.comments {
            for comment in comments.dropLast(2) {
                history.append(["role": comment.role.rawValue, "content": comment.text])
            }
            history.append(["role": "user", "content": text])
        }

        let model = modelManager.selectedModel
        let messageID = originalMessage.id

        streamTask = Task {
            do {
                guard modelManager.apiKey(for: model) != nil else {
                    store.updateLastComment(text: "[No API key]", for: messageID, in: threadID)
                    streamingState = .done
                    return
                }

                let body: [String: Any] = [
                    "model": model.id,
                    "max_tokens": 2048,
                    "stream": true,
                    "system": systemPrompt + "\nYou are commenting on a specific message. Keep responses focused and concise.",
                    "messages": history
                ]
                let bodyData = try JSONSerialization.data(withJSONObject: body)

                guard let request = modelManager.buildRequest(for: model, body: bodyData) else {
                    store.updateLastComment(text: "[Failed to build request]", for: messageID, in: threadID)
                    streamingState = .done
                    return
                }

                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    var errorBody = ""
                    for try await line in bytes.lines { errorBody += line }
                    store.updateLastComment(text: "[API Error \(httpResponse.statusCode)]", for: messageID, in: threadID)
                    streamingState = .done
                    return
                }

                for try await line in bytes.lines {
                    try Task.checkCancellation()
                    guard line.hasPrefix("data: ") else { continue }
                    let data = String(line.dropFirst(6))
                    if data == "[DONE]" { break }

                    guard let jsonData = data.data(using: .utf8),
                          let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

                    // Support both Anthropic and OpenAI SSE formats
                    if let type = event["type"] as? String,
                       type == "content_block_delta",
                       let delta = event["delta"] as? [String: Any],
                       let text = delta["text"] as? String {
                        streamingText += text
                        store.updateLastComment(text: streamingText, for: messageID, in: threadID)
                    } else if let choices = event["choices"] as? [[String: Any]],
                              let delta = choices.first?["delta"] as? [String: Any],
                              let content = delta["content"] as? String {
                        streamingText += content
                        store.updateLastComment(text: streamingText, for: messageID, in: threadID)
                    }
                }
            } catch {
                if !Task.isCancelled {
                    store.updateLastComment(
                        text: streamingText + "\n[Error: \(error.localizedDescription)]",
                        for: messageID,
                        in: threadID
                    )
                }
            }
            store.saveThread(threadID)
            streamingState = .done
        }
    }

    /// Remove a queued offline message
    func cancelQueued(_ id: UUID) {
        offlineQueue.removeAll { $0.id == id }
        offlineQueueCount = offlineQueue.count
        persistQueue()
    }

    /// Retry a specific assistant message (not just the last one)
    func regenerateFrom(messageID: UUID, threadID: UUID, store: ThreadStore, modelManager: ModelManager) {
        guard !isStreaming else { return }
        guard let thread = store.threads.first(where: { $0.id == threadID }) else { return }
        guard let msgIdx = thread.messages.firstIndex(where: { $0.id == messageID }) else { return }
        let msg = thread.messages[msgIdx]
        guard msg.role == .assistant else { return }

        // Find the user message before this assistant message
        let userMsg = thread.messages.prefix(msgIdx).last(where: { $0.role == .user })
        guard let userText = userMsg?.text, !userText.isEmpty else { return }

        // Remove this assistant message and everything after it
        let tIdx = store.threads.firstIndex(where: { $0.id == threadID })!
        if msgIdx < store.threads[tIdx].messages.count {
            store.threads[tIdx].messages.removeSubrange(msgIdx...)
        }
        store.threads[tIdx].updatedAt = Date()
        store.saveThread(threadID)

        // Add new assistant placeholder and stream
        let assistantMsg = ChatMessage(role: .assistant, text: "", modelID: modelManager.selectedModel.id)
        store.appendMessage(assistantMsg, to: threadID)

        streamingState = .connecting
        streamingText = ""
        streamingThinkingText = ""

        let history: [[String: String]] = store.activeThread()?.messages
            .filter { !$0.text.isEmpty }
            .map { ["role": $0.role.rawValue, "content": $0.text] } ?? []

        let model = modelManager.selectedModel
        let newMsgID = assistantMsg.id

        streamTask = Task {
            do {
                try await streamResponse(
                    history: history, threadID: threadID, store: store,
                    model: model, modelManager: modelManager
                )
                saveMetrics(messageID: newMsgID, threadID: threadID, store: store)
            } catch {
                if !Task.isCancelled {
                    store.updateLastMessage(
                        text: streamingText + "\n[Error: \(error.localizedDescription)]",
                        in: threadID
                    )
                }
            }
            store.saveThread(threadID)
            streamingState = .done
        }
    }

    func regenerate(threadID: UUID, store: ThreadStore, modelManager: ModelManager) {
        guard !isStreaming else { return }
        guard let thread = store.activeThread(),
              thread.messages.count >= 2 else { return }

        // Find the last user message text
        let lastUserText = thread.messages.last(where: { $0.role == .user })?.text ?? ""
        guard !lastUserText.isEmpty else { return }

        // Remove the last assistant message
        store.removeLastAssistantMessage(in: threadID)

        // Resend
        let assistantMsg = ChatMessage(role: .assistant, text: "", modelID: modelManager.selectedModel.id)
        store.appendMessage(assistantMsg, to: threadID)

        streamingState = .connecting
        streamingText = ""

        let history: [[String: String]] = store.activeThread()?.messages
            .filter { !$0.text.isEmpty }
            .map { ["role": $0.role.rawValue, "content": $0.text] } ?? []

        let model = modelManager.selectedModel
        let regenAssistantMsgID = assistantMsg.id

        streamTask = Task {
            do {
                try await streamResponse(
                    history: history,
                    threadID: threadID,
                    store: store,
                    model: model,
                    modelManager: modelManager
                )
                saveMetrics(messageID: regenAssistantMsgID, threadID: threadID, store: store)
            } catch {
                if !Task.isCancelled {
                    if streamingOutputTokens > 10 {
                        let partial = streamingText
                        store.updateLastMessage(text: partial + "\n\n*[Recovering...]*", in: threadID)
                        var continueHistory = history
                        continueHistory.append(["role": "assistant", "content": partial])
                        continueHistory.append(["role": "user", "content": "Continue from where you left off. Do not repeat what you already said."])
                        streamingText = partial + "\n\n"
                        do {
                            try await streamResponse(
                                history: continueHistory, threadID: threadID, store: store,
                                model: model, modelManager: modelManager
                            )
                            saveMetrics(messageID: regenAssistantMsgID, threadID: threadID, store: store)
                        } catch {
                            store.updateLastMessage(
                                text: streamingText + "\n[Error: \(error.localizedDescription)]",
                                in: threadID
                            )
                        }
                    } else {
                        store.updateLastMessage(
                            text: streamingText + "\n[Error: \(error.localizedDescription)]",
                            in: threadID
                        )
                    }
                }
            }
            store.saveThread(threadID)
            streamingState = .done
        }
    }

    private func saveMetrics(messageID: UUID, threadID: UUID, store: ThreadStore) {
        guard streamingOutputTokens > 0 else { return }
        let total: Int
        if let start = streamStartTime {
            total = Int(Date().timeIntervalSince(start) * 1000)
        } else {
            total = 0
        }
        store.updateMessageMetrics(
            messageID,
            ttfbMs: streamingTTFB,
            tokPerSec: streamingTokensPerSec,
            outputTokens: streamingOutputTokens,
            totalMs: total,
            in: threadID
        )
    }

    private func generateTitle(from text: String) -> String {
        let cleaned = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let words = cleaned.split(separator: " ").prefix(6).joined(separator: " ")
        return words.isEmpty ? "New Thread" : String(words)
    }

    private func streamResponse(
        history: [[String: String]],
        threadID: UUID,
        store: ThreadStore,
        model: AIModel,
        modelManager: ModelManager,
        mode: ChatMode = .trinity
    ) async throws {
        guard let key = modelManager.apiKey(for: model) else {
            store.updateLastMessage(text: "[No API key for \(model.provider.rawValue)]", in: threadID)
            return
        }

        // Track for cancel recording
        lastModelID = model.id
        lastProviderName = model.provider.rawValue

        switch model.provider {
        case .perplexity, .xai:
            try await streamOpenAI(
                history: history, threadID: threadID, store: store,
                model: model, key: key, modelManager: modelManager, mode: mode
            )
        case .anthropic, .zai:
            try await streamAnthropic(
                history: history, threadID: threadID, store: store,
                model: model, key: key, modelManager: modelManager, mode: mode
            )
        case .ollama:
            try await streamOllama(
                history: history, threadID: threadID, store: store,
                model: model, modelManager: modelManager, mode: mode
            )
        }
    }

    // MARK: - Anthropic / z.ai streaming (same SSE format)

    private func streamAnthropic(
        history: [[String: String]],
        threadID: UUID,
        store: ThreadStore,
        model: AIModel,
        key: String,
        modelManager: ModelManager,
        mode: ChatMode = .trinity,
        retryCount: Int = 0,
        triedModels: Set<String> = []
    ) async throws {
        let effectiveMaxTokens = mode == .reason ? 16384 : effortLevel.maxTokens
        var body: [String: Any] = [
            "model": model.id,
            "max_tokens": effectiveMaxTokens,
            "stream": true,
            "system": systemPrompt + mode.systemSuffix,
            "messages": history
        ]
        // Enable extended thinking for reason mode or high/max effort (Anthropic API)
        if model.provider == .anthropic {
            let thinkingBudget: Int?
            if mode == .reason {
                thinkingBudget = 8192
            } else {
                thinkingBudget = effortLevel.thinkingBudget
            }
            if let budget = thinkingBudget {
                body["thinking"] = ["type": "enabled", "budget_tokens": budget]
            }
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        guard let request = modelManager.buildRequest(for: model, body: bodyData) else {
            store.updateLastMessage(text: "[Failed to build request]", in: threadID)
            return
        }

        streamStartTime = Date()
        firstTokenTime = nil
        streamingOutputTokens = 0
        streamingTTFB = 0  // Reset TTFB on every attempt
        isSlowResponse = false
        lastError = nil
        let inputTokens = history.reduce(0) { $0 + ($1["content"]?.count ?? 0) / 4 }

        // Start slow-response timer
        let slowTimer = Task {
            try await Task.sleep(for: .seconds(5))
            if firstTokenTime == nil {
                await MainActor.run { isSlowResponse = true }
            }
        }

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            slowTimer.cancel()
            // Connection error (timeout, no network, etc.)
            let errType: APIErrorType = error.localizedDescription.contains("timed out")
                ? .timeout : .connectionFailed
            lastError = errType

            // Try failover chain
            var tried = triedModels.union([model.id])
            let chain = modelManager.failoverChain(excluding: tried)
            if let next = chain.first, let nextKey = modelManager.apiKey(for: next) {
                tried.insert(next.id)
                store.updateLastMessage(text: "", in: threadID)
                failoverEvent = FailoverEvent(from: model.displayName, to: next.displayName, timestamp: Date())
                failoverLog.append(failoverEvent!)
                try await streamAnthropic(
                    history: history, threadID: threadID, store: store,
                    model: next, key: nextKey, modelManager: modelManager,
                    mode: mode, retryCount: 0, triedModels: tried
                )
                return
            }
            store.updateLastMessage(text: "[\(errType.userMessage)]", in: threadID)
            NetworkLog.shared.record(
                provider: model.provider.rawValue, model: model.id,
                inputTokens: inputTokens, outputTokens: 0, ttfbMs: 0,
                totalMs: Int(Date().timeIntervalSince(streamStartTime!) * 1000),
                status: "error", errorMessage: errType.userMessage
            )
            return
        }

        slowTimer.cancel()
        isSlowResponse = false

        if let httpResponse = response as? HTTPURLResponse {
            modelManager.parseRateLimitHeaders(httpResponse, provider: model.provider)

            if httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines { errorBody += line }

                let errType = APIErrorType.from(statusCode: httpResponse.statusCode, body: errorBody, headers: httpResponse)
                lastError = errType

                // Retry on 429 or 5xx — try same model first, then failover chain
                if (httpResponse.statusCode == 429 || httpResponse.statusCode >= 500) && retryCount < 2 {
                    let delay = [3.0, 8.0][min(retryCount, 1)]
                    streamingText = ""
                    streamingOutputTokens = 0
                    firstTokenTime = nil
                    streamingTTFB = 0
                    // Don't leave "Reconnecting..." in final message — clear it
                    store.updateLastMessage(text: "", in: threadID)
                    try await Task.sleep(for: .seconds(delay))

                    // Try failover chain on 2nd+ retry
                    var retryModel = model
                    var retryKey = key
                    var tried = triedModels.union([model.id])
                    if retryCount >= 1 {
                        let chain = modelManager.failoverChain(excluding: tried)
                        if let fallback = chain.first, let fbKey = modelManager.apiKey(for: fallback) {
                            retryModel = fallback
                            retryKey = fbKey
                            tried.insert(fallback.id)
                            failoverEvent = FailoverEvent(from: model.displayName, to: fallback.displayName, timestamp: Date())
                            failoverLog.append(failoverEvent!)
                        }
                    }

                    try await streamAnthropic(
                        history: history, threadID: threadID, store: store,
                        model: retryModel, key: retryKey, modelManager: modelManager,
                        mode: mode, retryCount: retryCount + 1, triedModels: tried
                    )
                    return
                }

                NetworkLog.shared.record(
                    provider: model.provider.rawValue, model: model.id,
                    inputTokens: inputTokens, outputTokens: 0, ttfbMs: 0,
                    totalMs: Int(Date().timeIntervalSince(streamStartTime!) * 1000),
                    status: "error", errorMessage: "HTTP \(httpResponse.statusCode)"
                )
                store.updateLastMessage(text: "[\(errType.userMessage)]", in: threadID)
                return
            }
        }

        var currentBlockType: String = "text"  // Track content block type

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))
            if data == "[DONE]" { break }

            guard let jsonData = data.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let type = event["type"] as? String else { continue }

            // Track block type from content_block_start
            if type == "content_block_start",
               let contentBlock = event["content_block"] as? [String: Any],
               let blockType = contentBlock["type"] as? String {
                currentBlockType = blockType
            }

            if type == "content_block_delta",
               let delta = event["delta"] as? [String: Any] {
                // Handle thinking deltas
                if let thinking = delta["thinking"] as? String, currentBlockType == "thinking" {
                    if firstTokenTime == nil {
                        firstTokenTime = Date()
                        if let start = streamStartTime {
                            streamingTTFB = Int(firstTokenTime!.timeIntervalSince(start) * 1000)
                        }
                        isSlowResponse = false
                    }
                    streamingThinkingText += thinking
                    store.updateLastMessageThinking(text: streamingThinkingText, in: threadID)
                }
                // Handle text deltas
                else if let text = delta["text"] as? String {
                    if firstTokenTime == nil {
                        firstTokenTime = Date()
                        if let start = streamStartTime {
                            streamingTTFB = Int(firstTokenTime!.timeIntervalSince(start) * 1000)
                        }
                        isSlowResponse = false
                    }
                    streamingText += text
                    streamingOutputTokens += max(text.count / 4, 1)
                    updateTokensPerSec()
                    store.updateLastMessage(text: streamingText, in: threadID)
                }
            }
        }

        // Record to network log
        if let start = streamStartTime {
            let totalMs = Int(Date().timeIntervalSince(start) * 1000)
            NetworkLog.shared.record(
                provider: model.provider.rawValue, model: model.id,
                inputTokens: inputTokens, outputTokens: streamingOutputTokens,
                ttfbMs: streamingTTFB, totalMs: totalMs, status: "ok"
            )
        }
    }

    // MARK: - OpenAI-compatible streaming (Perplexity, xAI Grok)

    private func streamOpenAI(
        history: [[String: String]],
        threadID: UUID,
        store: ThreadStore,
        model: AIModel,
        key: String,
        modelManager: ModelManager,
        mode: ChatMode = .trinity,
        retryCount: Int = 0,
        triedModels: Set<String> = []
    ) async throws {
        var messages: [[String: String]] = [["role": "system", "content": systemPrompt + mode.systemSuffix]]
        messages.append(contentsOf: history)

        var body: [String: Any] = [
            "model": model.id,
            "stream": true,
            "messages": messages
        ]

        if mode == .search && model.provider == .perplexity {
            body["search_recency_filter"] = "week"
        }
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        guard let request = modelManager.buildRequest(for: model, body: bodyData) else {
            store.updateLastMessage(text: "[Failed to build request]", in: threadID)
            return
        }

        streamStartTime = Date()
        firstTokenTime = nil
        streamingOutputTokens = 0
        streamingTTFB = 0
        isSlowResponse = false
        lastError = nil
        let inputTokens = history.reduce(0) { $0 + ($1["content"]?.count ?? 0) / 4 }

        let slowTimer = Task {
            try await Task.sleep(for: .seconds(5))
            if firstTokenTime == nil {
                await MainActor.run { isSlowResponse = true }
            }
        }

        let bytes: URLSession.AsyncBytes
        let response: URLResponse
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            slowTimer.cancel()
            let errType: APIErrorType = error.localizedDescription.contains("timed out")
                ? .timeout : .connectionFailed
            lastError = errType

            var tried = triedModels.union([model.id])
            let chain = modelManager.failoverChain(excluding: tried)
            if let next = chain.first, let nextKey = modelManager.apiKey(for: next) {
                tried.insert(next.id)
                store.updateLastMessage(text: "", in: threadID)
                failoverEvent = FailoverEvent(from: model.displayName, to: next.displayName, timestamp: Date())
                failoverLog.append(failoverEvent!)
                try await streamOpenAI(
                    history: history, threadID: threadID, store: store,
                    model: next, key: nextKey, modelManager: modelManager,
                    mode: mode, retryCount: 0, triedModels: tried
                )
                return
            }
            store.updateLastMessage(text: "[\(errType.userMessage)]", in: threadID)
            NetworkLog.shared.record(
                provider: model.provider.rawValue, model: model.id,
                inputTokens: inputTokens, outputTokens: 0, ttfbMs: 0,
                totalMs: Int(Date().timeIntervalSince(streamStartTime!) * 1000),
                status: "error", errorMessage: errType.userMessage
            )
            return
        }

        slowTimer.cancel()
        isSlowResponse = false

        if let httpResponse = response as? HTTPURLResponse {
            modelManager.parseRateLimitHeaders(httpResponse, provider: model.provider)

            if httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines { errorBody += line }

                let errType = APIErrorType.from(statusCode: httpResponse.statusCode, body: errorBody, headers: httpResponse)
                lastError = errType

                if (httpResponse.statusCode == 429 || httpResponse.statusCode >= 500) && retryCount < 2 {
                    let delay = [3.0, 8.0][min(retryCount, 1)]
                    streamingText = ""
                    streamingOutputTokens = 0
                    firstTokenTime = nil
                    streamingTTFB = 0
                    store.updateLastMessage(text: "", in: threadID)
                    try await Task.sleep(for: .seconds(delay))

                    var retryModel = model
                    var retryKey = key
                    var tried = triedModels.union([model.id])
                    if retryCount >= 1 {
                        let chain = modelManager.failoverChain(excluding: tried)
                        if let fallback = chain.first, let fbKey = modelManager.apiKey(for: fallback) {
                            retryModel = fallback
                            retryKey = fbKey
                            tried.insert(fallback.id)
                            failoverEvent = FailoverEvent(from: model.displayName, to: fallback.displayName, timestamp: Date())
                            failoverLog.append(failoverEvent!)
                        }
                    }

                    try await streamOpenAI(
                        history: history, threadID: threadID, store: store,
                        model: retryModel, key: retryKey, modelManager: modelManager,
                        mode: mode, retryCount: retryCount + 1, triedModels: tried
                    )
                    return
                }

                NetworkLog.shared.record(
                    provider: model.provider.rawValue, model: model.id,
                    inputTokens: inputTokens, outputTokens: 0, ttfbMs: 0,
                    totalMs: Int(Date().timeIntervalSince(streamStartTime!) * 1000),
                    status: "error", errorMessage: "HTTP \(httpResponse.statusCode)"
                )
                store.updateLastMessage(text: "[\(errType.userMessage)]", in: threadID)
                return
            }
        }

        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data: ") else { continue }
            let data = String(line.dropFirst(6))
            if data == "[DONE]" { break }

            guard let jsonData = data.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any],
                  let choices = event["choices"] as? [[String: Any]],
                  let delta = choices.first?["delta"] as? [String: Any],
                  let content = delta["content"] as? String else { continue }

            if firstTokenTime == nil {
                firstTokenTime = Date()
                if let start = streamStartTime {
                    streamingTTFB = Int(firstTokenTime!.timeIntervalSince(start) * 1000)
                }
                isSlowResponse = false
            }
            streamingText += content
            streamingOutputTokens += max(content.count / 4, 1)
            updateTokensPerSec()
            store.updateLastMessage(text: streamingText, in: threadID)
        }

        // Extract citations for search mode (Perplexity responses)
        if mode == .search && !streamingText.isEmpty {
            let citations = ChatClient.extractCitations(from: streamingText)
            if !citations.isEmpty {
                store.updateLastMessageCitations(citations, in: threadID)
            }
        }

        if let start = streamStartTime {
            let totalMs = Int(Date().timeIntervalSince(start) * 1000)
            NetworkLog.shared.record(
                provider: model.provider.rawValue, model: model.id,
                inputTokens: inputTokens, outputTokens: streamingOutputTokens,
                ttfbMs: streamingTTFB, totalMs: totalMs, status: "ok"
            )
        }
    }

    // MARK: - Ollama streaming (NDJSON format)

    private func streamOllama(
        history: [[String: String]],
        threadID: UUID,
        store: ThreadStore,
        model: AIModel,
        modelManager: ModelManager,
        mode: ChatMode = .trinity
    ) async throws {
        let modelName = modelManager.ollamaModelName(model)
        var messages: [[String: String]] = [["role": "system", "content": systemPrompt + mode.systemSuffix]]
        messages.append(contentsOf: history)

        let body: [String: Any] = [
            "model": modelName,
            "messages": messages,
            "stream": true
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        guard let request = modelManager.buildRequest(for: model, body: bodyData) else {
            store.updateLastMessage(text: "[Failed to build Ollama request]", in: threadID)
            return
        }

        streamStartTime = Date()
        firstTokenTime = nil
        streamingOutputTokens = 0
        streamingTTFB = 0
        isSlowResponse = false
        lastError = nil
        let inputTokens = history.reduce(0) { $0 + ($1["content"]?.count ?? 0) / 4 }

        let (bytes, response): (URLSession.AsyncBytes, URLResponse)
        do {
            (bytes, response) = try await URLSession.shared.bytes(for: request)
        } catch {
            lastError = .connectionFailed
            store.updateLastMessage(text: "[Ollama not reachable. Is it running?]", in: threadID)
            return
        }

        if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
            var errorBody = ""
            for try await line in bytes.lines { errorBody += line }
            store.updateLastMessage(text: "[Ollama error: HTTP \(httpResponse.statusCode) \(String(errorBody.prefix(200)))]", in: threadID)
            return
        }

        // Ollama streams NDJSON: each line is a JSON object with {"message":{"content":"..."}, "done":false}
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard !line.isEmpty,
                  let jsonData = line.data(using: .utf8),
                  let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

            if let done = event["done"] as? Bool, done { break }

            guard let message = event["message"] as? [String: Any],
                  let content = message["content"] as? String else { continue }

            if firstTokenTime == nil {
                firstTokenTime = Date()
                if let start = streamStartTime {
                    streamingTTFB = Int(firstTokenTime!.timeIntervalSince(start) * 1000)
                }
            }
            streamingText += content
            streamingOutputTokens += max(content.count / 4, 1)
            updateTokensPerSec()
            store.updateLastMessage(text: streamingText, in: threadID)
        }

        if let start = streamStartTime {
            let totalMs = Int(Date().timeIntervalSince(start) * 1000)
            NetworkLog.shared.record(
                provider: model.provider.rawValue, model: model.id,
                inputTokens: inputTokens, outputTokens: streamingOutputTokens,
                ttfbMs: streamingTTFB, totalMs: totalMs, status: "ok"
            )
        }
    }

    // MARK: - Regenerate with specific model override

    func regenerateFromWithModel(messageID: UUID, threadID: UUID, store: ThreadStore, modelManager: ModelManager, withModel: AIModel) {
        guard !isStreaming else { return }
        guard let thread = store.threads.first(where: { $0.id == threadID }) else { return }
        guard let msgIdx = thread.messages.firstIndex(where: { $0.id == messageID }) else { return }
        let msg = thread.messages[msgIdx]
        guard msg.role == .assistant else { return }

        // Find the user message before this assistant message
        let userMsg = thread.messages.prefix(msgIdx).last(where: { $0.role == .user })
        guard let userText = userMsg?.text, !userText.isEmpty else { return }

        // Save old response as branch
        let tIdx = store.threads.firstIndex(where: { $0.id == threadID })!
        let branchID = store.threads[tIdx].messages[msgIdx].branchID ?? UUID()
        let oldIndex = store.threads[tIdx].messages[msgIdx].branchIndex ?? 0
        let branchKey = "branch_\(branchID)_\(oldIndex)"
        let oldMessages = Array(store.threads[tIdx].messages[msgIdx...])
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        if let data = try? encoder.encode(oldMessages) {
            UserDefaults.standard.set(data, forKey: branchKey)
        }

        // Remove this message and after
        if msgIdx < store.threads[tIdx].messages.count {
            store.threads[tIdx].messages.removeSubrange(msgIdx...)
        }
        store.threads[tIdx].updatedAt = Date()
        store.saveThread(threadID)

        // Add new assistant placeholder with the chosen model
        var assistantMsg = ChatMessage(role: .assistant, text: "", modelID: withModel.id)
        assistantMsg.branchID = branchID
        assistantMsg.branchIndex = oldIndex + 1
        store.appendMessage(assistantMsg, to: threadID)

        streamingState = .connecting
        streamingText = ""
        streamingThinkingText = ""

        let history: [[String: String]] = store.activeThread()?.messages
            .filter { !$0.text.isEmpty }
            .map { ["role": $0.role.rawValue, "content": $0.text] } ?? []

        let newMsgID = assistantMsg.id

        streamTask = Task {
            do {
                try await streamResponse(
                    history: history, threadID: threadID, store: store,
                    model: withModel, modelManager: modelManager
                )
                saveMetrics(messageID: newMsgID, threadID: threadID, store: store)
            } catch {
                if !Task.isCancelled {
                    store.updateLastMessage(
                        text: streamingText + "\n[Error: \(error.localizedDescription)]",
                        in: threadID
                    )
                }
            }
            store.saveThread(threadID)
            streamingState = .done
        }
    }
}

// MARK: - Memory Extractor

enum MemoryExtractor {
    /// Scan response text for actionable patterns
    static func extract(from text: String) -> [MemoryEntry] {
        var entries: [MemoryEntry] = []
        let patterns: [String] = [
            #"(?:set|changed|configured)\s+(\w[\w\s]*?)\s+to\s+([\w\d\.\-]+)"#,
            #"the fix was\s+(.+?)(?:\.|$)"#,
            #"use\s+(\w[\w\s]*?)\s+instead of\s+(\w[\w\s]*?)(?:\.|$)"#,
            #"PPL[=: ]+(\d+\.?\d*)"#,
        ]

        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.count > 10 && trimmed.count < 200 else { continue }

            for pattern in patterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
                let range = NSRange(trimmed.startIndex..., in: trimmed)
                if regex.firstMatch(in: trimmed, range: range) != nil {
                    let entry = MemoryEntry(text: trimmed, source: String(trimmed.prefix(80)))
                    if !entries.contains(where: { $0.text == entry.text }) {
                        entries.append(entry)
                    }
                    break
                }
            }
        }

        return Array(entries.prefix(3))
    }
}
