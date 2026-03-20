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
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            Spacer()

            // Animated icon
            animatedIcon

            Text(title)
                .font(WernickeTypography.h4Semibold)
                .foregroundStyle(V4Color.textPrimary)

            Text(message)
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textSecondary)
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
            .font(WernickeTypography.display)
            .foregroundStyle(V4Color.textSecondary.opacity(V2Depth.stateDisabled))
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
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            Spacer()

            ProgressView()
                .scaleEffect(1.5)
                .tint(V4Color.accent)

            Text(message)
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textSecondary)

            if let progress = progress {
                Text("\(Int(progress * 100))%")
                    .font(WernickeTypography.caption2MediumMono)
                    .foregroundStyle(V4Color.textSecondary.opacity(0.7))
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
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            Spacer()

            Image(systemName: "exclamationmark.triangle.fill")
                .font(WernickeTypography.display)
                .foregroundStyle(V4Color.error)

            Text("Something went wrong")
                .font(WernickeTypography.h4Semibold)
                .foregroundStyle(V4Color.textPrimary)

            Text(error.localizedDescription)
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textSecondary)
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
                        .foregroundStyle(V4Color.textSecondary)
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
            HStack(spacing: ParietalSpacing.lg) {
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
        .background(V4Color.background)
    }

    private func onboardingPage(_ page: OnboardingPage) -> some View {
        VStack(spacing: ParietalSpacing.xl) {
            Spacer()

            Image(systemName: page.icon)
                .font(WernickeTypography.size56)
                .foregroundStyle(V4Color.accent)
                .symbolRenderingMode(.hierarchical)

            Text(page.title)
                .font(WernickeTypography.h2Semibold)
                .foregroundStyle(V4Color.textPrimary)

            Text(page.message)
                .font(WernickeTypography.size16)
                .foregroundStyle(V4Color.textSecondary)
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
        VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
            Text("Discover Features")
                .font(.headline)
                .foregroundStyle(V4Color.textPrimary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 150))], spacing: ParietalSpacing.md) {
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
            VStack(spacing: ParietalSpacing.md) {
                Image(systemName: feature.icon)
                    .font(WernickeTypography.size24)
                    .foregroundStyle(selectedFeature?.id == feature.id ? V4Color.accent : V4Color.textSecondary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(selectedFeature?.id == feature.id ? V4Color.accent.opacity(V2Depth.bgSidebarHover) : Color.clear)
                    )

                Text(feature.title)
                    .font(WernickeTypography.captionMedium)
                    .foregroundStyle(V4Color.textPrimary)

                Text(feature.description)
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(V4Color.surface)
            .cornerRadius(V1Theme.cornerSmall)
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
        VStack(spacing: ParietalSpacing.xl) {
            Spacer()

            // Success icon with animation
            ZStack {
                Circle()
                    .fill(.green.opacity(V2Depth.bgSidebarHover))
                    .frame(width: 80, height: 80)

                Image(systemName: "checkmark.circle.fill")
                    .font(WernickeTypography.display)
                    .foregroundStyle(.green)
                    .scaleEffect(showConfetti ? 1 : 0.5)
            }
            .onAppear {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.6)) {
                    showConfetti = true
                }
            }

            Text(title)
                .font(WernickeTypography.size20.weight(.bold))
                .foregroundStyle(V4Color.textPrimary)

            Text(message)
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textSecondary)
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
        VStack(spacing: ParietalSpacing.xl) {
            Spacer()

            // Progress ring
            ZStack {
                ProgressRing(progress: progress, size: 60, color: V4Color.accent)

                Text("\(currentStep + 1)")
                    .font(WernickeTypography.h4Semibold)
                    .foregroundStyle(V4Color.textPrimary)
            }

            Text(title)
                .font(WernickeTypography.h4Semibold)
                .foregroundStyle(V4Color.textPrimary)

            // Step list
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: ParietalSpacing.sm) {
                        Circle()
                            .fill(index <= currentStep ? V4Color.accent : V4Color.border)
                            .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)

                        Text(step)
                            .font(WernickeTypography.size12)
                            .foregroundStyle(index <= currentStep ? V4Color.textPrimary : V4Color.textSecondary)

                        if index < currentStep {
                            Spacer()
                                .frame(height: 1)
                                .background(V4Color.accent.opacity(V2Depth.stateHover))
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
        .background(V4Color.background)
    }
}
