//
// V4 — Color Processing Area
// Extracts color tokens for semantic UI colors
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - V4 Color Processing Area

/// V4 — Color Processing Area in visual cortex
/// V4 processes color and form information received from V1
///
/// This file defines semantic color tokens used throughout Trinity Queen UI.
/// Colors are organized by purpose (background, surface, text, interactive, etc.)
public enum V4Color {

    // MARK: - Background Colors

    /// Primary window background - deepest layer
    public static var background: Color {
        V1Theme.bgWindow
    }

    /// Secondary background for panels and cards
    public static var surface: Color {
        V1Theme.bgCard
    }

    /// Elevated surface (third layer)
    public static var surfaceElevated: Color {
        Color(white: 0.1, opacity: 1.0)
    }

    /// Sidebar background
    public static var sidebar: Color {
        V1Theme.bgSidebar
    }

    /// Input background
    public static var input: Color {
        Color(white: 0.1, opacity: 1.0)
    }

    // MARK: - Text Colors

    /// Primary text - highest contrast
    public static var textPrimary: Color {
        V1Theme.textPrimary
    }

    /// Secondary text - reduced contrast
    public static var textSecondary: Color {
        V1Theme.textMuted
    }

    /// Tertiary text - lowest contrast
    public static var textTertiary: Color {
        Color(white: 0.4, opacity: 1.0)
    }

    /// Text on accent color (should be white)
    public static var textOnAccent: Color {
        .white
    }

    /// Text for links
    public static var textLink: Color {
        V1Theme.accent
    }

    /// Text for errors
    public static var textError: Color {
        error
    }

    /// Text for warnings
    public static var textWarning: Color {
        warning
    }

    /// Text for success
    public static var textSuccess: Color {
        success
    }

    // MARK: - Border Colors

    /// Default border - subtle
    public static var border: Color {
        Color.white.opacity(0.08)
    }

    /// Border for focused elements
    public static var borderFocus: Color {
        V1Theme.accent.opacity(V2Depth.stateDisabled)
    }

    /// Border for error states
    public static var borderError: Color {
        error.opacity(V2Depth.stateDisabled)
    }

    /// Border for disabled elements
    public static var borderDisabled: Color {
        Color.white.opacity(0.05)
    }

    // MARK: - Interactive States

    /// Hover state background
    public static var hover: Color {
        Color.white.opacity(V2Depth.bgSubtle)
    }

    /// Hover state on accent
    public static var hoverAccent: Color {
        V1Theme.accent.opacity(0.2)
    }

    /// Active/pressed state
    public static var active: Color {
        Color.white.opacity(V2Depth.bgSidebarHover)
    }

    /// Focus ring
    public static var focus: Color {
        Color.accentColor.opacity(V2Depth.stateHover)
    }

    /// Selected state background
    public static var selected: Color {
        V1Theme.accent.opacity(V2Depth.bgSidebarHover)
    }

    // MARK: - Accent Colors

    /// Primary accent color (user-selected)
    public static var accent: Color {
        V1Theme.accent
    }

    /// Accent color with reduced opacity
    public static func accentOpacity(_ opacity: Double) -> Color {
        accent.opacity(opacity)
    }

    // MARK: - Status Colors

    /// Error/danger color
    public static var error: Color {
        V1Theme.statusError
    }

    /// Warning color
    public static var warning: Color {
        V1Theme.statusWarn
    }

    /// Success color
    public static var success: Color {
        V1Theme.statusOK
    }

    /// Info color
    public static var info: Color {
        Color(hex: 0x00D9FF)
    }

    // MARK: - Semantic Colors

    /// Color for Brain realm (RAZUM)
    public static let brain = Color(red: 1.0, green: 215.0/255.0, blue: 0)

    /// Color for Body realm (MATERIYA)
    public static let body = Color(red: 80.0/255.0, green: 250.0/255.0, blue: 250.0/255.0)

    /// Color for Spirit realm (DUKH)
    public static let spirit = Color(red: 189.0/255.0, green: 147.0/255.0, blue: 249.0/255.0)

    // MARK: - Special Colors

    /// Golden color (φ-related)
    public static let golden = V1Theme.golden

    /// Purple color (special)
    public static let purple = V1Theme.purple

