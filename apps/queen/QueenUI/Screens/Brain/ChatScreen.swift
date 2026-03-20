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
    @State private var replyingTo: ChatMessage? = nil
    @State private var chatMode: ChatMode = .trinity
    @State private var attachedFiles: [(name: String, content: String)] = []
    @State private var isRecording = false
    @State private var pulseScale = 1.0
    @State private var showShortcuts = false
    @State private var isDropTargeted = false
    @State private var showScrollToBottom = false
    @State private var showComparison = false
    @State private var comparisonPrompt = ""
    @State private var showCommandPalette = false
    @State private var showMentionPopup = false
    @State private var mentionQuery = ""
    @State private var showSlashPopup = false
    @State private var slashQuery = ""
    @State private var showSidebar = true
    @State private var focusMode = false
    @State private var showModelPopover = false
    @State private var slashCommandResult: String? = nil
    @State private var showThinkingTranscript = false
    @State private var showOnboarding = false
    @State private var taskItems: [TaskItem] = []
    @State private var selectedPersona: Persona? = nil
    @State private var showPersonaLibrary = false
    @State private var showTemplatePicker = false
    @State private var historyIndex: Int = -1
    @State private var savedCurrentInput: String = ""
    @State private var lastSentText = ""
    @State private var showSentConfirmation = false
    @State private var showDraftSaved = false
    @State private var showQueueDrained = false
    @State private var queueDrainedMessageCount = 0
    @State private var rateLimitDismissed = false
    @State private var budgetWarningDismissed = false
    @State private var modelSuggestionDismissed = false
    @ObservedObject private var networkLog = NetworkLog.shared
    @State private var showThreadStats = false
    @State private var showInThreadSearch = false
    @State private var inThreadSearchQuery = ""
    @State private var inThreadSearchIndex = 0
    @State private var showShareCopied = false
    @State private var showSystemPrompt = false
    @State private var systemPromptDraft = ""
    @State private var hoveringTopBar = false
    @State private var showContextPreview = false
    @State private var requestInputFocus = false
    // Multi-select mode
    @State private var isSelecting = false
    @State private var selectedMessageIDs: Set<UUID> = []
    @State private var lastSelectedID: UUID? = nil
    /// Message ID that should be highlighted (flash animation when navigating from sidebar)
    @State private var highlightedMessageID: UUID? = nil
    /// Tracks message IDs present at initial thread load so we only animate new ones
    @State private var initialMessageIDs: Set<UUID> = []
    /// Set to true after initial thread load completes
    @State private var initialLoadDone = false
    /// Brief loading state when switching to a thread with many messages
    @State private var isLoadingThread = false
    // Voice input state
    @State private var speechRecognizer: SFSpeechRecognizer?
    @State private var audioEngine: AVAudioEngine?
    @State private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    @State private var recognitionTask: SFSpeechRecognitionTask?
    @State private var transcriptText = ""
    @AppStorage("stylePreset") private var stylePresetRaw: String = StylePreset.concise.rawValue
    @AppStorage("effortLevel") private var effortLevelRaw: String = EffortLevel.medium.rawValue
    @AppStorage("useCtrlEnterToSend") private var useCtrlEnterToSend = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var a11y: AccessibilityManager
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

    /// Subtle context pill: message count, duration, tokens (hover-only)
    private func conversationContextPill(for t: ChatThread) -> some View {
        let msgs = t.messages
        let count = msgs.count
        let tokens = msgs.compactMap(\.outputTokens).reduce(0, +)
        let duration: String = {
            guard let first = msgs.first?.timestamp, let last = msgs.last?.timestamp else { return "" }
            let secs = Int(last.timeIntervalSince(first))
            if secs < 60 { return "<1 min" }
            if secs < 3600 { return "\(secs / 60) min" }
            let h = secs / 3600; let m = (secs % 3600) / 60
            if h < 24 { return m > 0 ? "\(h)h \(m)min" : "\(h)h" }
            return "\(h / 24) days"
        }()
        let tokenStr = tokens >= 1000 ? String(format: "%.1fK", Double(tokens) / 1000.0) : "\(tokens)"
        return HStack(spacing: ParietalSpacing.xs) {
            Spacer()
            Text("\u{1F4AC} \(count) msgs")
            if !duration.isEmpty { Text("\u{00B7}"); Text(duration) }
            if tokens > 0 { Text("\u{00B7}"); Text("\(tokenStr) tokens") }
        }
        .font(WernickeTypography.size10)
        .foregroundStyle(V4Color.textSecondary.opacity(V1Theme.opacityTextTertiary))
        .padding(.horizontal, LayoutConstants.standardPadding)
        .padding(.vertical, 3)
    }

    /// Messages matching in-thread search
    private var inThreadSearchMatches: [ChatMessage] {
        guard !inThreadSearchQuery.isEmpty, let msgs = thread?.messages else { return [] }
        let q = inThreadSearchQuery.lowercased()
        return msgs.filter { $0.text.lowercased().contains(q) }
    }

    /// Determine search highlight state for a message
    private func searchHighlightFor(_ msg: ChatMessage) -> MessageRow.SearchHighlight {
        guard showInThreadSearch, !inThreadSearchQuery.isEmpty else { return .none }
        let matches = inThreadSearchMatches
        guard let idx = matches.firstIndex(where: { $0.id == msg.id }) else { return .none }
        return idx == inThreadSearchIndex ? .currentMatch : .match
    }

    /// Suggest a better model based on query complexity
    private var suggestedModel: (model: AIModel, reason: String)? {
        guard !input.isEmpty, !client.isStreaming, !modelSuggestionDismissed else { return nil }
        let lower = input.lowercased()
        let current = modelManager.selectedModel
        let codeKw = ["debug", "implement", "refactor", "fix bug", "write code", "function", "algorithm", "optimize"]
        let isCode = codeKw.contains(where: { lower.contains($0) })
        if isCode && current.displayName.lowercased().contains("haiku") {
            if let s = modelManager.availableModels.first(where: { $0.displayName.contains("Sonnet") }) {
                return (s, "better for code tasks")
            }
        }
        let deepKw = ["analyze", "compare", "architecture", "design", "evaluate", "trade-off", "tradeoff"]
        let isDeep = deepKw.contains(where: { lower.contains($0) })
        if isDeep && (current.displayName.lowercased().contains("haiku") || current.displayName.lowercased().contains("glm")) {
            if let s = modelManager.availableModels.first(where: { $0.displayName.contains("Sonnet") }) {
                return (s, "deep reasoning needed")
            }
        }
        let simpleKw = ["explain simply", "what is", "define", "translate", "hello", "hi ", "hey "]
        let isSimple = simpleKw.contains(where: { lower.contains($0) })
        if isSimple && !current.displayName.lowercased().contains("haiku") && !current.displayName.lowercased().contains("glm") {
            if let h = modelManager.availableModels.first(where: { $0.displayName.contains("Haiku") }) {
                return (h, "fast & cheap for simple queries")
            }
            if let g = modelManager.availableModels.first(where: { $0.displayName.contains("GLM") }) {
                return (g, "fast & cheap for simple queries")
            }
        }
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.count < 20 && !current.displayName.lowercased().contains("haiku")
            && !current.displayName.lowercased().contains("glm") && !isCode && !isDeep {
            if let h = modelManager.availableModels.first(where: { $0.displayName.contains("Haiku") }) {
                return (h, "10x cheaper for short queries")
            }
        }
        return nil
    }

    /// Token estimation: ~3.5 chars/token for English, ~2.5 for code/mixed
    private var estimatedTokens: Int {
        let msgs = thread?.messages ?? []
        let msgTokens = msgs.reduce(0) { total, msg in
            total + estimateTokens(msg.text)
        }
        let inputTokens = estimateTokens(input)
        // System prompt baseline: ~200 base instructions + ~500 CLAUDE.md + ~300 state/persona
        return msgTokens + inputTokens + 500
    }

    /// Improved token estimation: code-heavy text has more tokens per char
    private func estimateTokens(_ text: String) -> Int {
        guard !text.isEmpty else { return 0 }
        let hasCode = text.contains("```") || text.contains("    ")
        let ratio: Double = hasCode ? 3.2 : 3.8 // chars per token
        return Int(ceil(Double(text.count) / ratio))
    }

    /// Estimated cost of the next message in USD
    private var estimatedCostString: String? {
        let provider = modelManager.selectedModel.provider
        guard provider != .ollama else { return nil }
        let inputTokens = estimatedTokens
        let outputTokens = effortLevel.maxTokens
        let cost = AIModel.estimateCost(
            provider: provider.rawValue,
            inputTokens: inputTokens,
            outputTokens: outputTokens
        )
        if cost < 0.001 { return "<$0.01" }
        if cost < 0.10 { return String(format: "~$%.2f", cost) }
        return String(format: "~$%.1f", cost)
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
        bodyContent
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: showComparison)
            .background(Color.black)
            .onAppear { handleOnAppear() }
            .modifier(NotificationReceiversModifier(
                store: store,
                client: client,
                modelManager: modelManager,
                input: $input,
                showCommandPalette: $showCommandPalette,
                showSidebar: $showSidebar,
                focusMode: $focusMode,
                showInThreadSearch: $showInThreadSearch,
                inThreadSearchQuery: $inThreadSearchQuery,
                inThreadSearchIndex: $inThreadSearchIndex,
                showComparison: $showComparison,
                showPersonaLibrary: $showPersonaLibrary,
                showThinkingTranscript: $showThinkingTranscript,
                commentingMessage: $commentingMessage,
                slashCommandResult: $slashCommandResult,
                historyIndex: $historyIndex,
                savedCurrentInput: $savedCurrentInput,
                highlightedMessageID: $highlightedMessageID,
                requestInputFocus: $requestInputFocus,
                thread: thread
            ))
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
            .modifier(ChangeTrackersModifier(
                input: $input,
                showDraftSaved: $showDraftSaved,
                modelSuggestionDismissed: $modelSuggestionDismissed,
                taskItems: $taskItems,
                selectedPersona: $selectedPersona,
                initialMessageIDs: $initialMessageIDs,
                isLoadingThread: $isLoadingThread,
                store: store,
                client: client
            ))
            .onChange(of: requestInputFocus) { _, newValue in
                if newValue { focused = true }
            }
    }

    // MARK: - Body Content

    private var bodyContent: some View {
        HStack(spacing: 0) {
            if !focusMode { sidebarSection }
            mainChatArea
            if !focusMode { commentSidebarSection }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: commentingMessage != nil)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.3), value: focusMode)
        .overlay {
            if !focusMode { overlaysLayer }
        }
        .overlay(alignment: .topTrailing) {
            if focusMode {
                VStack {
                    HStack {
                        Spacer()
                        Button {
                            withAnimation(.easeInOut(duration: 0.3)) { focusMode = false }
                        } label: {
                            HStack(spacing: ParietalSpacing.xs) {
                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                    .font(WernickeTypography.miniSemibold)
                                Text("Exit Focus")
                                    .font(WernickeTypography.caption2MediumMono)
                            }
                            .foregroundStyle(.white.opacity(V1Theme.opacityTextSecondary))
                            .padding(.horizontal, ParietalSpacing.xs)
                            .padding(.vertical, 5)
                            .background(.white.opacity(0.08))
                            .clipShape(SwiftUI.Capsule())
                        }
                        .buttonStyle(.plain)
                        .padding(.top, 8)
                        .padding(.trailing, 12)
                    }
                    Spacer()
                }
                .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if showShareCopied {
                VStack {
                    Spacer()
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(WernickeTypography.size13)
                            .foregroundStyle(V4Color.statusOK)
                        Text("Conversation copied to clipboard")
                            .font(WernickeTypography.captionMedium)
                            .foregroundStyle(.white)
                    }
                    .padding(.horizontal, LayoutConstants.standardPadding)
                    .padding(.vertical, 10)
                    .background(V4Color.bgCard)
                    .clipShape(SwiftUI.Capsule())
                    .shadow(color: .black.opacity(V2Depth.stateHover), radius: 8, y: 4)
                    .padding(.bottom, 80)
                }
                .transition(.opacity.combined(with: .move(edge: .bottom)))
                .allowsHitTesting(false)
            }
        }
        .overlay(alignment: .bottom) {
            if isSelecting, !selectedMessageIDs.isEmpty {
                VStack {
                    Spacer()
                    MultiSelectActionBar(
                        selectedCount: selectedMessageIDs.count,
                        canCompareModels: canCompareSelectedModels(),
                        canDelete: canDeleteSelectedMessages(),
                        onCopyAll: copySelectedMessages,
                        onDeleteSelected: deleteSelectedMessages,
                        onQuoteSelected: quoteSelectedMessages,
                        onCompareModels: compareSelectedModels,
                        onSelectAll: selectAllMessages,
                        onDeselectAll: deselectAllMessages,
                        onCancel: exitSelectionMode
                    )
                    .padding(.bottom, 90)
                    .transition(.scale.combined(with: .opacity))
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.7), value: selectedMessageIDs.count)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .onKeyPress(phases: .down) { keyPress in
            if keyPress.key == .escape && isSelecting {
                exitSelectionMode()
                return .handled
            }
            // Cmd+A: Select all
            if keyPress.key == KeyEquivalent(Character("a")) && keyPress.modifiers.contains(.command) && !keyPress.modifiers.contains(.shift) {
                if isSelecting {
                    selectAllMessages()
                    return .handled
                }
            }
            // Cmd+Shift+A: Deselect all
            if keyPress.key == KeyEquivalent(Character("a")) && keyPress.modifiers.contains(.command) && keyPress.modifiers.contains(.shift) {
                if isSelecting {
                    deselectAllMessages()
                    return .handled
                }
            }
            return .ignored
        }
    }

    // MARK: - Main Chat Area

    private var mainChatArea: some View {
        ZStack(alignment: .bottomTrailing) {
            (focusMode ? Color(white: 0.04) : Color.black)

            VStack(spacing: 0) {
                if !focusMode {
                    // Connection status bar + conversation context pill (hover-only)
                    VStack(spacing: 0) {
                        ConnectionStatusBar(modelManager: modelManager, client: client)

                        if hoveringTopBar, let t = thread, !t.messages.isEmpty {
                            conversationContextPill(for: t)
                                .transition(.opacity)
                        }
                    }
                    .onHover { hovering in
                        withAnimation(.easeInOut(duration: 0.15)) { hoveringTopBar = hovering }
                    }

                    // Sticky context meter (always visible when >1K tokens)
                    ContextBar(tokens: estimatedTokens, onCompact: {
                        guard let tid = store.activeThreadID else { return }
                        client.checkAutoCompaction(threadID: tid, store: store, modelManager: modelManager)
                    })
                }

                // In-thread search bar (Cmd+F)
                inThreadSearchSection

                // Messages
                messageScrollArea

                Spacer(minLength: 0)

                // Smart suggestions (proactive actions based on Trinity state)
                if !focusMode, thread?.messages.isEmpty != false {
                    SmartSuggestionBar { prompt in
                        input = prompt
                        send()
                    }
                }

                mentionPopupSection

                stickyStreamingBar

                inputAreaContent
                if !focusMode {
                    rateLimitWarningBar
                    budgetWarningBar
                }
                replyPreviewBar
                inputBarView
                if !focusMode {
                    modelSuggestionView
                    modeBarView
                }
            }
        }
        .layoutPriority(1)
        // Drag & drop files onto chat area
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            handleFileDrop(providers)
            return true
        }
        .overlay {
            if isDropTargeted {
                ZStack {
                    RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                        .fill(V4Color.accent.opacity(0.05))
                    RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                        .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [8, 4]))
                        .foregroundStyle(V4Color.accent)
                    Text("Drop files here")
                        .font(WernickeTypography.body16Medium)
                        .foregroundStyle(V4Color.accent)
                }
                .allowsHitTesting(false)
            }
        }
    }

    // MARK: - In-Thread Search

    @ViewBuilder
    private var inThreadSearchSection: some View {
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
    }

    // MARK: - Message Scroll Area

    private var messageScrollArea: some View {
        ScrollViewReader { proxy in
            VStack(spacing: 0) {
                // Pinned messages strip
                if !focusMode, let threadID = store.activeThreadID {
                    let pinned = store.pinnedMessages(in: threadID)
                    if !pinned.isEmpty {
                        PinnedMessagesStrip(messages: pinned) { messageID in
                            withAnimation(.easeOut(duration: 0.2)) {
                                proxy.scrollTo(messageID, anchor: .center)
                            }
                        }
                    }
                }

                ScrollView {
                    messageListContent
                }
                .coordinateSpace(name: "chatScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { maxY in
                    showScrollToBottom = maxY > 200
                }
                .onChange(of: thread?.messages.count) {
                    let anim: Animation = reduceMotion
                        ? .easeOut(duration: 0.15)
                        : .spring(response: 0.35, dampingFraction: 0.8)
                    withAnimation(anim) {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: client.streamingText) {
                    if !showScrollToBottom {
                        proxy.scrollTo("bottom", anchor: .bottom)
                    }
                }
                .onChange(of: inThreadSearchIndex) { _, newIdx in
                    let matches = inThreadSearchMatches
                    if newIdx < matches.count {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(matches[newIdx].id, anchor: .center)
                        }
                    }
                }
                .overlay(alignment: .bottom) {
                    scrollToBottomButton(proxy: proxy)
                }
            }
        }
    }

    // MARK: - Message List Content

    private var messageListContent: some View {
        LazyVStack(alignment: .leading, spacing: 0) {
            // Thread-switching loading skeleton for large threads
            if isLoadingThread {
                VStack(spacing: ParietalSpacing.lg) {
                    ForEach(0..<4, id: \.self) { i in
                        ThreadLoadingSkeleton(isUser: i % 2 == 0)
                    }
                }
                .padding(.horizontal, ParietalSpacing.lg)
                .padding(.top, 20)
            }

            if thread?.messages.isEmpty != false {
                EmptyThreadView(chatMode: $chatMode, onSuggestion: { suggestion in
                    input = suggestion
                    send()
                }, onQuickInsert: { text in
                    input = text
                })
            }
            // MARK: Thread Stats Card
            if !focusMode, let t = thread, t.messages.count >= 4 {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    ThreadStatsCard(thread: t, isExpanded: $showThreadStats)
                    Button(action: shareConversation) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: a11y.scaledFontSize(11)))
                            .foregroundStyle(V4Color.textSecondary)
                            .padding(ParietalSpacing.xxs)
                            .background(V4Color.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                                    .stroke(a11y.highContrast ? V1Theme.HighContrast.borderDark : V4Color.bgCardBorder, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help("Share conversation to clipboard")
                    .accessibilityLabel("Share conversation")
                    .accessibilityHint("Double tap to copy conversation to clipboard")
                    .accessibilityIdentifier("chat.shareConversation")
                    Button {
                        let animation = a11y.isReduceMotionEnabled() ? nil : Animation.easeInOut(duration: 0.15)
                        withAnimation(animation) {
                            isSelecting.toggle()
                            if !isSelecting {
                                selectedMessageIDs.removeAll()
                                lastSelectedID = nil
                            }
                        }
                    } label: {
                        Image(systemName: isSelecting ? "checkmark.circle.fill" : "checkmark.circle")
                            .font(.system(size: a11y.scaledFontSize(11)))
                            .foregroundStyle(isSelecting ? (a11y.highContrast ? V4Color.HighContrast.accent : V4Color.accent) : V4Color.textSecondary)
                            .padding(ParietalSpacing.xxs)
                            .background(V4Color.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                            .overlay(
                                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                                    .stroke(isSelecting ? (a11y.highContrast ? V4Color.HighContrast.accent : V4Color.accent).opacity(V2Depth.stateDisabled) : V4Color.bgCardBorder, lineWidth: 0.5)
                            )
                    }
                    .buttonStyle(.plain)
                    .help(isSelecting ? "Exit selection mode" : "Select messages")
                    .accessibilityLabel(isSelecting ? "Exit selection mode" : "Select messages")
                    .accessibilityHint(isSelecting ? "Double tap to exit selection mode" : "Double tap to enter message selection mode")
                    .accessibilityIdentifier(isSelecting ? "chat.exitSelection" : "chat.selectMessages")
                }
                .padding(.bottom, 12)
            }

            ForEach(Array((thread?.messages ?? []).enumerated()), id: \.element.id) { index, msg in
                messageEntranceAnimation(for: msg, index: index)
            }

            errorRetryBlock

            continueButton

            streamingIndicatorView

            toolTimelineSection

            elicitationSection

            followUpSection

            Color.clear.frame(height: ParietalSpacing.dividerHeight).id("bottom")
        }
        .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
        .padding(.top, 20)
        .padding(.bottom, 100)
        .background(
            GeometryReader { geo in
                Color.clear
                    .preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("chatScroll")).maxY)
            }
        )
    }

    // MARK: - Tool Timeline

    @ViewBuilder
    private var toolTimelineSection: some View {
        if !client.activeToolCalls.isEmpty {
            ToolTimeline(steps: client.activeToolCalls)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - Elicitation Card

    @ViewBuilder
    private var elicitationSection: some View {
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
    }

    // MARK: - Follow-up Suggestions

    @ViewBuilder
    private var followUpSection: some View {
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
    }

    // MARK: - Continue Button (truncated response)

    @ViewBuilder
    private var continueButton: some View {
        if client.lastResponseTruncated && !client.isStreaming {
            Button {
                guard let threadID = store.activeThreadID else { return }
                client.lastResponseTruncated = false
                input = ""
                client.send(
                    "Please continue from where you left off.",
                    threadID: threadID,
                    store: store,
                    modelManager: modelManager,
                    mode: chatMode
                )
            } label: {
                HStack(spacing: ParietalSpacing.xs) {
                    Text("\u{21AA}")
                        .font(.system(size: a11y.scaledFontSize(13), weight: .bold))
                    Text("Continue")
                        .font(.system(size: a11y.scaledFontSize(12), weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, LayoutConstants.compactPadding)
                .background(a11y.highContrast ? V4Color.HighContrast.accent : V4Color.accent)
                .clipShape(SwiftUI.Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Continue generation")
            .accessibilityHint("Double tap to continue the truncated response")
            .accessibilityIdentifier("chat.continue")
            .transition(.opacity)
        }
    }

    // MARK: - Scroll To Bottom Button

    @ViewBuilder
    private func scrollToBottomButton(proxy: ScrollViewProxy) -> some View {
        if showScrollToBottom && !client.isStreaming {
            Button {
                let animation = a11y.isReduceMotionEnabled() ? nil : Animation.easeOut(duration: 0.3)
                withAnimation(animation) {
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            } label: {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "arrow.down")
                        .font(.system(size: a11y.scaledFontSize(13), weight: .semibold))
                    Text("New messages")
                        .font(.system(size: a11y.scaledFontSize(13), weight: .medium))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, LayoutConstants.standardPadding)
                .background(a11y.highContrast ? V4Color.HighContrast.accent : V4Color.accent)
                .clipShape(SwiftUI.Capsule())
                .shadow(color: .black.opacity(V1Theme.opacityTextTertiary), radius: V1Theme.shadowMediumRadius, y: 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Scroll to bottom, new messages")
            .accessibilityHint("Scrolls to the latest messages")
            .accessibilityIdentifier("chat.scrollToBottom")
            .padding(.bottom, 120)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
        }
    }

    // MARK: - OnAppear Handler

    private func handleOnAppear() {
        if store.threads.isEmpty { store.newThread() }
        focused = true
        if !UserDefaults.standard.bool(forKey: "onboardingCompleted") {
            showOnboarding = true
        }
        // Snapshot existing messages so we don't animate history on load
        if let msgs = thread?.messages {
            initialMessageIDs = Set(msgs.map(\.id))
        }
        initialLoadDone = true
        Task { @MainActor in
            NotificationService.shared.requestPermission()
            NetworkLog.shared.checkAllProviders()
            store.cleanupOldThreads()
            modelManager.refreshOllamaModels()
            client.loadPersistedQueue()
        }
        startHealthRefreshTimer()
    }

    // MARK: - Message Entrance Transition

    /// Returns a direction-aware pop-in transition for new messages only.
    /// History messages (present at load / thread switch) get identity transition.
    private func messageTransition(for msg: ChatMessage) -> AnyTransition {
        // Don't animate messages that were already present when thread loaded
        guard initialLoadDone, !initialMessageIDs.contains(msg.id) else {
            return .identity
        }
        if reduceMotion {
            return .opacity
        }
        let edge: Edge = msg.role == .user ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .opacity
        )
    }

    // MARK: - Message Entrance Animation Modifier

    /// Custom modifier that provides smooth spring-based entrance animations for messages
    /// with staggered delays when multiple messages appear simultaneously.
    struct MessageEntranceModifier: ViewModifier {
        let isNew: Bool
        let messageIndex: Int
        let baseIndex: Int
        let isUser: Bool
        let reduceMotion: Bool

        func body(content: Content) -> some View {
            if !isNew || reduceMotion {
                // No animation for existing messages or when reduce motion is enabled
                content
            } else {
                content
                    .scaleEffect(isAnimating ? 1.0 : MTMotion.entranceScale)
                    .opacity(isAnimating ? 1.0 : 0.0)
                    .offset(y: isAnimating ? 0 : (isUser ? 12 : -12))
                    .animation(staggeredSpringAnimation, value: isAnimating)
                    .onAppear {
                        // Stagger animation based on position from base
                        let stagger = Double(messageIndex - baseIndex) * MTMotion.messageStaggerDelay
                        let delay = max(0, stagger)
                        withAnimation(staggeredSpringAnimation.delay(delay)) {
                            isAnimating = true
                        }
                    }
            }
        }

        /// Staggered spring animation for cascade effect
        private var staggeredSpringAnimation: Animation {
            MTMotion.adaptiveStandardSpring()
        }

        @State private var isAnimating: Bool = false
    }

    /// Applies the entrance modifier with calculated parameters
    @ViewBuilder
    private func messageEntranceAnimation(for msg: ChatMessage, index: Int) -> some View {
        let isNew = initialLoadDone && !initialMessageIDs.contains(msg.id)
        let baseIndex = thread?.messages.firstIndex(where: { initialMessageIDs.contains($0.id) }) ?? 0
        MessageRow(
            message: msg,
            store: store,
            client: client,
            modelManager: modelManager,
            isLastMessage: msg.id == thread?.messages.last?.id,
            onComment: { commentingMessage = $0 },
            onReply: { replyingTo = $0; focused = true },
            searchHighlight: searchHighlightFor(msg),
            searchQuery: inThreadSearchQuery,
            isSelecting: isSelecting,
            isSelected: selectedMessageIDs.contains(msg.id),
            onToggleSelect: { shiftClick in
                toggleMessageSelection(msg.id, shiftClick: shiftClick)
            }
        )
        .modifier(MessageEntranceModifier(
            isNew: isNew,
            messageIndex: index,
            baseIndex: baseIndex,
            isUser: msg.role == .user,
            reduceMotion: reduceMotion
        ))
        .transition(exitTransition(for: msg))
    }

    /// Direction-aware exit transition based on message role
    private func exitTransition(for msg: ChatMessage) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        let edge: Edge = msg.role == .user ? .trailing : .leading
        return .asymmetric(
            insertion: .move(edge: edge).combined(with: .opacity).combined(with: .scale(scale: 0.95)),
            removal: .move(edge: edge).combined(with: .opacity).combined(with: .scale(scale: MTMotion.exitScale))
        )
    }

    // MARK: - Share Conversation

    private func shareConversation() {
        guard let thread = thread else { return }
        let text = Self.formatShareText(thread: thread)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        SoundCueManager.shared.playCopy()
        withAnimation(.easeInOut(duration: 0.2)) { showShareCopied = true }
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            withAnimation(.easeInOut(duration: 0.2)) { showShareCopied = false }
        }
    }

    // MARK: - Multi-Select

    private func toggleMessageSelection(_ id: UUID, shiftClick: Bool) {
        let messages = thread?.messages ?? []
        if shiftClick, let lastID = lastSelectedID,
           let lastIdx = messages.firstIndex(where: { $0.id == lastID }),
           let curIdx = messages.firstIndex(where: { $0.id == id }) {
            let range = lastIdx <= curIdx ? lastIdx...curIdx : curIdx...lastIdx
            for i in range {
                selectedMessageIDs.insert(messages[i].id)
            }
        } else {
            if selectedMessageIDs.contains(id) {
                selectedMessageIDs.remove(id)
            } else {
                selectedMessageIDs.insert(id)
            }
        }
        lastSelectedID = id
    }

    private func exitSelectionMode() {
        withAnimation(.easeInOut(duration: 0.15)) {
            isSelecting = false
            selectedMessageIDs.removeAll()
            lastSelectedID = nil
        }
    }

    private func copySelectedMessages() {
        let messages = thread?.messages ?? []
        let selected = messages.filter { selectedMessageIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let text = selected.map { msg in
            let role = msg.role == .user ? "You" : "Assistant"
            return "\(role): \(msg.text)"
        }.joined(separator: "\n\n")
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        SoundCueManager.shared.playCopy()
        exitSelectionMode()
    }

    private func exportSelectedAsMarkdown() {
        let messages = thread?.messages ?? []
        let selected = messages.filter { selectedMessageIDs.contains($0.id) }
        guard !selected.isEmpty else { return }
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        var md = "# Conversation Export\n\n"
        for msg in selected {
            let role = msg.role == .user ? "**You**" : "**Assistant**"
            let ts = dateFormatter.string(from: msg.timestamp)
            md += "### \(role) (\(ts))\n\n\(msg.text)\n\n---\n\n"
        }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(md, forType: .string)
        SoundCueManager.shared.playCopy()
        exitSelectionMode()
    }

    private func deleteSelectedMessages() {
        guard let thread = thread else { return }
        let messages = thread.messages
        let selected = messages.filter { selectedMessageIDs.contains($0.id) }
        guard !selected.isEmpty else { return }

        // Delete each selected message
        for msg in selected {
            store.deleteMessage(msg.id, in: thread.id)
        }
        SoundCueManager.shared.playCopy()  // playDelete doesn't exist, reuse playCopy for feedback
        exitSelectionMode()
    }

    private func quoteSelectedMessages() {
        let messages = thread?.messages ?? []
        let selected = messages.filter { selectedMessageIDs.contains($0.id) }
        guard !selected.isEmpty else { return }

        // Combine selected messages into a single quote block
        let quoteText = selected.map { msg in
            let role = msg.role == .user ? "You" : "Assistant"
            return "\(role): \(msg.text)"
        }.joined(separator: "\n\n")

        // Insert into input field as quote
        input = "> Combined quote from \(selected.count) message(s):\n\n\(quoteText)\n\n---\n\n"
        focused = true
        exitSelectionMode()
    }

    private func compareSelectedModels() {
        let messages = thread?.messages ?? []
        let selected = messages.filter { selectedMessageIDs.contains($0.id) }
        guard selected.count >= 2 else { return }

        // Get unique models from selected messages
        let models = Set(selected.compactMap { $0.modelID })
        guard models.count >= 2 else { return }

        // Create comparison prompt
        comparisonPrompt = "Compare these \(models.count) model responses:\n\n" +
            selected.enumerated().map { idx, msg in
                let modelName = msg.modelID ?? "Unknown"
                return "## Response \(idx + 1) (\(modelName)):\n\(msg.text)"
            }.joined(separator: "\n\n---\n\n")
        showComparison = true
        exitSelectionMode()
    }

    private func canCompareSelectedModels() -> Bool {
        let messages = thread?.messages ?? []
        let selected = messages.filter { selectedMessageIDs.contains($0.id) }
        guard selected.count >= 2 else { return false }
        let models = Set(selected.compactMap { $0.modelID })
        return models.count >= 2
    }

    private func canDeleteSelectedMessages() -> Bool {
        guard let thread = thread else { return false }
        let messages = thread.messages
        let selected = messages.filter { selectedMessageIDs.contains($0.id) }
        // Can't delete if all messages are selected (need at least one)
        return selected.count < messages.count
    }

    private func selectAllMessages() {
        guard let thread = thread else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedMessageIDs = Set(thread.messages.map { $0.id })
            lastSelectedID = thread.messages.last?.id
        }
    }

    private func deselectAllMessages() {
        withAnimation(.easeInOut(duration: 0.15)) {
            selectedMessageIDs.removeAll()
            lastSelectedID = nil
        }
    }

    static func formatShareText(thread: ChatThread) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .short
        let dateStr = dateFormatter.string(from: thread.createdAt)
        let model = thread.messages.compactMap(\.modelID).last ?? "Unknown"
        let messages = thread.messages
        let totalCount = messages.count
        let maxMessages = 20
        let shareable: ArraySlice<ChatMessage>
        let omittedNote: String?
        if totalCount > maxMessages {
            shareable = messages.suffix(maxMessages)
            let omitted = totalCount - maxMessages
            omittedNote = "... (\(omitted) earlier message\(omitted == 1 ? "" : "s") omitted)\n\n"
        } else {
            shareable = messages[messages.startIndex...]
            omittedNote = nil
        }
        var lines: [String] = []
        lines.append("# \(thread.title)")
        lines.append("*\(dateStr) \u{00b7} \(totalCount) messages \u{00b7} \(model)*")
        lines.append("")
        if let note = omittedNote {
            lines.append(note)
        }
        for msg in shareable {
            let role = msg.role == .user ? "User" : "Assistant"
            lines.append("**\(role):** \(msg.text)")
            lines.append("")
        }
        lines.append("---")
        lines.append("*Shared from Queen UI*")
        return lines.joined(separator: "\n")
    }

    // MARK: - Sidebar Section

    @ViewBuilder
    private var sidebarSection: some View {
        if showSidebar {
            VStack(spacing: 0) {
                ChatSidebar(store: store, modelManager: modelManager)

                Rectangle()
                    .fill(Color.white.opacity(V2Depth.bgCard))
                    .frame(height: 1)

                ContextInspector()
                    .frame(maxHeight: 200)

                Rectangle()
                    .fill(Color.white.opacity(V2Depth.bgCard))
                    .frame(height: 1)

                NetworkDashboard(client: client, modelManager: modelManager, store: store)
                    .frame(maxHeight: 220)
            }
            .frame(
                minWidth: LayoutConstants.sidebarMinWidth,
                idealWidth: LayoutConstants.sidebarIdealWidth,
                maxWidth: LayoutConstants.sidebarMaxWidth
            )
            .background(V4Color.sidebar)
            .transition(reduceMotion ? .opacity : .move(edge: .leading))

            Rectangle()
                .fill(Color.white.opacity(V2Depth.bgCard))
                .frame(width: ParietalSpacing.hairline)
        }
    }

    // MARK: - Comment Sidebar

    @ViewBuilder
    private var commentSidebarSection: some View {
        if let msg = commentingMessage {
            Rectangle()
                .fill(Color.white.opacity(V2Depth.bgCard))
                .frame(width: ParietalSpacing.hairline)

            CommentSidebar(
                message: msg,
                store: store,
                client: commentClient,
                modelManager: modelManager,
                onClose: { commentingMessage = nil }
            )
        }
    }

    // MARK: - Overlays Layer

    @ViewBuilder
    private var overlaysLayer: some View {
        if showShortcuts {
            ShortcutsOverlay(isPresented: $showShortcuts)
        }

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

        if showComparison {
            ModelComparisonView(
                prompt: comparisonPrompt,
                modelManager: modelManager,
                onClose: { showComparison = false }
            )
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - Mention Popup

    @ViewBuilder
    private var mentionPopupSection: some View {
        if showMentionPopup {
            // TODO: Re-enable EnhancedMentionPopup after fixing visibility issue
            // EnhancedMentionPopup(
            //     query: mentionQuery,
            //     isPresented: $showMentionPopup,
            //     onSelect: { value in
            //         if let atRange = input.range(of: "@\(mentionQuery)", options: .backwards) {
            //             input.replaceSubrange(atRange, with: "@\(value)")
            //         }
            //         showMentionPopup = false
            //     },
            //     repoContext: repoContext,
            //     trinityContext: trinityCtx
            // )
            EmptyView()
        }
    }

    // MARK: - Streaming Indicator

    @ViewBuilder
    private var streamingIndicatorView: some View {
        if client.isStreaming {
            VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
                streamingMetricsRow
                slowResponseWarning
            }
            .padding(.vertical, LayoutConstants.cardPadding)
            .transition(.opacity)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Streaming response")
            .accessibilityValue("Generation in progress")
        }
    }

    private var streamingMetricsRow: some View {
        HStack(spacing: ParietalSpacing.md) {
            // Compact pulse ring indicator
            CompactPulseRing(state: client.streamingState)
                .accessibilityHidden(true)

            if !client.streamingThinkingText.isEmpty && client.streamingText.isEmpty {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: a11y.scaledFontSize(14)))
                    .foregroundStyle(V4Color.purple)
                    .symbolEffect(.pulse, options: .repeating)
                Text("Reasoning...")
                    .font(.caption)
                    .foregroundStyle(V4Color.purple)
                StreamingElapsedTimer()
                Text("\(client.streamingThinkingText.count) chars")
                    .font(.system(size: a11y.scaledFontSize(9), design: .monospaced))
                    .foregroundStyle(V4Color.textSecondary)
                    .accessibilityLabel("\(client.streamingThinkingText.count) characters of reasoning")
            } else if thread?.messages.last?.text.isEmpty ?? false {
                QueenThinkingIndicator()
                LiveTTFBCounter(isWaiting: client.streamingTTFB == 0)
            }
            if client.streamingTTFB > 0 {
                Text("First token: \(client.streamingTTFB)ms")
                    .font(.system(size: a11y.scaledFontSize(10), weight: .medium, design: .monospaced))
                    .foregroundStyle(ttfbColor(client.streamingTTFB))
                    .accessibilityLabel("First token received in \(client.streamingTTFB) milliseconds")
            }
            if client.streamingTokensPerSec > 0 {
                LiveSpeedIndicator(tokPerSec: client.streamingTokensPerSec)
            }
            if client.streamingOutputTokens > 0 {
                Text("\(client.streamingOutputTokens) tok")
                    .font(.system(size: a11y.scaledFontSize(10), design: .monospaced))
                    .foregroundStyle(V4Color.textSecondary)
                    .accessibilityLabel("\(client.streamingOutputTokens) tokens generated")
            }
            if client.streamingMaxTokens > 0, client.streamingOutputTokens > 0 {
                let pct = min(Double(client.streamingOutputTokens) / Double(client.streamingMaxTokens) * 100, 100)
                Text(String(format: "~%.0f%%", pct))
                    .font(.system(size: a11y.scaledFontSize(10), weight: .medium, design: .monospaced))
                    .foregroundStyle(V4Color.textSecondary)
                    .accessibilityLabel("\(Int(pct)) percent of maximum tokens")
            }
        }
    }

    @ViewBuilder
    private var slowResponseWarning: some View {
        if client.isSlowResponse {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: "tortoise.fill")
                    .font(WernickeTypography.size10)
                Text("Slow response")
                    .font(WernickeTypography.miniMedium)
                Button {
                    client.stop()
                    if let threadID = store.activeThreadID {
                        store.removeLastAssistantMessage(in: threadID)
                        input = thread?.messages.last(where: { $0.role == .user })?.text ?? ""
                    }
                } label: {
                    Text("Cancel")
                        .font(WernickeTypography.miniBold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, ParietalSpacing.xs)
                        .padding(.vertical, 3)
                        .background(V4Color.statusError)
                        .clipShape(SwiftUI.Capsule())
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
                            .font(WernickeTypography.miniBold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, ParietalSpacing.xs)
                            .padding(.vertical, 3)
                            .background(V4Color.statusWarn)
                            .clipShape(SwiftUI.Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .foregroundStyle(V4Color.statusWarn)
            .transition(.opacity)
        }
    }

    // MARK: - Extracted Input Area Views

    @ViewBuilder
    private var errorRetryBlock: some View {
        if !client.isStreaming,
           let last = thread?.messages.last,
           last.role == .assistant,
           last.hasError,
           let errKind = last.errorKind {
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                HStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: errKind.icon)
                        .font(WernickeTypography.size16)
                        .foregroundStyle(errKind.color)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(errKind.label)
                            .font(WernickeTypography.smallBold)
                            .foregroundStyle(errKind.color)
                        if let detail = client.lastError?.userMessage {
                            Text(detail)
                                .font(WernickeTypography.size11)
                                .foregroundStyle(V4Color.textSecondary)
                                .lineLimit(2)
                        }
                    }
                    Spacer()
                }
                HStack(spacing: ParietalSpacing.sm) {
                    Button {
                        guard let threadID = store.activeThreadID else { return }
                        client.regenerate(threadID: threadID, store: store, modelManager: modelManager)
                    } label: {
                        HStack(spacing: ParietalSpacing.xs) {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: a11y.scaledFontSize(12), weight: .bold))
                            Text("Retry")
                                .font(.system(size: a11y.scaledFontSize(12), weight: .bold))
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, LayoutConstants.compactPadding)
                        .background(errKind.color)
                        .clipShape(SwiftUI.Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Regenerate response")
                    .accessibilityHint("Repeats the last request to generate a new response")
                    .accessibilityIdentifier("chat.retry")

                    Button {
                        if let userMsg = thread?.messages.last(where: { $0.role == .user }) {
                            input = userMsg.text
                        }
                        guard let threadID = store.activeThreadID else { return }
                        store.removeLastAssistantMessage(in: threadID)
                    } label: {
                        HStack(spacing: ParietalSpacing.xs) {
                            Image(systemName: "pencil")
                                .font(.system(size: a11y.scaledFontSize(12), weight: .bold))
                            Text("Edit & Retry")
                                .font(.system(size: a11y.scaledFontSize(12), weight: .bold))
                        }
                        .foregroundStyle(V4Color.white70)
                        .padding(.horizontal, 14)
                        .padding(.vertical, LayoutConstants.compactPadding)
                        .background(Color.white.opacity(V2Depth.bgSubtle))
                        .clipShape(SwiftUI.Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Edit and retry message")
                    .accessibilityHint("Loads your last message into the input for editing")
                    .accessibilityIdentifier("chat.editRetry")

                    if let fallback = modelManager.failoverModel() {
                        Button {
                            modelManager.selectedModel = fallback
                            modelManager.persistSelection()
                            guard let threadID = store.activeThreadID else { return }
                            client.regenerate(threadID: threadID, store: store, modelManager: modelManager)
                        } label: {
                            HStack(spacing: ParietalSpacing.xs) {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                    .font(.system(size: a11y.scaledFontSize(12), weight: .bold))
                                Text("Try \(fallback.displayName)")
                                    .font(.system(size: a11y.scaledFontSize(12), weight: .bold))
                            }
                            .foregroundStyle(.black)
                            .padding(.horizontal, 14)
                            .padding(.vertical, LayoutConstants.compactPadding)
                            .background(V4Color.accent)
                            .clipShape(SwiftUI.Capsule())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Try fallback model")
                        .accessibilityHint("Switches to \(fallback.displayName) and retries")
                        .accessibilityIdentifier("chat.tryFallback")
                    }
                }
            }
            .padding(LayoutConstants.cardPadding)
            .background(errKind.color.opacity(V2Depth.bgCard))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .padding(.vertical, LayoutConstants.standardPadding)
            .transition(.opacity)
        }
        // Legacy error fallback
        else if !client.isStreaming,
           let last = thread?.messages.last,
           last.role == .assistant,
           !last.hasError,
           last.text.hasPrefix("[") && last.text.contains("Error") {
            HStack(spacing: ParietalSpacing.md) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.statusError)
                Text(String(last.text.prefix(200)))
                    .font(WernickeTypography.size13)
                    .foregroundStyle(V4Color.statusError)
                    .lineLimit(2)
                Button {
                    guard let threadID = store.activeThreadID else { return }
                    client.regenerate(threadID: threadID, store: store, modelManager: modelManager)
                } label: {
                    Text("Retry")
                        .font(WernickeTypography.captionBold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 14)
                        .padding(.vertical, LayoutConstants.compactPadding)
                        .background(V4Color.statusError)
                        .clipShape(SwiftUI.Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.vertical, LayoutConstants.cardPadding)
            .transition(.opacity)
        }
    }

    @ViewBuilder
    private var stickyStreamingBar: some View {
        if client.isStreaming {
            PulseRingIndicator(
                isStreaming: client.isStreaming,
                streamingState: client.streamingState,
                onStop: { client.stop() },
                ttfb: client.streamingTTFB,
                tokensPerSec: client.streamingTokensPerSec,
                outputTokens: client.streamingOutputTokens,
                maxTokens: client.streamingMaxTokens
            )
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            .padding(.vertical, LayoutConstants.compactPadding)
            .transition(.scale.combined(with: .opacity))
            .keyboardShortcut(.escape, modifiers: [])
        }
    }

    @ViewBuilder
    private var offlineQueueBadge: some View {
        Group {
            if client.offlineQueueCount > 0 {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "envelope.badge")
                        .font(WernickeTypography.size11)
                    Text("\(client.offlineQueueCount) queued")
                        .font(WernickeTypography.captionMedium)
                }
                .foregroundStyle(Color.orange)
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, 5)
                .background(Color.orange.opacity(0.12))
                .clipShape(SwiftUI.Capsule())
                .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            } else if showQueueDrained {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(WernickeTypography.size11)
                    Text("\(queueDrainedMessageCount) queued messages sent")
                        .font(WernickeTypography.captionMedium)
                }
                .foregroundStyle(V4Color.statusOK)
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, 5)
                .background(V4Color.statusOK.opacity(0.12))
                .clipShape(SwiftUI.Capsule())
                .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
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

    // MARK: - Reply Preview Bar

    @ViewBuilder
    private var replyPreviewBar: some View {
        if let msg = replyingTo {
            HStack(spacing: ParietalSpacing.sm) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(a11y.highContrast ? V4Color.HighContrast.accent : V4Color.accent)
                    .frame(width: ParietalSpacing.dividerThickness)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(msg.role == .user ? "You" : "Queen")
                        .font(.system(size: a11y.scaledFontSize(10), weight: .semibold))
                        .foregroundStyle(a11y.highContrast ? V4Color.HighContrast.accent : V4Color.accent)
                    Text(String(msg.text.prefix(80)) + (msg.text.count > 80 ? "..." : ""))
                        .font(.system(size: a11y.scaledFontSize(11)))
                        .foregroundStyle(V4Color.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Button {
                    withAnimation { replyingTo = nil }
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: a11y.scaledFontSize(10), weight: .medium))
                        .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Cancel reply")
                .accessibilityHint("Removes the reply preview")
                .accessibilityIdentifier("chat.cancelReply")
            }
            .padding(.horizontal, LayoutConstants.cardPadding)
            .padding(.vertical, LayoutConstants.standardPadding)
            .background(Color.white.opacity(V2Depth.bgCardLight))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Replying to \(msg.role == .user ? "your" : "Queen's") message")
            .transition(reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity))
        }
    }

    @ViewBuilder
    private var inputAreaContent: some View {
        // Offline queue badge + drain toast
        offlineQueueBadge

        // Slash command result banner
        if let result = slashCommandResult {
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: "terminal")
                    .font(WernickeTypography.size11)
                    .foregroundStyle(V4Color.accent)
                Text(result)
                    .font(WernickeTypography.captionMedium)
                    .foregroundStyle(V4Color.textPrimary)
                Spacer()
                Button {
                    slashCommandResult = nil
                } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size9)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LayoutConstants.cardPadding)
            .padding(.vertical, LayoutConstants.compactPadding)
            .background(V4Color.accent.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
        }

        // Slash command autocomplete
        if input.hasPrefix("/") && !input.contains(" ") && input.count > 1 {
            let query = input.lowercased()
            let matches = SlashCommand.allCases.filter { $0.rawValue.hasPrefix(query) }
            if !matches.isEmpty {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    ForEach(matches, id: \.rawValue) { cmd in
                        Button {
                            input = cmd.rawValue + " "
                        } label: {
                            HStack(spacing: ParietalSpacing.xs) {
                                Image(systemName: cmd.icon)
                                    .font(WernickeTypography.size10)
                                Text(cmd.rawValue)
                                    .font(WernickeTypography.caption2Medium)
                            }
                            .foregroundStyle(V4Color.white70)
                            .padding(.horizontal, ParietalSpacing.xs)
                            .padding(.vertical, ParietalSpacing.xxs)
                            .background(Color.white.opacity(V2Depth.bgCard))
                            .clipShape(SwiftUI.Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
            }
        }

        // Template picker (shown via /template command)
        if showTemplatePicker {
            TemplatePicker(
                store: store,
                onSelect: { templateBody in
                    input = templateBody
                    showTemplatePicker = false
                },
                onDismiss: { showTemplatePicker = false }
            )
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
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
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: "checkmark.circle.fill")
                    .font(WernickeTypography.size12)
                    .foregroundStyle(V4Color.statusOK)
                Text("\(recovered) is back online")
                    .font(WernickeTypography.captionMedium)
                    .foregroundStyle(V4Color.statusOK)
                Spacer()
                if modelManager.selectedModel.provider.rawValue != recovered {
                    Button {
                        if let model = modelManager.availableModels.first(where: { $0.provider.rawValue == recovered }) {
                            modelManager.selectedModel = model
                            modelManager.persistSelection()
                        }
                    } label: {
                        Text("Switch back")
                            .font(WernickeTypography.miniBold)
                            .foregroundStyle(.black)
                            .padding(.horizontal, ParietalSpacing.xs)
                            .padding(.vertical, 3)
                            .background(V4Color.statusOK)
                            .clipShape(SwiftUI.Capsule())
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    NetworkLog.shared.recoveredProviders.removeAll { $0 == recovered }
                } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size9)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LayoutConstants.cardPadding)
            .padding(.vertical, LayoutConstants.compactPadding)
            .background(V4Color.statusOK.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
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

        // Context overflow warning (using new tiered banner)
        if estimatedTokens > 144_000 { // 80% of 180K
            ContextOverflowBanner(
                tokens: estimatedTokens,
                maxTokens: 180_000,
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
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
        }

        // Task tracker
        if !taskItems.isEmpty {
            TaskTrackerView(tasks: $taskItems)
                .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
                .padding(.bottom, 4)
        }

        // @Mention chips (parsed from input — click to remove)
        if !parsedMentionChips.isEmpty {
            HStack(spacing: ParietalSpacing.sm - 2) {
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
                                .font(WernickeTypography.size7)
                                .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                        }
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            .padding(.bottom, 2)
        }

        // Attached files chips
        if !attachedFiles.isEmpty {
            HStack(spacing: ParietalSpacing.sm) {
                ForEach(attachedFiles.indices, id: \.self) { idx in
                    HStack(spacing: ParietalSpacing.xs) {
                        Image(systemName: attachedFiles[idx].name.hasSuffix(".png") || attachedFiles[idx].name.hasSuffix(".jpg") ? "photo" : "paperclip")
                            .font(.caption2)
                        Text(attachedFiles[idx].name)
                            .font(.caption2)
                            .foregroundStyle(attachedFiles[idx].name.contains("clipboard") ? V4Color.purple : V4Color.accent)
                            .lineLimit(1)
                        Button {
                            attachedFiles.remove(at: idx)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.caption2)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.horizontal, ParietalSpacing.xs)
                    .padding(.vertical, ParietalSpacing.xxs)
                    .background(Color.white.opacity(0.08))
                    .clipShape(SwiftUI.Capsule())
                }
                Spacer()
            }
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            .padding(.bottom, 4)
        }
    }

    // MARK: - Rate Limit Warning Bar

    private var activeProviderRemaining: Int? {
        let provider = modelManager.selectedModel.provider.rawValue
        let result = networkLog.providerHealth[provider]?.remainingRequests
        return result
    }

    private var rateLimitWarningBar: some View {
        Group {
            let provider = modelManager.selectedModel.provider.rawValue
            let remaining = activeProviderRemaining
            let eta = networkLog.rateLimitETA(provider)

            if let remaining = remaining, remaining <= 0, !rateLimitDismissed {
                // Rate limited — error style
                HStack(spacing: ParietalSpacing.sm) {
                    Text("\u{1F6AB} Rate limited \u{2014} switching provider...")
                        .font(WernickeTypography.captionMedium)
                        .foregroundStyle(V4Color.statusError)
                    Spacer()
                    Button {
                        rateLimitDismissed = true
                    } label: {
                        Text("\u{00D7}")
                            .font(WernickeTypography.title3Bold)
                            .foregroundStyle(V4Color.statusError.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss rate limit warning")
                }
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, LayoutConstants.compactPadding)
                .background(V4Color.statusError.opacity(V2Depth.bgSidebarHover))
                .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            } else if let remaining = remaining, remaining < 50, !rateLimitDismissed {
                // Low quota — warning style
                HStack(spacing: ParietalSpacing.sm) {
                    if let eta = eta {
                        Text("\u{26A0} \(remaining) requests remaining (~\(eta) min)")
                            .font(WernickeTypography.captionMedium)
                            .foregroundStyle(V4Color.golden)
                    } else {
                        Text("\u{26A0} \(remaining) requests remaining")
                            .font(WernickeTypography.captionMedium)
                            .foregroundStyle(V4Color.golden)
                    }
                    Spacer()
                    Button {
                        rateLimitDismissed = true
                    } label: {
                        Text("\u{00D7}")
                            .font(WernickeTypography.title3Bold)
                            .foregroundStyle(V4Color.golden.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss rate limit warning")
                }
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, LayoutConstants.compactPadding)
                .background(V4Color.golden.opacity(V2Depth.bgSidebarHover))
                .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            }
        }
        .onChange(of: activeProviderRemaining) { _, newValue in
            // Auto-reset when quota recovers (above 50) or data becomes unavailable (nil = fresh state)
            if newValue == nil || (newValue ?? 0) >= 50 {
                rateLimitDismissed = false
            }
        }
    }

    private var budgetWarningBar: some View {
        Group {
            let cost = networkLog.todayCostEstimate()
            let budget = networkLog.dailyCostBudget
            let pct = Int((cost / budget) * 100)

            if networkLog.isBudgetExceeded && !budgetWarningDismissed {
                HStack(spacing: ParietalSpacing.sm) {
                    Text("\u{1F6AB} Daily budget exceeded: $\(String(format: "%.2f", cost)) / $\(String(format: "%.2f", budget)) \u{2014} consider switching to cheaper model")
                        .font(WernickeTypography.captionMedium)
                        .foregroundStyle(V4Color.statusError)
                    Spacer()
                    Button {
                        budgetWarningDismissed = true
                    } label: {
                        Text("\u{00D7}")
                            .font(WernickeTypography.title3Bold)
                            .foregroundStyle(V4Color.statusError.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss cost warning")
                }
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, LayoutConstants.compactPadding)
                .background(V4Color.statusError.opacity(V2Depth.bgSidebarHover))
                .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            } else if networkLog.isBudgetWarning && !budgetWarningDismissed {
                HStack(spacing: ParietalSpacing.sm) {
                    Text("\u{26A0}\u{FE0F} Daily spend: $\(String(format: "%.2f", cost)) / $\(String(format: "%.2f", budget)) (\(pct)%)")
                        .font(WernickeTypography.captionMedium)
                        .foregroundStyle(V4Color.golden)
                    Spacer()
                    Button {
                        budgetWarningDismissed = true
                    } label: {
                        Text("\u{00D7}")
                            .font(WernickeTypography.title3Bold)
                            .foregroundStyle(V4Color.golden.opacity(0.7))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Dismiss cost warning")
                }
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, LayoutConstants.compactPadding)
                .background(V4Color.golden.opacity(V2Depth.bgSidebarHover))
                .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            }
        }
    }

    private var inputBarView: some View {
        HStack(spacing: ParietalSpacing.md) {
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
            .layoutPriority(1)

            Button {
                send()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(WernickeTypography.size24)
                    .foregroundStyle(input.isEmpty ? V4Color.accent.opacity(V2Depth.stateHover) : V4Color.accent)
            }
            .buttonStyle(.plain)
            .help("Send message (⌘+)")
            .accessibilityLabel("Send message")
            .accessibilityHint("Double tap to send your message")
            .disabled(input.isEmpty)
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 24)
                .fill(V4Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: 24)
                        .stroke(isDropTargeted ? V4Color.accent : Color.white.opacity(0.08), lineWidth: isDropTargeted ? 2 : 1)
                )
        )
        .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
        .frame(height: ParietalSpacing.inputBarHeight)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - System Prompt Editor

    private var systemPromptEditorView: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            HStack {
                Image(systemName: "terminal")
                    .font(WernickeTypography.size11)
                    .foregroundStyle(V4Color.accent)
                Text("Custom System Prompt")
                    .font(WernickeTypography.caption2Semibold)
                    .foregroundStyle(V4Color.textSecondary)
                Spacer()
                Text("\(systemPromptDraft.count) chars")
                    .font(WernickeTypography.miniMono)
                    .foregroundStyle(V4Color.textSecondary)
                Button {
                    systemPromptDraft = ""
                    if let tid = store.activeThreadID,
                       let idx = store.threads.firstIndex(where: { $0.id == tid }) {
                        store.threads[idx].customSystemPrompt = nil
                        store.threads[idx].updatedAt = Date()
                        store.saveThread(tid)
                    }
                } label: {
                    Text("Reset")
                        .font(WernickeTypography.miniMedium)
                        .foregroundStyle(V4Color.statusWarn)
                }
                .buttonStyle(.plain)
                .help("Clear custom prompt, revert to default")
                Button {
                    if let tid = store.activeThreadID,
                       let idx = store.threads.firstIndex(where: { $0.id == tid }) {
                        let trimmed = systemPromptDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                        store.threads[idx].customSystemPrompt = trimmed.isEmpty ? nil : trimmed
                        store.threads[idx].updatedAt = Date()
                        store.saveThread(tid)
                    }
                    showSystemPrompt = false
                } label: {
                    Text("Save")
                        .font(WernickeTypography.miniSemibold)
                        .foregroundStyle(V4Color.accent)
                }
                .buttonStyle(.plain)
                .help("Save custom system prompt for this thread")
            }
            TextEditor(text: $systemPromptDraft)
                .font(WernickeTypography.size12Mono)
                .foregroundStyle(V4Color.textPrimary)
                .scrollContentBackground(.hidden)
                .frame(minHeight: 60, maxHeight: 120)
                .padding(LayoutConstants.compactPadding)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(V4Color.surfaceElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(Color.white.opacity(V2Depth.bgCard), lineWidth: 1)
                        )
                )
        }
        .padding(.horizontal, LayoutConstants.cardPadding)
        .padding(.vertical, LayoutConstants.standardPadding)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(V4Color.surface)
        )
        .padding(.bottom, 4)
    }

    @ViewBuilder
    private var modelSuggestionView: some View {
        if let suggestion = suggestedModel, suggestion.model != modelManager.selectedModel {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Button {
                    modelManager.selectedModel = suggestion.model
                    modelManager.persistSelection()
                    modelSuggestionDismissed = true
                } label: {
                    HStack(spacing: ParietalSpacing.xs) {
                        Text("\u{1F4A1} Try \(suggestion.model.displayName)")
                            .fontWeight(.medium)
                        Text("\u{2014} \(suggestion.reason)")
                    }
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .opacity(V1Theme.opacityTextSecondary)
                }
                .buttonStyle(.plain)
                Spacer()
                Button {
                    modelSuggestionDismissed = true
                } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size8)
                        .foregroundStyle(V4Color.white20)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
        }
    }

    @ViewBuilder
    private var sendButton: some View {
        Group {
            if client.isStreaming {
                Button(action: { client.stop() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: a11y.scaledFontSize(24)))
                        .foregroundStyle(a11y.highContrast ? V4Color.HighContrast.error : V4Color.accent)
                }
                .accessibilityLabel("Stop generation")
                .accessibilityHint("Double tap to stop the current response generation")
                .accessibilityIdentifier("chat.stopGeneration")
            } else {
                Button(action: { send() }) {
                    ZStack {
                        Circle()
                            .fill(input.isEmpty ? Color.white.opacity(V2Depth.bgSubtle) : modeColor(chatMode))
                            .frame(width: ParietalSpacing.touchFrame, height: 32)
                        Image(systemName: chatMode == .image ? "photo" : "arrow.up")
                            .font(.system(size: a11y.scaledFontSize(14), weight: .semibold))
                            .foregroundStyle(input.isEmpty ? Color.white.opacity(V2Depth.stateHover) : .black)
                    }
                }
                .disabled(input.isEmpty)
                .accessibilityLabel("Send message")
                .accessibilityHint("Double tap to send your message")
                .accessibilityIdentifier("chat.send")
                .accessibilityAction(named: "Send with specific model") {
                    if !input.isEmpty {
                        showModelPopover = true
                    }
                }
                .popover(isPresented: $showModelPopover) {
                    VStack(spacing: ParietalSpacing.xs) {
                        Text("Send with model")
                            .font(.system(size: a11y.scaledFontSize(11), weight: .bold))
                            .foregroundStyle(Color.white.opacity(V1Theme.opacityTextSecondary))
                            .padding(.top, 8)
                            .accessibilityAddTraits(.isHeader)
                        ForEach(modelManager.availableModels.filter { modelManager.providerHasKey($0.provider) }) { model in
                            Button {
                                showModelPopover = false
                                sendWithModel(model)
                            } label: {
                                HStack {
                                    Text(model.displayName)
                                        .font(.system(size: a11y.scaledFontSize(12)))
                                    if model == modelManager.selectedModel {
                                        Image(systemName: "checkmark")
                                            .font(WernickeTypography.size10)
                                            .accessibilityLabel("Currently selected")
                                    }
                                }
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, LayoutConstants.cardPadding)
                                .padding(.vertical, LayoutConstants.compactPadding)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Send with \(model.displayName)")
                            .accessibilityHint(model == modelManager.selectedModel ? "Currently selected model" : "Switches to this model and sends")
                        }
                    }
                    .padding(.bottom, 8)
                    .frame(minWidth: 180)
                    .background(V4Color.surface)
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

    // MARK: - Context Preview Popover
    private var contextPreviewPopover: some View {
        let msgs = thread?.messages ?? []
        let msgCount = msgs.count
        let sysPrompt = client.systemPrompt
        let sysLen = sysPrompt.count
        let sysPreview = sysLen > 100 ? String(sysPrompt.prefix(100)) + "..." : sysPrompt
        let personaName = client.activePersona?.name
        let customPrompt = client.customSystemPrompt
        let customPreview = customPrompt.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        let msgTokens = msgs.reduce(0) { $0 + estimateTokens($1.text) }
        let inputTokens = estimateTokens(input)
        let systemTokens = estimateTokens(sysPrompt)
        let fileTokens = attachedFiles.reduce(0) { $0 + estimateTokens($1.content) }
        let totalTokens = systemTokens + msgTokens + inputTokens + fileTokens
        let outputBudget = effortLevel.maxTokens
        let model = modelManager.selectedModel
        let cost = AIModel.estimateCost(provider: model.provider.rawValue, inputTokens: totalTokens, outputTokens: outputBudget)
        let costStr = cost < 0.001 ? "<$0.01" : String(format: "~$%.2f", cost)
        return VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack {
                Image(systemName: "eye").font(WernickeTypography.size11).foregroundStyle(V4Color.accent)
                Text("Context Preview").font(WernickeTypography.captionBold).foregroundStyle(V4Color.textPrimary)
                Spacer()
                Text(model.displayName).font(WernickeTypography.miniMono).foregroundStyle(V4Color.accent)
            }
            Divider().background(Color.white.opacity(V2Depth.bgSubtle))
            contextPreviewRow(icon: "terminal", label: "System prompt", detail: "\(sysLen) chars", preview: sysPreview)
            if let name = personaName { contextPreviewRow(icon: "person.fill", label: "Persona", detail: name, preview: nil) }
            if let cp = customPreview {
                contextPreviewRow(icon: "doc.text", label: "Custom prompt", detail: "\(cp.count) chars", preview: cp.count > 50 ? String(cp.prefix(50)) + "..." : cp)
            }
            if !attachedFiles.isEmpty {
                contextPreviewRow(icon: "paperclip", label: "Files (\(attachedFiles.count))", detail: "\(fileTokens) tok", preview: attachedFiles.map(\.name).joined(separator: ", "))
            }
            if !parsedMentionChips.isEmpty {
                contextPreviewRow(icon: "at", label: "Mentions", detail: "\(parsedMentionChips.count)", preview: parsedMentionChips.map { "@\($0.type):\($0.value)" }.joined(separator: ", "))
            }
            contextPreviewRow(icon: "bubble.left.and.bubble.right", label: "History", detail: "\(msgCount) msgs, ~\(formatTokenCount(msgTokens))", preview: nil)
            if !input.isEmpty {
                contextPreviewRow(icon: "pencil", label: "Your message", detail: "~\(formatTokenCount(inputTokens))", preview: input.count > 50 ? String(input.prefix(50)) + "..." : input)
            }
            Divider().background(Color.white.opacity(V2Depth.bgSubtle))
            HStack {
                Text("Total estimated").font(WernickeTypography.caption2Semibold).foregroundStyle(V4Color.textPrimary)
                Spacer()
                Text("~\(formatTokenCount(totalTokens)) tokens  \(costStr)").font(WernickeTypography.caption2BoldMono).foregroundStyle(V4Color.accent)
            }
            HStack {
                Text("Output budget").font(WernickeTypography.size10).foregroundStyle(V4Color.textSecondary)
                Spacer()
                Text("\(formatTokenCount(outputBudget)) (\(effortLevel.rawValue))").font(WernickeTypography.size10Mono).foregroundStyle(V4Color.textSecondary)
            }
        }
        .padding(LayoutConstants.cardPadding)
            .frame(maxWidth: 340)
            .frame(minWidth: 280)
            .background(V4Color.surface)
    }

    private func contextPreviewRow(icon: String, label: String, detail: String, preview: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: icon).font(WernickeTypography.size10).foregroundStyle(V4Color.textSecondary).frame(width: ParietalSpacing.xSmallFrame)
                Text(label).font(WernickeTypography.caption2Medium).foregroundStyle(V4Color.textPrimary)
                Spacer()
                Text(detail).font(WernickeTypography.miniMono).foregroundStyle(V4Color.textSecondary)
            }
            if let preview = preview {
                Text(preview).font(WernickeTypography.size10Mono).foregroundStyle(V4Color.white35).lineLimit(2).padding(.leading, 20)
            }
        }
    }
    private func formatTokenCount(_ tokens: Int) -> String {
        tokens >= 1000 ? String(format: "%.1fK", Double(tokens) / 1000.0) : "\(tokens)"
    }

    @ViewBuilder
    private var modeBarView: some View {
        HStack(spacing: ParietalSpacing.md) {
            ForEach(ChatMode.allCases, id: \.rawValue) { mode in
                Button { chatMode = mode } label: {
                    HStack(spacing: ParietalSpacing.xs) {
                        Image(systemName: mode.icon)
                            .font(.system(size: a11y.scaledFontSize(12)))
                        Text(mode.rawValue)
                            .font(.system(size: a11y.scaledFontSize(12), weight: .medium))
                    }
                    .foregroundStyle(chatMode == mode ? .black : Color.white.opacity(V2Depth.stateDisabled))
                    .padding(.horizontal, LayoutConstants.cardPadding)
                    .padding(.vertical, LayoutConstants.compactPadding)
                    .background(chatMode == mode ? modeColor(mode) : Color.white.opacity(V2Depth.bgCard))
                    .clipShape(SwiftUI.Capsule())
                    .overlay(
                        SwiftUI.Capsule()
                            .stroke(chatMode == mode ? modeColor(mode) : Color.clear, lineWidth: 1.5)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(mode.rawValue) mode\(chatMode == mode ? ", selected" : "")")
                .accessibilityHint("Double tap to switch to \(mode.rawValue) mode")
                .accessibilityIdentifier("chat.mode.\(mode.rawValue)")
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
                                    .accessibilityLabel("Currently selected")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: effortLevel.icon)
                        .font(.system(size: a11y.scaledFontSize(10)))
                    Text(effortLevel.rawValue)
                        .font(.system(size: a11y.scaledFontSize(10), weight: .medium))
                }
                .foregroundStyle(effortLevel.color)
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(effortLevel.color.opacity(0.12))
                .clipShape(SwiftUI.Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .help("Effort level: controls reasoning depth")
            .accessibilityLabel("Effort level, currently \(effortLevel.rawValue)")
            .accessibilityHint("Double tap to change reasoning depth")
            .accessibilityIdentifier("chat.effortLevel")

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
                                    .accessibilityLabel("Currently selected")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: stylePreset.icon)
                        .font(.system(size: a11y.scaledFontSize(10)))
                    Text(stylePreset.rawValue)
                        .font(.system(size: a11y.scaledFontSize(10), weight: .medium))
                }
                .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(Color.white.opacity(V2Depth.bgCard))
                .clipShape(SwiftUI.Capsule())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Style preset, currently \(stylePreset.rawValue)")
            .accessibilityHint("Double tap to change response style")
            .accessibilityIdentifier("chat.stylePreset")

            ContextMeter(tokens: estimatedTokens)
        }
        .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
        .padding(.bottom, 16)
    }

    private func send(modelOverride: AIModel? = nil) {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !client.isStreaming else { return }

        // Reset input history navigation
        historyIndex = -1
        savedCurrentInput = ""

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
                if result == "__SHOW_TEMPLATES__" {
                    showTemplatePicker = true
                    return
                }
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

        // Prepend reply quote if replying to a message
        if let reply = replyingTo {
            let quoted = reply.text.prefix(200)
            text = "> \(quoted)\n\n\(text)"
            replyingTo = nil
        }

        lastSentText = text
        input = ""
        modelSuggestionDismissed = false
        // Clear draft on send
        UserDefaults.standard.removeObject(forKey: "draft_\(threadID)")
        // Brief send confirmation
        showSentConfirmation = true
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1))
            showSentConfirmation = false
        }
        // Sync style preset, effort level, persona, and custom system prompt
        client.stylePreset = stylePreset
        client.effortLevel = effortLevel
        client.activePersona = selectedPersona
        if let thread = store.threads.first(where: { $0.id == threadID }) {
            client.customSystemPrompt = thread.customSystemPrompt
        }
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
        if ms < 1000 { return V4Color.accent }
        if ms < 3000 { return V4Color.textSecondary }
        if ms < 5000 { return V4Color.statusWarn }
        return V4Color.statusError
    }

    private func modeColor(_ mode: ChatMode) -> Color {
        switch mode {
        case .search: return V4Color.accent
        case .trinity: return V4Color.golden
        case .reason: return V4Color.purple
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

    private static let supportedDropExtensions: Set<String> = [
        "swift", "zig", "md", "txt", "json", "py", "js", "ts"
    ]

    private func handleFileDrop(_ providers: [NSItemProvider]) {
        let remaining = max(0, 3 - attachedFiles.count)
        guard remaining > 0 else { return }
        for provider in providers.prefix(remaining) {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil) else { return }
                let ext = url.pathExtension.lowercased()
                guard Self.supportedDropExtensions.contains(ext) else {
                    Task { @MainActor in
                        slashCommandResult = "Unsupported file type: .\(ext)"
                        try? await Task.sleep(for: .seconds(3))
                        slashCommandResult = nil
                    }
                    return
                }
                // Load off main thread
                Task.detached { [maxAttachmentSize] in
                    guard let fileData = try? Data(contentsOf: url) else { return }
                    let name = url.lastPathComponent
                    let size = fileData.count
                    if let content = String(data: fileData.prefix(maxAttachmentSize), encoding: .utf8) {
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

    // MARK: - Voice Input

    private func toggleVoiceInput() {
        if isRecording {
            stopRecording()
            return
        }

        SFSpeechRecognizer.requestAuthorization { status in
            DispatchQueue.main.async {
                switch status {
                case .authorized:
                    startRecording()
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

    private func startRecording() {
        guard let recognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US")),
              recognizer.isAvailable else {
            slashCommandResult = "Speech recognizer unavailable"
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                slashCommandResult = nil
            }
            return
        }

        speechRecognizer = recognizer

        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true

        recognitionRequest = request

        let audioEngine = AVAudioEngine()
        self.audioEngine = audioEngine

        let inputNode = audioEngine.inputNode
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak request] buffer, _ in
            request?.append(buffer)
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
            isRecording = true
            transcriptText = ""

            recognitionTask = recognizer.recognitionTask(with: request) { result, error in
                if let result {
                    DispatchQueue.main.async {
                        transcriptText = result.bestTranscription.formattedString
                        input = transcriptText
                    }
                }
                if error != nil || (result?.isFinal ?? false) {
                    self.stopRecording()
                }
            }

            // Auto-stop after 30s
            Task {
                try? await Task.sleep(for: .seconds(30))
                if isRecording {
                    self.stopRecording()
                }
            }
        } catch {
            slashCommandResult = "Failed to start audio engine"
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(3))
                slashCommandResult = nil
            }
            stopRecording()
        }
    }

    private func stopRecording() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil

        DispatchQueue.main.async {
            isRecording = false
            if !transcriptText.isEmpty {
                input = transcriptText
            }
            transcriptText = ""
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
                    try? md.write(to: url, atomically: true, encoding: .utf8)
                }
            }
        case .toggleSearch:
            NotificationCenter.default.post(name: .toggleThreadSearch, object: nil)
        case .runCommand(let prompt):
            NotificationCenter.default.post(name: .runCommand, object: prompt)
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

// MARK: - Notification Receivers Modifier

private struct NotificationReceiversModifier: ViewModifier {
    @ObservedObject var store: ThreadStore
    @ObservedObject var client: ChatClient
    @ObservedObject var modelManager: ModelManager
    @Binding var input: String
    @Binding var showCommandPalette: Bool
    @Binding var showSidebar: Bool
    @Binding var focusMode: Bool
    @Binding var showInThreadSearch: Bool
    @Binding var inThreadSearchQuery: String
    @Binding var inThreadSearchIndex: Int
    @Binding var showComparison: Bool
    @Binding var showPersonaLibrary: Bool
    @Binding var showThinkingTranscript: Bool
    @Binding var commentingMessage: ChatMessage?
    @Binding var slashCommandResult: String?
    @Binding var historyIndex: Int
    @Binding var savedCurrentInput: String
    @Binding var highlightedMessageID: UUID?
    @Binding var requestInputFocus: Bool
    var thread: ChatThread?

    /// All user messages in current thread, newest first (for Up/Down history navigation)
    private var inputHistory: [String] {
        guard let msgs = thread?.messages else { return [] }
        return msgs.filter { $0.role == .user }.map(\.text).reversed()
    }

    func body(content: Content) -> some View {
        let base = content
            .onReceive(NotificationCenter.default.publisher(for: .toggleCommandPalette)) { _ in
                showCommandPalette.toggle()
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleSidebar)) { _ in
                withAnimation(.easeInOut(duration: 0.2)) { showSidebar.toggle() }
            }
            .onReceive(NotificationCenter.default.publisher(for: .toggleFocusMode)) { _ in
                withAnimation(.easeInOut(duration: 0.3)) {
                    focusMode.toggle()
                    if focusMode { showSidebar = false }
                }
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

        let base2 = base
            .onReceive(NotificationCenter.default.publisher(for: .searchInThread)) { _ in
                showInThreadSearch = true
            }
            .onReceive(NotificationCenter.default.publisher(for: .copyLastResponse)) { _ in
                if let last = thread?.messages.last(where: { $0.role == .assistant }) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(last.text, forType: .string)
                    SoundCueManager.shared.playCopy()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .showThinkingTranscript)) { _ in
                showThinkingTranscript = true
            }

        return base2
            .onReceive(NotificationCenter.default.publisher(for: .exportThreadClipboard)) { _ in
                if let threadID = store.activeThreadID,
                   let md = store.exportAsMarkdown(threadID) {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(md, forType: .string)
                    SoundCueManager.shared.playCopy()
                    slashCommandResult = "Thread exported to clipboard as Markdown"
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(3))
                        slashCommandResult = nil
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .recallLastMessage)) { _ in
                let history = inputHistory
                guard !history.isEmpty else { return }
                guard input.isEmpty || historyIndex >= 0 else { return }
                if historyIndex == -1 { savedCurrentInput = input }
                let nextIndex = min(historyIndex + 1, history.count - 1)
                if nextIndex != historyIndex {
                    historyIndex = nextIndex
                    input = history[historyIndex]
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .navigateHistoryDown)) { _ in
                guard historyIndex >= 0 else { return }
                historyIndex -= 1
                if historyIndex == -1 {
                    input = savedCurrentInput
                } else {
                    input = inputHistory[historyIndex]
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .escapeAction)) { _ in
                if focusMode {
                    withAnimation(.easeInOut(duration: 0.3)) { focusMode = false }
                } else if client.isStreaming {
                    client.stop()
                } else if showCommandPalette {
                    showCommandPalette = false
                } else if showInThreadSearch {
                    showInThreadSearch = false
                    inThreadSearchQuery = ""
                    inThreadSearchIndex = 0
                } else if showComparison {
                    showComparison = false
                } else if showPersonaLibrary {
                    showPersonaLibrary = false
                } else if commentingMessage != nil {
                    commentingMessage = nil
                } else if !input.isEmpty {
                    input = ""
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .clearChat)) { _ in
                // TODO: Implement clear thread functionality
                if store.activeThreadID == nil { return }
                input = ""
            }
            .onReceive(NotificationCenter.default.publisher(for: .focusInput)) { _ in
                requestInputFocus = true
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(100))
                    requestInputFocus = false
                }
            }
    }
}

