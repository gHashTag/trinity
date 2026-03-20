import SwiftUI

// MARK: - Thread Store for Message Replies

@MainActor
final class MessageThreadStore: ObservableObject {
    @Published var threads: [MessageThread] = []

    /// Get or create a thread for a parent message
    func thread(for parentID: UUID) -> MessageThread {
        if let existing = threads.first(where: { $0.parentID == parentID }) {
            return existing
        }
        let new = MessageThread(parentID: parentID)
        threads.append(new)
        return new
    }

    /// Add a reply to a thread
    func addReply(_ reply: ThreadReply, to parentID: UUID) {
        if let index = threads.firstIndex(where: { $0.parentID == parentID }) {
            threads[index].replies.append(reply)
            threads[index].unreadCount += 1
        }
    }

    /// Mark all replies in a thread as read
    func markAsRead(parentID: UUID) {
        if let index = threads.firstIndex(where: { $0.parentID == parentID }) {
            threads[index].unreadCount = 0
        }
    }

    /// Get reply count for a parent message
    func replyCount(for parentID: UUID) -> Int {
        threads.first(where: { $0.parentID == parentID })?.replies.count ?? 0
    }

    /// Get unread count for a parent message
    func unreadCount(for parentID: UUID) -> Int {
        threads.first(where: { $0.parentID == parentID })?.unreadCount ?? 0
    }
}

// MARK: - Thread Data Models

struct MessageThread: Identifiable {
    let id = UUID()
    let parentID: UUID
    var replies: [ThreadReply] = []
    var unreadCount: Int = 0
    var createdAt: Date = Date()
}

struct ThreadReply: Identifiable, Equatable {
    let id = UUID()
    let author: String
    let authorAvatarColor: Color
    let content: String
    let timestamp: Date
    var isUnread: Bool = true
    var reactions: [String] = []

    init(author: String, authorAvatarColor: Color = V4Color.accent, content: String, timestamp: Date = Date(), reactions: [String] = []) {
        self.author = author
        self.authorAvatarColor = authorAvatarColor
        self.content = content
        self.timestamp = timestamp
        self.reactions = reactions
    }
}

// MARK: - Thread Indicator Badge

struct ThreadIndicator: View {
    let count: Int
    let hasUnread: Bool
    let onTap: () -> Void

    @State private var isPressed = false

    var body: some View {
        Button(action: {
            withAnimation(MTMotion.quickSpring) {
                onTap()
            }
        }) {
            ZStack {
                // Outer ring for unread state
                if hasUnread {
                    Circle()
                        .stroke(V4Color.accent, lineWidth: 2)
                }

                // Badge background
                Circle()
                    .fill(hasUnread ? V4Color.accent.opacity(0.2) : V4Color.textSecondary.opacity(V2Depth.stateHover))

                // Reply count
                Text(count < 10 ? "\(count)" : "9+")
                    .font(WernickeTypography.caption2Bold)
                    .foregroundStyle(hasUnread ? V4Color.accent : V4Color.textSecondary)
            }
            .frame(width: 22, height: 22)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .onTapGesture {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.6)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation {
                    isPressed = false
                }
            }
        }
        .accessibilityLabel("Thread with \(count) \(count == 1 ? "reply" : "replies")\(hasUnread ? ", \(hasUnread) unread" : "")")
    }
}

// MARK: - Inline Thread View

struct ThreadInlineView: View {
    let parentMessage: ChatMessage
    let thread: MessageThread
    let onReply: (String) -> Void
    let onDismiss: () -> Void

    @State private var replyText = ""
    @FocusState private var isFocused: Bool
    @Environment(\.colorScheme) private var colorScheme

