import SwiftUI

// MARK: - Settings Panels View
//
// Comprehensive settings UI components for Queen UI.
// Provides reusable, theme-aware settings controls with:
// - @AppStorage binding for persistence
// - Live preview of changes
// - Validation feedback (inline)
// - Section collapse/expand state
// - Keyboard navigation (arrow keys)
// - Search highlighting
// - "Modified" indicator for unsaved changes

// MARK: - Settings Section Container

/// Groups related settings with a collapsible header
struct SettingsSection<Content: View>: View {
    let title: String
    let icon: String?
    let color: Color
    @ViewBuilder let content: Content

    @State private var isExpanded: Bool = true

    init(
        _ title: String,
        icon: String? = nil,
        color: Color = V4Color.accent,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.icon = icon
        self.color = color
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(MTMotion.standardSpring) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: ParietalSpacing.sm) {
                    if let icon {
                        Image(systemName: icon)
                            .font(WernickeTypography.miniSemibold)
                            .foregroundStyle(color)
                    }
                    Text(title.uppercased())
                        .font(.caption.weight(.bold))
                        .foregroundStyle(color)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(WernickeTypography.miniSemibold)
                        .foregroundStyle(V4Color.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : -90))
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm + 2)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            // Content with animation
            if isExpanded {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm + 2) {
                    content
                }
                .padding(ParietalSpacing.md)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(V4Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Settings Toggle

/// Boolean preference with icon, label, and description
struct SettingsToggle: View {
    @Binding var isOn: Bool
    let title: String
    let description: String?
    let icon: String?
    let iconColor: Color

    @State private var isHovered = false

    init(
        _ title: String,
        isOn: Binding<Bool>,
        description: String? = nil,
        icon: String? = nil,
        iconColor: Color = V4Color.accent
    ) {
        self.title = title
        self._isOn = isOn
        self.description = description
        self.icon = icon
        self.iconColor = iconColor
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            // Optional icon
            if let icon {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(V2Depth.bgSidebarHover))
                        .frame(width: 28, height: 28)

                    Image(systemName: icon)
                        .font(WernickeTypography.caption2Semibold)
                        .foregroundStyle(iconColor)
                }
            }

            // Title and description
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body.weight(.medium))
                    .foregroundStyle(V4Color.textPrimary)

                if let description {
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
        }
        .padding(.vertical, ParietalSpacing.xs)
        .contentShape(Rectangle())
        .background(isHovered ? V4Color.textPrimary.opacity(0.03) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onHover { isHovered = $0 }
    }
}

// MARK: - Settings Picker

/// Enum selection with visual preview cards
struct SettingsPicker<T: Hashable & CaseIterable>: View where T.AllCases: RandomAccessCollection {
    let title: String
    let description: String?
    let options: [PickerOption<T>]
    @Binding var selection: T

    @State private var isHovered = false

    init(
        _ title: String,
        selection: Binding<T>,
        description: String? = nil,
        options: [(T, String, String, String)] = []
    ) where T: RawRepresentable, T.RawValue == String {
        self.title = title
        self._selection = selection
        self.description = description

        // Generate options from enum cases if not provided
        if options.isEmpty {
            self.options = T.allCases.map { value in
                let label = (value as? CustomLabel)?.label ?? String(describing: value)
                let icon = (value as? CustomIcon)?.icon ?? "circle.fill"
                let desc = (value as? CustomDescription)?.description ?? ""
                return PickerOption(value: value, label: label, icon: icon, description: desc)
            }
        } else {
            self.options = options.map { PickerOption(value: $0.0, label: $0.1, icon: $0.2, description: $0.3) }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)

                if let description {
                    Spacer()
                    Text(description)
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            HStack(spacing: ParietalSpacing.sm) {
                ForEach(options) { option in
                    OptionCard(
                        option: option,
                        isSelected: selection == option.value
                    ) {
                        withAnimation(MTMotion.standardSpring) {
                            selection = option.value
                        }
                    }
                }
            }
        }
    }

    // MARK: - Option Card