// MARK: - Change Trackers Modifier

private struct ChangeTrackersModifier: ViewModifier {
    @Binding var input: String
    @Binding var showDraftSaved: Bool
    @Binding var modelSuggestionDismissed: Bool
    @Binding var taskItems: [TaskItem]
    @Binding var selectedPersona: Persona?
    @Binding var initialMessageIDs: Set<UUID>
    @Binding var isLoadingThread: Bool
    @ObservedObject var store: ThreadStore
    @ObservedObject var client: ChatClient
    @State private var draftSaveTask: Task<Void, Never>? = nil

    func body(content: Content) -> some View {
        content
            .onChange(of: input) { _, newValue in
                modelSuggestionDismissed = false
                // Debounced draft save: persist after 1s of typing inactivity
                draftSaveTask?.cancel()
                draftSaveTask = Task { @MainActor in
                    try? await Task.sleep(for: .seconds(1))
                    guard !Task.isCancelled else { return }
                    if let tid = store.activeThreadID {
                        if newValue.isEmpty {
                            UserDefaults.standard.removeObject(forKey: "draft_\(tid)")
                        } else {
                            UserDefaults.standard.set(newValue, forKey: "draft_\(tid)")
                        }
                    }
                }
                if !newValue.isEmpty && !client.followUpSuggestions.isEmpty {
                    client.followUpSuggestions = []
                }
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
            .onChange(of: store.activeThreadID) { oldID, newID in
                // Flush pending draft for the thread we're leaving
                draftSaveTask?.cancel()
                draftSaveTask = nil
                if let oldTid = oldID, !input.isEmpty {
                    UserDefaults.standard.set(input, forKey: "draft_\(oldTid)")
                } else if let oldTid = oldID {
                    UserDefaults.standard.removeObject(forKey: "draft_\(oldTid)")
                }
                // Restore draft for the thread we're switching to
                if let tid = newID {
                    let draft = UserDefaults.standard.string(forKey: "draft_\(tid)") ?? ""
                    input = draft
                }
                // Snapshot all messages of the new thread so we don't animate history
                if let msgs = store.activeThread()?.messages {
                    initialMessageIDs = Set(msgs.map(\.id))
                    // Brief loading skeleton for large threads (>50 messages)
                    if msgs.count > 50 {
                        isLoadingThread = true
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(150))
                            withAnimation(.easeOut(duration: 0.2)) { isLoadingThread = false }
                        }
                    } else {
                        isLoadingThread = false
                    }
                }
            }
            .onChange(of: selectedPersona) { _, newPersona in
                if let tid = store.activeThreadID,
                   let idx = store.threads.firstIndex(where: { $0.id == tid }) {
                    store.threads[idx].personaID = newPersona?.id
                    store.saveThread(tid)
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
    static let exportThreadClipboard = Notification.Name("exportThreadClipboard")
    static let recallLastMessage = Notification.Name("recallLastMessage")
    static let navigateHistoryDown = Notification.Name("navigateHistoryDown")
    static let escapeAction = Notification.Name("escapeAction")
    static let toggleFocusMode = Notification.Name("toggleFocusMode")
    static let scrollToMessage = Notification.Name("scrollToMessage")
    static let runCommand = Notification.Name("runCommand")
    static let clearChat = Notification.Name("clearChat")
    static let focusInput = Notification.Name("focusInput")
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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "wifi.slash")
                        .font(.caption2)
                    Text("No network connection")
                        .font(.caption2)
                    Spacer()
                    Text(networkMonitor.connectionType.rawValue)
                        .font(WernickeTypography.size9Mono)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
                .foregroundStyle(V4Color.statusError)
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, 5)
                .background(V4Color.statusError.opacity(0.12))
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            // Reconnected toast
            if networkMonitor.wasDisconnected {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "wifi")
                        .font(.caption2)
                    Text("Reconnected")
                        .font(.caption2)
                    Spacer()
                }
                .foregroundStyle(V4Color.statusOK)
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(V4Color.statusOK.opacity(0.08))
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            // Failover chain notification
            if let event = client.failoverEvent, showFailover {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                        .font(.caption2)
                    Text(event.from)
                        .font(WernickeTypography.miniMedium)
                        .foregroundStyle(V4Color.statusError)
                        .strikethrough()
                    Image(systemName: "arrow.right")
                        .font(WernickeTypography.size8)
                    Text(event.to)
                        .font(WernickeTypography.miniMedium)
                        .foregroundStyle(V4Color.statusOK)
                    if let notice = modelManager.cloudFallbackNotice {
                        Text(notice)
                            .font(WernickeTypography.size9)
                            .foregroundStyle(V4Color.accent)
                    } else {
                        Text("timed out \u{2192} switched")
                            .font(WernickeTypography.size9)
                            .foregroundStyle(V4Color.textSecondary)
                    }
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
                            .font(WernickeTypography.microBold)
                            .foregroundStyle(V4Color.accent)
                    }
                    .buttonStyle(.plain)
                    Button {
                        withAnimation { showFailover = false }
                    } label: {
                        Image(systemName: "xmark")
                            .font(WernickeTypography.size9)
                            .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                    }
                    .buttonStyle(.plain)
                }
                .foregroundStyle(V4Color.accent)
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, 5)
                .background(V4Color.accent.opacity(0.08))
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            // Checking connection spinner
            if isOnline == nil {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Checking connection...")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                    Spacer()
                }
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, ParietalSpacing.xxs)
                .transition(reduceMotion ? .opacity : .move(edge: .top).combined(with: .opacity))
            }

            // Offline warning for selected provider
            if let online = isOnline, !online {
                HStack(spacing: ParietalSpacing.sm - 2) {
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
                    .padding(.horizontal, ParietalSpacing.xs)
                    .padding(.vertical, 2)
                    .background(V4Color.statusError)
                    .clipShape(SwiftUI.Capsule())
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retry connection")
                }
                .foregroundStyle(V4Color.statusError)
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, LayoutConstants.compactPadding)
                .background(V4Color.statusError.opacity(V2Depth.bgSubtle))
            }

            // Provider status dots bar (show if any provider is down)
            if networkLog.providerHealth.values.contains(where: { !$0.isUp }) {
                HStack(spacing: ParietalSpacing.md) {
                    ForEach(Array(networkLog.providerHealth.values).sorted(by: { $0.name < $1.name }), id: \.name) { status in
                        HStack(spacing: ParietalSpacing.xs) {
                            Circle()
                                .fill(status.isUp ? V4Color.statusOK : V4Color.statusError)
                                .frame(width: ParietalSpacing.microIndicator, height: 5)
                            Text(status.name)
                                .font(WernickeTypography.size9)
                                .foregroundStyle(status.isUp ? V4Color.textSecondary : V4Color.statusError)
                            if let remaining = status.remainingRequests {
                                Text("(\(remaining))")
                                    .font(WernickeTypography.size8Mono)
                                    .foregroundStyle(V4Color.textSecondary)
                            }
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, LayoutConstants.standardPadding)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(Color.white.opacity(0.02))
            }

            // Rate limit predictor warning
            RateLimitWarning(modelManager: modelManager)

            // MCP server status + Branch pill
            HStack(spacing: ParietalSpacing.md) {
                MCPStatusView()
                    .onAppear {
                        // Will load from .mcp.json
                    }
                BranchPill()
                Spacer()
            }
            .padding(.horizontal, LayoutConstants.standardPadding)
            .padding(.vertical, 2)
        }
        .onAppear { checkConnection() }
        .onChange(of: client.failoverEvent) {
            withAnimation(.easeInOut(duration: 0.3)) { showFailover = true }
            // Auto-dismiss after 4s (8s for cloud-to-local fallback)
            let delay = modelManager.cloudFallbackNotice != nil ? 8 : 4
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(delay))
                withAnimation(.easeInOut(duration: 0.3)) { showFailover = false }
                modelManager.cloudFallbackNotice = nil
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

    private var ratio: Double { min(Double(tokens) / Double(maxTokens), 1.0) }
    private var percent: Int { Int(ratio * 100) }

    private var meterColor: Color {
        if ratio < 0.70 { return V4Color.accent }
        if ratio < 0.85 { return V4Color.golden }
        return V4Color.statusError
    }

    var body: some View {
        let cost = networkLog.todayCostEstimate()

        HStack(spacing: ParietalSpacing.sm - 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    SwiftUI.Capsule()
                        .fill(Color.white.opacity(V2Depth.bgCard))
                    SwiftUI.Capsule()
                        .fill(meterColor)
                        .frame(width: geo.size.width * ratio)
                        .animation(.easeInOut(duration: 0.4), value: ratio)
                }
            }
            .frame(width: ParietalSpacing.largeFrame, height: 3)

            Text("\(percent)% (\(tokens / 1000)K)")
                .font(WernickeTypography.microMono)
                .foregroundStyle(meterColor)
                .animation(.easeInOut(duration: 0.4), value: meterColor)

            if cost > 0.001 {
                Text(String(format: "$%.2f", cost))
                    .font(WernickeTypography.microMono)
                    .foregroundStyle(cost > 1.0 ? V4Color.golden : V4Color.textSecondary)
            }
        }
        .help("\(tokens) tokens / \(maxTokens / 1000)K context | Session: $\(String(format: "%.3f", cost))")
    }
}

