//
// V2 — Secondary Visual Cortex
// Depth perception, transparency, and layer processing
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - V2 Depth Processing Area

/// V2 — Secondary Visual Cortex in visual hierarchy
/// V2 processes depth, layers, and transparency information received from V1
///
/// Biologically, V2 is responsible for:
/// - Depth perception and binocular fusion
/// - Layer segregation (figure-ground)
/// - Transparent surfaces
///
/// In UI terms: opacity, z-index, modal backdrops, overlays
public enum V2Depth {

    // MARK: - Raw Depth Values

    /// Completely invisible
    public static let invisible: Double = 0.0

    /// Barely visible separator
    public static let ghost: Double = 0.02

    /// Card background (lighter)
    public static let hint: Double = 0.04

    /// Card background (normal)
    public static let tint: Double = 0.06

    /// Subtle background
    public static let wash: Double = 0.1

    /// Hover/selected background
    public static let overlay: Double = 0.15

    /// Disabled/muted state
    public static let muted: Double = 0.3

    /// Partially dimmed (modal backdrop)
    public static let dim: Double = 0.7

    /// Fully visible
    public static let solid: Double = 1.0

    // MARK: - Semantic Depth Tokens

    /// Disabled state for interactive elements
    public static var stateDisabled: Double { muted }

    /// Hover state for interactive elements
    public static var stateHover: Double { muted }

    /// Pressed/active state
    public static var statePressed: Double { muted }

    /// Background for sidebar items on hover
    public static var bgSidebarHover: Double { overlay }

    /// Background for subtle UI elements
    public static var bgSubtle: Double { wash }

    /// Background for cards and panels
    public static var bgCard: Double { tint }

    /// Background for lighter cards
    public static var bgCardLight: Double { hint }

    /// Modal backdrop dimming
    public static var modalBackdrop: Double { dim }

    /// Divider/separator lines
    public static var divider: Double { ghost }

    // MARK: - Component-Specific Depth

    /// Chat bubble background
    public static var chatBubble: Double { bgCard }

    /// Input placeholder text
    public static var inputPlaceholder: Double { stateDisabled }

    /// Message timestamp opacity
    public static var messageTimestamp: Double { stateDisabled }

    /// Button disabled state
    public static var buttonDisabled: Double { stateDisabled }

    /// Settings modal backdrop
    public static var settingsModal: Double { modalBackdrop }
}

// MARK: - Convenience Extensions

public extension V2Depth {

    /// Returns a color with this depth value applied
    static func apply(_ opacity: Double, to color: Color) -> Color {
        color.opacity(opacity)
    }

    /// Returns white with specified depth
    static func white(_ opacity: Double) -> Color {
        Color.white.opacity(opacity)
    }

    /// Returns black with specified depth
    static func black(_ opacity: Double) -> Color {
        Color.black.opacity(opacity)
    }
}

// MARK: - Predefined Color + Depth Combinations

public extension V2Depth {
    /// White at 10% (very subtle highlight)
    static var white10: Color { white(0.1) }

    /// White at 15% (subtle highlight)
    static var white15: Color { white(0.15) }

    /// White at 20% (subtle highlight)
    static var white20: Color { white(0.2) }

    /// White at 25% (medium highlight)
    static var white25: Color { white(0.25) }

    /// White at 30% (medium highlight)
    static var white30: Color { white(0.3) }

    /// White at 35% (medium-strong highlight)
    static var white35: Color { white(0.35) }

    /// White at 40% (strong highlight)
    static var white40: Color { white(0.4) }

    /// White at 50% (very strong highlight)
    static var white50: Color { white(0.5) }

    /// White at 60% (strong highlight)
    static var white60: Color { white(0.6) }

    /// Black at 15% (very subtle overlay)
    static var black15: Color { black(0.15) }

    /// Black at 20% (subtle overlay)
    static var black20: Color { black(0.2) }

    /// Black at 25% (medium overlay)
    static var black25: Color { black(0.25) }

    /// Black at 30% (subtle overlay)
    static var black30: Color { black(0.3) }

    /// Black at 35% (medium overlay)
    static var black35: Color { black(0.35) }

    /// Black at 40% (medium-strong overlay)
    static var black40: Color { black(0.4) }

    /// Black at 50% (medium overlay)
    static var black50: Color { black(0.5) }

    /// Black at 60% (strong overlay)
    static var black60: Color { black(0.6) }

    /// Black at 70% (modal backdrop)
    static var black70: Color { black(0.7) }

    /// Black at 80% (strong modal backdrop)
    static var black80: Color { black(0.8) }

    /// Black at 85% (strong modal backdrop)
    static var black85: Color { black(0.85) }

    /// Black at 90% (very strong modal backdrop)
    static var black90: Color { black(0.9) }
}
