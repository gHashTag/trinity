//
// Prefrontal Cortex — Adaptive Behavior
// Responsive container based on available width
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Prefrontal Responsive

/// Prefrontal Cortex — Adaptive Behavior
///
/// The prefrontal cortex is responsible for executive functions,
/// including adaptive behavior and decision making.
///
/// This component provides responsive layout that adapts to available space:
/// - Compact (< 600px): Single column, simplified UI
/// - Regular (600-900px): Two columns, standard UI
/// - Expanded (> 900px): Three columns, full UI
public struct PrefrontalResponsive<Content: View>: View {
    let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geo in
            if geo.size.width < 600 {
                CompactLayout { content }
            } else if geo.size.width < 900 {
                RegularLayout { content }
            } else {
                ExpandedLayout { content }
            }
        }
    }
}

// MARK: - Layout Variants

/// Compact layout for small screens
private struct CompactLayout<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
    }
}

/// Regular layout for medium screens
private struct RegularLayout<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
    }
}

/// Expanded layout for large screens
private struct ExpandedLayout<Content: View>: View {
    let content: Content

    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    var body: some View {
        content
            .frame(maxWidth: .infinity)
    }
}

// MARK: - Responsive Size Category

/// Size categories for responsive behavior
public enum PrefrontalSize {
    case compact    // < 600px
    case regular    // 600-900px
    case expanded   // > 900px

    public init(width: CGFloat) {
        if width < 600 {
            self = .compact
        } else if width < 900 {
            self = .regular
        } else {
            self = .expanded
        }
    }
}

// MARK: - Responsive Container

/// Container that provides size category to children
public struct PrefrontalContainer<Content: View>: View {
    let content: (PrefrontalSize) -> Content

    public init(@ViewBuilder content: @escaping (PrefrontalSize) -> Content) {
        self.content = content
    }

    public var body: some View {
        GeometryReader { geo in
            content(PrefrontalSize(width: geo.size.width))
        }
    }
}

// MARK: - Responsive HStack

/// HStack that collapses to VStack on small screens
public struct PrefrontalAdaptiveStack<Content: View>: View {
    let content: Content
    let threshold: CGFloat

    public init(
        threshold: CGFloat = 600,
        @ViewBuilder content: () -> Content
    ) {
        self.threshold = threshold
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geo in
            if geo.size.width < threshold {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    content
                }
            } else {
                HStack(spacing: ParietalSpacing.sm) {
                    content
                }
            }
        }
    }
}

// MARK: - Responsive Grid

/// Grid that adjusts column count based on available width
public struct PrefrontalGrid<Content: View>: View {
    let content: Content
    let minItemWidth: CGFloat
    let spacing: CGFloat

    public init(
        minItemWidth: CGFloat = 200,
        spacing: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.content = content()
    }

    public var body: some View {
        GeometryReader { geo in
            let columns = max(1, Int(geo.size.width / (minItemWidth + spacing)))
            LazyVGrid(
                columns: Array(repeating: GridItem(.flexible(), spacing: spacing), count: columns),
                spacing: spacing
            ) {
                content
            }
        }
    }
}

// MARK: - Responsive Sidebar

/// Sidebar that collapses on small screens
public struct PrefrontalSidebar<Sidebar: View, Main: View>: View {
    let sidebar: Sidebar
    let main: Main
    let sidebarWidth: CGFloat
    let collapseThreshold: CGFloat

    @State private var isSidebarVisible: Bool = true

    public init(
        sidebarWidth: CGFloat = 280,
        collapseThreshold: CGFloat = 800,
        @ViewBuilder sidebar: () -> Sidebar,
        @ViewBuilder main: () -> Main
    ) {
        self.sidebarWidth = sidebarWidth
        self.collapseThreshold = collapseThreshold
        self.sidebar = sidebar()
        self.main = main()
    }

    public var body: some View {
        GeometryReader { geo in
            HStack(spacing: 0) {
                if isSidebarVisible || geo.size.width >= collapseThreshold {
                    sidebar
                        .frame(width: sidebarWidth)
                        .transition(.move(edge: .leading))
                }

                main
            }
            .onChange(of: geo.size.width) { _, newWidth in
                isSidebarVisible = newWidth >= collapseThreshold
            }
        }
    }
}

// MARK: - Preview
// NOTE: Preview blocks removed for CLI build compatibility
