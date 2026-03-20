// Color Picker — Color Selection with Presets and Custom Picker
import SwiftUI

// MARK: - Color Picker View

struct ColorPickerView: View {
    @Binding var selectedColor: Color
    let presets: [ColorPreset]
    let allowCustom: Bool

    @State private var showCustomPicker = false
    @State private var customColor: NSColor = .white

    struct ColorPreset: Identifiable {
        let id: UUID
        let color: Color
        let name: String

        init(name: String, color: Color) {
            self.name = name
            self.color = color
            self.id = UUID()
        }
    }

    init(
        selectedColor: Binding<Color>,
        presets: [ColorPreset] = defaultPresets,
        allowCustom: Bool = true
    ) {
        self._selectedColor = selectedColor
        self.presets = presets
        self.allowCustom = allowCustom
    }

    static var defaultPresets: [ColorPreset] {
        [
            ColorPreset(name: "Red", color: .red),
            ColorPreset(name: "Orange", color: .orange),
            ColorPreset(name: "Yellow", color: .yellow),
            ColorPreset(name: "Green", color: .green),
            ColorPreset(name: "Blue", color: .blue),
            ColorPreset(name: "Purple", color: .purple),
            ColorPreset(name: "Pink", color: .pink),
            ColorPreset(name: "Gray", color: .gray),
            ColorPreset(name: "Black", color: .black),
            ColorPreset(name: "White", color: .white)
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            // Presets
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: ParietalSpacing.sm + 2) {
                ForEach(presets) { preset in
                    ColorSwatchView(
                        color: preset.color,
                        isSelected: selectedColor == preset.color,
                        name: preset.name
                    ) {
                        withAnimation {
                            selectedColor = preset.color
                        }
                    }
                }
            }

            // Custom picker
            if allowCustom {
                Divider()
                    .background(V4Color.border)

                Button {
                    showCustomPicker = true
                } label: {
                    HStack(spacing: ParietalSpacing.sm + 2) {
                        Rectangle()
                            .fill(Color(customColor))
                            .frame(width: ParietalSpacing.lg, height: ParietalSpacing.lg)
                            .cornerRadius(V1Theme.cornerTiny)

                        Text("Custom Color...")
                            .font(WernickeTypography.size13)
                            .foregroundStyle(V4Color.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, ParietalSpacing.md)
                    .padding(.vertical, ParietalSpacing.sm)
                    .background(V4Color.background.opacity(V2Depth.stateDisabled))
                    .cornerRadius(V1Theme.cornerSmall)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showCustomPicker) {
                    CustomColorSheet(
                        color: $customColor,
                        isPresented: $showCustomPicker
                    ) { newColor in
                        selectedColor = Color(newColor)
                    }
                }
            }
        }
        .padding(ParietalSpacing.md)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Color Swatch

struct ColorSwatchView: View {
    let color: Color
    let isSelected: Bool
    let name: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            ZStack {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 40, height: 40)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.white.opacity(V2Depth.stateHover), lineWidth: 1)
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(WernickeTypography.body14Medium)
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(V2Depth.stateHover), radius: 2)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }
}

// MARK: - Custom Color Sheet

struct CustomColorSheet: View {
    @Binding var color: NSColor
    @Binding var isPresented: Bool
    let onColorSelected: (NSColor) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 30) {
                // Color wheel
                ColorWheelRepresentation(color: $color, diameter: 250)
                    .frame(height: 280)

                // Brightness slider
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Brightness")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)

                    HStack(spacing: ParietalSpacing.md) {
                        Image(systemName: "sun.min")
                            .font(WernickeTypography.size12)
                            .foregroundStyle(V4Color.textSecondary)

                        Slider(value: .constant(color.brightnessComponent), in: 0...1)

                        Image(systemName: "sun.max")
                            .font(WernickeTypography.size12)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }

                // Preview
                HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                    VStack(spacing: ParietalSpacing.xs) {
                        Text("Selected")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(color))
                            .frame(width: 60, height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(V4Color.border, lineWidth: 1)
                            )
                    }

                    Spacer()

                    VStack(spacing: ParietalSpacing.xs) {
                        Text("Hex Code")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)

                        Text(hexCode)
                            .font(WernickeTypography.smallSemiboldMono)
                            .foregroundStyle(V4Color.textPrimary)
                            .padding(.horizontal, ParietalSpacing.sm + 2)
                            .padding(.vertical, ParietalSpacing.xs + 2)
                            .background(V4Color.background.opacity(V2Depth.stateDisabled))
                            .cornerRadius(V1Theme.cornerSmall)
                    }
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Choose Color")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        isPresented = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onColorSelected(color)
                        isPresented = false
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }

    private var hexCode: String {
        let rgb = color.usingColorSpace(.deviceRGB) ?? color
        let red = Int(rgb.redComponent * 255)
        let green = Int(rgb.greenComponent * 255)
        let blue = Int(rgb.blueComponent * 255)
        return String(format: "#%02X%02X%02X", red, green, blue)
    }
}

