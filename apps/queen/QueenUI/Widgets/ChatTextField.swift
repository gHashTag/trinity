import SwiftUI

/// Minimal text input field - single-line, compact (32pt height)
struct ChatTextField: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var placeholder: String
    var onSubmit: () -> Void

    var body: some View {
        ZStack(alignment: .leading) {
            if text.isEmpty {
                Text(placeholder)
                    .font(WernickeTypography.body14Medium)
                    .foregroundStyle(V4Color.textSecondary.opacity(V4Color.opacity50))
            }
            TextField("", text: $text, onCommit: onSubmit)
                .textFieldStyle(.plain)
                .font(WernickeTypography.body)
                .foregroundStyle(V4Color.textPrimary)
                .background(Color.clear)
                .focused($isFocused)
                .frame(height: ParietalSpacing.avatarSmall)
        }
    }
}

/// Minimal send button
struct ChatSendButton: View {
    var text: String
    var isStreaming: Bool
    var action: () -> Void

    private var isEnabled: Bool {
        !text.isEmpty && !isStreaming
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: "arrow.up.circle.fill")
                .font(WernickeTypography.size20)
                .foregroundStyle(isEnabled ? V4Color.accent : V4Color.textSecondary.opacity(V4Color.opacity15))
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .frame(width: ParietalSpacing.avatarSmall + 4, height: ParietalSpacing.avatarSmall + 4)
    }
}
