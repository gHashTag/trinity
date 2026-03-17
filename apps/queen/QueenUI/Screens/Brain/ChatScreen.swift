import SwiftUI
import AppKit
import AVFoundation
import Speech
import UniformTypeIdentifiers

struct ChatScreen: View {
    @StateObject private var store = ThreadStore()
    @StateObject private var client = ChatClient()
    @StateObject private var commentClient = ChatClient()
    @StateObject private var modelManager = ModelManager()
    @StateObject private var repoContext = RepoContext()
    private var trinityCtx: TrinityContext { TrinityContext.shared }
    @State private var input = ""
    @State private var commentingMessage: ChatMessage? = nil
    @State private var chatMode: ChatMode = .trinity
    @State private var attachedFiles: [(name: String, content: String)] = []
    @State private var isRecording = false
    @State private var showShortcuts = false
    @State private var isDropTargeted = false
    @State private var showScrollToBottom = false
    @State private var showComparison = false
    @State private var comparisonPrompt = ""
    @State private var showCommandPalette = false
    @State private var showMentionPopup = false
    @State private var mentionQuery = ""
    @State private var showSidebar = true
    @State private var showModelPopover = false
    @State private var slashCommandResult: String? = nil
    @State private var showThinkingTranscript = false
    @State private var showOnboarding = false
    @State private var taskItems: [TaskItem] = []
    @State private var selectedPersona: Persona? = nil
    @State private var showPersonaLibrary = false
    @State private var lastSentText = ""
    @State private var showSentConfirmation = false
    @State private var showDraftSaved = false
    @State private var showQueueDrained = false
    @State private var queueDrainedMessageCount = 0
    @State private var showInThreadSearch = false
    @State private var inThreadSearchQuery = ""
    @State private var inThreadSearchIndex = 0
    @AppStorage("stylePreset") private var stylePresetRaw: String = StylePreset.concise.rawValue
    @AppStorage("effortLevel") private var effortLevelRaw: String = EffortLevel.medium.rawValue
    @AppStorage("useCtrlEnterToSend") private var useCtrlEnterToSend = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var focused: Bool

    private var stylePreset: StylePreset {
        get { StylePreset(rawValue: stylePresetRaw) ?? .concise }
    }

    private var effortLevel: EffortLevel {
        get { EffortLevel(rawValue: effortLevelRaw) ?? .medium }
        set { effortLevelRaw = newValue.rawValue }
    }

    /// Parse @mentions from current input into visual chips
    private var parsedMentionChips: [(type: String, value: String)] {
        let mentions: [(String, String)] = [
            ("@file:", "file"), ("@grep:", "grep"), ("@build", "build"),
            ("@farm", "farm"), ("@issues", "issues"), ("@gitdiff", "gitdiff"),
        ]
        var chips: [(String, String)] = []
        for (prefix, type) in mentions {
            if input.contains(prefix) {
                if prefix.hasSuffix(":") {
                    // Extract value after prefix
                    if let range = input.range(of: prefix) {
                        let after = input[range.upperBound...]
                        let value = String(after.prefix(while: { !$0.isWhitespace }))
                        if !value.isEmpty {
                            chips.append((type, value))
                        }
                    }
                } else {
                    chips.append((type, type))
                }
            }
        }
        return chips
    }

    private var thread: ChatThread? {
        store.activeThread()
    }

    /// Messages matching in-thread search
    private var inThreadSearchMatches: [ChatMessage] {
        guard !inThreadSearchQuery.isEmpty, let msgs = thread?.messages else { return [] }
        let q = inThreadSearchQuery.lowercased()
        return msgs.filter { $0.text.lowercased().contains(q) }
    }

    /// Token estimation: ~3.5 chars/token for English, ~2.5 for code/mixed
    private var estimatedTokens: Int {
        let msgs = thread?.messages ?? []
        let msgTokens = msgs.reduce(0) { total, msg in
            total + estimateTokens(msg.text)
        }
        let inputTokens = estimateTokens(input)
        // Add ~200 tokens for system prompt overhead
        return msgTokens + inputTokens + 200
    }

    /// Improved token estimation: code-heavy text has more tokens per char
    private func estimateTokens(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let hasCode = text.contains("```") || text.contains("    ")
        let ratio: Double = hasCode ? 3.2 : 3.8 // chars per token
        return Int(ceil(Double(text.count) / ratio))
    }

    /// Dynamic placeholder based on chat mode
    private var placeholder: String {
        switch chatMode {
        case .search: return "Search the web..."
        case .trinity: return "Ask anything about Trinity..."
        case .reason: return "Describe a problem to analyze..."
        case .compare: return "Enter prompt to compare models..."
        case .image: return "Describe an image to generate..."
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Sidebar with context inspector (toggleable)
                if showSidebar {
                    VStack(spacing: 0) {
                        ChatSidebar(store: store, modelManager: modelManager)

                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)

                        ContextInspector()
                            .frame(maxHeight: 200)

                        Rectangle()
                            .fill(Color.white.opacity(0.06))
                            .frame(height: 1)

                        NetworkDashboard(client: client, modelManager: modelManager)
                            .frame(maxHeight: 220)
                    }
                    .frame(width: 240)
                    .transition(.move(edge: .leading))

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)
                }

                // Main chat area
                ZStack(alignment: .bottomTrailing) {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Connection status bar
                        ConnectionStatusBar(modelManager: modelManager, client: client)

                        // Sticky context meter (always visible when >1K tokens)
                        ContextBar(tokens: estimatedTokens)

                        // In-thread search bar (Cmd+F)
                        if showInThreadSearch {
                            InThreadSearchBar(
                                query: $inThreadSearchQuery,
                                currentIndex: $inThreadSearchIndex,
                                totalMatches: inThreadSearchMatches.count,
                                onDismiss: {
                                    showInThreadSearch = false
                                    inThreadSearchQuery = ""
                                    inThreadSearchIndex = 0
                                }
                            )
                        }

                        // Messages
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(alignment: .leading, spacing: 0) {
                                    if thread?.messages.isEmpty != false {
                                        EmptyThreadView(chatMode: $chatMode, onSuggestion: { suggestion in
                                            input = suggestion
                                            send()
                                        })
                                    }
                                    ForEach(thread?.messages ?? []) { msg in
                                        MessageRow(
                                            message: msg,
                                            store: store,
                                            client: client,
                                            modelManager: modelManager,
                                            isLastMessage: msg.id == thread?.messages.last?.id,
                                            onComment: { commentingMessage = $0 }
                                        )
                                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .offset(y: 6)))
                                    }

                                    errorRetryBlock

                                    // Typing indicator + streaming metrics
                                    if client.isStreaming {
                                        VStack(alignment: .leading, spacing: 6) {
                                            HStack(spacing: 12) {
                                                if !client.streamingThinkingText.isEmpty && client.streamingText.isEmpty {
                                                    // Reasoning mode: show pulsing indicator with elapsed + hint
                                                    ThinkingDots()
                                                    Text("Reasoning...")
                                                        .font(.caption)
                                                        .foregroundStyle(TrinityTheme.purple)
                                                    StreamingElapsedTimer()
                                                    if effortLevel == .max || effortLevel == .high {
                                                        Text("(may take 10-30s)")
                                                            .font(.system(size: 9))
                                                            .foregroundStyle(TrinityTheme.textMuted)
                                                    }
                                                } else if thread?.messages.last?.text.isEmpty ?? false {
                                                    ThinkingDots()
                                                    SpinnerVerb()
                                                        .font(.caption)
                                                        .foregroundStyle(TrinityTheme.textMuted)
                                                    // Live TTFB counter while waiting for first token
                                                    LiveTTFBCounter(isWaiting: client.streamingTTFB == 0)
                                                }
                                                // Show TTFB after first token arrives
                                                if client.streamingTTFB > 0 {
                                                    Text("TTFB \(client.streamingTTFB)ms")
                                                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                        .foregroundStyle(ttfbColor(client.streamingTTFB))
                                                }
                                                if client.streamingTokensPerSec > 0 {
                                                    Text(String(format: "%.0f tok/s", client.streamingTokensPerSec))
                                                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                                                        .foregroundStyle(TrinityTheme.accent)
                                                }
                                                if client.streamingOutputTokens > 0 {
                                                    Text("\(client.streamingOutputTokens) tok")
                                                        .font(.system(size: 10, design: .monospaced))
                                                        .foregroundStyle(TrinityTheme.textMuted)
                                                }
                                            }

                                            // Slow response warning (>3s for non-reasoning, >10s for reasoning)
                                            if client.isSlowResponse {
                                                HStack(spacing: 6) {
                                                    Image(systemName: "tortoise.fill")
                                                        .font(.system(size: 10))
                                                    Text("Slow response")
                                                        .font(.system(size: 10, weight: .medium))
                                                    Button {
                                                        client.stop()
                                                        if let threadID = store.activeThreadID {
                                                            store.removeLastAssistantMessage(in: threadID)
                                                            input = thread?.messages.last(where: { $0.role == .user })?.text ?? ""
                                                        }
                                                    } label: {
                                                        Text("Cancel")
                                                            .font(.system(size: 10, weight: .bold))
                                                            .foregroundStyle(.black)
                                                            .padding(.horizontal, 8)
                                                            .padding(.vertical, 3)
                                                            .background(TrinityTheme.statusError)
                                                            .clipShape(Capsule())
                                                    }
                                                    .buttonStyle(.plain)
                                                    if let fallback = modelManager.failoverModel() {
                                                        Button {
                                                            client.stop()
                                                            modelManager.selectedModel = fallback
                                                            modelManager.persistSelection()
                                                            if let threadID = store.activeThreadID {
                                                                store.removeLastAssistantMessage(in: threadID)
                                                                input = thread?.messages.last(where: { $0.role == .user })?.text ?? ""
                                                            }
                                                        } label: {
                                                            Text("Try \(fallback.displayName)")
                                                                .font(.system(size: 10, weight: .bold))
                                                                .foregroundStyle(.black)
                                                                .padding(.horizontal, 8)
                                                                .padding(.vertical, 3)
                                                                .background(TrinityTheme.statusWarn)
                                                                .clipShape(Capsule())
                                                        }
                                                        .buttonStyle(.plain)
                                                    }
                                                }
                                                .foregroundStyle(TrinityTheme.statusWarn)
                                                .transition(.opacity)
                                            }
                                        }
                                        .padding(.vertical, 12)
                                        .transition(.opacity)
                                    }

                                    // Tool execution timeline
                                    if !client.activeToolCalls.isEmpty {
                                        ToolTimeline(steps: client.activeToolCalls)
                                            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                                    }

                                    // Elicitation card (Queen asks a question)
                                    if let q = client.elicitationQuestion {
                                        ElicitationCard(
                                            question: q.question,
                                            options: q.options,
                                            onSelect: { answer in
                                                input = answer
                                                send()
                                                client.elicitationQuestion = nil
                                            }
                                        )
                                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                                    }

                                    // Follow-up suggestions (after response)
                                    if !client.isStreaming && !client.followUpSuggestions.isEmpty {
                                        FollowUpSuggestions(
                                            suggestions: client.followUpSuggestions,
                                            onSelect: { suggestion in
                                                input = suggestion
                                                send()
                                                client.followUpSuggestions = []
                                            }
                                        )
                                        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
                                    }

