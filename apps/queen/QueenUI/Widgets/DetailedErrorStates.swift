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
            case .network, .server: return TrinityTheme.statusWarn
            case .notFound: return TrinityTheme.textMuted
            case .permission: return TrinityTheme.statusError
            case .custom: return TrinityTheme.statusError
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
        VStack(spacing: 20) {
            Spacer()

            // Icon
            ZStack {
                Circle()
                    .fill(error.color.opacity(0.15))
                    .frame(width: 70, height: 70)

                Image(systemName: error.icon)
                    .font(.system(size: 28))
                    .foregroundStyle(error.color)
            }

            // Title
            Text(error.title)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TrinityTheme.textPrimary)

            // Message
            if let message = message {
                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            // Retry button
            Button {
                onRetry()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))

                    Text(retryTitle)
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(error.color)
                .cornerRadius(8)
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
        HStack(spacing: 12) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 20))
                .foregroundStyle(TrinityTheme.statusWarn)

            VStack(alignment: .leading, spacing: 2) {
                Text("Error")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Text(error)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            Spacer()

            Button {
                onRetry()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.accent)
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .background(TrinityTheme.statusWarn.opacity(0.1))
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(TrinityTheme.statusWarn.opacity(0.3), lineWidth: 1)
        )
    }
}

// MARK: - Inline Error

struct InlineError: View {
    let message: String
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "xmark.circle.fill")
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.statusError)

            Text(message)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textPrimary)

            Spacer()

            Button {
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(TrinityTheme.statusError.opacity(0.1))
        .cornerRadius(6)
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
            Color.black.opacity(0.4)
                .ignoresSafeArea()
                .onTapGesture {
                    isPresented.wrappedValue = false
                }

            VStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(TrinityTheme.statusError.opacity(0.15))
                        .frame(width: 50, height: 50)

                    Image(systemName: "xmark.octagon.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(TrinityTheme.statusError)
                }

                // Title and message
                VStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    Text(message)
                        .font(.system(size: 13))
                        .foregroundStyle(TrinityTheme.textMuted)
                        .multilineTextAlignment(.center)
                }

                // Dismiss button
                Button {
                    isPresented.wrappedValue = false
                } label: {
                    Text(dismissTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(TrinityTheme.statusError)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(24)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerLarge)
            .shadow(color: .black.opacity(0.2), radius: 20)
            .padding(.horizontal, 40)
        }
    }
}

// MARK: - Error Banner (top of screen)

struct ErrorBannerTop: View {
    let message: String
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.statusError)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textPrimary)

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
                    .font(.system(size: 10))
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            TrinityTheme.statusError.opacity(0.1)
        )
        .overlay(
            Rectangle()
                .fill(TrinityTheme.statusError)
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
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(TrinityTheme.statusWarn.opacity(0.15))
                    .frame(width: 80, height: 80)

                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 32))
                    .foregroundStyle(TrinityTheme.statusWarn)
            }

            Text("Connection Lost")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text("Please check your internet connection and try again.")
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            Button {
                onRetry()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Retry")
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(TrinityTheme.statusWarn)
                .cornerRadius(8)
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
            .frame(width: 400, height: 350)
            .padding()
            .background(TrinityTheme.bgWindow)

            CompactErrorState(
                error: "Failed to load data",
                onRetry: {}
            )
            .frame(width: 350)
            .padding()
            .background(TrinityTheme.bgWindow)

            NetworkErrorView(onRetry: {})
                .frame(width: 350, height: 350)
                .padding()
                .background(TrinityTheme.bgWindow)
        }
    }
}
