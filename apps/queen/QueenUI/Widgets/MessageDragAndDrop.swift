import SwiftUI

/// A drag-and-drop wrapper for chat messages that allows reordering within the same role.
/// Provides visual feedback with ghost images, drop indicators, and spring animations.
struct MessageDragAndDrop<Content: View>: View {
    /// Binding to the messages array that will be reordered
    @Binding var messages: [ChatMessage]

    /// The message this view represents
    let message: ChatMessage

    /// Content view to display (the actual message bubble)
    let content: Content

    /// Currently dragged message ID
    @State private var draggedMessageID: UUID?

    /// Location where the dragged message will be dropped
    @State private var dropTarget: DropTarget?

    /// Whether drag is currently active
    @State private var isDragging = false

    var body: some View {
        content
            .opacity(isDragging && draggedMessageID == message.id ? 0.3 : 1.0)
            .scaleEffect(isDragging && draggedMessageID == message.id ? 0.95 : 1.0)
            .overlay(
                // Drop indicator above message
                dropIndicator(for: .above),
                alignment: .top
            )
            .overlay(
                // Drop indicator below message
                dropIndicator(for: .below),
                alignment: .bottom
            )
            .background(
                // Invisible drag hit area
                GeometryReader { geometry in
                    Color.clear
                        .gesture(
                            dragGesture(geometry: geometry)
                        )
                }
            )
            .animation(MTMotion.standardSpring, value: isDragging)
            .animation(MTMotion.standardSpring, value: dropTarget)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Message \(message.role.rawValue)")
            .accessibilityHint("Drag to reorder")
            .accessibilityAddTraits(.isButton)
    }

    // MARK: - Drop Indicator

    @ViewBuilder
    private func dropIndicator(for position: DropTarget.Position) -> some View {
        if dropTarget?.messageID == message.id && dropTarget?.position == position {
            Rectangle()
                .fill(V4Color.accent)
                .frame(height: ParietalSpacing.xxxs)
                .frame(maxWidth: .infinity)
                .transition(.asymmetric(
                    insertion: .scale(scale: 0).combined(with: .opacity),
                    removal: .opacity
                ))
        }
    }

    // MARK: - Drag Gesture

    private func dragGesture(geometry: GeometryProxy) -> some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                guard !isDragging else { return }

                // Start drag
                isDragging = true
                draggedMessageID = message.id

                updateDropTarget(at: value.location, in: geometry)
            }
            .onEnded { value in
                guard draggedMessageID == message.id else {
                    resetDragState()
                    return
                }

                if let target = dropTarget,
                   canDrop(message: message, at: target) {
                    performDrop(to: target)
                }

                resetDragState()
            }
    }

    // MARK: - Drop Target Logic

    private func updateDropTarget(at location: CGPoint, in geometry: GeometryProxy) {
        let messageFrame = geometry.frame(in: .global)

        // Use dropTarget based on drag direction relative to message center
        if location.y < messageFrame.midY {
            dropTarget = DropTarget(messageID: message.id, position: .above)
        } else {
            dropTarget = DropTarget(messageID: message.id, position: .below)
        }
    }

    private func canDrop(message: ChatMessage, at target: DropTarget) -> Bool {
        // Only allow dropping at positions with same role
        guard let targetIndex = messages.firstIndex(where: { $0.id == target.messageID }) else {
            return false
        }

        let targetMessage = messages[targetIndex]
        return targetMessage.role == message.role
    }

    private func performDrop(to target: DropTarget) {
        guard let sourceIndex = messages.firstIndex(where: { $0.id == message.id }),
              let targetIndex = messages.firstIndex(where: { $0.id == target.messageID }) else {
            return
        }

        var newMessages = messages
        let movedMessage = newMessages.remove(at: sourceIndex)

        // Calculate insertion index based on drop position
        var insertIndex = targetIndex
        if sourceIndex < targetIndex {
            // Moving down: adjust for removal offset
            insertIndex = target.position == .above ? targetIndex : targetIndex + 1
        } else {
            // Moving up
            insertIndex = target.position == .above ? max(0, targetIndex) : targetIndex + 1
        }

        // Adjust for the removal when source was before target
        if sourceIndex < insertIndex {
            insertIndex -= 1
        }

        newMessages.insert(movedMessage, at: min(insertIndex, newMessages.count))
        messages = newMessages

        // Haptic feedback
        triggerHapticFeedback()
    }

    private func resetDragState() {
        isDragging = false
        draggedMessageID = nil
        dropTarget = nil
    }

    // MARK: - Haptic Feedback

    private func triggerHapticFeedback() {
        #if os(macOS)
        NSSound.beep()
        #elseif os(iOS)
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()
        #endif
    }
}

// MARK: - Drop Target

struct DropTarget: Equatable {
    enum Position {
        case above
        case below
    }

    let messageID: UUID
    let position: Position
}

// MARK: - Convenience Initializer

extension MessageDragAndDrop {
    /// Creates a drag-and-drop wrapper with a trailing closure content builder
    init(
        messages: Binding<[ChatMessage]>,
        message: ChatMessage,
        @ViewBuilder content: () -> Content
    ) {
        self._messages = messages
        self.message = message
        self.content = content()
    }
}

// Note: Preview available in Xcode via the #Preview macro
// Open this file in Xcode to see the live preview
