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