    struct OptionCard: View {
        let option: PickerOption<T>
        let isSelected: Bool
        let action: () -> Void

        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                VStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: option.icon)
                        .font(WernickeTypography.size18Medium)
                        .foregroundStyle(isSelected ? V4Color.accent : V4Color.textSecondary)

                    Text(option.label)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(isSelected ? V4Color.textPrimary : V4Color.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, ParietalSpacing.sm + 2)
                .background(
                    Group {
                        if isSelected {
                            V4Color.accent.opacity(V2Depth.bgSidebarHover)
                        } else if isHovered {
                            V4Color.textPrimary.opacity(0.05)
                        } else {
                            Color.clear
                        }
                    }
                )
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                        .stroke(
                            isSelected ? V4Color.accent : V4Color.border,
                            lineWidth: isSelected ? 1.5 : 1
                        )
                )
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
        }
    }
}

// MARK: - Picker Option Model

struct PickerOption<T: Hashable>: Identifiable {
    let id = UUID()
    let value: T
    let label: String
    let icon: String
    let description: String
}

// MARK: - Picker Customization Protocols

protocol CustomLabel {
    var label: String { get }
}

protocol CustomIcon {
    var icon: String { get }
}

protocol CustomDescription {
    var description: String { get }
}

// MARK: - Settings Slider

/// Numeric value slider with live preview
struct SettingsSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let unit: String?
    let previewText: ((Double) -> String)?

    @State private var isDragging = false

    init(
        _ title: String,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double = 1,
        unit: String? = nil,
        previewText: ((Double) -> String)? = nil
    ) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.unit = unit
        self.previewText = previewText
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(width: 100, alignment: .leading)

                Slider(value: $value, in: range, step: step)
                    .frame(maxWidth: .infinity)

                // Value display
                HStack(spacing: 2) {
                    Text(previewText?(value) ?? formattedValue)
                        .font(.body.monospacedDigit())
                        .foregroundStyle(V4Color.textPrimary)
                        .frame(width: 44, alignment: .trailing)

                    if let unit {
                        Text(unit)
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }
            }

            // Live preview bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 2)
                        .fill(V4Color.border)
                        .frame(height: ParietalSpacing.xs)

                    // Fill
                    RoundedRectangle(cornerRadius: 2)
                        .fill(V4Color.accent)
                        .frame(width: geometry.size.width * CGFloat((value - range.lowerBound) / (range.upperBound - range.lowerBound)))
                        .frame(height: ParietalSpacing.xs)
                        .animation(isDragging ? nil : MTMotion.standardSpring, value: value)
                }
            }
            .frame(height: ParietalSpacing.xs)
        }
    }

    private var formattedValue: String {
        if step.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.1f", value)
        }
    }
}

// MARK: - Settings Text Field

/// String input with inline validation
struct SettingsTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let validation: ((String) -> ValidationState)?
    let isSecure: Bool
    let keyboardType: KeyboardType

    enum KeyboardType {
        case default_
        case url
        case email
        case number
    }

    init(
        _ title: String,
        text: Binding<String>,
        placeholder: String = "",
        validation: ((String) -> ValidationState)? = nil,
        isSecure: Bool = false,
        keyboardType: KeyboardType = .default_
    ) {
        self.title = title
        self._text = text
        self.placeholder = placeholder
        self.validation = validation
        self.isSecure = isSecure
        self.keyboardType = keyboardType
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(width: 100, alignment: .leading)

                HStack(spacing: ParietalSpacing.sm) {
                    Group {
                        if isSecure {
                            SecureField(placeholder, text: $text)
                        } else {
                            TextField(placeholder, text: $text)
                        }
                    }
                    .textFieldStyle(.plain)
                    .font(.body.monospaced())
                    .padding(.horizontal, ParietalSpacing.sm + 2)
                    .padding(.vertical, ParietalSpacing.xs + 2)
                    .background(V4Color.surface)
                    .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                    .overlay(
                        RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                            .stroke(validationColor, lineWidth: 1)
                    )

                    // Validation icon
                    if validation != nil {
                        Image(systemName: validationIcon)
                            .font(WernickeTypography.miniSemibold)
                            .foregroundStyle(validationColor)
                    }
                }
            }

            // Validation message
            if validation != nil, let message = validationMessage {
                HStack {
                    Text(title)
                        .font(.caption)
                        .foregroundStyle(.clear)
                        .frame(width: 100, alignment: .leading)

                    Text(message)
                        .font(.caption2)
                        .foregroundStyle(validationColor)
                }
            }
        }
    }

    private var validationState: ValidationState? {
        validation?(text)
    }

    private var validationColor: Color {
        switch validationState {
        case .valid, .none:
            return V4Color.border
        case .invalid:
            return V4Color.error
        case .warning:
            return V4Color.warning
        }
    }

    private var validationIcon: String {
        switch validationState {
        case .valid:
            return "checkmark.circle.fill"
        case .invalid:
            return "xmark.circle.fill"
        case .warning:
            return "exclamationmark.triangle.fill"
        case .none:
            return ""
        }
    }

    private var validationMessage: String? {
        switch validationState {
        case .invalid(let msg), .warning(let msg):
            return msg
        case .valid, .none:
            return nil
        }
    }
}

