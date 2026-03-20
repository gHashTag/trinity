import SwiftUI

// MARK: - Message Status Indicators

/// Visual indicators for message transmission and streaming status.
/// Shows TTFB (Time to First Byte), token throughput, and streaming state.
struct MessageStatusIndicators: View {
    let message: ChatMessage
    let isStreaming: Bool
    let streamingTTFB: Int
    let streamingTokensPerSec: Double
    let streamingOutputTokens: Int

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var a11y: AccessibilityManager

    private var effectiveTTFB: Int {
        isStreaming ? streamingTTFB : (message.ttfbMs ?? 0)
    }

    private var effectiveTokensPerSec: Double {
        isStreaming ? streamingTokensPerSec : (message.tokPerSec ?? 0)
    }

    private var effectiveOutputTokens: Int {
        isStreaming ? streamingOutputTokens : (message.outputTokens ?? 0)
    }

    private var hasMetrics: Bool {
        effectiveTTFB > 0 || effectiveTokensPerSec > 0 || effectiveOutputTokens > 0
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            // TTFB indicator
            if effectiveTTFB > 0 {
                TTFBIndicator(ttfbMs: effectiveTTFB)
            }

            // Tokens/sec indicator
            if effectiveTokensPerSec > 0 {
                ThroughputIndicator(tokensPerSec: effectiveTokensPerSec)
            }

            // Output token count
            if effectiveOutputTokens > 0 {
                TokenCountIndicator(count: effectiveOutputTokens)
            }

            // Streaming indicator
            if isStreaming {
                StreamingIndicator()
            }
        }
        .font(.system(size: a11y.scaledFontSize(10)))
        .foregroundStyle(V4Color.textSecondary)
    }
}

// MARK: - TTFB Indicator

struct TTFBIndicator: View {
    let ttfbMs: Int

    @EnvironmentObject private var a11y: AccessibilityManager

    private var formattedTTFB: String {
        if ttfbMs < 1000 {
            return "\(ttfbMs)ms"
        } else {
            return String(format: "%.1fs", Double(ttfbMs) / 1000.0)
        }
    }

    private var ttfbColor: Color {
        switch ttfbMs {
        case 0..<500:
            return V4Color.success
        case 500..<1500:
            return V4Color.warning
        default:
            return V4Color.error
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(a11y.highContrast ? V4Color.HighContrast.accent : ttfbColor)
            Text(formattedTTFB)
        }
        .accessibilityLabel("Time to first token: \(formattedTTFB)")
        .accessibilityHint(ttfbMs < 500 ? "Fast response" : ttfbMs < 1500 ? "Moderate response" : "Slow response")
    }
}

// MARK: - Throughput Indicator

struct ThroughputIndicator: View {
    let tokensPerSec: Double

    @EnvironmentObject private var a11y: AccessibilityManager

    private var formattedThroughput: String {
        if tokensPerSec >= 1000 {
            return String(format: "%.1ft/s", tokensPerSec / 1000.0)
        } else {
            return String(format: "%.0ft/s", tokensPerSec)
        }
    }

    private var throughputColor: Color {
        switch tokensPerSec {
        case 50...:
            return V4Color.success
        case 20..<50:
            return V4Color.warning
        default:
            return V4Color.error
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "speedometer")
                .foregroundStyle(a11y.highContrast ? V4Color.HighContrast.accent : throughputColor)
            Text(formattedThroughput)
        }
        .accessibilityLabel("Token throughput: \(formattedThroughput)")
        .accessibilityHint(tokensPerSec >= 50 ? "High throughput" : tokensPerSec >= 20 ? "Moderate throughput" : "Low throughput")
    }
}

// MARK: - Token Count Indicator

struct TokenCountIndicator: View {
    let count: Int

    @EnvironmentObject private var a11y: AccessibilityManager

    private var formattedCount: String {
        if count >= 1000 {
            return String(format: "%.1fK", Double(count) / 1000.0)
        } else {
            return "\(count)"
        }
    }

