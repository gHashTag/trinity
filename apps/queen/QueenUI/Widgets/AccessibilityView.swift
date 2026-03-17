import SwiftUI

// MARK: - Accessibility Settings View

struct AccessibilitySettingsView: View {
    @AppStorage("reduceMotion") private var reduceMotion = false
    @AppStorage("highContrast") private var highContrast = false
    @AppStorage("fontSize") private var fontSize: Double = 16
    @AppStorage("voiceOverEnabled") private var voiceOverEnabled = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Accessibility")
                .font(.headline)
                .foregroundStyle(TrinityTheme.textPrimary)

            VStack(spacing: 16) {
                accessibilityToggle(
                    title: "Reduce Motion",
                    icon: "tortoise.fill",
                    description: "Minimize animations throughout the app",
                    isOn: $reduceMotion
                )

                accessibilityToggle(
                    title: "High Contrast",
                    icon: "circle.lefthalf.filled",
                    description: "Increase contrast for better visibility",
                    isOn: $highContrast
                )

                accessibilityToggle(
                    title: "VoiceOver",
                    icon: "eye.fill",
                    description: "Optimize for screen reader",
                    isOn: $voiceOverEnabled
                )

                fontSizeSlider
            }
        }
        .padding()
    }

    private func accessibilityToggle(
        title: String,
        icon: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(TrinityTheme.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Text(description)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            Spacer()

            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerSmall)
    }

    private var fontSizeSlider: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "textformat.size")
                    .font(.title3)
                    .foregroundStyle(TrinityTheme.accent)

                Text("Font Size")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Spacer()

                Text("\(Int(fontSize))pt")
                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            HStack(spacing: 12) {
                Text("A")
                    .font(.system(size: 12))
                    .foregroundStyle(TrinityTheme.textMuted)

                Slider(value: $fontSize, in: 12...24, step: 1)
                    .tint(TrinityTheme.accent)

                Text("A")
                    .font(.system(size: 20))
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerSmall)
    }
}

// MARK: - Keyboard Shortcuts Panel

struct KeyboardShortcutsPanel: View {
    @State private var selectedCategory: ShortcutCategory = .general

    enum ShortcutCategory: String, CaseIterable {
        case general = "General"
        case navigation = "Navigation"
        case editing = "Editing"
        case messages = "Messages"
    }

    private var shortcuts: [Shortcut] {
        switch selectedCategory {
        case .general:
            return [
                Shortcut(title: "New Thread", keys: ["⌘", "N"]),
                Shortcut(title: "Search", keys: ["⌘", "F"]),
                Shortcut(title: "Settings", keys: ["⌘", ","]),
                Shortcut(title: "Focus Mode", keys: ["⌘", "⇧", "F"])
            ]
        case .navigation:
            return [
                Shortcut(title: "Previous Thread", keys: ["⌘", "["]),
                Shortcut(title: "Next Thread", keys: ["⌘", "]"]),
                Shortcut(title: "Jump to Top", keys: ["⌘", "↑"]),
                Shortcut(title: "Jump to Bottom", keys: ["⌘", "↓"])
            ]
        case .editing:
            return [
                Shortcut(title: "Bold", keys: ["⌘", "B"]),
                Shortcut(title: "Italic", keys: ["⌘", "I"]),
                Shortcut(title: "Code", keys: ["⌘", "K"]),
                Shortcut(title: "Link", keys: ["⌘", "U"])
            ]
        case .messages:
            return [
                Shortcut(title: "New Message", keys: ["⌘", "⏎"]),
                Shortcut(title: "Reply", keys: ["⌘", "R"]),
                Shortcut(title: "Forward", keys: ["⌘", "⇧", "F"]),
                Shortcut(title: "Delete", keys: ["⌫"])
            ]
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Category picker
            Picker("Category", selection: $selectedCategory) {
                ForEach(ShortcutCategory.allCases, id: \.self) { category in
                    Text(category.rawValue).tag(category)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            Divider()
                .background(TrinityTheme.bgCardBorder)

            // Shortcuts list
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(shortcuts.indices, id: \.self) { index in
                        shortcutRow(shortcuts[index])
                            .padding(.horizontal, 16)
                            .padding(.vertical, 10)
                            .background(index % 2 == 0 ? TrinityTheme.bgCard.opacity(0.5) : Color.clear)

                        if index < shortcuts.count - 1 {
                            Divider()
                                .background(TrinityTheme.bgCardBorder)
                                .padding(.leading, 60)
                        }
                    }
                }
            }
        }
        .frame(height: 300)
        .background(TrinityTheme.bgWindow)
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }

    private func shortcutRow(_ shortcut: Shortcut) -> some View {
        HStack {
            Text(shortcut.title)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textPrimary)

            Spacer()

            HStack(spacing: 4) {
                ForEach(shortcut.keys, id: \.self) { key in
                    keyCap(key)
                }
            }
        }
    }

    private func keyCap(_ key: String) -> some View {
        Text(key)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(TrinityTheme.textPrimary)
            .padding(.horizontal, 6)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(TrinityTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 4)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
            )
    }
}

