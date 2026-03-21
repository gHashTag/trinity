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

    // MARK: - Micro Spacing Values

    /// Three point spacing - 3pt (between xxs and xxxs)
    public static let micro: CGFloat = 3

    /// Ten point spacing - 10pt
    public static let ten: CGFloat = 10

    /// Thirty point spacing - 30pt
    public static let thirty: CGFloat = 30

    // MARK: - Component-Specific Spacing

    /// Horizontal padding for buttons
    public static let buttonHorizontal: CGFloat = sm

    /// Vertical padding for buttons
    public static let buttonVertical: CGFloat = xs

    // MARK: - Icon Sizes
    public static let smallIconFrame: CGFloat = 16
    public static let icon: CGFloat = 20
    public static let iconLarge: CGFloat = 24
    public static let iconHeight: CGFloat = 20
    public static let largeIconHeight: CGFloat = 28
    public static let chipWidth: CGFloat = 32
    public static let extraIconHeight: CGFloat = 28
    public static let extraLargeFrame: CGFloat = 72

    // MARK: - Button Sizes
    public static let smallButtonHeight: CGFloat = 28
    public static let buttonHeight: CGFloat = 36
    public static let largeButtonHeight: CGFloat = 44
    public static let buttonMediumWidth: CGFloat = 100
    public static let buttonSmallWidth: CGFloat = 72
    public static let pipelineCardHeight: CGFloat = 64
    public static let statusDot: CGFloat = 8

    // MARK: - Touch Sizes
    public static let touchFrame: CGFloat = 44

    // MARK: - Avatar Sizes
    public static let avatarSmall: CGFloat = 24
    public static let avatarSmallHeight: CGFloat = 20
    public static let avatarMedium: CGFloat = 32
    public static let avatarMediumFrame: CGFloat = 32
    public static let avatarLarge: CGFloat = 48
    public static let avatarLargeHeight: CGFloat = 40
    public static let avatarHeight: CGFloat = 36

    // MARK: - Sheet Widths
    public static let wideSheetWidth: CGFloat = 600
    public static let sheetWidth: CGFloat = 500
    public static let extraWideSheet: CGFloat = 800

    // MARK: - Screen Frame Sizes
    public static let largeScreenFrame: CGFloat = 120

    // MARK: - Micro Height
    public static let microHeight: CGFloat = 4

    /// Horizontal padding for inputs
    public static let inputHorizontal: CGFloat = sm

    /// Vertical padding for inputs
    public static let inputVertical: CGFloat = xs

    /// Spacing between icon and text
    public static let iconText: CGFloat = xs

    /// Spacing between related elements
    public static let related: CGFloat = xs

    /// Spacing between unrelated elements
    public static let unrelated: CGFloat = md

    /// Spacing between sections
    public static let section: CGFloat = xl

    // MARK: - Height Values

    /// Audio player height - 180pt
    public static let audioPlayerHeight: CGFloat = 180

    /// Voice recorder height - 60pt
    public static let voiceRecorderHeight: CGFloat = 60

    /// Map preview height - 250pt
    public static let mapHeight: CGFloat = 250

    /// Map compact height - 120pt
    public static let mapCompactHeight: CGFloat = 120

    /// Search/results height - 400pt
    public static let searchResultsHeight: CGFloat = 400

    /// Typing indicator height - 10pt
    public static let typingIndicatorHeight: CGFloat = 10

    /// List component height - 80pt
    public static let listComponentHeight: CGFloat = 80

    /// Avatar frame height - 28pt
    public static let avatarFrameHeight: CGFloat = 28

    // MARK: - Additional Corner Radius Values

    /// Extra small corner radius - 1.5pt
    public static let cornerRadiusXSmall: CGFloat = 1.5

    /// Tiny corner radius - 2pt
    public static let cornerRadiusTiny: CGFloat = 2

    /// Small corner radius - 5pt
    public static let cornerRadiusSmall: CGFloat = 5

    /// Medium corner radius - 6pt
    public static let cornerRadiusMedium: CGFloat = 6

    /// Large corner radius - 8pt
    public static let cornerRadiusLarge: CGFloat = 8

    // MARK: - Frame Constraint Tokens

    /// Frame width zero - 0pt (for hiding)
    public static let frameWidthZero: CGFloat = 0

    /// Frame width tiny - 6pt
    public static let tinyIndicator: CGFloat = 6

    /// Frame width small - 12pt
    public static let smallFrame: CGFloat = 12
    public static let iconButtonFrame: CGFloat = 28
    public static let standardFrame: CGFloat = 24

    /// Frame width medium - 24pt
    public static let mediumFrame: CGFloat = 24

    /// Frame width large - 32pt
    public static let largeFrame: CGFloat = 32

    /// Frame width extra large - 48pt
    public static let xLargeFrame: CGFloat = 48

    /// Frame width extra extra large - 64pt
    public static let xxLargeFrame: CGFloat = 64
    public static let xxxLargeFrame: CGFloat = 96

    /// Status indicator height - 8pt
    public static let statusIndicatorHeight: CGFloat = 8

    // MARK: - Additional Frame Properties

    /// Panel width for sheet panels
    public static let panelWidth: CGFloat = 64
    public static let widePanelWidth: CGFloat = 80
    public static let compactPanel: CGFloat = 52
    public static let panelHeight: CGFloat = 56
    public static let chartPanelHeight: CGFloat = 200
    public static let dividerThickness: CGFloat = 1
    public static let dividerHeight: CGFloat = 1
    public static let inputBarHeight: CGFloat = 50
    public static let cursorLineHeight: CGFloat = 20
    public static let extraLargeScreenFrame: CGFloat = 900
    public static let toolbarMinHeight: CGFloat = 44
    public static let rowWidth: CGFloat = 60
    public static let smallBadge: CGFloat = 8
    public static let mediumBadge: CGFloat = 12
    public static let badgeHeight: CGFloat = 20
    public static let microIndicator: CGFloat = 3
    public static let captionHeight: CGFloat = 16
    public static let labelHeight: CGFloat = 18
    public static let extraLabelHeight: CGFloat = 22
    public static let subtitleHeight: CGFloat = 14
    public static let smallBadgeHeight: CGFloat = 12
    public static let cellFrame: CGFloat = 36
    public static let chipHeight: CGFloat = 20
    public static let xSmallFrame: CGFloat = 8
    public static let mediumModalFrame: CGFloat = 450
    public static let modalFrame: CGFloat = 300
    public static let smallModalFrame: CGFloat = 250
    public static let largeModalHeight: CGFloat = 400
    public static let xlModalFrame: CGFloat = 550
    public static let xxlModalFrame: CGFloat = 650
    public static let xxxlModalFrame: CGFloat = 750
    public static let sheetHeight: CGFloat = 500
    public static let hairline: CGFloat = 0.5
    public static let buttonFrame: CGFloat = 32
    public static let alignmentFrameWidth: CGFloat = 40
    public static let extraWideModal: CGFloat = 850
    public static let badgeFrame: CGFloat = 24

    /// Wide modal frame
    public static let wideModalFrame: CGFloat = 72

    /// Dot size for loading indicators
    public static let dotSize: CGFloat = 4

    /// Small indicator height
    public static let smallIndicatorHeight: CGFloat = 2

    /// Extra wide panel
    public static let extraWidePanel: CGFloat = 96

    /// Small indicator for StatCard
    public static let smallIndicator: CGFloat = 6

    /// Frame height tiny - 6pt
    public static let frameHeightTiny: CGFloat = 6

    /// Frame height small - 12pt
    public static let frameHeightSmall: CGFloat = 12

    /// Frame height medium - 100pt
    public static let frameHeightMedium: CGFloat = 100

    /// Frame height large - 120pt
    public static let frameHeightLarge: CGFloat = 120

    /// Frame height XL - 160pt
    public static let frameHeightXL: CGFloat = 160

    /// Frame height XXL - 180pt
    public static let frameHeightXXL: CGFloat = 180

    /// Frame height XXXL - 300pt
    public static let frameHeightXXXL: CGFloat = 300
    public static let itemHeight: CGFloat = 24
    public static let extraLargeModalHeight: CGFloat = 700

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