// MARK: - Sticky Context Bar (always visible at top of chat)

struct ContextBar: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tokens: Int
    var onCompact: (() -> Void)? = nil
    private let maxTokens = 180_000

    private var ratio: Double { min(Double(tokens) / Double(maxTokens), 1.0) }
    private var percent: Int { Int(ratio * 100) }

    private var color: Color {
        if ratio < 0.70 { return V4Color.accent }
        if ratio < 0.85 { return V4Color.golden }
        return V4Color.statusError
    }

    var body: some View {
        if tokens > 1000 {
            VStack(spacing: 2) {
                HStack(spacing: ParietalSpacing.sm) {
                    // Progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            SwiftUI.Capsule()
                                .fill(Color.white.opacity(V2Depth.bgCard))
                            SwiftUI.Capsule()
                                .fill(color)
                                .frame(width: geo.size.width * ratio)
                                .animation(.easeInOut(duration: 0.4), value: ratio)
                        }
                    }
                    .frame(height: ParietalSpacing.cursorLineHeight)

                    Text("\(tokens / 1000)K / \(maxTokens / 1000)K")
                        .font(WernickeTypography.microMono)
                        .foregroundStyle(color)
                        .fixedSize()
                        .animation(.easeInOut(duration: 0.4), value: color)

                    Text("\(percent)%")
                        .font(WernickeTypography.microBoldMono)
                        .foregroundStyle(color)
                        .fixedSize()
                        .animation(.easeInOut(duration: 0.4), value: color)
                }

                // CTA when context is filling up (>85%)
                if ratio > 0.85, let onCompact = onCompact {
                    HStack(spacing: ParietalSpacing.xs) {
                        Text("Context filling up —")
                            .font(WernickeTypography.size9)
                            .foregroundStyle(V4Color.textSecondary)
                        Button(action: onCompact) {
                            Text("Clear old messages")
                                .font(WernickeTypography.microSemibold)
                                .foregroundStyle(V4Color.accent)
                        }
                        .buttonStyle(.plain)
                    }
                    .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            .padding(.vertical, ParietalSpacing.xxs)
            .background(ratio >= 0.7 ? color.opacity(V2Depth.bgCardLight) : Color.clear)
            .animation(.easeInOut(duration: 0.3), value: ratio > 0.85)
        }
    }
}

