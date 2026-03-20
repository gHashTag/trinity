// Empty State View — Empty State Illustrations and Messages
import SwiftUI

// MARK: - Empty State View

struct DetailedEmptyState: View {
    let icon: String?
    let title: String
    let message: String
    let actionTitle: String?
    let action: () -> Void

    init(
        icon: String? = nil,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            Spacer()

            // Icon or illustration
            if let icon = icon {
                threeDIconView(icon)
            } else {
                // Default illustration
                emptyIllustration
            }

            // Title and message
            VStack(spacing: ParietalSpacing.sm) {
                Text(title)
                    .font(WernickeTypography.h4Semibold)
                    .foregroundStyle(V4Color.textPrimary)

                Text(message)
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            // Action button
            if let actionTitle = actionTitle {
                Button {
                    action()
                } label: {
                    Text(actionTitle)
                        .font(WernickeTypography.body14Medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, ParietalSpacing.md + ParietalSpacing.md)
                        .padding(.vertical, ParietalSpacing.sm + 2)
                        .background(V4Color.accent)
                        .cornerRadius(V1Theme.cornerSmall)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
    }

    private var emptyIllustration: some View {
        ZStack {
            Circle()
                .fill(V4Color.border.opacity(V2Depth.stateHover))
                .frame(width: 100, height: 100)

            VStack(spacing: ParietalSpacing.xs) {
                ForEach(0..<3) { _ in
                    Rectangle()
                        .fill(V4Color.border)
                        .frame(width: 40, height: 3)
                }
            }
        }
    }

    // 3D-style icon with layered depth effect
    private func threeDIconView(_ iconName: String) -> some View {
        ZStack {
            // Shadow layer
            Circle()
                .fill(V4Color.border.opacity(0.2))
                .frame(width: 88, height: 88)
                .offset(y: 4)

            // Main circle background with gradient
            Circle()
                .fill(
                    LinearGradient(
                        colors: [
                            V4Color.border.opacity(V1Theme.opacityTextTertiary),
                            V4Color.border.opacity(0.2)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 80, height: 80)

            // Icon with layered 3D effect
            ZStack {
                // Shadow icon
                Image(systemName: iconName)
                    .font(WernickeTypography.size32Medium)
                    .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateDisabled))
                    .offset(x: 2, y: 2)

                // Main icon
                Image(systemName: iconName)
                    .font(WernickeTypography.size32Medium)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                V4Color.textSecondary,
                                V4Color.textSecondary.opacity(0.8)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
            }
        }
    }
}

// MARK: - Compact Empty State

struct CompactEmptyState: View {
    let icon: String
    let title: String
    let message: String

    var body: some View {
        HStack(spacing: ParietalSpacing.lg) {
            Image(systemName: icon)
                .font(WernickeTypography.size28)
                .foregroundStyle(V4Color.textSecondary)

            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text(title)
                    .font(WernickeTypography.body14Medium)
                    .foregroundStyle(V4Color.textPrimary)

                Text(message)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }

            Spacer()
        }
        .padding(ParietalSpacing.lg)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
    }
}

// MARK: - List Empty State

struct ListEmptyState: View {
    let title: String
    let message: String
    let icon: String?

    init(
        title: String = "No Items",
        message: String = "There are no items to display",
        icon: String? = nil
    ) {
        self.title = title
        self.message = message
        self.icon = icon
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.md) {
            Image(systemName: icon ?? "tray")
                .font(WernickeTypography.size40)
                .foregroundStyle(V4Color.border)

            Text(title)
                .font(WernickeTypography.bodyMedium)
                .foregroundStyle(V4Color.textPrimary)

            Text(message)
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(40)
        .background(V4Color.surface)
    }
}

// MARK: - Search Empty State (Enhanced with Illustration + Action)

struct SearchEmptyState: View {
    let query: String
    let onRetrySearch: () -> Void

    init(query: String, onRetrySearch: @escaping () -> Void = {}) {
        self.query = query
        self.onRetrySearch = onRetrySearch
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.xl) {
            // 3D Magnifying glass illustration with layered effect
            ZStack {
                // Shadow circles
                Circle()
                    .fill(V4Color.border.opacity(V2Depth.bgSidebarHover))
                    .frame(width: 100, height: 100)
                    .offset(y: 6)

                // Main gradient circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                V4Color.border.opacity(V1Theme.opacityTextTertiary),
                                V4Color.border.opacity(V2Depth.bgSidebarHover)
                            ],
                            center: .topLeading,
                            startRadius: 0,
                            endRadius: 50
                        )
                    )
                    .frame(width: 88, height: 88)

                // Magnifying glass icon with 3D effect
                ZStack {
                    Image(systemName: "magnifyingglass")
                        .font(WernickeTypography.size36Light)
                        .foregroundStyle(V4Color.textSecondary.opacity(V1Theme.opacityTextTertiary))
                        .offset(x: 3, y: 3)

                    Image(systemName: "magnifyingglass")
                        .font(WernickeTypography.size36Light)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    V4Color.textSecondary.opacity(0.9),
                                    V4Color.textSecondary.opacity(V1Theme.opacityTextSecondary)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }

            VStack(spacing: ParietalSpacing.sm) {
                Text("No results for \"\(query)\"")
                    .font(WernickeTypography.size17)
                    .foregroundStyle(V4Color.textPrimary)

                Text("Try adjusting your search terms or browse categories")
                    .font(WernickeTypography.size13)
                    .foregroundStyle(V4Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            // Action buttons
            VStack(spacing: ParietalSpacing.md) {
                Button {
                    onRetrySearch()
                } label: {
                    HStack(spacing: ParietalSpacing.sm) {
                        Image(systemName: "arrow.clockwise.circle.fill")
                            .font(WernickeTypography.size16)
                        Text("Try Different Search")
                            .font(WernickeTypography.body14Medium)
                    }
                    .foregroundStyle(.white)
                    .padding(.horizontal, ParietalSpacing.md + ParietalSpacing.md)
                    .padding(.vertical, ParietalSpacing.md)
                    .background(V4Color.accent)
                    .cornerRadius(V1Theme.cornerMedium)
                }
                .buttonStyle(.plain)

                Button {
                    onRetrySearch()
                } label: {
                    Text("Clear Search")
                        .font(WernickeTypography.size13)
                        .foregroundStyle(V4Color.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Error Empty State (Enhanced with Specific Error Messages)

struct ErrorEmptyState: View {
    let title: String
    let message: String
    let retry: () -> Void
    let errorType: ErrorType

    enum ErrorType {
        case network
        case server
        case permission
        case timeout
        case unknown

        var icon: String {
            switch self {
            case .network: return "network.slash"
            case .server: return "server.fail"
            case .permission: return "lock.fill"
            case .timeout: return "clock.badge.exclamationmark"
            case .unknown: return "exclamationmark.triangle.fill"
            }
        }

        var defaultTitle: String {
            switch self {
            case .network: return "Connection Error"
            case .server: return "Server Error"
            case .permission: return "Access Denied"
            case .timeout: return "Request Timed Out"
            case .unknown: return "Something Went Wrong"
            }
        }

        var defaultMessage: String {
            switch self {
            case .network: return "Please check your internet connection and try again."
            case .server: return "Our servers are experiencing issues. Please try again later."
            case .permission: return "You don't have permission to access this resource."
            case .timeout: return "The request took too long to complete. Please try again."
            case .unknown: return "An unexpected error occurred. We're working to fix it."
            }
        }

        var color: Color {
            switch self {
            case .network: return V4Color.warning
            case .server: return V4Color.error
            case .permission: return V4Color.purple
            case .timeout: return V4Color.golden
            case .unknown: return V4Color.error
            }
        }
    }

    init(
        title: String? = nil,
        message: String? = nil,
        errorType: ErrorType = .unknown,
        retry: @escaping () -> Void
    ) {
        self.title = title ?? errorType.defaultTitle
        self.message = message ?? errorType.defaultMessage
        self.errorType = errorType
        self.retry = retry
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.xl) {
            // 3D Error illustration with gradient
            ZStack {
                // Pulsing background
                Circle()
                    .fill(errorType.color.opacity(V2Depth.bgSubtle))
                    .frame(width: 100, height: 100)
                    .blur(radius: 10)

                // Shadow
                Circle()
                    .fill(errorType.color.opacity(0.2))
                    .frame(width: 90, height: 90)
                    .offset(y: 4)

                // Main circle
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                errorType.color.opacity(V2Depth.stateHover),
                                errorType.color.opacity(V2Depth.bgSubtle)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 45
                        )
                    )
                    .frame(width: 80, height: 80)

                // Icon with 3D effect
                ZStack {
                    Image(systemName: errorType.icon)
                        .font(WernickeTypography.size34Medium)
                        .foregroundStyle(errorType.color.opacity(V2Depth.stateDisabled))
                        .offset(x: 2, y: 2)

                    Image(systemName: errorType.icon)
                        .font(WernickeTypography.size34Medium)
                        .foregroundStyle(
                            LinearGradient(
                                colors: [
                                    errorType.color,
                                    errorType.color.opacity(0.7)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                }
            }

            VStack(spacing: ParietalSpacing.sm + 2) {
                Text(title)
                    .font(WernickeTypography.size17)
                    .foregroundStyle(V4Color.textPrimary)

                Text(message)
                    .font(WernickeTypography.size13)
                    .foregroundStyle(V4Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            // Retry button
            Button {
                retry()
            } label: {
                HStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: "arrow.clockwise.circle.fill")
                        .font(WernickeTypography.size16)
                    Text("Retry")
                        .font(WernickeTypography.body14Medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, ParietalSpacing.xl)
                .padding(.vertical, ParietalSpacing.md)
                .background(errorType.color)
                .cornerRadius(V1Theme.cornerMedium)
            }
            .buttonStyle(.plain)
        }
        .padding(40)
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Placeholder Views

struct PlaceholderViews {
    static func noThreads(onNewChat: @escaping () -> Void = {}) -> some View {
        EmptyChatState(onNewChat: onNewChat)
    }

    static func noMessages() -> some View {
        ListEmptyState(
            title: "No Messages",
            message: "Be the first to send a message",
            icon: "message"
        )
    }

    static func noFiles() -> some View {
        ListEmptyState(
            title: "No Files",
            message: "Upload files to get started",
            icon: "doc"
        )
    }

    static func noNotifications() -> some View {
        ListEmptyState(
            title: "All Caught Up",
            message: "You have no new notifications",
            icon: "bell"
        )
    }

    static func noSearchResults(query: String, onRetry: @escaping () -> Void = {}) -> some View {
        SearchEmptyState(query: query, onRetrySearch: onRetry)
    }

    static func networkError(onRetry: @escaping () -> Void = {}) -> some View {
        ErrorEmptyState(errorType: .network, retry: onRetry)
    }

    static func serverError(onRetry: @escaping () -> Void = {}) -> some View {
        ErrorEmptyState(errorType: .server, retry: onRetry)
    }
}

// MARK: - Empty Chat State (Enhanced with "New Chat" button)

struct EmptyChatState: View {
    let onNewChat: () -> Void

    init(onNewChat: @escaping () -> Void = {}) {
        self.onNewChat = onNewChat
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.xl + 4) {
            Spacer()

            // 3D Chat bubble illustration
            ZStack {
                // Background glow
                Circle()
                    .fill(V4Color.accent.opacity(V2Depth.bgSubtle))
                    .frame(width: 110, height: 110)
                    .blur(radius: 15)

                // Shadow
                Circle()
                    .fill(V4Color.border.opacity(0.2))
                    .frame(width: 95, height: 95)
                    .offset(y: 5)

                // Main gradient circle
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [
                                V4Color.accent.opacity(V2Depth.stateHover),
                                V4Color.accent.opacity(V2Depth.bgSubtle)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 85, height: 85)

                // Chat bubbles with 3D effect
                ZStack {
                    // Shadow bubbles
                    HStack(spacing: -8) {
                        RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                            .fill(V4Color.textSecondary.opacity(V2Depth.stateHover))
                            .frame(width: 28, height: 20)
                            .offset(x: 2, y: 2)

                        RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                            .fill(V4Color.textSecondary.opacity(V2Depth.stateHover))
                            .frame(width: 28, height: 20)
                            .offset(x: 12, y: -4)
                            .rotationEffect(.degrees(-10))
                    }

                    // Main bubbles
                    HStack(spacing: -8) {
                        RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        V4Color.textSecondary.opacity(0.8),
                                        V4Color.textSecondary.opacity(V2Depth.stateDisabled)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 28, height: 20)

                        RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        V4Color.accent.opacity(0.9),
                                        V4Color.accent.opacity(V1Theme.opacityTextSecondary)
                                    ],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .frame(width: 28, height: 20)
                            .offset(x: 10, y: -6)
                            .rotationEffect(.degrees(-10))
                    }
                }
            }

            VStack(spacing: ParietalSpacing.sm + 2) {
                Text("Start a Conversation")
                    .font(WernickeTypography.h4Semibold)
                    .foregroundStyle(V4Color.textPrimary)

                Text("Begin chatting with Trinity AI. Ask questions, get help,\nor just have a conversation.")
                    .font(WernickeTypography.size13)
                    .foregroundStyle(V4Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
            }

            // "New Chat" button
            Button {
                onNewChat()
            } label: {
                HStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: "plus.circle.fill")
                        .font(WernickeTypography.size16)
                    Text("New Chat")
                        .font(WernickeTypography.body14Medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, ParietalSpacing.xl)
                .padding(.vertical, ParietalSpacing.md)
                .background(V4Color.accent)
                .cornerRadius(V1Theme.cornerMedium)
            }
            .buttonStyle(.plain)

            // Quick suggestions
            VStack(spacing: ParietalSpacing.sm) {
                Text("Try asking:")
                    .font(WernickeTypography.miniMedium)
                    .foregroundStyle(V4Color.textSecondary)

                FlowLayout(spacing: ParietalSpacing.sm) {
                    suggestionChip("Help me write code")
                    suggestionChip("Explain a concept")
                    suggestionChip("Solve a problem")
                }
            }

            Spacer()
        }
        .padding(24)
    }

    private func suggestionChip(_ text: String) -> some View {
        Text(text)
            .font(WernickeTypography.size12)
            .foregroundStyle(V4Color.textSecondary)
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.xs + 2)
            .background(V4Color.border.opacity(V2Depth.stateDisabled))
            .cornerRadius(V1Theme.cornerSmall)
    }
}

// MARK: - Loading Skeleton (Shimmer Effect)

struct LoadingSkeleton: View {
    @State private var isAnimating = false
    let style: SkeletonStyle

    enum SkeletonStyle {
        case list(rows: Int)
        case card
        case message
        case text(lines: Int)
        case custom(height: CGFloat, width: CGFloat)

        var contentHeight: CGFloat {
            switch self {
            case .list(let rows): return CGFloat(rows) * 60 + 40
            case .card: return 180
            case .message: return 80
            case .text(let lines): return CGFloat(lines) * 20 + 20
            case .custom(let h, let w): return h
            }
        }
    }

    init(style: SkeletonStyle) {
        self.style = style
    }

    var body: some View {
        Group {
            switch style {
            case .list(let rows):
                listSkeleton(rows: rows)
            case .card:
                cardSkeleton()
            case .message:
                messageSkeleton()
            case .text(let lines):
                textSkeleton(lines: lines)
            case .custom(let height, let width):
                customSkeleton(height: height, width: width)
            }
        }
        .onAppear {
            withAnimation(
                Animation.linear(duration: 1.5)
                    .repeatForever(autoreverses: false)
            ) {
                isAnimating = true
            }
        }
    }

    private func listSkeleton(rows: Int) -> some View {
        VStack(spacing: ParietalSpacing.md) {
            ForEach(0..<rows, id: \.self) { _ in
                HStack(spacing: ParietalSpacing.md) {
                    Circle()
                        .fill(shimmerGradient)
                        .frame(width: 40, height: 40)

                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Rectangle()
                            .fill(shimmerGradient)
                            .frame(height: 12)
                            .frame(maxWidth: 150)

                        Rectangle()
                            .fill(shimmerGradient)
                            .frame(height: 10)
                            .frame(maxWidth: 200)
                    }
                }
                .padding(.horizontal, ParietalSpacing.lg)
                .padding(.vertical, ParietalSpacing.sm)
                .background(V4Color.surface)
                .cornerRadius(V1Theme.cornerMedium)
            }
        }
        .padding(ParietalSpacing.lg)
    }

    private func cardSkeleton() -> some View {
        VStack(spacing: ParietalSpacing.lg) {
            // Header skeleton
            HStack {
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(width: 50, height: 50)
                    .cornerRadius(V1Theme.cornerSmall)

                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Rectangle()
                        .fill(shimmerGradient)
                        .frame(height: 14)
                        .frame(maxWidth: 120)

                    Rectangle()
                        .fill(shimmerGradient)
                        .frame(height: 10)
                        .frame(maxWidth: 80)
                }

                Spacer()
            }

            // Content skeleton
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 10)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 10)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 10)
                    .frame(maxWidth: 200)
            }
        }
        .padding(20)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
    }

