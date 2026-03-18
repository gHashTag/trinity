import SwiftUI

// MARK: - Message Quote View

struct MessageQuoteView: View {
    let originalMessage: ChatMessage
    let onReply: (String) -> Void

    @State private var replyText: String = ""
    @State private var isEditing: Bool = false
    @State private var showComposer: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
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
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.turn.up.left")
                        Text("Reply to this message")
                    }
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
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
            HStack(alignment: .top, spacing: 8) {
                // Mini avatar
                Circle()
                    .fill(TrinityTheme.accent.opacity(0.2))
                    .frame(width: 16, height: 16)
                    .overlay(
                        Image(systemName: message.role == .assistant ? "triangle.fill" : "person.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(TrinityTheme.accent)
                    )

                VStack(alignment: .leading, spacing: 4) {
                    // Author and time
                    HStack(spacing: 6) {
                        Text(message.role == .assistant ? "Trinity" : "You")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundStyle(TrinityTheme.textPrimary)

                        Text(formatDate(message.timestamp))
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }

                    // Truncated content
                    Text(truncatedText)
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                        .lineLimit(2)
                }

                Spacer()

                Image(systemName: "arrow.turn.down.right")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.accent)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                    .fill(TrinityTheme.bgCard.opacity(0.5))
            )
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                    .stroke(TrinityTheme.accent.opacity(0.3), lineWidth: 1)
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
        VStack(alignment: .leading, spacing: 8) {
            // Text editor
            TextEditor(text: $text)
                .font(.system(size: 14))
                .focused($isFocused)
                .frame(minHeight: 80, maxHeight: 120)
                .scrollContentBackground(.hidden)
                .background(TrinityTheme.bgCard)
                .cornerRadius(TrinityTheme.cornerSmall)
                .overlay(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                        .stroke(isFocused ? TrinityTheme.accent : TrinityTheme.bgCardBorder, lineWidth: 1)
                )

            HStack {
                Text("\(text.count) chars")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)

                Spacer()

                HStack(spacing: 8) {
                    Button("Cancel", action: onCancel)
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)

                    Button("Send") {
                        onSend(text)
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .disabled(text.isEmpty)
                    .foregroundStyle(text.isEmpty ? TrinityTheme.textMuted : TrinityTheme.accent)
                }
            }
        }
        .onAppear { isFocused = true }
    }
}

// MARK: - Preview

struct MessageQuoteView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
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
        .background(TrinityTheme.bgWindow)
    }
}
