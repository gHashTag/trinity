import SwiftUI

// Theme from src/trinity_node/ui.zig THEME struct
struct TrinityTheme {
    static let bgWindow    = Color(hex: 0x000000)
    static let bgSidebar   = Color(hex: 0x050505)
    static let bgCard      = Color(hex: 0x0A0A0A)
    static let accent      = Color(hex: 0x00FF88)
    static let golden      = Color(hex: 0xFFD700)
    static let purple      = Color(hex: 0x8B5CF6)
    static let textPrimary = Color.white
    static let textMuted   = Color(hex: 0xAAAAAA)  // raised from 0x888888 for WCAG AA (6.5:1 on black)
    static let statusOK    = Color(hex: 0x00FF88)
    static let statusWarn  = Color(hex: 0xFFD700)
    static let statusError = Color(hex: 0xEF4444)

    static let bgCardBorder = Color(hex: 0x1A1A1A)

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
}