    // MARK: - Status Colors (Direct TrinityTheme Bridge)

    /// Status OK color (matches TrinityTheme.statusOK)
    public static var statusOK: Color {
        V1Theme.statusOK
    }

    /// Status warning color (matches TrinityTheme.statusWarn)
    public static let statusWarn = V1Theme.statusWarn

    /// Status error color (matches TrinityTheme.statusError)
    public static let statusError = V1Theme.statusError

    // MARK: - Background Colors (Direct TrinityTheme Bridge)

    /// Window background (matches TrinityTheme.bgWindow)
    public static var bgWindow: Color {
        V1Theme.bgWindow
    }

    /// Card background (matches TrinityTheme.bgCard)
    public static var bgCard: Color {
        V1Theme.bgCard
    }

    /// Sidebar background (matches TrinityTheme.bgSidebar)
    public static var bgSidebar: Color {
        V1Theme.bgSidebar
    }

    /// Card border (matches TrinityTheme.bgCardBorder)
    public static var bgCardBorder: Color {
        V1Theme.bgCardBorder
    }

    // MARK: - Overlay Colors

    /// Dim overlay (for modals, sheets)
    public static var overlay: Color {
        Color.black.opacity(V1Theme.opacityTextSecondary)
    }

    /// Toast overlay
    public static var toastOverlay: Color {
        Color.black.opacity(0.8)
    }

    /// Tooltip background
    public static var tooltip: Color {
        Color(white: 0.1, opacity: 1.0)
    }

    // MARK: - Gradient Helpers

    /// Creates a gradient from accent color
    public static func accentGradient(start: UnitPoint = .topLeading, end: UnitPoint = .bottomTrailing) -> LinearGradient {
        LinearGradient(
            colors: [accent, accentOpacity(0.7)],
            startPoint: start,
            endPoint: end
        )
    }

    /// Creates a subtle gradient for backgrounds
    public static func subtleGradient(start: UnitPoint = .top, end: UnitPoint = .bottom) -> LinearGradient {
        LinearGradient(
            colors: [
                Color(white: 0.1, opacity: 1.0),
                Color(white: 0.04, opacity: 1.0)
            ],
            startPoint: start,
            endPoint: end
        )
    }
}

// MARK: - High Contrast Variants

extension V4Color {

    /// High contrast color variants
    public enum HighContrast {

        /// Maximum contrast background
        public static var background: Color {
            .black
        }

        /// Maximum contrast surface
        public static var surface: Color {
            Color(hex: 0x1A1A1A)
        }

        /// Maximum contrast text
        public static var textPrimary: Color {
            .white
        }

        /// Maximum contrast text secondary
        public static var textSecondary: Color {
            Color(hex: 0xD0D0D0)
        }

        /// Maximum contrast border
        public static var border: Color {
            .white
        }

        /// Maximum contrast accent
        public static var accent: Color {
            Color(hex: 0x00FF00)
        }

        /// Maximum contrast error
        public static var error: Color {
            Color(hex: 0xFF0000)
        }

        /// Maximum contrast warning
        public static var warning: Color {
            Color(hex: 0xFFAA00)
        }

        /// Maximum contrast success
        public static var success: Color {
            Color(hex: 0x00FF00)
        }
    }

    /// Returns high contrast variant if enabled
    public static func adaptive(_ standard: Color, highContrast: Color) -> Color {
        V1Theme.highContrastEnabled ? highContrast : standard
    }

    /// Returns adaptive background color
    public static var adaptiveBackground: Color {
        adaptive(background, highContrast: HighContrast.background)
    }

    /// Returns adaptive text primary color
    public static var adaptiveTextPrimary: Color {
        adaptive(textPrimary, highContrast: HighContrast.textPrimary)
    }

    /// Returns adaptive text secondary color
    public static var adaptiveTextSecondary: Color {
        adaptive(textSecondary, highContrast: HighContrast.textSecondary)
    }

    /// Returns adaptive border color
    public static var adaptiveBorder: Color {
        adaptive(border, highContrast: HighContrast.border)
    }

    /// Returns adaptive accent color
    public static var adaptiveAccent: Color {
        adaptive(accent, highContrast: HighContrast.accent)
    }

    /// Returns adaptive error color
    public static var adaptiveError: Color {
        adaptive(error, highContrast: HighContrast.error)
    }

