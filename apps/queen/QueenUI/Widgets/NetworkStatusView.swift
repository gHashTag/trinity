import SwiftUI

// MARK: - Network Status Indicator

struct NetworkStatusIndicator: View {
    @StateObject private var monitor = ConnectionStatusMonitor()
    @State private var showDetails = false

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            statusIndicator

            if showDetails {
                statusDetails
            }
        }
        .onHover { hovering in
            withAnimation {
                showDetails = hovering
            }
        }
    }

    private var statusIndicator: some View {
        Circle()
            .fill(monitor.isConnected ? .green : V4Color.error)
            .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)
            .overlay(
                Circle()
                    .stroke(monitor.isConnected ? Color.white : Color.clear, lineWidth: 1)
            )
    }

    private var statusDetails: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Text(monitor.isConnected ? "Connected" : "Offline")
                .font(.caption2)
                .foregroundStyle(V4Color.textPrimary)

            if monitor.isConnected {
                Text(monitor.providerName)
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(
            SwiftUI.Capsule()
                .fill(V4Color.surface)
        )
    }
}

// MARK: - Network Monitor

@MainActor
class ConnectionStatusMonitor: ObservableObject {
    @Published var isConnected: Bool = true
    @Published var providerName: String = "Anthropic"
    @Published var latency: TimeInterval = 0
    @Published var requestCount: Int = 0

    private var startTime: Date?

    func recordRequestStart() {
        startTime = Date()
        requestCount += 1
    }

    func recordRequestEnd() {
        if let start = startTime {
            latency = Date().timeIntervalSince(start)
        }
    }

    func simulateDisconnect() {
        isConnected = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.isConnected = true
        }
    }
}

// MARK: - Connection Quality Badge

struct ConnectionQualityBadge: View {
    let latency: TimeInterval

    var quality: Quality {
        switch latency {
        case 0..<0.5: return .excellent
        case 0.5..<1.0: return .good
        case 1.0..<2.0: return .fair
        default: return .poor
        }
    }

    enum Quality {
        case excellent, good, fair, poor

        var color: Color {
            switch self {
            case .excellent: return .green
            case .good: return .blue
            case .fair: return .orange
            case .poor: return V4Color.error
            }
        }

        var icon: String {
            switch self {
            case .excellent: return "bolt.fill"
            case .good: return "bolt.fill"
            case .fair: return "bolt"
            case .poor: return "bolt.slash.fill"
            }
        }

        var label: String {
            switch self {
            case .excellent: return "Excellent"
            case .good: return "Good"
            case .fair: return "Fair"
            case .poor: return "Poor"
            }
        }
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: quality.icon)
                .font(.caption2)
            Text("\(Int(latency * 1000))ms")
                .font(.caption2)
        }
        .foregroundStyle(quality.color)
        .padding(.horizontal, ParietalSpacing.xs + 2)
        .padding(.vertical, 3)
        .background(
            SwiftUI.Capsule()
                .fill(quality.color.opacity(V2Depth.bgSidebarHover))
        )
    }
}

// MARK: - Network Error Toast

struct NetworkErrorToast: View {
    let error: NetworkError
    let onRetry: () -> Void
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(WernickeTypography.size16)
                .foregroundStyle(V4Color.error)

            VStack(alignment: .leading, spacing: 2) {
                Text(error.title)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(V4Color.textPrimary)

                Text(error.message)
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }

            Spacer()

            Button("Retry") {
                onRetry()
                onDismiss()
            }
            .font(.caption)
            .buttonStyle(.bordered)
        }
        .padding(ParietalSpacing.md)
        .background(V4Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                .stroke(V4Color.error.opacity(V2Depth.stateDisabled), lineWidth: 1)
        )
        .cornerRadius(V1Theme.cornerSmall)
        .shadow(color: .black.opacity(0.2), radius: 10)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(.spring()) {
                isVisible = true
            }
        }
    }
}

// MARK: - Network Error Model

struct NetworkError {
    let title: String
    let message: String
    let isRetryable: Bool

    static let timeout = NetworkError(
        title: "Request Timeout",
        message: "The request took too long. Please try again.",
        isRetryable: true
    )

    static let connectionLost = NetworkError(
        title: "Connection Lost",
        message: "Please check your internet connection.",
        isRetryable: true
    )

    static let rateLimit = NetworkError(
        title: "Rate Limit Exceeded",
        message: "Too many requests. Please wait a moment.",
        isRetryable: false
    )
}

// MARK: - Retry Animation View

