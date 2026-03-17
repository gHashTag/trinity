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

    init(author: String, authorAvatarColor: Color = TrinityTheme.accent, content: String, timestamp: Date = Date(), reactions: [String] = []) {
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
            withAnimation(TrinityTheme.quickSpring()) {
                onTap()
            }
        }) {
            ZStack {
                // Outer ring for unread state
                if hasUnread {
                    Circle()
                        .stroke(TrinityTheme.accent, lineWidth: 2)
                }

                // Badge background
                Circle()
                    .fill(hasUnread ? TrinityTheme.accent.opacity(0.2) : TrinityTheme.textMuted.opacity(0.3))

                // Reply count
                Text(count < 10 ? "\(count)" : "9+")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(hasUnread ? TrinityTheme.accent : TrinityTheme.textMuted)
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
                .background(TrinityTheme.bgCardBorder.opacity(0.5))

            // Replies scroll view
            repliesScrollView

            Divider()
                .background(TrinityTheme.bgCardBorder.opacity(0.5))

            // Reply composer
            replyComposer
        }
        .background(TrinityTheme.bgCard)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(TrinityTheme.bgCardBorder.opacity(0.5), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))
        .shadow(color: .black.opacity(0.2), radius: 8, x: 0, y: 2)
    }

    private var headerView: some View {
        HStack(spacing: TrinityTheme.spacing / 2) {
            // Thread icon
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .foregroundStyle(TrinityTheme.accent)
                .font(.system(size: 14))

            // Reply count
            Text("\(thread.replies.count) \(thread.replies.count == 1 ? "Reply" : "Replies")")
                .font(.system(size: TrinityTheme.chatCaptionSize, weight: .medium))
                .foregroundStyle(TrinityTheme.textPrimary)

            Spacer()

            // Close button
            Button(action: onDismiss) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(TrinityTheme.textMuted)
                    .font(.system(size: 16))
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Close thread")
        }
        .padding(.horizontal, TrinityTheme.spacing)
        .padding(.vertical, 10)
        .background(TrinityTheme.bgSidebar.opacity(0.5))
    }

    private var repliesScrollView: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                // Collapsed parent message preview
                parentPreview

                // Thread replies
                ForEach(thread.replies) { reply in
                    ThreadReplyCell(reply: reply)
                        .padding(.horizontal, TrinityTheme.spacing)
                }
            }
            .padding(.vertical, TrinityTheme.spacing)
        }
        .frame(maxHeight: thread.replies.count > maxVisibleReplies ? 280 : .none)
    }

    private var parentPreview: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Original message")
                    .font(.system(size: TrinityTheme.chatCaptionSize, weight: .medium))
                    .foregroundStyle(TrinityTheme.textMuted)

                Text(parentMessage.text)
                    .font(.system(size: TrinityTheme.chatFontSize - 1))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .lineLimit(2)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(TrinityTheme.bgSidebar.opacity(0.3))
            .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall))
        }
        .padding(.horizontal, TrinityTheme.spacing)
        .padding(.bottom, 4)
    }

    private var replyComposer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            TextField("Add a reply...", text: $replyText, axis: .vertical)
                .font(.system(size: TrinityTheme.chatFontSize))
                .foregroundStyle(TrinityTheme.textPrimary)
                .focused($isFocused)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(TrinityTheme.bgSidebar.opacity(0.5))
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall))
                .onSubmit {
                    submitReply()
                }

            Button(action: submitReply) {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundStyle(replyText.isEmpty ? TrinityTheme.textMuted : TrinityTheme.accent)
                    .font(.system(size: 20))
            }
            .buttonStyle(.plain)
            .disabled(replyText.isEmpty)
            .accessibilityLabel("Send reply")
        }
        .padding(TrinityTheme.spacing)
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
        HStack(alignment: .top, spacing: 10) {
            // Indentation spacer (40% left indentation)
            Spacer()
                .frame(width: 0)

            VStack(alignment: .leading, spacing: 6) {
                // Author header
                HStack(spacing: 8) {
                    // Avatar
                    Circle()
                        .fill(reply.authorAvatarColor.opacity(0.8))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Text(String(reply.author.prefix(1)).uppercased())
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(.white)
                        )

                    // Author name
                    Text(reply.author)
                        .font(.system(size: TrinityTheme.chatCaptionSize, weight: .semibold))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    // Timestamp
                    Text(formatTimestamp(reply.timestamp))
                        .font(.system(size: TrinityTheme.chatCaptionSize - 1))
                        .foregroundStyle(TrinityTheme.textMuted)

                    Spacer()

                    // Inline actions (show on hover)
                    if isHovering {
                        HStack(spacing: 6) {
                            replyActionButton(icon: "arrowshape.turn.up.left", label: "Reply") {}
                            replyActionButton(icon: "hand.thumbsup", label: "React") {}
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                }

                // Content with markdown support
                MarkdownTextView(text: reply.content)
                    .font(.system(size: TrinityTheme.chatFontSize))

                // Reactions
                if !reply.reactions.isEmpty {
                    HStack(spacing: 4) {
                        ForEach(reply.reactions, id: \.self) { reaction in
                            Text(reaction)
                                .font(.system(size: 13))
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(TrinityTheme.bgCardBorder.opacity(0.5))
                                .clipShape(Capsule())
                        }
                    }
                }
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                    .fill(TrinityTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                    .stroke(TrinityTheme.bgCardBorder.opacity(0.3), lineWidth: 1)
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
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.textMuted)
                .padding(4)
                .background(TrinityTheme.bgCardBorder.opacity(0.3))
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
        VStack(alignment: .trailing, spacing: 4) {
            if isExpanded {
                ThreadInlineView(
                    parentMessage: parentMessage,
                    thread: thread,
                    onReply: { content in
                        onReply(content)
                        withAnimation(TrinityTheme.gentleSpring()) {
                            isExpanded = false
                        }
                    },
                    onDismiss: {
                        withAnimation(TrinityTheme.gentleSpring()) {
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
                    withAnimation(TrinityTheme.springAnimation()) {
                        isExpanded = true
                        onMarkRead()
                    }
                }
                .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(TrinityTheme.springAnimation(), value: isExpanded)
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
        VStack(spacing: 24) {
            // Thread indicator - unread
            HStack {
                Text("Parent message with thread")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textPrimary)
                Spacer()
                ThreadIndicator(count: 3, hasUnread: true) {}
            }
            .padding()
            .background(TrinityTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Thread indicator - read
            HStack {
                Text("Parent message with read thread")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textPrimary)
                Spacer()
                ThreadIndicator(count: 5, hasUnread: false) {}
            }
            .padding()
            .background(TrinityTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Expanded thread
            ThreadInlineView(
                parentMessage: ChatMessage(role: .user, text: "This is the original message that started the thread. It has some content that we want to show in a collapsed preview."),
                thread: sampleThread,
                onReply: { _ in },
                onDismiss: {}
            )
            .padding()
            .frame(width: 500)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TrinityTheme.bgWindow)
    }
}

private struct ReplyCellsPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Thread Reply Cells")
                .font(.headline)
                .foregroundStyle(TrinityTheme.textPrimary)
                .padding(.horizontal)

            VStack(spacing: 8) {
                ThreadReplyCell(reply: sampleReply1)
                ThreadReplyCell(reply: sampleReply2)
                ThreadReplyCell(reply: sampleReply3)
            }
            .padding()
            .frame(width: 500)
            .background(TrinityTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TrinityTheme.bgWindow)
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