    /// Returns adaptive warning color
    public static var adaptiveWarning: Color {
        adaptive(warning, highContrast: HighContrast.warning)
    }

    /// Returns adaptive success color
    public static var adaptiveSuccess: Color {
        adaptive(success, highContrast: HighContrast.success)
    }
}

// MARK: - Opacity Helpers

extension V4Color {

    /// Returns text color with specified opacity
    public static func text(_ opacity: Double) -> Color {
        textPrimary.opacity(opacity)
    }

    /// Returns border color with specified opacity
    public static func border(_ opacity: Double) -> Color {
        border.opacity(opacity)
    }

    /// Returns black overlay with specified opacity
    public static func overlay(_ opacity: Double) -> Color {
        Color.black.opacity(opacity)
    }

    /// Returns white overlay with specified opacity
    public static func whiteOverlay(_ opacity: Double) -> Color {
        Color.white.opacity(opacity)
    }

    /// White at 10% opacity (very subtle highlight)
    public static var white10: Color { Color.white.opacity(0.1) }

    /// White at 15% opacity (subtle highlight)
    public static var white15: Color { Color.white.opacity(0.15) }

    /// White at 20% opacity (subtle highlight)
    public static var white20: Color { Color.white.opacity(0.2) }

    /// White at 35% opacity (medium-strong highlight)
    public static var white35: Color { Color.white.opacity(0.35) }

    /// White at 30% opacity (medium highlight)
    public static var white30: Color { Color.white.opacity(0.3) }

    /// White at 40% opacity (strong highlight)
    public static var white40: Color { Color.white.opacity(0.4) }

    /// White at 50% opacity (very strong highlight)
    public static var white50: Color { Color.white.opacity(0.5) }

    /// White at 60% opacity (strong highlight)
    public static var white60: Color { Color.white.opacity(0.6) }

    /// White at 70% opacity (strong highlight)
    public static var white70: Color { Color.white.opacity(0.7) }

    /// White at 80% opacity (strong highlight)
    public static var white80: Color { Color.white.opacity(0.8) }

    /// Black at 30% opacity (subtle overlay)
    public static var black30: Color { Color.black.opacity(0.3) }

    /// Black at 50% opacity (medium overlay)
    public static var black50: Color { Color.black.opacity(0.5) }

    /// Black at 15% opacity (very subtle overlay)
    public static var black15: Color { Color.black.opacity(0.15) }

    /// Black at 20% opacity (subtle overlay)
    public static var black20: Color { Color.black.opacity(0.2) }

    /// Black at 25% opacity (medium overlay)
    public static var black25: Color { Color.black.opacity(0.25) }

    /// Black at 35% opacity (medium overlay)
    public static var black35: Color { Color.black.opacity(0.35) }

    /// Black at 40% opacity (strong overlay)
    public static var black40: Color { Color.black.opacity(0.4) }

    // MARK: - Common Opacity Values

    /// 5% opacity - very subtle
    public static var opacity5: Double { 0.05 }

    /// 8% opacity
    public static var opacity8: Double { 0.08 }

    /// 10% opacity - subtle
    public static var opacity10: Double { 0.1 }

    /// 15% opacity
    public static let opacity15: Double = 0.15

    /// 20% opacity - medium
    public static var opacity20: Double { 0.2 }

    /// 25% opacity
    public static var opacity25: Double { 0.25 }

    /// 30% opacity
    public static let opacity30: Double = 0.3

    /// 35% opacity
    public static var opacity35: Double { 0.35 }

    /// 40% opacity
    public static var opacity40: Double { 0.4 }

    /// 50% opacity - half
    public static let opacity50: Double = 0.5

    /// 60% opacity
    public static var opacity60: Double { 0.6 }

    /// 70% opacity
    public static var opacity70: Double { 0.7 }

    /// 80% opacity
    public static var opacity80: Double { 0.8 }

    /// 90% opacity - mostly visible
    public static var opacity90: Double { 0.9 }

    /// 4% opacity - extremely subtle
    public static var opacity4: Double { 0.04 }

    /// 6% opacity
    public static var opacity6: Double { 0.06 }

    /// 12% opacity
    public static var opacity12: Double { 0.12 }
}
