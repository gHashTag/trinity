//
// Wernicke's Area — Language Comprehension
// Defines typography tokens for text rendering
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Wernicke Typography

/// Wernicke's Area — Language Comprehension
///
/// Wernicke's area is responsible for language comprehension.
/// This file defines typography tokens for consistent text rendering.
///
/// Font sizes follow a modular scale (1.25 ratio) for visual harmony.
public enum WernickeTypography {

    // MARK: - Font Sizes

    /// Extra extra large display text - 34pt
    public static var h1: Font { .system(size: 34, weight: .bold) }

    /// Extra extra large display - 48pt (hero numbers)
    public static var display: Font { .system(size: 48, weight: .bold) }

    /// Display 48pt without explicit weight (uses default)
    public static var display48: Font { .system(size: 48) }

    /// Extra large heading - 28pt
    public static var h2: Font { .system(size: 28, weight: .bold) }

    /// Large heading - 22pt
    public static var h3: Font { .system(size: 22, weight: .semibold) }

    /// Medium heading - 18pt
    public static var h4: Font { .system(size: 18, weight: .semibold) }

    /// Small heading - 16pt
    public static var h5: Font { .system(size: 16, weight: .medium) }

    /// Body text - 15pt (default)
    public static var body: Font { .system(size: 15, weight: .regular) }

    /// Small body text - 13pt
    public static var small: Font { .system(size: 13, weight: .regular) }

    /// Caption text - 12pt
    public static var caption: Font { .system(size: 12, weight: .regular) }

    /// Caption 2 text - 11pt (secondary caption)
    public static var caption2: Font { .system(size: 11, weight: .regular) }

    /// Tiny text - 11pt
    public static var tiny: Font { .system(size: 11, weight: .regular) }

    /// Micro text - 9pt (very small labels)
    public static var micro: Font { .system(size: 9, weight: .regular) }

    /// Mini text - 10pt (small labels)
    public static var mini: Font { .system(size: 10, weight: .regular) }

    /// Tiny8 text - 8pt (extra small labels)
    public static var tiny8: Font { .system(size: 8, weight: .regular) }

    /// Icon label text - 14pt
    public static var iconLabel: Font { .system(size: 14, weight: .medium) }

    // MARK: - Weight Variants

    /// Caption with medium weight - 12pt
    public static var captionMedium: Font { .system(size: 12, weight: .medium) }

    /// Caption with bold weight - 12pt
    public static var captionBold: Font { .system(size: 12, weight: .bold) }

    /// Caption2 with bold weight - 11pt
    public static var caption2Bold: Font { .system(size: 11, weight: .bold) }

    /// Caption2 with medium weight - 11pt
    public static var caption2Medium: Font { .system(size: 11, weight: .medium) }

    /// Mini with medium weight - 10pt
    public static var miniMedium: Font { .system(size: 10, weight: .medium) }

    /// Mini with bold weight - 10pt
    public static var miniBold: Font { .system(size: 10, weight: .bold) }

    /// Mini with semibold weight - 10pt
    public static var miniSemibold: Font { .system(size: 10, weight: .semibold) }

    /// Micro with medium weight - 9pt
    public static var microMedium: Font { .system(size: 9, weight: .medium) }

    /// Micro with bold weight - 9pt
    public static var microBold: Font { .system(size: 9, weight: .bold) }

    /// Micro with semibold weight - 9pt
    public static var microSemibold: Font { .system(size: 9, weight: .semibold) }

    /// Small with medium weight - 13pt
    public static var smallMedium: Font { .system(size: 13, weight: .medium) }

    /// Body with medium weight - 15pt
    public static var bodyMedium: Font { .system(size: 15, weight: .medium) }

    /// H5 with bold weight - 16pt
    public static var h5Bold: Font { .system(size: 16, weight: .bold) }

    /// Title3 with bold weight - 14pt
    public static var title3Bold: Font { .system(size: 14, weight: .bold) }

    // MARK: - Monospace Variants

    /// Micro monospace - 9pt
    public static var microMono: Font { .system(size: 9, weight: .medium, design: .monospaced) }

    /// Mini monospace - 10pt
    public static var miniMono: Font { .system(size: 10, weight: .medium, design: .monospaced) }

    /// Caption monospace - 12pt
    public static var captionMono: Font { .system(size: 12, weight: .medium, design: .monospaced) }

    // MARK: - Additional Common Sizes

    /// 16pt body (slightly larger than standard)
    public static var body16: Font { .system(size: 16, weight: .regular) }

    /// 16pt medium
    public static var body16Medium: Font { .system(size: 16, weight: .medium) }

    /// 14pt medium
    public static var body14Medium: Font { .system(size: 14, weight: .medium) }

    /// 16pt bold
    public static var body16Bold: Font { .system(size: 16, weight: .bold) }

