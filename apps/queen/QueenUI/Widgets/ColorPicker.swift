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
        VStack(alignment: .leading, spacing: 12) {
            // Presets
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 40))], spacing: 10) {
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
                    .background(TrinityTheme.bgCardBorder)

                Button {
                    showCustomPicker = true
                } label: {
                    HStack(spacing: 10) {
                        Rectangle()
                            .fill(Color(customColor))
                            .frame(width: 24, height: 24)
                            .cornerRadius(4)

                        Text("Custom Color...")
                            .font(.system(size: 13))
                            .foregroundStyle(TrinityTheme.textPrimary)

                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(TrinityTheme.bgWindow.opacity(0.5))
                    .cornerRadius(6)
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
        .padding(12)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
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
                            .stroke(.white.opacity(0.3), lineWidth: 1)
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white)
                        .shadow(color: .black.opacity(0.3), radius: 2)
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
                VStack(alignment: .leading, spacing: 8) {
                    Text("Brightness")
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)

                    HStack(spacing: 12) {
                        Image(systemName: "sun.min")
                            .font(.system(size: 12))
                            .foregroundStyle(TrinityTheme.textMuted)

                        Slider(value: .constant(color.brightnessComponent), in: 0...1)

                        Image(systemName: "sun.max")
                            .font(.system(size: 12))
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }

                // Preview
                HStack(spacing: 20) {
                    VStack(spacing: 4) {
                        Text("Selected")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)

                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(color))
                            .frame(width: 60, height: 60)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                            )
                    }

                    Spacer()

                    VStack(spacing: 4) {
                        Text("Hex Code")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)

                        Text(hexCode)
                            .font(.system(size: 13, weight: .medium, design: .monospaced))
                            .foregroundStyle(TrinityTheme.textPrimary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(TrinityTheme.bgWindow.opacity(0.5))
                            .cornerRadius(6)
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
                .frame(width: 20, height: 20)
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Color")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)

            HStack(spacing: 8) {
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
        case .accent: return TrinityTheme.accent
        case .statusOK: return TrinityTheme.statusOK
        case .statusWarn: return TrinityTheme.statusWarn
        case .statusError: return TrinityTheme.statusError
        case .primary: return TrinityTheme.textPrimary
        case .muted: return TrinityTheme.textMuted
        case .bgCard: return TrinityTheme.bgCard
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
        VStack(alignment: .leading, spacing: 10) {
            Text("Gradient")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
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
            .frame(width: 300)
            .padding()
            .background(TrinityTheme.bgWindow)

            ThemeColorPicker(
                selectedColor: .constant(TrinityTheme.accent)
            )
            .frame(width: 300)
            .padding()
            .background(TrinityTheme.bgWindow)
        }
    }
}
