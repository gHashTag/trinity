import SwiftUI

/// Side-by-side model comparison: sends same prompt to 2 models in parallel.
/// Shows streaming responses with metrics (TTFB, tok/s, cost estimate).
struct ModelComparisonView: View {
    let prompt: String
    @ObservedObject var modelManager: ModelManager
    let onClose: () -> Void

    @State private var leftModel: AIModel?
    @State private var rightModel: AIModel?
    @State private var leftText = ""
    @State private var rightText = ""
    @State private var leftMetrics = StreamMetrics()
    @State private var rightMetrics = StreamMetrics()
    @State private var isRunning = false
    @State private var leftTask: Task<Void, Never>?
    @State private var rightTask: Task<Void, Never>?

    struct StreamMetrics {
        var ttfbMs: Int = 0
        var tokPerSec: Double = 0
        var outputTokens: Int = 0
        var totalMs: Int = 0
        var status: String = "idle"  // idle, streaming, done, error
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("MODEL COMPARISON")
                    .font(WernickeTypography.caption2BoldMono)
                    .foregroundStyle(V4Color.golden)

                Spacer()

                if !isRunning {
                    Button("Run") { startComparison() }
                        .font(WernickeTypography.caption2Bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, ParietalSpacing.md)
                        .padding(.vertical, ParietalSpacing.xs)
                        .background(V4Color.accent)
                        .clipShape(SwiftUI.Capsule())
                        .buttonStyle(.plain)
                        .disabled(leftModel == nil || rightModel == nil)
                } else {
                    Button("Stop") { stopComparison() }
                        .font(WernickeTypography.caption2Bold)
                        .foregroundStyle(.black)
                        .padding(.horizontal, ParietalSpacing.md)
                        .padding(.vertical, ParietalSpacing.xs)
                        .background(V4Color.error)
                        .clipShape(SwiftUI.Capsule())
                        .buttonStyle(.plain)
                }