    /// 17pt body (Apple's standard body)
    public static var body17: Font { .system(size: 17, weight: .regular) }

    /// 18pt semibold
    public static var h4Semibold: Font { .system(size: 18, weight: .semibold) }

    /// 20pt semibold
    public static var h5Semibold: Font { .system(size: 20, weight: .semibold) }

    /// 11pt semibold
    public static var caption2Semibold: Font { .system(size: 11, weight: .semibold) }

    /// 10pt bold monospace
    public static var miniBoldMono: Font { .system(size: 10, weight: .bold, design: .monospaced) }

    /// 9pt bold monospace
    public static var microBoldMono: Font { .system(size: 9, weight: .bold, design: .monospaced) }

    /// 13pt bold
    public static var smallBold: Font { .system(size: 13, weight: .bold) }

    /// 13pt semibold
    public static var smallSemibold: Font { .system(size: 13, weight: .semibold) }

    // MARK: - Rare Sizes

    /// 8pt medium (tiny8 medium)
    public static var tiny8Medium: Font { .system(size: 8, weight: .medium) }

    /// 8pt bold
    public static var tiny8Bold: Font { .system(size: 8, weight: .bold) }

    /// 14pt semibold
    public static var body14Semibold: Font { .system(size: 14, weight: .semibold) }

    /// 24pt bold
    public static var h3Bold: Font { .system(size: 24, weight: .bold) }

    /// 28pt semibold
    public static var h2Semibold: Font { .system(size: 28, weight: .semibold) }

    /// 48pt rounded
    public static var displayRounded: Font { .system(size: 48, weight: .bold, design: .rounded) }

    /// 13pt semibold monospace
    public static var smallSemiboldMono: Font { .system(size: 13, weight: .semibold, design: .monospaced) }

    /// 12pt semibold monospace
    public static var captionSemiboldMono: Font { .system(size: 12, weight: .semibold, design: .monospaced) }

    /// 11pt bold monospace
    public static var caption2BoldMono: Font { .system(size: 11, weight: .bold, design: .monospaced) }

    /// 11pt medium monospace
    public static var caption2MediumMono: Font { .system(size: 11, weight: .medium, design: .monospaced) }

    /// 8pt bold monospace
    public static var tiny8BoldMono: Font { .system(size: 8, weight: .bold, design: .monospaced) }

    // MARK: - Default Weight Variants (no explicit weight)

    /// 48pt default weight
    public static var size48: Font { .system(size: 48) }

    /// 32pt default weight
    public static var size32: Font { .system(size: 32) }

    /// 24pt default weight
    public static var size24: Font { .system(size: 24) }

    /// 20pt default weight
    public static var size20: Font { .system(size: 20) }

    /// 18pt default weight
    public static var size18: Font { .system(size: 18) }

    /// 16pt default weight
    public static var size16: Font { .system(size: 16) }

    /// 15pt default weight
    public static var size15: Font { .system(size: 15) }

    /// 14pt default weight
    public static var size14: Font { .system(size: 14) }

    /// 13pt default weight
    public static var size13: Font { .system(size: 13) }

    /// 12pt default weight
    public static var size12: Font { .system(size: 12) }

    /// 11pt default weight
    public static var size11: Font { .system(size: 11) }

    /// 10pt default weight
    public static var size10: Font { .system(size: 10) }

    /// 9pt default weight
    public static var size9: Font { .system(size: 9) }

    /// 8pt default weight
    public static var size8: Font { .system(size: 8) }

    /// 7pt default weight
    public static var size7: Font { .system(size: 7) }

    /// 6pt default weight
    public static var size6: Font { .system(size: 6) }

    /// 56pt default weight
    public static var size56: Font { .system(size: 56) }

    /// 40pt default weight
    public static var size40: Font { .system(size: 40) }

    /// 28pt default weight
    public static var size28: Font { .system(size: 28) }

    /// 17pt default weight
    public static var size17: Font { .system(size: 17) }

    /// 36pt light weight
    public static var size36Light: Font { .system(size: 36, weight: .light) }

    /// 34pt medium weight
    public static var size34Medium: Font { .system(size: 34, weight: .medium) }

    /// 32pt medium weight
    public static var size32Medium: Font { .system(size: 32, weight: .medium) }

    /// 18pt medium weight
    public static var size18Medium: Font { .system(size: 18, weight: .medium) }

    /// 11pt semibold weight
    public static var size11Semibold: Font { .system(size: 11, weight: .semibold) }

    // MARK: - Monospace Default Weight

    /// 12pt monospace default weight
    public static var size12Mono: Font { .system(size: 12, design: .monospaced) }

    /// 11pt monospace default weight
    public static var size11Mono: Font { .system(size: 11, design: .monospaced) }

