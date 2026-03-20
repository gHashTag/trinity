//
// V1 — Primary Visual Cortex
// Foundation of all visual processing in Trinity Queen UI
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Appearance Mode

/// How the UI adapts to system appearance
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

// MARK: - Accent Color

/// User-selectable accent colors for Trinity UI
public enum AccentColor: String, CaseIterable, Identifiable {
    case green = "green"
    case blue = "blue"
    case purple = "purple"
    case gold = "gold"
    case rose = "rose"

    public var id: String { rawValue }

    var name: String {
        switch self {
        case .green: return "Matrix Green"
        case .blue: return "Cyber Blue"
        case .purple: return "Neon Purple"
        case .gold: return "Golden Hour"
        case .rose: return "Rose Quartz"
        }
    }

    var hexValue: UInt32 {
        switch self {
        case .green: return 0x00FF88
        case .blue: return 0x00D9FF
        case .purple: return 0xA78BFA
        case .gold: return 0xFFD700
        case .rose: return 0xFB7185
        }
    }

    var icon: String {
        switch self {
        case .green: return "leaf.fill"
        case .blue: return "drop.fill"
        case .purple: return "sparkles"
        case .gold: return "star.fill"
        case .rose: return "heart.fill"
        }
    }
}

// MARK: - Theme Variant

/// Background theme variants for Trinity UI
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
        case .deepSpace: return "Rich dark grays with accent color"
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

// MARK: - V1 Primary Visual Cortex

/// V1 — Primary Visual Cortex
/// Foundation of all visual processing in Trinity Queen UI
///
/// V1 is the first cortical area in the visual stream,
/// processing basic visual information before passing to
/// higher areas (V4 for color, MT for motion).
public struct V1Theme {

    // MARK: - Appearance Storage

    @AppStorage("appearanceMode") public static var appearanceModeRaw: String = AppearanceMode.dark.rawValue
    @AppStorage("selectedAccentColor") public static var selectedAccentColorRaw: String = AccentColor.green.rawValue
    @AppStorage("reduceMotionEnabled") public static var reduceMotionEnabled: Bool = false
    @AppStorage("highContrastEnabled") public static var highContrastEnabled: Bool = false

    public static var appearanceMode: AppearanceMode {
        AppearanceMode(rawValue: appearanceModeRaw) ?? .dark
    }

    public static var colorScheme: ColorScheme? {
        switch appearanceMode {
        case .system: return nil
        case .dark: return .dark
        case .light: return .light
        }
    }

    // MARK: - Theme Variant Storage

    @AppStorage("selectedTheme") public static var selectedThemeRaw: String = ThemeVariant.deepSpace.rawValue

    public static var selectedTheme: ThemeVariant {
        ThemeVariant(rawValue: selectedThemeRaw) ?? .deepSpace
    }

    // MARK: - Accent Color Storage

    public static var selectedAccentColor: AccentColor {
        AccentColor(rawValue: selectedAccentColorRaw) ?? .green
    }

    // MARK: - Accessibility Preferences

    /// Returns reduced motion setting (respects system preference if not manually overridden)
    public static var reduceMotion: Bool {
        reduceMotionEnabled || NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
    }

    /// Returns appropriate animation based on reduce motion setting
    public static func adaptiveAnimation(_ animation: @autoclosure () -> Animation) -> Animation {
        reduceMotion ? .easeInOut(duration: 0.2) : animation()
    }

    /// Spring animation that respects reduce motion
    public static func springAnimation(response: Double = springResponse,
                                        dampingFraction: Double = springDampingFraction) -> Animation {
        let spring = Animation.spring(response: response, dampingFraction: dampingFraction, blendDuration: springBlendDuration)
        return adaptiveAnimation(spring)
    }

    // MARK: - Animation Tokens (MT/V5 Bridge)

    /// Spring animation for message entrance (smooth, responsive)
    public static let springResponse: Double = 0.45
    public static let springDampingFraction: Double = 0.75
    public static let springBlendDuration: Double = 0.35

    /// Stagger delay for multiple messages appearing (cascade effect)
    public static let messageStaggerDelay: Double = 0.05

    /// Scale values for message entrance polish
    public static let messageEntranceScale: CGFloat = 0.92
    public static let messageExitScale: CGFloat = 0.98

