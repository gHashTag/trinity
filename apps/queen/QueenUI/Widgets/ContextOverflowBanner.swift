import SwiftUI

// MARK: - Context Warning Tier

enum ContextWarningTier: Comparable {
    case none       // < 80%
    case info       // 80-90%
    case warning    // 90-95%
    case urgent     // 95-99%
    case critical   // 99-100%

    var color: Color {
        switch self {
        case .none: return TrinityTheme.statusOK
        case .info: return TrinityTheme.statusOK
        case .warning: return TrinityTheme.statusWarn
        case .urgent: return Color(hex: 0xFF8C00)  // Dark orange
        case .critical: return TrinityTheme.statusError
        }
    }

    var bgColor: Color {
        switch self {
        case .none: return TrinityTheme.statusOK.opacity(0.08)
        case .info: return TrinityTheme.statusOK.opacity(0.08)
        case .warning: return TrinityTheme.statusWarn.opacity(0.1)
        case .urgent: return Color(hex: 0xFF8C00).opacity(0.12)
        case .critical: return TrinityTheme.statusError.opacity(0.15)
        }
    }

    var borderColor: Color {
        switch self {
        case .none: return TrinityTheme.statusOK.opacity(0.2)
        case .info: return TrinityTheme.statusOK.opacity(0.3)
        case .warning: return TrinityTheme.statusWarn.opacity(0.4)
        case .urgent: return Color(hex: 0xFF8C00).opacity(0.5)
        case .critical: return TrinityTheme.statusError.opacity(0.6)
        }
    }

    var icon: String {
        switch self {
        case .none: return "checkmark.circle"
        case .info: return "info.circle"
        case .warning: return "exclamationmark.triangle.fill"
        case .urgent: return "exclamationmark.triangle.fill"
        case .critical: return "exclamationmark.octagon.fill"
        }
    }

    var title: String {
        switch self {
        case .none: return "Context OK"
        case .info: return "Context filling up"
        case .warning: return "Context warning"
        case .urgent: return "Context urgent"
        case .critical: return "Context overflow imminent"
        }
    }

    var description: String {
        switch self {
        case .none: return ""
        case .info: return "Consider summarizing soon"
        case .warning: return "Summarize or start new thread"
        case .urgent: return "Strongly recommend action"
        case .critical: return "Cannot send more messages"
        }
    }

    var shouldAnimate: Bool {
        switch self {
        case .none, .info: return false
        case .warning: return true
        case .urgent: return true
        case .critical: return true
        }
    }
}

// MARK: - Context Overflow Banner

struct ContextOverflowBanner: View {
    let tokens: Int
    let maxTokens: Int
    var onSummarize: () -> Void
    var onNewThread: () -> Void
    var onArchive: ((Int) -> Void)? = nil
    var onRemoveOldest: ((Int) -> Void)? = nil

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isExpanded = false
    @State private var pulseScale: CGFloat = 1.0

    private var percentage: Double {
        min(Double(tokens) / Double(maxTokens), 1.0)
    }

    private var tier: ContextWarningTier {
        let pct = percentage
        if pct < 0.80 { return .none }
        if pct < 0.90 { return .info }
        if pct < 0.95 { return .warning }
        if pct < 0.99 { return .urgent }
        return .critical
    }

    var body: some View {
        if tier != .none {
            VStack(spacing: 0) {
                // Main banner
                HStack(spacing: 12) {
                    // Animated icon with glow
                    ZStack {
                        if tier.shouldAnimate && !reduceMotion {
                            Circle()
                                .fill(tier.color.opacity(0.3))
                                .frame(width: 28, height: 28)
                                .scaleEffect(pulseScale)
                                .blur(radius: 4)
                        }

                        Image(systemName: tier.icon)
                            .font(.system(size: tier == .critical ? 16 : 14))
                            .foregroundStyle(tier.color)
                            .scaleEffect(tier.shouldAnimate && !reduceMotion ? pulseScale : 1.0)
                    }
                    .onAppear {
                        if tier.shouldAnimate && !reduceMotion {
                            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                                pulseScale = 1.3
                            }
                        }
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(tier.title)
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(tier.color)

                            Text("\(tokens.formatted()) tokens")
                                .font(.system(size: 10))
                                .foregroundStyle(TrinityTheme.textMuted)

                            Text("(\(Int(percentage * 100))%)")
                                .font(.system(size: 10, weight: .semibold, design: .monospaced))
                                .foregroundStyle(tier.color)
                        }

                        if !tier.description.isEmpty {
                            Text(tier.description)
                                .font(.system(size: 10))
                                .foregroundStyle(TrinityTheme.textMuted.opacity(0.7))
                        }

                        // Gradient progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(0.1))
                                    .frame(height: 4)

                                // Gradient fill
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(gradientBar)
                                    .frame(width: geometry.size.width * percentage, height: 4)

                                // Threshold markers
                                ForEach([0.8, 0.9, 0.95, 0.99], id: \.self) { threshold in
                                    Rectangle()
                                        .fill(Color.white.opacity(0.3))
                                        .frame(width: 1, height: 6)
                                        .offset(x: geometry.size.width * threshold)
                                }
                            }
                        }
                        .frame(height: 4)
                    }

