//
// Entorhinal Cortex — Navigation & Grid Cells
// Responsive sidebar with 220-400px width
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Entorhinal Sidebar

/// Entorhinal Cortex — Navigation & Grid Cells
///
/// The entorhinal cortex is involved in navigation and spatial memory.
/// Contains grid cells that provide a coordinate system for navigation.
///
/// This component provides a responsive sidebar that:
/// - Expands from 220px to 400px
/// - Has an ideal width of 280px
/// - Animates smoothly on size changes
public struct EntorhinalSidebar<Content: View>: View {
    let content: Content

    /// Minimum width for accessibility (220px)
    public let minWidth: CGFloat = 220

    /// Ideal width for most content (280px)
    public let idealWidth: CGFloat = 280

    /// Maximum width for space efficiency (400px)
    public let maxWidth: CGFloat = 400

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(minWidth: minWidth, idealWidth: idealWidth, maxWidth: maxWidth)
            .background(V4Color.sidebar)
            .transition(.move(edge: .leading).combined(with: .opacity))
    }
}

// MARK: - Entorhinal Navigation Item

/// Navigation item with icon and text
public struct EntorhinalNavItem: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void

    public init(
        title: String,
        icon: String,
        isSelected: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.isSelected = isSelected
        self.action = action
    }

    public var body: some View {
        Button {
            withAnimation(MTMotion.quickSpring) {
                action()
            }
        } label: {
            HStack(spacing: ParietalSpacing.xs) {
                Image(systemName: icon)
                    .font(WernickeTypography.small)
                    .frame(width: ParietalSpacing.icon)

                Text(title)
                    .font(WernickeTypography.small)
                    .monospaced()

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .padding(.horizontal, ParietalSpacing.md)
            .background(isSelected ? V4Color.selected : Color.clear)
            .foregroundStyle(isSelected ? V4Color.textPrimary : V4Color.textSecondary)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Entorhinal Section

/// Section header with realm color
public struct EntorhinalSection: View {
    let title: String
    let color: Color

    public init(title: String, color: Color) {
        self.title = title
        self.color = color
    }

    public var body: some View {
        Text(title)
            .font(WernickeTypography.caption2Bold.monospaced())
            .foregroundStyle(color)
            .padding(.vertical, ParietalSpacing.xs)
            .padding(.horizontal, ParietalSpacing.md)
    }
}

// MARK: - Entorhinal Compact Sidebar

/// Compact sidebar variant for smaller windows
public struct EntorhinalCompactSidebar<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        content
            .frame(width: 180)
            .background(V4Color.sidebar)
    }
}

// MARK: - Realm Colors

/// Realm colors from photon_trinity_canvas.zig
public enum EntorhinalRealm {
    public static let brain = Color(red: 1.0, green: 215.0/255.0, blue: 0)           // Gold (RAZUM)
    public static let body = Color(red: 80.0/255.0, green: 250.0/255.0, blue: 250.0/255.0) // Cyan (MATERIYA)
    public static let spirit = Color(red: 189.0/255.0, green: 147.0/255.0, blue: 249.0/255.0) // Purple (DUKH)
}

// MARK: - Responsive Sidebar Container

/// Sidebar that adapts to available space
public struct EntorhinalResponsiveSidebar<Sidebar: View, Main: View>: View {
    let sidebar: Sidebar
    let main: Main
    @State private var sidebarWidth: CGFloat = 280

    public init(
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder main: () -> Main
    ) {
        self.sidebar = sidebar()
        self.main = main()
    }

    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                // Sidebar
                sidebar
                    .frame(width: min(max(sidebarWidth, 220), 400))
                    .transition(.move(edge: .leading).combined(with: .opacity))

                // Divider
                Rectangle()
                    .fill(V4Color.border)
                    .frame(width: 1)

                // Main content
                main
            }
            .onChange(of: geo.size.width) { _, newWidth in
                // Adjust sidebar width based on available space
                if newWidth < 800 {
                    sidebarWidth = 220
                } else if newWidth > 1200 {
                    sidebarWidth = 320
                } else {
                    sidebarWidth = 280
                }
            }
        }
    }
}

// MARK: - Preview
// NOTE: Preview blocks removed for CLI build compatibility
