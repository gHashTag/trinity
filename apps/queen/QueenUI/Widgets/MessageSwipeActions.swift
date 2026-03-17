import SwiftUI
import AppKit

// MARK: - Swipe Action Enum

/// Actions available through swipe gestures on messages
public enum SwipeAction: Equatable {
    case reply
    case forward
    case copy
    case delete

    /// Icon displayed for the action
    var icon: String {
        switch self {
        case .reply: return "arrow.uturn.backward"
        case .forward: return "arrow.uturn.forward"
        case .copy: return "doc.on.doc"
        case .delete: return "trash"
        }
    }

    /// Color for the action background
    var color: Color {
        switch self {
        case .reply: return Color(hex: 0x00FF88) // green from theme accent
        case .forward: return TrinityTheme.purple
        case .copy: return Color(hex: 0x3B82F6) // blue
        case .delete: return TrinityTheme.statusError
        }
    }

    /// Accessibility label for VoiceOver
    var accessibilityLabel: String {
        switch self {
        case .reply: return "Reply to message"
        case .forward: return "Forward message"
        case .copy: return "Copy message"
        case .delete: return "Delete message"
        }
    }

    /// Accessibility hint for VoiceOver
    var accessibilityHint: String {
        switch self {
        case .reply: return "Opens reply composer with this message quoted"
        case .forward: return "Shares this message to another conversation"
        case .copy: return "Copies message text to clipboard"
        case .delete: return "Removes this message permanently"
        }
    }
}

// MARK: - Swipe Gesture State

/// Tracks the current state of a swipe gesture
private enum SwipeState {
    case idle
    case dragging(offset: CGFloat)
    case triggering(action: SwipeAction)

    var currentOffset: CGFloat {
        switch self {
        case .idle: return 0
        case .dragging(let offset): return offset
        case .triggering: return 0
        }
    }
}

// MARK: - Message Swipe Actions Modifier

/// A view modifier that adds swipe actions to any view
public struct MessageSwipeActions: ViewModifier {
    // MARK: - Properties

    /// Callback when an action is triggered
    var onSwipeAction: (SwipeAction) -> Void

    /// Actions available on the leading (right swipe) side
    var leadingActions: [SwipeAction] = [.reply, .copy]

    /// Actions available on the trailing (left swipe) side
    var trailingActions: [SwipeAction] = [.forward, .delete]

    /// Minimum swipe distance to trigger an action
    var triggerThreshold: CGFloat = 80

    /// Width of each action button for visual feedback
    var actionWidth: CGFloat = 80

    // MARK: - State

    @State private var swipeState: SwipeState = .idle
    @State private var isTriggering = false

    // MARK: - Environment

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    // MARK: - Body

    public func body(content: Content) -> some View {
        content
            .offset(x: swipeState.currentOffset)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        guard !isTriggering else { return }
                        handleDragChanged(value)
                    }
                    .onEnded { value in
                        handleDragEnded(value)
                    }
            )
            .background(swipeBackground)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Message")
            .animation(reduceMotion ? .easeInOut(duration: 0.2) : .spring(response: 0.4, dampingFraction: 0.75), value: swipeState.currentOffset)
    }

    // MARK: - Drag Handling

    private func handleDragChanged(_ value: DragGesture.Value) {
        let translation = value.translation.width

        // Constrain to maximum swipe distance
        let maxOffset = CGFloat(trailingActions.count) * actionWidth
        let minOffset = -CGFloat(leadingActions.count) * actionWidth
        let constrainedOffset = max(minOffset, min(maxOffset, translation))

        swipeState = .dragging(offset: constrainedOffset)
    }

    private func handleDragEnded(_ value: DragGesture.Value) {
        let offset = value.translation.width
        let velocity = value.velocity.width

        // Determine if we should trigger an action
        if offset > triggerThreshold || (offset > triggerThreshold * 0.5 && velocity > 500) {
            // Right swipe - leading actions
            let actionIndex = min(Int(abs(offset) / actionWidth), leadingActions.count - 1)
            triggerAction(leadingActions[actionIndex])
        } else if offset < -triggerThreshold || (offset < -triggerThreshold * 0.5 && velocity < -500) {
            // Left swipe - trailing actions
            let actionIndex = min(Int(abs(offset) / actionWidth), trailingActions.count - 1)
            triggerAction(trailingActions[actionIndex])
        } else {
            // Spring back to idle
            swipeState = .idle
        }
    }

    private func triggerAction(_ action: SwipeAction) {
        guard !isTriggering else { return }
        isTriggering = true
        swipeState = .triggering(action: action)

        // Haptic feedback
        TrinityHapticFeedback.perform(.alignment)

        // Notify parent
        onSwipeAction(action)

        // Reset after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isTriggering = false
            swipeState = .idle
        }
    }

    // MARK: - Background View

    @ViewBuilder
    private var swipeBackground: some View {
        ZStack {
            if case .dragging(let offset) = swipeState, offset != 0 {
                GeometryReader { geometry in
                    HStack(spacing: 0) {
                        // Leading actions (right swipe)
                        ForEach(Array(leadingActions.enumerated()), id: \.offset) { index, action in
                            actionBackground(for: action)
                                .frame(width: actionWidth)
                                .opacity(trailingActionOpacity(for: index, offset: offset))
                        }

                        Spacer()

                        // Trailing actions (left swipe)
                        ForEach(Array(trailingActions.enumerated()), id: \.offset) { index, action in
                            actionBackground(for: action)
                                .frame(width: actionWidth)
                                .opacity(leadingActionOpacity(for: index, offset: offset))
                        }
                    }
                }
            }
        }
    }

    private func actionBackground(for action: SwipeAction) -> some View {
        ZStack {
            action.color

            Image(systemName: action.icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)
        }
    }

    // MARK: - Opacity Calculations

    private func trailingActionOpacity(for index: Int, offset: CGFloat) -> Double {
        let progress = offset / actionWidth
        _ = Double(index + 1) // unused threshold
        return min(max((progress - Double(index)) / 1.0, 0), 1)
    }

    private func leadingActionOpacity(for index: Int, offset: CGFloat) -> Double {
        let progress = abs(offset) / actionWidth
        _ = Double(index + 1) // unused threshold
        return min(max((progress - Double(index)) / 1.0, 0), 1)
    }

    // MARK: - Accessibility

    /// Accessibility actions for VoiceOver - handled via custom action handler
    var accessibilityActionHandlers: [String: SwipeAction] {
        var handlers: [String: SwipeAction] = [:]
        for action in leadingActions + trailingActions {
            handlers[action.accessibilityLabel] = action
        }
        return handlers
    }
}