// MARK: - Shortcut Model

struct Shortcut {
    let title: String
    let keys: [String]
}

// MARK: - Color Blindness Simulator

struct ColorBlindnessSimulator: View {
    @State private var selectedType: ColorBlindnessType?

    enum ColorBlindnessType: String, CaseIterable {
        case none = "None"
        case protanopia = "Protanopia"
        case deuteranopia = "Deuteranopia"
        case tritanopia = "Tritanopia"
        case achromatopsia = "Achromatopsia"

        var filter: ColorMatrix {
            switch self {
            case .none: return ColorMatrix.identity
            case .protanopia: return ColorMatrix(
                r: (0.567, 0.433, 0),
                g: (0.558, 0.442, 0),
                b: (0.242, 0.758, 0)
            )
            case .deuteranopia: return ColorMatrix(
                r: (0.625, 0.375, 0),
                g: (0.7, 0.3, 0),
                b: (0.3, 0.7, 0)
            )
            case .tritanopia: return ColorMatrix(
                r: (0.95, 0.05, 0),
                g: (0, 0.433, 0.567),
                b: (0, 0.475, 0.525)
            )
            case .achromatopsia: return ColorMatrix.grayscale
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Color Blindness Simulator")
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)

            HStack(spacing: 8) {
                ForEach(ColorBlindnessType.allCases, id: \.self) { type in
                    typeButton(type)
                }
            }

            // Preview area
            if let type = selectedType {
                previewArea(type)
            }
        }
    }

    private func typeButton(_ type: ColorBlindnessType) -> some View {
        Button {
            selectedType = type == selectedType ? nil : type
        } label: {
            Text(type.rawValue)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(selectedType == type ? TrinityTheme.accent : TrinityTheme.bgCard)
                .foregroundStyle(selectedType == type ? .white : TrinityTheme.textMuted)
                .cornerRadius(4)
        }
        .buttonStyle(.plain)
    }

    private func previewArea(_ type: ColorBlindnessType) -> some View {
        VStack(spacing: 8) {
            testColorStrip
            testPattern

            Text("Note: Actual color filtering requires Metal shaders")
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerSmall)
    }

    private var testColorStrip: some View {
        HStack(spacing: 0) {
            ForEach([Color.red, .green, .blue, .yellow, .purple], id: \.description) { color in
                Rectangle()
                    .fill(color)
                    .frame(height: 30)
            }
        }
    }

    private var testPattern: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Circle().fill(TrinityTheme.accent).frame(width: 20, height: 20)
                Circle().fill(TrinityTheme.purple).frame(width: 20, height: 20)
                Circle().fill(TrinityTheme.golden).frame(width: 20, height: 20)
            }
            Text("Test Pattern: Red Green Blue Purple Gold")
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)
        }
    }
}

// MARK: - Color Matrix

struct ColorMatrix {
    let r: (Double, Double, Double)
    let g: (Double, Double, Double)
    let b: (Double, Double, Double)

    static let identity = ColorMatrix(
        r: (1, 0, 0),
        g: (0, 1, 0),
        b: (0, 0, 1)
    )

    static let grayscale = ColorMatrix(
        r: (0.299, 0.587, 0.114),
        g: (0.299, 0.587, 0.114),
        b: (0.299, 0.587, 0.114)
    )
}

// MARK: - Large Text Mode

struct LargeTextModeView: View {
    @Binding var isEnabled: Bool
    @Binding var textScale: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Toggle("Large Text Mode", isOn: $isEnabled)
                .font(.system(size: isEnabled ? 18 : 14))

            if isEnabled {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Text Scale: \(Int(textScale * 100))%")
                        .font(.system(size: 16))

                    Slider(value: $textScale, in: 1.0...2.0, step: 0.1)
                        .tint(TrinityTheme.accent)
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .cornerRadius(TrinityTheme.cornerSmall)
            }
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
    }
}

// MARK: - Screen Reader Announcement

struct ScreenReaderAnnouncer {
    static func announce(_ message: String) {
        // Post accessibility announcement via NotificationCenter
        // Note: Full VoiceOver integration requires NSAccessibilityProtocol
        NotificationCenter.default.post(
            name: Notification.Name("AccessibilityAnnouncement"),
            object: nil,
            userInfo: ["message": message]
        )
    }

    static func announce(_ message: String, priority: String) {
        // Higher priority announcement
        announce(message)
    }
}

// MARK: - Preview

struct AccessibilityView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            AccessibilitySettingsView()
                .frame(width: 400)

            KeyboardShortcutsPanel()
                .frame(width: 350)

            ColorBlindnessSimulator()
                .frame(width: 400)
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
