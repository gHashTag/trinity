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
    @FocusState private var focused: Bool

    private var thread: ChatThread? {
        store.activeThread()
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
                // Sidebar with context inspector
                VStack(spacing: 0) {
                    ChatSidebar(store: store, modelManager: modelManager)

                    Rectangle()
                        .fill(Color.white.opacity(0.06))
                        .frame(height: 1)

                    ContextInspector()
                        .frame(maxHeight: 200)
                }
                .frame(width: 240)

                Rectangle()
                    .fill(Color.white.opacity(0.06))
                    .frame(width: 1)

                // Main chat area
                ZStack(alignment: .bottomTrailing) {
                    Color.black.ignoresSafeArea()

                    VStack(spacing: 0) {
                        // Connection status bar
                        ConnectionStatusBar(modelManager: modelManager)

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
                                    }

                                    // Typing indicator + streaming metrics
                                    if client.isStreaming {
                                        HStack(spacing: 12) {
                                            if thread?.messages.last?.text.isEmpty ?? false {
                                                ThinkingDots()
                                                Text("Thinking...")
                                                    .font(.caption)
                                                    .foregroundStyle(TrinityTheme.textMuted)
                                            }
                                            if client.streamingTTFB > 0 {
                                                Text("TTFB \(client.streamingTTFB)ms")
                                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                                    .foregroundStyle(TrinityTheme.textMuted)
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
                                        .padding(.vertical, 12)
                                        .transition(.opacity)
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

                        // Attached files chips
                        if !attachedFiles.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(attachedFiles.indices, id: \.self) { idx in
                                    HStack(spacing: 4) {
                                        Text("📎")
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

                        // Input bar — pill shape at bottom
                        VStack(spacing: 8) {
                            HStack(spacing: 0) {
                                // Model picker (left icon area)
                                ModelPicker(modelManager: modelManager)
                                    .padding(.leading, 14)

                                TextField(placeholder, text: $input, axis: .vertical)
                                    .textFieldStyle(.plain)
                                    .font(.system(size: 15))
                                    .foregroundStyle(Color.white)
                                    .focused($focused)
                                    .lineLimit(1...8)
                                    .onSubmit { send() }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 14)

                                // Right utility buttons
                                HStack(spacing: 8) {
                                    // Attach
                                    Button { openFilePicker() } label: {
                                        Image(systemName: "paperclip")
                                            .font(.system(size: 15))
                                            .foregroundStyle(Color.white.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Attach file (⌘O)")
                                    .accessibilityLabel("Attach file")

                                    // Shortcuts
                                    Button { showShortcuts.toggle() } label: {
                                        Image(systemName: "keyboard")
                                            .font(.system(size: 15))
                                            .foregroundStyle(Color.white.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Shortcuts (⌘/)")
                                    .accessibilityLabel("Keyboard shortcuts")

                                    // Voice
                                    Button { toggleVoiceInput() } label: {
                                        Image(systemName: isRecording ? "mic.fill" : "mic")
                                            .font(.system(size: 15))
                                            .foregroundStyle(isRecording ? TrinityTheme.statusError : Color.white.opacity(0.4))
                                    }
                                    .buttonStyle(.plain)
                                    .help("Voice input")
                                    .accessibilityLabel(isRecording ? "Stop recording" : "Voice input")

                                    // Send / Stop button
                                    Group {
                                        if client.isStreaming {
                                            Button(action: { client.stop() }) {
                                                Image(systemName: "stop.circle.fill")
                                                    .font(.system(size: 24))
                                                    .foregroundStyle(TrinityTheme.accent)
                                            }
                                            .accessibilityLabel("Stop generating")
                                        } else {
                                            Button(action: send) {
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
                                            .accessibilityLabel("Send message")
                                        }
                                    }
                                    .buttonStyle(.plain)
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

                            // Mode buttons row + context meter
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

                                // Context meter
                                ContextMeter(tokens: estimatedTokens)
                            }
                        }
                        .padding(.horizontal, 60)
                        .padding(.bottom, 16)
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
            .animation(.easeInOut(duration: 0.2), value: commentingMessage != nil)

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
        .animation(.easeInOut(duration: 0.2), value: showComparison)
        .background(Color.black)
        .onAppear {
            if store.threads.isEmpty { store.newThread() }
            focused = true
            // Defer heavy work off the body evaluation path
            Task { @MainActor in
                NotificationService.shared.requestPermission()
                NetworkLog.shared.checkAllProviders()
            }
            startHealthRefreshTimer()
        }
        .onReceive(NotificationCenter.default.publisher(for: .toggleCommandPalette)) { _ in
            showCommandPalette.toggle()
        }
    }

    private func send() {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !client.isStreaming else { return }

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

        input = ""
        client.send(text, threadID: threadID, store: store, modelManager: modelManager, mode: chatMode)
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

    private func openFilePicker() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = true
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.plainText, .sourceCode, .json, .yaml, .xml, .png, .jpeg]
        panel.begin { response in
            guard response == .OK else { return }
            for url in panel.urls.prefix(3) {
                guard let data = try? Data(contentsOf: url),
                      let content = String(data: data.prefix(8192), encoding: .utf8) else { continue }
                let name = url.lastPathComponent
                DispatchQueue.main.async {
                    attachedFiles.append((name: name, content: content))
                }
            }
        }
    }

    // MARK: - Drag & Drop

    private func handleFileDrop(_ providers: [NSItemProvider]) {
        for provider in providers.prefix(3) {
            provider.loadItem(forTypeIdentifier: "public.file-url", options: nil) { item, _ in
                guard let data = item as? Data,
                      let url = URL(dataRepresentation: data, relativeTo: nil),
                      let fileData = try? Data(contentsOf: url),
                      let content = String(data: fileData.prefix(8192), encoding: .utf8) else { return }
                let name = url.lastPathComponent
                DispatchQueue.main.async {
                    attachedFiles.append((name: name, content: content))
                }
            }
        }
    }

    // MARK: - Voice Input

    private func toggleVoiceInput() {
        if isRecording {
            isRecording = false
            SFSpeechRecognizer.requestAuthorization { _ in }
        } else {
            SFSpeechRecognizer.requestAuthorization { status in
                DispatchQueue.main.async {
                    if status == .authorized {
                        isRecording = true
                        startListening()
                    }
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
            }
        }
    }
}

// MARK: - Notification for cross-view communication

extension Notification.Name {
    static let toggleThreadSearch = Notification.Name("toggleThreadSearch")
    static let toggleCommandPalette = Notification.Name("toggleCommandPalette")
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
    @StateObject private var networkLog = NetworkLog.shared
    @State private var isOnline: Bool? = nil  // nil = checking

    private var selectedProviderUp: Bool {
        let provider = modelManager.selectedModel.provider.rawValue
        return networkLog.providerHealth[provider]?.isUp ?? true
    }

    var body: some View {
        VStack(spacing: 0) {
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
        }
        .onAppear { checkConnection() }
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
    private let maxTokens = 180_000

    var body: some View {
        let ratio = min(Double(tokens) / Double(maxTokens), 1.0)
        let color: Color = ratio < 0.5 ? TrinityTheme.accent
            : ratio < 0.8 ? TrinityTheme.golden
            : TrinityTheme.statusError

        HStack(spacing: 4) {
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
        }
        .help("\(tokens) tokens / \(maxTokens / 1000)K context")
    }
}

// MARK: - Model Picker (inline, compact)

struct ModelPicker: View {
    @ObservedObject var modelManager: ModelManager

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
                                    Text(model.displayName)
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
                Text(modelManager.selectedModel.displayName)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.7))
                Image(systemName: "chevron.down")
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(Color.white.opacity(0.4))
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

    var body: some View {
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
                                    .font(.system(size: 15, weight: .semibold))
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
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.white)
                                .textSelection(.enabled)
                                .multilineTextAlignment(.trailing)
                        }

                        // Timestamp + edit button on hover
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
                        .font(.system(size: 15, weight: .regular))
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
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
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
            if message.text.isEmpty {
                Text(" ")
            } else {
                MarkdownTextView(text: message.text)
            }

            // Display attached images (from image generation)
            if let urls = message.imageURLs, !urls.isEmpty {
                ForEach(urls, id: \.self) { url in
                    ImageBlockView(alt: "Generated Image", url: url)
                }
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
                // Retry (shows prominently if error)
                actionButton(
                    "arrow.clockwise",
                    tooltip: "Retry",
                    active: hasError,
                    tint: hasError ? TrinityTheme.statusError : nil
                ) {
                    guard let threadID = store.activeThreadID else { return }
                    client.regenerate(threadID: threadID, store: store, modelManager: modelManager)
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
                    tooltip: "Dislike",
                    active: isLiked == false
                ) {
                    guard let threadID = store.activeThreadID else { return }
                    let newVal: Bool? = (isLiked == false) ? nil : false
                    store.toggleLike(message.id, liked: newVal, in: threadID)
                }
            }

            Spacer()

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

    private let suggestions: [(String, String, ChatMode)] = [
        ("🔍", "What's new in ternary AI research?", .search),
        ("🧬", "Show SEVO farm evolution status", .trinity),
        ("💡", "Analyze Trinity's architecture trade-offs", .reason),
        ("🖼", "Trinity logo: golden crown on black, sci-fi style", .image),
        ("📊", "Compare our PPL with BitNet and Falcon", .trinity),
        ("🔨", "Is the build passing? What needs fixing?", .trinity),
    ]

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
