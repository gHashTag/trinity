import SwiftUI

struct CommentSidebar: View {
    let message: ChatMessage
    @ObservedObject var store: ThreadStore
    @ObservedObject var client: ChatClient
    @ObservedObject var modelManager: ModelManager
    let onClose: () -> Void

    @State private var commentInput = ""
    @FocusState private var commentFocused: Bool

    private var comments: [ChatMessage] {
        guard let threadID = store.activeThreadID,
              let thread = store.threads.first(where: { $0.id == threadID }),
              let msg = thread.messages.first(where: { $0.id == message.id }) else {
            return []
        }
        return msg.comments ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Comments")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Color.white)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close comments")
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Quoted original message
            Text(message.text)
                .font(.system(size: 12))
                .foregroundStyle(Color.white.opacity(0.4))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(TrinityTheme.accent.opacity(0.5))
                        .frame(width: 3)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 12)

            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            // Comment messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment)
                        }

                        if client.isStreaming {
                            HStack(spacing: 6) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(TrinityTheme.accent)
                                Text("Thinking...")
                                    .font(.system(size: 12))
                                    .foregroundStyle(Color.white.opacity(0.3))
                            }
                            .padding(.horizontal, 16)
                        }

                        Color.clear.frame(height: 1).id("commentBottom")
                    }
                    .padding(.vertical, 12)
                }
                .onChange(of: comments.count) {
                    withAnimation(.easeOut(duration: 0.15)) {
                        proxy.scrollTo("commentBottom", anchor: .bottom)
                    }
                }
            }

            Spacer(minLength: 0)

            // Mini input bar
            Rectangle()
                .fill(Color.white.opacity(0.06))
                .frame(height: 1)

            HStack(spacing: 8) {
                TextField("Add a comment...", text: $commentInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 13))
                    .foregroundStyle(Color.white)
                    .focused($commentFocused)
                    .lineLimit(1...4)
                    .onSubmit { sendComment() }

                Button(action: sendComment) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(commentInput.isEmpty ? Color.white.opacity(0.15) : TrinityTheme.accent)
                }
                .buttonStyle(.plain)
                .disabled(commentInput.isEmpty || client.isStreaming)
                .accessibilityLabel("Send comment")
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(hex: 0x111111))
        }
        .frame(
            minWidth: LayoutConstants.commentSidebarMinWidth,
            idealWidth: LayoutConstants.commentSidebarIdealWidth,
            maxWidth: LayoutConstants.commentSidebarMaxWidth
        )
        .background(Color(hex: 0x0A0A0A))
        .transition(.move(edge: .trailing).combined(with: .opacity))
        .onAppear { commentFocused = true }
    }

    private func sendComment() {
        let text = commentInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !client.isStreaming else { return }
        guard let threadID = store.activeThreadID else { return }
        commentInput = ""
        client.sendComment(text, about: message, threadID: threadID, store: store, modelManager: modelManager)
    }
}

// MARK: - Comment Row (simplified message)

struct CommentRow: View {
    let comment: ChatMessage
    var onRetry: (() -> Void)? = nil

    private var hasError: Bool {
        comment.role == .assistant &&
        (comment.text.contains("[Error") || comment.text.contains("[API Error"))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Circle()
                    .fill(comment.role == .user ? Color.white.opacity(0.3) :
                          hasError ? TrinityTheme.statusError.opacity(0.5) :
                          TrinityTheme.accent.opacity(0.5))
                    .frame(width: 6, height: 6)
                Text(comment.role == .user ? "You" : "Queen")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(comment.role == .user ? Color.white.opacity(0.5) :
                                    hasError ? TrinityTheme.statusError :
                                    TrinityTheme.accent)
            }

            if comment.text.isEmpty {
                Text(" ")
                    .font(.system(size: 13))
            } else if let attributed = try? AttributedString(markdown: comment.text) {
                Text(attributed)
                    .font(.system(size: 13))
                    .foregroundStyle(hasError ? TrinityTheme.statusError : Color(hex: 0xD1D1D1))
                    .textSelection(.enabled)
                    .lineSpacing(2)
            } else {
                Text(comment.text)
                    .font(.system(size: 13))
                    .foregroundStyle(hasError ? TrinityTheme.statusError : Color(hex: 0xD1D1D1))
                    .textSelection(.enabled)
                    .lineSpacing(2)
            }

            // Retry button for error comments
            if hasError, let retry = onRetry {
                Button {
                    retry()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                        Text("Retry")
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(TrinityTheme.statusError)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, 16)
    }
}