    private func messageSkeleton() -> some View {
        HStack(alignment: .top, spacing: ParietalSpacing.md) {
            Circle()
                .fill(shimmerGradient)
                .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)

            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 12)
                    .frame(maxWidth: 80)

                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 10)
                    .frame(maxWidth: 250)

                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 10)
                    .frame(maxWidth: 200)
            }

            Spacer()
        }
        .padding(ParietalSpacing.lg)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
    }

    private func textSkeleton(lines: Int) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            ForEach(0..<lines, id: \.self) { index in
                Rectangle()
                    .fill(shimmerGradient)
                    .frame(height: 10)
                    .frame(maxWidth: index == lines - 1 ? 150 : .infinity)
            }
        }
        .padding(ParietalSpacing.lg)
    }

    private func customSkeleton(height: CGFloat, width: CGFloat) -> some View {
        Rectangle()
            .fill(shimmerGradient)
            .frame(height: height)
            .frame(maxWidth: width)
            .cornerRadius(V1Theme.cornerSmall)
    }

    private var shimmerGradient: LinearGradient {
        let animationOffset = isAnimating ? 1.0 : -0.5

        return LinearGradient(
            colors: [
                V4Color.border.opacity(V2Depth.stateHover),
                V4Color.border.opacity(V1Theme.opacityTextSecondary),
                V4Color.border.opacity(V2Depth.stateHover)
            ],
            startPoint: UnitPoint(x: animationOffset - 0.5, y: 0.5),
            endPoint: UnitPoint(x: animationOffset + 0.5, y: 0.5)
        )
    }
}

