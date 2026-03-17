import SwiftUI

// MARK: - Appearance Mode

public enum AppearanceMode: String, CaseIterable {
    case system = "system"
    case dark = "dark"
    case light = "light"

    var label: String {
        switch self {
        case .system: return "System"
        case .dark: return "Dark"
        case .light: return "Light"
        }
    }
}

// MARK: - Theme Variant

public enum ThemeVariant: String, CaseIterable, Identifiable {
    case deepSpace = "deepSpace"
    case oledBlack = "oledBlack"
    case midnightBlue = "midnightBlue"

    public var id: String { rawValue }

    var name: String {
        switch self {
        case .deepSpace: return "Deep Space"
        case .oledBlack: return "OLED Black"
        case .midnightBlue: return "Midnight Blue"
        }
    }

    var description: String {
        switch self {
        case .deepSpace: return "Rich dark grays with green accent"
        case .oledBlack: return "Pure black for OLED displays"
        case .midnightBlue: return "Dark blue tones with purple tint"
        }
    }

    var icon: String {
        switch self {
        case .deepSpace: return "sparkles"
        case .oledBlack: return "circle.fill"
        case .midnightBlue: return "moon.stars.fill"
        }
    }

    // MARK: - Theme Colors

    var bgWindowDark: UInt32 {
        switch self {
        case .deepSpace: return 0x0A0A0F
        case .oledBlack: return 0x000000
        case .midnightBlue: return 0x0A0E1A
        }
    }

    var bgSidebarDark: UInt32 {
        switch self {
        case .deepSpace: return 0x0D0D12
        case .oledBlack: return 0x000000
        case .midnightBlue: return 0x0D111F
        }
    }

    var bgCardDark: UInt32 {
        switch self {
        case .deepSpace: return 0x121218
        case .oledBlack: return 0x050505
        case .midnightBlue: return 0x131B2E
        }
    }

    var bgCardBorderDark: UInt32 {
        switch self {
        case .deepSpace: return 0x1A1A24
        case .oledBlack: return 0x111111
        case .midnightBlue: return 0x1E2A40
        }
    }

    var accentColor: UInt32 {
        switch self {
        case .deepSpace: return 0x00FF88
        case .oledBlack: return 0x00FF88
        case .midnightBlue: return 0x00D9FF
        }
    }
}

// Theme from src/trinity_node/ui.zig THEME struct
struct TrinityTheme {
    // MARK: - Appearance Storage

    @AppStorage("appearanceMode") static var appearanceModeRaw: String = AppearanceMode.dark.rawValue

