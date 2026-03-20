// Keyboard Shortcut View — Shortcut Display and Recording
import SwiftUI

// MARK: - Keyboard Shortcut Display

struct KeyboardShortcutDisplay: View {
    let shortcut: KeyboardShortcut

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            ForEach(keys, id: \.self) { key in
                KeyCap(key: key)
            }
        }
    }

    private var keys: [String] {
        var result: [String] = []

        if let modifiers = shortcut.modifiers {
            if modifiers.contains(.command) {
                result.append("⌘")
            }
            if modifiers.contains(.option) {
                result.append("⌥")
            }
            if modifiers.contains(.control) {
                result.append("⌃")
            }
            if modifiers.contains(.shift) {
                result.append("⇧")
            }
        }

        if let key = shortcut.key {
            result.append(keyDisplay(for: key))
        }

        return result
    }

    private func keyDisplay(for key: ShortcutKey) -> String {
        switch key {
        case .space: return "Space"
        case .enterKey: return "↩"
        case .tab: return "⇥"
        case .delete: return "⌫"
        case .escape: return "⎋"
        case .upArrow: return "↑"
        case .downArrow: return "↓"
        case .leftArrow: return "←"
        case .rightArrow: return "→"
        case .home: return "↖"
        case .end: return "↘"
        case .pageUp: return "⇞"
        case .pageDown: return "⇟"
        case .character(let string): return string
        }
    }
}

// MARK: - Key Cap

struct KeyCap: View {
    let key: String
    let isPressed: Bool

    init(key: String, isPressed: Bool = false) {
        self.key = key
        self.isPressed = isPressed
    }

    var body: some View {
        Text(key)
            .font(WernickeTypography.caption2MediumMono)
            .foregroundStyle(isPressed ? V4Color.accent : V4Color.textPrimary)
            .padding(.horizontal, ParietalSpacing.xs + 2)
            .padding(.vertical, ParietalSpacing.xs)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isPressed ? V4Color.accent.opacity(V2Depth.bgSidebarHover) : V4Color.border)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(V4Color.border, lineWidth: isPressed ? 0 : 1)
            )
    }
}

// MARK: - Keyboard Shortcut Recorder

struct ShortcutRecorder: View {
    @Binding var shortcut: KeyboardShortcut?
    let isRecording: Binding<Bool>
    let clearable: Bool

    init(
        shortcut: Binding<KeyboardShortcut?>,
        isRecording: Binding<Bool>,
        clearable: Bool = true
    ) {
        self._shortcut = shortcut
        self.isRecording = isRecording
        self.clearable = clearable
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            if let shortcut = shortcut {
                KeyboardShortcutDisplay(shortcut: shortcut)

                if clearable {
                    Button {
                        self.shortcut = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(WernickeTypography.size14)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .buttonStyle(.plain)
                }
            } else if isRecording.wrappedValue {
                recordingPlaceholder
            } else {
                recordButton
            }
        }
    }

    private var recordingPlaceholder: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            ProgressView()
                .scaleEffect(0.7)

            Text("Recording...")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            Button("Cancel") {
                isRecording.wrappedValue = false
            }
            .buttonStyle(.plain)
        }
    }

    private var recordButton: some View {
        Button {
            isRecording.wrappedValue = true
        } label: {
            Text("Record Shortcut")
                .font(.caption)
                .foregroundStyle(V4Color.accent)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Shortcut List Item

struct ShortcutListItem: View {
    let title: String
    let shortcut: KeyboardShortcut
    let isEnabled: Bool
    let onToggle: ((Bool) -> Void)?
    let onChangeShortcut: (() -> Void)?

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            Text(title)
                .font(WernickeTypography.size13)
                .foregroundStyle(isEnabled ? V4Color.textPrimary : V4Color.textSecondary)

            Spacer()

            if let onChangeShortcut = onChangeShortcut {
                Button {
                    onChangeShortcut()
                } label: {
                    KeyboardShortcutDisplay(shortcut: shortcut)
                        .opacity(isEnabled ? 1 : 0.5)
                }
                .buttonStyle(.plain)
                .disabled(!isEnabled)
            } else {
                KeyboardShortcutDisplay(shortcut: shortcut)
                    .opacity(isEnabled ? 1 : 0.5)
            }

            if let onToggle = onToggle {
                Toggle("", isOn: Binding(
                    get: { isEnabled },
                    set: onToggle
                ))
                .toggleStyle(.switch)
            }
        }
    }
}

