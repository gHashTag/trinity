// MARK: - Toast Notification System
// Complete toast notification system with queue management, animations,
// swipe-to-dismiss, progress indicators, and sound effects.

import SwiftUI
import AppKit

// MARK: - Toast Style

enum ToastStyle: String, CaseIterable, Identifiable {
    case info
    case success
    case warning
    case error

    var id: String { rawValue }

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
        case .info: return V4Color.info
        case .success: return V4Color.success
        case .warning: return V4Color.warning
        case .error: return V4Color.error
        }
    }

    var soundName: String {
        switch self {
        case .info: return "Glass"
        case .success: return "Hero"
        case .warning: return "Morse"
        case .error: return "Basso"
        }
    }
}

// MARK: - Toast Position

enum ToastPosition {
    case top
    case topLeading
    case topTrailing
    case bottom
    case bottomLeading
    case bottomTrailing

    var alignment: Alignment {
        switch self {
        case .top: return .top
        case .topLeading: return .topLeading
        case .topTrailing: return .topTrailing
        case .bottom: return .bottom
        case .bottomLeading: return .bottomLeading
        case .bottomTrailing: return .bottomTrailing
        }
    }
}

// MARK: - Toast Item

struct ToastItem: Identifiable, Equatable {
    let id = UUID()
    let style: ToastStyle
    let title: String
    let message: String?
    let timeout: TimeInterval
    let createdAt: Date = Date()

    init(style: ToastStyle, title: String, message: String? = nil, timeout: TimeInterval = 5.0) {
        self.style = style
        self.title = title
        self.message = message
        self.timeout = timeout
    }

    static func == (lhs: ToastItem, rhs: ToastItem) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Toast Queue Manager

@MainActor
class ToastQueue: ObservableObject {
    @Published private(set) var toasts: [ToastItem] = []
    private var timers: [UUID: Timer] = [:]
    private let maxVisibleToasts = 3
    private var pausedProgress: [UUID: Double] = [:]

    var position: ToastPosition = .topTrailing

    func present(_ toast: ToastItem) {
        // Remove oldest if at limit
        if toasts.count >= maxVisibleToasts {
            let oldest = toasts.first
            if let oldestId = oldest?.id {
                dismiss(oldestId)
            }
        }

        withAnimation(MTMotion.standardSpring) {
            toasts.append(toast)
        }

        // Play appropriate sound based on style
        playSoundForStyle(toast.style)

        // Schedule auto-dismiss
        scheduleDismiss(for: toast)
    }

    func dismiss(_ id: UUID) {
        withAnimation(MTMotion.slow) {
            toasts.removeAll { $0.id == id }
        }
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
        pausedProgress.removeValue(forKey: id)
    }

    func dismissAll() {
        withAnimation(MTMotion.slow) {
            toasts.removeAll()
        }
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()
        pausedProgress.removeAll()
    }

    func pauseTimer(for id: UUID, currentProgress: Double) {
        pausedProgress[id] = currentProgress
        timers[id]?.invalidate()
        timers.removeValue(forKey: id)
    }

    private func playSoundForStyle(_ style: ToastStyle) {
        switch style {
        case .info, .success:
            SoundCueManager.shared.playSend()
        case .warning:
            SoundCueManager.shared.playCopy()  // Morse sound for warnings
        case .error:
            SoundCueManager.shared.playError()
        }
    }

    func resumeTimer(for id: UUID) {
        guard let toast = toasts.first(where: { $0.id == id }),
              let progress = pausedProgress[id] else { return }

        let remainingTime = toast.timeout * (1 - progress)
        scheduleDismiss(for: toast, delay: remainingTime)
        pausedProgress.removeValue(forKey: id)
    }

