import SwiftUI
import AppKit

// MARK: - Message Action Types

/// Individual action available on a chat message
enum MessageAction: String, CaseIterable, Identifiable {
    case copy = "Copy"
    case copyCode = "Copy Code"
    case regenerate = "Regenerate"
    case edit = "Edit"
    case delete = "Delete"
    case bookmark = "Bookmark"
    case share = "Share"
    case translate = "Translate"
    case cite = "Cite"
    case quoteReply = "Quote Reply"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .copy: return "doc.on.doc"
        case .copyCode: return "chevron.left.forwardslash.chevron.right"
        case .regenerate: return "arrow.clockwise"
        case .edit: return "pencil"
        case .delete: return "trash"
        case .bookmark: return "bookmark"
        case .share: return "square.and.arrow.up"
        case .translate: return "globe"
        case .cite: return "link"
        case .quoteReply: return "quote.bubble"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .copy: return "Copy message to clipboard"
        case .copyCode: return "Copy code blocks from message"
        case .regenerate: return "Regenerate this response"
        case .edit: return "Edit this message"
        case .delete: return "Delete this message"
        case .bookmark: return "Bookmark this message"
        case .share: return "Share this message"
        case .translate: return "Translate this message"
        case .cite: return "Copy with citations"
        case .quoteReply: return "Reply with quote"
        }
    }

    var color: Color {
        switch self {
        case .copy, .copyCode, .share, .translate, .cite: return TrinityTheme.accent
        case .regenerate, .edit, .quoteReply: return TrinityTheme.purple
        case .delete: return TrinityTheme.statusError
        case .bookmark: return TrinityTheme.statusWarn
        }
    }
}

// MARK: - Message Actions Panel

/// A panel displaying available actions for a chat message.
/// Provides a row of icon buttons that trigger actions like copy, share, bookmark, etc.
struct MessageActionsPanel: View {
    let message: ChatMessage
    let onAction: (MessageAction) -> Void
    @Environment(\.colorScheme) private var colorScheme
    @State private var isHovering = false

    /// Actions that should be available for this specific message
    private var availableActions: [MessageAction] {
        var actions: [MessageAction] = [.copy, .bookmark, .quoteReply, .share]

        // Add copy code if message contains code blocks
        if message.text.contains("```") {
            actions.append(.copyCode)
        }

        // Add translate option
        actions.append(.translate)

        // Add cite if message has citations
        if let citations = message.citations, !citations.isEmpty {
            actions.append(.cite)
        }

        // Add regenerate for assistant messages
        if message.role == .assistant {
            actions.append(.regenerate)
        }

        // Add edit for user messages
        if message.role == .user {
            actions.append(.edit)
        }

        // Delete is always available
        actions.append(.delete)

        return actions
    }

    // MARK: - Body

    var body: some View {
        HStack(spacing: 6) {
            ForEach(availableActions) { action in
                ActionButton(action: action) {
                    performAction(action)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(panelBackground)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))
        .opacity(isHovering ? 1 : 0.7)
        .animation(TrinityTheme.quickSpring(), value: isHovering)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Message actions")
    }

    // MARK: - Background

    private var panelBackground: some View {
        TrinityTheme.bgCardBorder.opacity(0.3)
    }

    // MARK: - Action Handler

    private func performAction(_ action: MessageAction) {
        onAction(action)

        // Play sound feedback
        switch action {
        case .copy, .copyCode, .cite:
            SoundCueManager.shared.playCopy()
        case .delete:
            SoundCueManager.shared.playError()
        default:
            break
        }

        // Haptic feedback
        NSHapticFeedbackManager.defaultPerformer.perform(
            .alignment,
            performanceTime: .default
        )
    }

    // MARK: - Action Button

    private struct ActionButton: View {
        let action: MessageAction
        let onTap: () -> Void

        @State private var isPressed = false

        var body: some View {
            Button(action: {
                withAnimation(.easeOut(duration: 0.1)) {
                    isPressed = true
                }
                onTap()
                Task {
                    try? await Task.sleep(nanoseconds: 100_000_000)
                    await MainActor.run {
                        isPressed = false
                    }
                }
            }) {
                Image(systemName: action.icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(buttonColor)
                    .frame(width: 28, height: 28)
                    .background(buttonBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .scaleEffect(isPressed ? 0.9 : 1.0)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(action.accessibilityLabel)
            .help(action.accessibilityLabel)
        }

        private var buttonColor: Color {
            action.color.opacity(isPressed ? 1.0 : 0.8)
        }

        private var buttonBackground: some View {
            TrinityTheme.bgCardBorder.opacity(0.2)
        }
    }
}

// MARK: - Compact Actions Row

/// A minimal horizontal row of actions for inline message display.
/// Shows only the most common actions: copy, bookmark, share.
struct MessageActionsCompact: View {
    let message: ChatMessage
    let onAction: (MessageAction) -> Void

    var body: some View {
        HStack(spacing: 4) {
            CompactActionButton(icon: "doc.on.doc", color: TrinityTheme.accent) {
                onAction(.copy)
                SoundCueManager.shared.playCopy()
            }
            .accessibilityLabel("Copy message")

            CompactActionButton(icon: message.isBookmarked == true ? "bookmark.fill" : "bookmark",
                                color: TrinityTheme.statusWarn) {
                onAction(.bookmark)
            }
            .accessibilityLabel(message.isBookmarked == true ? "Unbookmark" : "Bookmark")

            CompactActionButton(icon: "square.and.arrow.up", color: TrinityTheme.accent) {
                onAction(.share)
            }
            .accessibilityLabel("Share message")
        }
    }
}

private struct CompactActionButton: View {
    let icon: String
    let color: Color
    let onTap: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onTap) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundColor(color.opacity(isHovering ? 1.0 : 0.6))
                .frame(width: 24, height: 24)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            withAnimation(TrinityTheme.quickSpring()) {
                isHovering = hovering
            }
        }
    }
}

// MARK: - Floating Actions Menu

/// A floating menu that appears on right-click or long-press.
/// Shows all available actions in a popover menu.
struct MessageActionsMenu: View {
    let message: ChatMessage
    let onAction: (MessageAction) -> Void
    @Binding var isPresented: Bool