    private var maxVisibleReplies: Int { 5 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with parent preview
            headerView

            Divider()
                .background(V4Color.border.opacity(V2Depth.stateDisabled))

            // Replies scroll view
            repliesScrollView

            Divider()
                .background(V4Color.border.opacity(V2Depth.stateDisabled))

            // Reply composer
            replyComposer
        }
        .background(V4Color.surface)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.border.opacity(V2Depth.stateDisabled), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }

    private var headerView: some View {
        HStack(spacing: ParietalSpacing.md / 2) {
            // Thread icon
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundStyle(V4Color.accent)
                .font(WernickeTypography.size14)

            // Reply count
            Text("\(thread.replies.count) \(thread.replies.count == 1 ? "Reply" : "Replies")")
                .font(.system(size: V1Theme.chatCaptionSize, weight: .medium))
                .foregroundStyle(V4Color.textPrimary)

            Spacer()

            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(V4Color.textSecondary)
                    .font(WernickeTypography.size16)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close thread")
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm + 2)
        .background(V4Color.sidebar.opacity(V2Depth.stateDisabled))
    }

    private var repliesScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                // Collapsed parent message preview
                parentPreview

                // Thread replies
                ForEach(thread.replies) { reply in
                    ThreadReplyCell(reply: reply)
                        .padding(.horizontal, ParietalSpacing.md)
                }
            }
            .padding(.vertical, ParietalSpacing.md)
        }
        .frame(maxHeight: thread.replies.count > maxVisibleReplies ? 280 : .none)
    }

    private var parentPreview: some View {
        HStack(alignment: .top, spacing: ParietalSpacing.sm) {
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text("Original message")
                    .font(.system(size: V1Theme.chatCaptionSize, weight: .medium))
                    .foregroundStyle(V4Color.textSecondary)

                Text(parentMessage.text)
                    .font(.system(size: V1Theme.chatFontSize - 1))
                    .foregroundStyle(V4Color.textSecondary)
                    .lineLimit(2)
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm)
            .background(V4Color.sidebar.opacity(V2Depth.stateHover))
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.bottom, 4)
    }

    private var replyComposer: some View {
        HStack(alignment: .bottom, spacing: ParietalSpacing.sm) {
            TextField("Add a reply...", text: $replyText, axis: .vertical)
                .font(.system(size: V1Theme.chatFontSize))
                .foregroundStyle(V4Color.textPrimary)
                .focused($isFocused)
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm)
                .background(V4Color.sidebar.opacity(V2Depth.stateDisabled))
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                .onSubmit {
                    submitReply()
                }

            Button(action: submitReply) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(replyText.isEmpty ? V4Color.textSecondary : V4Color.accent)
                    .font(WernickeTypography.size20)
            }
            .buttonStyle(.plain)
            .disabled(replyText.isEmpty)
            .accessibilityLabel("Send reply")
        }
        .padding(ParietalSpacing.md)
    }

    private func submitReply() {
        guard !replyText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        onReply(replyText)
        replyText = ""
    }
}

// MARK: - Thread Reply Cell

struct ThreadReplyCell: View {
    let reply: ThreadReply
    @State private var isHovering = false