    private func scheduleDismiss(for toast: ToastItem, delay: TimeInterval? = nil) {
        let timeInterval = delay ?? toast.timeout
        let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.dismiss(toast.id)
            }
        }
        timers[toast.id] = timer
    }

    // Convenience methods
    func info(_ title: String, message: String? = nil, timeout: TimeInterval = 5.0) {
        present(ToastItem(style: .info, title: title, message: message, timeout: timeout))
    }

    func success(_ title: String, message: String? = nil, timeout: TimeInterval = 5.0) {
        present(ToastItem(style: .success, title: title, message: message, timeout: timeout))
    }

    func warning(_ title: String, message: String? = nil, timeout: TimeInterval = 5.0) {
        present(ToastItem(style: .warning, title: title, message: message, timeout: timeout))
    }

    func error(_ title: String, message: String? = nil, timeout: TimeInterval = 5.0) {
        present(ToastItem(style: .error, title: title, message: message, timeout: timeout))
    }
}

// MARK: - Single Toast View

struct ToastView: View {
    let item: ToastItem
    let onHoverChange: (Bool) -> Void
    let onDismiss: () -> Void

    @State private var isHovered = false
    @State private var dragOffset: CGFloat = 0
    @State private var isVisible = false
    @State private var progress: Double = 0

    private let toastWidth: CGFloat = 320
    private let dragThreshold: CGFloat = 100

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            // Icon
            iconView

            // Content
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text(item.title)
                    .font(WernickeTypography.smallSemibold)
                    .foregroundStyle(V4Color.textPrimary)
                    .lineLimit(2)

                if let message = item.message {
                    Text(message)
                        .font(WernickeTypography.size11)
                        .foregroundStyle(V4Color.textSecondary)
                        .lineLimit(3)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Dismiss button
            Button {
                SoundCueManager.shared.playCopy()
                onDismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(WernickeTypography.miniSemibold)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(width: ParietalSpacing.icon + 4, height: ParietalSpacing.icon + 4)
                    .background(Circle().fill(V4Color.textSecondary.opacity(V2Depth.bgSubtle)))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss notification")
        }
        .padding(ParietalSpacing.md)
        .frame(width: toastWidth)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(V4Color.surface)
                .shadow(color: .black.opacity(V2Depth.stateHover), radius: 12, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(item.style.color.opacity(V2Depth.stateDisabled), lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            if !isHovered {
                progressBar
            }
        }
        .offset(x: dragOffset)
        .scaleEffect(isVisible ? 1 : 0.8)
        .opacity(isVisible ? 1 : 0)
        .onAppear {
            withAnimation(MTMotion.standardSpring) {
                isVisible = true
            }
            // Start progress animation
            withAnimation(.linear(duration: item.timeout)) {
                progress = 1
            }
        }
        .onHover { hovering in
            isHovered = hovering
            onHoverChange(hovering)
        }
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width < 0 {
                        dragOffset = value.translation.width
                    }
                }
                .onEnded { value in
                    if value.translation.width < -dragThreshold {
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragOffset = -toastWidth
                            isVisible = false
                        }
                        SoundCueManager.shared.playError()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            onDismiss()
                        }
                    } else {
                        withAnimation(MTMotion.quickSpring) {
                            dragOffset = 0
                        }
                    }
                }
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(item.style.rawValue): \(item.title)\(item.message.map { ". \($0)" } ?? "")")
    }

    private var iconView: some View {
        ZStack {
            Circle()
                .fill(item.style.color.opacity(V2Depth.bgSidebarHover))
                .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)

            Image(systemName: item.style.icon)
                .font(WernickeTypography.body14Medium)
                .foregroundStyle(item.style.color)
        }
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            HStack(spacing: 0) {
                ForEach(0..<40) { i in
                    Rectangle()
                        .fill(item.style.color)
                        .frame(width: geometry.size.width / 40)
                        .opacity(segmentOpacity(index: i, total: 40))
                }
            }
        }
        .frame(height: ParietalSpacing.xxxs)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
        .frame(maxWidth: .infinity, alignment: .leading)
        .offset(y: 1.5)
    }

    // Segment opacity based on progress
    private func segmentOpacity(index: Int, total: Int) -> Double {
        let segmentProgress = Double(index) / Double(total)
        return progress > segmentProgress ? 0.3 : 1.0
    }
}

