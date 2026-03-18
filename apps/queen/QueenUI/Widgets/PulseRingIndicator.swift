import SwiftUI

// MARK: - Pulse Ring Streaming Indicator

/// An animated pulse ring indicator for streaming state with enhanced visual feedback.
/// Respects accessibility reduce motion setting and provides clear visual cues
/// for connection and streaming states.
struct PulseRingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isStreaming: Bool
    let streamingState: StreamingState
    let onStop: () -> Void

    // Metrics for display
    var ttfb: Int = 0
    var tokensPerSec: Double = 0
    var outputTokens: Int = 0
    var maxTokens: Int = 0

    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0
    @State private var corePulse: CGFloat = 1.0

    private var isConnecting: Bool {
        if case .connecting = streamingState { return true }
        return false
    }

    private var isActive: Bool {
        if case .streaming = streamingState { return true }
        return isConnecting
    }

    private var primaryColor: Color {
        isConnecting ? TrinityTheme.statusWarn : TrinityTheme.accent
    }

    private var statusText: String {
        isConnecting ? "Connecting..." : "Streaming"
    }

    private var progressPercent: Double {
        guard maxTokens > 0 else { return 0 }
        return min(Double(outputTokens) / Double(maxTokens), 1.0)
    }

    var body: some View {
        HStack(spacing: 14) {
            // Pulse Ring Indicator
            ZStack {
                // Outer glow ring (expands outward)
                Circle()
                    .stroke(
                        LinearGradient(
                            colors: [primaryColor.opacity(0), primaryColor.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 2
                    )
                    .frame(width: 36, height: 36)
                    .scaleEffect(reduceMotion ? 1 : pulseScale)
                    .opacity(reduceMotion ? 0.5 : (2 - pulseScale))
                    .blur(radius: reduceMotion ? 0 : 3)

                // Middle rotating ring
                Circle()
                    .trim(from: 0, to: 0.75)
                    .stroke(
                        primaryColor,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(reduceMotion ? 0 : rotation))
                    .shadow(color: primaryColor.opacity(0.6), radius: 3)

                // Core dot
                Circle()
                    .fill(primaryColor)
                    .frame(width: 10, height: 10)
                    .scaleEffect(corePulse)
            }
            .frame(width: 44, height: 44)
            .task(id: isActive) {
                guard isActive, !reduceMotion else {
                    pulseScale = 1.0
                    rotation = 0
                    corePulse = 1.0
                    return
                }

                // Pulse animation for outer ring
                withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) {
                    pulseScale = 1.6
                }

                // Rotation for middle ring
                withAnimation(.linear(duration: 2.2).repeatForever(autoreverses: false)) {
                    rotation = 360
                }

                // Core pulse
                withAnimation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true)) {
                    corePulse = 1.3
                }
            }

            // Status and metrics
            VStack(alignment: .leading, spacing: 3) {
                Text(statusText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(primaryColor)

                // Progress bar for long operations
                if maxTokens > 0 {
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            SwiftUI.Capsule()
                                .fill(Color.white.opacity(0.08))
                            SwiftUI.Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [primaryColor, primaryColor.opacity(0.6)],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progressPercent)
                        }
                    }
                    .frame(height: 3)
                }

                // Metrics row
                HStack(spacing: 8) {
                    if ttfb > 0 {
                        Text("TTFB: \(ttfb)ms")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(ttfbColor(ttfb))
                    }

                    if tokensPerSec > 0 {
                        HStack(spacing: 3) {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: 7))
                            Text(String(format: "%.0f/s", tokensPerSec))
                                .font(.system(size: 9, weight: .bold, design: .monospaced))
                        }
                        .foregroundStyle(speedColor(tokensPerSec))
                    }

                    if outputTokens > 0 {
                        Text("\(outputTokens) tok")
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }
            }

            Spacer()

            // Enhanced Stop Button
            Button {
                onStop()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 12, weight: .semibold))
                    Text("Stop")
                        .font(.system(size: 12, weight: .bold))
                }
                .foregroundStyle(.black)
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(TrinityTheme.statusError)
                .clipShape(SwiftUI.Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Stop generating")
            .accessibilityHint("Press Escape to stop")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .fill(
                    LinearGradient(
                        colors: [
                            primaryColor.opacity(0.08),
                            primaryColor.opacity(0.03)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(primaryColor.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Helper Functions

    private func ttfbColor(_ ms: Int) -> Color {
        if ms < 2000 { return TrinityTheme.textMuted }
        if ms < 5000 { return TrinityTheme.statusWarn }
        return TrinityTheme.statusError
    }

    private func speedColor(_ tps: Double) -> Color {
        if tps < 20 { return TrinityTheme.statusError }
        if tps < 50 { return TrinityTheme.statusWarn }
        return TrinityTheme.statusOK
    }
}

// MARK: - Compact Pulse Ring (for inline use)

/// A compact version of the pulse ring for inline message list display.
struct CompactPulseRing: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let state: StreamingState

    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0

    private var isActive: Bool {
        switch state {
        case .connecting, .streaming: return true
        default: return false
        }
    }

    private var primaryColor: Color {
        switch state {
        case .connecting: return TrinityTheme.statusWarn
        case .streaming: return TrinityTheme.accent
        default: return TrinityTheme.textMuted
        }
    }

    var body: some View {
        ZStack {
            // Outer glow
            Circle()
                .stroke(primaryColor.opacity(0.4), lineWidth: 1.5)
                .frame(width: 20, height: 20)
                .scaleEffect(reduceMotion ? 1 : pulseScale)
                .opacity(reduceMotion ? 0.6 : (2 - pulseScale) * 0.5)

            // Rotating segment
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(
                    primaryColor,
                    style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
                )
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(reduceMotion ? 0 : rotation))

            // Core
            Circle()
                .fill(primaryColor)
                .frame(width: 5, height: 5)
        }
        .frame(width: 22, height: 22)
        .task(id: isActive) {
            guard isActive, !reduceMotion else {
                pulseScale = 1.0
                rotation = 0
                return
            }

            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.5
            }
            withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