    static var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .dark
    }

    static var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    // MARK: - Theme Variant Storage

    @AppStorage("selectedTheme") static var selectedThemeRaw: String = ThemeVariant.deepSpace.rawValue

    static var selectedTheme: ThemeVariant {
        ThemeVariant(rawValue: selectedThemeRaw) ?? .deepSpace
    }

    // MARK: - Adaptive Colors

    static var bgWindow: Color {
        Color(light: Color(hex: 0xF5F5F5), dark: Color(hex: selectedTheme.bgWindowDark))
    }
    static var bgSidebar: Color {
        Color(light: Color(hex: 0xEBEBEB), dark: Color(hex: selectedTheme.bgSidebarDark))
    }
    static var bgCard: Color {
        Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: selectedTheme.bgCardDark))
    }
    static var textPrimary: Color {
        Color(light: .black, dark: .white)
    }
    static var textMuted: Color {
        Color(light: Color(hex: 0x555555), dark: Color(hex: 0xAAAAAA))
    }
    static var bgCardBorder: Color {
        Color(light: Color(hex: 0xDDDDDD), dark: Color(hex: selectedTheme.bgCardBorderDark))
    }

    // MARK: - Fixed Colors (same in both modes)

    static var accent: Color {
        Color(hex: selectedTheme.accentColor)
    }
    static let golden      = Color(hex: 0xFFD700)
    static let purple      = Color(hex: 0x8B5CF6)
    static var statusOK: Color {
        Color(hex: selectedTheme.accentColor)
    }
    static let statusWarn  = Color(hex: 0xFFD700)
    static let statusError = Color(hex: 0xEF4444)

    static let cardCorner: CGFloat = 12
    static let spacing: CGFloat = 16

    // MARK: - Unified Corner Radius Tokens
    static let cornerSmall: CGFloat = 6       // small buttons, badges
    static let cornerMedium: CGFloat = 10     // input fields, popovers
    static let cornerLarge: CGFloat = 12      // cards, panels
    static let cornerXL: CGFloat = 24         // input bar (pill shape)

    // MARK: - Shadow Tokens
    static func shadowSmall(_ scheme: ColorScheme = .dark) -> some View {
        Color.black.opacity(0.3).blur(radius: 4)
    }

    static let shadowMediumRadius: CGFloat = 8
    static let shadowMediumOpacity: Double = 0.4
    static let shadowLargeRadius: CGFloat = 16
    static let shadowLargeOpacity: Double = 0.5

    // MARK: - User-controlled font size (Settings slider)
    /// User-adjustable chat font size (12-22pt), persisted in UserDefaults
    static var chatFontSize: CGFloat {
        let stored = UserDefaults.standard.integer(forKey: "chatFontSize")
        return stored > 0 ? CGFloat(stored) : 15
    }

    static var chatCaptionSize: CGFloat {
        return max(chatFontSize - 4, 9)
    }

    static var chatHeadingSize: CGFloat {
        return chatFontSize + 5
    }

    // MARK: - Dynamic Type Sizes (Accessibility)
    /// Base font sizes that scale with system Dynamic Type setting
    static func bodySize(_ sizeCategory: DynamicTypeSize = .medium) -> CGFloat {
        switch sizeCategory {
        case .xSmall: return 12
        case .small: return 13
        case .medium: return 15
        case .large: return 16
        case .xLarge: return 18
        case .xxLarge: return 20
        case .xxxLarge: return 22
        case .accessibility1: return 26
        case .accessibility2: return 30
        case .accessibility3: return 34
        case .accessibility4: return 38
        case .accessibility5: return 42
        @unknown default: return 15
        }
    }

    static func captionSize(_ sizeCategory: DynamicTypeSize = .medium) -> CGFloat {
        return max(bodySize(sizeCategory) - 4, 9)
    }

    static func headingSize(_ sizeCategory: DynamicTypeSize = .medium) -> CGFloat {
        return bodySize(sizeCategory) + 5
    }

    // MARK: - Animation Tokens

    /// Spring animation for message entrance (smooth, responsive)
    static let springResponse: Double = 0.45
    static let springDampingFraction: Double = 0.75
    static let springBlendDuration: Double = 0.35

    /// Stagger delay for multiple messages appearing (cascade effect)
    static let messageStaggerDelay: Double = 0.05

    /// Scale values for message entrance polish
    static let messageEntranceScale: CGFloat = 0.92
    static let messageExitScale: CGFloat = 0.98

    /// Standard spring animation for UI elements
    static func springAnimation(response: Double = springResponse,
                                dampingFraction: Double = springDampingFraction) -> Animation {
        .spring(response: response, dampingFraction: dampingFraction, blendDuration: springBlendDuration)
    }

    /// Quick spring for snappy interactions
    static func quickSpring() -> Animation {
        .spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)
    }

    /// Gentle spring for subtle animations
    static func gentleSpring() -> Animation {
        .spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.4)
    }

    /// Fade-only animation for reduced motion accessibility
    static var fadeAnimation: Animation {
        .easeInOut(duration: 0.25)
    }

    // MARK: - High Contrast Colors

    /// High contrast variant with stronger color differences for accessibility
    /// Use these colors when AccessibilityManager.shared.highContrast is true
    struct HighContrast {
        /// Maximum contrast accent (bright green on dark backgrounds)
        static let accent = Color(hex: 0x00FF00)

        /// Pure white for text on dark backgrounds
        static let textPrimary = Color.white

        /// Light gray for secondary text (still high contrast)
        static let textMuted = Color(hex: 0xD0D0D0)

        /// Pure black borders on light backgrounds
        static let borderLight = Color.black

        /// Pure white borders on dark backgrounds
        static let borderDark = Color.white

        /// Strong error color (bright red)
        static let error = Color(hex: 0xFF0000)

        /// Strong warning color (bright yellow/orange)
        static let warning = Color(hex: 0xFFAA00)

        /// Strong success color (bright green)
        static let success = Color(hex: 0x00FF00)

        /// Background for high contrast mode
        static let background = Color.black

        /// Card background for high contrast mode (slightly lighter than background)
        static let cardBackground = Color(hex: 0x1A1A1A)
    }

    /// Returns appropriate accent color based on high contrast setting
    static func accessibleAccent(_ highContrast: Bool) -> Color {
        highContrast ? HighContrast.accent : accent
    }

    /// Returns appropriate text primary color based on high contrast setting
    static func accessibleTextPrimary(_ highContrast: Bool) -> Color {
        highContrast ? HighContrast.textPrimary : textPrimary
    }

    /// Returns appropriate text muted color based on high contrast setting
    static func accessibleTextMuted(_ highContrast: Bool) -> Color {
        highContrast ? HighContrast.textMuted : textMuted
    }

    /// Returns appropriate border color based on high contrast setting
    static func accessibleBorder(_ highContrast: Bool) -> Color {
        highContrast ? HighContrast.borderDark : bgCardBorder
    }

    /// Returns appropriate background color for cards in high contrast mode
    static func accessibleCardBackground(_ highContrast: Bool) -> Color {
        highContrast ? HighContrast.cardBackground : bgCard
    }
}

extension Color {
    init(hex: UInt32, opacity: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    /// Adaptive color that responds to the current color scheme.
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? NSColor(dark) : NSColor(light)
        })
    }
}
