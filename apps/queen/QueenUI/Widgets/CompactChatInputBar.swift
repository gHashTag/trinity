import SwiftUI

/// Compact chat input bar - 52pt total height
/// Combines text field and send button in minimal layout
struct CompactChatInputBar: View {
    @Binding var text: String
    @FocusState.Binding var isFocused: Bool
    var placeholder: String
    var isStreaming: Bool
    var isDropTargeted: Bool = false
    var onSubmit: () -> Void

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            ChatTextField(
                text: $text,
                isFocused: $isFocused,
                placeholder: placeholder,
                onSubmit: onSubmit
            )
            .layoutPriority(1)

            ChatSendButton(
                text: text,
                isStreaming: isStreaming,
                action: onSubmit
            )
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .fill(V4Color.surfaceElevated)
                .stroke(isDropTargeted ? V4Color.accent : V4Color.border, lineWidth: isDropTargeted ? 2 : 1)
        )
        .frame(minHeight: 52, idealHeight: 52, maxHeight: 52)
        .padding(.horizontal, ParietalSpacing.md)
    }
}