                                    Color.clear.frame(height: 1).id("bottom")
                                }
                                .padding(.horizontal, 60)
                                .padding(.top, 20)
                                .padding(.bottom, 100)
                                .background(
                                    GeometryReader { geo in
                                        Color.clear
                                            .preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("chatScroll")).maxY)
                                    }
                                )
                            }
                            .coordinateSpace(name: "chatScroll")
                            .onPreferenceChange(ScrollOffsetKey.self) { maxY in
                                // Show scroll-to-bottom when content is scrolled up
                                showScrollToBottom = maxY > 800
                            }
                            .onChange(of: thread?.messages.count) {
                                withAnimation(.easeOut(duration: 0.15)) {
                                    proxy.scrollTo("bottom", anchor: .bottom)
                                }
                            }
                            .onChange(of: client.streamingText) {
                                proxy.scrollTo("bottom", anchor: .bottom)
                            }
                            .onChange(of: inThreadSearchIndex) { _, newIdx in
                                let matches = inThreadSearchMatches
                                if newIdx < matches.count {
                                    withAnimation(.easeOut(duration: 0.2)) {
                                        proxy.scrollTo(matches[newIdx].id, anchor: .center)
                                    }
                                }
                            }

                            // Scroll-to-bottom FAB
                            if showScrollToBottom && !client.isStreaming {
                                Button {
                                    withAnimation(.easeOut(duration: 0.3)) {
                                        proxy.scrollTo("bottom", anchor: .bottom)
                                    }
                                } label: {
                                    Image(systemName: "arrow.down.circle.fill")
                                        .font(.system(size: 32))
                                        .foregroundStyle(TrinityTheme.accent)
                                        .background(Circle().fill(Color.black).padding(4))
                                        .shadow(color: .black.opacity(0.5), radius: 8)
                                }
                                .buttonStyle(.plain)
                                .accessibilityLabel("Scroll to bottom")
                                .padding(.trailing, 24)
                                .padding(.bottom, 180)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }

                        Spacer(minLength: 0)

                        // Smart suggestions (proactive actions based on Trinity state)
                        if thread?.messages.isEmpty != false {
                            SmartSuggestions { prompt in
                                input = prompt
                                send()
                            }
                        }

                        // @Mention popup (above input)
                        if showMentionPopup {
                            MentionPopup(
                                query: mentionQuery,
                                isPresented: $showMentionPopup,
                                onSelect: { value in
                                    // Replace @query with @value in input
                                    if let atRange = input.range(of: "@\(mentionQuery)", options: .backwards) {
                                        input.replaceSubrange(atRange, with: "@\(value)")
                                    }
                                    // Save grep pattern for history
                                    if value.hasPrefix("grep:") {
                                        let pattern = String(value.dropFirst(5))
                                        MentionPopup.saveGrepPattern(pattern)
                                    }
                                    showMentionPopup = false
                                },
                                repoContext: repoContext,
                                trinityContext: trinityCtx
                            )
                            .padding(.horizontal, 60)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }

                        stickyStreamingBar

                        inputAreaContent
                        inputBarView
                        modeBarView
                    }
                }
                .layoutPriority(1)
                // Drag & drop files onto chat area
                .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
                    handleFileDrop(providers)
                    return true
                }

                // Comment sidebar (Grok-style)
                if let msg = commentingMessage {
                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(width: 1)

                    CommentSidebar(
                        message: msg,
                        store: store,
                        client: commentClient,
                        modelManager: modelManager,
                        onClose: { commentingMessage = nil }
                    )
                }
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: commentingMessage != nil)

            // Shortcuts overlay
            if showShortcuts {
                ShortcutsOverlay(isPresented: $showShortcuts)
            }

            // Command palette (Cmd+K)
            if showCommandPalette {
                CommandPalette(
                    isPresented: $showCommandPalette,
                    store: store,
                    modelManager: modelManager
                ) { action in
                    handlePaletteAction(action)
                }
                .transition(.opacity)
            }

            // Model comparison overlay
            if showComparison {
                ModelComparisonView(
                    prompt: comparisonPrompt,
                    modelManager: modelManager,
                    onClose: { showComparison = false }
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showComparison)
        .background(Color.black)
        .onAppear {
            if store.threads.isEmpty { store.newThread() }
            focused = true
            // Show onboarding on first launch
            if !UserDefaults.standard.bool(forKey: "onboardingCompleted") {
                showOnboarding = true
            }
            // Defer heavy work off the body evaluation path
            Task { @MainActor in
                NotificationService.shared.requestPermission()
                NetworkLog.shared.checkAllProviders()
                store.cleanupOldThreads()
                modelManager.refreshOllamaModels()
                client.loadPersistedQueue()
            }
            startHealthRefreshTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleCommandPalette)) { _ in
            showCommandPalette.toggle()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
            withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .newThread)) { _ in
            store.newThread()
        }
        .onReceive(NotificationCenter.default.publisher(for: .prevThread)) { _ in
            let sorted = store.sortedThreads
            guard let currentID = store.activeThreadID,
                  let idx = sorted.firstIndex(where: { $0.id == currentID }),
                  idx > 0 else { return }
            store.activeThreadID = sorted[idx - 1].id
        }
        .onReceive(NotificationCenter.default.publisher(for: .nextThread)) { _ in
            let sorted = store.sortedThreads
            guard let currentID = store.activeThreadID,
                  let idx = sorted.firstIndex(where: { $0.id == currentID }),
                  idx < sorted.count - 1 else { return }
            store.activeThreadID = sorted[idx + 1].id
        }
        .onReceive(NotificationCenter.default.publisher(for: .searchInThread)) { _ in
            showInThreadSearch = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .copyLastResponse)) { _ in
            if let last = thread?.messages.last(where: { $0.role == .assistant }) {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(last.text, forType: .string)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .showThinkingTranscript)) { _ in
            showThinkingTranscript = true
        }
        .sheet(isPresented: $showThinkingTranscript) {
            ThinkingTranscriptSheet(messages: thread?.messages ?? [])
        }
        .sheet(isPresented: $showOnboarding) {
            OnboardingWalkthrough(isPresented: $showOnboarding)
        }
        .sheet(isPresented: $showPersonaLibrary) {
            PersonaLibrary(
                selectedPersona: $selectedPersona,
                isPresented: $showPersonaLibrary,
                onSelectTemplate: { template in
                    input = template
                }
            )
        }
        // Draft auto-save: persist input text per thread
        .onChange(of: input) { _, newValue in
            if let tid = store.activeThreadID {
                UserDefaults.standard.set(newValue, forKey: "draft_\(tid)")
            }
            // Clear follow-up suggestions when user starts typing
            if !newValue.isEmpty && !client.followUpSuggestions.isEmpty {
                client.followUpSuggestions = []
            }
            // Draft save indicator
            if !newValue.isEmpty {
                showDraftSaved = true
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(2))
                    showDraftSaved = false
                }
            }
        }
        .onChange(of: client.extractedTasks) { _, newTasks in
            if !newTasks.isEmpty {
                taskItems = newTasks.map { TaskItem(title: $0) }
            }
        }
        .onChange(of: store.activeThreadID) { _, newID in
            // Save current draft before switching
            // Restore draft for new thread
            if let tid = newID {
                let draft = UserDefaults.standard.string(forKey: "draft_\(tid)") ?? ""
                input = draft
            }
        }
        .onChange(of: selectedPersona) { _, newPersona in
            // Save persona to current thread
            if let tid = store.activeThreadID,
               let idx = store.threads.firstIndex(where: { $0.id == tid }) {
                store.threads[idx].personaID = newPersona?.id
                store.saveThread(tid)
            }
        }
    }

    // MARK: - Extracted Input Area Views

    @ViewBuilder
    private var errorRetryBlock: some View {
        if !client.isStreaming,
           let last = thread?.messages.last,
           last.role == .assistant,
           last.hasError {
            let errKind = last.errorKind!
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: errKind.icon)
                        .font(.system(size: 16))
                        .foregroundStyle(errKind.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(errKind.label)
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(errKind.color)
                        if let detail = client.lastError?.userMessage {
                            Text(detail)
                                .font(.system(size: 11))
                                .foregroundStyle(TrinityTheme.textMuted)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    Button {
                        guard let threadID = store.activeThreadID else { return }
                        client.regenerate(threadID: threadID, store: store, modelManager: modelManager)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 12, weight: .bold))
                            Text("Retry")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(errKind.color)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    Button {
                        if let userMsg = thread?.messages.last(where: { $0.role == .user }) {
                            input = userMsg.text
                        }
                        guard let threadID = store.activeThreadID else { return }
                        store.removeLastAssistantMessage(in: threadID)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "pencil")
                                .font(.system(size: 12, weight: .bold))
                            Text("Edit & Retry")
                                .font(.system(size: 12, weight: .bold))
                        }
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(Color.white.opacity(0.1))
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)

                    if let fallback = modelManager.failoverModel() {
                        Button {
                            modelManager.selectedModel = fallback
                            modelManager.persistSelection()
                            guard let threadID = store.activeThreadID else { return }
                            client.regenerate(threadID: threadID, store: store, modelManager: modelManager)
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: 12, weight: .bold))
                                Text("Try \(fallback.displayName)")
                                    .font(.system(size: 12, weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 6)
                            .background(TrinityTheme.accent)
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(12)
            .background(errKind.color.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.vertical, 8)
            .transition(.opacity)
        }
        // Legacy error fallback
        else if !client.isStreaming,
           let last = thread?.messages.last,
           last.role == .assistant,
           !last.hasError,
           last.text.hasPrefix("[") && last.text.contains("Error") {
            HStack(spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.statusError)
                Text(String(last.text.prefix(200)))
                    .font(.system(size: 13))
                    .foregroundStyle(TrinityTheme.statusError)
                    .lineLimit(2)
                Button {
                    guard let threadID = store.activeThreadID else { return }
                    client.regenerate(threadID: threadID, store: store, modelManager: modelManager)
                } label: {
                    Text("Retry")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(TrinityTheme.statusError)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, 12)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var stickyStreamingBar: some View {
        if client.isStreaming {
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(client.streamingState == .connecting ? TrinityTheme.statusWarn : TrinityTheme.statusOK)
                        .frame(width: 5, height: 5)
                    Text(client.streamingState == .connecting ? "Connecting..." : "Streaming")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                if client.streamingOutputTokens > 0 {
                    if client.streamingTTFB > 0 {
                        Text("TTFB \(client.streamingTTFB)ms")
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(ttfbColor(client.streamingTTFB))
                    }
                    Text(String(format: "%.0f tok/s", client.streamingTokensPerSec))
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(TrinityTheme.accent)
                    Text("\(client.streamingOutputTokens) tok")
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                Spacer()
                Button {
                    client.stop()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "stop.circle.fill")
                            .font(.system(size: 10))
                        Text("Stop")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(TrinityTheme.statusError)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .help("Stop generating (Esc)")
                .keyboardShortcut(.escape, modifiers: [])
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 4)
            .background(Color.white.opacity(0.03))
        }
    }

    @ViewBuilder
    private var offlineQueueBadge: some View {
        Group {
            if client.offlineQueueCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "envelope.badge")
                        .font(.system(size: 11))
                    Text("\(client.offlineQueueCount) queued")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(Color.orange)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.12))
                .clipShape(Capsule())
                .padding(.horizontal, 60)
            } else if showQueueDrained {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                    Text("\(queueDrainedMessageCount) queued messages sent")
                        .font(.system(size: 12, weight: .medium))
                }
                .foregroundStyle(TrinityTheme.statusOK)
                .padding(.horizontal, 10)
                .padding(.vertical, 5)
                .background(TrinityTheme.statusOK.opacity(0.12))
                .clipShape(Capsule())
                .padding(.horizontal, 60)
            }
        }
        .onChange(of: client.queueDrainedCount) { _, newValue in
            if newValue > 0 {
                queueDrainedMessageCount = newValue
                withAnimation { showQueueDrained = true }
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(3))
                    withAnimation { showQueueDrained = false }
                    client.queueDrainedCount = 0
                }
            }
        }
    }

    @ViewBuilder
    private var inputAreaContent: some View {
        // Offline queue badge + drain toast
        offlineQueueBadge

        // Slash command result banner
        if let result = slashCommandResult {
            HStack(spacing: 8) {
                Image(systemName: "terminal")
                    .font(.system(size: 11))
                    .foregroundStyle(TrinityTheme.accent)
                Text(result)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)
                Spacer()
                Button {
                    slashCommandResult = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(TrinityTheme.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 60)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
        }

        // Slash command autocomplete
        if input.hasPrefix("/") && !input.contains(" ") && input.count > 1 {
            let query = input.lowercased()
            let matches = SlashCommand.allCases.filter { $0.rawValue.hasPrefix(query) }
            if !matches.isEmpty {
                HStack(spacing: 6) {
                    ForEach(matches, id: \.rawValue) { cmd in
                        Button {
                            input = cmd.rawValue + " "
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: cmd.icon)
                                    .font(.system(size: 10))
                                Text(cmd.rawValue)
                                    .font(.system(size: 11, weight: .medium))
                            }
                            .foregroundStyle(Color.white.opacity(0.7))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.white.opacity(0.06))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, 60)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            }
        }

        // Offline queue banner
        if client.offlineQueueCount > 0 {
            OfflineQueueBanner(
                count: client.offlineQueueCount,
                onCancelAll: {
                    for q in client.offlineQueue {
                        client.cancelQueued(q.id)
                    }
                },
                queue: client.offlineQueue,
                onCancelOne: { id in
                    client.cancelQueued(id)
                }
            )
        }

        // Provider recovery notification
        if let recovered = NetworkLog.shared.recoveredProviders.first {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(TrinityTheme.statusOK)
                Text("\(recovered) is back online")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TrinityTheme.statusOK)
                Spacer()
                if modelManager.selectedModel.provider.rawValue != recovered {
                    Button {
                        if let model = modelManager.availableModels.first(where: { $0.provider.rawValue == recovered }) {
                            modelManager.selectedModel = model
                            modelManager.persistSelection()
                        }
                    } label: {
                        Text("Switch back")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(TrinityTheme.statusOK)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    NetworkLog.shared.recoveredProviders.removeAll { $0 == recovered }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(TrinityTheme.statusOK.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 60)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
        }

        // Rejection feedback inline (auto-dismiss after 30s)
        if let rejection = client.showRejectionFeedback,
           let threadID = store.activeThreadID, rejection.threadID == threadID {
            RejectionFeedbackView(
                onSubmit: { feedback in
                    client.resendWithFeedback(
                        feedback,
                        originalMessageID: rejection.messageID,
                        threadID: rejection.threadID,
                        store: store,
                        modelManager: modelManager
                    )
                },
                onDismiss: {
                    client.showRejectionFeedback = nil
                }
            )
            .onAppear {
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(30))
                    client.showRejectionFeedback = nil
                }
            }
        }

        // Context overflow warning
        if estimatedTokens > 144_000 { // 80% of 180K
            ContextOverflowBanner(
                tokens: estimatedTokens,
                onSummarize: {
                    input = "Summarize our conversation so far in 3 bullet points, then continue helping me."
                    send()
                },
                onNewThread: {
                    let summary = thread?.messages.suffix(4).map { "\($0.role == .user ? "User" : "Queen"): \(String($0.text.prefix(100)))" }.joined(separator: "\n") ?? ""
                    let newThread = store.newThread()
                    input = "Continue from previous thread:\n\(summary)"
                    store.activeThreadID = newThread.id
                }
            )
        }

        // Build error banner (above input)
        BuildErrorBanner { errorPrompt in
            input = errorPrompt
            send()
        }

        // Memory proposal cards
        if !client.proposedMemories.isEmpty {
            MemoryProposalCard(
                memories: client.proposedMemories,
                onAccept: { entry in
                    store.saveMemory(entry)
                    client.proposedMemories.removeAll { $0.id == entry.id }
                },
                onDismiss: { entry in
                    client.proposedMemories.removeAll { $0.id == entry.id }
                }
            )
            .padding(.horizontal, 60)
        }

        // Task tracker
        if !taskItems.isEmpty {
            TaskTrackerView(tasks: $taskItems)
                .padding(.horizontal, 60)
                .padding(.bottom, 4)
        }

        // @Mention chips (parsed from input — click to remove)
        if !parsedMentionChips.isEmpty {
            HStack(spacing: 6) {
                ForEach(parsedMentionChips, id: \.value) { chip in
                    Button {
                        // Remove this mention from input
                        let mentionStr = chip.type == chip.value ? "@\(chip.type)" : "@\(chip.type):\(chip.value)"
                        input = input.replacingOccurrences(of: mentionStr, with: "")
                            .trimmingCharacters(in: .whitespaces)
                    } label: {
                        HStack(spacing: 2) {
                            MentionChip(type: chip.type, value: chip.value)
                            Image(systemName: "xmark")
                                .font(.system(size: 7))
                                .foregroundStyle(Color.white.opacity(0.3))
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 2)
        }

        // Attached files chips
        if !attachedFiles.isEmpty {
            HStack(spacing: 8) {
                ForEach(attachedFiles.indices, id: \.self) { idx in
                    HStack(spacing: 4) {
                        Image(systemName: "paperclip")
                            .font(.caption2)
                        Text(attachedFiles[idx].name)
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.accent)
                            .lineLimit(1)
                        Button {
                            attachedFiles.remove(at: idx)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 4)
        }
    }

    @ViewBuilder
    private var inputBarView: some View {
        HStack(spacing: 0) {
            HStack(spacing: 4) {
                ModelPicker(modelManager: modelManager)
                PersonaPicker(selectedPersona: $selectedPersona, showLibrary: $showPersonaLibrary)
            }
            .padding(.leading, 14)

            MultilineInput(
                text: $input,
                placeholder: placeholder,
                isFocused: $focused,
                onSubmit: { send() },
                onImagePaste: { name, path in
                    attachedFiles.append((name: name, content: "[Image: \(name)]"))
                },
                onMentionTrigger: { query in
                    mentionQuery = query ?? ""
                    showMentionPopup = query != nil
                }
            )
            .padding(.horizontal, 12)
            .padding(.vertical, 14)

            HStack(spacing: 8) {
                Button { openFilePicker() } label: {
                    Image(systemName: "paperclip")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Attach file (⌘O)")

                Button { showShortcuts.toggle() } label: {
                    Image(systemName: "keyboard")
                        .font(.system(size: 15))
                        .foregroundStyle(Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Shortcuts (⌘/)")

                Button { toggleVoiceInput() } label: {
                    Image(systemName: isRecording ? "mic.fill" : "mic")
                        .font(.system(size: 15))
                        .foregroundStyle(isRecording ? TrinityTheme.statusError : Color.white.opacity(0.4))
                }
                .buttonStyle(.plain)
                .help("Voice input")

                sendButton

                // Send confirmation tick
                if showSentConfirmation {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TrinityTheme.accent)
                        .transition(.opacity.combined(with: .scale))
                }
                // Draft saved indicator + character counter
                if showDraftSaved && !showSentConfirmation && !client.isStreaming {
                    Text("Draft")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.2))
                        .transition(.opacity)
                }
                if input.count > 200 {
                    Text("\(input.count)")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(input.count > 8000 ? TrinityTheme.statusError : Color.white.opacity(0.2))
                }
            }
            .padding(.trailing, 10)
        }
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(hex: 0x1A1A1A))
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isDropTargeted ? TrinityTheme.accent : Color.white.opacity(0.08), lineWidth: isDropTargeted ? 2 : 1)
                )
        )
        .padding(.horizontal, 60)
    }

    @ViewBuilder
    private var sendButton: some View {
        Group {
            if client.isStreaming {
                Button(action: { client.stop() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(TrinityTheme.accent)
                }
            } else {
                Button(action: { send() }) {
                    ZStack {
                        Circle()
                            .fill(input.isEmpty ? Color.white.opacity(0.1) : modeColor(chatMode))
                            .frame(width: 32, height: 32)
                        Image(systemName: chatMode == .image ? "photo" : "arrow.up")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(input.isEmpty ? Color.white.opacity(0.3) : .black)
                    }
                }
                .disabled(input.isEmpty)
                .popover(isPresented: $showModelPopover) {
                    VStack(spacing: 4) {
                        Text("Send with model")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .padding(.top, 8)
                        ForEach(modelManager.availableModels.filter { modelManager.providerHasKey($0.provider) }) { model in
                            Button {
                                showModelPopover = false
                                sendWithModel(model)
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                        .font(.system(size: 12))
                                    if model == modelManager.selectedModel {
                                        Image(systemName: "checkmark")
                                            .font(.system(size: 10))
                                    }
                                }
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)
                    .frame(minWidth: 180)
                    .background(Color(hex: 0x1A1A1A))
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    if !input.isEmpty {
                        showModelPopover = true
                    }
                }
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var modeBarView: some View {
        HStack(spacing: 12) {
            ForEach(ChatMode.allCases, id: \.rawValue) { mode in
                Button { chatMode = mode } label: {
                    HStack(spacing: 4) {
                        Image(systemName: mode.icon)
                            .font(.system(size: 12))
                        Text(mode.rawValue)
                            .font(.system(size: 12, weight: .medium))
                    }
                    .foregroundStyle(chatMode == mode ? .black : Color.white.opacity(0.5))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(chatMode == mode ? modeColor(mode) : Color.white.opacity(0.06))
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .stroke(chatMode == mode ? modeColor(mode) : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
            }

            Spacer()

            // Effort level picker
            Menu {
                ForEach(EffortLevel.allCases) { level in
                    Button {
                        effortLevelRaw = level.rawValue
                        client.effortLevel = level
                    } label: {
                        HStack {
                            Image(systemName: level.icon)
                            Text(level.rawValue)
                            if effortLevel == level {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: effortLevel.icon)
                        .font(.system(size: 10))
                    Text(effortLevel.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(effortLevel.color)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(effortLevel.color.opacity(0.12))
                .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Effort level: controls reasoning depth")

            // Style preset picker
            Menu {
                ForEach(StylePreset.allCases) { preset in
                    Button {
                        stylePresetRaw = preset.rawValue
                        client.stylePreset = preset
                    } label: {
                        HStack {
                            Image(systemName: preset.icon)
                            Text(preset.rawValue)
                            if stylePreset == preset {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: stylePreset.icon)
                        .font(.system(size: 10))
                    Text(stylePreset.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(0.5))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.06))
                .clipShape(Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()

            ContextMeter(tokens: estimatedTokens)
        }
        .padding(.horizontal, 60)
        .padding(.bottom, 16)
    }

    private func send(modelOverride: AIModel? = nil) {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !client.isStreaming else { return }

        // Slash command handling
        var effortLevelVar = effortLevel
        var chatModeVar = chatMode
        if client.executeSlashCommand(
            text,
            store: store,
            modelManager: modelManager,
            effortBinding: &effortLevelVar,
            chatModeBinding: &chatModeVar,
            onResult: { result in
                slashCommandResult = result
                // Errors persist until user dismisses; success auto-dismisses after 4s
                let isError = result.lowercased().contains("error") || result.lowercased().contains("fail") || result.lowercased().contains("invalid")
                if !isError {
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(4))
                        slashCommandResult = nil
                    }
                }
            }
        ) {
            effortLevelRaw = effortLevelVar.rawValue
            chatMode = chatModeVar
            input = ""
            return
        }

        // Compare mode: open side-by-side view instead of sending
        if chatMode == .compare {
            comparisonPrompt = text
            input = ""
            showComparison = true
            return
        }

        guard let threadID = store.activeThreadID else { return }

        // Prepend attached file contents
        for file in attachedFiles {
            text += "\n\n[Attached: \(file.name)]\n```\n\(file.content)\n```"
        }
        attachedFiles.removeAll()

        lastSentText = text
        input = ""
        // Clear draft on send
        UserDefaults.standard.removeObject(forKey: "draft_\(threadID)")
        // Brief send confirmation
        showSentConfirmation = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            showSentConfirmation = false
        }
        // Sync style preset, effort level, and persona
        client.stylePreset = stylePreset
        client.effortLevel = effortLevel
        client.activePersona = selectedPersona
        client.send(text, threadID: threadID, store: store, modelManager: modelManager, mode: chatMode, modelOverride: modelOverride)

        // Auto-compaction check after send
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            client.checkAutoCompaction(threadID: threadID, store: store, modelManager: modelManager)
        }
    }

    private func sendWithModel(_ model: AIModel) {
        send(modelOverride: model)
    }

    private func ttfbColor(_ ms: Int) -> Color {
        if ms < 1000 { return TrinityTheme.accent }
        if ms < 3000 { return TrinityTheme.textMuted }
        if ms < 5000 { return TrinityTheme.statusWarn }
        return TrinityTheme.statusError
    }

    private func modeColor(_ mode: ChatMode) -> Color {
        switch mode {
        case .search: return TrinityTheme.accent
        case .trinity: return TrinityTheme.golden
        case .reason: return TrinityTheme.purple
        case .compare: return Color(hex: 0x8BE9FD)  // cyan
        case .image: return Color(hex: 0xFF6B6B)
        }
    }

    private let maxAttachmentSize = 16384 // 16KB

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .sourceCode, .json, .yaml, .xml, .png, .jpeg]
        panel.begin { response in
            guard response == .OK else { return }
            let urls = Array(panel.urls.prefix(3))
            Task.detached { [maxAttachmentSize] in
                for url in urls {
                    guard let data = try? Data(contentsOf: url) else { continue }
                    let name = url.lastPathComponent
                    let size = data.count
                    if let content = String(data: data.prefix(maxAttachmentSize), encoding: .utf8) {
                        let truncated = size > maxAttachmentSize
                        let sizeLabel = size >= 1024 ? "\(size/1024)KB" : "\(size)B"
                        let label = truncated
                            ? "\(name) (\(sizeLabel) → \(maxAttachmentSize/1024)KB)"
                            : "\(name) (\(sizeLabel))"
                        await MainActor.run {
                            attachedFiles.append((name: label, content: content))
                            if truncated {
                                slashCommandResult = "\(name): \(sizeLabel) truncated to \(maxAttachmentSize/1024)KB"
                                Task { @MainActor in
                                    try? await Task.sleep(for: .seconds(4))
                                    slashCommandResult = nil
                                }
                            }
                        }
                    } else {
                        await MainActor.run {
                            attachedFiles.append((name: "\(name) (binary)", content: "[Binary file: \(name), \(size) bytes]"))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Drag & Drop

    private func handleFileDrop(_ providers: [NSItemProvider]) {
        for provider in providers.prefix(3) {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                // Load off main thread
                Task.detached {
                    guard let fileData = try? Data(contentsOf: url) else { return }
                    let name = url.lastPathComponent
                    if let content = String(data: fileData.prefix(8192), encoding: .utf8) {
                        await MainActor.run {
                            attachedFiles.append((name: name, content: content))
                        }
                    } else {
                        await MainActor.run {
                            attachedFiles.append((name: "\(name) (binary)", content: "[Binary file: \(name)]"))
                        }
                    }
                }
            }
        }
    }

    // MARK: - Voice Input

    private func toggleVoiceInput() {
        if isRecording {
            isRecording = false
            return
        }

        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    isRecording = true
                    startListening()
                case .denied, .restricted:
                    slashCommandResult = "Microphone access denied. Enable in System Settings > Privacy > Speech Recognition"
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(5))
                        slashCommandResult = nil
                    }
                case .notDetermined:
                    break // Wait for user decision
                @unknown default:
                    break
                }
            }
        }
    }

    private func startListening() {
        guard let recognizer = SFSpeechRecognizer(), recognizer.isAvailable else {
            isRecording = false
            return
        }

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        let audioEngine = AVAudioEngine()
        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { buffer, _ in
            request.append(buffer)
        }

        audioEngine.prepare()
        try? audioEngine.start()

        recognizer.recognitionTask(with: request) { result, error in
            if let result {
                DispatchQueue.main.async {
                    input = result.bestTranscription.formattedString
                }
            }
            if error != nil || (result?.isFinal ?? false) {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                DispatchQueue.main.async {
                    isRecording = false
                }
            }
        }

        // Auto-stop after 30s
        Task {
            try? await Task.sleep(for: .seconds(30))
            if isRecording {
                audioEngine.stop()
                inputNode.removeTap(onBus: 0)
                request.endAudio()
                await MainActor.run { isRecording = false }
            }
        }
    }

    private func handlePaletteAction(_ action: CommandPalette.PaletteAction) {
        switch action {
        case .switchThread(let id):
            store.activeThreadID = id
        case .newThread:
            store.newThread()
        case .switchModel(let model):
            modelManager.selectedModel = model
            modelManager.persistSelection()
        case .switchMode(let mode):
            chatMode = mode
        case .exportThread:
            if let threadID = store.activeThreadID,
               let md = store.exportAsMarkdown(threadID) {
                let panel = NSSavePanel()
                panel.allowedContentTypes = [.plainText]
                panel.nameFieldStringValue = "thread.md"
                panel.begin { response in
                    guard response == .OK, let url = panel.url else { return }
                    try? md.data(using: .utf8)?.write(to: url)
                }
            }
        case .toggleSearch:
            NotificationCenter.default.post(name: .toggleThreadSearch, object: nil)
        case .runCommand(let prompt):
            input = prompt
            send()
        }
    }

    private func startHealthRefreshTimer() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                NetworkLog.shared.checkAllProviders()
                // Check for provider recovery after health check
                try? await Task.sleep(for: .seconds(3))
                NetworkLog.shared.checkRecovery()
            }
        }
    }
}

// MARK: - Notification for cross-view communication

public extension Notification.Name {
    static let toggleThreadSearch = Notification.Name("toggleThreadSearch")
    static let toggleCommandPalette = Notification.Name("toggleCommandPalette")
    static let toggleSidebar = Notification.Name("toggleSidebar")
    static let copyLastResponse = Notification.Name("copyLastResponse")
    static let newThread = Notification.Name("newThread")
    static let showThinkingTranscript = Notification.Name("showThinkingTranscript")
    static let prevThread = Notification.Name("prevThread")
    static let nextThread = Notification.Name("nextThread")
    static let searchInThread = Notification.Name("searchInThread")
}

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - Connection Status Bar

struct ConnectionStatusBar: View {
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var client: ChatClient
    @StateObject private var networkLog = NetworkLog.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared
    @State private var isOnline: Bool? = nil  // nil = checking
    @State private var showFailover = false

    private var selectedProviderUp: Bool {
        let provider = modelManager.selectedModel.provider.rawValue
        return networkLog.providerHealth[provider]?.isUp ?? true
    }

    var body: some View {
        VStack(spacing: 0) {
            // Device network offline (WiFi/Ethernet down)
            if !networkMonitor.isConnected {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                    Text("No network connection")
                        .font(.caption2)
                    Spacer()
                    Text(networkMonitor.connectionType.rawValue)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .foregroundStyle(TrinityTheme.statusError)
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(TrinityTheme.statusError.opacity(0.12))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Reconnected toast
            if networkMonitor.wasDisconnected {
                HStack(spacing: 6) {
                    Image(systemName: "wifi")
                        .font(.caption2)
                    Text("Reconnected")
                        .font(.caption2)
                    Spacer()
                }
                .foregroundStyle(TrinityTheme.statusOK)
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(TrinityTheme.statusOK.opacity(0.08))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Failover chain notification
            if let event = client.failoverEvent, showFailover {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                    Text(event.from)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TrinityTheme.statusError)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 8))
                    Text(event.to)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(TrinityTheme.statusOK)
                    Text("timed out → switched")
                        .font(.system(size: 9))
                        .foregroundStyle(TrinityTheme.textMuted)
                    Spacer()
                    // Undo: switch back to original
                    Button {
                        if let original = modelManager.availableModels.first(where: { $0.displayName == event.from }) {
                            modelManager.selectedModel = original
                            modelManager.persistSelection()
                        }
                        withAnimation { showFailover = false }
                    } label: {
                        Text("Undo")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(TrinityTheme.accent)
                    }
                    .buttonStyle(.plain)
                    Button {
                        withAnimation { showFailover = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(TrinityTheme.accent)
                .padding(.horizontal, 16)
                .padding(.vertical, 5)
                .background(TrinityTheme.accent.opacity(0.08))
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            // Offline warning for selected provider
            if let online = isOnline, !online {
                HStack(spacing: 6) {
                    Image(systemName: "wifi.exclamationmark")
                        .font(.caption2)
                    Text("No API connection — check keys in .env")
                        .font(.caption2)
                    Spacer()
                    Button("Retry") {
                        isOnline = nil
                        checkConnection()
                    }
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(TrinityTheme.statusError)
                    .clipShape(Capsule())
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retry connection")
                }
                .foregroundStyle(TrinityTheme.statusError)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .background(TrinityTheme.statusError.opacity(0.1))
            }

            // Provider status dots bar (show if any provider is down)
            if networkLog.providerHealth.values.contains(where: { !$0.isUp }) {
                HStack(spacing: 12) {
                    ForEach(Array(networkLog.providerHealth.values).sorted(by: { $0.name < $1.name }), id: \.name) { status in
                        HStack(spacing: 4) {
                            Circle()
                                .fill(status.isUp ? TrinityTheme.statusOK : TrinityTheme.statusError)
                                .frame(width: 5, height: 5)
                            Text(status.name)
                                .font(.system(size: 9))
                                .foregroundStyle(status.isUp ? TrinityTheme.textMuted : TrinityTheme.statusError)
                            if let remaining = status.remainingRequests {
                                Text("(\(remaining))")
                                    .font(.system(size: 8, design: .monospaced))
                                    .foregroundStyle(TrinityTheme.textMuted)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.02))
            }

            // Rate limit predictor warning
            RateLimitWarning(modelManager: modelManager)

            // MCP server status + Branch pill
            HStack(spacing: 12) {
                MCPStatusView()
                    .onAppear {
                        // Will load from .mcp.json
                    }
                BranchPill()
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 2)
        }
        .onAppear { checkConnection() }
        .onChange(of: client.failoverEvent) {
            withAnimation(.easeInOut(duration: 0.3)) { showFailover = true }
            // Auto-dismiss after 4s
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(4))
                withAnimation(.easeInOut(duration: 0.3)) { showFailover = false }
            }
        }
    }

    private func checkConnection() {
        Task {
            if !modelManager.hasAnyKey {
                isOnline = false
                return
            }
            // Check the selected model's provider endpoint
            let baseURL = modelManager.baseURL(for: modelManager.selectedModel)
            guard let url = URL(string: baseURL)?.deletingLastPathComponent() else {
                isOnline = false
                return
            }
            var request = URLRequest(url: url)
            request.httpMethod = "HEAD"
            request.timeoutInterval = 5
            do {
                let (_, response) = try await URLSession.shared.data(for: request)
                isOnline = (response as? HTTPURLResponse)?.statusCode != nil
            } catch {
                isOnline = false
            }
        }
    }
}

// MARK: - Context Meter (token usage bar)

struct ContextMeter: View {
    let tokens: Int
    @StateObject private var networkLog = NetworkLog.shared
    private let maxTokens = 180_000

    var body: some View {
        let ratio = min(Double(tokens) / Double(maxTokens), 1.0)
        let color: Color = ratio < 0.5 ? TrinityTheme.accent
            : ratio < 0.8 ? TrinityTheme.golden
            : TrinityTheme.statusError
        let cost = networkLog.todayCostEstimate()

        HStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(color)
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(width: 60, height: 3)

            Text("\(tokens / 1000)K")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundStyle(TrinityTheme.textMuted)

            if cost > 0.001 {
                Text(String(format: "$%.2f", cost))
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(cost > 1.0 ? TrinityTheme.golden : TrinityTheme.textMuted)
            }
        }
        .help("\(tokens) tokens / \(maxTokens / 1000)K context | Session: $\(String(format: "%.3f", cost))")
    }
}

// MARK: - Sticky Context Bar (always visible at top of chat)

struct ContextBar: View {
    let tokens: Int
    private let maxTokens = 180_000

    private var ratio: Double { min(Double(tokens) / Double(maxTokens), 1.0) }
    private var percent: Int { Int(ratio * 100) }

    private var color: Color {
        if ratio < 0.5 { return TrinityTheme.accent }
        if ratio < 0.7 { return TrinityTheme.golden }
        if ratio < 0.85 { return TrinityTheme.statusWarn }
        return TrinityTheme.statusError
    }

    var body: some View {
        if tokens > 1000 {
            HStack(spacing: 8) {
                // Progress bar
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.06))
                        Capsule()
                            .fill(color)
                            .frame(width: geo.size.width * ratio)
                    }
                }
                .frame(height: 3)

                Text("\(tokens / 1000)K / \(maxTokens / 1000)K")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(color)
                    .fixedSize()

                if ratio >= 0.7 {
                    Text("\(percent)%")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundStyle(color)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 60)
            .padding(.vertical, 4)
            .background(ratio >= 0.7 ? color.opacity(0.04) : Color.clear)
        }
    }
}

// MARK: - Model Picker (inline, compact)

struct ModelPicker: View {
    @ObservedObject var modelManager: ModelManager
    @StateObject private var networkLog = NetworkLog.shared

    private func providerIsUp(_ provider: AIProvider) -> Bool {
        networkLog.providerHealth[provider.rawValue]?.isUp ?? true
    }

    /// Sparkline string using Unicode block chars for TTFB history
    private func sparkline(for modelID: String) -> String {
        let points = networkLog.recentTTFB(for: modelID, count: 7)
        guard points.count >= 2 else { return "" }
        let bars: [Character] = ["▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"]
        let lo = Double(points.min() ?? 0)
        let hi = Double(points.max() ?? 1)
        let range = max(hi - lo, 1)
        return String(points.map { val in
            let idx = Int((Double(val) - lo) / range * 7)
            return bars[min(max(idx, 0), 7)]
        })
    }

    /// Average TTFB for display
    private func avgTTFB(for modelID: String) -> Int? {
        let points = networkLog.recentTTFB(for: modelID)
        guard !points.isEmpty else { return nil }
        return points.reduce(0, +) / points.count
    }

    var body: some View {
        Menu {
            ForEach(AIProvider.allCases) { provider in
                if modelManager.providerHasKey(provider) {
                    Section(provider.rawValue) {
                        ForEach(modelManager.availableModels.filter { $0.provider == provider }) { model in
                            Button(action: {
                                modelManager.selectedModel = model
                                modelManager.persistSelection()
                            }) {
                                HStack {
                                    Circle()
                                        .fill(providerIsUp(model.provider) ? TrinityTheme.statusOK : TrinityTheme.statusError)
                                        .frame(width: 6, height: 6)
                                    Text(model.displayName)
                                    let spark = sparkline(for: model.id)
                                    if !spark.isEmpty {
                                        Text(spark)
                                            .font(.system(size: 9))
                                        if let avg = avgTTFB(for: model.id) {
                                            Text("\(avg)ms")
                                                .font(.system(size: 9, design: .monospaced))
                                        }
                                    }
                                    if modelManager.selectedModel == model {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: 4) {
                Circle()
                    .fill(providerIsUp(modelManager.selectedModel.provider) ? TrinityTheme.statusOK : TrinityTheme.statusError)
                    .frame(width: 6, height: 6)
                Text(modelManager.selectedModel.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                // Inline sparkline on picker label
                let spark = sparkline(for: modelManager.selectedModel.id)
                if !spark.isEmpty {
                    Text(spark)
                        .font(.system(size: 9))
                        .foregroundStyle(TrinityTheme.accent.opacity(0.7))
                }
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))

                // Rate limit warning badge
                if let remaining = networkLog.providerHealth[modelManager.selectedModel.provider.rawValue]?.remainingRequests,
                   remaining < 20 {
                    Text("\(remaining)")
                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(remaining < 5 ? TrinityTheme.statusError : TrinityTheme.statusWarn)
                        .clipShape(Capsule())
                        .help("\(remaining) requests remaining")
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
    }
}

// MARK: - Message Row (Perplexity style — no bubbles)

struct MessageRow: View {
    let message: ChatMessage
    @ObservedObject var store: ThreadStore
    @ObservedObject var client: ChatClient
    @ObservedObject var modelManager: ModelManager
    var isLastMessage: Bool = false
    var onComment: ((ChatMessage) -> Void)? = nil
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editText = ""
    @AppStorage("chatFontSize") private var chatFontSize = 15

    /// Estimate token count for this message
    private var estimatedTokens: Int {
        if let actual = message.outputTokens { return actual }
        let chars = message.text.count
        guard chars > 0 else { return 0 }
        let hasCode = message.text.contains("```") || message.text.contains("    ")
        let ratio: Double = hasCode ? 3.2 : 3.8
        return Int(ceil(Double(chars) / ratio))
    }

    /// Estimate token share of this message (0...1)
    private var tokenShare: Double {
        let chars = Double(message.text.count)
        guard chars > 0 else { return 0 }
        let hasCode = message.text.contains("```") || message.text.contains("    ")
        let ratio: Double = hasCode ? 3.2 : 3.8
        let tokens = chars / ratio
        return min(tokens / 180_000.0, 1.0)
    }

    private var tokenBadgeColor: Color {
        if estimatedTokens < 500 { return TrinityTheme.textMuted }
        if estimatedTokens < 2000 { return TrinityTheme.accent }
        if estimatedTokens < 5000 { return TrinityTheme.golden }
        return TrinityTheme.statusError
    }

    private var tokenBadgeText: String {
        if estimatedTokens >= 1000 {
            return String(format: "%.1fK", Double(estimatedTokens) / 1000.0)
        }
        return "\(estimatedTokens)"
    }

    var body: some View {
        HStack(spacing: 0) {
        VStack(alignment: .leading, spacing: 0) {
            if message.role == .user {
                // User message — bold, slightly larger
                HStack(alignment: .top, spacing: 0) {
                    Spacer(minLength: 0)
                    VStack(alignment: .trailing, spacing: 4) {
                        if isEditing {
                            // Inline edit mode
                            VStack(alignment: .trailing, spacing: 6) {
                                TextField("Edit message...", text: $editText, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: CGFloat(chatFontSize), weight: .semibold))
                                    .foregroundStyle(Color.white)
                                    .lineLimit(1...10)
                                    .padding(10)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                    .onSubmit { submitEdit() }

                                HStack(spacing: 8) {
                                    Button("Cancel") {
                                        isEditing = false
                                    }
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .buttonStyle(.plain)

                                    Button("Send") { submitEdit() }
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 4)
                                        .background(TrinityTheme.accent)
                                        .clipShape(Capsule())
                                        .buttonStyle(.plain)
                                }
                            }
                        } else {
                            Text(message.text)
                                .font(.system(size: CGFloat(chatFontSize), weight: .semibold))
                                .foregroundStyle(Color.white)
                                .textSelection(.enabled)
                                .multilineTextAlignment(.trailing)
                        }

                        // Branch navigator (when message has been edited/forked)
                        if message.branchID != nil, let threadID = store.activeThreadID {
                            BranchNavigator(message: message, store: store, threadID: threadID)
                        }

                        // Timestamp + action buttons on hover
                        if isHovering && !isEditing {
                            HStack(spacing: 8) {
                                Button {
                                    editText = message.text
                                    isEditing = true
                                } label: {
                                    Image(systemName: "pencil")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                .help("Edit & resend")

                                Button {
                                    NSPasteboard.general.clearContents()
                                    NSPasteboard.general.setString(message.text, forType: .string)
                                } label: {
                                    Image(systemName: "doc.on.doc")
                                        .font(.system(size: 10))
                                        .foregroundStyle(Color.white.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                .help("Copy")

                                Button {
                                    guard let threadID = store.activeThreadID else { return }
                                    store.toggleBookmark(message.id, in: threadID)
                                } label: {
                                    Image(systemName: message.isBookmarked == true ? "bookmark.fill" : "bookmark")
                                        .font(.system(size: 10))
                                        .foregroundStyle(message.isBookmarked == true ? TrinityTheme.accent : Color.white.opacity(0.4))
                                }
                                .buttonStyle(.plain)
                                .help("Bookmark")

                                Text(message.timestamp, style: .time)
                                    .font(.system(size: 10))
                                    .foregroundStyle(TrinityTheme.textMuted)
                            }
                            .transition(.opacity)
                        }
                    }
                    .padding(.vertical, 16)
                }
            } else {
                // Assistant message — plain text, full width, readable
                VStack(alignment: .leading, spacing: 8) {
                    messageContent
                        .font(.system(size: CGFloat(chatFontSize), weight: .regular))
                        .foregroundStyle(Color(hex: 0xD1D1D1))
                        .textSelection(.enabled)
                        .lineSpacing(4)
                        .padding(.top, 16)

                    // Action toolbar (only for non-empty assistant messages)
                    if !message.text.isEmpty {
                        HStack(spacing: 0) {
                            MessageActionBar(
                                message: message,
                                store: store,
                                client: client,
                                modelManager: modelManager,
                                isHovering: isHovering,
                                onComment: onComment
                            )

                            // Timestamp on hover
                            if isHovering {
                                Text(message.timestamp, style: .time)
                                    .font(.system(size: 10))
                                    .foregroundStyle(TrinityTheme.textMuted)
                                    .padding(.leading, 8)
                                    .transition(.opacity)
                            }

                            Spacer()

                            // Token count badge
                            if estimatedTokens > 0 {
                                Text("\(tokenBadgeText) tok")
                                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                                    .foregroundStyle(tokenBadgeColor)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(tokenBadgeColor.opacity(0.1))
                                    .clipShape(Capsule())
                                    .help(message.outputTokens != nil ? "Actual tokens" : "Estimated tokens")
                            }
                        }
                        .padding(.top, 8)
                        .padding(.bottom, 12)
                    }
                }
            }

            // Thin separator between messages
            Rectangle()
                .fill(Color.white.opacity(0.04))
                .frame(height: 1)
        }

        // Token budget bar (right edge)
        if isHovering && !message.text.isEmpty {
            GeometryReader { geo in
                let barHeight = max(geo.size.height * min(tokenShare * 50, 1.0), 4)
                let color: Color = tokenShare < 0.02 ? TrinityTheme.accent.opacity(0.3)
                    : tokenShare < 0.05 ? TrinityTheme.golden.opacity(0.5)
                    : TrinityTheme.statusError.opacity(0.5)
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: 2, height: barHeight)
                }
            }
            .frame(width: 2)
            .transition(.opacity)
        }
        } // HStack
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        // Context menu (right-click)
        .contextMenu {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(message.text, forType: .string)
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if message.role == .user {
                Button {
                    editText = message.text
                    isEditing = true
                } label: {
                    Label("Edit & Resend", systemImage: "pencil")
                }
            }

            if message.role == .assistant, !client.isStreaming {
                Button {
                    guard let threadID = store.activeThreadID else { return }
                    client.regenerateFrom(messageID: message.id, threadID: threadID, store: store, modelManager: modelManager)
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
            }

            Button {
                guard let threadID = store.activeThreadID else { return }
                store.toggleBookmark(message.id, in: threadID)
            } label: {
                Label(
                    message.isBookmarked == true ? "Remove Bookmark" : "Bookmark",
                    systemImage: message.isBookmarked == true ? "bookmark.fill" : "bookmark"
                )
            }

            if let onComment {
                Button {
                    onComment(message)
                } label: {
                    Label("Comment", systemImage: "text.bubble")
                }
            }

            Divider()

            if message.role == .assistant {
                Button(role: .destructive) {
                    guard let threadID = store.activeThreadID else { return }
                    store.deleteMessage(message.id, in: threadID)
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(message.role == .user ? "You" : "Queen"): \(String(message.text.prefix(200)))")
        .accessibilityHint(message.role == .user ? "Double-tap to edit" : "Double-tap for actions")
    }

    private func submitEdit() {
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !client.isStreaming else { return }
        guard let threadID = store.activeThreadID else { return }
        isEditing = false
        client.editAndResend(message.id, newText: text, threadID: threadID, store: store, modelManager: modelManager)
    }

    @ViewBuilder
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Thinking/reasoning block (collapsible)
            if let thinking = message.thinkingText, !thinking.isEmpty {
                ThinkingBlockView(text: thinking)
            }

            // Sources panel (shown BEFORE answer for search mode)
            if let citations = message.citations, !citations.isEmpty {
                SourcesPanel(citations: citations)
            }

            if message.text.isEmpty {
                Text(" ")
            } else {
                MarkdownTextView(text: message.text, citations: message.citations)
            }

            // Display attached images (from image generation)
            if let urls = message.imageURLs, !urls.isEmpty {
                ForEach(urls, id: \.self) { url in
                    ImageBlockView(alt: "Generated Image", url: url)
                }
            }

            // Stale data badge
            if message.role == .assistant, !message.text.isEmpty {
                StaleBadge(message: message, store: store, client: client, modelManager: modelManager)
            }
        }
    }
}

// MARK: - Action Toolbar (Perplexity style)

struct MessageActionBar: View {
    let message: ChatMessage
    @ObservedObject var store: ThreadStore
    @ObservedObject var client: ChatClient
    @ObservedObject var modelManager: ModelManager
    let isHovering: Bool
    var onComment: ((ChatMessage) -> Void)? = nil

    @State private var isSpeaking = false
    @State private var didCopy = false
    @State private var synthesizer: AVSpeechSynthesizer?
    @State private var showRegenModelPicker = false

    private var isLiked: Bool? {
        message.isLiked
    }

    /// Detect if message has an error
    private var hasError: Bool {
        message.text.contains("[Error:") || message.text.contains("[API Error")
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left: action buttons
            HStack(spacing: 16) {
                // Regenerate — always visible, long-press for model picker
                actionButton(
                    "arrow.clockwise",
                    tooltip: "Regenerate (long-press for model picker)",
                    active: hasError,
                    tint: hasError ? TrinityTheme.statusError : nil
                ) {
                    guard let threadID = store.activeThreadID else { return }
                    client.regenerateFrom(
                        messageID: message.id,
                        threadID: threadID,
                        store: store,
                        modelManager: modelManager
                    )
                }
                .popover(isPresented: $showRegenModelPicker) {
                    VStack(spacing: 4) {
                        Text("Regenerate with")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .padding(.top, 8)
                        ForEach(modelManager.availableModels.filter { !$0.isImageModel }) { model in
                            Button {
                                showRegenModelPicker = false
                                guard let threadID = store.activeThreadID else { return }
                                client.regenerateFromWithModel(
                                    messageID: message.id,
                                    threadID: threadID,
                                    store: store,
                                    modelManager: modelManager,
                                    withModel: model
                                )
                            } label: {
                                HStack {
                                    ProviderDot(provider: model.provider)
                                    Text(model.displayName)
                                        .font(.system(size: 12))
                                    Spacer()
                                    if model.id == message.modelID {
                                        Text("current")
                                            .font(.system(size: 9))
                                            .foregroundStyle(Color.white.opacity(0.3))
                                    }
                                }
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)
                    .frame(minWidth: 200)
                    .background(Color(hex: 0x1A1A1A))
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    showRegenModelPicker = true
                }

                actionButton(isSpeaking ? "speaker.slash" : "speaker.wave.2", tooltip: isSpeaking ? "Stop" : "Read aloud") {
                    toggleSpeech()
                }

                actionButton(didCopy ? "checkmark" : "doc.on.doc", tooltip: "Copy", active: didCopy) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(message.text, forType: .string)
                    didCopy = true
                    Task {
                        try? await Task.sleep(for: .seconds(2))
                        await MainActor.run { didCopy = false }
                    }
                }

                actionButton("square.and.arrow.up", tooltip: "Share") {
                    let picker = NSSharingServicePicker(items: [message.text])
                    if let window = NSApp.keyWindow,
                       let contentView = window.contentView {
                        picker.show(relativeTo: .zero, of: contentView, preferredEdge: .minY)
                    }
                }

                actionButton("text.bubble", tooltip: "Comment") {
                    onComment?(message)
                }

                actionButton(
                    message.isBookmarked == true ? "bookmark.fill" : "bookmark",
                    tooltip: "Bookmark",
                    active: message.isBookmarked == true
                ) {
                    guard let threadID = store.activeThreadID else { return }
                    store.toggleBookmark(message.id, in: threadID)
                }

                actionButton(
                    "hand.thumbsup\(isLiked == true ? ".fill" : "")",
                    tooltip: "Like",
                    active: isLiked == true
                ) {
                    guard let threadID = store.activeThreadID else { return }
                    let newVal: Bool? = (isLiked == true) ? nil : true
                    store.toggleLike(message.id, liked: newVal, in: threadID)
                }

                actionButton(
                    "hand.thumbsdown\(isLiked == false ? ".fill" : "")",
                    tooltip: "Dislike — tell Queen what to do instead",
                    active: isLiked == false
                ) {
                    guard let threadID = store.activeThreadID else { return }
                    let newVal: Bool? = (isLiked == false) ? nil : false
                    store.toggleLike(message.id, liked: newVal, in: threadID)
                    // Show rejection feedback input
                    if newVal == false {
                        client.showRejectionFeedback = (messageID: message.id, threadID: threadID)
                    }
                }
            }

            Spacer()

            // Persisted metrics badge + cost
            if let ttfb = message.ttfbMs, let tps = message.tokPerSec, let tok = message.outputTokens {
                HStack(spacing: 6) {
                    Text("\(ttfb)ms")
                        .foregroundStyle(TrinityTheme.textMuted)
                    Text(String(format: "%.0f tok/s", tps))
                        .foregroundStyle(TrinityTheme.accent)
                    Text("\(tok) tok")
                        .foregroundStyle(TrinityTheme.textMuted)
                    // Cost estimate
                    if let modelID = message.modelID {
                        let provider = modelID.contains("claude") || modelID.contains("sonnet") || modelID.contains("opus") || modelID.contains("haiku") ? "Anthropic"
                            : modelID.contains("glm") ? "z.ai"
                            : modelID.contains("sonar") ? "Perplexity"
                            : modelID.contains("grok") ? "xAI"
                            : modelID.contains("llama") || modelID.contains("qwen") ? "Ollama" : "Anthropic"
                        let cost = AIModel.estimateCost(provider: provider, inputTokens: tok, outputTokens: tok)
                        if cost > 0.0001 {
                            Text(String(format: "$%.3f", cost))
                                .foregroundStyle(TrinityTheme.golden)
                        }
                    }
                }
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .padding(.trailing, 8)
            }

            // Right: model badge pill
            if let modelID = message.modelID {
                modelBadge(modelID)
            }
        }
        .opacity(isHovering ? 1 : 0.5)
        .animation(.easeInOut(duration: 0.15), value: isHovering)
    }

    @ViewBuilder
    private func actionButton(_ icon: String, tooltip: String, active: Bool = false, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(tint ?? (active ? TrinityTheme.accent : Color.white.opacity(0.4)))
        }
        .buttonStyle(ActionIconStyle())
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }

    @ViewBuilder
    private func modelBadge(_ modelID: String) -> some View {
        let name = modelDisplayName(modelID)
        HStack(spacing: 5) {
            Image(systemName: "cpu")
                .font(.system(size: 10))
            Text(name)
                .font(.system(size: 11, weight: .medium))
        }
        .foregroundStyle(Color.white.opacity(0.5))
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.white.opacity(0.06))
        .clipShape(Capsule())
    }

    private func modelDisplayName(_ id: String) -> String {
        if let model = modelManager.availableModels.first(where: { $0.id == id }) {
            return model.displayName
        }
        let parts = id.split(separator: "-")
        if parts.count > 2 {
            return parts.prefix(2).joined(separator: "-").capitalized
        }
        return id
    }

    private func toggleSpeech() {
        if isSpeaking {
            synthesizer?.stopSpeaking(at: .immediate)
            synthesizer = nil
            isSpeaking = false
        } else {
            let synth = AVSpeechSynthesizer()
            synthesizer = synth
            isSpeaking = true
            let utterance = AVSpeechUtterance(string: message.text)
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            synth.speak(utterance)
            Task {
                while synth.isSpeaking {
                    try? await Task.sleep(for: .milliseconds(200))
                }
                await MainActor.run {
                    isSpeaking = false
                }
            }
        }
    }
}

// MARK: - Action Icon Button Style

struct ActionIconStyle: ButtonStyle {
    @State private var isHovered = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(isHovered ? 0.8 : 0.6)
            .scaleEffect(configuration.isPressed ? 0.9 : 1.0)
            .onHover { isHovered = $0 }
            .animation(.easeInOut(duration: 0.1), value: isHovered)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Empty State with Suggestion Chips

struct EmptyThreadView: View {
    @Binding var chatMode: ChatMode
    var onSuggestion: ((String) -> Void)?
    @StateObject private var trinityCtx = TrinityContext.shared

    private var suggestions: [(String, String, ChatMode)] {
        var items: [(String, String, ChatMode)] = []

        // Contextual suggestions based on live state
        if trinityCtx.buildOK == false {
            items.append(("\u{1F6A8}", "Build is broken — diagnose and fix", .trinity))
        }
        if let ppl = trinityCtx.bestPPL, let run = trinityCtx.bestRun {
            items.append(("\u{1F3C6}", "\(run) PPL=\(String(format: "%.1f", ppl)) — analyze results", .trinity))
        }
        if let dirty = trinityCtx.dirtyFiles, dirty > 10 {
            items.append(("\u{1F9F9}", "\(dirty) dirty files — review changes", .trinity))
        }

        // Static fallbacks
        items.append(("\u{1F50D}", "What's new in ternary AI research?", .search))
        items.append(("\u{1F4A1}", "Analyze Trinity's architecture trade-offs", .reason))
        items.append(("\u{1F5BC}", "Trinity logo: golden crown on black, sci-fi style", .image))

        return Array(items.prefix(6))
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer(minLength: 60)

            // Logo
            Text("👑")
                .font(.system(size: 56))

            Text("Queen")
                .font(.system(size: 28, weight: .semibold))
                .foregroundStyle(Color.white)
            Text("Personal CTO of Trinity")
                .font(.system(size: 15))
                .foregroundStyle(Color.white.opacity(0.4))

            // Suggestion chips grid
            VStack(spacing: 10) {
                HStack(spacing: 10) {
                    ForEach(0..<3) { i in
                        suggestionChip(suggestions[i])
                    }
                }
                HStack(spacing: 10) {
                    ForEach(3..<6) { i in
                        suggestionChip(suggestions[i])
                    }
                }
            }
            .padding(.top, 16)

            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func suggestionChip(_ item: (String, String, ChatMode)) -> some View {
        let (emoji, text, mode) = item
        Button {
            chatMode = mode
            onSuggestion?(text)
        } label: {
            HStack(spacing: 6) {
                Text(emoji)
                    .font(.system(size: 13))
                Text(text)
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.7))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(0.04))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.08), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Multiline Input (Enter sends, Shift+Enter inserts newline)

struct MultilineInput: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var isFocused: FocusState<Bool>.Binding
    var onSubmit: () -> Void
    var onImagePaste: ((String, String) -> Void)? = nil  // (name, base64) callback
    var onMentionTrigger: ((String?) -> Void)? = nil  // trigger @mention popup (nil = dismiss)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.containerSize = NSSize(width: 0, height: CGFloat.greatestFiniteMagnitude)
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.insertionPointColor = .white

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder

        context.coordinator.textView = textView
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }
        if textView.string != text {
            textView.string = text
        }
        context.coordinator.onSubmit = onSubmit
        context.coordinator.placeholder = placeholder
        context.coordinator.onImagePaste = onImagePaste
        context.coordinator.onMentionTrigger = onMentionTrigger

        // Update placeholder visibility
        context.coordinator.updatePlaceholder()

        if isFocused.wrappedValue {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, placeholder: placeholder, onImagePaste: onImagePaste, onMentionTrigger: onMentionTrigger)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onSubmit: () -> Void
        var placeholder: String
        var onImagePaste: ((String, String) -> Void)?
        var onMentionTrigger: ((String?) -> Void)?
        weak var textView: NSTextView?
        private var placeholderLayer: CATextLayer?

        init(text: Binding<String>, onSubmit: @escaping () -> Void, placeholder: String, onImagePaste: ((String, String) -> Void)? = nil, onMentionTrigger: ((String?) -> Void)? = nil) {
            self._text = text
            self.onSubmit = onSubmit
            self.placeholder = placeholder
            self.onImagePaste = onImagePaste
            self.onMentionTrigger = onMentionTrigger
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            text = textView.string
            updatePlaceholder()

            // Detect @mention trigger — show popup on @ and while typing after it
            let cursorPos = textView.selectedRange().location
            let str = textView.string
            var mentionDetected = false
            if cursorPos > 0 && cursorPos <= str.count {
                let idx = str.index(str.startIndex, offsetBy: cursorPos)
                let before = str[str.startIndex..<idx]
                // Find last @ before cursor
                if let atRange = before.range(of: "@", options: .backwards) {
                    let query = String(before[atRange.upperBound...])
                    if !query.contains(" ") && !query.contains("\n") {
                        onMentionTrigger?(query)
                        mentionDetected = true
                    }
                }
            }
            if !mentionDetected {
                onMentionTrigger?(String?.none)  // dismiss popup
            }

            // Constrain height to ~8 lines
            if let container = textView.textContainer, let layoutManager = textView.layoutManager {
                layoutManager.ensureLayout(for: container)
                let rect = layoutManager.usedRect(for: container)
                let maxHeight: CGFloat = 200  // ~8 lines
                if let scrollView = textView.enclosingScrollView {
                    scrollView.hasVerticalScroller = rect.height > maxHeight
                }
            }
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                let useCtrlEnter = UserDefaults.standard.bool(forKey: "useCtrlEnterToSend")
                let modifiers = NSEvent.modifierFlags

                if useCtrlEnter {
                    // Ctrl+Enter mode: Ctrl+Enter = send, Enter = newline
                    if modifiers.contains(.control) {
                        onSubmit()
                        return true
                    }
                    textView.insertNewlineIgnoringFieldEditor(nil)
                    return true
                } else {
                    // Default mode: Enter = send, Shift+Enter = newline
                    if modifiers.contains(.shift) {
                        textView.insertNewlineIgnoringFieldEditor(nil)
                        return true
                    }
                    onSubmit()
                    return true
                }
            }
            return false
        }

        /// Handle paste: intercept images from clipboard
        func textView(_ textView: NSTextView, shouldChangeTextIn range: NSRange, replacementString text: String?) -> Bool {
            // Check for image paste on Cmd+V
            let pb = NSPasteboard.general
            if text == nil || text?.isEmpty == true {
                // Check for image data in pasteboard
                if let tiffData = pb.data(forType: .tiff),
                   let bitmap = NSBitmapImageRep(data: tiffData),
                   let pngData = bitmap.representation(using: .png, properties: [:]) {
                    let name = "clipboard-\(Int(Date().timeIntervalSince1970)).png"
                    // Save to temp file for attachment
                    let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(name)
                    try? pngData.write(to: tempURL)
                    onImagePaste?(name, tempURL.path)
                    return false // Don't insert text
                }
            }
            return true
        }

        func updatePlaceholder() {
            guard let textView = textView else { return }
            if placeholderLayer == nil {
                let layer = CATextLayer()
                layer.font = NSFont.systemFont(ofSize: 15) as CFTypeRef
                layer.fontSize = 15
                layer.foregroundColor = NSColor.white.withAlphaComponent(0.3).cgColor
                layer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2.0
                textView.wantsLayer = true
                textView.layer?.addSublayer(layer)
                placeholderLayer = layer
            }
            placeholderLayer?.string = placeholder
            placeholderLayer?.frame = CGRect(x: 5, y: 0, width: textView.bounds.width - 10, height: 20)
            placeholderLayer?.isHidden = !text.isEmpty
        }
    }
}

// MARK: - @Mention Popup (Cursor-style context injection with autocomplete)

struct MentionPopup: View {
    let query: String
    @Binding var isPresented: Bool
    var onSelect: (String) -> Void
    var repoContext: RepoContext? = nil
    var trinityContext: TrinityContext? = nil

    @State private var selectedIndex = 0
    @AppStorage("recentGrepPatterns") private var recentGrepPatternsRaw: String = ""

    private var recentGrepPatterns: [String] {
        recentGrepPatternsRaw.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    static func saveGrepPattern(_ pattern: String) {
        let key = "recentGrepPatterns"
        var existing = (UserDefaults.standard.string(forKey: key) ?? "")
            .split(separator: "\n").map(String.init).filter { !$0.isEmpty }
        existing.removeAll { $0 == pattern }
        existing.insert(pattern, at: 0)
        if existing.count > 10 { existing = Array(existing.prefix(10)) }
        UserDefaults.standard.set(existing.joined(separator: "\n"), forKey: key)
    }

    private var completions: [(icon: String, label: String, value: String, badge: String?)] {
        let q = query.lowercased()

        // If query starts with "file:", show file suggestions
        if q.hasPrefix("file:") {
            let fileQuery = String(q.dropFirst(5))
            let suggestions = repoContext?.fileSuggestions(matching: fileQuery, limit: 8) ?? []
            if !suggestions.isEmpty {
                return suggestions.map { path in
                    let ext = (path as NSString).pathExtension
                    let icon = ext == "swift" ? "swift" : ext == "zig" ? "cpu" : ext == "md" ? "doc.richtext" : "doc.text"
                    return (icon, path, "file:\(path)", nil)
                }
            }
        }

        // If query starts with "grep:", show grep suggestions
        if q.hasPrefix("grep:") {
            let grepQuery = String(q.dropFirst(5))
            let builtins = ["func ", "struct ", "class ", "TODO", "FIXME", "import ", "error", "test "]
            let allPatterns = recentGrepPatterns + builtins.filter { p in !recentGrepPatterns.contains(p) }
            let filtered = grepQuery.isEmpty ? allPatterns : allPatterns.filter { $0.lowercased().contains(grepQuery) }
            return Array(filtered.prefix(8)).map { pattern in
                let isRecent = recentGrepPatterns.contains(pattern)
                return ("magnifyingglass", pattern, "grep:\(pattern)", isRecent ? "recent" : nil)
            }
        }

        // Default: show mention types with live badges
        var items: [(String, String, String, String?)] = []

        let buildBadge: String? = {
            guard let ctx = trinityContext else { return nil }
            if let ok = ctx.buildOK { return ok ? "OK" : "FAIL" }
            return nil
        }()

        let issuesBadge: String? = {
            guard let ctx = trinityContext, let n = ctx.openIssues else { return nil }
            return "\(n) open"
        }()

        let farmBadge: String? = {
            guard let ctx = trinityContext else { return nil }
            var parts: [String] = []
            if let n = ctx.farmServices { parts.append("\(n) active") }
            if let ppl = ctx.bestPPL { parts.append("PPL=\(String(format: "%.1f", ppl))") }
            return parts.isEmpty ? nil : parts.joined(separator: ", ")
        }()

        let types: [(String, String, String, String?)] = [
            ("doc.text", "file:", "@file:path — attach file content", nil),
            ("magnifyingglass", "grep:", "@grep:query — search codebase", nil),
            ("terminal", "tri:", "@tri:command — run tri command", nil),
            ("hammer", "build", "@build — last build output", buildBadge),
            ("chart.bar", "farm", "@farm — farm events snapshot", farmBadge),
            ("list.bullet", "issues", "@issues — open GitHub issues", issuesBadge),
            ("arrow.triangle.branch", "gitdiff", "@gitdiff — current HEAD diff", nil),
        ]

        for (icon, prefix, desc, badge) in types {
            if q.isEmpty || prefix.contains(q) || desc.lowercased().contains(q) {
                items.append((icon, desc, prefix, badge))
            }
        }

        // If typing something that looks like a path (has / or .), show file suggestions too
        if !q.isEmpty && !q.hasPrefix("file:") && !q.hasPrefix("grep:") && (q.contains("/") || q.contains(".")) {
            let suggestions = repoContext?.fileSuggestions(matching: q, limit: 4) ?? []
            for path in suggestions {
                items.append(("doc.text", path, "file:\(path)", nil))
            }
        }

        return Array(items.prefix(8))
    }

    var body: some View {
        let items = completions
        if !items.isEmpty {
            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { idx, item in
                    Button {
                        onSelect(item.value)
                        isPresented = false
                    } label: {
                        HStack(spacing: 8) {
                            Image(systemName: item.icon)
                                .font(.system(size: 11))
                                .foregroundStyle(TrinityTheme.accent)
                                .frame(width: 16)
                            Text(item.label)
                                .font(.system(size: 12))
                                .foregroundStyle(Color.white.opacity(0.8))
                                .lineLimit(1)
                            Spacer()
                            if let badge = item.badge {
                                Text(badge)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(badge == "FAIL" ? Color.red : TrinityTheme.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(0.06))
                                    .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                        .background(idx == selectedIndex ? Color.white.opacity(0.08) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(width: 340)
            .background(Color(hex: 0x1A1A1A))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.4), radius: 12)
            .onKeyPress(.upArrow) {
                selectedIndex = max(0, selectedIndex - 1)
                return .handled
            }
            .onKeyPress(.downArrow) {
                selectedIndex = min(items.count - 1, selectedIndex + 1)
                return .handled
            }
            .onKeyPress(.return) {
                if selectedIndex < items.count {
                    onSelect(items[selectedIndex].value)
                    isPresented = false
                }
                return .handled
            }
            .onKeyPress(.escape) {
                isPresented = false
                return .handled
            }
            .onChange(of: query) { _, _ in
                selectedIndex = 0
            }
        }
    }
}

// MARK: - Sources Panel (Perplexity-style citations)

struct SourcesPanel: View {
    let citations: [Citation]
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "link")
                        .font(.system(size: 11))
                    Text("Sources (\(citations.count))")
                        .font(.system(size: 12, weight: .medium))
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 9))
                    Spacer()
                }
                .foregroundStyle(TrinityTheme.accent)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(Array(citations.prefix(6).enumerated()), id: \.element.id) { idx, citation in
                        HStack(spacing: 8) {
                            Text("\(idx + 1)")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundStyle(TrinityTheme.accent)
                                .frame(width: 16)

                            VStack(alignment: .leading, spacing: 1) {
                                if let domain = citation.domain {
                                    Text(domain)
                                        .font(.system(size: 11, weight: .medium))
                                        .foregroundStyle(Color.white.opacity(0.7))
                                }
                                Text(citation.url)
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.3))
                                    .lineLimit(1)
                                    .truncationMode(.middle)
                            }

                            Spacer()

                            Button {
                                if let url = URL(string: citation.url) {
                                    NSWorkspace.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "arrow.up.right.square")
                                    .font(.system(size: 10))
                                    .foregroundStyle(Color.white.opacity(0.3))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 4)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(TrinityTheme.accent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(TrinityTheme.accent.opacity(0.15), lineWidth: 1)
        )
    }
}

// MARK: - Branch Navigator (ChatGPT-style < 1/2 > arrows)

struct BranchNavigator: View {
    let message: ChatMessage
    @ObservedObject var store: ThreadStore
    let threadID: UUID

    private var branchCount: Int {
        store.branchCount(for: message.id, in: threadID)
    }

    private var currentIndex: Int {
        message.branchIndex ?? 0
    }

    var body: some View {
        if message.branchID != nil && branchCount > 1 {
            HStack(spacing: 4) {
                Button {
                    let prev = max(currentIndex - 1, 0)
                    store.switchBranch(message.id, toIndex: prev, in: threadID)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(currentIndex > 0 ? Color.white.opacity(0.6) : Color.white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(currentIndex <= 0)

                Text("\(currentIndex + 1)/\(branchCount)")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))

                Button {
                    let next = min(currentIndex + 1, branchCount - 1)
                    store.switchBranch(message.id, toIndex: next, in: threadID)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(currentIndex < branchCount - 1 ? Color.white.opacity(0.6) : Color.white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(currentIndex >= branchCount - 1)
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(0.06))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Thinking Block View (Feature 1)

struct ThinkingBlockView: View {
    let text: String
    @State private var isExpanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            ScrollView {
                Text(text)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.6))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(maxHeight: 200)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "brain")
                    .font(.system(size: 11))
                Text("Reasoning")
                    .font(.system(size: 12, weight: .medium))
                Text("(\(text.count) chars)")
                    .font(.system(size: 10))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .foregroundStyle(Color.white.opacity(0.5))
        }
        .padding(8)
        .background(Color.white.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }
}

// MARK: - Stale Data Badge (Feature 2)

struct StaleBadge: View {
    let message: ChatMessage
    @ObservedObject var store: ThreadStore
    @ObservedObject var client: ChatClient
    @ObservedObject var modelManager: ModelManager

    private var isStale: Bool {
        let age = Date().timeIntervalSince(message.timestamp)
        guard age > 3600 else { return false }  // 1 hour
        let keywords = ["PPL", "build", "farm", "Railway", "deploy", "service", "arena", "status", "running", "training"]
        return keywords.contains(where: { message.text.localizedCaseInsensitiveContains($0) })
    }

    var body: some View {
        if isStale {
            HStack(spacing: 6) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(.system(size: 10))
                Text("Stale data")
                    .font(.system(size: 10, weight: .medium))

                Button {
                    guard let threadID = store.activeThreadID else { return }
                    client.regenerate(threadID: threadID, store: store, modelManager: modelManager)
                } label: {
                    Text("Re-ask")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(TrinityTheme.statusWarn)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(TrinityTheme.statusWarn)
            .padding(.top, 4)
        }
    }
}

// MARK: - Build Error Banner (Feature 4)

struct BuildErrorBanner: View {
    var onFix: (String) -> Void
    @StateObject private var ctx = TrinityContext.shared

    var body: some View {
        if ctx.buildOK == false {
            HStack(spacing: 10) {
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.statusError)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Build is broken")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TrinityTheme.statusError)
                    if let summary = ctx.buildErrorSummary() {
                        Text(String(summary.prefix(100)))
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button {
                    let error = ctx.buildErrorSummary() ?? "Build is broken"
                    let prompt = "The build is broken. Fix this error:\n\n```\n\(error)\n```"
                    onFix(prompt)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "wrench.fill")
                            .font(.system(size: 10))
                        Text("Fix this?")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(TrinityTheme.statusError)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(TrinityTheme.statusError.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(TrinityTheme.statusError.opacity(0.3), lineWidth: 1)
            )
            .padding(.horizontal, 60)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Memory Proposal Card (Feature 8)

struct MemoryProposalCard: View {
    let memories: [MemoryEntry]
    var onAccept: (MemoryEntry) -> Void
    var onDismiss: (MemoryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 11))
                Text("Remember this?")
                    .font(.system(size: 11, weight: .bold))
            }
            .foregroundStyle(TrinityTheme.purple)

            ForEach(memories) { entry in
                HStack(spacing: 8) {
                    Text(String(entry.text.prefix(80)))
                        .font(.system(size: 11))
                        .foregroundStyle(Color.white.opacity(0.7))
                        .lineLimit(2)

                    Spacer()

                    Button {
                        onAccept(entry)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(TrinityTheme.statusOK)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDismiss(entry)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
        .padding(10)
        .background(TrinityTheme.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(TrinityTheme.purple.opacity(0.2), lineWidth: 1)
        )
        .transition(.opacity.combined(with: .move(edge: .bottom)))
    }
}

// MARK: - Streaming Elapsed Timer (Feature W6-1)

struct StreamingElapsedTimer: View {
    @State private var elapsed: Int = 0

    var body: some View {
        Text("\(elapsed)s")
            .font(.system(size: 10, weight: .medium, design: .monospaced))
            .foregroundStyle(elapsed > 10 ? TrinityTheme.statusWarn : TrinityTheme.textMuted)
            .task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(1))
                    elapsed += 1
                }
            }
    }
}

// MARK: - In-Thread Search Bar (Cmd+F)

struct InThreadSearchBar: View {
    @Binding var query: String
    @Binding var currentIndex: Int
    let totalMatches: Int
    var onDismiss: () -> Void
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.4))

            TextField("Find in thread...", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .foregroundStyle(Color.white)
                .focused($isFocused)
                .onSubmit { if currentIndex < totalMatches - 1 { currentIndex += 1 } }

            if !query.isEmpty {
                Text("\(totalMatches > 0 ? currentIndex + 1 : 0)/\(totalMatches)")
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(totalMatches > 0 ? TrinityTheme.accent : TrinityTheme.statusError)
                    .fixedSize()

                Button {
                    if currentIndex > 0 { currentIndex -= 1 }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(currentIndex > 0 ? Color.white : Color.white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(currentIndex <= 0)

                Button {
                    if currentIndex < totalMatches - 1 { currentIndex += 1 }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(currentIndex < totalMatches - 1 ? Color.white : Color.white.opacity(0.2))
                }
                .buttonStyle(.plain)
                .disabled(currentIndex >= totalMatches - 1)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(hex: 0x1A1A1A))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 60)
        .padding(.vertical, 4)
        .onAppear { isFocused = true }
        .onChange(of: query) { _, _ in currentIndex = 0 }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }
}

// MARK: - Live TTFB Counter (counts up while waiting for first token)

struct LiveTTFBCounter: View {
    let isWaiting: Bool
    @State private var elapsedMs: Int = 0

    private var color: Color {
        if elapsedMs < 2000 { return TrinityTheme.textMuted }
        if elapsedMs < 5000 { return TrinityTheme.statusWarn }
        return TrinityTheme.statusError
    }

    var body: some View {
        if isWaiting {
            HStack(spacing: 3) {
                Circle()
                    .fill(color)
                    .frame(width: 5, height: 5)
                Text(elapsedMs < 1000 ? "\(elapsedMs)ms" : String(format: "%.1fs", Double(elapsedMs) / 1000.0))
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(color)
            }
            .task {
                let start = Date()
                while !Task.isCancelled {
                    try? await Task.sleep(for: .milliseconds(100))
                    elapsedMs = Int(Date().timeIntervalSince(start) * 1000)
                }
            }
        }
    }
}

// MARK: - Network Dashboard (Feature W6-2)

struct NetworkDashboard: View {
    @ObservedObject var client: ChatClient
    @ObservedObject var modelManager: ModelManager
    @StateObject private var networkLog = NetworkLog.shared
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "network")
                        .font(.system(size: 10))
                    Text("Network")
                        .font(.system(size: 11, weight: .bold))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8))
                }
                .foregroundStyle(Color.white.opacity(0.6))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        providerRows
                        failoverHistory
                        offlineQueueSection
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
                }
            }
        }
        .background(Color.black)
    }

    @ViewBuilder
    private var providerRows: some View {
        ForEach(Array(networkLog.providerHealth.values).sorted(by: { $0.name < $1.name }), id: \.name) { status in
            let stats = networkLog.providerStats(status.name)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Circle()
                        .fill(status.isUp ? TrinityTheme.statusOK : TrinityTheme.statusError)
                        .frame(width: 5, height: 5)
                    Text(status.name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.7))
                    Spacer()
                    if let remaining = status.remainingRequests {
                        Text("\(remaining) left")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(remaining < 10 ? TrinityTheme.statusError : TrinityTheme.textMuted)
                    }
                    // Quick switch button if not current provider
                    if status.isUp && modelManager.selectedModel.provider.rawValue != status.name {
                        Button {
                            if let model = modelManager.availableModels.first(where: { $0.provider.rawValue == status.name && !$0.isImageModel }) {
                                modelManager.selectedModel = model
                                modelManager.persistSelection()
                            }
                        } label: {
                            Text("Use")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(TrinityTheme.accent)
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(spacing: 8) {
                    Text("\(stats.requests) req")
                        .font(.system(size: 8, design: .monospaced))
                    if stats.errors > 0 {
                        Text("\(stats.errors) err")
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(TrinityTheme.statusError)
                    }
                    if stats.avgTTFB > 0 {
                        Text("\(stats.avgTTFB)ms")
                            .font(.system(size: 8, design: .monospaced))
                    }
                    if stats.avgTPS > 0 {
                        Text(String(format: "%.0f t/s", stats.avgTPS))
                            .font(.system(size: 8, design: .monospaced))
                            .foregroundStyle(TrinityTheme.accent)
                    }
                }
                .foregroundStyle(TrinityTheme.textMuted)

                // TTFB sparkline
                let ttfbs = networkLog.recentTTFBForProvider(status.name, count: 10)
                if ttfbs.count >= 2 {
                    TTFBSparkline(values: ttfbs)
                        .frame(height: 16)
                }
            }
            .padding(.vertical, 4)
        }
    }

    @ViewBuilder
    private var failoverHistory: some View {
        if !client.failoverLog.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("Failover Log")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(Color.white.opacity(0.4))
                ForEach(Array(client.failoverLog.suffix(5).reversed().enumerated()), id: \.offset) { _, event in
                    HStack(spacing: 4) {
                        Text(event.from)
                            .foregroundStyle(TrinityTheme.statusError)
                        Image(systemName: "arrow.right")
                            .font(.system(size: 6))
                        Text(event.to)
                            .foregroundStyle(TrinityTheme.statusOK)
                        Spacer()
                        Text(event.timestamp, style: .time)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .font(.system(size: 8, design: .monospaced))
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var offlineQueueSection: some View {
        if !client.offlineQueue.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("Offline Queue (\(client.offlineQueue.count))")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(TrinityTheme.statusWarn)
                ForEach(client.offlineQueue) { queued in
                    HStack(spacing: 4) {
                        Text(String(queued.text.prefix(30)))
                            .font(.system(size: 8))
                            .foregroundStyle(Color.white.opacity(0.5))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            client.cancelQueued(queued.id)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 9))
                                .foregroundStyle(TrinityTheme.statusError)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.top, 4)
        }
    }
}

// MARK: - TTFB Sparkline (mini chart)

struct TTFBSparkline: View {
    let values: [Int]

    var body: some View {
        GeometryReader { geo in
            let maxVal = Double(values.max() ?? 1)
            let minVal = Double(values.min() ?? 0)
            let range = max(maxVal - minVal, 1)
            let w = geo.size.width / CGFloat(max(values.count - 1, 1))

            Path { path in
                for (i, val) in values.enumerated() {
                    let x = CGFloat(i) * w
                    let y = geo.size.height * (1 - CGFloat(Double(val) - minVal) / CGFloat(range))
                    if i == 0 {
                        path.move(to: CGPoint(x: x, y: y))
                    } else {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
            }
            .stroke(TrinityTheme.accent.opacity(0.6), lineWidth: 1)
        }
    }
}

// MARK: - Context Overflow Banner (Feature W6-3)

struct ContextOverflowBanner: View {
    let tokens: Int
    var onSummarize: () -> Void
    var onNewThread: () -> Void

    private var percentage: Int {
        min(Int(Double(tokens) / 180_000 * 100), 100)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.golden)

            VStack(alignment: .leading, spacing: 1) {
                Text("Context \(percentage)% full")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TrinityTheme.golden)
                Text("\(tokens / 1000)K / 180K tokens")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
            }

            Spacer()

            Button {
                onSummarize()
            } label: {
                Text("Summarize")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(TrinityTheme.golden)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                onNewThread()
            } label: {
                Text("New thread")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(TrinityTheme.accent)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.white.opacity(0.08))
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(10)
        .background(TrinityTheme.golden.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(TrinityTheme.golden.opacity(0.3), lineWidth: 1)
        )
        .padding(.horizontal, 60)
        .padding(.bottom, 6)
    }
}

// MARK: - Rate Limit Warning (Feature W6-5)

struct RateLimitWarning: View {
    @ObservedObject var modelManager: ModelManager
    @StateObject private var networkLog = NetworkLog.shared

    private var warning: (provider: String, remaining: Int)? {
        let provider = modelManager.selectedModel.provider.rawValue
        let (low, remaining) = networkLog.isRateLimitLow(provider)
        guard low, let r = remaining else { return nil }
        return (provider, r)
    }

    var body: some View {
        if let w = warning {
            HStack(spacing: 6) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(.system(size: 10))
                Text("\(w.provider): \(w.remaining) requests left")
                    .font(.system(size: 10, weight: .medium))

                if let eta = networkLog.rateLimitETA(w.provider) {
                    Text("(~\(eta) min)")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(eta < 5 ? TrinityTheme.statusError : TrinityTheme.statusWarn)
                }

                if let fallback = modelManager.failoverModel() {
                    Button {
                        modelManager.selectedModel = fallback
                        modelManager.persistSelection()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 8))
                            Text("Switch to \(fallback.displayName)")
                                .font(.system(size: 9, weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(TrinityTheme.statusWarn)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .foregroundStyle(TrinityTheme.statusWarn)
            .padding(.horizontal, 16)
            .padding(.vertical, 4)
            .background(TrinityTheme.statusWarn.opacity(0.06))
        }
    }
}

// MARK: - Branch Pill (shows current git branch)

struct BranchPill: View {
    @State private var branch: String = ""

    var body: some View {
        Group {
            if !branch.isEmpty && branch != "main" {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(.system(size: 8))
                    Text(branch)
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(TrinityTheme.purple)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(TrinityTheme.purple.opacity(0.1))
                .clipShape(Capsule())
                .padding(.horizontal, 16)
                .padding(.vertical, 2)
            }
        }
        .onAppear {
            Task { @MainActor in
                let repo = RepoContext()
                branch = repo.currentBranch()
            }
        }
    }
}

// MARK: - Follow-up Suggestions (after response)

struct FollowUpSuggestions: View {
    let suggestions: [String]
    var onSelect: (String) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(.system(size: 9))
                            Text(suggestion)
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(Color.white.opacity(0.7))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(0.06))
                        .clipShape(Capsule())
                        .overlay(
                            Capsule()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rejection Feedback (tell Queen what to do instead)

struct RejectionFeedbackView: View {
    @State private var feedback = ""
    @FocusState private var isFocused: Bool
    var onSubmit: (String) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(TrinityTheme.statusError)
                Text("Tell Queen what to do instead:")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 8) {
                TextField("e.g. Be more concise, use code examples...", text: $feedback)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white)
                    .padding(8)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .focused($isFocused)
                    .onSubmit {
                        guard !feedback.isEmpty else { return }
                        onSubmit(feedback)
                    }

                Button {
                    guard !feedback.isEmpty else { return }
                    onSubmit(feedback)
                } label: {
                    Text("Resend")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(TrinityTheme.statusError)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(TrinityTheme.statusError.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 60)
        .onAppear { isFocused = true }
    }
}

// MARK: - Spinner Verb (dynamic loading text)

struct SpinnerVerb: View {
    @State private var verbIndex = 0
    private let verbs = [
        "Thinking...",
        "Analyzing context...",
        "Crafting response...",
        "Reading project state...",
        "Considering options...",
        "Preparing answer...",
    ]

    var body: some View {
        Text(verbs[verbIndex % verbs.count])
            .onAppear {
                Task { @MainActor in
                    while !Task.isCancelled {
                        try? await Task.sleep(for: .seconds(2.5))
                        verbIndex += 1
                    }
                }
            }
    }
}

// MARK: - Tool Execution Timeline

struct ToolTimeline: View {
    let steps: [ChatClient.ToolCallStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(steps) { step in
                HStack(spacing: 8) {
                    // Status icon
                    Group {
                        switch step.status {
                        case .running:
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: 12, height: 12)
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(TrinityTheme.statusOK)
                        case .error:
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 11))
                                .foregroundStyle(TrinityTheme.statusError)
                        }
                    }
                    .frame(width: 14)

                    // Tool name
                    Text(step.name)
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(TrinityTheme.accent)

                    // Args
                    Text(step.args)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(TrinityTheme.textMuted)
                        .lineLimit(1)

                    Spacer()

                    // Duration
                    let elapsed = Date().timeIntervalSince(step.startTime)
                    if elapsed > 0.5 {
                        Text(String(format: "%.1fs", elapsed))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }
            }
        }
        .padding(8)
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.vertical, 4)
    }
}

// MARK: - Offline Queue Banner

struct OfflineQueueBanner: View {
    let count: Int
    var onCancelAll: () -> Void
    var queue: [ChatClient.QueuedMessage] = []
    var onCancelOne: ((UUID) -> Void)? = nil
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Image(systemName: "wifi.slash")
                    .font(.system(size: 12))
                    .foregroundStyle(TrinityTheme.statusWarn)
                Text("\(count) message\(count == 1 ? "" : "s") queued")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TrinityTheme.statusWarn)
                Text("Retrying every 15s...")
                    .font(.system(size: 10))
                    .foregroundStyle(TrinityTheme.textMuted)
                Spacer()
                if count > 1 {
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9))
                            .foregroundStyle(Color.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    onCancelAll()
                } label: {
                    Text("Cancel All")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(TrinityTheme.statusError)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(TrinityTheme.statusError.opacity(0.12))
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }

            // Per-message queue detail
            if isExpanded {
                ForEach(queue) { msg in
                    HStack(spacing: 6) {
                        Image(systemName: "clock")
                            .font(.system(size: 9))
                            .foregroundStyle(TrinityTheme.statusWarn)
                        Text(String(msg.text.prefix(60)))
                            .font(.system(size: 10))
                            .foregroundStyle(Color.white.opacity(0.6))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            onCancelOne?(msg.id)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 10))
                                .foregroundStyle(TrinityTheme.statusError.opacity(0.6))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(TrinityTheme.statusWarn.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 60)
    }
}