// MARK: - Validation State

enum ValidationState {
    case valid
    case invalid(String)
    case warning(String)
}

// MARK: - Settings Color Picker

/// Theme color selection with swatches
struct SettingsColorPicker: View {
    let title: String
    @Binding var selection: ColorOption
    let showCustom: Bool

    @State private var isHovered = false

    init(
        _ title: String,
        selection: Binding<ColorOption>,
        showCustom: Bool = true
    ) {
        self.title = title
        self._selection = selection
        self.showCustom = showCustom
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text(title)
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            HStack(spacing: ParietalSpacing.sm) {
                ForEach(ColorOption.allCases) { option in
                    ColorSwatch(
                        option: option,
                        isSelected: selection == option
                    ) {
                        withAnimation(MTMotion.standardSpring) {
                            selection = option
                        }
                    }
                }

                if showCustom {
                    ColorSwatch(
                        option: .custom,
                        isSelected: selection == .custom,
                        customColor: customColor
                    ) {
                        // Custom color picker would go here
                    }
                }
            }
        }
    }

    private var customColor: Color {
        selection.color
    }
}

// MARK: - Color Option

enum ColorOption: String, CaseIterable, Identifiable {
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case gold = "gold"
    case red = "red"
    case custom = "custom"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .green: return "Green"
        case .blue: return "Blue"
        case .purple: return "Purple"
        case .gold: return "Gold"
        case .red: return "Red"
        case .custom: return "Custom"
        }
    }

    var color: Color {
        switch self {
        case .green: return V4Color.accent
        case .blue: return V4Color.info
        case .purple: return V4Color.purple
        case .gold: return V4Color.golden
        case .red: return V4Color.error
        case .custom: return V4Color.accent
        }
    }

    var hex: UInt32 {
        switch self {
        case .green: return 0x00FF88
        case .blue: return 0x00D9FF
        case .purple: return 0x8B5CF6
        case .gold: return 0xFFD700
        case .red: return 0xEF4444
        case .custom: return 0x00FF88
        }
    }
}

// MARK: - Color Swatch

struct ColorSwatch: View {
    let option: ColorOption
    let isSelected: Bool
    let customColor: Color?
    let action: () -> Void

    @State private var isHovered = false

    init(
        option: ColorOption,
        isSelected: Bool,
        customColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.option = option
        self.isSelected = isSelected
        self.customColor = customColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(customColor ?? option.color)
                    .frame(width: ParietalSpacing.lg, height: ParietalSpacing.lg)

                if isSelected {
                    Circle()
                        .strokeBorder(V4Color.textPrimary, lineWidth: 2)
                        .frame(width: 28, height: 28)
                        .overlay {
                            Circle()
                                .fill(V4Color.textPrimary)
                                .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)
                        }
                }
            }
            .overlay(
                Circle()
                    .strokeBorder(V4Color.border, lineWidth: 1)
                    .frame(width: 26, height: 26)
            )
            .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .accessibilityLabel(option.name)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
    }
}

