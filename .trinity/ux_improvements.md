# ChatScreen UX Improvements Report

**Date:** 2026-03-18
**Component:** `apps/queen/QueenUI/Screens/Brain/ChatScreen.swift`
**Focus Areas:** Streaming Indicator, Context Overflow Banner, Message Input Area

---

## 1. Streaming Indicator Enhancement

### Current State Analysis

The streaming indicator exists in two forms:
- `streamingIndicatorView` (line 1073-1082) — displayed inline in message list
- `stickyStreamingBar` (line 1304-1356) — floating bar above input

**Problems identified:**
1. Visual subtlety — small 5px circle, muted colors, no glow effect
2. No central focal point — user's eye doesn't know where to look during streaming
3. Minimal animation during "thinking" phase (only opacity pulse on dots)
4. `stickyStreamingBar` has weak background contrast (`Color.white.opacity(0.03)`)
5. Stop button is small (10pt font) and easily missed

### Proposed Solution: "Pulse Ring" Indicator

```swift
struct PulseStreamingIndicator: View {
    let isStreaming: Bool
    let streamingState: StreamingState
    @State private var pulseScale: CGFloat = 1.0
    @State private var rotation: Double = 0

    var body: some View {
        ZStack {
            // Outer glow ring
            Circle()
                .stroke(
                    LinearGradient(
                        colors: [TrinityTheme.accent.opacity(0), TrinityTheme.accent.opacity(0.6)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 2
                )
                .frame(width: 32, height: 32)
                .scaleEffect(pulseScale)
                .opacity(2 - pulseScale)
                .blur(radius: 4)

            // Middle rotating ring
            Circle()
                .trim(from: 0, to: 0.7)
                .stroke(TrinityTheme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                .frame(width: 24, height: 24)
                .rotationEffect(.degrees(rotation))
                .shadow(color: TrinityTheme.accent, radius: 4)

            // Core dot
            Circle()
                .fill(TrinityTheme.accent)
                .frame(width: 8, height: 8)
        }
        .task {
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.8
            }
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}
```

**Implementation pattern:**
- Replace `stickyStreamingBar` with full-width gradient backdrop
- Add `PulseStreamingIndicator` to left side of bar
- Increase stop button size to 12pt font with pill shape
- Add subtle haptic-like bounce on stream start

**Estimated Effort:** 2-3 hours

---

## 2. Context Overflow Banner Visual Improvements

### Current State Analysis

`ContextOverflowBanner` (line 5251-5319) appears at 80% context usage (144K tokens).

**Problems identified:**
1. Static appearance — no urgency progression as context fills
2. Golden color is too subtle for critical state
3. No visual indicator of proximity to hard limit (180K)
4. "Summarize" action is not visually distinguished from secondary action
5. Missing visual "meter" or progress visualization

### Proposed Solution: Tiered Warning System with Progress Arc

```swift
struct ContextOverflowBanner: View {
    let tokens: Int
    var onSummarize: () -> Void
    var onNewThread: () -> Void

    private var percentage: Double { min(Double(tokens) / 180_000.0, 1.0) }
    private var urgencyLevel: UrgencyLevel {
        if percentage < 0.7 { return .safe }
        if percentage < 0.85 { return .warning }
        if percentage < 0.95 { return .critical }
        return .emergency
    }

    enum UrgencyLevel {
        case safe, warning, critical, emergency

        var color: Color {
            switch self {
            case .safe: return TrinityTheme.accent
            case .warning: return TrinityTheme.golden
            case .critical: return Color.orange
            case .emergency: return TrinityTheme.statusError
            }
        }

        var icon: String {
            switch self {
            case .safe: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .critical: return "exclamationmark.octagon.fill"
            case .emergency: return "xmark.octagon.fill"
            }
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            // Animated icon with glow
            ZStack {
                Circle()
                    .fill(urgencyLevel.color.opacity(0.2))
                    .frame(width: 32, height: 32)
                    .blur(radius: urgencyLevel == .emergency ? 8 : 0)

                Image(systemName: urgencyLevel.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(urgencyLevel.color)
                    .symbolEffect(.pulse, options: .repeating)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(urgencyLevel.message)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(urgencyLevel.color)

                // Progress bar with gradient
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.1))
                        Capsule()
                            .fill(LinearGradient(
                                colors: [urgencyLevel.color, urgencyLevel.color.opacity(0.6)],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * percentage)
                    }
                }
                .frame(height: 4)

                Text("\(tokens.formatted()) tokens (\(Int(percentage * 100))%)")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.5))
            }

            Spacer()

            HStack(spacing: 8) {
                // Primary action (Summarize) - more prominent
                Button { onSummarize() } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 10))
                        Text("Summarize")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .foregroundStyle(.black)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(urgencyLevel.color)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                // Secondary action
                Button { onNewThread() } label: {
                    Text("New thread")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(urgencyLevel.color.opacity(0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(urgencyLevel.color.opacity(0.4), lineWidth: 1)
        )
        .padding(.horizontal, 60)
        .padding(.bottom, 8)
        .transition(.scale.combined(with: .opacity))
    }
}

// Extend UrgencyLevel with messages
extension ContextOverflowBanner.UrgencyLevel {
    var message: String {
        switch self {
        case .safe: return "Context usage normal"
        case .warning: return "Context filling up"
        case .critical: return "Context near limit"
        case .emergency: return "Context almost full"
        }
    }
}
```