                Button { onClose() } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size11)
                        .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ParietalSpacing.lg)
            .padding(.vertical, ParietalSpacing.sm + 2)
            .background(V4Color.background)

            // Prompt preview
            Text(prompt)
                .font(WernickeTypography.size12)
                .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, ParietalSpacing.lg)
                .padding(.vertical, ParietalSpacing.xs + 2)
                .background(Color.white.opacity(0.02))

            Divider().background(Color.white.opacity(V2Depth.bgCard))

            // Model pickers
            HStack(spacing: 0) {
                modelPicker(selection: $leftModel, label: "LEFT")
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(V2Depth.bgCard))
                    .frame(width: ParietalSpacing.hairline)

                modelPicker(selection: $rightModel, label: "RIGHT")
                    .frame(maxWidth: .infinity)
            }
            .padding(.vertical, ParietalSpacing.xs + 2)
            .background(V4Color.background)

            Divider().background(Color.white.opacity(V2Depth.bgCard))

            // Side-by-side responses
            HStack(spacing: 0) {
                responsePanel(
                    text: leftText,
                    metrics: leftMetrics,
                    model: leftModel
                )
                .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.white.opacity(V2Depth.bgCard))
                    .frame(width: ParietalSpacing.hairline)

                responsePanel(
                    text: rightText,
                    metrics: rightMetrics,
                    model: rightModel
                )
                .frame(maxWidth: .infinity)
            }
        }
        .background(Color.black)
        .onAppear { pickDefaultModels() }
    }

    // MARK: - Model Picker

    private func modelPicker(selection: Binding<AIModel?>, label: String) -> some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            Text(label)
                .font(WernickeTypography.microBoldMono)
                .foregroundStyle(Color.white.opacity(V2Depth.stateHover))

            Menu {
                ForEach(modelManager.availableModels.filter { !$0.isImageModel }) { model in
                    Button(model.displayName) {
                        selection.wrappedValue = model
                    }
                }
            } label: {
                HStack(spacing: ParietalSpacing.xs) {
                    Text(selection.wrappedValue?.displayName ?? "Select...")
                        .font(WernickeTypography.miniMedium)
                        .foregroundStyle(V4Color.white70)
                    Image(systemName: "chevron.down")
                        .font(WernickeTypography.size8)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                }
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xs)
                .background(Color.white.opacity(V2Depth.bgCard))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
        }
        .padding(.horizontal, ParietalSpacing.md)
    }

    // MARK: - Response Panel

    private func responsePanel(text: String, metrics: StreamMetrics, model: AIModel?) -> some View {
        VStack(spacing: 0) {
            // Metrics bar
            HStack(spacing: ParietalSpacing.sm + 2) {
                statusDot(metrics.status)
                if metrics.ttfbMs > 0 {
                    metricLabel("TTFB", "\(metrics.ttfbMs)ms")
                }
                if metrics.tokPerSec > 0 {
                    metricLabel("tok/s", String(format: "%.0f", metrics.tokPerSec))
                }
                if metrics.outputTokens > 0 {
                    metricLabel("out", "\(metrics.outputTokens)")
                }
                if metrics.totalMs > 0 {
                    metricLabel("total", "\(metrics.totalMs)ms")
                }
                Spacer()
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.xs + 2)
            .background(Color.white.opacity(0.02))

            // Response text
            ScrollView {
                if text.isEmpty && metrics.status == "streaming" {
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        ThinkingDots()
                        Text("Thinking...")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .padding()
                } else if text.isEmpty {
                    Text("Waiting...")
                        .font(.caption)
                        .foregroundStyle(V4Color.white20)
                        .padding()
                } else {
                    MarkdownTextView(text: text)
                        .font(WernickeTypography.size13)
                        .foregroundStyle(V4Color.border)
                        .textSelection(.enabled)
                        .padding(ParietalSpacing.md)
                }
            }
        }
    }

    private func statusDot(_ status: String) -> some View {
        Circle()
            .fill(statusColor(status))
            .frame(width: ParietalSpacing.dotSize, height: 6)
    }

    private func statusColor(_ status: String) -> Color {
        switch status {
        case "streaming": return V4Color.golden
        case "done": return V4Color.success
        case "error": return V4Color.error
        default: return V4Color.white20
        }
    }

    private func metricLabel(_ label: String, _ value: String) -> some View {
        HStack(spacing: 2) {
            Text(label)
                .font(WernickeTypography.size8Mono)
                .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
            Text(value)
                .font(WernickeTypography.microBoldMono)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextSecondary))
        }
    }

    // MARK: - Logic

    private func pickDefaultModels() {
        let available = modelManager.availableModels.filter { !$0.isImageModel }
        if available.count >= 2 {
            leftModel = available[0]
            rightModel = available[1]
        } else if available.count == 1 {
            leftModel = available[0]
        }
    }

    private func startComparison() {
        guard let left = leftModel, let right = rightModel else { return }
        isRunning = true
        leftText = ""
        rightText = ""
        leftMetrics = StreamMetrics(status: "streaming")
        rightMetrics = StreamMetrics(status: "streaming")

        leftTask = Task { await runModel(left, setText: { leftText = $0 }, setMetrics: { leftMetrics = $0 }) }
        rightTask = Task { await runModel(right, setText: { rightText = $0 }, setMetrics: { rightMetrics = $0 }) }

        // Wait for both to finish
        Task {
            _ = await leftTask?.value
            _ = await rightTask?.value
            isRunning = false
        }
    }

    private func stopComparison() {
        leftTask?.cancel()
        rightTask?.cancel()
        leftTask = nil
        rightTask = nil
        isRunning = false
        // Ensure both sides show final state (fix race condition)
        if leftMetrics.status == "streaming" { leftMetrics.status = "stopped" }
        if rightMetrics.status == "streaming" { rightMetrics.status = "stopped" }
    }

    private func runModel(
        _ model: AIModel,
        setText: @escaping (String) -> Void,
        setMetrics: @escaping (StreamMetrics) -> Void
    ) async {
        guard modelManager.apiKey(for: model) != nil else {
            setMetrics(StreamMetrics(status: "error"))
            setText("[No API key for \(model.provider.rawValue)]")
            return
        }

        let systemPrompt = "You are Queen, a technical AI assistant. Answer concisely and precisely."
        let startTime = Date()
        var firstTokenTime: Date?
        var outputTokens = 0
        var accumulated = ""

        do {
            let body: [String: Any]
            switch model.provider {
            case .anthropic, .zai:
                body = [
                    "model": model.id,
                    "max_tokens": 2048,
                    "stream": true,
                    "system": systemPrompt,
                    "messages": [["role": "user", "content": prompt]]
                ]
            case .perplexity, .xai:
                body = [
                    "model": model.id,
                    "stream": true,
                    "messages": [
                        ["role": "system", "content": systemPrompt],
                        ["role": "user", "content": prompt]
                    ]
                ]
            case .ollama:
                let modelName = modelManager.ollamaModelName(model)
                body = [
                    "model": modelName,
                    "stream": true,
                    "messages": [
                        ["role": "system", "content": systemPrompt],
                        ["role": "user", "content": prompt]
                    ]
                ]
            }

            let bodyData = try JSONSerialization.data(withJSONObject: body)
            guard let request = modelManager.buildRequest(for: model, body: bodyData) else {
                setMetrics(StreamMetrics(status: "error"))
                setText("[Failed to build request]")
                return
            }

            let (bytes, response) = try await URLSession.shared.bytes(for: request)

            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode != 200 {
                var errorBody = ""
                for try await line in bytes.lines { errorBody += line }
                setMetrics(StreamMetrics(totalMs: Int(Date().timeIntervalSince(startTime) * 1000), status: "error"))
                setText("[Error \(httpResponse.statusCode): \(errorBody.prefix(200))]")
                return
            }

            for try await line in bytes.lines {
                try Task.checkCancellation()
                guard line.hasPrefix("data: ") else { continue }
                let data = String(line.dropFirst(6))
                if data == "[DONE]" { break }

                guard let jsonData = data.data(using: .utf8),
                      let event = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else { continue }

                var token: String?

                // Anthropic format
                if let type = event["type"] as? String, type == "content_block_delta",
                   let delta = event["delta"] as? [String: Any],
                   let text = delta["text"] as? String {
                    token = text
                }
                // OpenAI format
                if let choices = event["choices"] as? [[String: Any]],
                   let delta = choices.first?["delta"] as? [String: Any],
                   let content = delta["content"] as? String {
                    token = content
                }

                if let t = token {
                    if firstTokenTime == nil { firstTokenTime = Date() }
                    accumulated += t
                    outputTokens += max(t.count / 4, 1)
                    setText(accumulated)

                    let elapsed = Date().timeIntervalSince(firstTokenTime!)
                    let tokSec = elapsed > 0.1 ? Double(outputTokens) / elapsed : 0
                    setMetrics(StreamMetrics(
                        ttfbMs: Int((firstTokenTime?.timeIntervalSince(startTime) ?? 0) * 1000),
                        tokPerSec: tokSec,
                        outputTokens: outputTokens,
                        totalMs: Int(Date().timeIntervalSince(startTime) * 1000),
                        status: "streaming"
                    ))
                }
            }

            let totalMs = Int(Date().timeIntervalSince(startTime) * 1000)
            let ttfb = Int((firstTokenTime?.timeIntervalSince(startTime) ?? 0) * 1000)
            let elapsed = firstTokenTime.map { Date().timeIntervalSince($0) } ?? 0
            let tokSec = elapsed > 0.1 ? Double(outputTokens) / elapsed : 0
            setMetrics(StreamMetrics(ttfbMs: ttfb, tokPerSec: tokSec, outputTokens: outputTokens, totalMs: totalMs, status: "done"))

            NetworkLog.shared.record(
                provider: model.provider.rawValue, model: model.id,
                inputTokens: prompt.count / 4, outputTokens: outputTokens,
                ttfbMs: ttfb, totalMs: totalMs, status: "ok"
            )

        } catch is CancellationError {
            setMetrics(StreamMetrics(status: "done"))
        } catch {
            setMetrics(StreamMetrics(status: "error"))
            setText(accumulated + "\n[Error: \(error.localizedDescription)]")
        }
    }
}