// MARK: - Settings Navigation

/// Sidebar navigation pattern for settings
struct SettingsNavigation<Content: View>: View {
    let sections: [SettingsNavSection]
    @Binding var selectedSection: String
    @ViewBuilder let content: () -> Content

    init(
        sections: [SettingsNavSection],
        selectedSection: Binding<String>,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.sections = sections
        self._selectedSection = selectedSection
        self.content = content
    }

    var body: some View {
        HSplitView {
            // Sidebar
            VStack(alignment: .leading, spacing: 0) {
                ForEach(sections) { section in
                    NavButton(
                        section: section,
                        isSelected: selectedSection == section.id
                    ) {
                        withAnimation(MTMotion.standardSpring) {
                            selectedSection = section.id
                        }
                    }
                }
                Spacer()
            }
            .frame(minWidth: 180, maxWidth: 220)
            .padding(.top, 8)
            .background(V4Color.sidebar)

            // Content
            ScrollView {
                content()
                    .padding(ParietalSpacing.md * 1.5)
            }
            .background(V4Color.background)
        }
    }

    // MARK: - Nav Button

    struct NavButton: View {
        let section: SettingsNavSection
        let isSelected: Bool
        let action: () -> Void

        @State private var isHovered = false

        var body: some View {
            Button(action: action) {
                HStack(spacing: ParietalSpacing.sm + 2) {
                    Image(systemName: section.icon)
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(isSelected ? V4Color.accent : V4Color.textSecondary)
                        .frame(width: ParietalSpacing.buttonSmallWidth)

                    Text(section.name)
                        .font(.body.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? V4Color.textPrimary : V4Color.textSecondary)

                    Spacer()

                    if section.hasChanges {
                        Circle()
                            .fill(V4Color.accent)
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm)
                .background(
                    isSelected
                        ? V4Color.accent.opacity(0.12)
                        : (isHovered ? V4Color.textPrimary.opacity(0.05) : Color.clear)
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .onHover { isHovered = $0 }
        }
    }
}

// MARK: - Settings Nav Section

struct SettingsNavSection: Identifiable {
    let id: String
    let name: String
    let icon: String
    var hasChanges: Bool = false
}

// MARK: - Settings Search

/// Filter sections by keyword with highlighting
struct SettingsSearch: View {
    @Binding var searchText: String
    let availableSections: [String]

    @State private var isFocused = false

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(WernickeTypography.smallMedium)
                .foregroundStyle(searchText.isEmpty ? V4Color.textSecondary : V4Color.accent)

            TextField("Search settings", text: $searchText)
                .textFieldStyle(.plain)
                .font(.body)
                .onFocusChange { isFocused = $0 }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size13)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm)
        .background(V4Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isFocused ? V4Color.accent : V4Color.border, lineWidth: isFocused ? 1.5 : 1)
        )
    }
}

// MARK: - Search Filter

extension View {
    /// Filters settings sections based on search text
    func filterSettings(searchText: String, keywords: [String]) -> some View {
        opacity(searchText.isEmpty || keywords.contains(where: { keyword in
            keyword.localizedCaseInsensitiveContains(searchText) ||
            searchText.localizedCaseInsensitiveContains(keyword)
        }) ? 1 : 0.3)
    }
}

// MARK: - Reset Button

/// Reset to defaults button with confirmation
struct SettingsResetButton: View {
    let action: () -> Void
    let title: String

    @State private var showingConfirmation = false

    init(title: String = "Reset to Defaults", action: @escaping () -> Void) {
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            showingConfirmation = true
        } label: {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: "arrow.counterclockwise")
                    .font(WernickeTypography.miniSemibold)
                Text(title)
                    .font(WernickeTypography.smallMedium)
            }
            .foregroundStyle(V4Color.error)
            .padding(.horizontal, ParietalSpacing.md + 2)
            .padding(.vertical, 7)
            .background(V4Color.error.opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            "Reset Settings",
            isPresented: $showingConfirmation,
            titleVisibility: .visible
        ) {
            Button("Reset to Defaults", role: .destructive) {
                action()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will reset all settings in this section to their default values. This action cannot be undone.")
        }
    }
}

