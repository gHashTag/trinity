// Notification Banner View — Top/Bottom Notification Banners
import SwiftUI

// MARK: - Notification Banner

struct NotificationBanner: View {
    let title: String
    let message: String?
    let style: BannerStyle
    let onDismiss: () -> Void

    enum BannerStyle {
        case info
        case success
        case warning
        case error

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .info: return Color(hex: 0x00D9FF)
            case .success: return TrinityTheme.statusOK
            case .warning: return TrinityTheme.statusWarn
            case .error: return TrinityTheme.statusError
            }
        }
    }

    @State private var isVisible = false

    init(
        title: String,
        message: String? = nil,
        style: BannerStyle = .info,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.title = title
        self.message = message
        self.style = style
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: 12) {
            // Icon
            Image(systemName: style.icon)
                .font(.system(size: 16))
                .foregroundStyle(style.color)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                if let message = message {
                    Text(message)
                        .font(.system(size: 11))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }

            Spacer()

            // Dismiss button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(style.color.opacity(0.1))
        .overlay(
            Rectangle()
                .fill(style.color)
                .frame(width: 3),
            alignment: .leading
        )
        .offset(y: isVisible ? 0 : -80)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }

    private func dismiss() {
        withAnimation {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            onDismiss()
        }
    }
}

// MARK: - Notification Manager

@MainActor
class NotificationManager: ObservableObject {
    @Published var banners: [NotificationItem] = []
    private var dismissalTimers: [UUID: Timer] = [:]

    struct NotificationItem: Identifiable {
        let id = UUID()
        let title: String
        let message: String?
        let style: NotificationBanner.BannerStyle
        let duration: TimeInterval?

        init(
            title: String,
            message: String? = nil,
            style: NotificationBanner.BannerStyle = .info,
            duration: TimeInterval? = nil
        ) {
            self.title = title
            self.message = message
            self.style = style
            self.duration = duration
        }
    }

    func show(
        title: String,
        message: String? = nil,
        style: NotificationBanner.BannerStyle = .info,
        duration: TimeInterval? = nil
    ) {
        let banner = NotificationItem(title: title, message: message, style: style, duration: duration)
        withAnimation {
            banners.append(banner)
        }

        // Auto-dismiss after duration
        let effectiveDuration = duration ?? style.defaultDuration
        let timer = Timer.scheduledTimer(withTimeInterval: effectiveDuration, repeats: false) { [weak self] _ in
            self?.dismiss(id: banner.id)
        }
        dismissalTimers[banner.id] = timer
    }

    func dismiss(_ id: UUID) {
        dismissalTimers[id]?.invalidate()
        dismissalTimers.removeValue(forKey: id)

        withAnimation {
            banners.removeAll { $0.id == id }
        }
    }

    private func dismiss(id: UUID) {
        Task { @MainActor in
            dismissalTimers[id]?.invalidate()
            dismissalTimers.removeValue(forKey: id)

            withAnimation {
                banners.removeAll { $0.id == id }
            }
        }
    }

    func dismissAll() {
        for timer in dismissalTimers.values {
            timer.invalidate()
        }
        dismissalTimers.removeAll()

        withAnimation {
            banners.removeAll()
        }
    }

    func info(_ title: String, message: String? = nil) {
        show(title: title, message: message, style: .info)
    }

    func success(_ title: String, message: String? = nil) {
        show(title: title, message: message, style: .success)
    }

    func warning(_ title: String, message: String? = nil) {
        show(title: title, message: message, style: .warning)
    }

    func error(_ title: String, message: String? = nil) {
        show(title: title, message: message, style: .error)
    }
}

extension NotificationBanner.BannerStyle {
    var defaultDuration: TimeInterval {
        switch self {
        case .info: return 4.0
        case .success: return 3.0
        case .warning: return 5.0
        case .error: return 6.0
        }
    }
}

// MARK: - Notification Stack

struct NotificationStack: View {
    @ObservedObject var manager: NotificationManager
    let position: VerticalAlignment

    enum VerticalAlignment {
        case top
        case bottom

        var alignment: Alignment {
            switch self {
            case .top: return .top
            case .bottom: return .bottom
            }
        }
    }

    init(manager: NotificationManager, position: VerticalAlignment = .top) {
        self.manager = manager
        self.position = position
    }

    var body: some View {
        VStack(spacing: 8) {
            ForEach(manager.banners) { banner in
                NotificationBanner(
                    title: banner.title,
                    message: banner.message,
                    style: banner.style
                ) {
                    manager.dismiss(banner.id)
                }
                .transition(.move(edge: .top).combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
    }
}

// MARK: - In-App Notification

struct InAppNotification: View {
    let content: AnyView
    private let isVisibleBinding: Binding<Bool>
    let onDismiss: () -> Void

    init<Content: View>(
        isVisible: Binding<Bool>,
        @ViewBuilder content: () -> Content,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.content = AnyView(content())
        self.isVisibleBinding = isVisible
        self.onDismiss = onDismiss
    }

    private var isVisible: Bool {
        get { isVisibleBinding.wrappedValue }
        nonmutating set { isVisibleBinding.wrappedValue = newValue }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.001)
                .onTapGesture {
                    dismiss()
                }

            content
                .padding(16)
                .background(TrinityTheme.bgCard)
                .cornerRadius(TrinityTheme.cornerMedium)
                .shadow(color: .black.opacity(0.2), radius: 12)
                .overlay(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                        .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                )
        }
        .opacity(isVisible ? 1 : 0)
        .scaleEffect(isVisible ? 1 : 0.95)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isVisible)
    }

    private func dismiss() {
        withAnimation {
            isVisible = false
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            onDismiss()
        }
    }
}

// MARK: - Toast-Style Notification

struct ToastNotification: View {
    let message: String
    let style: ToastStyle
    @Binding var isPresented: Bool

    enum ToastStyle {
        case info, success, warning, error

        var icon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }

        var color: Color {
            switch self {
            case .info: return Color(hex: 0x00D9FF)
            case .success: return TrinityTheme.statusOK
            case .warning: return TrinityTheme.statusWarn
            case .error: return TrinityTheme.statusError
            }
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: style.icon)
                .font(.system(size: 16))
                .foregroundStyle(style.color)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textPrimary)

            Spacer()

            Button {
                isPresented = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11))
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(style.color.opacity(0.1))
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(style.color.opacity(0.5), lineWidth: 1)
        )
        .scaleEffect(isPresented ? 1 : 0.8)
        .opacity(isPresented ? 1 : 0)
        .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isPresented)
    }
}

// MARK: - Preview

struct NotificationBanner_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Notification stack
            NotificationStack(
                manager: NotificationManager(),
                position: .top
            )
            .frame(width: 400, height: 200)
            .padding()
            .background(TrinityTheme.bgWindow)
            .onAppear {
                let manager = NotificationManager()
                manager.info("Info notification", message: "This is an informational message")
                manager.success("Success!", message: "Operation completed")
                manager.warning("Warning", message: "Please review this")
                manager.error("Error", message: "Something went wrong")
            }

            // Toast notification
            ToastNotification(
                message: "Changes saved successfully",
                style: .success,
                isPresented: .constant(true)
            )
            .frame(width: 300)
            .padding()
            .background(TrinityTheme.bgWindow)
        }
    }
}
