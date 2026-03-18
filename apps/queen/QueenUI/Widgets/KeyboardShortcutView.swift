// Keyboard Shortcut View — Shortcut Display and Recording
import SwiftUI

// MARK: - Keyboard Shortcut Display

struct KeyboardShortcutDisplay: View {
    let shortcut: KeyboardShortcut

    var body: some View {
        HStack(spacing: 4) {
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
            .font(.system(size: 11, weight: .medium, design: .monospaced))
            .foregroundStyle(isPressed ? TrinityTheme.accent : TrinityTheme.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isPressed ? TrinityTheme.accent.opacity(0.15) : TrinityTheme.bgCardBorder)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: isPressed ? 0 : 1)
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
        HStack(spacing: 8) {
            if let shortcut = shortcut {
                KeyboardShortcutDisplay(shortcut: shortcut)

                if clearable {
                    Button {
                        self.shortcut = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(TrinityTheme.textMuted)
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
        HStack(spacing: 6) {
            ProgressView()
                .scaleEffect(0.7)

            Text("Recording...")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)

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
                .foregroundStyle(TrinityTheme.accent)
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
        HStack(spacing: 12) {
            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(isEnabled ? TrinityTheme.textPrimary : TrinityTheme.textMuted)

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
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TrinityTheme.textMuted)
                .padding(.horizontal, 4)

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
                    .fill(TrinityTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
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
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textPrimary)

            Spacer()

            KeyboardShortcutDisplay(shortcut: item.shortcut)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }
}

// MARK: - Command Palette Trigger

struct CommandPaletteTrigger: View {
    let shortcut: KeyboardShortcut
    let onTrigger: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Text("Command Palette")
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textMuted)

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
            VStack(alignment: .leading, spacing: 16) {
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
        .background(TrinityTheme.bgWindow)
    }
}
