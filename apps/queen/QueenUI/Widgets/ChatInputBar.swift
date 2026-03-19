import SwiftUI

// MARK: - Compact Chat Input Bar Components

/// Minimal text input field (single-line)
struct CompactTextInput: View {
    @Binding var text: String
    var placeholder: String
    @FocusState.Binding var isFocused: Bool
    var onSubmit: () -> Void

    var body: some View {
        TextField(placeholder, text: $text, onCommit: onSubmit)
            .textFieldStyle(.plain)
            .font(.system(size: 15))
            .foregroundStyle(Color.white)
            .focused($isFocused)
            .frame(height: 32)
    }
}

/// Compact send button
struct SendButton: View {
    var text: String
    var isStreaming: Bool
    var action: () -> Void

    private var isEnabled: Bool {
        !text.isEmpty && !isStreaming
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 20))
                .foregroundStyle(isEnabled ? TrinityTheme.accent : Color.white.opacity(0.15))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .frame(width: 36, height: 36)
    }
}

/// Minimal chat input bar - just text + send button
struct CompactChatInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var isStreaming: Bool
    var onSend: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            CompactTextInput(
                text: $text,
                placeholder: "Type a message...",
                isFocused: $isFocused,
                onSubmit: onSend
            )

            SendButton(
                text: text,
                isStreaming: isStreaming,
                action: onSend
            )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: 0x1A1A1A))
                .stroke(Color.white.opacity(0.1), lineWidth: 1)
        )
        .frame(height: 52)
        .fixedSize(horizontal: false, vertical: true)
    }
}
