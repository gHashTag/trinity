// Themeable View — Theme Support Components
import SwiftUI

// MARK: - Themeable Container

struct ThemeableContainer<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .background(TrinityTheme.bgWindow)
    }
}

// MARK: - Theme Switcher

struct ThemeSwitcher: View {
    @AppStorage("appearanceMode") private var appearanceMode: String = "auto"

    enum AppearanceMode: String, CaseIterable {
        case light, dark, auto

        var icon: String {
            switch self {
            case .light: return "sun.max.fill"
            case .dark: return "moon.fill"
            case .auto: return "circle.lefthalf.filled"
            }
        }

        var displayName: String {
            switch self {
            case .light: return "Light"
            case .dark: return "Dark"
            case .auto: return "Auto"
            }
        }
    }

    var body: some View {
        Picker("Appearance", selection: $appearanceMode) {
            ForEach(AppearanceMode.allCases, id: \.rawValue) { mode in
                Label(mode.displayName, systemImage: mode.icon)
                    .tag(mode.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 200)
    }
}

// MARK: - Accent Color Picker

struct AccentColorPicker: View {
    @AppStorage("accentColor") private var accentColorHex: String = "00D9FF"

    private var accentColor: Color {
        Color(hex: Int(accentColorHex, radix: 16) ?? 0x00D9FF)
    }

    let colors: [Color] = [
        Color(hex: 0x00D9FF), // Cyan
        Color(hex: 0x5AC8FA), // Blue
        Color(hex: 0x007AFF), // systemBlue
        Color(hex: 0x5856D6), // Purple
        Color(hex: 0xAF52DE), // Pink
        Color(hex: 0xFF2D55), // Red
        Color(hex: 0xFF9500), // Orange
        Color(hex: 0xFFCC00), // Yellow
        Color(hex: 0x34C759), // Green
        Color(hex: 0x30B0C7), // Teal
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Accent Color")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TrinityTheme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 10) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    colorButton(color: color, isSelected: color == accentColor) {
                        if let hex = color.toHex() {
                            accentColorHex = hex
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }

    private func colorButton(color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: 36)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? .white : Color.clear, lineWidth: 2)
                )
                .shadow(color: isSelected ? color.opacity(0.5) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Font Size Picker

struct FontSizePicker: View {
    @AppStorage("fontSize") private var fontSize: Double = 14

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Font Size")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TrinityTheme.textPrimary)

            HStack {
                Text("A")
                    .font(.system(size: 11))
                    .foregroundStyle(TrinityTheme.textMuted)

                Slider(value: $fontSize, in: 10...20, step: 1)
                    .tint(TrinityTheme.accent)

                Text("A")
                    .font(.system(size: 20))
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            Text("\(Int(fontSize))pt")
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let title: String
    let message: String
    let actionTitle: String

    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textMuted)

            HStack(spacing: 12) {
                Button("Cancel") {}
                    .buttonStyle(.bordered)

                Button(actionTitle) {}
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Reduce Motion Option

struct ReduceMotionOption: View {
    @AppStorage("reduceMotion") private var reduceMotion = false

    var body: some View {
        Toggle("Reduce Motion", isOn: $reduceMotion)
            .font(.system(size: 13))
            .toggleStyle(.switch)
    }
}

// MARK: - High Contrast Option

struct HighContrastOption: View {
    @AppStorage("highContrast") private var highContrast = false

    var body: some View {
        Toggle("High Contrast", isOn: $highContrast)
            .font(.system(size: 13))
            .toggleStyle(.switch)
    }
}

// MARK: - Theme Settings Panel

struct ThemeSettingsPanel: View {
    @State private var selectedTab: SettingsTab = .general

    enum SettingsTab: String, CaseIterable {
        case general, colors, typography

        var icon: String {
            switch self {
            case .general: return "paintbrush"
            case .colors: return "palette"
            case .typography: return "textformat"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            TabPicker(selection: $selectedTab, tabs: SettingsTab.allCases)

            Divider()

            switch selectedTab {
            case .general:
                generalSettings
            case .colors:
                colorSettings
            case .typography:
                typographySettings
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            ThemeSwitcher()
            ReduceMotionOption()
            HighContrastOption()
        }
    }

    private var colorSettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            AccentColorPicker()
        }
    }

    private var typographySettings: some View {
        VStack(alignment: .leading, spacing: 20) {
            FontSizePicker()
        }
    }
}

// MARK: - Tab Picker

struct TabPicker: View {
    @Binding var selection: ThemeSettingsPanel.SettingsTab
    let tabs: [ThemeSettingsPanel.SettingsTab]

    init(selection: Binding<ThemeSettingsPanel.SettingsTab>, tabs: [ThemeSettingsPanel.SettingsTab]) {
        self._selection = selection
        self.tabs = tabs
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(tabs, id: \.self) { tab in
                Button {
                    withAnimation {
                        selection = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12))
                        Text(tab.rawValue.capitalized)
                            .font(.system(size: 12))
                    }
                    .foregroundStyle(selection == tab ? TrinityTheme.accent : TrinityTheme.textMuted)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selection == tab ? TrinityTheme.accent.opacity(0.15) : Color.clear)
                    )
                }
                .buttonStyle(.plain)

                if tab != tabs.last {
                    Divider()
                        .frame(height: 20)
                }
            }
        }
    }
}

// MARK: - Color Extension

extension Color {
    init(hex: Int) {
        let red = Double((hex >> 16) & 0xFF) / 255
        let green = Double((hex >> 8) & 0xFF) / 255
        let blue = Double(hex & 0xFF) / 255
        self.init(red: red, green: green, blue: blue)
    }

    func toHex() -> String? {
        #if os(iOS)
        guard let components = UIColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        #else
        guard let components = NSColor(self).cgColor.components, components.count >= 3 else {
            return nil
        }
        #endif
        let r = Int(components[0] * 255)
        let g = Int(components[1] * 255)
        let b = Int(components[2] * 255)
        return String(format: "%02X%02X%02X", r, g, b)
    }
}

// MARK: - Preview

struct ThemeableView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ThemeSettingsPanel()
                .frame(width: 400)

            ThemePreviewCard(
                title: "Theme Preview",
                message: "This is how the theme looks",
                actionTitle: "Save"
            )
            .frame(width: 300)
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
