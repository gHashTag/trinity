import SwiftUI

// MARK: - Message Quote View

struct MessageQuoteView: View {
    let originalMessage: ChatMessage
    let onReply: (String) -> Void

    @State private var replyText: String = ""
    @State private var isEditing: Bool = false
    @State private var showComposer: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            // Original quoted message
            QuoteBubble(message: originalMessage, onTap: scrollTOriginal)

            if showComposer {
                QuoteComposer(
                    text: $replyText,
                    isEditing: $isEditing,
                    onCancel: { showComposer = false },
                    onSend: { text in
                        onReply(text)
                        showComposer = false
                        replyText = ""
                    }
                )
            } else {
                Button {
                    withAnimation {
                        showComposer = true
                    }
                } label: {
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        Image(systemName: "arrow.turn.up.left")
                        Text("Reply to this message")
                    }
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, ParietalSpacing.sm)
    }

    private func scrollTOriginal() {
        NotificationCenter.default.post(
            name: .scrollToMessage,
            object: originalMessage.id
        )
    }
}

// MARK: - Quote Bubble

struct QuoteBubble: View {
    let message: ChatMessage
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: ParietalSpacing.sm) {
                // Mini avatar
                Circle()
                    .fill(V4Color.accent.opacity(0.2))
                    .frame(width: ParietalSpacing.icon, height: ParietalSpacing.icon)
                    .overlay(
                        Image(systemName: message.role == .assistant ? "triangle.fill" : "person.fill")
                            .font(WernickeTypography.size8)
                            .foregroundStyle(V4Color.accent)
                    )

                VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                    // Author and time
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        Text(message.role == .assistant ? "Trinity" : "You")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(V4Color.textPrimary)

                        Text(formatDate(message.timestamp))
                            .font(.caption2)
                            .foregroundStyle(V4Color.textSecondary)
                    }

                    // Truncated content
                    Text(truncatedText)
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2)
                    .foregroundStyle(V4Color.accent)
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm)
            .background(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .fill(V4Color.surface.opacity(V2Depth.stateDisabled))
            )
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .stroke(V4Color.accent.opacity(V2Depth.stateHover), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private var truncatedText: String {
        let cleaned = message.text.replacingOccurrences(of: "\n", with: " ")
        return String(cleaned.prefix(60)) + (cleaned.count > 60 ? "..." : "")
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: date)
    }
}

// MARK: - Quote Composer

struct QuoteComposer: View {
    @Binding var text: String
    @Binding var isEditing: Bool
    let onCancel: () -> Void
    let onSend: (String) -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            // Text editor
            TextEditor(text: $text)
                .font(WernickeTypography.size14)
                .focused($isFocused)
                .frame(minHeight: 80, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .background(V4Color.surface)
                .cornerRadius(V1Theme.cornerSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                        .stroke(isFocused ? V4Color.accent : V4Color.border, lineWidth: 1)
                )

            HStack {
                Text("\(text.count) chars")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)

                Spacer()

                HStack(spacing: ParietalSpacing.sm) {
                    Button("Cancel", action: onCancel)
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)

                    Button("Send") {
                        onSend(text)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .disabled(text.isEmpty)
                    .foregroundStyle(text.isEmpty ? V4Color.textSecondary : V4Color.accent)
                }
            }
        }
        .onAppear { isFocused = true }
    }
}

// MARK: - Preview

struct MessageQuoteView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            MessageQuoteView(
                originalMessage: ChatMessage(
                    role: .assistant,
                    text: "This is a longer message that should be truncated when displayed in the quote bubble. It demonstrates how the preview works."
                ),
                onReply: { _ in }
            )
            .padding()

            QuoteBubble(
                message: ChatMessage(role: .user, text: "Short message"),
                onTap: {}
            )
            .padding()
        }
        .background(V4Color.background)
    }
}