// MARK: - Toast Container View

struct ToastNotificationView: View {
    @StateObject private var queue = ToastQueue()
    @FocusState private var focusFocused: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: queue.position.alignment) {
                // Invisible focus trap for keyboard shortcuts
                Button("") {
                    dismissAll()
                }
                .keyboardShortcut(.escape)
                .focusable()
                .focused($focusFocused)
                .opacity(0)
                .frame(width: 0, height: 0)

                // Toast stack
                VStack(spacing: ParietalSpacing.sm) {
                    ForEach(queue.toasts.reversed()) { toast in
                        ToastView(
                            item: toast,
                            onHoverChange: { isHovering in
                                if isHovering {
                                    queue.pauseTimer(for: toast.id, currentProgress: 0.5)
                                } else {
                                    queue.resumeTimer(for: toast.id)
                                }
                            },
                            onDismiss: {
                                queue.dismiss(toast.id)
                            }
                        )
                        .transition(.asymmetric(
                            insertion: .scale(scale: 0.8).combined(with: .opacity),
                            removal: .scale(scale: 0.98).combined(with: .opacity)
                        ))
                    }
                }
                .padding(ParietalSpacing.lg)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: queue.position.alignment)
            }
        }
        .environment(\.toastQueue, queue)
    }

    private func dismissAll() {
        guard !queue.toasts.isEmpty else { return }
        SoundCueManager.shared.playSend()
        queue.dismissAll()
    }
}

// MARK: - Toast Environment Key

private struct ToastQueueKey: EnvironmentKey {
    static let defaultValue: ToastQueue? = nil
}

extension EnvironmentValues {
    var toastQueue: ToastQueue? {
        get { self[ToastQueueKey.self] }
        set { self[ToastQueueKey.self] = newValue }
    }
}

// MARK: - Toast View Modifier

struct ToastModifier: ViewModifier {
    let position: ToastPosition

    func body(content: Content) -> some View {
        ZStack {
            content

            ToastNotificationView()
                .allowsHitTesting(false)
        }
    }
}

extension View {
    /// Adds toast notification support to this view
    func toast(position: ToastPosition = .topTrailing) -> some View {
        modifier(ToastModifier(position: position))
    }
}

// MARK: - Global Toast Presenter (for non-SwiftUI contexts)

@MainActor
class ToastPresenter {
    static let shared = ToastPresenter()
    private weak var currentQueue: ToastQueue?

    func attach(_ queue: ToastQueue) {
        currentQueue = queue
    }

    func show(
        style: ToastStyle,
        title: String,
        message: String? = nil,
        timeout: TimeInterval = 5.0
    ) {
        let toast = ToastItem(style: style, title: title, message: message, timeout: timeout)
        currentQueue?.present(toast)
    }

    func showInfo(_ title: String, message: String? = nil, timeout: TimeInterval = 5.0) {
        show(style: .info, title: title, message: message, timeout: timeout)
    }

    func showSuccess(_ title: String, message: String? = nil, timeout: TimeInterval = 5.0) {
        show(style: .success, title: title, message: message, timeout: timeout)
    }

    func showWarning(_ title: String, message: String? = nil, timeout: TimeInterval = 5.0) {
        show(style: .warning, title: title, message: message, timeout: timeout)
    }

    func showError(_ title: String, message: String? = nil, timeout: TimeInterval = 5.0) {
        show(style: .error, title: title, message: message, timeout: timeout)
    }

    func dismissAll() {
        currentQueue?.dismissAll()
    }
}

// MARK: - SoundCueManager Helper for Toast Sounds
// Note: SoundCueManager already has private play() method in ChatClient.swift
// We use existing playSend(), playError(), playCopy() methods for toast feedback

// MARK: - Preview

