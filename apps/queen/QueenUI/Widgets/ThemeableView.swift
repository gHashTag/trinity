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
            .background(V4Color.background)
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
        .frame(width: ParietalSpacing.xl * 8)
    }
}

// MARK: - Accent Color Picker

struct AccentColorPicker: View {
    @AppStorage("accentColor") private var accentColorHex: String = "00D9FF"

    private var accentColor: Color {
        Color(hex: Int(accentColorHex, radix: 16) ?? 0x00D9FF)
    }

    let colors: [Color] = [
        V4Color.info, // Cyan
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
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            Text("Accent Color")
                .font(WernickeTypography.smallMedium)
                .foregroundStyle(V4Color.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: ParietalSpacing.sm + 2) {
                ForEach(Array(colors.enumerated()), id: \.offset) { index, color in
                    colorButton(color: color, isSelected: color == accentColor) {
                        if let hex = color.toHex() {
                            accentColorHex = hex
                        }
                    }
                }
            }
        }
        .padding(ParietalSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }

    private func colorButton(color: Color, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button {
            action()
        } label: {
            RoundedRectangle(cornerRadius: 8)
                .fill(color)
                .frame(height: ParietalSpacing.buttonHeight)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? .white : Color.clear, lineWidth: 2)
                )
                .shadow(color: isSelected ? color.opacity(V2Depth.stateDisabled) : .clear, radius: 4)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Font Size Picker

struct FontSizePicker: View {
    @AppStorage("fontSize") private var fontSize: Double = 14

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            Text("Font Size")
                .font(WernickeTypography.smallMedium)
                .foregroundStyle(V4Color.textPrimary)

            HStack {
                Text("A")
                    .font(WernickeTypography.size11)
                    .foregroundStyle(V4Color.textSecondary)

                Slider(value: $fontSize, in: 10...20, step: 1)
                    .tint(V4Color.accent)

                Text("A")
                    .font(WernickeTypography.size20)
                    .foregroundStyle(V4Color.textSecondary)
            }

            Text("\(Int(fontSize))pt")
                .font(WernickeTypography.size12)
                .foregroundStyle(V4Color.textSecondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(ParietalSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let title: String
    let message: String
    let actionTitle: String

    var body: some View {
        VStack(spacing: ParietalSpacing.md) {
            Text(title)
                .font(WernickeTypography.body16Medium)
                .foregroundStyle(V4Color.textPrimary)

            Text(message)
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textSecondary)

            HStack(spacing: ParietalSpacing.md) {
                Button("Cancel") {}
                    .buttonStyle(.bordered)

                Button(actionTitle) {}
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding(ParietalSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Reduce Motion Option

struct ReduceMotionOption: View {
    @AppStorage("reduceMotion") private var reduceMotion = false

    var body: some View {
        Toggle("Reduce Motion", isOn: $reduceMotion)
            .font(WernickeTypography.size13)
            .toggleStyle(.switch)
    }
}

// MARK: - High Contrast Option

struct HighContrastOption: View {
    @AppStorage("highContrast") private var highContrast = false

    var body: some View {
        Toggle("High Contrast", isOn: $highContrast)
            .font(WernickeTypography.size13)
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
        .padding(ParietalSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }

    private var generalSettings: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md + ParietalSpacing.md) {
            ThemeSwitcher()
            ReduceMotionOption()
            HighContrastOption()
        }
    }

    private var colorSettings: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md + ParietalSpacing.md) {
            AccentColorPicker()
        }
    }

    private var typographySettings: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md + ParietalSpacing.md) {
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
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        Image(systemName: tab.icon)
                            .font(WernickeTypography.size12)
                        Text(tab.rawValue.capitalized)
                            .font(WernickeTypography.size12)
                    }
                    .foregroundStyle(selection == tab ? V4Color.accent : V4Color.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, ParietalSpacing.sm)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(selection == tab ? V4Color.accent.opacity(V2Depth.bgSidebarHover) : Color.clear)
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
                .frame(width: ParietalSpacing.xl * 16)

            ThemePreviewCard(
                title: "Theme Preview",
                message: "This is how the theme looks",
                actionTitle: "Save"
            )
            .frame(width: ParietalSpacing.xl * 12)
        }
        .padding()
        .background(V4Color.background)
    }
}
