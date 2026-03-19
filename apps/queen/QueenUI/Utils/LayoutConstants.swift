import SwiftUI

/// Responsive layout constants for Queen UI
/// Eliminates hardcoded sizes and enables adaptive layouts across window sizes
enum LayoutConstants {
    // MARK: - Sidebar Widths

    /// Main chat sidebar (thread list, context, network)
    static let sidebarMinWidth: CGFloat = 200
    static let sidebarIdealWidth: CGFloat = 240
    static let sidebarMaxWidth: CGFloat = 280

    /// Comment sidebar (thread replies)
    static let commentSidebarMinWidth: CGFloat = 240
    static let commentSidebarIdealWidth: CGFloat = 280
    static let commentSidebarMaxWidth: CGFloat = 320

    /// Agent stream overlay
    static let agentStreamMinWidth: CGFloat = 300
    static let agentStreamIdealWidth: CGFloat = 350
    static let agentStreamMaxWidth: CGFloat = 400

    // MARK: - Spacing

    static let compactSpacing: CGFloat = 4
    static let standardSpacing: CGFloat = 8
    static let looseSpacing: CGFloat = 16

    // MARK: - Padding

    static let compactPadding: CGFloat = 8
    static let standardPadding: CGFloat = 16
    static let loosePadding: CGFloat = 24
    static let messageHorizontalPadding: CGFloat = 60
    static let cardPadding: CGFloat = 12
    static let inputAreaPadding: CGFloat = 16

    // MARK: - Buttons

    static let iconButtonSize: CGFloat = 36
    static let minButtonHeight: CGFloat = 32
}