    var body: some View {
        HStack(spacing: 2) {
            Image(systemName: "text.word.count")
                .foregroundStyle(a11y.highContrast ? V4Color.HighContrast.textSecondary : V4Color.textSecondary)
            Text("\(formattedCount)t")
        }
        .accessibilityLabel("Output tokens: \(formattedCount)")
    }
}

// MARK: - Streaming Indicator

struct StreamingIndicator: View {
    @State private var isAnimating = true

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: "waveform")
                .symbolEffect(.pulse, options: .repeating, isActive: isAnimating)
                .foregroundStyle(V4Color.accent)
            Text("Streaming")
        }
        .accessibilityLabel("Streaming response")
        .accessibilityHint("AI is currently generating text")
    }
}

// MARK: - Compact Status Pill

/// A compact single-pill version that shows the most relevant status
struct CompactStatusPill: View {
    let message: ChatMessage
    let isStreaming: Bool
    let streamingTTFB: Int
    let streamingTokensPerSec: Double

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var a11y: AccessibilityManager

    private var effectiveTTFB: Int {
        isStreaming ? streamingTTFB : (message.ttfbMs ?? 0)
    }

    private var effectiveTokensPerSec: Double {
        isStreaming ? streamingTokensPerSec : (message.tokPerSec ?? 0)
    }

    var body: some View {
        Group {
            if isStreaming {
                streamingPill
            } else if effectiveTTFB > 0 || effectiveTokensPerSec > 0 {
                metricsPill
            }
        }
    }

    private var streamingPill: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: "waveform")
                .symbolEffect(.pulse, options: .repeating, isActive: true)
                .foregroundStyle(V4Color.accent)
                .font(.system(size: a11y.scaledFontSize(9)))
            Text("Generating...")
                .font(.system(size: a11y.scaledFontSize(10)))
                .foregroundStyle(V4Color.textSecondary)
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, 3)
        .background(
            V4Color.accent.opacity(V2Depth.bgSubtle),
            in: SwiftUI.Capsule()
        )
        .accessibilityLabel("Generating response")
    }

    private var metricsPill: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            if let ttfb = message.ttfbMs, ttfb > 0 {
                indicator(icon: "bolt.fill", value: ttfb < 1000 ? "\(ttfb)ms" : String(format: "%.1fs", Double(ttfb) / 1000.0), color: ttfbColor(ttfb))
            }
            if let tps = message.tokPerSec, tps > 0 {
                indicator(icon: "speedometer", value: tps >= 1000 ? String(format: "%.1ft/s", tps / 1000.0) : String(format: "%.0ft/s", tps), color: throughputColor(tps))
            }
            if let tokens = message.outputTokens, tokens > 0 {
                indicator(icon: "text.word.count", value: tokens >= 1000 ? String(format: "%.1fKt", Double(tokens) / 1000.0) : "\(tokens)t", color: V4Color.textSecondary)
            }
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, 3)
        .background(
            V4Color.border.opacity(V2Depth.stateDisabled),
            in: SwiftUI.Capsule()
        )
    }

    private func indicator(icon: String, value: String, color: Color) -> some View {
        HStack(spacing: 2) {
            Image(systemName: icon)
                .foregroundStyle(a11y.highContrast ? V4Color.HighContrast.accent : color)
                .font(.system(size: a11y.scaledFontSize(8)))
            Text(value)
                .font(.system(size: a11y.scaledFontSize(9)))
        }
    }

    private func ttfbColor(_ ms: Int) -> Color {
        switch ms {
        case 0..<500: return V4Color.success
        case 500..<1500: return V4Color.warning
        default: return V4Color.error
        }
    }

    private func throughputColor(_ tps: Double) -> Color {
        switch tps {
        case 50...: return V4Color.success
        case 20..<50: return V4Color.warning
        default: return V4Color.error
        }
    }
}

// MARK: - Previews