// MARK: - Shortcut Group

struct ShortcutGroup: View {
    let title: String
    let shortcuts: [ShortcutItem]

    struct ShortcutItem: Identifiable {
        let id = UUID()
        let title: String
        let shortcut: KeyboardShortcut
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text(title)
                .font(WernickeTypography.miniSemibold)
                .foregroundStyle(V4Color.textSecondary)
                .padding(.horizontal, ParietalSpacing.xs)

            VStack(spacing: 0) {
                ForEach(Array(shortcuts.enumerated()), id: \.element.id) { index, item in
                    ShortcutRow(item: item)

                    if index < shortcuts.count - 1 {
                        Divider()
                            .padding(.leading, 16)
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(V4Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(V4Color.border, lineWidth: 1)
            )
        }
    }
}

// MARK: - Shortcut Row

struct ShortcutRow: View {
    let item: ShortcutGroup.ShortcutItem

    var body: some View {
        HStack {
            Text(item.title)
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textPrimary)

            Spacer()

            KeyboardShortcutDisplay(shortcut: item.shortcut)
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm)
    }
}

// MARK: - Command Palette Trigger

struct CommandPaletteTrigger: View {
    let shortcut: KeyboardShortcut
    let onTrigger: () -> Void

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            Text("Command Palette")
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textSecondary)

            KeyboardShortcutDisplay(shortcut: shortcut)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture {
            onTrigger()
        }
    }
}

// MARK: - Key Equivalent

enum ShortcutKey: Equatable {
    case space, enterKey, tab, delete, escape
    case upArrow, downArrow, leftArrow, rightArrow
    case home, end, pageUp, pageDown
    case character(String)

    static func == (lhs: ShortcutKey, rhs: ShortcutKey) -> Bool {
        switch (lhs, rhs) {
        case (.space, .space), (.enterKey, .enterKey), (.tab, .tab),
             (.delete, .delete), (.escape, .escape),
             (.upArrow, .upArrow), (.downArrow, .downArrow),
             (.leftArrow, .leftArrow), (.rightArrow, .rightArrow),
             (.home, .home), (.end, .end),
             (.pageUp, .pageUp), (.pageDown, .pageDown):
            return true
        case (.character(let l), .character(let r)):
            return l == r
        default:
            return false
        }
    }
}

// MARK: - Keyboard Shortcut Model

struct KeyboardShortcut: Equatable {
    let modifiers: EventModifiers?
    let key: ShortcutKey?

    init(modifiers: EventModifiers? = nil, key: ShortcutKey? = nil) {
        self.modifiers = modifiers
        self.key = key
    }

    static let commandK = KeyboardShortcut(modifiers: .command, key: .character("k"))
    static let commandSlash = KeyboardShortcut(modifiers: [.command, .shift], key: .character("/"))
    static let commandN = KeyboardShortcut(modifiers: .command, key: .character("n"))
    static let commandW = KeyboardShortcut(modifiers: .command, key: .character("w"))

    static func == (lhs: KeyboardShortcut, rhs: KeyboardShortcut) -> Bool {
        lhs.modifiers == rhs.modifiers && lhs.key == rhs.key
    }
}

// MARK: - Preview

struct KeyboardShortcutView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
                KeyboardShortcutDisplay(shortcut: .commandK)

                ShortcutGroup(
                    title: "File",
                    shortcuts: [
                        ShortcutGroup.ShortcutItem(title: "New", shortcut: .commandN),
                        ShortcutGroup.ShortcutItem(title: "Close", shortcut: .commandW),
                        ShortcutGroup.ShortcutItem(title: "Search", shortcut: .commandSlash)
                    ]
                )

                ShortcutListItem(
                    title: "Enable Command Palette",
                    shortcut: .commandK,
                    isEnabled: true,
                    onToggle: nil,
                    onChangeShortcut: nil
                )
            }
            .padding()
        }
        .padding()
        .background(V4Color.background)
    }
}
