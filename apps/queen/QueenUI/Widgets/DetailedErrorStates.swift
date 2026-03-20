// Error State View — Error Display and Retry
import SwiftUI

// MARK: - Error State View

struct DetailedErrorState: View {
    let error: ErrorType
    let message: String?
    let retryTitle: String
    let onRetry: () -> Void

    enum ErrorType {
        case network
        case server
        case notFound
        case permission
        case custom(String, String)

        var icon: String {
            switch self {
            case .network: return "wifi.slash"
            case .server: return "server.fail"
            case .notFound: return "questionmark.folder"
            case .permission: return "lock.fill"
            case .custom(let icon, _): return icon
            }
        }

        var title: String {
            switch self {
            case .network: return "Connection Error"
            case .server: return "Server Error"
            case .notFound: return "Not Found"
            case .permission: return "Permission Denied"
            case .custom(_, let title): return title
            }
        }

        var color: Color {
            switch self {
            case .network, .server: return V4Color.warning
            case .notFound: return V4Color.textSecondary
            case .permission: return V4Color.error
            case .custom: return V4Color.error
            }
        }
    }

    init(
        error: ErrorType,
        message: String? = nil,
        retryTitle: String = "Try Again",
        onRetry: @escaping () -> Void
    ) {
        self.error = error
        self.message = message
        self.retryTitle = retryTitle
        self.onRetry = onRetry
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(error.color.opacity(V2Depth.bgSidebarHover))
                    .frame(width: ParietalSpacing.badgeFrame, height: ParietalSpacing.badgeFrame)

                Image(systemName: error.icon)
                    .font(WernickeTypography.size28)
                    .foregroundStyle(error.color)
            }

            // Title
            Text(error.title)
                .font(WernickeTypography.h4Semibold)
                .foregroundStyle(V4Color.textPrimary)

            // Message
            if let message = message {
                Text(message)
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            // Retry button
            Button {
                onRetry()
            } label: {
                HStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: "arrow.clockwise")
                        .font(WernickeTypography.smallSemibold)

                    Text(retryTitle)
                        .font(WernickeTypography.body14Medium)
                }
                .foregroundStyle(.white)
                .padding(.horizontal, ParietalSpacing.md + ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm + 2)
                .background(error.color)
                .cornerRadius(V1Theme.cornerBase)
            }
            .buttonStyle(.plain)

            Spacer()
        }
    }
}

// MARK: - Compact Error State

struct CompactErrorState: View {
    let error: String
    let onRetry: () -> Void

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(WernickeTypography.size20)
                .foregroundStyle(V4Color.warning)

            VStack(alignment: .leading, spacing: 2) {
                Text("Error")
                    .font(WernickeTypography.smallMedium)
                    .foregroundStyle(V4Color.textPrimary)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }

            Spacer()

            Button {
                onRetry()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(ParietalSpacing.md)
        .background(V4Color.warning.opacity(V2Depth.bgSubtle))
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.warning.opacity(V2Depth.stateHover), lineWidth: 1)
        )
    }
}

// MARK: - Inline Error

struct InlineError: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            Image(systemName: "xmark.circle.fill")
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.error)

            Text(message)
                .font(.caption)
                .foregroundStyle(V4Color.textPrimary)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(WernickeTypography.size10)
                    .foregroundStyle(V4Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ParietalSpacing.sm + 2)
        .padding(.vertical, ParietalSpacing.sm)
        .background(V4Color.error.opacity(V2Depth.bgSubtle))
        .cornerRadius(V1Theme.cornerSmall)
    }
}

// MARK: - Error Alert

struct ErrorAlert: View {
    let title: String
    let message: String
    let dismissTitle: String
    let isPresented: Binding<Bool>

    var body: some View {
        ZStack {
            Color.black.opacity(V1Theme.opacityTextTertiary)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented.wrappedValue = false
                }

            VStack(spacing: ParietalSpacing.lg) {
                // Icon
                ZStack {
                    Circle()
                        .fill(V4Color.error.opacity(V2Depth.bgSidebarHover))
                        .frame(width: ParietalSpacing.mediumFrame, height: ParietalSpacing.mediumFrame)

                    Image(systemName: "xmark.octagon.fill")
                        .font(WernickeTypography.h2)
                        .foregroundStyle(V4Color.error)
                }

                // Title and message
                VStack(spacing: ParietalSpacing.sm) {
                    Text(title)
                        .font(WernickeTypography.body16Medium)
                        .foregroundStyle(V4Color.textPrimary)

                    Text(message)
                        .font(WernickeTypography.size13)
                        .foregroundStyle(V4Color.textSecondary)
                        .multilineTextAlignment(.center)
                }

                // Dismiss button
                Button {
                    isPresented.wrappedValue = false
                } label: {
                    Text(dismissTitle)
                        .font(WernickeTypography.body14Medium)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, ParietalSpacing.sm + 2)
                        .background(V4Color.error)
                        .cornerRadius(V1Theme.cornerBase)
                }
                .buttonStyle(.plain)
            }
            .padding(ParietalSpacing.xl)
            .background(V4Color.surface)
            .cornerRadius(V1Theme.cornerLarge)
            .shadow(color: .black.opacity(0.2), radius: 20)
            .padding(.horizontal, ParietalSpacing.xxl)
        }
    }
}

// MARK: - Error Banner (top of screen)

struct ErrorBannerTop: View {
    let message: String
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: ParietalSpacing.sm + 2) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.error)

            Text(message)
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textPrimary)

            Spacer()

            Button {
                withAnimation {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(WernickeTypography.size10)
                    .foregroundStyle(V4Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm + 2)
        .background(
            V4Color.error.opacity(V2Depth.bgSubtle)
        )
        .overlay(
            Rectangle()
                .fill(V4Color.error)
                .frame(height: 2),
            alignment: .top
        )
        .offset(y: isVisible ? 0 : -60)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

// MARK: - Network Error View

struct NetworkErrorView: View {
    let onRetry: () -> Void

    var body: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            ZStack {
                Circle()
                    .fill(V4Color.warning.opacity(V2Depth.bgSidebarHover))
                    .frame(width: ParietalSpacing.xLargeFrame, height: ParietalSpacing.xLargeFrame)

                Image(systemName: "wifi.exclamationmark")
                    .font(WernickeTypography.size32)
                    .foregroundStyle(V4Color.warning)
            }

            Text("Connection Lost")
                .font(WernickeTypography.h4Semibold)
                .foregroundStyle(V4Color.textPrimary)

            Text("Please check your internet connection and try again.")
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                onRetry()
            } label: {
                HStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: "arrow.clockwise")
                        .font(WernickeTypography.smallSemibold)
                    Text("Retry")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, ParietalSpacing.md + ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm + 2)
                .background(V4Color.warning)
                .cornerRadius(V1Theme.cornerBase)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Preview

struct DetailedErrorStates_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DetailedErrorState(
                error: .network,
                message: "Unable to connect to the server. Please check your internet connection.",
                onRetry: {}
            )
            .frame(width: ParietalSpacing.sheetWidth, height: 350)
            .padding()
            .background(V4Color.background)

            CompactErrorState(
                error: "Failed to load data",
                onRetry: {}
            )
            .frame(width: ParietalSpacing.extraWidePanel)
            .padding()
            .background(V4Color.background)

            NetworkErrorView(onRetry: {})
                .frame(width: ParietalSpacing.extraWidePanel, height: 350)
                .padding()
                .background(V4Color.background)
        }
    }
}