// MARK: - Elicitation Card (Queen asks structured questions)

struct ElicitationCard: View {
    let question: String
    let options: [String]
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: "questionmark.circle.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.purple)
                Text(question)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)
            }

            HStack(spacing: 8) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        Text(option)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.8))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(TrinityTheme.purple.opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(TrinityTheme.purple.opacity(0.3), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(12)
        .background(TrinityTheme.purple.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Thinking Transcript Sheet (Cmd+O)

struct ThinkingTranscriptSheet: View {
    let messages: [ChatMessage]
    @Environment(\.dismiss) private var dismiss

    private var thinkingEntries: [(model: String, thinking: String, response: String)] {
        messages.filter { $0.role == .assistant && $0.thinkingText != nil }.map { msg in
            (
                model: msg.modelID ?? "unknown",
                thinking: msg.thinkingText ?? "",
                response: String(msg.text.prefix(200))
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "brain")
                    .font(.system(size: 16))
                    .foregroundStyle(TrinityTheme.purple)
                Text("Thinking Transcript")
                    .font(.headline)
                    .foregroundStyle(TrinityTheme.textPrimary)
                Spacer()
                Button {
                    // Copy all thinking to clipboard
                    let all = thinkingEntries.map { "[\($0.model)]\n\($0.thinking)" }.joined(separator: "\n\n---\n\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(all, forType: NSPasteboard.PasteboardType.string)
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy All")
                    }
                    .font(.system(size: 12))
                    .foregroundStyle(TrinityTheme.accent)
                }
                .buttonStyle(.plain)
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }
            .padding()

            if thinkingEntries.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 32))
                        .foregroundStyle(Color.white.opacity(0.2))
                    Text("No thinking data in this thread")
                        .font(.system(size: 14))
                        .foregroundStyle(TrinityTheme.textMuted)
                    Text("Use Reason mode or High/Max effort to enable extended thinking")
                        .font(.system(size: 12))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 16) {
                        ForEach(Array(thinkingEntries.enumerated()), id: \.offset) { idx, entry in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text("Turn \(idx + 1)")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(TrinityTheme.purple)
                                    Text(entry.model)
                                        .font(.system(size: 10, design: .monospaced))
                                        .foregroundStyle(TrinityTheme.textMuted)
                                    Spacer()
                                    Text("\(entry.thinking.count) chars")
                                        .font(.system(size: 9, design: .monospaced))
                                        .foregroundStyle(Color.white.opacity(0.3))
                                }

                                Text(entry.thinking)
                                    .font(.system(size: 12, design: .monospaced))
                                    .foregroundStyle(Color.white.opacity(0.7))
                                    .textSelection(.enabled)
                                    .padding(8)
                                    .background(Color.white.opacity(0.03))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                // Response preview
                                Text(entry.response + (entry.response.count >= 200 ? "..." : ""))
                                    .font(.system(size: 11))
                                    .foregroundStyle(Color.white.opacity(0.4))
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(TrinityTheme.bgWindow)
    }
}

// MARK: - Onboarding Walkthrough (4-step)

struct OnboardingWalkthrough: View {
    @Binding var isPresented: Bool
    @State private var step = 0

    private let steps: [(icon: String, title: String, body: String)] = [
        ("crown.fill", "Welcome to Queen",
         "Your personal CTO for the Trinity project. Queen has full access to your repo, build status, training farm, and arena."),
        ("at", "Use @mentions",
         "Type @ in the input to attach context: @file:path, @grep:query, @build, @farm, @issues, @gitdiff. Queen reads them automatically."),
        ("keyboard", "Slash Commands",
         "Type / for quick actions: /effort, /model, /compact, /cost, /fast, /branch, /help. Or press Cmd+K for the command palette."),
        ("gauge.with.dots.needle.33percent", "Control Quality",
         "Use the Effort picker (Low/Med/High/Max) to control response depth. Use Style presets for tone. Long-press Send to pick a specific model."),
    ]

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Step indicator
            HStack(spacing: 8) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Circle()
                        .fill(i == step ? TrinityTheme.accent : Color.white.opacity(0.15))
                        .frame(width: 8, height: 8)
                }
            }

            // Content
            let current = steps[step]
            Image(systemName: current.icon)
                .font(.system(size: 48))
                .foregroundStyle(step == 0 ? TrinityTheme.golden : TrinityTheme.accent)

            Text(current.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(current.body)
                .font(.system(size: 15))
                .foregroundStyle(Color.white.opacity(0.6))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Spacer()

            // Navigation
            HStack(spacing: 16) {
                if step > 0 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Text("Back")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.white.opacity(0.5))
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                Button {
                    if step < steps.count - 1 {
                        withAnimation { step += 1 }
                    } else {
                        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                        isPresented = false
                    }
                } label: {
                    Text(step < steps.count - 1 ? "Next" : "Get Started")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.black)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(TrinityTheme.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 40)
            .padding(.bottom, 30)

            // Skip
            Button {
                UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                isPresented = false
            } label: {
                Text("Skip")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.white.opacity(0.3))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(TrinityTheme.bgWindow)
    }
}