    /// 10pt monospace default weight
    public static var size10Mono: Font { .system(size: 10, design: .monospaced) }

    /// 9pt monospace default weight
    public static var size9Mono: Font { .system(size: 9, design: .monospaced) }

    /// 8pt monospace default weight
    public static var size8Mono: Font { .system(size: 8, design: .monospaced) }

    // MARK: - Font Weights

    /// Thin font weight
    public static var thin: Font.Weight { .thin }

    /// Light font weight
    public static var light: Font.Weight { .light }

    /// Regular font weight
    public static var regular: Font.Weight { .regular }

    /// Medium font weight
    public static var medium: Font.Weight { .medium }

    /// Semibold font weight
    public static var semibold: Font.Weight { .semibold }

    /// Bold font weight
    public static var bold: Font.Weight { .bold }

    /// Heavy font weight
    public static var heavy: Font.Weight { .heavy }

    // MARK: - Composite Fonts

    /// Display font for large titles
    public static func display(size: CGFloat = 34) -> Font {
        .system(size: size, weight: .bold, design: .rounded)
    }

    /// Title font for headings
    public static func title(size: CGFloat = 22) -> Font {
        .system(size: size, weight: .semibold)
    }

    /// Emphasized body text
    public static var bodyEmphasized: Font {
        .system(size: 15, weight: .medium)
    }

    /// Code/monospace font
    public static func code(size: CGFloat = 13) -> Font {
        .system(size: size, design: .monospaced)
    }

    /// Tabular numbers font
    public static func tabular(size: CGFloat = 15) -> Font {
        .system(size: size, design: .monospaced)
    }

    // MARK: - Line Heights

    /// Tight line height (1.2x)
    public static let lineHeightTight: CGFloat = 1.2

    /// Normal line height (1.5x)
    public static let lineHeightNormal: CGFloat = 1.5

    /// Relaxed line height (1.75x)
    public static let lineHeightRelaxed: CGFloat = 1.75

    // MARK: - Letter Spacing

    /// Tight letter spacing (-0.5%)
    public static let letterSpacingTight: CGFloat = -0.005

    /// Normal letter spacing (0%)
    public static let letterSpacingNormal: CGFloat = 0

    /// Wide letter spacing (0.5%)
    public static let letterSpacingWide: CGFloat = 0.005

    // MARK: - Dynamic Type Support

    /// Returns body size for current dynamic type category
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

    /// Returns caption size for current dynamic type category
    public static func captionSize(_ sizeCategory: DynamicTypeSize = .medium) -> CGFloat {
        max(bodySize(sizeCategory) - 4, 9)
    }

    /// Returns heading size for current dynamic type category
    public static func headingSize(_ sizeCategory: DynamicTypeSize = .medium) -> CGFloat {
        bodySize(sizeCategory) + 5
    }
}

// MARK: - Typography View Extensions

extension View {

    /// Applies heading font
    @ViewBuilder
    func fontHeading(_ level: Int = 1) -> some View {
        switch level {
        case 1: font(WernickeTypography.h1)
        case 2: font(WernickeTypography.h2)
        case 3: font(WernickeTypography.h3)
        case 4: font(WernickeTypography.h4)
        case 5: font(WernickeTypography.h5)
        default: font(WernickeTypography.h3)
        }
    }

    /// Applies body font
    @ViewBuilder
    func fontBody() -> some View {
        font(WernickeTypography.body)
    }

    /// Applies caption font
    @ViewBuilder
    func fontCaption() -> some View {
        font(WernickeTypography.caption)
    }

    /// Applies code font
    @ViewBuilder
    func fontCode(size: CGFloat = 13) -> some View {
        font(WernickeTypography.code(size: size))
    }
}

// MARK: - Text Styles

/// Predefined text styles for common use cases
public enum WernickeTextStyle {
    case largeTitle
    case title1
    case title2
    case title3
    case headline
    case body
    case callout
    case subheadline
    case footnote
    case caption1
    case caption2

    var font: Font {
        switch self {
        case .largeTitle: return .system(size: 34, weight: .bold)
        case .title1: return .system(size: 28, weight: .bold)
        case .title2: return .system(size: 22, weight: .semibold)
        case .title3: return .system(size: 20, weight: .semibold)
        case .headline: return .system(size: 17, weight: .semibold)
        case .body: return .system(size: 17, weight: .regular)
        case .callout: return .system(size: 16, weight: .regular)
        case .subheadline: return .system(size: 15, weight: .regular)
        case .footnote: return .system(size: 13, weight: .regular)
        case .caption1: return .system(size: 12, weight: .regular)
        case .caption2: return .system(size: 11, weight: .regular)
        }
    }
}

extension View {

    /// Applies a predefined text style
    @ViewBuilder
    func textStyle(_ style: WernickeTextStyle) -> some View {
        font(style.font)
    }
}