                    Spacer()

                    // Expand/collapse button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(TrinityTheme.textMuted)
                            .padding(4)
                            .background(Circle().fill(Color.white.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Collapse actions" : "Expand actions")
                }
                .padding(12)
                .background(tier.bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(tier.borderColor, lineWidth: 1)
                )

                // Expanded action buttons
                if isExpanded {
                    VStack(spacing: 8) {
                        Divider()
                            .background(Color.white.opacity(0.1))

                        // Primary actions
                        HStack(spacing: 8) {
                            SimpleActionButton(
                                icon: "text.alignleft",
                                title: "Summarize",
                                color: tier.color,
                                action: onSummarize
                            )

                            SimpleActionButton(
                                icon: "square.and.pencil",
                                title: "New Thread",
                                color: TrinityTheme.accent,
                                action: onNewThread
                            )

                            if let onArchive = onArchive {
                                SimpleActionButton(
                                    icon: "archivebox",
                                    title: "Archive Old",
                                    color: TrinityTheme.purple,
                                    action: { onArchive(10) }
                                )
                            }
                        }

                        // Smart suggestions section
                        if let onRemoveOldest = onRemoveOldest {
                            SmartSuggestionsSection(
                                onRemoveOldest: onRemoveOldest,
                                tier: tier
                            )
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                    .background(tier.bgColor)
                }
            }
            .padding(.horizontal, 60)
            .padding(.bottom, 8)
        }
    }

    private var gradientBar: LinearGradient {
        let colors: [Color] = [
            TrinityTheme.statusOK,
            TrinityTheme.statusWarn,
            Color(hex: 0xFF8C00),
            TrinityTheme.statusError
        ]

        return LinearGradient(
            colors: colors,
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Simple Action Button

struct SimpleActionButton: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(title) action")
    }
}

// MARK: - Smart Suggestions Section

struct SmartSuggestionsSection: View {
    let onRemoveOldest: (Int) -> Void
    let tier: ContextWarningTier

    @State private var removeCount = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(TrinityTheme.statusWarn)
                Text("Smart suggestions")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textMuted)
                Spacer()
            }

            Text("Remove oldest messages to free up context space")
                .font(.system(size: 9))
                .foregroundStyle(TrinityTheme.textMuted.opacity(0.6))

            HStack(spacing: 8) {
                ForEach([5, 10, 20], id: \.self) { count in
                    Button {
                        onRemoveOldest(count)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "minus.circle.fill")
                                .font(.system(size: 7))
                            Text("Oldest \(count)")
                                .font(.system(size: 9, weight: .medium))
                        }
                        .foregroundStyle(removeCount == count ? TrinityTheme.statusError : TrinityTheme.textMuted)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background((removeCount == count ? tier.color : Color.white).opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke((removeCount == count ? tier.color : Color.white.opacity(0.1)), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onTapGesture {
                        removeCount = count
                    }
                }
            }
        }
        .padding(8)
        .background(Color.black.opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Compact Context Indicator

struct CompactContextIndicator: View {
    let tokens: Int
    let maxTokens: Int
    @State private var isHovering = false

    private var percentage: Double {
        min(Double(tokens) / Double(maxTokens), 1.0)
    }

    private var tier: ContextWarningTier {
        let pct = percentage
        if pct < 0.80 { return .none }
        if pct < 0.90 { return .info }
        if pct < 0.95 { return .warning }
        if pct < 0.99 { return .urgent }
        return .critical
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: tier.icon)
                .font(.system(size: 8))
                .foregroundStyle(tier.color)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 3)

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(tier.color)
                        .frame(width: geometry.size.width * percentage, height: 3)
                }
            }
            .frame(width: 40)

            if isHovering {
                Text("\(tokens.formatted()) / \(maxTokens.formatted())")
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .transition(.opacity)
            }
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.2)) {
                isHovering = hovering
            }
        }
    }
}