    /// Quick spring for snappy interactions (respects reduce motion)
    public static func quickSpring() -> Animation {
        let spring = Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)
        return adaptiveAnimation(spring)
    }

    /// Gentle spring for subtle animations (respects reduce motion)
    public static func gentleSpring() -> Animation {
        let spring = Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.4)
        return adaptiveAnimation(spring)
    }

    /// Accessible animation that respects reduce motion preference
    public static func accessibleAnimation() -> Animation {
        adaptiveAnimation(.spring(response: springResponse, dampingFraction: springDampingFraction, blendDuration: springBlendDuration))
    }

    /// Fade-only animation for reduced motion accessibility
    public static var fadeAnimation: Animation {
        .easeInOut(duration: 0.25)
    }

    // MARK: - High Contrast Colors

    /// High contrast variant with stronger color differences for accessibility
    public struct HighContrast {
        /// Maximum contrast accent (bright green on dark backgrounds)
        public static let accent = Color(hex: 0x00FF00)

        /// Pure white for text on dark backgrounds
        public static let textPrimary = Color.white

        /// Light gray for secondary text (still high contrast)
        public static let textMuted = Color(hex: 0xD0D0D0)

        /// Pure black borders on light backgrounds
        public static let borderLight = Color.black

        /// Pure white borders on dark backgrounds
        public static let borderDark = Color.white

        /// Strong error color (bright red)
        public static let error = Color(hex: 0xFF0000)

        /// Strong warning color (bright yellow/orange)
        public static let warning = Color(hex: 0xFFAA00)

        /// Strong success color (bright green)
        public static let success = Color(hex: 0x00FF00)

        /// Background for high contrast mode
        public static let background = Color.black

        /// Card background for high contrast mode (slightly lighter than background)
        public static let cardBackground = Color(hex: 0x1A1A1A)
    }

    /// Returns appropriate accent color based on high contrast setting
    public static func accessibleAccent(_ highContrast: Bool = highContrastEnabled) -> Color {
        highContrast ? HighContrast.accent : accent
    }

    /// Returns appropriate accent color for user-selected preference
    public static func userAccent(_ color: AccentColor? = nil) -> Color {
        let accentColor = color ?? selectedAccentColor
        return highContrastEnabled ? HighContrast.accent : Color(hex: accentColor.hexValue)
    }

    /// All available accent colors for selection UI
    public static var allAccentColors: [AccentColor] {
        AccentColor.allCases
    }

    /// Returns appropriate text primary color based on high contrast setting
    public static func accessibleTextPrimary(_ highContrast: Bool) -> Color {
        highContrast ? HighContrast.textPrimary : textPrimary
    }

    /// Returns appropriate text muted color based on high contrast setting
    public static func accessibleTextMuted(_ highContrast: Bool) -> Color {
        highContrast ? HighContrast.textMuted : textMuted
    }

    /// Returns appropriate border color based on high contrast setting
    public static func accessibleBorder(_ highContrast: Bool) -> Color {
        highContrast ? HighContrast.borderDark : bgCardBorder
    }

    /// Returns appropriate background color for cards in high contrast mode
    public static func accessibleCardBackground(_ highContrast: Bool) -> Color {
        highContrast ? HighContrast.cardBackground : bgCard
    }

    // MARK: - Corner Radius Tokens

    /// Unified corner radius tokens for consistent UI
    public static let cornerMicro: CGFloat = 3       // micro badges, tiny pills
    public static let cornerTiny: CGFloat = 4        // tiny elements, inline badges
    public static let cornerSmall: CGFloat = 6       // small buttons, badges
    public static let cornerBase: CGFloat = 8        // base cards, containers (between small/medium)
    public static let cornerMedium: CGFloat = 10     // input fields, popovers
    public static let cornerLarge: CGFloat = 12      // cards, panels
    public static let cornerXLarge: CGFloat = 16     // large panels, modals
    public static let cornerXL: CGFloat = 24         // input bar (pill shape)

    /// Legacy alias for cornerLarge (backward compatibility)
    @available(*, deprecated, message: "Use cornerLarge instead")
    public static let cardCorner: CGFloat = 12

    // MARK: - Shadow Tokens

    public static func shadowSmall(_ scheme: ColorScheme = .dark) -> some View {
        Color.black.opacity(V2Depth.stateHover).blur(radius: 4)
    }

    public static let shadowMediumRadius: CGFloat = 8
    public static let shadowMediumOpacity: Double = 0.4
    public static let shadowLargeRadius: CGFloat = 16
    public static let shadowLargeOpacity: Double = 0.5

    // MARK: - Opacity Tokens

    /// Disabled state opacity
    public static let opacityDisabled: Double = 0.5

    /// Hover/active state opacity
    public static let opacityHover: Double = 0.3

    /// Selected state background opacity
    public static let opacitySelected: Double = 0.15

    /// Subtle background opacity
    public static let opacitySubtle: Double = 0.1

    /// Card background opacity (normal)
    public static let opacityCard: Double = 0.06

    /// Card background opacity (lighter)
    public static let opacityCardLight: Double = 0.04

    /// Text secondary opacity
    public static let opacityTextSecondary: Double = 0.6

    /// Text tertiary opacity
    public static let opacityTextTertiary: Double = 0.4

    // MARK: - User-controlled font size (Settings slider)

    /// User-adjustable chat font size (12-22pt), persisted in UserDefaults
    public static var chatFontSize: CGFloat {
        let stored = UserDefaults.standard.integer(forKey: "chatFontSize")
        return stored > 0 ? CGFloat(stored) : 15
    }

    public static var chatCaptionSize: CGFloat {
        return max(chatFontSize - 4, 9)
    }

    public static var chatHeadingSize: CGFloat {
        return chatFontSize + 5
    }

    // MARK: - Dynamic Type Sizes (Accessibility)

    /// Base font sizes that scale with system Dynamic Type setting
    public static func bodySize(_ sizeCategory: DynamicTypeSize = .medium) -> CGFloat {
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

    public static func captionSize(_ sizeCategory: DynamicTypeSize = .medium) -> CGFloat {
        return max(bodySize(sizeCategory) - 4, 9)
    }

    public static func headingSize(_ sizeCategory: DynamicTypeSize = .medium) -> CGFloat {
        return bodySize(sizeCategory) + 5
    }

    // MARK: - Legacy Spacing Compatibility

    /// Default spacing value (16pt - use ParietalSpacing.md in new code)
    @available(*, deprecated, message: "Use ParietalSpacing.md instead")
    public static let spacing: CGFloat = 16
}

