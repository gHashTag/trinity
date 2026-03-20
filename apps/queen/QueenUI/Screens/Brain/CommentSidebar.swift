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
                    .font(WernickeTypography.body14Semibold)
                    .foregroundStyle(Color.white)
                Spacer()
                Button(action: onClose) {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.captionMedium)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Close comments")
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm)

            // Quoted original message
            Text(message.text)
                .font(WernickeTypography.size12)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
                .lineLimit(3)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 12)
                .overlay(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(V4Color.accent.opacity(V2Depth.stateDisabled))
                        .frame(width: ParietalSpacing.smallIndicator)
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.bottom, 12)

            Rectangle()
                .fill(Color.white.opacity(V2Depth.bgCard))
                .frame(height: 1)

            // Comment messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: ParietalSpacing.md) {
                        ForEach(comments) { comment in
                            CommentRow(comment: comment)
                        }

                        if client.isStreaming {
                            HStack(spacing: ParietalSpacing.sm - 2) {
                                ProgressView()
                                    .controlSize(.small)
                                    .tint(V4Color.accent)
                                Text("Thinking...")
                                    .font(WernickeTypography.size12)
                                    .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
                            }
                            .padding(.horizontal, ParietalSpacing.md)
                        }

                        Color.clear.frame(height: 1).id("commentBottom")
                    }
                    .padding(.vertical, ParietalSpacing.sm)
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
                .fill(Color.white.opacity(V2Depth.bgCard))
                .frame(height: 1)

            HStack(spacing: ParietalSpacing.sm) {
                TextField("Add a comment...", text: $commentInput, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(WernickeTypography.size13)
                    .foregroundStyle(Color.white)
                    .focused($commentFocused)
                    .lineLimit(1...4)
                    .onSubmit { sendComment() }

                Button(action: sendComment) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(WernickeTypography.size20)
                        .foregroundStyle(commentInput.isEmpty ? Color.white.opacity(V2Depth.bgSidebarHover) : V4Color.accent)
                }
                .buttonStyle(.plain)
                .disabled(commentInput.isEmpty || client.isStreaming)
                .accessibilityLabel("Send comment")
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, 10)
            .background(V4Color.surfaceElevated)
        }
        .frame(
            minWidth: LayoutConstants.commentSidebarMinWidth,
            idealWidth: LayoutConstants.commentSidebarIdealWidth,
            maxWidth: LayoutConstants.commentSidebarMaxWidth
        )
        .background(V4Color.background)
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
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Circle()
                    .fill(comment.role == .user ? Color.white.opacity(V2Depth.stateHover) :
                          hasError ? V4Color.statusError.opacity(V2Depth.stateDisabled) :
                          V4Color.accent.opacity(V2Depth.stateDisabled))
                    .frame(width: ParietalSpacing.dotSize, height: 6)
                Text(comment.role == .user ? "You" : "Queen")
                    .font(WernickeTypography.caption2Semibold)
                    .foregroundStyle(comment.role == .user ? Color.white.opacity(V2Depth.stateDisabled) :
                                    hasError ? V4Color.statusError :
                                    V4Color.accent)
            }

            if comment.text.isEmpty {
                Text(" ")
                    .font(WernickeTypography.size13)
            } else if let attributed = try? AttributedString(markdown: comment.text) {
                Text(attributed)
                    .font(WernickeTypography.size13)
                    .foregroundStyle(hasError ? V4Color.statusError : V4Color.textSecondary)
                    .textSelection(.enabled)
                    .lineSpacing(2)
            } else {
                Text(comment.text)
                    .font(WernickeTypography.size13)
                    .foregroundStyle(hasError ? V4Color.statusError : V4Color.textSecondary)
                    .textSelection(.enabled)
                    .lineSpacing(2)
            }

            // Retry button for error comments
            if hasError, let retry = onRetry {
                Button {
                    retry()
                } label: {
                    HStack(spacing: ParietalSpacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(WernickeTypography.size9)
                        Text("Retry")
                            .font(WernickeTypography.miniBold)
                    }
                    .foregroundStyle(V4Color.statusError)
                }
                .buttonStyle(.plain)
                .padding(.top, 2)
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
    }
}
