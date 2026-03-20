import SwiftUI
import AppKit

// MARK: - Keyboard Actions

enum KeyboardAction: Equatable {
    case new
    case search
    case open(UUID)
    case delete(UUID)
    case pin(UUID)
    case navigate(direction: NavigationDirection)
    case selectNext
    case selectPrevious
    case selectFirst
    case selectLast

    enum NavigationDirection {
        case up
        case down
        case left
        case right
    }
}

// Make NavigationDirection public for external use
extension KeyboardAction.NavigationDirection {
}

// MARK: - Type Select Buffer

private final class TypeSelectBuffer: @unchecked Sendable {
    var buffer: String = ""
    private var debounceTask: Task<Void, Never>?

    func resetAfterDelay() {
        debounceTask?.cancel()
        debounceTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 800_000_000)
            if !Task.isCancelled {
                self.buffer = ""
            }
        }
    }

    func cancelDebounce() {
        debounceTask?.cancel()
    }
}

// MARK: - Keyboard Handler

struct ThreadKeyboardHandler {
    @Binding var selectedThreadID: UUID?
    let onAction: (KeyboardAction) -> Void
    let threads: () -> [ChatThread]

    private var typeSelectBuffer = TypeSelectBuffer()

    init(
        selectedThreadID: Binding<UUID?>,
        onAction: @escaping (KeyboardAction) -> Void,
        threads: @escaping () -> [ChatThread]
    ) {
        self._selectedThreadID = selectedThreadID
        self.onAction = onAction
        self.threads = threads
    }

    mutating func handleKeyEvent(_ event: NSEvent) -> Bool {
        guard let chars = event.charactersIgnoringModifiers, !chars.isEmpty else {
            return false
        }

        let char = chars.first!
        let modifiers = event.modifierFlags

        // Handle with Command key
        if modifiers.contains(.command) {
            return handleCommandKey(char: char, modifiers: modifiers)
        }

        // Handle arrow keys for navigation using custom extension
        if let keyEvent = event.specialKeyEvent {
            return handleSpecialKeyEvent(keyEvent)
        }

        // Handle Delete key
        if char == Character(UnicodeScalar(127)) || event.keyCode == 51 {
            if let id = selectedThreadID {
                onAction(.delete(id))
                return true
            }
        }

        // Handle Enter/Return
        if char == "\r" || event.keyCode == 36 {
            if let id = selectedThreadID {
                onAction(.open(id))
                return true
            }
        }

        // Handle type-to-select
        if modifiers.intersection([.command, .control, .option]).isEmpty && char.isLetter {
            return handleTypeSelect(char)
        }

        return false
    }

    private func handleCommandKey(char: Character, modifiers: NSEvent.ModifierFlags) -> Bool {
        let hasShift = modifiers.contains(.shift)

        switch char {
        case "n":
            if hasShift {
                onAction(.new)
                return true
            }
        case "f":
            if hasShift {
                onAction(.search)
                return true
            }
        case "p":
            if hasShift, let id = selectedThreadID {
                onAction(.pin(id))
                return true
            }
        default:
            break
        }
        return false
    }

    private func handleSpecialKeyEvent(_ keyEvent: KeyEvent) -> Bool {
        switch keyEvent {
        case .upArrow:
            onAction(.navigate(direction: .up))
            return true
        case .downArrow:
            onAction(.navigate(direction: .down))
            return true
        case .leftArrow:
            onAction(.navigate(direction: .left))
            return true
        case .rightArrow:
            onAction(.navigate(direction: .right))
            return true
        case .pageUp:
            onAction(.selectFirst)
            return true
        case .pageDown:
            onAction(.selectLast)
            return true
        }
    }

    private mutating func handleTypeSelect(_ char: Character) -> Bool {
        // Cancel previous debounce task
        typeSelectBuffer.cancelDebounce()

        // Append character to buffer
        typeSelectBuffer.buffer.append(char.lowercased())

        // Get current buffer for immediate use
        let currentBuffer = typeSelectBuffer.buffer

        // Debounce: reset buffer after 800ms of no typing
        typeSelectBuffer.resetAfterDelay()

        // Find matching thread
        let allThreads = threads()
        guard !allThreads.isEmpty else { return false }

        // Start search from current selection or beginning
        let startIndex: Int
        if let currentID = selectedThreadID,
           let currentIndex = allThreads.firstIndex(where: { $0.id == currentID }) {
            startIndex = currentIndex + 1
        } else {
            startIndex = 0
        }

        // Search in threads from startIndex to end, then wrap to beginning
        let searchRange = allThreads[startIndex...] + allThreads[..<startIndex]

        for thread in searchRange {
            if thread.title.lowercased().hasPrefix(currentBuffer) {
                selectedThreadID = thread.id
                onAction(.open(thread.id))
                return true
            }
        }

        return false
    }