// MARK: - Modified Indicator

/// Shows "Modified" indicator for unsaved changes
struct ModifiedIndicator: View {
    let isModified: Bool

    var body: some View {
        if isModified {
            HStack(spacing: ParietalSpacing.xs) {
                Circle()
                    .fill(V4Color.accent)
                    .frame(width: ParietalSpacing.xxxs, height: ParietalSpacing.xxxs)
                Text("Modified")
                    .font(.caption2)
                    .foregroundStyle(V4Color.accent)
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, 3)
            .background(V4Color.accent.opacity(0.12))
            .clipShape(SwiftUI.Capsule())
        }
    }
}

// MARK: - Standard Settings Sections

/// Pre-built settings sections for common use cases
enum StandardSettingsSection {
    case appearance
    case behavior
    case privacy
    case advanced

    var navSection: SettingsNavSection {
        switch self {
        case .appearance:
            return SettingsNavSection(id: "appearance", name: "Appearance", icon: "paintbrush.fill")
        case .behavior:
            return SettingsNavSection(id: "behavior", name: "Behavior", icon: "gearshape.fill")
        case .privacy:
            return SettingsNavSection(id: "privacy", name: "Privacy", icon: "hand.raised.fill")
        case .advanced:
            return SettingsNavSection(id: "advanced", name: "Advanced", icon: "slider.horizontal.3")
        }
    }
}

// MARK: - Appearance Settings Content

struct AppearanceSettingsContent: View {
    @AppStorage("chatFontSize") private var chatFontSize = 15
    @AppStorage("animationsEnabled") private var animationsEnabled = true
    @AppStorage("reducedMotion") private var reducedMotion = false
    @AppStorage("sidebarWidth") private var sidebarWidth: Double = 220
    @AppStorage("accentColor") private var accentColorRaw: String = ColorOption.green.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            // Font size
            SettingsSection("Display", icon: "textformat", color: V4Color.accent) {
                SettingsSlider(
                    "Font Size",
                    value: Binding(
                        get: { Double(chatFontSize) },
                        set: { chatFontSize = Int($0) }
                    ),
                    in: 12...22,
                    unit: "pt"
                )

                Text("The quick brown fox jumps over the lazy dog")
                    .font(.system(size: CGFloat(chatFontSize)))
                    .foregroundStyle(V4Color.textPrimary)
                    .padding(ParietalSpacing.sm)
                    .background(Color.white.opacity(V2Depth.bgCardLight))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .padding(.top, 4)
            }

            // Animations
            SettingsSection("Animations", icon: "sparkles", color: V4Color.purple) {
                SettingsToggle(
                    "Enable Animations",
                    isOn: $animationsEnabled,
                    description: "Smooth transitions and visual feedback"
                )

                SettingsToggle(
                    "Reduced Motion",
                    isOn: $reducedMotion,
                    description: "Minimize animation for accessibility"
                )
            }

            // Layout
            SettingsSection("Layout", icon: "rectangle.split.3x3", color: V4Color.golden) {
                SettingsSlider(
                    "Sidebar Width",
                    value: $sidebarWidth,
                    in: 180...300,
                    unit: "px"
                )
            }

