import SwiftUI

// MARK: - Message Quick Actions

struct MessageQuickActions: View {
    let message: ChatMessage
    let onAction: (QuickAction) -> Void

    @State private var showActions = false
    @State private var hoverPosition: CGPoint = .zero

    var body: some View {
        messageContent
            .overlay(actionBar, alignment: .topTrailing)
            .onHover { hovering in
                withAnimation(.easeInOut(duration: 0.2)) {
                    showActions = hovering
                }
            }
    }

    private var messageContent: some View {
        Text(message.text)
            .padding(12)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerMedium)
    }

    private var actionBar: some View {
        Group {
            if showActions {
                HStack(spacing: 4) {
                    ForEach(QuickAction.allCases, id: \.self) { action in
                        actionButton(action)
                    }
                }
                .padding(.trailing, 8)
                .padding(.top, 8)
                .transition(.scale.combined(with: .opacity))
            }
        }
    }

    private func actionButton(_ action: QuickAction) -> some View {
        Button {
            onAction(action)
        } label: {
            Image(systemName: action.icon)
                .font(.system(size: 11))
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(width: 24, height: 24)
                .background(
                    Circle()
                        .fill(TrinityTheme.bgCard)
                )
                .overlay(
                    Circle()
                        .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .help(action.label)
    }
}

// MARK: - Quick Action Enum

enum QuickAction: String, CaseIterable {
    case copy
    case quote
    case forward
    case bookmark
    case translate
    case share

    var icon: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .quote: return "quote.bubble"
        case .forward: return "arrow.turn.up.right"
        case .bookmark: return "bookmark"
        case .translate: return "globe"
        case .share: return "square.and.arrow.up"
        }
    }

    var label: String {
        switch self {
        case .copy: return "Copy"
        case .quote: return "Quote"
        case .forward: return "Forward"
        case .bookmark: return "Bookmark"
        case .translate: return "Translate"
        case .share: return "Share"
        }
    }
}

// MARK: - Quick Action Bar (Floating)

struct QuickActionBar: View {
    let message: ChatMessage
    let onAction: (QuickAction) -> Void
    let isVisible: Bool

    var body: some View {
        if isVisible {
            HStack(spacing: 8) {
                ForEach(QuickAction.allCases, id: \.self) { action in
                    quickActionButton(action)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .fill(TrinityTheme.bgCard)
                    .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
            )
            .transition(.scale.combined(with: .opacity))
        }
    }

    private func quickActionButton(_ action: QuickAction) -> some View {
        Button {
            onAction(action)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 12))
                Text(action.label)
                    .font(.caption)
            }
            .foregroundStyle(TrinityTheme.textPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                    .fill(TrinityTheme.bgWindow)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Context Menu Actions

struct MessageContextMenu: View {
    let message: ChatMessage
    let onAction: (QuickAction) -> Void

    var body: some View {
        Menu {
            ForEach(QuickAction.allCases, id: \.self) { action in
                Button {
                    onAction(action)
                } label: {
                    Label(action.label, systemImage: action.icon)
                }
            }

            Divider()

            Menu {
                Button("Light") {}
                Button("Dark") {}
                Button("OLED") {}
            } label: {
                Label("Appearance", systemImage: "paintbrush.fill")
            }
        } label: {
            Image(systemName: "ellipsis.circle")
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .menuStyle(.borderlessButton)
    }
}

// MARK: - Action Confirmation Dialog

struct ActionConfirmationDialog: View {
    let action: QuickAction
    let message: ChatMessage
    let onConfirm: () -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            // Action icon
            Image(systemName: action.icon)
                .font(.system(size: 32))
                .foregroundStyle(TrinityTheme.accent)
                .frame(width: 60, height: 60)
                .background(
                    Circle()
                        .fill(TrinityTheme.accent.opacity(0.2))
                )

            // Title and description
            VStack(spacing: 8) {
                Text("Confirm \(action.label)")
                    .font(.headline)
                    .foregroundStyle(TrinityTheme.textPrimary)

                Text(actionDescription)
                    .font(.body)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .multilineTextAlignment(.center)
            }

            // Message preview
            Text(message.text)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
                .padding()
                .frame(maxWidth: .infinity)
                .background(TrinityTheme.bgCard.opacity(0.5))
                .cornerRadius(TrinityTheme.cornerSmall)

            // Buttons
            HStack(spacing: 12) {
                Button("Cancel", action: onCancel)
                    .keyboardShortcut(.cancelAction)
                    .controlSize(.large)

                Button(action.label, action: onConfirm)
                    .keyboardShortcut(.return)
                    .controlSize(.large)
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 320)
        .background(TrinityTheme.bgWindow)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerLarge)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
        .cornerRadius(TrinityTheme.cornerLarge)
        .shadow(color: .black.opacity(0.3), radius: 30)
    }

    private var actionDescription: String {
        switch action {
        case .copy:
            return "Copy this message to clipboard"
        case .quote:
            return "Quote this message in your reply"
        case .forward:
            return "Forward to another conversation"
        case .bookmark:
            return "Add to your bookmarks"
        case .translate:
            return "Translate to another language"
        case .share:
            return "Share via system share sheet"
        }
    }
}

// MARK: - Action Result Toast

struct ActionResultToast: View {
    let action: QuickAction
    let isSuccess: Bool
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isSuccess ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(isSuccess ? .green : TrinityTheme.statusError)

            Text(actionDescription)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textPrimary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            Capsule()
                .stroke(isSuccess ? .green.opacity(0.5) : TrinityTheme.statusError.opacity(0.5), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.2), radius: 10, y: 4)
        .opacity(isVisible ? 1 : 0)
        .offset(y: isVisible ? 0 : -20)
        .onAppear {
            withAnimation(.spring()) {
                isVisible = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                onDismiss()
            }
        }
    }

    private var actionDescription: String {
        isSuccess ? "\(action.label) completed" : "\(action.label) failed"
    }
}

// MARK: - Keyboard Shortcut Handler

struct MessageShortcutHandler: View {
    let message: ChatMessage
    let onAction: (QuickAction) -> Void

    var body: some View {
        EmptyView()
            .onReceive(NotificationCenter.default.publisher(for: .messageShortcut)) { notification in
                guard let messageID = notification.userInfo?["messageID"] as? UUID,
                      messageID == message.id,
                      let actionRaw = notification.userInfo?["action"] as? String,
                      let action = QuickAction(rawValue: actionRaw) else {
                    return
                }
                onAction(action)
            }
    }
}

extension Notification.Name {
    static let messageShortcut = Notification.Name("messageShortcut")
}

// MARK: - Preview

struct MessageQuickActions_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            MessageQuickActions(message: sampleMessage) { _ in }
                .frame(width: 300)

            QuickActionBar(
                message: sampleMessage,
                onAction: { _ in },
                isVisible: true
            )

            ActionConfirmationDialog(
                action: .copy,
                message: sampleMessage,
                onConfirm: {},
                onCancel: {}
            )

            ActionResultToast(
                action: .copy,
                isSuccess: true,
                onDismiss: {}
            )
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}

private let sampleMessage = ChatMessage(
    role: .assistant,
    text: "This is a sample message for previewing the quick actions."
)