// MARK: - TTFB Sparkline (Path-based, 25x8px)

/// Tiny Path-based sparkline showing recent TTFB values
struct TTFBSparkline: View {
    let values: [Int]
    var width: CGFloat = 25
    var height: CGFloat = 8
    var color: Color = V4Color.accent

    var body: some View {
        if values.count >= 2 {
            let lo = Double(values.min() ?? 0)
            let hi = Double(values.max() ?? 1)
            let range = max(hi - lo, 1.0)
            Path { path in
                for (i, val) in values.enumerated() {
                    let x = width * CGFloat(i) / CGFloat(values.count - 1)
                    let y = height - height * CGFloat(Double(val) - lo) / CGFloat(range)
                    if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                    else { path.addLine(to: CGPoint(x: x, y: y)) }
                }
            }
            .stroke(color, lineWidth: 1.2)
            .frame(width: width, height: height)
        }
    }
}

struct ModelPicker: View {
    @ObservedObject var modelManager: ModelManager
    @StateObject private var networkLog = NetworkLog.shared

    private func providerIsUp(_ provider: AIProvider) -> Bool {
        networkLog.providerHealth[provider.rawValue]?.isUp ?? true
    }

    /// Last 5 TTFB points for a model
    private func ttfbPoints(for modelID: String) -> [Int] {
        networkLog.recentTTFB(for: modelID, count: 5)
    }

    /// Average TTFB for display
    private func avgTTFB(for modelID: String) -> Int? {
        let points = ttfbPoints(for: modelID)
        guard !points.isEmpty else { return nil }
        return points.reduce(0, +) / points.count
    }

    /// Whether circuit breaker is open for a provider
    private func isCircuitOpen(for provider: AIProvider) -> Bool {
        networkLog.isCircuitOpen(provider: provider.rawValue)
    }