// MARK: - Task Tracker

struct TaskItem: Identifiable {
    let id = UUID()
    var title: String
    var isDone: Bool = false
}

struct TaskTrackerView: View {
    @Binding var tasks: [TaskItem]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "checklist")
                    .font(.system(size: 11))
                    .foregroundStyle(TrinityTheme.accent)
                Text("Tasks")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(TrinityTheme.accent)
                let done = tasks.filter(\.isDone).count
                Text("\(done)/\(tasks.count)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(TrinityTheme.textMuted)
                Spacer()
                Button {
                    tasks.removeAll()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 9))
                        .foregroundStyle(Color.white.opacity(0.3))
                }
                .buttonStyle(.plain)
            }

            ForEach(tasks.indices, id: \.self) { idx in
                HStack(spacing: 6) {
                    Button {
                        tasks[idx].isDone.toggle()
                    } label: {
                        Image(systemName: tasks[idx].isDone ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 12))
                            .foregroundStyle(tasks[idx].isDone ? TrinityTheme.statusOK : Color.white.opacity(0.3))
                    }
                    .buttonStyle(.plain)

                    Text(tasks[idx].title)
                        .font(.system(size: 11))
                        .foregroundStyle(tasks[idx].isDone ? TrinityTheme.textMuted : TrinityTheme.textPrimary)
                        .strikethrough(tasks[idx].isDone)
                }
            }

            // Progress bar
            let progress = tasks.isEmpty ? 0.0 : Double(tasks.filter(\.isDone).count) / Double(tasks.count)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.06))
                    Capsule()
                        .fill(progress >= 1.0 ? TrinityTheme.statusOK : TrinityTheme.accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: 3)
            .padding(.top, 4)
        }
        .padding(10)
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - @Mention Chips (visual inline chips)