// MARK: - V1 Core Colors (Bridged from V4)

/// V1 basic colors - see V4Color for full semantic palette
public extension V1Theme {

    /// Primary window background
    static var bgWindow: Color {
        Color(light: Color(hex: 0xF5F5F5), dark: Color(hex: selectedTheme.bgWindowDark))
    }

    /// Sidebar background
    static var bgSidebar: Color {
        Color(light: Color(hex: 0xEBEBEB), dark: Color(hex: selectedTheme.bgSidebarDark))
    }

    /// Card background
    static var bgCard: Color {
        Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: selectedTheme.bgCardDark))
    }

    /// Primary text color
    static var textPrimary: Color {
        Color(light: .black, dark: .white)
    }

    /// Secondary text color
    static var textMuted: Color {
        Color(light: Color(hex: 0x555555), dark: Color(hex: 0xAAAAAA))
    }

    /// Card border color
    static var bgCardBorder: Color {
        Color(light: Color(hex: 0xDDDDDD), dark: Color(hex: selectedTheme.bgCardBorderDark))
    }

    /// Accent color (user-selected)
    static var accent: Color {
        let baseHex = selectedAccentColor.hexValue
        return highContrastEnabled ? Color(hex: 0x00FF00) : Color(hex: baseHex)
    }

    /// Golden color (special)
    static let golden = Color(hex: 0xFFD700)

    /// Purple color (special)
    static let purple = Color(hex: 0x8B5CF6)

    /// Status OK color
    static var statusOK: Color {
        Color(hex: selectedTheme.accentColor)
    }

    /// Status warning color
    static let statusWarn = Color(hex: 0xFFD700)

    /// Status error color
    static let statusError = Color(hex: 0xEF4444)
}

// MARK: - Color Extensions

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