    /// Latency info for a model row: sparkline + avg, or "Local" badge, or circuit breaker warning
    @ViewBuilder
    private func latencyBadge(for model: AIModel) -> some View {
        if model.provider == .ollama {
            Text("Local")
                .font(WernickeTypography.microSemibold)
                .foregroundStyle(V4Color.accent)
                .padding(.horizontal, 4)
                .padding(.vertical, 1)
                .background(V4Color.accent.opacity(V2Depth.bgSidebarHover))
                .cornerRadius(V1Theme.cornerMicro)
        } else if isCircuitOpen(for: model.provider) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(WernickeTypography.size9)
                .foregroundStyle(V4Color.statusError)
                .help("Circuit breaker open \u{2014} provider temporarily unavailable")
        } else {
            let points = ttfbPoints(for: model.id)
            if points.count >= 2 {
                TTFBSparkline(values: points)
                if let avg = avgTTFB(for: model.id) {
                    Text("~\(avg)ms")
                        .font(WernickeTypography.size9Mono)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                }
            } else if let avg = avgTTFB(for: model.id) {
                Text("~\(avg)ms")
                    .font(WernickeTypography.size9Mono)
                    .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
            } else {
                Text("\u{2014}")
                    .font(WernickeTypography.size9)
                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
            }
        }
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
                                        .fill(providerIsUp(model.provider) ? V4Color.statusOK : V4Color.statusError)
                                        .frame(width: ParietalSpacing.dotSize, height: 6)
                                    Text(model.displayName)
                                    latencyBadge(for: model)
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
            HStack(spacing: ParietalSpacing.xs) {
                Circle()
                    .fill(providerIsUp(modelManager.selectedModel.provider) ? V4Color.statusOK : V4Color.statusError)
                    .frame(width: ParietalSpacing.dotSize, height: 6)
                Text(modelManager.selectedModel.displayName)
                    .font(WernickeTypography.smallMedium)
                    .foregroundStyle(V4Color.white70)
                // Inline Path sparkline on picker label
                let points = ttfbPoints(for: modelManager.selectedModel.id)
                if points.count >= 2 {
                    TTFBSparkline(values: points, color: V4Color.accent.opacity(0.7))
                }
                if isCircuitOpen(for: modelManager.selectedModel.provider) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(WernickeTypography.size9)
                        .foregroundStyle(V4Color.statusError)
                }
                Image(systemName: "chevron.down")
                    .font(WernickeTypography.microMedium)
                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))

                // Rate limit warning badge
                if let remaining = networkLog.providerHealth[modelManager.selectedModel.provider.rawValue]?.remainingRequests,
                   remaining < 20 {
                    Text("\(remaining)")
                        .font(WernickeTypography.tiny8BoldMono)
                        .foregroundStyle(.black)
                        .padding(.horizontal, 4)
                        .padding(.vertical, 1)
                        .background(remaining < 5 ? V4Color.statusError : V4Color.statusWarn)
                        .clipShape(SwiftUI.Capsule())
                        .help("\(remaining) requests remaining")
                }
            }
            .padding(.horizontal, ParietalSpacing.xs)
            .padding(.vertical, LayoutConstants.compactPadding)
            .background(Color.white.opacity(V2Depth.bgCard))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .accessibilityLabel("Select AI model, currently \(modelManager.selectedModel.displayName)")
        .accessibilityHint("Opens model selection menu")
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
    var onReply: ((ChatMessage) -> Void)? = nil
    var searchHighlight: SearchHighlight = .none
    var searchQuery: String = ""
    var isSelecting: Bool = false
    var isSelected: Bool = false
    var onToggleSelect: ((_ shiftClick: Bool) -> Void)? = nil

    enum SearchHighlight {
        case none, match, currentMatch
    }

    /// Create attributed string with search highlights
    private func attributedTextWithHighlight(_ text: String) -> AttributedString {
        guard !searchQuery.isEmpty else {
            return AttributedString(text)
        }

        var result = AttributedString(text)
        let lowerText = text.lowercased()
        let lowerQuery = searchQuery.lowercased()
        var searchRange = lowerText.startIndex..<lowerText.endIndex

        // Find all match ranges and apply highlights
        while let range = lowerText.range(of: lowerQuery, range: searchRange) {
            let attributedRange = result.range(of: String(text[range]), options: .caseInsensitive)
            if let attributedRange = attributedRange {
                result[attributedRange].backgroundColor = V4Color.golden.opacity(V2Depth.stateHover)
            }
            searchRange = range.upperBound..<lowerText.endIndex
        }

        return result
    }

    /// Create highlighted text view for search results
    @ViewBuilder
    private func HighlightText(_ text: String) -> some View {
        if !searchQuery.isEmpty {
            Text(attributedTextWithHighlight(text))
        } else {
            Text(text)
        }
    }
    @State private var isHovering = false
    @State private var isEditing = false
    @State private var editText = ""
    @State private var showDiffConfirm = false
    @State private var showSaveTemplate = false
    @State private var saveTemplateName = ""
    @State private var saveTemplateCategory = "Code"
    @State private var saveTemplateConfirmed = false
    @State private var timestampCopied = false
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
        if estimatedTokens < 500 { return V4Color.textSecondary }
        if estimatedTokens < 2000 { return V4Color.accent }
        if estimatedTokens < 5000 { return V4Color.golden }
        return V4Color.statusError
    }

    private var tokenBadgeText: String {
        if estimatedTokens >= 1000 {
            return String(format: "%.1fK", Double(estimatedTokens) / 1000.0)
        }
        return "\(estimatedTokens)"
    }

    /// Word count for reading time display
    private var wordCount: Int {
        message.text.split(separator: " ").count
    }

    /// Estimated reading time in minutes (250 wpm average)
    private var readingTimeMinutes: Int {
        max(1, Int(ceil(Double(wordCount) / 250.0)))
    }

    var body: some View {
        HStack(spacing: 0) {
            selectionCheckbox
            messageContent
        }
        .padding(.vertical, LayoutConstants.standardPadding)
        .background(rowBackground)
        .overlay(rowHighlightOverlay)
    }

    // MARK: - Subviews (extracted for compiler performance)

    @ViewBuilder
    private var selectionCheckbox: some View {
        if isSelecting {
            Button {
                onToggleSelect?(NSEvent.modifierFlags.contains(.shift))
            } label: {
                ZStack {
                    if isSelected {
                        Circle()
                            .stroke(V4Color.accent.opacity(V2Depth.stateHover), lineWidth: 2)
                            .frame(width: ParietalSpacing.iconButtonFrame, height: ParietalSpacing.chipHeight)
                            .scaleEffect(isSelected ? 1.2 : 1.0)
                            .opacity(isSelected ? 0.5 : 0)
                    }

                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(WernickeTypography.size18)
                        .foregroundStyle(isSelected ? V4Color.accent : Color.white.opacity(V1Theme.opacityTextTertiary))
                        .scaleEffect(isSelected ? 1.1 : 1.0)
                }
                .animation(.spring(response: 0.3, dampingFraction: 0.6), value: isSelected)
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
            .transition(.asymmetric(
                insertion: .scale.combined(with: .opacity),
                removal: .scale.combined(with: .opacity)
            ))
        }
    }

    @ViewBuilder
    private var rowBackground: some View {
        if searchHighlight != .none {
            RoundedRectangle(cornerRadius: 8)
                .fill(searchHighlight == .currentMatch ? V4Color.golden.opacity(V2Depth.bgSidebarHover) : Color.white.opacity(0.03))
        }
    }

    @ViewBuilder
    private var rowHighlightOverlay: some View {
        EmptyView()
    }

    @ViewBuilder
    private var messageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if message.role == .user {
                userMessageContent
            } else {
                assistantMessageContent
            }
        }
    }

    // MARK: - User Message Content

    /// Edit mode UI for user messages with diff preview and action buttons
    @ViewBuilder
    private func userMessageEditModeView() -> some View {
        VStack(alignment: .trailing, spacing: ParietalSpacing.sm - 2) {
            TextField("Edit message...", text: $editText, axis: .vertical)
                .textFieldStyle(.plain)
                .font(.system(size: CGFloat(chatFontSize), weight: .semibold))
                .foregroundStyle(Color.white)
                .lineLimit(1...10)
                .padding(LayoutConstants.compactPadding)
                .background(Color.white.opacity(V2Depth.bgCard))
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .onSubmit { submitEdit() }

            // Diff preview
            if editText.trimmingCharacters(in: .whitespacesAndNewlines) != message.text.trimmingCharacters(in: .whitespacesAndNewlines) {
                let diff = Self.computeBriefDiff(old: message.text, new: editText)
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    (Text(diff.removed).foregroundColor(.red.opacity(0.8)).strikethrough()
                     + Text(" → ").foregroundColor(.white.opacity(V2Depth.stateHover))
                     + Text(diff.added).foregroundColor(.green.opacity(0.8)))
                        .font(WernickeTypography.size11)
                        .lineLimit(2)
                        .truncationMode(.middle)
                        .padding(.horizontal, ParietalSpacing.xs)
                        .padding(.vertical, ParietalSpacing.xxs)
                        .background(Color.white.opacity(V2Depth.bgCardLight))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                }
            } else if !editText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                HStack(spacing: 0) {
                    Spacer(minLength: 0)
                    Text("No changes")
                        .font(WernickeTypography.size11)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
            }

            HStack(spacing: ParietalSpacing.sm) {
                Button("Cancel") {
                    isEditing = false
                    showDiffConfirm = false
                }
                .font(WernickeTypography.size12)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                .buttonStyle(.plain)

                Button("Send") { submitEdit() }
                    .font(WernickeTypography.captionBold)
                    .foregroundStyle(.black)
                    .padding(.horizontal, LayoutConstants.cardPadding)
                    .padding(.vertical, ParietalSpacing.xxs)
                    .background(
                        editText.trimmingCharacters(in: .whitespacesAndNewlines) != message.text.trimmingCharacters(in: .whitespacesAndNewlines)
                        ? V4Color.accent
                        : Color.gray.opacity(V2Depth.stateHover)
                    )
                    .clipShape(SwiftUI.Capsule())
                    .buttonStyle(.plain)
                    .disabled(editText.trimmingCharacters(in: .whitespacesAndNewlines) == message.text.trimmingCharacters(in: .whitespacesAndNewlines))
            }
        }
    }

    /// Display mode UI for user messages with highlight text and action buttons
    @ViewBuilder
    private func userMessageDisplayModeView() -> some View {
        VStack(alignment: .trailing, spacing: ParietalSpacing.xs) {
            HighlightText(message.text)
                .font(.system(size: CGFloat(chatFontSize), weight: .semibold))
                .foregroundStyle(Color.white)
                .textSelection(.enabled)
                .multilineTextAlignment(.trailing)

            // Branch navigator (when message has been edited/forked)
            if message.branchID != nil, let threadID = store.activeThreadID {
                BranchNavigator(message: message, store: store, threadID: threadID)
            }

            // Metadata line: always visible for last message, hover for others
            if isLastMessage || (isHovering && !isEditing) {
                metadataLine
                    .transition(.opacity)
            }

            // Action buttons on hover
            if isHovering && !isEditing {
                HStack(spacing: ParietalSpacing.sm) {
                    Button {
                        editText = message.text
                        isEditing = true
                    } label: {
                        Image(systemName: "pencil")
                            .font(WernickeTypography.size10)
                            .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                    }
                    .buttonStyle(.plain)
                    .help("Edit & resend")

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(message.text, forType: .string)
                        SoundCueManager.shared.playCopy()
                    } label: {
                        Image(systemName: "doc.on.doc")
                            .font(WernickeTypography.size10)
                            .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                    }
                    .buttonStyle(.plain)
                    .help("Copy")

                    Button {
                        guard let threadID = store.activeThreadID else { return }
                        store.toggleBookmark(message.id, in: threadID)
                    } label: {
                        Image(systemName: message.isBookmarked == true ? "pin.fill" : "pin")
                            .font(WernickeTypography.size10)
                            .foregroundStyle(message.isBookmarked == true ? V4Color.accent : Color.white.opacity(V1Theme.opacityTextTertiary))
                    }
                    .buttonStyle(.plain)
                    .help("Pin message")
                }
                .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var userMessageContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            // User message — bold, slightly larger
            HStack(alignment: .top, spacing: 0) {
                Spacer(minLength: 0)
                VStack(alignment: .trailing, spacing: ParietalSpacing.xs) {
                    if isEditing {
                        userMessageEditModeView()
                    } else {
                        userMessageDisplayModeView()
                    }
                }
                .padding(.vertical, ParietalSpacing.md)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        // Context menu (right-click)
        .contextMenu { userMessageContextMenu() }
        .popover(isPresented: $showSaveTemplate) {
            SaveAsTemplatePopover(
                name: $saveTemplateName,
                category: $saveTemplateCategory,
                messageText: message.text,
                store: store,
                isPresented: $showSaveTemplate,
                confirmed: $saveTemplateConfirmed
            )
        }
        // Accessibility
        .accessibilityElement(children: .combine)
        .accessibilityLabel("You: \(String(message.text.prefix(200)))")
        .accessibilityHint("Double-tap to edit")
        .background(
            Group {
                switch searchHighlight {
                case .currentMatch:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(V4Color.accent.opacity(0.18))
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(V4Color.accent.opacity(V2Depth.stateDisabled), lineWidth: 1.5)
                        )
                case .match:
                    RoundedRectangle(cornerRadius: 8)
                        .fill(V4Color.accent.opacity(0.08))
                case .none:
                    if isSelected {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(V4Color.accent.opacity(0.05))
                    } else {
                        Color.clear
                    }
                }
            }
        )
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelecting {
                onToggleSelect?(NSEvent.modifierFlags.contains(.shift))
            }
        }
    }

    // MARK: - User Message Context Menu

    /// Context menu for user messages
    @ViewBuilder
    private func userMessageContextMenu() -> some View {
        Group {
            userCopySubmenu()
            copyTimestampButton()
            copyMessageIDButton()
            editAndResendButton()
            userBookmarkButton()
            saveAsTemplateButton()
            userCommentReplyButtons()
            Divider()
        }
    }

    @ViewBuilder
    private func userCopySubmenu() -> some View {
        Menu {
            userCopyAsMarkdownButton()
            userCopyPlainTextButton()
            userCopyCodeOnlyButton()
            userCopyWithCitationsButton()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }

    @ViewBuilder
    private func userCopyAsMarkdownButton() -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.text, forType: .string)
            SoundCueManager.shared.playCopy()
        } label: {
            Label("Copy as Markdown", systemImage: "doc.richtext")
        }
    }

    @ViewBuilder
    private func userCopyPlainTextButton() -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(MessageRow.stripMarkdown(from: message.text), forType: .string)
            SoundCueManager.shared.playCopy()
        } label: {
            Label("Copy Plain Text", systemImage: "doc.plaintext")
        }
    }

    @ViewBuilder
    private func userCopyCodeOnlyButton() -> some View {
        let codeBlocks = MessageRow.extractCodeBlocks(from: message.text)
        if !codeBlocks.isEmpty {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(codeBlocks.joined(separator: "\n\n"), forType: .string)
                SoundCueManager.shared.playCopy()
            } label: {
                Label("Copy Code Only", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    @ViewBuilder
    private func userCopyWithCitationsButton() -> some View {
        if let citations = message.citations, !citations.isEmpty {
            Button {
                copyWithCitations(citations: citations)
            } label: {
                Label("Copy with Citations", systemImage: "link")
            }
        }
    }

    @ViewBuilder
    private func copyTimestampButton() -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(isoTimestamp, forType: .string)
        } label: {
            Label("Copy Timestamp", systemImage: "clock")
        }
    }

    @ViewBuilder
    private func copyMessageIDButton() -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.id.uuidString, forType: .string)
        } label: {
            Label("Copy Message ID", systemImage: "number")
        }
    }

    @ViewBuilder
    private func editAndResendButton() -> some View {
        Button {
            editText = message.text
            isEditing = true
        } label: {
            Label("Edit & Resend", systemImage: "pencil")
        }
    }

    @ViewBuilder
    private func userBookmarkButton() -> some View {
        Button {
            guard let threadID = store.activeThreadID else { return }
            store.toggleBookmark(message.id, in: threadID)
        } label: {
            Label(
                message.isBookmarked == true ? "Unpin" : "Pin message",
                systemImage: message.isBookmarked == true ? "pin.fill" : "pin"
            )
        }
    }

    @ViewBuilder
    private func saveAsTemplateButton() -> some View {
        Button {
            saveTemplateName = String(message.text.prefix(40))
            saveTemplateCategory = "Code"
            showSaveTemplate = true
        } label: {
            Label("Save as Template", systemImage: "doc.on.clipboard")
        }
    }

    @ViewBuilder
    private func userCommentReplyButtons() -> some View {
        if let onComment {
            Button {
                onComment(message)
            } label: {
                Label("Comment", systemImage: "text.bubble")
            }
        }

        if let onReply {
            Button {
                onReply(message)
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
        }
    }

    // MARK: - Assistant Message Content

    /// Retry button shown on failed assistant messages
    @ViewBuilder
    private func assistantRetryButton() -> some View {
        if isLastMessage, message.hasError, !client.isStreaming,
           let errKind = message.errorKind {
            Button {
                guard let threadID = store.activeThreadID else { return }
                client.regenerateFrom(
                    messageID: message.id,
                    threadID: threadID,
                    store: store,
                    modelManager: modelManager
                )
            } label: {
                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: "arrow.clockwise")
                        .font(WernickeTypography.captionBold)
                    Text("Retry")
                        .font(WernickeTypography.captionBold)
                }
                .foregroundStyle(errKind.color)
                .padding(.horizontal, 14)
                .padding(.vertical, LayoutConstants.compactPadding)
                .background(errKind.color.opacity(0.12))
                .clipShape(SwiftUI.Capsule())
            }
            .buttonStyle(.plain)
            .transition(.opacity)
        }
    }

    /// Branch navigator for alternative responses
    @ViewBuilder
    private func branchNavigatorView() -> some View {
        if message.branchID != nil, let threadID = store.activeThreadID {
            BranchNavigator(message: message, store: store, threadID: threadID)
        }
    }

    /// Reading time indicator for long messages
    @ViewBuilder
    private func readingTimeView() -> some View {
        if message.role == .assistant, !client.isStreaming, wordCount > 200 {
            HStack(spacing: ParietalSpacing.xs) {
                Image(systemName: "text.alignleft")
                Text("\(wordCount) words · \(readingTimeMinutes) min read")
            }
            .font(.caption2)
            .foregroundStyle(V4Color.textSecondary)
            .opacity(V2Depth.stateDisabled)
        }
    }

    /// Message action toolbar with metadata and token badge
    @ViewBuilder
    private func messageActionToolbar() -> some View {
        if !message.text.isEmpty {
            HStack(spacing: 0) {
                MessageActionBar(
                    message: message,
                    store: store,
                    client: client,
                    modelManager: modelManager,
                    isHovering: isHovering,
                    onComment: onComment,
                    onReply: onReply
                )

                // Timestamp + model badge (always for last, hover for others)
                if isLastMessage || isHovering {
                    metadataLine
                        .padding(.leading, 8)
                        .transition(.opacity)
                }

                Spacer()

                // Token count badge
                if estimatedTokens > 0 {
                    Text("\(tokenBadgeText) tok")
                        .font(WernickeTypography.microMono)
                        .foregroundStyle(tokenBadgeColor)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(tokenBadgeColor.opacity(V2Depth.bgSubtle))
                        .clipShape(SwiftUI.Capsule())
                        .help(message.outputTokens != nil ? "Actual tokens" : "Estimated tokens")
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 12)
        }
    }

    /// Token budget bar shown on hover
    @ViewBuilder
    private func tokenBudgetBar() -> some View {
        if isHovering && !message.text.isEmpty {
            GeometryReader { geo in
                let barHeight = max(geo.size.height * min(tokenShare * 50, 1.0), 4)
                let color: Color = tokenShare < 0.02 ? V4Color.accent.opacity(V2Depth.stateHover)
                    : tokenShare < 0.05 ? V4Color.golden.opacity(V2Depth.stateDisabled)
                    : V4Color.statusError.opacity(V2Depth.stateDisabled)
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 1)
                        .fill(color)
                        .frame(width: ParietalSpacing.dividerThickness, height: barHeight)
                }
            }
            .frame(width: ParietalSpacing.dividerThickness)
            .transition(.opacity)
        }
    }

    /// Main message body for assistant
    @ViewBuilder
    private func assistantMessageBody() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                messageBodyContent
                    .font(.system(size: CGFloat(chatFontSize), weight: .regular))
                    .foregroundStyle(V4Color.textSecondary)
                    .textSelection(.enabled)
                    .lineSpacing(4)
                    .padding(.top, 16)

                assistantRetryButton()
                branchNavigatorView()
                readingTimeView()
                messageActionToolbar()
            }

            // Thin separator between messages
            Rectangle()
                .fill(Color.white.opacity(V2Depth.bgCardLight))
                .frame(height: 1)
        }
    }

    @ViewBuilder
    private var assistantMessageContent: some View {
        HStack(spacing: 0) {
            assistantMessageBody()
            tokenBudgetBar()
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
        .contextMenu { assistantContextMenu() }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Queen: \(String(message.text.prefix(200)))")
        .accessibilityHint("Double-tap for actions")
        .background(messageBackgroundHighlight())
        .contentShape(Rectangle())
        .onTapGesture {
            if isSelecting {
                onToggleSelect?(NSEvent.modifierFlags.contains(.shift))
            }
        }
    }

    /// Background highlight for search results and selection
    @ViewBuilder
    private func messageBackgroundHighlight() -> some View {
        switch searchHighlight {
        case .currentMatch:
            RoundedRectangle(cornerRadius: 8)
                .fill(V4Color.accent.opacity(0.18))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .strokeBorder(V4Color.accent.opacity(V2Depth.stateDisabled), lineWidth: 1.5)
                )
        case .match:
            RoundedRectangle(cornerRadius: 8)
                .fill(V4Color.accent.opacity(0.08))
        case .none:
            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .fill(V4Color.accent.opacity(0.05))
            } else {
                Color.clear
            }
        }
    }

    /// Context menu for assistant messages
    @ViewBuilder
    private func assistantContextMenu() -> some View {
        Group {
            copySubmenu()
            Divider()
            regenerationButton()
            bookmarkButton()
            commentReplyButtons()
            quickActionsMenu()
            Divider()
            deleteButton()
        }
    }

    /// Copy submenu with various copy options
    @ViewBuilder
    private func copySubmenu() -> some View {
        Menu {
            copyAsMarkdownButton()
            copyPlainTextButton()
            copyCodeOnlyButton()
            copyWithCitationsButton()
        } label: {
            Label("Copy", systemImage: "doc.on.doc")
        }
    }

    @ViewBuilder
    private func copyAsMarkdownButton() -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(message.text, forType: .string)
            SoundCueManager.shared.playCopy()
        } label: {
            Label("Copy as Markdown", systemImage: "doc.richtext")
        }
    }

    @ViewBuilder
    private func copyPlainTextButton() -> some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(MessageRow.stripMarkdown(from: message.text), forType: .string)
            SoundCueManager.shared.playCopy()
        } label: {
            Label("Copy Plain Text", systemImage: "doc.plaintext")
        }
    }

    @ViewBuilder
    private func copyCodeOnlyButton() -> some View {
        let codeBlocks = MessageRow.extractCodeBlocks(from: message.text)
        if !codeBlocks.isEmpty {
            Button {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(codeBlocks.joined(separator: "\n\n"), forType: .string)
                SoundCueManager.shared.playCopy()
            } label: {
                Label("Copy Code Only", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }
    }

    @ViewBuilder
    private func copyWithCitationsButton() -> some View {
        if let citations = message.citations, !citations.isEmpty {
            Button {
                copyWithCitations(citations: citations)
            } label: {
                Label("Copy with Citations", systemImage: "link")
            }
        }
    }

    private func copyWithCitations(citations: [Citation]) {
        let citationList = citations.enumerated().map { "[\($0.offset + 1)] \($0.element.title ?? $0.element.url)" }.joined(separator: "\n")
        let withCitations = message.text + "\n\n---\n**Citations:**\n" + citationList
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(withCitations, forType: .string)
        SoundCueManager.shared.playCopy()
    }

    @ViewBuilder
    private func regenerationButton() -> some View {
        if message.role == .assistant, !client.isStreaming {
            Button {
                guard let threadID = store.activeThreadID else { return }
                client.regenerateFrom(messageID: message.id, threadID: threadID, store: store, modelManager: modelManager)
            } label: {
                Label("Regenerate", systemImage: "arrow.clockwise")
            }
        }
    }

    @ViewBuilder
    private func bookmarkButton() -> some View {
        Button {
            guard let threadID = store.activeThreadID else { return }
            store.toggleBookmark(message.id, in: threadID)
        } label: {
            Label(
                message.isBookmarked == true ? "Unpin" : "Pin message",
                systemImage: message.isBookmarked == true ? "pin.fill" : "pin"
            )
        }
    }

    @ViewBuilder
    private func commentReplyButtons() -> some View {
        if let onComment {
            Button {
                onComment(message)
            } label: {
                Label("Comment", systemImage: "text.bubble")
            }
        }

        if let onReply {
            Button {
                onReply(message)
            } label: {
                Label("Reply", systemImage: "arrowshape.turn.up.left")
            }
        }
    }

    @ViewBuilder
    private func quickActionsMenu() -> some View {
        if message.role == .assistant {
            Menu {
                quickActionCopyAllCode()
                quickActionExtractTasks()
                Divider()
                quickActionSummarize()
                quickActionExplainSimply()
            } label: {
                Label("Quick Actions", systemImage: "bolt.circle")
            }
        }
    }

    @ViewBuilder
    private func quickActionCopyAllCode() -> some View {
        Button {
            let codeBlocks = MessageRow.extractCodeBlocks(from: message.text)
            if !codeBlocks.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(codeBlocks.joined(separator: "\n\n"), forType: .string)
            }
        } label: {
            Label("Copy All Code", systemImage: "chevron.left.forwardslash.chevron.right")
        }
        .disabled(MessageRow.extractCodeBlocks(from: message.text).isEmpty)
    }

    @ViewBuilder
    private func quickActionExtractTasks() -> some View {
        Button {
            let tasks = MessageRow.extractTasks(from: message.text)
            if !tasks.isEmpty {
                NSPasteboard.general.clearContents()
                NSPasteboard.general.setString(tasks.joined(separator: "\n"), forType: .string)
            }
        } label: {
            Label("Extract Tasks (\(MessageRow.extractTasks(from: message.text).count))", systemImage: "checklist")
        }
        .disabled(MessageRow.extractTasks(from: message.text).isEmpty)
    }

    @ViewBuilder
    private func quickActionSummarize() -> some View {
        Button {
            guard let threadID = store.activeThreadID, !client.isStreaming else { return }
            client.send("Summarize the above response in 3 bullet points.", threadID: threadID, store: store, modelManager: modelManager)
        } label: {
            Label("Summarize", systemImage: "text.justify.leading")
        }
        .disabled(client.isStreaming)
    }

    @ViewBuilder
    private func quickActionExplainSimply() -> some View {
        Button {
            guard let threadID = store.activeThreadID, !client.isStreaming else { return }
            client.send("Explain the above response in simpler terms, as if to a beginner.", threadID: threadID, store: store, modelManager: modelManager)
        } label: {
            Label("Explain Simply", systemImage: "lightbulb")
        }
        .disabled(client.isStreaming)
    }

    @ViewBuilder
    private func deleteButton() -> some View {
        if message.role == .assistant {
            Button(role: .destructive) {
                guard let threadID = store.activeThreadID else { return }
                store.deleteMessage(message.id, in: threadID)
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    private func submitEdit() {
        let text = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !client.isStreaming else { return }
        guard text != message.text.trimmingCharacters(in: .whitespacesAndNewlines) else {
            isEditing = false
            return
        }
        guard let threadID = store.activeThreadID else { return }
        isEditing = false
        showDiffConfirm = false
        client.editAndResend(message.id, newText: text, threadID: threadID, store: store, modelManager: modelManager)
    }

    /// Brief diff: find the changed substring between old and new text.
    /// Returns (removed, added) snippets capped at ~80 chars each.
    static func computeBriefDiff(old: String, new: String) -> (removed: String, added: String) {
        let oldChars = Array(old)
        let newChars = Array(new)
        var prefixLen = 0
        while prefixLen < oldChars.count && prefixLen < newChars.count && oldChars[prefixLen] == newChars[prefixLen] {
            prefixLen += 1
        }
        var suffixLen = 0
        while suffixLen < (oldChars.count - prefixLen) && suffixLen < (newChars.count - prefixLen)
              && oldChars[oldChars.count - 1 - suffixLen] == newChars[newChars.count - 1 - suffixLen] {
            suffixLen += 1
        }
        let removedRange = prefixLen ..< (oldChars.count - suffixLen)
        let addedRange = prefixLen ..< (newChars.count - suffixLen)
        let contextLen = 12
        let prefixContext = prefixLen > 0
            ? String(oldChars[max(0, prefixLen - contextLen) ..< prefixLen]) : ""
        let suffixContext = suffixLen > 0
            ? String(oldChars[(oldChars.count - suffixLen) ..< min(oldChars.count, oldChars.count - suffixLen + contextLen)]) : ""
        var removed = String(oldChars[removedRange])
        var added = String(newChars[addedRange])
        let cap = 80
        if removed.count > cap { removed = String(removed.prefix(cap)) + "..." }
        if added.count > cap { added = String(added.prefix(cap)) + "..." }
        let removedDisplay = prefixContext + removed + suffixContext
        let addedDisplay = prefixContext + added + suffixContext
        if removedDisplay.count > 200 {
            return (String(old.prefix(80)) + "...", String(new.prefix(80)) + "...")
        }
        return (removedDisplay, addedDisplay)
    }

    // MARK: - Timestamp & Model Badge Helpers

    private var relativeTimestamp: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: message.timestamp, relativeTo: Date())
    }

    /// Truncate long model IDs: "claude-sonnet-4-20251022" → "sonnet-4"
    private static func truncateModelID(_ raw: String) -> String {
        // Remove date suffixes like -20251022
        var id = raw
        if let range = id.range(of: #"-\d{8}$"#, options: .regularExpression) {
            id = String(id[id.startIndex..<range.lowerBound])
        }
        // Remove vendor prefix: "claude-" / "gpt-" / "gemini-" etc.
        let prefixes = ["claude-", "anthropic-", "openai-"]
        for prefix in prefixes {
            if id.hasPrefix(prefix) {
                id = String(id.dropFirst(prefix.count))
                break
            }
        }
        return id
    }

    private var isoTimestamp: String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f.string(from: message.timestamp)
    }

    private var fullTimestamp: String {
        message.timestamp.formatted(date: .abbreviated, time: .shortened)
    }

    @ViewBuilder
    private var metadataLine: some View {
        HStack(spacing: 0) {
            Text(relativeTimestamp)
                .foregroundStyle(timestampCopied ? Color.accentColor : V4Color.textSecondary)
                .help(fullTimestamp)
                .onTapGesture {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(isoTimestamp, forType: .string)
                    timestampCopied = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { timestampCopied = false }
                }
            if let modelID = message.modelID, !modelID.isEmpty {
                Text(" \u{00B7} ")
                Text(Self.truncateModelID(modelID))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(V4Color.textSecondary.opacity(V2Depth.bgSidebarHover))
                    .clipShape(SwiftUI.Capsule())
            }
        }
        .font(WernickeTypography.size10)
        .foregroundStyle(V4Color.textSecondary)
        .opacity(V2Depth.stateDisabled)
    }

    @ViewBuilder
    private var messageBodyContent: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
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
            } else if !searchQuery.isEmpty {
                // Use highlighted text when search is active
                HighlightText(message.text)
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

    // MARK: - Quick Action Helpers

    /// Extract all fenced code blocks from markdown text
    static func extractCodeBlocks(from text: String) -> [String] {
        var blocks: [String] = []
        let lines = text.components(separatedBy: "\n")
        var inBlock = false
        var current: [String] = []
        for line in lines {
            if line.hasPrefix("```") {
                if inBlock {
                    blocks.append(current.joined(separator: "\n"))
                    current = []
                    inBlock = false
                } else {
                    inBlock = true
                }
            } else if inBlock {
                current.append(line)
            }
        }
        return blocks
    }

    /// Extract task/checklist items from markdown text
    static func extractTasks(from text: String) -> [String] {
        var tasks: [String] = []
        let lines = text.components(separatedBy: "\n")
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- [ ] ") || trimmed.hasPrefix("- [x] ") || trimmed.hasPrefix("- [X] ") {
                tasks.append(trimmed)
            } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
                tasks.append(trimmed)
            } else if let first = trimmed.first, first.isNumber,
                      trimmed.contains(". ") {
                let dotIdx = trimmed.firstIndex(of: ".")!
                let afterDot = trimmed[trimmed.index(after: dotIdx)...]
                if afterDot.hasPrefix(" ") {
                    tasks.append(trimmed)
                }
            }
        }
        return tasks
    }

    /// Strip markdown formatting from text, returning plain text
    static func stripMarkdown(from text: String) -> String {
        var result = text

        // Remove code blocks but keep content
        result = result.replacingOccurrences(of: "```[\\w]*\\n([^`]*)```", with: "$1", options: .regularExpression)

        // Remove inline code
        result = result.replacingOccurrences(of: "`([^`]*)`", with: "$1", options: .regularExpression)

        // Remove headers
        result = result.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)

        // Remove bold/italic
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "__([^_]+)__", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)

        // Remove strikethrough
        result = result.replacingOccurrences(of: "~~([^~]+)~~", with: "$1", options: .regularExpression)

        // Remove links but keep text
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)

        // Clean up extra whitespace
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
    var onReply: ((ChatMessage) -> Void)? = nil

    @State private var isSpeaking = false
    @State private var didCopy = false
    @State private var synthesizer: AVSpeechSynthesizer?
    @State private var showRegenModelPicker = false
    @State private var showDislikeCategoryPopover = false

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
            HStack(spacing: ParietalSpacing.lg) {
                // Regenerate — always visible, long-press for model picker
                actionButton(
                    "arrow.clockwise",
                    tooltip: "Regenerate (long-press for model picker)",
                    active: hasError,
                    tint: hasError ? V4Color.statusError : nil
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
                    VStack(spacing: ParietalSpacing.xs) {
                        Text("Regenerate with")
                            .font(WernickeTypography.caption2Bold)
                            .foregroundStyle(Color.white.opacity(V1Theme.opacityTextSecondary))
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
                                        .font(WernickeTypography.size12)
                                    Spacer()
                                    if model.id == message.modelID {
                                        Text("current")
                                            .font(WernickeTypography.size9)
                                            .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                                    }
                                }
                                .foregroundStyle(Color.white)
                                .padding(.horizontal, LayoutConstants.cardPadding)
                                .padding(.vertical, LayoutConstants.compactPadding)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.bottom, 8)
                    .frame(minWidth: 200)
                    .background(V4Color.surface)
                }
                .onLongPressGesture(minimumDuration: 0.5) {
                    showRegenModelPicker = true
                }

                actionButton(isSpeaking ? "speaker.slash" : "speaker.wave.2", tooltip: isSpeaking ? "Stop" : "Read aloud") {
                    toggleSpeech()
                }

                // Enhanced copy menu
                CopyMenuView(
                    message: message,
                    onCopy: { content, _ in
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(content, forType: .string)
                    },
                    isShowing: .constant(false),
                    didCopy: $didCopy,
                    lastCopyAction: .constant(nil)
                )
                .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)

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

                actionButton("arrowshape.turn.up.left", tooltip: "Reply") {
                    onReply?(message)
                }

                actionButton(
                    message.isBookmarked == true ? "pin.fill" : "pin",
                    tooltip: "Pin message",
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
                    if isLiked == false {
                        // Already disliked — toggle off
                        store.toggleLike(message.id, liked: nil, in: threadID)
                    } else {
                        // Show category popover
                        showDislikeCategoryPopover = true
                    }
                }
                .popover(isPresented: $showDislikeCategoryPopover) {
                    DislikeCategoryPopover(
                        onSelect: { category in
                            showDislikeCategoryPopover = false
                            guard let threadID = store.activeThreadID else { return }
                            store.toggleLike(message.id, liked: false, in: threadID)
                            store.setFeedbackCategory(category, for: message.id, in: threadID)
                            // Also show text feedback for custom input
                            client.showRejectionFeedback = (messageID: message.id, threadID: threadID)
                        },
                        onDismiss: {
                            showDislikeCategoryPopover = false
                        }
                    )
                }
            }

            Spacer()

            // Persisted metrics badge + cost
            if let ttfb = message.ttfbMs, let tps = message.tokPerSec, let tok = message.outputTokens {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Text("\(ttfb)ms")
                        .foregroundStyle(V4Color.textSecondary)
                    Text(String(format: "%.0f tok/s", tps))
                        .foregroundStyle(V4Color.accent)
                    Text("\(tok) tok")
                        .foregroundStyle(V4Color.textSecondary)
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
                                .foregroundStyle(V4Color.golden)
                        }
                    }
                }
                .font(WernickeTypography.microMono)
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
                .font(WernickeTypography.size13)
                .foregroundStyle(tint ?? (active ? V4Color.accent : Color.white.opacity(V1Theme.opacityTextTertiary)))
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
                .font(WernickeTypography.size10)
            Text(name)
                .font(WernickeTypography.caption2Medium)
        }
        .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
        .padding(.horizontal, ParietalSpacing.xs)
        .padding(.vertical, ParietalSpacing.xxs)
        .background(Color.white.opacity(V2Depth.bgCard))
        .clipShape(SwiftUI.Capsule())
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
    var onQuickInsert: ((String) -> Void)?
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

    private let quickActions: [(icon: String, label: String)] = [
        ("chevron.left.forwardslash.chevron.right", "Write code"),
        ("ladybug", "Debug issue"),
        ("lightbulb", "Explain concept"),
        ("doc.text.magnifyingglass", "Review PR"),
    ]

    var body: some View {
        VStack(spacing: ParietalSpacing.xl) {
            Spacer(minLength: 60)

            // Logo
            Text("\u{1F451}")
                .font(WernickeTypography.size56)

            Text("Queen")
                .font(WernickeTypography.h2Semibold)
                .foregroundStyle(Color.white)
            Text("Start a conversation")
                .font(WernickeTypography.size15)
                .foregroundStyle(V4Color.textSecondary)

            // Quick action chips
            HStack(spacing: ParietalSpacing.sm + 2) {
                ForEach(quickActions, id: \.label) { action in
                    Button {
                        onQuickInsert?(action.label)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: action.icon)
                                .font(WernickeTypography.size11)
                                .foregroundStyle(V4Color.accent)
                            Text(action.label)
                                .font(WernickeTypography.size12)
                                .foregroundStyle(V4Color.white70)
                        }
                        .padding(.horizontal, LayoutConstants.cardPadding)
                        .padding(.vertical, LayoutConstants.standardPadding)
                        .background(Color.white.opacity(V2Depth.bgCardLight))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Contextual suggestion chips grid
            VStack(spacing: ParietalSpacing.sm + 2) {
                HStack(spacing: ParietalSpacing.sm + 2) {
                    ForEach(0..<3) { i in
                        suggestionChip(suggestions[i])
                    }
                }
                HStack(spacing: ParietalSpacing.sm + 2) {
                    ForEach(3..<6) { i in
                        suggestionChip(suggestions[i])
                    }
                }
            }
            .padding(.top, 8)

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
            HStack(spacing: ParietalSpacing.sm - 2) {
                Text(emoji)
                    .font(WernickeTypography.size13)
                Text(text)
                    .font(WernickeTypography.size12)
                    .foregroundStyle(V4Color.white70)
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.white.opacity(V2Depth.bgCardLight))
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
    var onSlashTrigger: ((String?) -> Void)? = nil  // trigger /command popup (nil = dismiss)

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.isEditable = true
        textView.isSelectable = true
        textView.font = NSFont.systemFont(ofSize: 15)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        // FIXED: disable vertical resizing for compact single-line input
        textView.isVerticallyResizable = false
        textView.isHorizontallyResizable = false
        // FIXED: compression resistance for horizontal
        textView.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // FIXED: fixed container size - no expansion
        textView.textContainer?.containerSize = NSSize(width: 400, height: ParietalSpacing.inputHeight)
        textView.textContainer?.heightTracksTextView = true
        textView.textContainer?.widthTracksTextView = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.insertionPointColor = .white
        // FIXED: allow proper text container sizing
        textView.setFrameSize(NSSize(width: 400, height: ParietalSpacing.inputHeight))

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        // FIXED: proper scrollview frame for input
        scrollView.setFrameSize(NSSize(width: 400, height: ParietalSpacing.inputHeight))

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
        context.coordinator.onSlashTrigger = onSlashTrigger

        // Update placeholder visibility
        context.coordinator.updatePlaceholder()

        if isFocused.wrappedValue {
            DispatchQueue.main.async {
                textView.window?.makeFirstResponder(textView)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(text: $text, onSubmit: onSubmit, placeholder: placeholder, onImagePaste: onImagePaste, onMentionTrigger: onMentionTrigger, onSlashTrigger: onSlashTrigger)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        @Binding var text: String
        var onSubmit: () -> Void
        var placeholder: String
        var onImagePaste: ((String, String) -> Void)?
        var onMentionTrigger: ((String?) -> Void)?
        var onSlashTrigger: ((String?) -> Void)?
        weak var textView: NSTextView?
        private var placeholderLayer: CATextLayer?

        init(text: Binding<String>, onSubmit: @escaping () -> Void, placeholder: String, onImagePaste: ((String, String) -> Void)? = nil, onMentionTrigger: ((String?) -> Void)? = nil, onSlashTrigger: ((String?) -> Void)? = nil) {
            self._text = text
            self.onSubmit = onSubmit
            self.placeholder = placeholder
            self.onImagePaste = onImagePaste
            self.onMentionTrigger = onMentionTrigger
            self.onSlashTrigger = onSlashTrigger
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

            // Detect / slash command trigger
            var slashDetected = false
            if cursorPos > 0 && cursorPos <= str.count {
                let idx = str.index(str.startIndex, offsetBy: cursorPos)
                let before = str[str.startIndex..<idx]
                // Check if current line starts with /
                if let newlineRange = before.range(of: "\n", options: .backwards) {
                    let afterNewline = String(before[newlineRange.upperBound...])
                    if afterNewline.hasPrefix("/") {
                        let query = String(afterNewline.dropFirst())
                        if !query.contains(" ") {
                            onSlashTrigger?(query)
                            slashDetected = true
                        }
                    }
                } else if before.hasPrefix("/") {
                    // First line starts with /
                    let query = String(before.dropFirst())
                    if !query.contains(" ") {
                        onSlashTrigger?(query)
                        slashDetected = true
                    }
                }
            }
            if !slashDetected {
                onSlashTrigger?(String?.none)  // dismiss popup
            }

            // Constrain height to ~5 lines
            if let container = textView.textContainer, let layoutManager = textView.layoutManager {
                layoutManager.ensureLayout(for: container)
                let rect = layoutManager.usedRect(for: container)
                let maxHeight: CGFloat = 120  // ~5 lines
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
            placeholderLayer?.frame = CGRect(x: 5, y: 0, width: textView.bounds.width - 10, height: ParietalSpacing.iconHeight)
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
                        HStack(spacing: ParietalSpacing.sm) {
                            Image(systemName: item.icon)
                                .font(WernickeTypography.size11)
                                .foregroundStyle(V4Color.accent)
                                .frame(width: ParietalSpacing.icon)
                            Text(item.label)
                                .font(WernickeTypography.size12)
                                .foregroundStyle(V4Color.white80)
                                .lineLimit(1)
                            Spacer()
                            if let badge = item.badge {
                                Text(badge)
                                    .font(WernickeTypography.miniMono)
                                    .foregroundStyle(badge == "FAIL" ? Color.red : V4Color.accent)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.white.opacity(V2Depth.bgCard))
                                    .clipShape(SwiftUI.Capsule())
                            }
                        }
                        .padding(.horizontal, ParietalSpacing.xs)
                        .padding(.vertical, LayoutConstants.compactPadding)
                        .contentShape(Rectangle())
                        .background(idx == selectedIndex ? Color.white.opacity(0.08) : Color.clear)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: 340)
                .frame(minWidth: 280)
                .background(V4Color.surface)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.white.opacity(V2Depth.bgSubtle), lineWidth: 1)
            )
            .shadow(color: .black.opacity(V1Theme.opacityTextTertiary), radius: 12)
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
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "link")
                        .font(WernickeTypography.size11)
                    Text("Sources (\(citations.count))")
                        .font(WernickeTypography.captionMedium)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(WernickeTypography.size9)
                    Spacer()
                }
                .foregroundStyle(V4Color.accent)
                .padding(.horizontal, LayoutConstants.cardPadding)
                .padding(.vertical, LayoutConstants.standardPadding)
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                    ForEach(Array(citations.prefix(6).enumerated()), id: \.element.id) { idx, citation in
                        HStack(spacing: ParietalSpacing.sm) {
                            Text("\(idx + 1)")
                                .font(WernickeTypography.miniBoldMono)
                                .foregroundStyle(V4Color.accent)
                                .frame(width: ParietalSpacing.icon)

                            VStack(alignment: .leading, spacing: ParietalSpacing.xxxxs) {
                                if let domain = citation.domain {
                                    Text(domain)
                                        .font(WernickeTypography.caption2Medium)
                                        .foregroundStyle(V4Color.white70)
                                }
                                Text(citation.url)
                                    .font(WernickeTypography.size10)
                                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
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
                                    .font(WernickeTypography.size10)
                                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, LayoutConstants.cardPadding)
                        .padding(.vertical, ParietalSpacing.xxs)
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .background(V4Color.accent.opacity(0.05))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(V4Color.accent.opacity(V2Depth.bgSidebarHover), lineWidth: 1)
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
            HStack(spacing: ParietalSpacing.xs) {
                Button {
                    let prev = max(currentIndex - 1, 0)
                    store.switchBranch(message.id, toIndex: prev, in: threadID)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(WernickeTypography.microBold)
                        .foregroundStyle(currentIndex > 0 ? Color.white.opacity(V1Theme.opacityTextSecondary) : V4Color.white20)
                }
                .buttonStyle(.plain)
                .disabled(currentIndex <= 0)
                .accessibilityLabel("Previous branch")
                .accessibilityHint("Shows the previous response branch")

                Text("\(currentIndex + 1)/\(branchCount)")
                    .font(WernickeTypography.miniMono)
                    .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))

                Button {
                    let next = min(currentIndex + 1, branchCount - 1)
                    store.switchBranch(message.id, toIndex: next, in: threadID)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(WernickeTypography.microBold)
                        .foregroundStyle(currentIndex < branchCount - 1 ? Color.white.opacity(V1Theme.opacityTextSecondary) : V4Color.white20)
                }
                .buttonStyle(.plain)
                .disabled(currentIndex >= branchCount - 1)
                .accessibilityLabel("Next branch, \(currentIndex + 1) of \(branchCount)")
                .accessibilityHint("Shows the next response branch")
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(Color.white.opacity(V2Depth.bgCard))
            .clipShape(SwiftUI.Capsule())
        }
    }
}