struct MentionChip: View {
    let type: String  // "file", "grep", "build", etc.
    let value: String

    private var icon: String {
        switch type {
        case "file": return "doc.text"
        case "grep": return "magnifyingglass"
        case "build": return "hammer"
        case "farm": return "chart.bar"
        case "issues": return "list.bullet"
        case "gitdiff": return "arrow.triangle.branch"
        default: return "at"
        }
    }

    private var color: Color {
        switch type {
        case "file": return TrinityTheme.accent
        case "grep": return TrinityTheme.purple
        case "build": return TrinityTheme.statusError
        case "farm": return TrinityTheme.golden
        default: return TrinityTheme.accent
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.system(size: 9))
            Text(value)
                .font(.system(size: 10, weight: .medium))
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(Capsule())
    }
}

// MARK: - Agent Status Indicator (3 states)

struct AgentStatusIndicator: View {
    enum AgentState {
        case active, done, pending
    }

    let name: String
    let state: AgentState

    private var icon: String {
        switch state {
        case .active: return "circle.fill"
        case .done: return "checkmark.circle.fill"
        case .pending: return "clock"
        }
    }

    private var color: Color {
        switch state {
        case .active: return TrinityTheme.accent
        case .done: return TrinityTheme.statusOK
        case .pending: return TrinityTheme.textMuted
        }
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 8))
                .foregroundStyle(color)
            Text(name)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - MCP Status Indicator