    mutating func resetTypeSelect() {
        typeSelectBuffer.buffer = ""
        typeSelectBuffer.cancelDebounce()
    }
}

// MARK: - Keyboard Shortcut View Modifier

struct ThreadKeyboardShortcuts: ViewModifier {
    @Binding var selectedThreadID: UUID?
    @Binding var isSearchFocused: Bool
    let threads: () -> [ChatThread]
    let onAction: (KeyboardAction) -> Void
    @State private var handler: ThreadKeyboardHandler
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        selectedThreadID: Binding<UUID?>,
        isSearchFocused: Binding<Bool>,
        threads: @escaping () -> [ChatThread],
        onAction: @escaping (KeyboardAction) -> Void
    ) {
        self._selectedThreadID = selectedThreadID
        self._isSearchFocused = isSearchFocused
        self.threads = threads
        self.onAction = onAction
        self._handler = State(initialValue: ThreadKeyboardHandler(
            selectedThreadID: selectedThreadID,
            onAction: onAction,
            threads: threads
        ))
    }

    func body(content: Content) -> some View {
        content
            .background(KeyboardShortcutMonitor(
                handler: $handler,
                isSearchFocused: _isSearchFocused
            ))
    }
}

// MARK: - Keyboard Shortcut Monitor

private struct KeyboardShortcutMonitor: NSViewRepresentable {
    @Binding var handler: ThreadKeyboardHandler
    @Binding var isSearchFocused: Bool

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.postsFrameChangedNotifications = true

        // Add local event monitor for keyboard events
        context.coordinator.monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak view] event in
            // Don't handle if search is focused
            if isSearchFocused {
                return event
            }

            // Let the responder chain handle first
            if let view = view, view.window?.firstResponder != nil {
                // Check if a text field is editing
                if let textView = view.window?.firstResponder as? NSTextView,
                   textView.isFieldEditor {
                    return event
                }
            }

            // Handle with our handler
            if handler.handleKeyEvent(event) {
                return nil // Consume the event
            }

            return event
        }

        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator {
        var monitor: Any?
    }
}

// MARK: - View Extension

extension View {
    func threadKeyboardShortcuts(
        selectedThreadID: Binding<UUID?>,
        isSearchFocused: Binding<Bool> = .constant(false),
        threads: @escaping () -> [ChatThread],
        onAction: @escaping (KeyboardAction) -> Void
    ) -> some View {
        self.modifier(ThreadKeyboardShortcuts(
            selectedThreadID: selectedThreadID,
            isSearchFocused: isSearchFocused,
            threads: threads,
            onAction: onAction
        ))
    }
}

// MARK: - Thread Row Selection Indicator

struct ThreadSelectionIndicator: View {
    let isSelected: Bool
    let isPinned: Bool
    let hasUnread: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isSelected: Bool, isPinned: Bool = false, hasUnread: Bool = false) {
        self.isSelected = isSelected
        self.isPinned = isPinned
        self.hasUnread = hasUnread
    }

    var body: some View {
        HStack(spacing: 0) {
            // Selection indicator bar
            Rectangle()
                .fill(isSelected ? V4Color.accent : Color.clear)
                .frame(width: ParietalSpacing.xxxs)
                .animation(reduceMotion ? .none : .easeInOut(duration: 0.2), value: isSelected)

            // Selection background
            if isSelected {
                Rectangle()
                    .fill(V4Color.accent.opacity(V2Depth.bgSidebarHover))
                    .transition(.opacity.combined(with: .move(edge: .leading)))
            }

            // Pin indicator
            if isPinned {
                Image(systemName: "pin.fill")
                    .font(WernickeTypography.size8)
                    .foregroundColor(V4Color.golden)
                    .padding(ParietalSpacing.xxs)
                    .background(Circle().fill(V4Color.golden.opacity(0.2)))
            }

            // Unread indicator
            if hasUnread {
                Circle()
                    .fill(V4Color.accent)
                    .frame(width: ParietalSpacing.dotSize, height: 6)
            }
        }
    }
}

// MARK: - Keyboard Shortcut Hint

struct KeyboardShortcutHint: View {
    let key: String
    let modifiers: String
    let action: String