// MARK: - Thinking Block View (Feature 1)

struct ThinkingBlockView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let text: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Toggle header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(WernickeTypography.miniSemibold)
                        .foregroundStyle(V4Color.accent)
                    Text("\u{1F4AD} Thinking")
                        .font(WernickeTypography.captionMedium)
                        .foregroundStyle(V4Color.textSecondary)
                    Text("(\(text.count) chars)")
                        .font(WernickeTypography.size10)
                        .foregroundStyle(V4Color.textSecondary.opacity(V1Theme.opacityTextSecondary))
                    Spacer()
                }
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, LayoutConstants.standardPadding)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isExpanded ? "Hide thinking process" : "Show thinking process")
            .accessibilityHint(isExpanded ? "Collapses the thinking block" : "Expands the thinking block")

            // Collapsible body
            if isExpanded {
                ScrollView {
                    Text(text)
                        .font(WernickeTypography.size12Mono)
                        .foregroundStyle(V4Color.textPrimary.opacity(0.7))
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, LayoutConstants.cardPadding)
                        .padding(.vertical, LayoutConstants.standardPadding)
                }
                .frame(maxHeight: 300)
                .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
        .overlay(
            // Left accent border (blockquote style)
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(V4Color.accent.opacity(V1Theme.opacityTextSecondary))
                    .frame(width: ParietalSpacing.dividerThickness)
                Spacer()
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                .stroke(V4Color.bgCardBorder, lineWidth: 1)
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
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: "clock.badge.exclamationmark")
                    .font(WernickeTypography.size10)
                Text("Stale data")
                    .font(WernickeTypography.miniMedium)

                Button {
                    guard let threadID = store.activeThreadID else { return }
                    client.regenerate(threadID: threadID, store: store, modelManager: modelManager)
                } label: {
                    Text("Re-ask")
                        .font(WernickeTypography.miniBold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, ParietalSpacing.xs)
                        .padding(.vertical, 3)
                        .background(V4Color.statusWarn)
                        .clipShape(SwiftUI.Capsule())
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(V4Color.statusWarn)
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
            HStack(spacing: ParietalSpacing.sm + 2) {
                Image(systemName: "xmark.octagon.fill")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.statusError)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Build is broken")
                        .font(WernickeTypography.captionBold)
                        .foregroundStyle(V4Color.statusError)
                    if let summary = ctx.buildErrorSummary() {
                        Text(String(summary.prefix(100)))
                            .font(WernickeTypography.size10Mono)
                            .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                            .lineLimit(2)
                    }
                }

                Spacer()

                Button {
                    let error = ctx.buildErrorSummary() ?? "Build is broken"
                    let prompt = "The build is broken. Fix this error:\n\n```\n\(error)\n```"
                    onFix(prompt)
                } label: {
                    HStack(spacing: ParietalSpacing.xs) {
                        Image(systemName: "wrench.fill")
                            .font(WernickeTypography.size10)
                        Text("Fix this?")
                            .font(WernickeTypography.caption2Bold)
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, LayoutConstants.cardPadding)
                    .padding(.vertical, LayoutConstants.compactPadding)
                    .background(V4Color.statusError)
                    .clipShape(SwiftUI.Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(LayoutConstants.cardPadding)
            .background(V4Color.statusError.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(V4Color.statusError.opacity(V2Depth.stateHover), lineWidth: 1)
            )
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            .padding(.bottom, 8)
        }
    }
}

