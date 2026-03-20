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
        case .none: return V4Color.success
        case .info: return V4Color.success
        case .warning: return V4Color.warning
        case .urgent: return V4Color.warning  // Dark orange
        case .critical: return V4Color.error
        }
    }

    var bgColor: Color {
        switch self {
        case .none: return V4Color.success.opacity(0.08)
        case .info: return V4Color.success.opacity(0.08)
        case .warning: return V4Color.warning.opacity(V2Depth.bgSubtle)
        case .urgent: return V4Color.warning.opacity(0.12)
        case .critical: return V4Color.error.opacity(V2Depth.bgSidebarHover)
        }
    }

    var borderColor: Color {
        switch self {
        case .none: return V4Color.success.opacity(0.2)
        case .info: return V4Color.success.opacity(V2Depth.stateHover)
        case .warning: return V4Color.warning.opacity(V1Theme.opacityTextTertiary)
        case .urgent: return V4Color.warning.opacity(V2Depth.stateDisabled)
        case .critical: return V4Color.error.opacity(V1Theme.opacityTextSecondary)
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
                HStack(spacing: ParietalSpacing.md) {
                    // Animated icon with glow
                    ZStack {
                        if tier.shouldAnimate && !reduceMotion {
                            Circle()
                                .fill(tier.color.opacity(V2Depth.stateHover))
                                .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)
                                .scaleEffect(pulseScale)
                                .blur(radius: 4)
                        }

                        Image(systemName: tier.icon)
                            .font(tier == .critical ? WernickeTypography.size16 : WernickeTypography.size14)
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
                        HStack(spacing: ParietalSpacing.sm - 2) {
                            Text(tier.title)
                                .font(WernickeTypography.captionBold)
                                .foregroundStyle(tier.color)

                            Text("\(tokens.formatted()) tokens")
                                .font(WernickeTypography.size10)
                                .foregroundStyle(V4Color.textSecondary)

                            Text("(\(Int(percentage * 100))%)")
                                .font(WernickeTypography.size10.weight(.semibold))
                                .foregroundStyle(tier.color)
                        }

                        if !tier.description.isEmpty {
                            Text(tier.description)
                                .font(WernickeTypography.size10)
                                .foregroundStyle(V4Color.textSecondary.opacity(0.7))
                        }

                        // Gradient progress bar
                        GeometryReader { geometry in
                            ZStack(alignment: .leading) {
                                // Background track
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.white.opacity(V2Depth.bgSubtle))
                                    .frame(height: ParietalSpacing.xs)

                                // Gradient fill
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(gradientBar)
                                    .frame(width: geometry.size.width * percentage, height: ParietalSpacing.microHeight)

                                // Threshold markers
                                ForEach([0.8, 0.9, 0.95, 0.99], id: \.self) { threshold in
                                    Rectangle()
                                        .fill(Color.white.opacity(V2Depth.stateHover))
                                        .frame(width: ParietalSpacing.hairline, height: 6)
                                        .offset(x: geometry.size.width * threshold)
                                }
                            }
                        }
                        .frame(height: ParietalSpacing.xs)
                    }

                    Spacer()

                    // Expand/collapse button
                    Button {
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(WernickeTypography.miniSemibold)
                            .foregroundStyle(V4Color.textSecondary)
                            .padding(4)
                            .background(Circle().fill(Color.white.opacity(0.05)))
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(isExpanded ? "Collapse actions" : "Expand actions")
                }
                .padding(ParietalSpacing.md)
                .background(tier.bgColor)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(tier.borderColor, lineWidth: 1)
                )

                // Expanded action buttons
                if isExpanded {
                    VStack(spacing: ParietalSpacing.sm) {
                        Divider()
                            .background(Color.white.opacity(V2Depth.bgSubtle))

                        // Primary actions
                        HStack(spacing: ParietalSpacing.sm) {
                            SimpleActionButton(
                                icon: "text.alignleft",
                                title: "Summarize",
                                color: tier.color,
                                action: onSummarize
                            )

                            SimpleActionButton(
                                icon: "square.and.pencil",
                                title: "New Thread",
                                color: V4Color.accent,
                                action: onNewThread
                            )

                            if let onArchive = onArchive {
                                SimpleActionButton(
                                    icon: "archivebox",
                                    title: "Archive Old",
                                    color: V4Color.purple,
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
                    .padding(.horizontal, ParietalSpacing.md)
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
            V4Color.success,
            V4Color.warning,
            V4Color.warning,
            V4Color.error
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
            HStack(spacing: ParietalSpacing.xs) {
                Image(systemName: icon)
                    .font(WernickeTypography.size9)
                Text(title)
                    .font(WernickeTypography.miniSemibold)
            }
            .foregroundStyle(color)
            .padding(.horizontal, ParietalSpacing.sm + 2)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08))
            .clipShape(SwiftUI.Capsule())
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
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            HStack {
                Image(systemName: "lightbulb.fill")
                    .font(WernickeTypography.size8)
                    .foregroundStyle(V4Color.warning)
                Text("Smart suggestions")
                    .font(WernickeTypography.miniSemibold)
                    .foregroundStyle(V4Color.textSecondary)
                Spacer()
            }

            Text("Remove oldest messages to free up context space")
                .font(WernickeTypography.size9)
                .foregroundStyle(V4Color.textSecondary.opacity(V1Theme.opacityTextSecondary))

            HStack(spacing: ParietalSpacing.sm) {
                ForEach([5, 10, 20], id: \.self) { count in
                    Button {
                        onRemoveOldest(count)
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "minus.circle.fill")
                                .font(WernickeTypography.size7)
                            Text("Oldest \(count)")
                                .font(WernickeTypography.microMedium)
                        }
                        .foregroundStyle(removeCount == count ? V4Color.error : V4Color.textSecondary)
                        .padding(.horizontal, ParietalSpacing.sm)
                        .padding(.vertical, ParietalSpacing.xs)
                        .background((removeCount == count ? tier.color : Color.white).opacity(0.05))
                        .clipShape(RoundedRectangle(cornerRadius: 5))
                        .overlay(
                            RoundedRectangle(cornerRadius: 5)
                                .stroke((removeCount == count ? tier.color : Color.white.opacity(V2Depth.bgSubtle)), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    .onTapGesture {
                        removeCount = count
                    }
                }
            }
        }
        .padding(ParietalSpacing.sm)
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
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: tier.icon)
                .font(WernickeTypography.size8)
                .foregroundStyle(tier.color)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Color.white.opacity(V2Depth.bgSubtle))
                        .frame(height: ParietalSpacing.xxxs)

                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(tier.color)
                        .frame(width: geometry.size.width * percentage, height: 3)
                }
            }
            .frame(width: ParietalSpacing.buttonMediumWidth)

            if isHovering {
                Text("\(tokens.formatted()) / \(maxTokens.formatted())")
                    .font(WernickeTypography.size9Mono)
                    .foregroundStyle(V4Color.textSecondary)
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