struct RetryAnimationView: View {
    @State private var isAnimating = false
    @State private var retryCount: Int = 0
    let maxRetries: Int

    var body: some View {
        VStack(spacing: ParietalSpacing.md) {
            ZStack {
                Circle()
                    .stroke(V4Color.accent.opacity(V2Depth.stateHover), lineWidth: 4)
                    .frame(width: 60, height: 60)

                Circle()
                    .trim(from: 0, to: CGFloat(retryCount) / CGFloat(maxRetries))
                    .stroke(V4Color.accent, lineWidth: 4)
                    .frame(width: 60, height: 60)
                    .rotationEffect(.degrees(isAnimating ? 360 : 0))
            }

            Text("Retrying... (\(retryCount)/\(maxRetries))")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
        }
        .onAppear {
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Token Usage Indicator

struct TokenUsageIndicator: View {
    let used: Int
    let limit: Int

    private var percentage: Double {
        guard limit > 0 else { return 0 }
        return min(Double(used) / Double(limit), 1.0)
    }

    private var color: Color {
        switch percentage {
        case 0..<0.5: return V4Color.accent
        case 0.5..<0.8: return .orange
        default: return V4Color.error
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack {
                Text("Tokens")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)

                Spacer()

                Text("\(used)/\(limit)")
                    .font(.caption2)
                    .foregroundStyle(percentage > 0.8 ? V4Color.error : V4Color.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(V4Color.border)
                        .frame(height: ParietalSpacing.xs)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(color)
                        .frame(width: geometry.size.width * percentage, height: 4)
                }
            }
            .frame(height: ParietalSpacing.xs)
        }
    }
}

// MARK: - Streaming Progress Indicator

struct StreamingProgressIndicator: View {
    @State private var progress: CGFloat = 0
    @State private var isAnimating = true

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            ZStack {
                Circle()
                    .stroke(V4Color.textSecondary.opacity(0.2), lineWidth: 2)
                    .frame(width: ParietalSpacing.icon, height: ParietalSpacing.icon)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(V4Color.accent, lineWidth: 2)
                    .frame(width: ParietalSpacing.icon, height: ParietalSpacing.icon)
                    .rotationEffect(.degrees(-90))
            }

            Text("Streaming...")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
        }
        .onAppear {
            withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                progress = 1
            }
        }
    }
}

// MARK: - Model Provider Switcher

struct ModelProviderSwitcher: View {
    @Binding var selectedProvider: ModelProvider
    let providers: [ModelProvider]

    var body: some View {
        Menu {
            ForEach(providers) { provider in
                Button {
                    selectedProvider = provider
                } label: {
                    HStack {
                        providerIcon(provider)
                        Text(provider.name)
                        if provider.id == selectedProvider.id {
                            Image(systemName: "checkmark")
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: ParietalSpacing.sm - 2) {
                providerIcon(selectedProvider)
                Text(selectedProvider.name)
                    .font(.caption)
                    .foregroundStyle(V4Color.textPrimary)
                Image(systemName: "chevron.down")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs + 2)
            .background(V4Color.surface)
            .cornerRadius(V1Theme.cornerSmall)
        }
        .menuStyle(.borderlessButton)
    }

    private func providerIcon(_ provider: ModelProvider) -> some View {
        Group {
            if provider.icon != nil {
                Image(systemName: provider.icon ?? "cpu")
                    .font(.caption)
            } else {
                Image(systemName: "cpu")
                    .font(.caption)
            }
        }
        .foregroundStyle(provider.color ?? V4Color.accent)
    }
}

// MARK: - Model Provider

struct ModelProvider: Identifiable, Equatable {
    let id: String
    let name: String
    let icon: String?
    let color: Color?
    let isAvailable: Bool

    init(id: String, name: String, icon: String? = nil, color: Color? = nil, isAvailable: Bool = true) {
        self.id = id
        self.name = name
        self.icon = icon
        self.color = color
        self.isAvailable = isAvailable
    }
}

// MARK: - Preview

struct NetworkStatusView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            NetworkStatusIndicator()

            HStack(spacing: ParietalSpacing.sm + 2) {
                ConnectionQualityBadge(latency: 0.3)
                ConnectionQualityBadge(latency: 0.8)
                ConnectionQualityBadge(latency: 1.5)
                ConnectionQualityBadge(latency: 3.0)
            }

            NetworkErrorToast(
                error: .timeout,
                onRetry: {},
                onDismiss: {}
            )

            TokenUsageIndicator(used: 75000, limit: 100000)

            StreamingProgressIndicator()
        }
        .padding()
        .background(V4Color.background)
    }
}