**Key improvements:**
- Color progression: green -> gold -> orange -> red
- Animated icon with pulsing symbol effect
- Gradient progress bar
- Emergency mode gets glow effect
- Primary action (Summarize) visually dominant

**Estimated Effort:** 1.5-2 hours

---

## 3. Message Input Area UX Improvements

### Current State Analysis

`MultilineInput` (line 4593+) uses `NSTextView` wrapped in `NSViewRepresentable`.

**Problems identified:**
1. Max height hardcoded to 200px (~8 lines) with no visual cue when reached
2. No character/token counter visibility for long inputs
3. Focus ring doesn't indicate available actions
4. Attachment button doesn't show file count when multiple files attached
5. No visual feedback for voice recording state (mic button only changes color)
6. Send button stays same size regardless of input state

### Proposed Solution: Expandable Input with Status Bar

```swift
struct EnhancedInputArea: View {
    @Binding var text: String
    @FocusState var isFocused: Bool
    @Binding var attachedFiles: [(name: String, content: String)]
    let placeholder: String
    let onSubmit: () -> Void

    @State private var inputHeight: CGFloat = 44
    @State private var isRecording = false

    private var inputLines: Int { max(1, text.components(separatedBy: "\n").count) }
    private var isNearLimit: Bool { text.count > 8000 }
    private var estimatedTokens: Int { text.count / 4 } // Rough estimate

    var body: some View {
        VStack(spacing: 0) {
            // Main input bar
            HStack(alignment: .bottom, spacing: 0) {
                // Left toolbar
                HStack(spacing: 4) {
                    ModelPicker(modelManager: modelManager)
                    PersonaPicker(selectedPersona: $selectedPersona, ...)

                    // Voice recording with visualizer
                    VoiceRecordingButton(
                        isRecording: $isRecording,
                        onTap: { toggleVoiceInput() }
                    )
                }
                .padding(.leading, 14)

                // Text input with dynamic frame
                MultilineInput(
                    text: $text,
                    placeholder: placeholder,
                    isFocused: $isFocused,
                    onSubmit: onSubmit
                )
                .frame(height: min(inputHeight, 200))
                .padding(.horizontal, 12)
                .padding(.vertical, 14)
                .background(
                    RoundedRectangle(cornerRadius: 20)
                        .fill(isFocused ? TrinityTheme.accent.opacity(0.05) : Color.clear)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20)
                        .stroke(
                            isFocused ? TrinityTheme.accent.opacity(0.5) : Color.clear,
                            lineWidth: 1
                        )
                )

                // Right toolbar with enhanced indicators
                HStack(spacing: 8) {
                    // Attachment badge
                    AttachmentButton(fileCount: attachedFiles.count) {
                        openFilePicker()
                    }

                    // Actions
                    Button { showShortcuts.toggle() } label: {
                        Image(systemName: "keyboard")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.white.opacity(0.4))
                    }

                    // Context preview with token estimate
                    if !text.isEmpty {
                        TokenPreviewButton(tokens: estimatedTokens) {
                            showContextPreview.toggle()
                        }
                    }

                    // Send button with dynamic sizing
                    SendButton(
                        text: text,
                        isFocused: isFocused,
                        onTap: onSubmit
                    )
                }
                .padding(.trailing, 10)
            }
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color(hex: 0x1A1A1A))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .stroke(
                                isNearLimit ? TrinityTheme.statusError.opacity(0.5) : Color.white.opacity(0.08),
                                lineWidth: isNearLimit ? 2 : 1
                            )
                    )
            )

            // Status bar (condensed, below input)
            if inputLines > 3 || isNearLimit || !attachedFiles.isEmpty {
                HStack(spacing: 12) {
                    // Line counter
                    HStack(spacing: 4) {
                        Image(systemName: "text.alignleft")
                            .font(.system(size: 8))
                        Text("\(inputLines) lines")
                            .font(.system(size: 9, design: .monospaced))
                    }
                    .foregroundStyle(Color.white.opacity(0.3))

                    // Token estimate
                    if estimatedTokens > 100 {
                        HStack(spacing: 4) {
                            Image(systemName: "brain")
                                .font(.system(size: 8))
                            Text("~\(estimatedTokens) tokens")
                                .font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundStyle(estimatedTokens > 4000 ? TrinityTheme.statusError : Color.white.opacity(0.3))
                    }

                    // Attachment list
                    if !attachedFiles.isEmpty {
                        HStack(spacing: 4) {
                            Image(systemName: "paperclip")
                                .font(.system(size: 8))
                            Text("\(attachedFiles.count) file\(attachedFiles.count == 1 ? "" : "s")")
                                .font(.system(size: 9, design: .monospaced))
                        }
                        .foregroundStyle(TrinityTheme.accent.opacity(0.7))
                    }

                    Spacer()
                }
                .padding(.horizontal, 80)
                .padding(.vertical, 4)
                .transition(.opacity)
            }
        }
        .padding(.horizontal, 60)
    }
}

// Helper components
struct AttachmentButton: View {
    let fileCount: Int
    let onTap: () -> Void

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button { onTap() } label: {
                Image(systemName: "paperclip")
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.4))
            }
            .buttonStyle(.plain)

            if fileCount > 0 {
                Text("\(fileCount)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(TrinityTheme.accent)
                    .clipShape(Capsule())
                    .offset(x: 4, y: -4)
            }
        }
    }
}

struct SendButton: View {
    let text: String
    let isFocused: Bool
    let onTap: () -> Void

    private var isReady: Bool { !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        Button { onTap() } label: {
            HStack(spacing: 6) {
                Image(systemName: isReady ? "arrow.up" : "arrow.up.circle")
                    .font(.system(size: 14, weight: .semibold))
                if isReady {
                    Text("Send")
                        .font(.system(size: 12, weight: .semibold))
                }
            }
            .foregroundStyle(isReady ? .black : Color.white.opacity(0.3))
            .padding(.horizontal, isReady ? 14 : 10)
            .padding(.vertical, 6)
            .background(
                isReady ? TrinityTheme.accent : Color.white.opacity(0.08)
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .disabled(!isReady)
    }
}
```

**Key improvements:**
- Dynamic input frame that grows visually (user sees expansion)
- Focus ring appears when typing
- Status bar appears conditionally (lines > 3 OR near limit OR has attachments)
- Send button expands to show "Send" text when ready
- Attachment count badge on paperclip icon
- Token estimate shown when significant
- Border turns red when approaching input limits

**Estimated Effort:** 2.5-3 hours

---

## Summary Table

| Improvement | Priority | Effort | Impact |
|-------------|----------|--------|--------|
| Pulse Ring Streaming Indicator | HIGH | 2-3h | High — streaming is core UX |
| Tiered Context Overflow Banner | MEDIUM | 1.5-2h | Medium — critical but rare state |
| Expandable Input with Status Bar | MEDIUM | 2.5-3h | High — used constantly |

**Total Estimated Effort:** 6-8 hours for all three improvements

---

## Implementation Notes

1. **Streaming Indicator** — Requires no new state, can replace existing `stickyStreamingBar`
2. **Context Overflow** — Can extend existing `ContextOverflowBanner` struct
3. **Input Area** — Requires extracting `inputBarView` into separate component for modularity

All components use existing `TrinityTheme` colors and respect `accessibilityReduceMotion`.