// MARK: - Memory Proposal Card (Feature 8)

struct MemoryProposalCard: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let memories: [MemoryEntry]
    var onAccept: (MemoryEntry) -> Void
    var onDismiss: (MemoryEntry) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: "brain.head.profile")
                    .font(WernickeTypography.size11)
                Text("Remember this?")
                    .font(WernickeTypography.caption2Bold)
            }
            .foregroundStyle(V4Color.purple)

            ForEach(memories) { entry in
                HStack(spacing: ParietalSpacing.sm) {
                    Text(String(entry.text.prefix(80)))
                        .font(WernickeTypography.size11)
                        .foregroundStyle(V4Color.white70)
                        .lineLimit(2)

                    Spacer()

                    Button {
                        onAccept(entry)
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .font(WernickeTypography.size14)
                            .foregroundStyle(V4Color.statusOK)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDismiss(entry)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(WernickeTypography.size14)
                            .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, ParietalSpacing.xxs)
            }
        }
        .padding(LayoutConstants.compactPadding)
        .background(V4Color.purple.opacity(V2Depth.bgCard))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(V4Color.purple.opacity(0.2), lineWidth: 1)
        )
        .transition(reduceMotion ? .opacity : .opacity.combined(with: .move(edge: .bottom)))
    }
}

// MARK: - Streaming Elapsed Timer (Feature W6-1)

struct StreamingElapsedTimer: View {
    @State private var elapsed: Int = 0

    var body: some View {
        Text("\(elapsed)s")
            .font(WernickeTypography.miniMono)
            .foregroundStyle(elapsed > 10 ? V4Color.statusWarn : V4Color.textSecondary)
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
        HStack(spacing: ParietalSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(WernickeTypography.size12)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))

            TextField("Find in thread...", text: $query)
                .textFieldStyle(.plain)
                .font(WernickeTypography.size13)
                .foregroundStyle(Color.white)
                .focused($isFocused)
                .onSubmit { if currentIndex < totalMatches - 1 { currentIndex += 1 } }

            if !query.isEmpty {
                Text(totalMatches > 0 ? "\(currentIndex + 1) of \(totalMatches)" : "No matches")
                    .font(WernickeTypography.caption2MediumMono)
                    .foregroundStyle(totalMatches > 0 ? V4Color.accent : V4Color.statusError)
                    .fixedSize()

                Button {
                    if currentIndex > 0 { currentIndex -= 1 }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(WernickeTypography.caption2Bold)
                        .foregroundStyle(currentIndex > 0 ? Color.white : V4Color.white20)
                }
                .buttonStyle(.plain)
                .disabled(currentIndex <= 0)

                Button {
                    if currentIndex < totalMatches - 1 { currentIndex += 1 }
                } label: {
                    Image(systemName: "chevron.down")
                        .font(WernickeTypography.caption2Bold)
                        .foregroundStyle(currentIndex < totalMatches - 1 ? Color.white : V4Color.white20)
                }
                .buttonStyle(.plain)
                .disabled(currentIndex >= totalMatches - 1)
            }

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(WernickeTypography.size11)
                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, LayoutConstants.cardPadding)
        .padding(.vertical, LayoutConstants.compactPadding)
        .background(V4Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
        .padding(.vertical, ParietalSpacing.xxs)
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
        if elapsedMs < 2000 { return V4Color.textSecondary }
        if elapsedMs < 5000 { return V4Color.statusWarn }
        return V4Color.statusError
    }

    var body: some View {
        if isWaiting {
            HStack(spacing: 3) {
                Circle()
                    .fill(color)
                    .frame(width: ParietalSpacing.microIndicator, height: 5)
                Text(elapsedMs < 1000 ? "\(elapsedMs)ms" : String(format: "%.1fs", Double(elapsedMs) / 1000.0))
                    .font(WernickeTypography.miniMono)
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

// MARK: - Live Speed Indicator (color-coded tok/s during streaming)

struct LiveSpeedIndicator: View {
    let tokPerSec: Double

    private var speedColor: Color {
        if tokPerSec < 20 { return V4Color.statusError }
        if tokPerSec < 50 { return V4Color.statusWarn }
        return V4Color.statusOK
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: "bolt.fill")
                .font(WernickeTypography.size8)
                .foregroundStyle(speedColor)
            Text(String(format: "%.0f tok/s", tokPerSec))
                .font(WernickeTypography.miniBoldMono)
                .foregroundStyle(speedColor)
        }
        .contentTransition(.numericText(countsDown: false))
        .animation(.easeInOut(duration: 0.3), value: Int(tokPerSec))
    }
}

// MARK: - Network Dashboard (Feature W6-2)

struct NetworkDashboard: View {
    @ObservedObject var client: ChatClient
    @ObservedObject var modelManager: ModelManager
    @ObservedObject var store: ThreadStore
    @StateObject private var networkLog = NetworkLog.shared
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "network")
                        .font(WernickeTypography.size10)
                    Text("Network")
                        .font(WernickeTypography.caption2Bold)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(WernickeTypography.size8)
                }
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextSecondary))
                .padding(.horizontal, LayoutConstants.cardPadding)
                .padding(.vertical, LayoutConstants.standardPadding)
            }
            .buttonStyle(.plain)

            if isExpanded {
                ScrollView {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        providerRows
                        failoverHistory
                        offlineQueueSection
                    }
                    .padding(.horizontal, LayoutConstants.cardPadding)
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
                HStack(spacing: ParietalSpacing.xs) {
                    Circle()
                        .fill(status.isUp ? V4Color.statusOK : V4Color.statusError)
                        .frame(width: ParietalSpacing.microIndicator, height: 5)
                    Text(status.name)
                        .font(WernickeTypography.miniMedium)
                        .foregroundStyle(V4Color.white70)
                    Spacer()
                    if let remaining = status.remainingRequests {
                        Text("\(remaining) left")
                            .font(WernickeTypography.size8Mono)
                            .foregroundStyle(remaining < 10 ? V4Color.statusError : V4Color.textSecondary)
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
                                .font(WernickeTypography.tiny8Bold)
                                .foregroundStyle(.black)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(V4Color.accent)
                                .clipShape(SwiftUI.Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                HStack(spacing: ParietalSpacing.sm) {
                    Text("\(stats.requests) req")
                        .font(WernickeTypography.size8Mono)
                    if stats.errors > 0 {
                        Text("\(stats.errors) err")
                            .font(WernickeTypography.size8Mono)
                            .foregroundStyle(V4Color.statusError)
                    }
                    if stats.avgTTFB > 0 {
                        Text("\(stats.avgTTFB)ms")
                            .font(WernickeTypography.size8Mono)
                    }
                    if stats.avgTPS > 0 {
                        Text(String(format: "%.0f t/s", stats.avgTPS))
                            .font(WernickeTypography.size8Mono)
                            .foregroundStyle(V4Color.accent)
                    }
                }
                .foregroundStyle(V4Color.textSecondary)

                // TTFB sparkline
                let ttfbs = networkLog.recentTTFBForProvider(status.name, count: 10)
                if ttfbs.count >= 2 {
                    TTFBSparkline(values: ttfbs)
                        .frame(height: ParietalSpacing.icon)
                }
            }
            .padding(.vertical, ParietalSpacing.xxs)
        }
    }

    @ViewBuilder
    private var failoverHistory: some View {
        if !client.failoverLog.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                Text("Failover Log")
                    .font(WernickeTypography.microBold)
                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                ForEach(Array(client.failoverLog.suffix(5).reversed().enumerated()), id: \.offset) { _, event in
                    HStack(spacing: ParietalSpacing.xs) {
                        Text(event.from)
                            .foregroundStyle(V4Color.statusError)
                        Image(systemName: "arrow.right")
                            .font(WernickeTypography.size6)
                        Text(event.to)
                            .foregroundStyle(V4Color.statusOK)
                        Spacer()
                        Text(event.timestamp, style: .time)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .font(WernickeTypography.size8Mono)
                }
            }
            .padding(.top, 4)
        }
    }

    @ViewBuilder
    private var offlineQueueSection: some View {
        if !client.offlineQueue.isEmpty {
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Text("Offline Queue (\(client.offlineQueue.count))")
                    .font(WernickeTypography.microBold)
                    .foregroundStyle(V4Color.statusWarn)
                ForEach(client.offlineQueue) { queued in
                    HStack(spacing: ParietalSpacing.xs) {
                        Text(String(queued.text.prefix(30)))
                            .font(WernickeTypography.size8)
                            .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            client.cancelQueued(queued.id)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(WernickeTypography.size9)
                                .foregroundStyle(V4Color.statusError)
                        }
                        .buttonStyle(.plain)
                    }
                }

                HStack {
                    Spacer()
                    Button {
                        store.newThread()
                    } label: {
                        Text("New thread")
                            .font(WernickeTypography.miniBold)
                            .foregroundStyle(V4Color.accent)
                            .padding(.horizontal, ParietalSpacing.xs)
                            .padding(.vertical, ParietalSpacing.xxs)
                            .background(Color.white.opacity(0.08))
                            .clipShape(SwiftUI.Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(LayoutConstants.compactPadding)
            .background(V4Color.golden.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(V4Color.golden.opacity(V2Depth.stateHover), lineWidth: 1)
            )
            .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
            .padding(.bottom, 6)
        }
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
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: "gauge.with.needle.fill")
                    .font(WernickeTypography.size10)
                Text("\(w.provider): \(w.remaining) requests left")
                    .font(WernickeTypography.miniMedium)

                if let eta = networkLog.rateLimitETA(w.provider) {
                    Text("(~\(eta) min)")
                        .font(WernickeTypography.size9Mono)
                        .foregroundStyle(eta < 5 ? V4Color.statusError : V4Color.statusWarn)
                }

                if let fallback = modelManager.failoverModel() {
                    Button {
                        modelManager.selectedModel = fallback
                        modelManager.persistSelection()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(WernickeTypography.size8)
                            Text("Switch to \(fallback.displayName)")
                                .font(WernickeTypography.microBold)
                        }
                        .foregroundStyle(.black)
                        .padding(.horizontal, ParietalSpacing.xs)
                        .padding(.vertical, 3)
                        .background(V4Color.statusWarn)
                        .clipShape(SwiftUI.Capsule())
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
            .foregroundStyle(V4Color.statusWarn)
            .padding(.horizontal, LayoutConstants.standardPadding)
            .padding(.vertical, ParietalSpacing.xxs)
            .background(V4Color.statusWarn.opacity(V2Depth.bgCard))
        }
    }
}

// MARK: - Branch Pill (shows current git branch)

struct BranchPill: View {
    @State private var branch: String = ""

    var body: some View {
        Group {
            if !branch.isEmpty && branch != "main" {
                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: "arrow.triangle.branch")
                        .font(WernickeTypography.size8)
                    Text(branch)
                        .font(WernickeTypography.microMono)
                }
                .foregroundStyle(V4Color.purple)
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, 3)
                .background(V4Color.purple.opacity(V2Depth.bgSubtle))
                .clipShape(SwiftUI.Capsule())
                .padding(.horizontal, LayoutConstants.standardPadding)
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
            HStack(spacing: ParietalSpacing.sm - 2) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button {
                        onSelect(suggestion)
                    } label: {
                        HStack(spacing: ParietalSpacing.xs) {
                            Image(systemName: "arrow.turn.down.right")
                                .font(WernickeTypography.size9)
                            Text(suggestion)
                                .font(WernickeTypography.caption2Medium)
                        }
                        .foregroundStyle(V4Color.white70)
                        .padding(.horizontal, ParietalSpacing.xs)
                        .padding(.vertical, 5)
                        .background(Color.white.opacity(V2Depth.bgCard))
                        .clipShape(SwiftUI.Capsule())
                        .overlay(
                            SwiftUI.Capsule()
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.vertical, ParietalSpacing.xxs)
    }
}

// MARK: - Rejection Feedback (tell Queen what to do instead)

struct RejectionFeedbackView: View {
    @State private var feedback = ""
    @FocusState private var isFocused: Bool
    var onSubmit: (String) -> Void
    var onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack {
                Image(systemName: "hand.thumbsdown.fill")
                    .font(WernickeTypography.size12)
                    .foregroundStyle(V4Color.statusError)
                Text("Tell Queen what to do instead:")
                    .font(WernickeTypography.captionMedium)
                    .foregroundStyle(V4Color.textPrimary)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size10)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: ParietalSpacing.sm) {
                TextField("e.g. Be more concise, use code examples...", text: $feedback)
                    .textFieldStyle(.plain)
                    .font(WernickeTypography.size13)
                    .foregroundStyle(Color.white)
                    .padding(LayoutConstants.compactPadding)
                    .background(Color.white.opacity(V2Depth.bgCard))
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
                        .font(WernickeTypography.captionBold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, LayoutConstants.cardPadding)
                        .padding(.vertical, LayoutConstants.compactPadding)
                        .background(V4Color.statusError)
                        .clipShape(SwiftUI.Capsule())
                }
                .buttonStyle(.plain)
            }
        }
        .padding(LayoutConstants.cardPadding)
        .background(V4Color.statusError.opacity(V2Depth.bgCard))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
        .onAppear { isFocused = true }
    }
}

// MARK: - Pinned Messages Strip

struct PinnedMessagesStrip: View {
    let messages: [ChatMessage]
    var onScrollTo: (UUID) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: "pin.fill")
                    .font(WernickeTypography.size10)
                    .foregroundStyle(V4Color.accent)

                ForEach(messages) { msg in
                    Button {
                        onScrollTo(msg.id)
                    } label: {
                        Text(String(msg.text.prefix(50)).replacingOccurrences(of: "\n", with: " "))
                            .font(WernickeTypography.size11)
                            .foregroundStyle(V4Color.white80)
                            .lineLimit(1)
                            .padding(.horizontal, ParietalSpacing.xs)
                            .padding(.vertical, ParietalSpacing.xxs)
                            .background(V4Color.accent.opacity(0.12))
                            .clipShape(SwiftUI.Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, LayoutConstants.standardPadding)
            .padding(.vertical, LayoutConstants.compactPadding)
        }
        .background(V4Color.background.opacity(0.9))
    }
}

// MARK: - Dislike Category Popover

struct DislikeCategoryPopover: View {
    var onSelect: (String) -> Void
    var onDismiss: () -> Void

    private let categories = [
        ("Inaccurate", "exclamationmark.triangle"),
        ("Not helpful", "hand.thumbsdown"),
        ("Too long", "text.badge.minus"),
        ("Incomplete", "text.badge.plus"),
        ("Wrong tone", "quote.bubble"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Text("What went wrong?")
                .font(WernickeTypography.caption2Bold)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextSecondary))
                .padding(.horizontal, LayoutConstants.cardPadding)
                .padding(.top, 8)

            ForEach(categories, id: \.0) { category, icon in
                Button {
                    onSelect(category)
                } label: {
                    HStack(spacing: ParietalSpacing.sm) {
                        Image(systemName: icon)
                            .font(WernickeTypography.size11)
                            .frame(width: ParietalSpacing.icon)
                        Text(category)
                            .font(WernickeTypography.size12)
                    }
                    .foregroundStyle(Color.white)
                    .padding(.horizontal, LayoutConstants.cardPadding)
                    .padding(.vertical, LayoutConstants.compactPadding)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .background(Color.white.opacity(0.001))
            }

            Divider()
                .background(Color.white.opacity(V2Depth.bgSubtle))
                .padding(.horizontal, ParietalSpacing.xs)

            Button {
                onDismiss()
            } label: {
                Text("Cancel")
                    .font(WernickeTypography.size11)
                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                    .padding(.horizontal, LayoutConstants.cardPadding)
                    .padding(.vertical, ParietalSpacing.xxs)
            }
            .buttonStyle(.plain)
        }
        .padding(.bottom, 8)
        .frame(minWidth: 180)
        .background(V4Color.surface)
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

// MARK: - Queen Thinking Indicator

struct QueenThinkingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var opacity: Double = 0.3

    var body: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            Text("\u{25CF}\u{25CF}\u{25CF}")
                .foregroundColor(V4Color.accent)
                .opacity(reduceMotion ? 0.7 : opacity)
            Text("Queen is thinking...")
                .foregroundColor(V4Color.textSecondary)
                .italic()
                .font(.caption)
        }
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 0.75).repeatForever(autoreverses: true)) {
                opacity = 1.0
            }
        }
    }
}

// MARK: - Tool Execution Timeline

struct ToolTimeline: View {
    let steps: [ChatClient.ToolCallStep]

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            ForEach(steps) { step in
                HStack(spacing: ParietalSpacing.sm) {
                    // Status icon
                    Group {
                        switch step.status {
                        case .running:
                            ProgressView()
                                .scaleEffect(0.5)
                                .frame(width: ParietalSpacing.mediumBadge, height: ParietalSpacing.badgeHeight)
                        case .success:
                            Image(systemName: "checkmark.circle.fill")
                                .font(WernickeTypography.size11)
                                .foregroundStyle(V4Color.statusOK)
                        case .error:
                            Image(systemName: "xmark.circle.fill")
                                .font(WernickeTypography.size11)
                                .foregroundStyle(V4Color.statusError)
                        }
                    }
                    .frame(width: ParietalSpacing.xSmallFrame)

                    // Tool name
                    Text(step.name)
                        .font(WernickeTypography.miniBoldMono)
                        .foregroundStyle(V4Color.accent)

                    // Args
                    Text(step.args)
                        .font(WernickeTypography.size10Mono)
                        .foregroundStyle(V4Color.textSecondary)
                        .lineLimit(1)

                    Spacer()

                    // Duration
                    let elapsed = Date().timeIntervalSince(step.startTime)
                    if elapsed > 0.5 {
                        Text(String(format: "%.1fs", elapsed))
                            .font(WernickeTypography.size9Mono)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }
            }
        }
        .padding(LayoutConstants.compactPadding)
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.vertical, ParietalSpacing.xxs)
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
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: "wifi.slash")
                    .font(WernickeTypography.size12)
                    .foregroundStyle(V4Color.statusWarn)
                Text("\(count) message\(count == 1 ? "" : "s") queued")
                    .font(WernickeTypography.captionMedium)
                    .foregroundStyle(V4Color.statusWarn)
                Text("Retrying every 15s...")
                    .font(WernickeTypography.size10)
                    .foregroundStyle(V4Color.textSecondary)
                Spacer()
                if count > 1 {
                    Button {
                        withAnimation { isExpanded.toggle() }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(WernickeTypography.size9)
                            .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                    }
                    .buttonStyle(.plain)
                }
                Button {
                    onCancelAll()
                } label: {
                    Text("Cancel All")
                        .font(WernickeTypography.miniBold)
                        .foregroundStyle(V4Color.statusError)
                        .padding(.horizontal, ParietalSpacing.xs)
                        .padding(.vertical, 3)
                        .background(V4Color.statusError.opacity(0.12))
                        .clipShape(SwiftUI.Capsule())
                }
                .buttonStyle(.plain)
            }

            // Per-message queue detail
            if isExpanded {
                ForEach(queue) { msg in
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        Image(systemName: "clock")
                            .font(WernickeTypography.size9)
                            .foregroundStyle(V4Color.statusWarn)
                        Text(String(msg.text.prefix(60)))
                            .font(WernickeTypography.size10)
                            .foregroundStyle(Color.white.opacity(V1Theme.opacityTextSecondary))
                            .lineLimit(1)
                        Spacer()
                        Button {
                            onCancelOne?(msg.id)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .font(WernickeTypography.size10)
                                .foregroundStyle(V4Color.statusError.opacity(V1Theme.opacityTextSecondary))
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding(.horizontal, LayoutConstants.cardPadding)
        .padding(.vertical, LayoutConstants.compactPadding)
        .background(V4Color.statusWarn.opacity(V2Depth.bgCard))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, LayoutConstants.messageHorizontalPadding)
    }
}

// MARK: - Elicitation Card (Queen asks structured questions)