struct ToastNotificationView_Previews: PreviewProvider {
    static var previews: some View {
        ToastDemoView()
    }
}

private struct ToastDemoView: View {
    @StateObject private var queue = ToastQueue()

    var body: some View {
        ZStack {
            V4Color.background.ignoresSafeArea()

            VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                Text("Toast Notification Demo")
                    .font(WernickeTypography.h3Bold)
                    .foregroundStyle(V4Color.textPrimary)

                Text("Demonstrates all toast styles with animations")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textSecondary)

                VStack(spacing: ParietalSpacing.md) {
                    toastButton("Info", style: .info) {
                        queue.info("Information", message: "This is an informational toast notification with timeout progress.")
                    }

                    toastButton("Success", style: .success) {
                        queue.success("Success!", message: "Operation completed successfully.")
                    }

                    toastButton("Warning", style: .warning) {
                        queue.warning("Warning", message: "Please review this important message.")
                    }

                    toastButton("Error", style: .error) {
                        queue.error("Error occurred", message: "Something went wrong. Please try again.")
                    }
                }

                Divider()
                    .background(V4Color.border)

                VStack(spacing: ParietalSpacing.sm) {
                    Text("Keyboard Shortcuts")
                        .font(WernickeTypography.caption2Semibold)
                        .foregroundStyle(V4Color.textSecondary)

                    HStack(spacing: ParietalSpacing.lg) {
                        shortcutKey("Esc", action: "Dismiss all")

                        shortcutKey("Swipe", action: "Swipe left to dismiss")
                    }
                }

                Spacer()
            }
            .padding(ParietalSpacing.xl)
            .frame(maxWidth: 500)
        }
        .overlay(alignment: .topTrailing) {
            toastStack
        }
        .onAppear {
            // Auto-attach presenter
            ToastPresenter.shared.attach(queue)

            // Show welcome toast
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                queue.info("Welcome!", message: "Toast notifications are now active. Press Esc to dismiss all.")
            }
        }
    }

    private var toastStack: some View {
        VStack(spacing: ParietalSpacing.sm) {
            ForEach(queue.toasts.reversed()) { toast in
                ToastView(
                    item: toast,
                    onHoverChange: { isHovering in
                        if isHovering {
                            queue.pauseTimer(for: toast.id, currentProgress: 0.5)
                        } else {
                            queue.resumeTimer(for: toast.id)
                        }
                    },
                    onDismiss: {
                        queue.dismiss(toast.id)
                    }
                )
                .transition(.asymmetric(
                    insertion: .scale(scale: 0.8).combined(with: .opacity),
                    removal: .scale(scale: 0.98).combined(with: .opacity)
                ))
            }
        }
        .padding(ParietalSpacing.lg)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topTrailing)
        .background(
            GeometryReader { _ in
                Color.clear
                    .onKeyPress(.escape) {
                        guard !queue.toasts.isEmpty else { return .ignored }
                        queue.dismissAll()
                        return .handled
                    }
            }
        )
    }

    private func toastButton(_ title: String, style: ToastStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ParietalSpacing.sm) {
                Image(systemName: style.icon)
                    .foregroundStyle(style.color)

                Text(title)
                    .font(WernickeTypography.smallMedium)
                    .foregroundStyle(V4Color.textPrimary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ParietalSpacing.sm + 2)
            .background(style.color.opacity(V2Depth.bgSidebarHover))
            .cornerRadius(V1Theme.cornerSmall)
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .stroke(style.color.opacity(V2Depth.stateHover), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func shortcutKey(_ key: String, action: String) -> some View {
        HStack(spacing: ParietalSpacing.sm) {
            Text(key)
                .font(WernickeTypography.caption2Semibold)
                .foregroundStyle(V4Color.textPrimary)
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xs)
                .background(V4Color.border)
                .cornerRadius(V1Theme.cornerTiny)

            Text(action)
                .font(WernickeTypography.size11)
                .foregroundStyle(V4Color.textSecondary)
        }
    }
}