// MARK: - First Run Onboarding State

struct FirstRunOnboardingState: View {
    let onGetStarted: () -> Void

    init(onGetStarted: @escaping () -> Void = {}) {
        self.onGetStarted = onGetStarted
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            // Welcome illustration with 3D Trinity logo effect
            ZStack {
                // Outer glow
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                V4Color.accent.opacity(V2Depth.bgSidebarHover),
                                V4Color.accent.opacity(0.02)
                            ],
                            center: .center,
                            startRadius: 0,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .blur(radius: 20)

                // Geometric Trinity symbol (triangle)
                ZStack {
                    // Shadow layer
                    Triangle()
                        .fill(V4Color.border.opacity(V1Theme.opacityTextTertiary))
                        .frame(width: 100, height: 87)
                        .offset(y: 6)

                    // Main triangle with gradient
                    Triangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    V4Color.accent.opacity(0.8),
                                    V4Color.purple.opacity(V1Theme.opacityTextSecondary)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                        .frame(width: 100, height: 87)

                    // Inner triangle overlay for depth
                    Triangle()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    .white.opacity(V2Depth.stateHover),
                                    .white.opacity(V2Depth.bgSubtle)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 2
                        )
                        .frame(width: 90, height: 78)
                }

                // Orbiting particles
                ForEach(0..<3) { index in
                    Circle()
                        .fill(V4Color.accent.opacity(V1Theme.opacityTextSecondary))
                        .frame(width: 6, height: 6)
                        .offset(
                            x: cos(Double(index) * .pi * 2 / 3) * 55,
                            y: sin(Double(index) * .pi * 2 / 3) * 55
                        )
                }
            }

            VStack(spacing: ParietalSpacing.md) {
                Text("Welcome to Trinity")
                    .font(WernickeTypography.h3Bold)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                V4Color.accent,
                                V4Color.purple
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )

                Text("Your autonomous AI assistant powered by\nternary computing. Fast, efficient, intelligent.")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textSecondary)
                    .multilineTextAlignment(.center)
            }

            // Feature highlights
            HStack(spacing: ParietalSpacing.xl) {
                featureItem(icon: "bolt.fill", title: "Fast", subtitle: "Ternary compute")
                featureItem(icon: "brain.head.profile", title: "Smart", subtitle: "AI powered")
                featureItem(icon: "shield.checkered", title: "Safe", subtitle: "Local first")
            }

            // Get Started button
            Button {
                onGetStarted()
            } label: {
                HStack(spacing: ParietalSpacing.sm + 2) {
                    Image(systemName: "star.fill")
                        .font(WernickeTypography.size16)
                    Text("Get Started")
                        .font(WernickeTypography.bodyEmphasized)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, ParietalSpacing.xl + ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.md + 2)
                .background(
                    LinearGradient(
                        colors: [
                            V4Color.accent,
                            V4Color.purple
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(V1Theme.cornerLarge)
                .shadow(color: V4Color.accent.opacity(V1Theme.opacityTextTertiary), radius: V1Theme.shadowMediumRadius, y: 4)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(32)
        .frame(maxWidth: .infinity)
    }

    private func featureItem(icon: String, title: String, subtitle: String) -> some View {
        VStack(spacing: ParietalSpacing.sm - 2) {
            ZStack {
                Circle()
                    .fill(V4Color.border.opacity(V2Depth.stateHover))
                    .frame(width: ParietalSpacing.avatarMedium - 4, height: ParietalSpacing.avatarMedium - 4)

                Image(systemName: icon)
                    .font(WernickeTypography.size18Medium)
                    .foregroundStyle(V4Color.accent)
            }

            Text(title)
                .font(WernickeTypography.size11Semibold)
                .foregroundStyle(V4Color.textPrimary)

            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)
        }
    }
}

// Triangle shape for Trinity logo
struct Triangle: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height

        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}

// MARK: - Preview

struct DetailedEmptyStates_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // 1. Empty Chat State
            EmptyChatState()
                .frame(width: 400, height: 500)
                .background(V4Color.background)

            Divider()

            // 2. Search Empty State
            SearchEmptyState(query: "quantum physics") {}
                .frame(width: 400, height: 400)
                .background(V4Color.background)

            Divider()

            // 3. Error States
            HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                ErrorEmptyState(errorType: .network) {}
                    .frame(width: 280, height: 350)
                ErrorEmptyState(errorType: .server) {}
                    .frame(width: 280, height: 350)
                ErrorEmptyState(errorType: .timeout) {}
                    .frame(width: 280, height: 350)
            }
            .background(V4Color.background)

            Divider()

            // 4. Loading Skeletons
            VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                LoadingSkeleton(style: .list(rows: 3))
                LoadingSkeleton(style: .card)
                LoadingSkeleton(style: .message)
            }
            .frame(width: ParietalSpacing.xl * 16)
            .padding()
            .background(V4Color.background)

            Divider()

            // 5. First Run Onboarding
            FirstRunOnboardingState()
                .frame(width: 500, height: 600)
                .background(V4Color.background)
        }
        .previewLayout(.sizeThatFits)
    }
}
