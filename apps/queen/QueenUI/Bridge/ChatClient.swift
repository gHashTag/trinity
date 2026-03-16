import Foundation

/// Chat mode: determines how the message is routed
enum ChatMode: String, CaseIterable {
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

@MainActor
class ChatClient: ObservableObject {
    @Published var isStreaming = false
    @Published var streamingText = ""
    @Published var streamingTokensPerSec: Double = 0
    @Published var streamingTTFB: Int = 0          // ms to first token
    @Published var streamingOutputTokens: Int = 0

    private var streamTask: Task<Void, Never>?
    private let repo = RepoContext()
    private var streamStartTime: Date?
    private var firstTokenTime: Date?

    private var systemPrompt: String {
        buildSystemPrompt()
    }

    private func buildSystemPrompt() -> String {
        var prompt = """
            You are Queen — the personal CTO agent of the Trinity project. \
            Trinity is a pure Zig autonomous AI agent swarm with ternary {-1,0,+1} computing. \
            Answer concisely in the user's language. You are wise, direct, and technically precise.
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

        prompt += "\n\nYou can read files from the repository. "
        prompt += "To read a file, output [READ:file://path/to/file] and the content will be injected."
        return prompt
    }

    /// Build repo summary as a content block (not system prompt) for first message
    func buildRepoSummary() -> String {
        var summary = "## Repository Structure\n"
        summary += repo.fileTree(depth: 2)
        summary += "\n\n## Recent Commits\n"
        summary += repo.recentCommits(count: 5).joined(separator: "\n")
        return summary
    }

    /// Process [READ:file://...] tags in AI response, return file contents to inject
    func processReadTags(_ text: String) -> String? {
        let pattern = #"\[READ:file://([^\]]+)\]"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)
        guard !matches.isEmpty else { return nil }

        var contents: [String] = []
        for match in matches {
            guard let r = Range(match.range(at: 1), in: text) else { continue }
            let path = String(text[r])
            if let content = repo.readFile(path) {
                contents.append("### \(path)\n```\n\(String(content.prefix(8000)))\n```")
            } else {
                contents.append("### \(path)\n[File not found or too large]")
            }
        }
        return contents.joined(separator: "\n\n")
    }

    /// Auto-detect file paths in user message and attach contents
    func attachFileContext(_ text: String) -> String? {
        let paths = repo.detectPaths(in: text)
        guard !paths.isEmpty else { return nil }
        var context: [String] = []
        for path in paths.prefix(3) { // Max 3 files per message
            if let content = repo.readFile(path) {
                context.append("### \(path)\n```\n\(String(content.prefix(4000)))\n```")
                TrinityContext.shared.recordAttachedFile(path, size: content.count)
            }
        }
        return context.isEmpty ? nil : context.joined(separator: "\n\n")
    }

    func send(_ text: String, threadID: UUID, store: ThreadStore, modelManager: ModelManager, mode: ChatMode = .trinity) {
        // Image mode — route to xAI image generation
        if mode == .image {
            sendImageGeneration(text, threadID: threadID, store: store, modelManager: modelManager)
            return
        }

        // Auto-detect file paths in user message and attach file contents
        var enrichedText = text
        if let fileContext = attachFileContext(text) {
            enrichedText += "\n\n---\n[Attached file contents]\n" + fileContext
        }

        let userMsg = ChatMessage(role: .user, text: text)
        store.appendMessage(userMsg, to: threadID)

        // Resolve model based on mode
        let model: AIModel
        switch mode {
        case .search:
            model = AIModel.allModels.first(where: { $0.id == "sonar-pro" }) ?? modelManager.selectedModel
        case .reason:
            model = AIModel.allModels.first(where: { $0.id == "sonar-reasoning-pro" }) ?? modelManager.selectedModel
        case .trinity, .image, .compare:
            model = modelManager.selectedModel
        }

        let assistantMsg = ChatMessage(role: .assistant, text: "", modelID: model.id)
        store.appendMessage(assistantMsg, to: threadID)

        isStreaming = true
        streamingText = ""

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

                if isFirstExchange {
                    let title = generateTitle(from: text)
                    store.rename(threadID, title: title)
                }
            } catch {
                if !Task.isCancelled {
                    store.updateLastMessage(
                        text: streamingText + "\n[Error: \(error.localizedDescription)]",
                        in: threadID
                    )
                }
            }
            store.saveThread(threadID)
            isStreaming = false
        }
    }

    // MARK: - Image Generation (xAI Grok Aurora)

    private func sendImageGeneration(_ prompt: String, threadID: UUID, store: ThreadStore, modelManager: ModelManager) {
        let userMsg = ChatMessage(role: .user, text: prompt)
        store.appendMessage(userMsg, to: threadID)

        let assistantMsg = ChatMessage(role: .assistant, text: "Generating image...", modelID: "grok-2-image")
        store.appendMessage(assistantMsg, to: threadID)

        isStreaming = true
        streamingText = "Generating image..."

        streamTask = Task {
            do {
                guard let key = modelManager.xaiKey else {
                    store.updateLastMessage(text: "[XAI_API_KEY not set in .env]", in: threadID)
                    isStreaming = false
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
            isStreaming = false
        }
    }

    func stop() {
        streamTask?.cancel()
        streamTask = nil
        isStreaming = false

        // Record cancellation
        if let start = streamStartTime {
            NetworkLog.shared.record(
                provider: "", model: "", inputTokens: 0,
                outputTokens: streamingOutputTokens,
                ttfbMs: streamingTTFB,
                totalMs: Int(Date().timeIntervalSince(start) * 1000),
                status: "cancelled"
            )
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

        isStreaming = true
        streamingText = ""

        let history: [[String: String]] = store.activeThread()?.messages
            .filter { !$0.text.isEmpty }
            .map { ["role": $0.role.rawValue, "content": $0.text] } ?? []

        let model = modelManager.selectedModel

        streamTask = Task {
            do {
                try await streamResponse(
                    history: history, threadID: threadID, store: store,
                    model: model, modelManager: modelManager, mode: mode
                )
            } catch {
                if !Task.isCancelled {
                    store.updateLastMessage(
                        text: streamingText + "\n[Error: \(error.localizedDescription)]",
                        in: threadID
                    )
                }
            }
            store.saveThread(threadID)
            isStreaming = false
        }
    }

    private func updateTokensPerSec() {
        guard let first = firstTokenTime else { return }
        let elapsed = Date().timeIntervalSince(first)
        guard elapsed > 0.1 else { return }
        streamingTokensPerSec = Double(streamingOutputTokens) / elapsed
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

        isStreaming = true
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
                    isStreaming = false
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
                    isStreaming = false
                    return
                }

                let (bytes, response) = try await URLSession.shared.bytes(for: request)

                if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                    var errorBody = ""
                    for try await line in bytes.lines { errorBody += line }
                    store.updateLastComment(text: "[API Error \(httpResponse.statusCode)]", for: messageID, in: threadID)
                    isStreaming = false
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
            isStreaming = false
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

        isStreaming = true
        streamingText = ""

        let history: [[String: String]] = store.activeThread()?.messages
            .filter { !$0.text.isEmpty }
            .map { ["role": $0.role.rawValue, "content": $0.text] } ?? []

        let model = modelManager.selectedModel

        streamTask = Task {
            do {
                try await streamResponse(
                    history: history,
                    threadID: threadID,
                    store: store,
                    model: model,
                    modelManager: modelManager
                )
            } catch {
                if !Task.isCancelled {
                    store.updateLastMessage(
                        text: streamingText + "\n[Error: \(error.localizedDescription)]",
                        in: threadID
                    )
                }
            }
            store.saveThread(threadID)
            isStreaming = false
        }
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
        retryCount: Int = 0
    ) async throws {
        let body: [String: Any] = [
            "model": model.id,
            "max_tokens": 4096,
            "stream": true,
            "system": systemPrompt + mode.systemSuffix,
            "messages": history
        ]
        let bodyData = try JSONSerialization.data(withJSONObject: body)

        guard let request = modelManager.buildRequest(for: model, body: bodyData) else {
            store.updateLastMessage(text: "[Failed to build request]", in: threadID)
            return
        }

        streamStartTime = Date()
        firstTokenTime = nil
        streamingOutputTokens = 0
        let inputTokens = history.reduce(0) { $0 + ($1["content"]?.count ?? 0) / 4 }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            modelManager.parseRateLimitHeaders(httpResponse, provider: model.provider)

            if httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines { errorBody += line }

                // Retry on 429 (rate limit) or 5xx
                if (httpResponse.statusCode == 429 || httpResponse.statusCode >= 500) && retryCount < 2 {
                    let delay = [3.0, 8.0][min(retryCount, 1)]
                    // Reset streaming state to avoid text concatenation on retry
                    streamingText = ""
                    streamingOutputTokens = 0
                    firstTokenTime = nil
                    store.updateLastMessage(text: "Reconnecting (\(retryCount + 1)/3)...", in: threadID)
                    try await Task.sleep(for: .seconds(delay))

                    // Try auto-failover on 2nd+ retry
                    var retryModel = model
                    var retryKey = key
                    if retryCount >= 1, let fallback = modelManager.failoverModel(),
                       let fbKey = modelManager.apiKey(for: fallback) {
                        retryModel = fallback
                        retryKey = fbKey
                        store.updateLastMessage(text: "Failover to \(fallback.displayName)...", in: threadID)
                    }

                    try await streamAnthropic(
                        history: history, threadID: threadID, store: store,
                        model: retryModel, key: retryKey, modelManager: modelManager,
                        mode: mode, retryCount: retryCount + 1
                    )
                    return
                }

                NetworkLog.shared.record(
                    provider: model.provider.rawValue, model: model.id,
                    inputTokens: inputTokens, outputTokens: 0, ttfbMs: 0,
                    totalMs: Int(Date().timeIntervalSince(streamStartTime!) * 1000),
                    status: "error", errorMessage: "HTTP \(httpResponse.statusCode)"
                )
                store.updateLastMessage(text: "[API Error \(httpResponse.statusCode): \(errorBody)]", in: threadID)
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
                  let type = event["type"] as? String else { continue }

            if type == "content_block_delta",
               let delta = event["delta"] as? [String: Any],
               let text = delta["text"] as? String {
                // Track first token time
                if firstTokenTime == nil {
                    firstTokenTime = Date()
                    streamingTTFB = Int(firstTokenTime!.timeIntervalSince(streamStartTime!) * 1000)
                }
                streamingText += text
                streamingOutputTokens += max(text.count / 4, 1)
                updateTokensPerSec()
                store.updateLastMessage(text: streamingText, in: threadID)
            }
        }

        // Record to network log
        let totalMs = Int(Date().timeIntervalSince(streamStartTime!) * 1000)
        NetworkLog.shared.record(
            provider: model.provider.rawValue, model: model.id,
            inputTokens: inputTokens, outputTokens: streamingOutputTokens,
            ttfbMs: streamingTTFB, totalMs: totalMs, status: "ok"
        )
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
        retryCount: Int = 0
    ) async throws {
        // OpenAI chat completions format (used by Perplexity, xAI)
        var messages: [[String: String]] = [["role": "system", "content": systemPrompt + mode.systemSuffix]]
        messages.append(contentsOf: history)

        var body: [String: Any] = [
            "model": model.id,
            "stream": true,
            "messages": messages
        ]

        // Search mode: add recency filter for fresh results (Perplexity-only)
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
        let inputTokens = history.reduce(0) { $0 + ($1["content"]?.count ?? 0) / 4 }

        let (bytes, response) = try await URLSession.shared.bytes(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            modelManager.parseRateLimitHeaders(httpResponse, provider: model.provider)

            if httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines { errorBody += line }

                // Retry on 429 or 5xx
                if (httpResponse.statusCode == 429 || httpResponse.statusCode >= 500) && retryCount < 2 {
                    let delay = [3.0, 8.0][min(retryCount, 1)]
                    streamingText = ""
                    streamingOutputTokens = 0
                    firstTokenTime = nil
                    store.updateLastMessage(text: "Reconnecting (\(retryCount + 1)/3)...", in: threadID)
                    try await Task.sleep(for: .seconds(delay))

                    var retryModel = model
                    var retryKey = key
                    if retryCount >= 1, let fallback = modelManager.failoverModel(),
                       let fbKey = modelManager.apiKey(for: fallback) {
                        retryModel = fallback
                        retryKey = fbKey
                        store.updateLastMessage(text: "Failover to \(fallback.displayName)...", in: threadID)
                    }

                    try await streamOpenAI(
                        history: history, threadID: threadID, store: store,
                        model: retryModel, key: retryKey, modelManager: modelManager,
                        mode: mode, retryCount: retryCount + 1
                    )
                    return
                }

                NetworkLog.shared.record(
                    provider: model.provider.rawValue, model: model.id,
                    inputTokens: inputTokens, outputTokens: 0, ttfbMs: 0,
                    totalMs: Int(Date().timeIntervalSince(streamStartTime!) * 1000),
                    status: "error", errorMessage: "HTTP \(httpResponse.statusCode)"
                )
                store.updateLastMessage(text: "[API Error \(httpResponse.statusCode): \(errorBody)]", in: threadID)
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
                streamingTTFB = Int(firstTokenTime!.timeIntervalSince(streamStartTime!) * 1000)
            }
            streamingText += content
            streamingOutputTokens += max(content.count / 4, 1)
            updateTokensPerSec()
            store.updateLastMessage(text: streamingText, in: threadID)
        }

        let totalMs = Int(Date().timeIntervalSince(streamStartTime!) * 1000)
        NetworkLog.shared.record(
            provider: model.provider.rawValue, model: model.id,
            inputTokens: inputTokens, outputTokens: streamingOutputTokens,
            ttfbMs: streamingTTFB, totalMs: totalMs, status: "ok"
        )
    }
}