    init(_ key: String, modifiers: String = "", action: String) {
        self.key = key
        self.modifiers = modifiers
        self.action = action
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            Text(action)
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            Spacer()

            HStack(spacing: ParietalSpacing.xs) {
                if !modifiers.isEmpty {
                    Text(modifiers)
                        .font(WernickeTypography.size10Mono.weight(.medium))
                        .foregroundStyle(V4Color.textSecondary)
                }
                Text(key)
                    .font(WernickeTypography.size10Mono.weight(.medium))
                    .foregroundStyle(V4Color.golden)
                    .padding(.horizontal, ParietalSpacing.xs + 2)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(V4Color.textSecondary.opacity(V2Depth.stateHover))
                    )
            }
        }
    }
}

// MARK: - Thread Keyboard Help Panel

struct ThreadKeyboardHelpPanel: View {
    @Binding var isPresented: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(isPresented: Binding<Bool>) {
        self._isPresented = isPresented
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Thread Navigation")
                    .font(.headline)
                    .foregroundStyle(V4Color.accent)

                Spacer()

                Button {
                    withAnimation(reduceMotion ? .none : .easeInOut(duration: 0.2)) {
                        isPresented = false
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding()

            Divider()
                .background(V4Color.textSecondary.opacity(0.2))

            ScrollView {
                VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
                    // Actions section
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("Actions")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(V4Color.textSecondary)
                            .padding(.horizontal)

                        KeyboardShortcutHint("N", modifiers: "⌘⇧", action: "New Thread")
                        KeyboardShortcutHint("F", modifiers: "⌘⇧", action: "Search")
                        KeyboardShortcutHint("P", modifiers: "⌘⇧", action: "Pin Thread")
                        KeyboardShortcutHint("⌫", action: "Archive")
                        KeyboardShortcutHint("↵", action: "Open Thread")
                    }
                    .padding(.bottom, 8)

                    // Navigation section
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("Navigation")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(V4Color.textSecondary)
                            .padding(.horizontal)

                        KeyboardShortcutHint("↑", action: "Previous Thread")
                        KeyboardShortcutHint("↓", action: "Next Thread")
                        KeyboardShortcutHint("⇠", action: "Previous Section")
                        KeyboardShortcutHint("⇢", action: "Next Section")
                    }
                    .padding(.bottom, 8)

                    // Type to select
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("Type to Select")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(V4Color.textSecondary)
                            .padding(.horizontal)

                        HStack {
                            Text("Start typing to filter threads by title")
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                            Spacer()
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
            }
        }
        .frame(width: ParietalSpacing.panelWidth, height: 320)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(V4Color.surface)
                .shadow(color: .black.opacity(V2Depth.stateDisabled), radius: 20, y: 4)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(V4Color.accent.opacity(V2Depth.stateHover), lineWidth: 1)
        )
    }
}

// MARK: - Accessible Thread Row

struct AccessibleThreadRow<Content: View>: View {
    let thread: ChatThread
    let isSelected: Bool
    let onTap: () -> Void
    let onSecondaryTap: () -> Void
    @ViewBuilder let content: Content

    init(
        thread: ChatThread,
        isSelected: Bool,
        onTap: @escaping () -> Void,
        onSecondaryTap: @escaping () -> Void = {},
        @ViewBuilder content: () -> Content
    ) {
        self.thread = thread
        self.isSelected = isSelected
        self.onTap = onTap
        self.onSecondaryTap = onSecondaryTap
        self.content = content()
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            content
        }
        .buttonStyle(.plain)
        .background(isSelected ? V4Color.accent.opacity(V2Depth.bgSidebarHover) : Color.clear)
        .overlay(
            Rectangle()
                .fill(isSelected ? V4Color.accent : Color.clear)
                .frame(width: ParietalSpacing.xxxs),
            alignment: .leading
        )
        .contextMenu {
            Button("Pin") {
                onSecondaryTap()
            }
            Button("Archive", role: .destructive) {
                onSecondaryTap()
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(thread.title)
        .accessibilityHint(isSelected ? "Selected" : "Double tap to open")
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityAction(named: "Open") {
            onTap()
        }
    }
}

// MARK: - KeyEvent Enum

private enum KeyEvent {
    case upArrow, downArrow, leftArrow, rightArrow, pageUp, pageDown
}

// MARK: - NSEvent Special Key Extension

private extension NSEvent {
    var specialKeyEvent: KeyEvent? {
        switch keyCode {
        case 126: return .upArrow
        case 125: return .downArrow
        case 123: return .leftArrow
        case 124: return .rightArrow
        case 116: return .pageUp
        case 121: return .pageDown
        default: return nil
        }
    }
}