struct MessageStatusIndicators_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Streaming
            MessageStatusIndicators(
                message: ChatMessage(role: .assistant, text: "Hello"),
                isStreaming: true,
                streamingTTFB: 450,
                streamingTokensPerSec: 85,
                streamingOutputTokens: 42
            )
            .padding()
            .background(V4Color.background)
            .environmentObject(AccessibilityManager.shared)
            .previewDisplayName("Streaming")

            // Fast Response
            MessageStatusIndicators(
                message: ChatMessage(role: .assistant, text: "Hello"),
                isStreaming: false,
                streamingTTFB: 0,
                streamingTokensPerSec: 0,
                streamingOutputTokens: 0
            )
            .padding()
            .background(V4Color.background)
            .environmentObject(AccessibilityManager.shared)
            .previewDisplayName("Fast Response")

            // With Metrics (Fast)
            let msg2 = makeMessage(text: "Hello", ttfbMs: 320, tokPerSec: 95, outputTokens: 1567)
            MessageStatusIndicators(
                message: msg2,
                isStreaming: false,
                streamingTTFB: 0,
                streamingTokensPerSec: 0,
                streamingOutputTokens: 0
            )
            .padding()
            .background(V4Color.background)
            .environmentObject(AccessibilityManager.shared)
            .previewDisplayName("With Metrics")

            // With Metrics (Slow)
            let msg3 = makeMessage(text: "Hello", ttfbMs: 2800, tokPerSec: 12, outputTokens: 890)
            MessageStatusIndicators(
                message: msg3,
                isStreaming: false,
                streamingTTFB: 0,
                streamingTokensPerSec: 0,
                streamingOutputTokens: 0
            )
            .padding()
            .background(V4Color.background)
            .environmentObject(AccessibilityManager.shared)
            .previewDisplayName("Slow Response")
        }
    }

    private static func makeMessage(text: String, ttfbMs: Int, tokPerSec: Double, outputTokens: Int) -> ChatMessage {
        var msg = ChatMessage(role: .assistant, text: text)
        msg.ttfbMs = ttfbMs
        msg.tokPerSec = tokPerSec
        msg.outputTokens = outputTokens
        return msg
    }
}

struct CompactStatusPill_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Streaming
            CompactStatusPill(
                message: ChatMessage(role: .assistant, text: "Hello"),
                isStreaming: true,
                streamingTTFB: 450,
                streamingTokensPerSec: 85
            )
            .padding()
            .background(V4Color.background)
            .environmentObject(AccessibilityManager.shared)
            .previewDisplayName("Streaming")

            // With Metrics (Fast)
            let msg2 = makeMessage(text: "Hello", ttfbMs: 320, tokPerSec: 95, outputTokens: 1567)
            CompactStatusPill(
                message: msg2,
                isStreaming: false,
                streamingTTFB: 0,
                streamingTokensPerSec: 0
            )
            .padding()
            .background(V4Color.background)
            .environmentObject(AccessibilityManager.shared)
            .previewDisplayName("Fast Metrics")

            // With Metrics (Slow)
            let msg3 = makeMessage(text: "Hello", ttfbMs: 2800, tokPerSec: 12, outputTokens: 890)
            CompactStatusPill(
                message: msg3,
                isStreaming: false,
                streamingTTFB: 0,
                streamingTokensPerSec: 0
            )
            .padding()
            .background(V4Color.background)
            .environmentObject(AccessibilityManager.shared)
            .previewDisplayName("Slow Metrics")
        }
    }

    private static func makeMessage(text: String, ttfbMs: Int, tokPerSec: Double, outputTokens: Int) -> ChatMessage {
        var msg = ChatMessage(role: .assistant, text: text)
        msg.ttfbMs = ttfbMs
        msg.tokPerSec = tokPerSec
        msg.outputTokens = outputTokens
        return msg
    }
}

struct IndividualIndicators_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            TTFBIndicator(ttfbMs: 320)
            TTFBIndicator(ttfbMs: 850)
            TTFBIndicator(ttfbMs: 2100)
            Divider()
            ThroughputIndicator(tokensPerSec: 120)
            ThroughputIndicator(tokensPerSec: 45)
            ThroughputIndicator(tokensPerSec: 8)
            Divider()
            TokenCountIndicator(count: 1567)
            TokenCountIndicator(count: 24300)
        }
        .padding()
        .background(V4Color.background)
        .environmentObject(AccessibilityManager.shared)
        .previewDisplayName("Individual Indicators")
    }
}