    var body: some View {
        HStack(alignment: .top, spacing: ParietalSpacing.sm + 2) {
            // Indentation spacer (40% left indentation)
            Spacer()
                .frame(width: 0)

            VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
                // Author header
                HStack(spacing: ParietalSpacing.sm) {
                    // Avatar
                    Circle()
                        .fill(reply.authorAvatarColor.opacity(0.8))
                        .frame(width: ParietalSpacing.lg, height: ParietalSpacing.lg)
                        .overlay(
                            Text(String(reply.author.prefix(1)).uppercased())
                                .font(WernickeTypography.caption2Bold)
                                .foregroundStyle(.white)
                        )

                    // Author name
                    Text(reply.author)
                        .font(.system(size: V1Theme.chatCaptionSize, weight: .semibold))
                        .foregroundStyle(V4Color.textPrimary)

                    // Timestamp
                    Text(formatTimestamp(reply.timestamp))
                        .font(.system(size: V1Theme.chatCaptionSize - 1))
                        .foregroundStyle(V4Color.textSecondary)

                    Spacer()

                    // Inline actions (show on hover)
                    if isHovering {
                        HStack(spacing: ParietalSpacing.sm - 2) {
                            replyActionButton(icon: "arrowshape.turn.up.left", label: "Reply") {}
                            replyActionButton(icon: "hand.thumbsup", label: "React") {}
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }

                // Content with markdown support
                MarkdownTextView(text: reply.content)
                    .font(.system(size: V1Theme.chatFontSize))

                // Reactions
                if !reply.reactions.isEmpty {
                    HStack(spacing: ParietalSpacing.xs) {
                        ForEach(reply.reactions, id: \.self) { reaction in
                            Text(reaction)
                                .font(WernickeTypography.size13)
                                .padding(.horizontal, ParietalSpacing.xs + 2)
                                .padding(.vertical, 2)
                                .background(V4Color.border.opacity(V2Depth.stateDisabled))
                                .clipShape(SwiftUI.Capsule())
                        }
                    }
                }
            }
            .padding(ParietalSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .fill(V4Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .stroke(V4Color.border.opacity(V2Depth.stateHover), lineWidth: 1)
            )
        }
        .onHover { hovering in
            withAnimation(.easeInOut(duration: 0.15)) {
                isHovering = hovering
            }
        }
    }

    private func replyActionButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(WernickeTypography.size12)
                .foregroundStyle(V4Color.textSecondary)
                .padding(4)
                .background(V4Color.border.opacity(V2Depth.stateHover))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func formatTimestamp(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

// MARK: - Thread Expandable Container

struct ThreadExpandableContainer: View {
    let parentMessage: ChatMessage
    let thread: MessageThread
    let onReply: (String) -> Void
    let onMarkRead: () -> Void

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .trailing, spacing: ParietalSpacing.xs) {
            if isExpanded {
                ThreadInlineView(
                    parentMessage: parentMessage,
                    thread: thread,
                    onReply: { content in
                        onReply(content)
                        withAnimation(MTMotion.slow) {
                            isExpanded = false
                        }
                    },
                    onDismiss: {
                        withAnimation(MTMotion.slow) {
                            isExpanded = false
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95)),
                    removal: .opacity
                ))
            } else {
                ThreadIndicator(
                    count: thread.replies.count,
                    hasUnread: thread.unreadCount > 0
                ) {
                    withAnimation(MTMotion.standardSpring) {
                        isExpanded = true
                        onMarkRead()
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(MTMotion.standardSpring, value: isExpanded)
    }
}

// MARK: - Preview

struct MessageThreadView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ThreadStatesPreview()
            ReplyCellsPreview()
        }
    }
}

private struct ThreadStatesPreview: View {
    var body: some View {
        VStack(spacing: ParietalSpacing.xl) {
            // Thread indicator - unread
            HStack {
                Text("Parent message with thread")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textPrimary)
                Spacer()
                ThreadIndicator(count: 3, hasUnread: true) {}
            }
            .padding()
            .background(V4Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Thread indicator - read
            HStack {
                Text("Parent message with read thread")
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textPrimary)
                Spacer()
                ThreadIndicator(count: 5, hasUnread: false) {}
            }
            .padding()
            .background(V4Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Expanded thread
            ThreadInlineView(
                parentMessage: ChatMessage(role: .user, text: "This is the original message that started the thread. It has some content that we want to show in a collapsed preview."),
                thread: sampleThread,
                onReply: { _ in },
                onDismiss: {}
            )
            .padding()
            .frame(width: ParietalSpacing.xl * 20)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(V4Color.background)
    }
}

private struct ReplyCellsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            Text("Thread Reply Cells")
                .font(.headline)
                .foregroundStyle(V4Color.textPrimary)
                .padding(.horizontal)

            VStack(spacing: ParietalSpacing.sm) {
                ThreadReplyCell(reply: sampleReply1)
                ThreadReplyCell(reply: sampleReply2)
                ThreadReplyCell(reply: sampleReply3)
            }
            .padding()
            .frame(width: ParietalSpacing.xl * 20)
            .background(V4Color.surface)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(V4Color.background)
    }
}

// MARK: - Sample Data for Preview

private var sampleThread: MessageThread {
    var thread = MessageThread(parentID: UUID())
    thread.replies = [
        ThreadReply(author: "Alice", authorAvatarColor: .blue, content: "This is a great point! I think we should explore this further."),
        ThreadReply(author: "Bob", authorAvatarColor: .purple, content: "I agree. Let me add some **markdown** formatting to show *emphasis* and `code` blocks."),
        ThreadReply(author: "Charlie", authorAvatarColor: .orange, content: "Here's a thought:\n\n1. First consideration\n2. Second point\n3. Third item to discuss"),
        ThreadReply(author: "Diana", authorAvatarColor: .pink, content: "Could someone explain the third item in more detail?"),
    ]
    thread.unreadCount = 2
    return thread
}

private var sampleReply1: ThreadReply {
    ThreadReply(
        author: "Alice",
        authorAvatarColor: .blue,
        content: "This is a great point! I think we should explore this further."
    )
}

private var sampleReply2: ThreadReply {
    ThreadReply(
        author: "Bob",
        authorAvatarColor: .purple,
        content: "I agree. Let me add some **markdown** formatting to show *emphasis* and `code` blocks.",
        reactions: ["👍", "💡"]
    )
}

private var sampleReply3: ThreadReply {
    ThreadReply(
        author: "Charlie",
        authorAvatarColor: .orange,
        content: "Here's a thought:\n\n1. First consideration\n2. Second point\n3. Third item to discuss"
    )
}
