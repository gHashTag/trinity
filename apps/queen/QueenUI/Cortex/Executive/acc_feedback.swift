//
// Anterior Cingulate Cortex — Error Monitoring
// Loading/error feedback components
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - ACC Feedback States

/// ACC — Anterior Cingulate Cortex
///
/// The anterior cingulate cortex monitors errors and detects conflict.
/// This file provides loading and error feedback components.
///
/// Components:
/// - Loading states (spinner, skeleton, progress)
/// - Error states (message, retry, recovery)
/// - Empty states (placeholder, illustration)
/// - Success states (confirmation, completion)
public enum ACCFeedback {}

// MARK: - Loading View

extension ACCFeedback {

    /// Loading indicator with optional message
    public struct LoadingView: View {
        let message: String?
        let size: Size

        public enum Size {
            case small
            case medium
            case large

            var scale: CGFloat {
                switch self {
                case .small: return 0.7
                case .medium: return 1.0
                case .large: return 1.3
                }
            }
        }

        public init(message: String? = nil, size: Size = .medium) {
            self.message = message
            self.size = size
        }

        public var body: some View {
            VStack(spacing: ParietalSpacing.sm) {
                ProgressView()
                    .scaleEffect(size.scale)

                if let message = message {
                    Text(message)
                        .font(WernickeTypography.body)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Error View

extension ACCFeedback {

    /// Error display with retry action
    public struct ErrorView: View {
        let title: String
        let message: String?
        let systemImage: String?
        let retry: (() -> Void)?

        public init(
            title: String,
            message: String? = nil,
            systemImage: String? = "exclamationmark.triangle.fill",
            retry: (() -> Void)? = nil
        ) {
            self.title = title
            self.message = message
            self.systemImage = systemImage
            self.retry = retry
        }

        public var body: some View {
            VStack(spacing: ParietalSpacing.md) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(WernickeTypography.display)
                        .foregroundStyle(V4Color.error)
                }

                Text(title)
                    .font(WernickeTypography.h4)
                    .foregroundStyle(V4Color.textPrimary)

                if let message = message {
                    Text(message)
                        .font(WernickeTypography.body)
                        .foregroundStyle(V4Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let retry = retry {
                    Button {
                        retry()
                    } label: {
                        Text("Retry")
                            .font(WernickeTypography.body)
                            .foregroundStyle(.white)
                            .padding(.horizontal, ParietalSpacing.md)
                            .padding(.vertical, ParietalSpacing.xs)
                            .background(V4Color.accent)
                            .cornerRadius(V1Theme.cornerMedium)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Empty View

extension ACCFeedback {

    /// Empty state placeholder
    public struct EmptyView: View {
        let title: String
        let message: String?
        let systemImage: String?
        let action: EmptyAction?

        public struct EmptyAction {
            let title: String
            let handler: () -> Void

            public init(title: String, handler: @escaping () -> Void) {
                self.title = title
                self.handler = handler
            }
        }

        public init(
            title: String,
            message: String? = nil,
            systemImage: String? = "tray",
            action: EmptyAction? = nil
        ) {
            self.title = title
            self.message = message
            self.systemImage = systemImage
            self.action = action
        }

        public var body: some View {
            VStack(spacing: ParietalSpacing.md) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(WernickeTypography.display)
                        .foregroundStyle(V4Color.textTertiary)
                }

                Text(title)
                    .font(WernickeTypography.h4)
                    .foregroundStyle(V4Color.textPrimary)

                if let message = message {
                    Text(message)
                        .font(WernickeTypography.body)
                        .foregroundStyle(V4Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let action = action {
                    Button {
                        action.handler()
                    } label: {
                        Text(action.title)
                            .font(WernickeTypography.body)
                            .foregroundStyle(.white)
                            .padding(.horizontal, ParietalSpacing.md)
                            .padding(.vertical, ParietalSpacing.xs)
                            .background(V4Color.accent)
                            .cornerRadius(V1Theme.cornerMedium)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Success View

extension ACCFeedback {

    /// Success confirmation view
    public struct SuccessView: View {
        let title: String
        let message: String?
        let systemImage: String?
        let action: (() -> Void)?

        public init(
            title: String,
            message: String? = nil,
            systemImage: String? = "checkmark.circle.fill",
            action: (() -> Void)? = nil
        ) {
            self.title = title
            self.message = message
            self.systemImage = systemImage
            self.action = action
        }

        public var body: some View {
            VStack(spacing: ParietalSpacing.md) {
                if let systemImage = systemImage {
                    Image(systemName: systemImage)
                        .font(WernickeTypography.display)
                        .foregroundStyle(V4Color.success)
                }

                Text(title)
                    .font(WernickeTypography.h4)
                    .foregroundStyle(V4Color.textPrimary)

                if let message = message {
                    Text(message)
                        .font(WernickeTypography.body)
                        .foregroundStyle(V4Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                if let action = action {
                    Button {
                        action()
                    } label: {
                        Text("Continue")
                            .font(WernickeTypography.body)
                            .foregroundStyle(.white)
                            .padding(.horizontal, ParietalSpacing.md)
                            .padding(.vertical, ParietalSpacing.xs)
                            .background(V4Color.accent)
                            .cornerRadius(V1Theme.cornerMedium)
                    }
                }
            }
            .padding()
        }
    }
}

// MARK: - Progress Ring

extension ACCFeedback {

    /// Circular progress indicator
    public struct ProgressRing: View {
        @Binding var progress: Double
        let message: String?

        public init(progress: Binding<Double>, message: String? = nil) {
            self._progress = progress
            self.message = message
        }

        public var body: some View {
            VStack(spacing: ParietalSpacing.sm) {
                ZStack {
                    Circle()
                        .stroke(V4Color.border, lineWidth: 4)

                    Circle()
                        .trim(from: 0, to: progress)
                        .stroke(
                            V4Color.accent,
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(MTMotion.standardSpring, value: progress)

                    Text("\(Int(progress * 100))%")
                        .font(WernickeTypography.body)
                        .foregroundStyle(V4Color.textPrimary)
                }
                .frame(width: ParietalSpacing.largeFrame, height: ParietalSpacing.largeFrame)

                if let message = message {
                    Text(message)
                        .font(WernickeTypography.body)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
            .padding()
        }
    }
}

// MARK: - Skeleton Loader

extension ACCFeedback {

    /// Skeleton placeholder for loading content
    public struct Skeleton: View {
        let width: CGFloat?
        let height: CGFloat
        let cornerRadius: CGFloat

        public init(width: CGFloat? = nil, height: CGFloat = 16, cornerRadius: CGFloat = 4) {
            self.width = width
            self.height = height
            self.cornerRadius = cornerRadius
        }

        public var body: some View {
            Rectangle()
                .fill(V4Color.textTertiary.opacity(0.2))
                .frame(width: width, height: height)
                .cornerRadius(cornerRadius)
                .overlay(
                    LinearGradient(
                        colors: [
                            .clear,
                            .white.opacity(V2Depth.stateHover),
                            .clear
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .cornerRadius(cornerRadius)
                )
                .opacity(0.8)
        }
    }

    /// Skeleton row for text
    public struct SkeletonRow: View {
        let lines: Int

        public init(lines: Int = 3) {
            self.lines = lines
        }

        public var body: some View {
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                ForEach(0..<lines, id: \.self) { index in
                    Skeleton(
                        width: index == lines - 1 ? 0.6 : nil,
                        height: 16
                    )
                }
            }
        }
    }
}

// MARK: - Toast Banner

extension ACCFeedback {

    /// Toast notification banner
    public struct Toast: View {
        let message: String
        let type: ToastType
        let onDismiss: () -> Void

        public enum ToastType {
            case info
            case success
            case warning
            case error

            var color: Color {
                switch self {
                case .info: return V4Color.info
                case .success: return V4Color.success
                case .warning: return V4Color.warning
                case .error: return V4Color.error
                }
            }

            var icon: String {
                switch self {
                case .info: return "info.circle.fill"
                case .success: return "checkmark.circle.fill"
                case .warning: return "exclamationmark.triangle.fill"
                case .error: return "xmark.circle.fill"
                }
            }
        }

        public init(message: String, type: ToastType = .info, onDismiss: @escaping () -> Void = {}) {
            self.message = message
            self.type = type
            self.onDismiss = onDismiss
        }

        public var body: some View {
            HStack(spacing: ParietalSpacing.xs) {
                Image(systemName: type.icon)
                    .foregroundStyle(type.color)

                Text(message)
                    .font(WernickeTypography.body)
                    .foregroundStyle(V4Color.textPrimary)

                Spacer()

                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.caption2Semibold)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.xs)
            .background(V4Color.surfaceElevated)
            .overlay(
                Rectangle()
                    .fill(type.color)
                    .frame(width: ParietalSpacing.smallIndicator),
                alignment: .leading
            )
            .cornerRadius(V1Theme.cornerMedium)
            .shadow(radius: ParietalSpacing.xxxs)
        }
    }
}

// MARK: - Preview
// NOTE: Preview blocks removed for CLI build compatibility