struct MCPStatusView: View {
    @State private var servers: [(name: String, connected: Bool)] = []

    var body: some View {
        Group {
            if !servers.isEmpty {
                HStack(spacing: 8) {
                    ForEach(servers, id: \.name) { server in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(server.connected ? TrinityTheme.statusOK : Color.white.opacity(0.2))
                                .frame(width: 5, height: 5)
                            Text(server.name)
                                .font(.system(size: 9))
                                .foregroundStyle(server.connected ? TrinityTheme.textMuted : Color.white.opacity(0.2))
                        }
                    }
                }
            }
        }
        .onAppear {
            servers = Self.loadServers()
        }
    }

    /// Probe .mcp.json to determine which MCP servers are configured
    static func loadServers() -> [(name: String, connected: Bool)] {
        let cwd = FileManager.default.currentDirectoryPath
        let mcpPath = "\(cwd)/.mcp.json"
        let names = ["trinity", "needle", "zig-docs", "railway"]

        guard let data = try? Data(contentsOf: URL(fileURLWithPath: mcpPath)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let configured = json["mcpServers"] as? [String: Any] else {
            return names.map { ($0, false) }
        }

        return names.map { ($0, configured[$0] != nil) }
    }
}

// MARK: - Truncation Gradient Modifier

struct TruncationGradient: ViewModifier {
    let maxHeight: CGFloat

    func body(content: Content) -> some View {
        content
            .frame(maxHeight: maxHeight)
            .clipped()
            .overlay(alignment: .bottom) {
                LinearGradient(
                    colors: [Color.black.opacity(0), Color.black],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 30)
            }
    }
}

extension View {
    func truncationGradient(maxHeight: CGFloat = 200) -> some View {
        modifier(TruncationGradient(maxHeight: maxHeight))
    }
}
