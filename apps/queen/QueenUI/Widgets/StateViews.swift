import SwiftUI

// MARK: - Empty State View

struct EmptyStateView: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: () -> Void

    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: @escaping () -> Void) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            // Animated icon
            animatedIcon

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let actionTitle = actionTitle {
                Button(actionTitle) {
                    action()
                    SoundCueManager.shared.playSend()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var animatedIcon: some View {
        Image(systemName: icon)
            .font(.system(size: 48))
            .foregroundStyle(TrinityTheme.textMuted.opacity(0.5))
            .scaleEffect(1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) {
                    // Could add scale animation here
                }
            }
    }
}

// MARK: - Loading State View

struct LoadingStateView: View {
    let message: String
    let progress: Double?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(TrinityTheme.accent)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textMuted)

            if let progress = progress {
                Text("\(Int(progress * 100))%")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(TrinityTheme.textMuted.opacity(0.7))
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Error State View

struct ErrorStateView: View {
    let error: Error
    let retryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(TrinityTheme.statusError)

            Text("Something went wrong")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(error.localizedDescription)
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 300)

            if let retryAction = retryAction {
                Button("Try Again") {
                    retryAction()
                    SoundCueManager.shared.playSend()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Welcome Onboarding View

struct WelcomeOnboardingView: View {
    let onDismiss: () -> Void
    @State private var currentPage = 0

    private let pages: [OnboardingPage] = [
        OnboardingPage(
            icon: "sparkles",
            title: "Welcome to Queen",
            message: "Your intelligent coding assistant with a beautiful interface."
        ),
        OnboardingPage(
            icon: "keyboard",
            title: "Keyboard Shortcuts",
            message: "Press ⌘K for quick commands, ⌘/ to search, and Esc to focus."
        ),
        OnboardingPage(
            icon: "paintbrush.fill",
            title: "Customize Your Experience",
            message: "Adjust themes, fonts, and animation styles to your liking."
        ),
        OnboardingPage(
            icon: "heart.fill",
            title: "Ready to Start",
            message: "You're all set! Let's build something amazing."
        )
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Dismiss button
            HStack {
                Spacer()
                Button {
                    onDismiss()
                } label: {
                    Text("Skip")
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Spacer()

            // Content
            TabView(selection: $currentPage) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    onboardingPage(page)
                    .tag(index)
                }
            }

            // Navigation
            HStack(spacing: 16) {
                if currentPage > 0 {
                    Button("Back") {
                        withAnimation {
                            currentPage -= 1
                        }
                    }
                    .buttonStyle(.bordered)
                }

                if currentPage < pages.count - 1 {
                    Button("Next") {
                        withAnimation {
                            currentPage += 1
                        }
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Get Started") {
                        onDismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.bottom, 32)
        }
        .background(TrinityTheme.bgWindow)
    }

    private func onboardingPage(_ page: OnboardingPage) -> some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: page.icon)
                .font(.system(size: 64))
                .foregroundStyle(TrinityTheme.accent)
                .symbolRenderingMode(.hierarchical)

            Text(page.title)
                .font(.system(size: 28, weight: .bold))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(page.message)
                .font(.system(size: 16))
                .foregroundStyle(TrinityTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Spacer()
        }
        .padding()
    }
}

// MARK: - Onboarding Page Model

struct OnboardingPage {
    let icon: String
    let title: String
    let message: String
}

// MARK: - Feature Discovery View

struct FeatureDiscoveryView: View {
    @State private var selectedFeature: Feature?
    @State private var showTooltip = false

    private let features: [Feature] = [
        Feature(id: "threads", icon: "bubble.left.fill", title: "Threads", description: "Organize conversations into threads"),
        Feature(id: "search", icon: "magnifyingglass", title: "Search", description: "Find anything quickly"),
        Feature(id: "themes", icon: "paintbrush", title: "Themes", description: "Customize appearance"),
        Feature(id: "shortcuts", icon: "command", title: "Shortcuts", description: "Work faster with keys"),
        Feature(id: "export", icon: "square.and.arrow.up", title: "Export", description: "Share your work")
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Discover Features")
                .font(.headline)
                .foregroundStyle(TrinityTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: 12) {
                ForEach(features) { feature in
                    featureCard(feature)
                }
            }
        }
        .padding()
    }

    private func featureCard(_ feature: Feature) -> some View {
        Button {
            selectedFeature = feature
            showTooltip = true
        } label: {
            VStack(spacing: 12) {
                Image(systemName: feature.icon)
                    .font(.system(size: 24))
                    .foregroundStyle(selectedFeature?.id == feature.id ? TrinityTheme.accent : TrinityTheme.textMuted)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(selectedFeature?.id == feature.id ? TrinityTheme.accent.opacity(0.15) : Color.clear)
                    )

                Text(feature.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Text(feature.description)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerSmall)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Feature Model

struct Feature: Identifiable {
    let id: String
    let icon: String
    let title: String
    let description: String
}

// MARK: - Success State View

struct SuccessStateView: View {
    let title: String
    let message: String
    let actionTitle: String
    let action: () -> Void

    @State private var showConfetti = false

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Success icon with animation
            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                    .scaleEffect(showConfetti ? 1 : 0.5)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showConfetti = true
                }
            }

            Text(title)
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 350)

            Button(actionTitle) {
                action()
                SoundCueManager.shared.playSend()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Progress State View

struct ProgressStateView: View {
    let title: String
    let steps: [String]
    let currentStep: Int

    private var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(currentStep) / Double(steps.count)
    }

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            // Progress ring
            ZStack {
                ProgressRing(progress: progress, size: 60, color: TrinityTheme.accent)

                Text("\(currentStep + 1)")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)
            }

            Text(title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TrinityTheme.textPrimary)

            // Step list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 8) {
                        Circle()
                            .fill(index <= currentStep ? TrinityTheme.accent : TrinityTheme.bgCardBorder)
                            .frame(width: 8, height: 8)

                        Text(step)
                            .font(.system(size: 12))
                            .foregroundStyle(index <= currentStep ? TrinityTheme.textPrimary : TrinityTheme.textMuted)

                        if index < currentStep {
                            Spacer()
                                .frame(height: 1)
                                .background(TrinityTheme.accent.opacity(0.3))
                        } else {
                            Spacer()
                        }
                    }
                }
            }
            .frame(maxWidth: 250)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Preview

struct StateViews_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            EmptyStateView(
                icon: "tray",
                title: "No Messages",
                message: "Start a conversation to see messages here.",
                actionTitle: "New Thread",
                action: {}
            )
            .frame(height: 300)
            .previewDisplayName("Empty State")

            LoadingStateView(
                message: "Loading messages...",
                progress: 0.6
            )
            .frame(height: 300)
            .previewDisplayName("Loading State")

            ErrorStateView(
                error: NSError(domain: "Test", code: 1, userInfo: [NSLocalizedDescriptionKey: "Connection failed"]),
                retryAction: {}
            )
            .frame(height: 300)
            .previewDisplayName("Error State")

            WelcomeOnboardingView(onDismiss: {})
            .frame(height: 500)
            .previewDisplayName("Onboarding")

            SuccessStateView(
                title: "All Done!",
                message: "Your settings have been saved successfully.",
                actionTitle: "Continue",
                action: {}
            )
            .frame(height: 400)
            .previewDisplayName("Success State")
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
