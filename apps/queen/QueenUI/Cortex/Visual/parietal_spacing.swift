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

    /// Alias for xxxxs - xxxfs (alternative naming)
    public static let xxxfs: CGFloat = 1

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

    // MARK: - Frame Sizes

    /// Frame width extra extra small - 1pt
    public static let frameWidthXXS: CGFloat = 1

    /// Frame width extra small - 2pt
    public static let frameWidthXS: CGFloat = 2

    /// Frame width small - 20pt
    public static let frameWidthSmall: CGFloat = 20

    /// Frame width medium - 40pt
    public static let frameWidthMedium: CGFloat = 40

    /// Frame width large - 80pt
    public static let frameWidthLarge: CGFloat = 80

    /// Frame width extra large - 100pt
    public static let frameWidthXL: CGFloat = 100

    /// Sidebar width - 280pt
    public static let sidebarWidth: CGFloat = 280

    /// Sidebar min width - 220pt
    public static let sidebarMinWidth: CGFloat = 220

    /// Sidebar max width - 400pt
    public static let sidebarMaxWidth: CGFloat = 400

    /// Modal width - 540pt
    public static let modalWidth: CGFloat = 540

    /// Modal max width - 600pt
    public static let modalMaxWidth: CGFloat = 600

    /// Cell minimum height - 44pt (touch target)
    public static let cellMinHeight: CGFloat = 44

    /// Row height - 48pt
    public static let rowHeight: CGFloat = 48

    /// Toolbar height - 44pt
    public static let toolbarHeight: CGFloat = 44

    /// Tab bar height - 49pt
    public static let tabBarHeight: CGFloat = 49

    /// Navigation bar height - 44pt
    public static let navigationBarHeight: CGFloat = 44

    /// Status bar height - 44pt
    public static let statusBarHeight: CGFloat = 44

    // MARK: - Component Frame Widths

    /// Icon button frame - 24pt
    public static let iconButtonFrame: CGFloat = 24

    /// Small icon frame - 28pt
    public static let smallIconFrame: CGFloat = 28

    /// Touch frame - 32pt
    public static let touchFrame: CGFloat = 32

    /// Standard frame - 40pt
    public static let standardFrame: CGFloat = 40

    /// Medium frame - 50pt
    public static let mediumFrame: CGFloat = 50

    /// Large frame - 60pt
    public static let largeFrame: CGFloat = 60

    /// Extra large frame - 80pt
    public static let xLargeFrame: CGFloat = 80

    /// XXL frame - 100pt
    public static let xxLargeFrame: CGFloat = 100

    /// XXXL frame - 120pt
    public static let xxxLargeFrame: CGFloat = 120

    /// Panel width - 280pt
    public static let panelWidth: CGFloat = 280

    /// Wide panel width - 320pt
    public static let widePanelWidth: CGFloat = 320

    /// Extra wide panel - 350pt
    public static let extraWidePanel: CGFloat = 350

    /// Sheet width - 400pt
    public static let sheetWidth: CGFloat = 400

    /// Wide sheet width - 500pt
    public static let wideSheetWidth: CGFloat = 500

    /// Extra wide sheet - 600pt
    public static let extraWideSheet: CGFloat = 600

    // MARK: - Small Component Sizes

    /// Divider thickness - 2pt
    public static let dividerThickness: CGFloat = 2

    /// Hairline width - 1pt
    public static let hairline: CGFloat = 1

    /// Small indicator - 3pt
    public static let smallIndicator: CGFloat = 3

    /// Micro indicator - 5pt
    public static let microIndicator: CGFloat = 5

    /// Dot size - 6pt
    public static let dotSize: CGFloat = 6

    /// Tiny indicator - 8pt
    public static let tinyIndicator: CGFloat = 8

    /// Small badge - 10pt
    public static let smallBadge: CGFloat = 10

    /// Medium badge - 12pt
    public static let mediumBadge: CGFloat = 12

    // MARK: - Additional Frame Sizes

    /// Extra small frame - 14pt
    public static let xSmallFrame: CGFloat = 14

    /// Small frame - 22pt
    public static let smallFrame: CGFloat = 22

    /// Compact frame - 26pt
    public static let compactFrame: CGFloat = 26

    /// Standard cell frame - 36pt
    public static let cellFrame: CGFloat = 36

    /// Button frame - 44pt
    public static let buttonFrame: CGFloat = 44

    /// Badge frame - 70pt
    public static let badgeFrame: CGFloat = 70

    /// Extra extra large frame - 160pt
    public static let extraLargeFrame: CGFloat = 160

    /// Modal frame - 200pt
    public static let modalFrame: CGFloat = 200

    /// Small modal frame - 250pt
    public static let smallModalFrame: CGFloat = 250

    /// Medium modal frame - 300pt
    public static let mediumModalFrame: CGFloat = 300

    /// Wide modal frame - 340pt
    public static let wideModalFrame: CGFloat = 340

    /// XL modal frame - 360pt
    public static let xlModalFrame: CGFloat = 360

    /// XXL modal frame - 380pt
    public static let xxlModalFrame: CGFloat = 380

    /// XXXL modal frame - 480pt
    public static let xxxlModalFrame: CGFloat = 480

    /// Extra wide modal - 560pt
    public static let extraWideModal: CGFloat = 560

    /// Large screen frame - 900pt
    public static let largeScreenFrame: CGFloat = 900

    /// Extra large screen frame - 1000pt
    public static let extraLargeScreenFrame: CGFloat = 1000

    /// Row width - 18pt
    public static let rowWidth: CGFloat = 18

    /// Chip width - 20pt
    public static let chipWidth: CGFloat = 20

    /// Avatar medium - 48pt
    public static let avatarMediumFrame: CGFloat = 48

    /// Compact panel - 180pt
    public static let compactPanel: CGFloat = 180

    // MARK: - Height Values

    /// Micro height - 4pt
    public static let microHeight: CGFloat = 4

    /// Small badge height - 9pt
    public static let smallBadgeHeight: CGFloat = 9

    /// Chip height - 24pt
    public static let chipHeight: CGFloat = 24

    /// Large modal height - 450pt
    public static let largeModalHeight: CGFloat = 450

    /// Extra large modal height - 500pt
    public static let extraLargeModalHeight: CGFloat = 500

    /// Caption height - 10pt
    public static let captionHeight: CGFloat = 10

    /// Badge height - 12pt
    public static let badgeHeight: CGFloat = 12

    /// Subtitle height - 14pt
    public static let subtitleHeight: CGFloat = 14

    /// Icon height - 20pt
    public static let iconHeight: CGFloat = 20

    /// Small button height - 28pt
    public static let smallButtonHeight: CGFloat = 28

    /// Item height - 40pt
    public static let itemHeight: CGFloat = 40

    /// Large button height - 56pt
    public static let largeButtonHeight: CGFloat = 56

    /// Large icon height - 85pt
    public static let largeIconHeight: CGFloat = 85

    /// Avatar small height - 88pt
    public static let avatarSmallHeight: CGFloat = 88

    /// Label height - 90pt
    public static let labelHeight: CGFloat = 90

    /// Extra label height - 95pt
    public static let extraLabelHeight: CGFloat = 95

    /// Extra icon height - 110pt
    public static let extraIconHeight: CGFloat = 110

    /// Small indicator height - 16pt
    public static let smallIndicatorHeight: CGFloat = 16

    /// Avatar height - 22pt
    public static let avatarHeight: CGFloat = 22

    /// Compact height - 26pt
    public static let compactHeight: CGFloat = 26

    /// Avatar large height - 36pt
    public static let avatarLargeHeight: CGFloat = 36

    /// Chart height - 150pt
    public static let chartHeight: CGFloat = 150

    /// Overlay height - 200pt
    public static let overlayHeight: CGFloat = 200

    /// Panel height - 280pt
    public static let panelHeight: CGFloat = 280

    /// Sheet height - 480pt
    public static let sheetHeight: CGFloat = 480

    // MARK: - Specific Component Heights

    /// Divider line height - 1pt
    public static let dividerHeight: CGFloat = 1

    /// Cursor/selection line height - 3pt
    public static let cursorLineHeight: CGFloat = 3

    /// Input bar height - 52pt
    public static let inputBarHeight: CGFloat = 52

    /// Toolbar minimum height - 30pt
    public static let toolbarMinHeight: CGFloat = 30

    /// Status indicator height - 6pt
    public static let statusIndicatorHeight: CGFloat = 6

    /// Chart panel height - 140pt
    public static let chartPanelHeight: CGFloat = 140

    /// Pipeline card height - 220pt
    public static let pipelineCardHeight: CGFloat = 220

    /// Alignment frame width - 44pt (for SettingsPanelsView)
    public static let alignmentFrameWidth: CGFloat = 44
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
