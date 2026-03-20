//
// Posterior Parietal Cortex — Spatial Perception
// Defines spacing tokens for layout
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Parietal Spacing

/// Posterior Parietal Cortex — Spatial Perception
///
/// The parietal lobe processes spatial information and sensory integration.
/// This file defines spacing tokens for consistent layout throughout Trinity UI.
///
/// Spacing follows a base-2 scale (4, 8, 16, 24, 32, 48) for visual harmony.
public enum ParietalSpacing {

    // MARK: - Base Scale

    /// Extra extra small spacing - 4pt
    public static let xxs: CGFloat = 4

    /// Extra extra extra small spacing - 2pt (very tight)
    public static let xxxs: CGFloat = 2

    /// Extra extra extra extra small spacing - 1pt (micro spacing)
    public static let xxxxs: CGFloat = 1

    /// Extra small spacing - 8pt
    public static let xs: CGFloat = 8

    /// Small spacing - 12pt
    public static let sm: CGFloat = 12

    /// Medium spacing - 16pt (base unit)
    public static let md: CGFloat = 16

    /// Large spacing - 24pt
    public static let lg: CGFloat = 24

    /// Extra large spacing - 32pt
    public static let xl: CGFloat = 32

    /// Extra extra large spacing - 48pt
    public static let xxl: CGFloat = 48

    // MARK: - Named Spacing

    /// Compact spacing for tight layouts
    public static let compact: CGFloat = xs

    /// Standard spacing for most UI elements
    public static let standard: CGFloat = md

    /// Comfortable spacing for breathing room
    public static let comfortable: CGFloat = lg

    /// Spacious spacing for section separation
    public static let spacious: CGFloat = xl

    // MARK: - Component-Specific Spacing

    /// Horizontal padding for buttons
    public static let buttonHorizontal: CGFloat = sm

    /// Vertical padding for buttons
    public static let buttonVertical: CGFloat = xs

    /// Horizontal padding for inputs
    public static let inputHorizontal: CGFloat = sm

    /// Vertical padding for inputs
    public static let inputVertical: CGFloat = xs

    /// Horizontal padding for cards
    public static let cardHorizontal: CGFloat = md

    /// Vertical padding for cards
    public static let cardVertical: CGFloat = md

    /// Horizontal padding for lists
    public static let listHorizontal: CGFloat = md

    /// Vertical padding for list items
    public static let listVertical: CGFloat = sm

    /// Spacing between icon and text
    public static let iconText: CGFloat = xs

    /// Spacing between related elements
    public static let related: CGFloat = xs

    /// Spacing between unrelated elements
    public static let unrelated: CGFloat = md

    /// Spacing between sections
    public static let section: CGFloat = xl

    // MARK: - Layout Constants

    /// Minimum touch target size (accessibility)
    public static let minTouchTarget: CGFloat = 44

    /// Standard border radius
    public static let cornerRadius: CGFloat = 10

    /// Card corner radius
    public static let cardCornerRadius: CGFloat = 12

    // MARK: - Helper Functions

    /// Returns spacing scaled by a factor
    public static func scaled(_ base: CGFloat, by factor: CGFloat) -> CGFloat {
        base * factor
    }

    /// Returns spacing for a given size category
    public static func spacing(for size: SizeCategory) -> CGFloat {
        switch size {
        case .compact: return xs
        case .regular: return md
        case .spacious: return lg
        }
    }

    /// Size categories for spacing
    public enum SizeCategory {
        case compact
        case regular
        case spacious
    }

    // MARK: - Common Size Tokens

    /// Icon size - 16pt
    public static let icon: CGFloat = 16

    /// Large icon size - 24pt
    public static let iconLarge: CGFloat = 24

    /// Small icon size - 12pt
    public static let iconSmall: CGFloat = 12

    /// Touch target minimum - 44pt (accessibility)
    public static let touchMin: CGFloat = 44

    /// Button height - 36pt
    public static let buttonHeight: CGFloat = 36

    /// Button small width - 20pt
    public static let buttonSmallWidth: CGFloat = 20

    /// Button medium width - 40pt
    public static let buttonMediumWidth: CGFloat = 40

    /// Input height - 36pt
    public static let inputHeight: CGFloat = 36

    /// Status dot size - 8pt
    public static let statusDot: CGFloat = 8

    /// Avatar size small - 32pt
    public static let avatarSmall: CGFloat = 32

    /// Avatar size medium - 48pt
    public static let avatarMedium: CGFloat = 48

    /// Avatar size large - 64pt
    public static let avatarLarge: CGFloat = 64

    /// Separator height - 1pt
    public static let separator: CGFloat = 1

    /// Border width - 1pt
    public static let borderWidth: CGFloat = 1

    /// Progress bar height - 4pt
    public static let progressHeight: CGFloat = 4

    /// Slider track height - 4pt
    public static let sliderTrack: CGFloat = 4
}

// MARK: - Spacing View Extensions

extension View {

    /// Applies padding using Parietal spacing tokens
    @ViewBuilder
    func padding(_ spacing: ParietalSpacingToken) -> some View {
        padding(spacing.rawValue)
    }

    /// Applies horizontal padding using Parietal spacing
    @ViewBuilder
    func paddingHorizontal(_ spacing: ParietalSpacingToken) -> some View {
        padding(.horizontal, spacing.rawValue)
    }

    /// Applies vertical padding using Parietal spacing
    @ViewBuilder
    func paddingVertical(_ spacing: ParietalSpacingToken) -> some View {
        padding(.vertical, spacing.rawValue)
    }
}

// MARK: - Spacing Tokens Enum

/// Individual spacing token values
public enum ParietalSpacingToken {
    case xxs
    case xs
    case sm
    case md
    case lg
    case xl
    case xxl

    var rawValue: CGFloat {
        switch self {
        case .xxs: return ParietalSpacing.xxs
        case .xs: return ParietalSpacing.xs
        case .sm: return ParietalSpacing.sm
        case .md: return ParietalSpacing.md
        case .lg: return ParietalSpacing.lg
        case .xl: return ParietalSpacing.xl
        case .xxl: return ParietalSpacing.xxl
        }
    }
}

// MARK: - Legacy Compatibility

/// Extension to provide legacy LayoutConstants - will be deprecated
extension ParietalSpacing {
    /// Legacy alias for md (backward compatibility)
    @available(*, deprecated, message: "Use md instead")
    public static let medium: CGFloat = md

    public static let legacyCompactSpacing: CGFloat = ParietalSpacing.xxs
    public static let legacyStandardPadding: CGFloat = ParietalSpacing.md
    public static let legacyDoublePadding: CGFloat = ParietalSpacing.xl
}