// MARK: - Color Wheel Representation

struct ColorWheelRepresentation: View {
    @Binding var color: NSColor
    let diameter: CGFloat

    var body: some View {
        ZStack {
            // Background gradient representing color wheel
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            Color.white,
                            Color(hue: 0, saturation: 1, brightness: 1),
                            Color(hue: 0.16, saturation: 1, brightness: 1),
                            Color(hue: 0.33, saturation: 1, brightness: 1),
                            Color(hue: 0.5, saturation: 1, brightness: 1),
                            Color(hue: 0.66, saturation: 1, brightness: 1),
                            Color(hue: 0.83, saturation: 1, brightness: 1),
                            Color(hue: 1, saturation: 1, brightness: 1)
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: diameter / 2
                    )
                )

            // Center indicator
            Circle()
                .fill(Color(color))
                .frame(width: ParietalSpacing.icon + 4, height: ParietalSpacing.icon + 4)
                .overlay(
                    Circle()
                        .stroke(.white, lineWidth: 2)
                )
                .shadow(color: .black.opacity(0.2), radius: 2)
        }
        .frame(width: diameter, height: diameter)
    }
}

// MARK: - Theme Color Picker

struct ThemeColorPicker: View {
    @Binding var selectedColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm + 2) {
            Text("Color")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            HStack(spacing: ParietalSpacing.sm) {
                ForEach(TrinityThemeColors.allCases, id: \.self) { themeColor in
                    ColorSwatchView(
                        color: themeColor.color,
                        isSelected: colorMatches(selectedColor, themeColor.color),
                        name: themeColor.name
                    ) {
                        withAnimation {
                            selectedColor = themeColor.color
                        }
                    }
                }
            }
        }
    }

    private func colorMatches(_ color1: Color, _ color2: Color) -> Bool {
        // Simple color comparison
        return true // Placeholder
    }
}

// MARK: - Theme Colors

enum TrinityThemeColors: CaseIterable {
    case accent
    case statusOK
    case statusWarn
    case statusError
    case primary
    case muted
    case bgCard

    var color: Color {
        switch self {
        case .accent: return V4Color.accent
        case .statusOK: return V4Color.success
        case .statusWarn: return V4Color.warning
        case .statusError: return V4Color.error
        case .primary: return V4Color.textPrimary
        case .muted: return V4Color.textSecondary
        case .bgCard: return V4Color.surface
        }
    }

    var name: String {
        switch self {
        case .accent: return "Accent"
        case .statusOK: return "Success"
        case .statusWarn: return "Warning"
        case .statusError: return "Error"
        case .primary: return "Primary"
        case .muted: return "Muted"
        case .bgCard: return "Card"
        }
    }
}

// MARK: - Gradient Picker

struct GradientPicker: View {
    @Binding var selectedGradient: LinearGradient
    let gradients: [GradientOption]

    struct GradientOption: Identifiable {
        let id = UUID()
        let colors: [Color]
        let name: String
    }

    init(
        selectedGradient: Binding<LinearGradient>,
        gradients: [GradientOption] = defaultGradients
    ) {
        self._selectedGradient = selectedGradient
        self.gradients = gradients
    }

    static var defaultGradients: [GradientOption] {
        [
            GradientOption(colors: [.blue, .purple], name: "Blue-Purple"),
            GradientOption(colors: [.orange, .pink], name: "Sunset"),
            GradientOption(colors: [.green, .teal], name: "Forest"),
            GradientOption(colors: [.yellow, .orange], name: "Warm"),
            GradientOption(colors: [.purple, .pink], name: "Berry")
        ]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm + 2) {
            Text("Gradient")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: ParietalSpacing.sm + 2) {
                ForEach(gradients) { gradient in
                    GradientSwatchView(
                        colors: gradient.colors,
                        isSelected: false,
                        name: gradient.name
                    ) {
                        selectedGradient = LinearGradient(
                            colors: gradient.colors,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
            }
        }
    }
}

// MARK: - Gradient Swatch

struct GradientSwatchView: View {
    let colors: [Color]
    let isSelected: Bool
    let name: String
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: colors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 50, height: 50)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(name)
    }
}

// MARK: - Preview

struct ColorPicker_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ColorPickerView(
                selectedColor: .constant(.blue)
            )
            .frame(width: ParietalSpacing.xl * 12)
            .padding()
            .background(V4Color.background)

            ThemeColorPicker(
                selectedColor: .constant(V4Color.accent)
            )
            .frame(width: ParietalSpacing.xl * 12)
            .padding()
            .background(V4Color.background)
        }
    }
}