// MARK: - View Extension

public extension View {
    /// Adds swipe actions to a message view
    /// - Parameters:
    ///   - onSwipeAction: Closure called when an action is triggered
    ///   - leadingActions: Actions for right swipe (default: reply, copy)
    ///   - trailingActions: Actions for left swipe (default: forward, delete)
    ///   - triggerThreshold: Points to swipe before triggering (default: 80)
    ///   - actionWidth: Width of each action button (default: 80)
    /// - Returns: A view with swipe gesture support
    func messageSwipeActions(
        onSwipeAction: @escaping (SwipeAction) -> Void,
        leadingActions: [SwipeAction] = [.reply, .copy],
        trailingActions: [SwipeAction] = [.forward, .delete],
        triggerThreshold: CGFloat = 80,
        actionWidth: CGFloat = 80
    ) -> some View {
        self.modifier(
            MessageSwipeActions(
                onSwipeAction: onSwipeAction,
                leadingActions: leadingActions,
                trailingActions: trailingActions,
                triggerThreshold: triggerThreshold,
                actionWidth: actionWidth
            )
        )
    }
}

// MARK: - Haptic Feedback (macOS)

/// Custom haptic feedback performer to avoid naming conflict with AppKit
private enum TrinityHapticFeedback {
    enum Pattern {
        case alignment
        case generic
        case levelChange
        case impact
    }

    static func perform(_ pattern: Pattern) {
        #if os(macOS)
        let nsPattern: AppKit.NSHapticFeedbackManager.FeedbackPattern
        switch pattern {
        case .alignment: nsPattern = .alignment
        case .generic: nsPattern = .generic
        case .levelChange: nsPattern = .levelChange
        case .impact: nsPattern = .generic
        }

        NSHapticFeedbackManager.defaultPerformer?.perform(nsPattern, performanceTime: .default)
        #endif
    }
}

// MARK: - Preview

struct MessageSwipeActions_Previews: PreviewProvider {
    static var previews: some View {
        MessageSwipeActionsPreview()
    }
}

private struct MessageSwipeActionsPreview: View {
    @State private var lastAction: SwipeAction?

    var body: some View {
        VStack(spacing: 20) {
            Text("Swipe a message to see actions")
                .font(.caption)
                .foregroundColor(TrinityTheme.textMuted)

            if let action = lastAction {
                Text("Triggered: \(action.accessibilityLabel)")
                    .padding(8)
                    .background(TrinityTheme.bgCard)
                    .cornerRadius(TrinityTheme.cornerSmall)
            }

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(TrinityTheme.accent)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Trinity")
                            .font(.headline)
                            .foregroundColor(TrinityTheme.textPrimary)

                        Text("Swipe me left or right to see available actions")
                            .font(.body)
                            .foregroundColor(TrinityTheme.textMuted)
                    }

                    Spacer()
                }
                .padding(12)
                .background(TrinityTheme.bgCard)
                .cornerRadius(TrinityTheme.cornerMedium)
            }
            .messageSwipeActions(
                onSwipeAction: { action in
                    lastAction = action
                }
            )
            .frame(maxWidth: 400)
            .padding()

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Circle()
                        .fill(TrinityTheme.purple)
                        .frame(width: 32, height: 32)

                    VStack(alignment: .leading, spacing: 4) {
                        Text("User")
                            .font(.headline)
                            .foregroundColor(TrinityTheme.textPrimary)

                        Text("Try different swipe distances for different actions")
                            .font(.body)
                            .foregroundColor(TrinityTheme.textMuted)
                    }

                    Spacer()
                }
                .padding(12)
                .background(TrinityTheme.bgCard)
                .cornerRadius(TrinityTheme.cornerMedium)
            }
            .messageSwipeActions(
                onSwipeAction: { action in
                    lastAction = action
                },
                leadingActions: [.reply],
                trailingActions: [.delete]
            )
            .frame(maxWidth: 400)
            .padding()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(TrinityTheme.bgWindow)
    }
}