    var body: some View {
        Menu {
            ForEach(availableActions) { action in
                Button {
                    performAction(action)
                    isPresented = false
                } label: {
                    Label(action.rawValue, systemImage: action.icon)
                }
                .accessibilityLabel(action.accessibilityLabel)
            }
        } label: {
            EmptyView()
        }
        .menuStyle(.borderlessButton)
        .onAppear {
            // Auto-dismiss after 10 seconds if no interaction
            Task {
                try? await Task.sleep(nanoseconds: 10_000_000_000)
                if isPresented {
                    isPresented = false
                }
            }
        }
    }

    private var availableActions: [MessageAction] {
        var actions: [MessageAction] = [.copy, .bookmark, .quoteReply, .share]

        if message.text.contains("```") {
            actions.append(.copyCode)
        }

        actions.append(.translate)

        if let citations = message.citations, !citations.isEmpty {
            actions.append(.cite)
        }

        if message.role == .assistant {
            actions.append(.regenerate)
        }

        if message.role == .user {
            actions.append(.edit)
        }

        actions.append(.delete)

        return actions
    }

    private func performAction(_ action: MessageAction) {
        onAction(action)

        switch action {
        case .copy, .copyCode, .cite:
            SoundCueManager.shared.playCopy()
        case .delete:
            SoundCueManager.shared.playError()
        default:
            break
        }
    }
}

// MARK: - Context Menu Extension

extension View {
    /// Adds a context menu with message actions when right-clicked.
    func messageContextMenu(
        for message: ChatMessage,
        onAction: @escaping (MessageAction) -> Void
    ) -> some View {
        self.contextMenu {
            MessageActionButtons(message: message, onAction: onAction)
        }
    }
}

/// Helper view for context menu items
private struct MessageActionButtons: View {
    let message: ChatMessage
    let onAction: (MessageAction) -> Void

    var body: some View {
        Group {
            Button {
                onAction(.copy)
                SoundCueManager.shared.playCopy()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
            }

            if message.text.contains("```") {
                Button {
                    onAction(.copyCode)
                    SoundCueManager.shared.playCopy()
                } label: {
                    Label("Copy Code", systemImage: "chevron.left.forwardslash.chevron.right")
                }
            }

            Divider()

            Button {
                onAction(.bookmark)
            } label: {
                Label(
                    message.isBookmarked == true ? "Remove Bookmark" : "Bookmark",
                    systemImage: message.isBookmarked == true ? "bookmark.slash" : "bookmark"
                )
            }

            Button {
                onAction(.share)
            } label: {
                Label("Share", systemImage: "square.and.arrow.up")
            }

            Button {
                onAction(.quoteReply)
            } label: {
                Label("Quote Reply", systemImage: "quote.bubble")
            }

            Divider()

            if message.role == .assistant {
                Button {
                    onAction(.regenerate)
                } label: {
                    Label("Regenerate", systemImage: "arrow.clockwise")
                }
            }

            if message.role == .user {
                Button {
                    onAction(.edit)
                } label: {
                    Label("Edit", systemImage: "pencil")
                }
            }

            Divider()

            Button(role: .destructive) {
                onAction(.delete)
                SoundCueManager.shared.playError()
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }
}

// MARK: - Preview Provider

#if DEBUG
struct MessageActionsPanel_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Full panel
            MessageActionsPanel(
                message: sampleMessage,
                onAction: { _ in }
            )
            .frame(width: 400)

            // Compact row
            MessageActionsCompact(
                message: sampleMessage,
                onAction: { _ in }
            )

            // With bookmarked message
            MessageActionsCompact(
                message: bookmarkedMessage,
                onAction: { _ in }
            )
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }

    private static var sampleMessage: ChatMessage {
        var msg = ChatMessage(role: .assistant, text: "```swift\nlet x = 1\n```")
        msg.modelID = "claude-sonnet"
        msg.isBookmarked = false
        msg.citations = [Citation(url: "https://example.com", title: "Example", domain: "example.com")]
        return msg
    }

    private static var bookmarkedMessage: ChatMessage {
        var msg = ChatMessage(role: .assistant, text: "Bookmarked content")
        msg.isBookmarked = true
        return msg
    }
}
#endif