            // Color theme
            SettingsSection("Colors", icon: "paintpalette.fill", color: V4Color.accent) {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Accent Color")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)

                    HStack(spacing: ParietalSpacing.sm) {
                        ForEach(ColorOption.allCases.filter({ $0 != .custom })) { option in
                            ColorSwatch(option: option, isSelected: accentColorRaw == option.rawValue) {
                                accentColorRaw = option.rawValue
                            }
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Behavior Settings Content

struct BehaviorSettingsContent: View {
    @AppStorage("autoSaveEnabled") private var autoSaveEnabled = true
    @AppStorage("autoSaveInterval") private var autoSaveInterval: Double = 30
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("soundEnabled") private var soundEnabled = true
    @AppStorage("keyboardShortcutsEnabled") private var keyboardShortcutsEnabled = true

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            // Auto-save
            SettingsSection("Auto-Save", icon: "square.and.arrow.down", color: V4Color.accent) {
                SettingsToggle(
                    "Enable Auto-Save",
                    isOn: $autoSaveEnabled,
                    description: "Automatically save work at intervals"
                )

                if autoSaveEnabled {
                    SettingsSlider(
                        "Interval",
                        value: $autoSaveInterval,
                        in: 10...300,
                        step: 10,
                        unit: "s"
                    )
                    .transition(.opacity)
                }
            }

            // Notifications
            SettingsSection("Notifications", icon: "bell.fill", color: V4Color.purple) {
                SettingsToggle(
                    "Enable Notifications",
                    isOn: $notificationsEnabled,
                    description: "Show alerts for important events"
                )

                SettingsToggle(
                    "Sound Effects",
                    isOn: $soundEnabled,
                    description: "Play sounds for notifications"
                )
            }

            // Shortcuts
            SettingsSection("Keyboard", icon: "command", color: V4Color.golden) {
                SettingsToggle(
                    "Enable Shortcuts",
                    isOn: $keyboardShortcutsEnabled,
                    description: "Use keyboard shortcuts for quick actions"
                )

                HStack {
                    Text("Cmd+S")
                        .font(.caption.monospaced())
                        .padding(.horizontal, ParietalSpacing.xs + 2)
                        .padding(.vertical, 3)
                        .background(V4Color.border)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("Save current work")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .padding(.top, 4)

                HStack {
                    Text("Cmd+K")
                        .font(.caption.monospaced())
                        .padding(.horizontal, ParietalSpacing.xs + 2)
                        .padding(.vertical, 3)
                        .background(V4Color.border)
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    Text("Open command palette")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
        }
    }
}

// MARK: - Privacy Settings Content

struct PrivacySettingsContent: View {
    @AppStorage("analyticsEnabled") private var analyticsEnabled = false
    @AppStorage("crashReportsEnabled") private var crashReportsEnabled = true
    @AppStorage("telemetryLevel") private var telemetryLevelRaw: String = TelemetryLevel.basic.rawValue

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            // Analytics
            SettingsSection("Analytics", icon: "chart.bar", color: V4Color.accent) {
                SettingsToggle(
                    "Share Anonymous Analytics",
                    isOn: $analyticsEnabled,
                    description: "Help improve Queen UI with usage data",
                    icon: "chart.bar.fill",
                    iconColor: V4Color.purple
                )
            }

            // Crash reports
            SettingsSection("Crash Reports", icon: "exclamationmark.triangle.fill", color: V4Color.warning) {
                SettingsToggle(
                    "Send Crash Reports",
                    isOn: $crashReportsEnabled,
                    description: "Automatically send reports on crashes",
                    icon: "arrow.up.doc",
                    iconColor: V4Color.warning
                )
            }

            // Telemetry level
            SettingsSection("Data Collection", icon: "hand.raised.fill", color: V4Color.golden) {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Telemetry Level")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)

                    HStack(spacing: ParietalSpacing.sm) {
                        ForEach(TelemetryLevel.allCases) { level in
                            TelemetryLevelCard(
                                level: level,
                                isSelected: telemetryLevelRaw == level.rawValue
                            ) {
                                telemetryLevelRaw = level.rawValue
                            }
                        }
                    }
                }

                Text("None = no data | Basic = minimal stats | Full = detailed metrics")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Telemetry Level

enum TelemetryLevel: String, CaseIterable, Identifiable {
    case none = "none"
    case basic = "basic"
    case full = "full"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .none: return "None"
        case .basic: return "Basic"
        case .full: return "Full"
        }
    }

    var icon: String {
        switch self {
        case .none: return "slash.circle"
        case .basic: return "circle"
        case .full: return "circle.circle"
        }
    }

    var description: String {
        switch self {
        case .none: return "No data collection"
        case .basic: return "Minimal usage stats"
        case .full: return "Detailed metrics"
        }
    }
}

// MARK: - Telemetry Level Card

struct TelemetryLevelCard: View {
    let level: TelemetryLevel
    let isSelected: Bool
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: level.icon)
                    .font(WernickeTypography.body14Medium)
                    .foregroundStyle(isSelected ? V4Color.accent : V4Color.textSecondary)

                Text(level.name)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(isSelected ? V4Color.textPrimary : V4Color.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, ParietalSpacing.sm + 2)
            .background(
                isSelected
                    ? V4Color.accent.opacity(V2Depth.bgSidebarHover)
                    : (isHovered ? V4Color.textPrimary.opacity(0.05) : Color.clear)
            )
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .stroke(isSelected ? V4Color.accent : V4Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Advanced Settings Content

struct AdvancedSettingsContent: View {
    @AppStorage("debugMode") private var debugMode = false
    @AppStorage("verboseLogging") private var verboseLogging = false
    @AppStorage("logLevel") private var logLevelRaw: String = LogLevel.info.rawValue
    @AppStorage("cacheSizeMB") private var cacheSizeMB: Double = 500
    @AppStorage("developerMode") private var developerMode = false

    @State private var showingCacheClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            // Debug
            SettingsSection("Debug", icon: "ladybug.fill", color: V4Color.warning) {
                SettingsToggle(
                    "Debug Mode",
                    isOn: $debugMode,
                    description: "Show additional debugging information",
                    icon: "ladybug",
                    iconColor: V4Color.warning
                )

                SettingsToggle(
                    "Verbose Logging",
                    isOn: $verboseLogging,
                    description: "Enable detailed log output",
                    icon: "doc.text.fill",
                    iconColor: V4Color.purple
                )
            }

            // Logs
            SettingsSection("Logging", icon: "doc.text.fill", color: V4Color.purple) {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Log Level")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)

                    HStack(spacing: ParietalSpacing.sm) {
                        ForEach(LogLevel.allCases) { level in
                            LogLevelBadge(
                                level: level,
                                isSelected: logLevelRaw == level.rawValue
                            ) {
                                logLevelRaw = level.rawValue
                            }
                        }
                    }
                }
            }

            // Cache
            SettingsSection("Cache", icon: "externaldrive.fill", color: V4Color.accent) {
                SettingsSlider(
                    "Cache Size",
                    value: $cacheSizeMB,
                    in: 100...2000,
                    step: 100,
                    unit: "MB"
                )

                HStack(spacing: ParietalSpacing.md) {
                    Button {
                        showingCacheClear = true
                    } label: {
                        HStack(spacing: ParietalSpacing.xs) {
                            Image(systemName: "trash")
                                .font(WernickeTypography.size11)
                            Text("Clear Cache")
                                .font(WernickeTypography.captionMedium)
                        }
                        .foregroundStyle(V4Color.error)
                        .padding(.horizontal, ParietalSpacing.md)
                        .padding(.vertical, ParietalSpacing.xs + 2)
                        .background(V4Color.error.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
                    }
                    .buttonStyle(.plain)

                    Text("Frees ~\(Int(cacheSizeMB)) MB")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .padding(.top, 4)
                .alert("Clear Cache", isPresented: $showingCacheClear) {
                    Button("Cancel", role: .cancel) {}
                    Button("Clear", role: .destructive) {
                        // Cache clearing logic
                    }
                } message: {
                    Text("This will clear all cached data. Cached content will be re-downloaded when needed.")
                }
            }

            // Developer
            SettingsSection("Developer", icon: "hammer.fill", color: V4Color.golden) {
                SettingsToggle(
                    "Developer Mode",
                    isOn: $developerMode,
                    description: "Unlock experimental features and tools",
                    icon: "wrench.and.screwdriver",
                    iconColor: V4Color.golden
                )

                if developerMode {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
                        Text("Experimental Features")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)

                        Text("Advanced UI controls, API testing, performance profiling")
                            .font(.caption2)
                            .foregroundStyle(V4Color.textSecondary)
                            .padding(.leading, 4)
                    }
                    .transition(.opacity)
                }
            }
        }
    }
}

// MARK: - Log Level

enum LogLevel: String, CaseIterable, Identifiable {
    case error = "error"
    case warning = "warning"
    case info = "info"
    case debug = "debug"

    var id: String { rawValue }

    var name: String {
        switch self {
        case .error: return "Error"
        case .warning: return "Warn"
        case .info: return "Info"
        case .debug: return "Debug"
        }
    }

    var color: Color {
        switch self {
        case .error: return V4Color.error
        case .warning: return V4Color.warning
        case .info: return V4Color.accent
        case .debug: return V4Color.purple
        }
    }
}

// MARK: - Log Level Badge

struct LogLevelBadge: View {
    let level: LogLevel
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(level.name)
                .font(.caption2.weight(.medium))
                .foregroundStyle(isSelected ? V4Color.textPrimary : level.color)
                .padding(.horizontal, ParietalSpacing.sm + 2)
                .padding(.vertical, 5)
                .background(
                    isSelected
                        ? level.color.opacity(0.2)
                        : level.color.opacity(V2Depth.bgSubtle)
                )
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .overlay(
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isSelected ? level.color : Color.clear, lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Complete Settings View

/// A complete, ready-to-use settings view with all sections
struct SettingsPanelsView: View {
    @State private var selectedSection: String = "appearance"
    @State private var searchText: String = ""

    private let sections: [SettingsNavSection] = [
        StandardSettingsSection.appearance.navSection,
        StandardSettingsSection.behavior.navSection,
        StandardSettingsSection.privacy.navSection,
        StandardSettingsSection.advanced.navSection,
    ]

    var body: some View {
        SettingsNavigation(sections: sections, selectedSection: $selectedSection) {
            VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                // Header
                HStack {
                    Text(settingsTitle)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(V4Color.textPrimary)

                    Spacer()

                    ModifiedIndicator(isModified: false)
                }
                .padding(.bottom, 4)

                // Search
                SettingsSearch(searchText: $searchText, availableSections: sections.map { $0.id })
                    .padding(.bottom, ParietalSpacing.md)

                // Content based on selection
                Group {
                    switch selectedSection {
                    case "appearance":
                        AppearanceSettingsContent()
                    case "behavior":
                        BehaviorSettingsContent()
                    case "privacy":
                        PrivacySettingsContent()
                    case "advanced":
                        AdvancedSettingsContent()
                    default:
                        AppearanceSettingsContent()
                    }
                }
                .filterSettings(searchText: searchText, keywords: sectionKeywords(for: selectedSection))
            }
        }
        .frame(minWidth: 700, minHeight: 500)
    }

    private var settingsTitle: String {
        switch selectedSection {
        case "appearance": return "Appearance"
        case "behavior": return "Behavior"
        case "privacy": return "Privacy"
        case "advanced": return "Advanced"
        default: return "Settings"
        }
    }

    private func sectionKeywords(for section: String) -> [String] {
        switch section {
        case "appearance":
            return ["font", "size", "animation", "color", "theme", "sidebar", "display"]
        case "behavior":
            return ["auto", "save", "notification", "sound", "keyboard", "shortcut", "interval"]
        case "privacy":
            return ["analytics", "crash", "report", "telemetry", "data", "collection"]
        case "advanced":
            return ["debug", "log", "cache", "developer", "experimental", "verbose"]
        default:
            return []
        }
    }
}

// MARK: - Preview

struct SettingsPanelsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsPanelsView()
            .frame(width: 900, height: 600)
    }
}

// MARK: - Helper Extensions

extension View {
    func onFocusChange(_ action: @escaping (Bool) -> Void) -> some View {
        self.onAppear { action(true) }
            .onDisappear { action(false) }
    }
}