struct ElicitationCard: View {
    let question: String
    let options: [String]
    var onSelect: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm + 2) {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: "questionmark.circle.fill")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.purple)
                Text(question)
                    .font(WernickeTypography.smallMedium)
                    .foregroundStyle(V4Color.textPrimary)
            }

            HStack(spacing: ParietalSpacing.sm) {
                ForEach(options, id: \.self) { option in
                    Button {
                        onSelect(option)
                    } label: {
                        Text(option)
                            .font(WernickeTypography.captionMedium)
                            .foregroundStyle(V4Color.white80)
                            .padding(.horizontal, LayoutConstants.cardPadding)
                            .padding(.vertical, LayoutConstants.compactPadding)
                            .background(V4Color.purple.opacity(V2Depth.bgSidebarHover))
                            .clipShape(SwiftUI.Capsule())
                            .overlay(
                                SwiftUI.Capsule()
                                    .stroke(V4Color.purple.opacity(V2Depth.stateHover), lineWidth: 1)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(LayoutConstants.cardPadding)
        .background(V4Color.purple.opacity(V2Depth.bgCard))
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
                    .font(WernickeTypography.size16)
                    .foregroundStyle(V4Color.purple)
                Text("Thinking Transcript")
                    .font(.headline)
                    .foregroundStyle(V4Color.textPrimary)
                Spacer()
                Button {
                    // Copy all thinking to clipboard
                    let all = thinkingEntries.map { "[\($0.model)]\n\($0.thinking)" }.joined(separator: "\n\n---\n\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(all, forType: NSPasteboard.PasteboardType.string)
                    SoundCueManager.shared.playCopy()
                } label: {
                    HStack(spacing: ParietalSpacing.xs) {
                        Image(systemName: "doc.on.doc")
                        Text("Copy All")
                    }
                    .font(WernickeTypography.size12)
                    .foregroundStyle(V4Color.accent)
                }
                .buttonStyle(.plain)
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size16)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
                .buttonStyle(.plain)
            }
            .padding()

            if thinkingEntries.isEmpty {
                VStack(spacing: ParietalSpacing.md) {
                    Image(systemName: "brain.head.profile")
                        .font(WernickeTypography.size32)
                        .foregroundStyle(V4Color.white20)
                    Text("No thinking data in this thread")
                        .font(WernickeTypography.size14)
                        .foregroundStyle(V4Color.textSecondary)
                    Text("Use Reason mode or High/Max effort to enable extended thinking")
                        .font(WernickeTypography.size12)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ParietalSpacing.lg) {
                        ForEach(Array(thinkingEntries.enumerated()), id: \.offset) { idx, entry in
                            VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
                                HStack {
                                    Text("Turn \(idx + 1)")
                                        .font(WernickeTypography.caption2Bold)
                                        .foregroundStyle(V4Color.purple)
                                    Text(entry.model)
                                        .font(WernickeTypography.size10Mono)
                                        .foregroundStyle(V4Color.textSecondary)
                                    Spacer()
                                    Text("\(entry.thinking.count) chars")
                                        .font(WernickeTypography.size9Mono)
                                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                                }

                                Text(entry.thinking)
                                    .font(WernickeTypography.size12Mono)
                                    .foregroundStyle(V4Color.white70)
                                    .textSelection(.enabled)
                                    .padding(LayoutConstants.compactPadding)
                                    .background(Color.white.opacity(0.03))
                                    .clipShape(RoundedRectangle(cornerRadius: 6))

                                // Response preview
                                Text(entry.response + (entry.response.count >= 200 ? "..." : ""))
                                    .font(WernickeTypography.size11)
                                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                                    .lineLimit(2)
                            }
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(minWidth: 600, minHeight: 400)
        .background(V4Color.bgWindow)
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
        VStack(spacing: ParietalSpacing.xl) {
            Spacer()

            // Step indicator
            HStack(spacing: ParietalSpacing.sm) {
                ForEach(0..<steps.count, id: \.self) { i in
                    Circle()
                        .fill(i == step ? V4Color.accent : Color.white.opacity(V2Depth.bgSidebarHover))
                        .frame(width: ParietalSpacing.tinyIndicator, height: 8)
                }
            }

            // Content
            let current = steps[step]
            Image(systemName: current.icon)
                .font(WernickeTypography.size48)
                .foregroundStyle(step == 0 ? V4Color.golden : V4Color.accent)

            Text(current.title)
                .font(WernickeTypography.h3Bold)
                .foregroundStyle(V4Color.textPrimary)

            Text(current.body)
                .font(WernickeTypography.size15)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextSecondary))
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Spacer()

            // Navigation
            HStack(spacing: ParietalSpacing.lg) {
                if step > 0 {
                    Button {
                        withAnimation { step -= 1 }
                    } label: {
                        Text("Back")
                            .font(WernickeTypography.size14)
                            .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
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
                        .font(WernickeTypography.title3Bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, ParietalSpacing.lg)
                        .padding(.vertical, 10)
                        .background(V4Color.accent)
                        .clipShape(SwiftUI.Capsule())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ParietalSpacing.xxl)
            .padding(.bottom, 30)

            // Skip
            Button {
                UserDefaults.standard.set(true, forKey: "onboardingCompleted")
                isPresented = false
            } label: {
                Text("Skip")
                    .font(WernickeTypography.size12)
                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
            }
            .buttonStyle(.plain)
            .padding(.bottom, 16)
        }
        .frame(minWidth: 500, minHeight: 400)
        .background(V4Color.bgWindow)
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
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack {
                Image(systemName: "checklist")
                    .font(WernickeTypography.size11)
                    .foregroundStyle(V4Color.accent)
                Text("Tasks")
                    .font(WernickeTypography.caption2Bold)
                    .foregroundStyle(V4Color.accent)
                let done = tasks.filter(\.isDone).count
                Text("\(done)/\(tasks.count)")
                    .font(WernickeTypography.size10Mono)
                    .foregroundStyle(V4Color.textSecondary)
                Spacer()
                Button {
                    tasks.removeAll()
                } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size9)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
                .buttonStyle(.plain)
            }

            ForEach(tasks.indices, id: \.self) { idx in
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Button {
                        tasks[idx].isDone.toggle()
                    } label: {
                        Image(systemName: tasks[idx].isDone ? "checkmark.circle.fill" : "circle")
                            .font(WernickeTypography.size12)
                            .foregroundStyle(tasks[idx].isDone ? V4Color.statusOK : Color.white.opacity(V2Depth.stateHover))
                    }
                    .buttonStyle(.plain)

                    Text(tasks[idx].title)
                        .font(WernickeTypography.size11)
                        .foregroundStyle(tasks[idx].isDone ? V4Color.textSecondary : V4Color.textPrimary)
                        .strikethrough(tasks[idx].isDone)
                }
            }

            // Progress bar
            let progress = tasks.isEmpty ? 0.0 : Double(tasks.filter(\.isDone).count) / Double(tasks.count)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    SwiftUI.Capsule()
                        .fill(Color.white.opacity(V2Depth.bgCard))
                    SwiftUI.Capsule()
                        .fill(progress >= 1.0 ? V4Color.statusOK : V4Color.accent)
                        .frame(width: geo.size.width * progress)
                }
            }
            .frame(height: ParietalSpacing.cursorLineHeight)
            .padding(.top, 4)
        }
        .padding(LayoutConstants.compactPadding)
        .background(V4Color.bgCard)
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
        case "file": return V4Color.accent
        case "grep": return V4Color.purple
        case "build": return V4Color.statusError
        case "farm": return V4Color.golden
        default: return V4Color.accent
        }
    }

    var body: some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(WernickeTypography.size9)
            Text(value)
                .font(WernickeTypography.miniMedium)
                .lineLimit(1)
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(color.opacity(0.12))
        .clipShape(SwiftUI.Capsule())
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
        case .active: return V4Color.accent
        case .done: return V4Color.statusOK
        case .pending: return V4Color.textSecondary
        }
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: icon)
                .font(WernickeTypography.size8)
                .foregroundStyle(color)
            Text(name)
                .font(WernickeTypography.miniMedium)
                .foregroundStyle(color)
        }
        .padding(.horizontal, ParietalSpacing.xs)
        .padding(.vertical, 3)
        .background(color.opacity(V2Depth.bgSubtle))
        .clipShape(SwiftUI.Capsule())
    }
}

// MARK: - MCP Status Indicator

struct MCPStatusView: View {
    @State private var servers: [(name: String, connected: Bool)] = []

    var body: some View {
        Group {
            if !servers.isEmpty {
                HStack(spacing: ParietalSpacing.sm) {
                    ForEach(servers, id: \.name) { server in
                        HStack(spacing: 3) {
                            Circle()
                                .fill(server.connected ? V4Color.statusOK : V4Color.white20)
                                .frame(width: ParietalSpacing.microIndicator, height: 5)
                            Text(server.name)
                                .font(WernickeTypography.size9)
                                .foregroundStyle(server.connected ? V4Color.textSecondary : V4Color.white20)
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
                .frame(height: ParietalSpacing.toolbarMinHeight)
            }
    }
}

// FIXME: temporarily disabled extension
/*
extension View {
    func truncationGradient(maxHeight: CGFloat = 200) -> some View {
        modifier(TruncationGradient(maxHeight: maxHeight))
    }
}
*/

// MARK: - Save as Template Popover

struct SaveAsTemplatePopover: View {
    @Binding var name: String
    @Binding var category: String
    let messageText: String
    @ObservedObject var store: ThreadStore
    @Binding var isPresented: Bool
    @Binding var confirmed: Bool

    private let categories = ["Code", "Debug", "Design", "Docs", "Git", "Other"]

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            Text("Save as Template")
                .font(WernickeTypography.title3Bold)
                .foregroundStyle(V4Color.textPrimary)

            TextField("Template name", text: $name)
                .textFieldStyle(.roundedBorder)
                .font(WernickeTypography.size12)

            Picker("Category", selection: $category) {
                ForEach(categories, id: \.self) { Text($0) }
            }
            .pickerStyle(.segmented)
            .controlSize(.small)

            Text(String(messageText.prefix(120)) + (messageText.count > 120 ? "..." : ""))
                .font(WernickeTypography.size10Mono)
                .foregroundStyle(V4Color.textSecondary)
                .lineLimit(3)
                .padding(LayoutConstants.compactPadding)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.white.opacity(V2Depth.bgCardLight))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                .buttonStyle(.plain)
                Spacer()
                Button("Save") {
                    let template = PromptTemplate(
                        title: name.isEmpty ? "Custom" : name,
                        body: messageText,
                        category: category,
                        icon: iconForCategory(category)
                    )
                    store.saveTemplate(template)
                    confirmed = true
                    isPresented = false
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        confirmed = false
                    }
                }
                .font(WernickeTypography.captionBold)
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, LayoutConstants.compactPadding)
                .background(V4Color.purple)
                .clipShape(SwiftUI.Capsule())
                .buttonStyle(.plain)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
        .padding(LayoutConstants.inputAreaPadding)
            .frame(maxWidth: 300)
            .frame(minWidth: 260)
            .background(V4Color.surface)
    }

    private func iconForCategory(_ cat: String) -> String {
        switch cat {
        case "Code": return "chevron.left.forwardslash.chevron.right"
        case "Debug": return "ladybug"
        case "Design": return "square.3.layers.3d"
        case "Docs": return "doc.text"
        case "Git": return "arrow.triangle.branch"
        default: return "doc.on.clipboard"
        }
    }
}

// MARK: - Template Picker (inline, shown when typing /template)

struct TemplatePicker: View {
    @ObservedObject var store: ThreadStore
    let onSelect: (String) -> Void
    let onDismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Image(systemName: "doc.on.clipboard")
                    .font(WernickeTypography.size12)
                    .foregroundStyle(V4Color.purple)
                Text("Templates")
                    .font(WernickeTypography.captionBold)
                    .foregroundStyle(V4Color.textPrimary)
                Spacer()
                Button { onDismiss() } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size10)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, LayoutConstants.cardPadding)
            .padding(.vertical, LayoutConstants.standardPadding)

            Divider().background(Color.white.opacity(V2Depth.bgSubtle))

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    Text("BUILT-IN")
                        .font(WernickeTypography.microBold)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                        .padding(.horizontal, LayoutConstants.cardPadding)
                        .padding(.top, 6)

                    ForEach(PromptTemplate.builtIn) { template in
                        templatePickerRow(template)
                    }

                    let custom = store.loadCustomTemplates()
                    if !custom.isEmpty {
                        Text("CUSTOM")
                            .font(WernickeTypography.microBold)
                            .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                            .padding(.horizontal, LayoutConstants.cardPadding)
                            .padding(.top, 8)

                        ForEach(custom) { template in
                            templatePickerRow(template)
                                .contextMenu {
                                    Button("Delete", role: .destructive) {
                                        store.deleteTemplate(template.id)
                                    }
                                }
                        }
                    }
                }
                .padding(.bottom, 8)
            }
            .frame(maxHeight: 280)
        }
        .frame(maxWidth: 320)
            .frame(minWidth: 280)
            .background(V4Color.background)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        .shadow(color: .black.opacity(V2Depth.stateDisabled), radius: 12)
    }

    @ViewBuilder
    private func templatePickerRow(_ template: PromptTemplate) -> some View {
        Button {
            onSelect(template.body)
        } label: {
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: template.icon)
                    .font(WernickeTypography.size11)
                    .foregroundStyle(V4Color.purple)
                    .frame(width: ParietalSpacing.rowWidth)
                VStack(alignment: .leading, spacing: ParietalSpacing.xxxxs) {
                    Text(template.title)
                        .font(WernickeTypography.captionMedium)
                        .foregroundStyle(Color.white)
                    Text(String(template.body.prefix(50)))
                        .font(WernickeTypography.size9)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                        .lineLimit(1)
                }
                Spacer()
            }
            .padding(.horizontal, LayoutConstants.cardPadding)
            .padding(.vertical, LayoutConstants.compactPadding)
            .background(Color.white.opacity(0.001))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Thread Stats Card

private struct ThreadStatsCard: View {
    let thread: ChatThread
    @Binding var isExpanded: Bool

    private var messageCount: Int { thread.messages.count }

    private var totalTokens: Int {
        thread.messages.compactMap(\.outputTokens).reduce(0, +)
    }

    private var totalMs: Int {
        thread.messages.compactMap(\.totalMs).reduce(0, +)
    }

    private var avgTTFB: Int {
        let vals = thread.messages.compactMap(\.ttfbMs)
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / vals.count
    }

    private var avgTokPerSec: Double {
        let vals = thread.messages.compactMap(\.tokPerSec)
        guard !vals.isEmpty else { return 0 }
        return vals.reduce(0, +) / Double(vals.count)
    }

    private var uniqueModels: [String] {
        Array(Set(thread.messages.compactMap(\.modelID))).sorted()
    }

    private var threadAge: String {
        let interval = Date().timeIntervalSince(thread.createdAt)
        let minutes = Int(interval) / 60
        let hours = minutes / 60
        let days = hours / 24
        if days > 0 { return "\(days)d ago" }
        if hours > 0 { return "\(hours)h ago" }
        if minutes > 0 { return "\(minutes)m ago" }
        return "just now"
    }

    private func formatDuration(_ ms: Int) -> String {
        let totalSec = ms / 1000
        let m = totalSec / 60
        let s = totalSec % 60
        if m > 0 { return "\(m)m \(s)s" }
        return "\(s)s"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Collapsed: single-line summary
            Button(action: { withAnimation(.easeInOut(duration: 0.2)) { isExpanded.toggle() } }) {
                HStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: "info.circle")
                        .font(WernickeTypography.size11)
                        .foregroundStyle(V4Color.textSecondary)
                    Text("\(messageCount) messages")
                        .font(WernickeTypography.caption2Medium)
                        .foregroundStyle(V4Color.textSecondary)
                    Text("·")
                        .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateDisabled))
                    Text("Created \(threadAge)")
                        .font(WernickeTypography.size11)
                        .foregroundStyle(V4Color.textSecondary.opacity(0.7))
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(WernickeTypography.size9)
                        .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateDisabled))
                }
                .padding(.horizontal, LayoutConstants.cardPadding)
                .padding(.vertical, LayoutConstants.standardPadding)
                .background(Color.white.opacity(0.001))
            }
            .buttonStyle(.plain)

            // Expanded: stat grid
            if isExpanded {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: ParietalSpacing.sm + 2),
                    GridItem(.flexible(), spacing: ParietalSpacing.sm + 2),
                ], spacing: ParietalSpacing.sm + 2) {
                    statCell(label: "Messages", value: "\(messageCount)", icon: "bubble.left.and.bubble.right")
                    statCell(label: "Total Tokens", value: totalTokens > 0 ? formatTokens(totalTokens) : "--", icon: "number")
                    statCell(label: "Total Time", value: totalMs > 0 ? formatDuration(totalMs) : "--", icon: "clock")
                    statCell(label: "Avg TTFB", value: avgTTFB > 0 ? "\(avgTTFB)ms" : "--", icon: "bolt")
                    statCell(label: "Avg tok/s", value: avgTokPerSec > 0 ? String(format: "%.1f", avgTokPerSec) : "--", icon: "speedometer")
                    statCell(label: "Thread Age", value: threadAge, icon: "calendar")
                }
                .padding(.horizontal, LayoutConstants.cardPadding)
                .padding(.bottom, 10)

                // Models pills
                if !uniqueModels.isEmpty {
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        Text("Models:")
                            .font(WernickeTypography.size10)
                            .foregroundStyle(V4Color.textSecondary)
                        ForEach(uniqueModels, id: \.self) { model in
                            Text(shortModelName(model))
                                .font(WernickeTypography.microMono)
                                .foregroundStyle(V4Color.accent)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(V4Color.accent.opacity(V2Depth.bgSubtle))
                                .clipShape(SwiftUI.Capsule())
                        }
                    }
                    .padding(.horizontal, LayoutConstants.cardPadding)
                    .padding(.bottom, 10)
                }
            }
        }
        .background(V4Color.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                .stroke(V4Color.bgCardBorder, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
    }

    private func statCell(label: String, value: String, icon: String) -> some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            Image(systemName: icon)
                .font(WernickeTypography.size10)
                .foregroundStyle(V4Color.accent.opacity(0.7))
                .frame(width: ParietalSpacing.xSmallFrame)
            VStack(alignment: .leading, spacing: ParietalSpacing.xxxxs) {
                Text(value)
                    .font(WernickeTypography.captionSemiboldMono)
                    .foregroundStyle(V4Color.textPrimary)
                Text(label)
                    .font(WernickeTypography.size9)
                    .foregroundStyle(V4Color.textSecondary)
            }
            Spacer()
        }
        .padding(.horizontal, ParietalSpacing.xs)
        .padding(.vertical, LayoutConstants.compactPadding)
        .background(V4Color.bgCard.opacity(V2Depth.stateDisabled))
        .overlay(
            RoundedRectangle(cornerRadius: 4)
                .stroke(V4Color.bgCardBorder.opacity(V2Depth.stateDisabled), lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 { return String(format: "%.1fM", Double(count) / 1_000_000) }
        if count >= 1_000 { return String(format: "%.1fK", Double(count) / 1_000) }
        return "\(count)"
    }

    private func shortModelName(_ model: String) -> String {
        if model.contains("sonnet") { return "sonnet-4" }
        if model.contains("opus") { return "opus-4" }
        if model.contains("haiku") { return "haiku-4" }
        if model.contains("gpt-4o") { return "gpt-4o" }
        if model.count > 20 { return String(model.prefix(18)) + ".." }
        return model
    }
}

// MARK: - Multi-Select Action Bar

struct MultiSelectActionBar: View {
    let selectedCount: Int
    let canCompareModels: Bool
    let canDelete: Bool
    let onCopyAll: () -> Void
    let onDeleteSelected: () -> Void
    let onQuoteSelected: () -> Void
    let onCompareModels: () -> Void
    let onSelectAll: () -> Void
    let onDeselectAll: () -> Void
    let onCancel: () -> Void

    @State private var isHovering = false

    private var countBadge: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Circle()
                .fill(V4Color.accent)
                .frame(width: ParietalSpacing.dotSize, height: 6)
            Text("\(selectedCount)")
                .font(WernickeTypography.smallSemiboldMono)
                .foregroundStyle(.white)
        }
    }

    private func actionButton(
        _ systemName: String,
        tooltip: String,
        color: Color = .white,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(WernickeTypography.body14Medium)
                .foregroundStyle(color)
                .frame(width: ParietalSpacing.touchFrame, height: 32)
                .background(
                    Circle()
                        .fill(color.opacity(V2Depth.bgSubtle))
                        .overlay(
                            Circle()
                                .stroke(color.opacity(0.2), lineWidth: 0.5)
                        )
                )
        }
        .buttonStyle(.plain)
        .help(tooltip)
        .accessibilityLabel(tooltip)
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            // Left: count badge
            countBadge
                .padding(.leading, 4)

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(V2Depth.bgSidebarHover))

            // Middle: action buttons
            HStack(spacing: ParietalSpacing.sm - 2) {
                actionButton("doc.on.doc", tooltip: "Copy All (Cmd+C)", color: V4Color.accent, action: onCopyAll)

                actionButton("bubble.left.and.text.bubble.right", tooltip: "Quote Selected", color: V4Color.golden, action: onQuoteSelected)

                if canDelete {
                    actionButton("trash", tooltip: "Delete Selected", color: V4Color.statusError, action: onDeleteSelected)
                }

                if canCompareModels {
                    actionButton("scale.3d", tooltip: "Compare Models", color: V4Color.purple, action: onCompareModels)
                }

                // Select/Deselect all
                actionButton("checkmark.circle", tooltip: "Select All (Cmd+A)", color: .white.opacity(0.8), action: onSelectAll)
                    .keyboardShortcut("a", modifiers: .command)

                if selectedCount > 1 {
                    actionButton("xmark.circle", tooltip: "Deselect All (Cmd+Shift+A)", color: .white.opacity(V1Theme.opacityTextSecondary), action: onDeselectAll)
                }
            }

            Divider()
                .frame(height: 20)
                .background(Color.white.opacity(V2Depth.bgSidebarHover))

            // Right: cancel
            Button(action: onCancel) {
                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.caption2Bold)
                    Text("Done")
                        .font(WernickeTypography.captionMedium)
                }
                .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, LayoutConstants.compactPadding)
                .background(Color.white.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .help("Exit selection mode (Esc)")
            .accessibilityLabel("Exit selection mode")
        }
        .padding(.horizontal, LayoutConstants.standardPadding)
        .padding(.vertical, 10)
        .background(
            ZStack {
                // Gradient background
                LinearGradient(
                    colors: [
                        V4Color.accent.opacity(V2Depth.bgSidebarHover),
                        V4Color.purple.opacity(V2Depth.bgSubtle)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )

                // Glass effect
                Color.white.opacity(0.03)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    LinearGradient(
                        colors: [
                            V4Color.accent.opacity(isHovering ? 0.5 : 0.2),
                            V4Color.purple.opacity(isHovering ? 0.3 : 0.1)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: V4Color.accent.opacity(isHovering ? 0.3 : 0.15),
            radius: isHovering ? 16 : 8,
            y: 4
        )
        .scaleEffect(isHovering ? 1.02 : 1.0)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovering)
        .onHover { hovering in
            isHovering = hovering
        }
    }
}

// MARK: - Thread Loading Skeleton (shown when switching to large threads)

struct ThreadLoadingSkeleton: View {
    let isUser: Bool
    @State private var shimmer = false

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }
            VStack(alignment: isUser ? .trailing : .leading, spacing: ParietalSpacing.sm - 2) {
                if !isUser {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(V2Depth.bgCardLight))
                        .frame(width: ParietalSpacing.mediumFrame, height: ParietalSpacing.captionHeight)
                }
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.white.opacity(isUser ? 0.06 : 0.04))
                    .frame(height: isUser ? 36 : 60)
                    .frame(maxWidth: isUser ? 280 : .infinity)
                if !isUser {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.white.opacity(0.03))
                        .frame(width: ParietalSpacing.xLargeFrame, height: 8)
                }
            }
            if !isUser { Spacer(minLength: 60) }
        }
        .opacity(shimmer ? 0.7 : 0.3)
        .animation(
            .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
            value: shimmer
        )
        .onAppear { shimmer = true }
    }
}
