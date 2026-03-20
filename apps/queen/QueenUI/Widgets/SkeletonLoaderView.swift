// Skeleton Loader View
// Shimmer loading placeholders for various UI patterns

import SwiftUI

// MARK: - Skeleton Content Protocol

/// Protocol for views that can display skeleton loading states.
/// Conforming types can provide custom skeleton representations of their content.
public protocol SkeletonContent {
    /// Returns a skeleton placeholder view that represents this view's loading state.
    @ViewBuilder
    func skeletonBody() -> any View
}

// MARK: - Shimmer Effect Modifier

/// An animated gradient sweep effect that creates a shimmering appearance.
/// The effect moves from left to right with a gradient that transitions
/// from base color through highlight and back to base color.
struct ShimmerEffect: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Base color for the skeleton (from TrinityTheme)
    let baseColor: Color

    /// Highlight color for the shimmer sweep
    let highlightColor: Color

    /// Duration of one complete shimmer cycle in seconds
    let duration: Double

    /// Direction of the shimmer animation
    enum Direction {
        case leftToRight
        case rightToLeft
        case topToBottom
        case bottomToTop
    }

    let direction: Direction

    @State private var phase: CGFloat = -1

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    let gradient = gradient(for: geometry.size)
                    Rectangle()
                        .fill(gradient)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                }
            )
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced {
                    phase = 0
                }
            }
    }

    private func gradient(for size: CGSize) -> LinearGradient {
        let startPoint: UnitPoint
        let endPoint: UnitPoint

        switch direction {
        case .leftToRight:
            startPoint = UnitPoint(x: phase - 1, y: 0.5)
            endPoint = UnitPoint(x: phase, y: 0.5)
        case .rightToLeft:
            startPoint = UnitPoint(x: 1 - phase, y: 0.5)
            endPoint = UnitPoint(x: 2 - phase, y: 0.5)
        case .topToBottom:
            startPoint = UnitPoint(x: 0.5, y: phase - 1)
            endPoint = UnitPoint(x: 0.5, y: phase)
        case .bottomToTop:
            startPoint = UnitPoint(x: 0.5, y: 1 - phase)
            endPoint = UnitPoint(x: 0.5, y: 2 - phase)
        }

        return LinearGradient(
            colors: [
                baseColor,
                baseColor,
                highlightColor,
                baseColor,
                baseColor
            ],
            startPoint: startPoint,
            endPoint: endPoint
        )
    }
}

// MARK: - Pulse Breath Modifier

/// A subtle pulse animation that creates a breathing effect.
/// Unlike shimmer, this effect uniformly pulses opacity/scale
/// for a softer, more gentle loading indication.
struct PulseBreath: ViewModifier {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Minimum scale/opacity value
    let minValue: CGFloat

    /// Maximum scale/opacity value
    let maxValue: CGFloat

    /// Duration of one breath cycle in seconds
    let duration: Double

    /// Whether to animate scale (vs opacity)
    let animateScale: Bool

    @State private var isBreathing = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(animateScale ? (isBreathing ? maxValue : minValue) : 1)
            .opacity(animateScale ? 1 : (isBreathing ? maxValue : minValue))
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(
                    .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true)
                ) {
                    isBreathing = true
                }
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced {
                    isBreathing = false
                }
            }
    }
}

// MARK: - Skeleton Line

/// A single horizontal line skeleton, perfect for text placeholders.
/// Varies width based on style (short, medium, long, full).
struct SkeletonLine: View {
    /// Width style for the line
    enum WidthStyle {
        case short      // 30%
        case medium     // 60%
        case long       // 85%
        case full       // 100%
        case custom(CGFloat)

        var percentage: CGFloat {
            switch self {
            case .short: return 0.3
            case .medium: return 0.6
            case .long: return 0.85
            case .full: return 1.0
            case .custom(let value): return min(max(value, 0), 1)
            }
        }
    }

    let style: WidthStyle
    let height: CGFloat
    let cornerRadius: CGFloat
    let duration: Double
    let usePulse: Bool

    init(
        style: WidthStyle = .long,
        height: CGFloat = 12,
        cornerRadius: CGFloat = 4,
        duration: Double = 1.8,
        usePulse: Bool = false
    ) {
        self.style = style
        self.height = height
        self.cornerRadius = cornerRadius
        self.duration = duration
        self.usePulse = usePulse
    }

    var body: some View {
        GeometryReader { geometry in
            shimmerShape(
                RoundedRectangle(cornerRadius: cornerRadius)
            )
            .frame(width: geometry.size.width * style.percentage, height: height)
        }
        .frame(height: height)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func shimmerShape<S: Shape>(_ shape: S) -> some View {
        let base = V4Color.border
        let highlight = Color(nsColor: NSColor(base).blended(withFraction: 0.3, of: .white) ?? .white)

        shape
            .fill(base)
            .if(!usePulse) { view in
                view.modifier(
                    ShimmerEffect(
                        baseColor: base,
                        highlightColor: highlight,
                        duration: duration,
                        direction: .leftToRight
                    )
                )
            }
            .if(usePulse) { view in
                view.modifier(
                    PulseBreath(
                        minValue: 0.7,
                        maxValue: 1.0,
                        duration: duration * 0.7,
                        animateScale: false
                    )
                )
            }
    }
}

// MARK: - Skeleton Rectangle

/// A rectangular skeleton placeholder for cards, images, or content blocks.
struct SkeletonRectangle: View {
    let width: CGFloat?
    let height: CGFloat
    let cornerRadius: CGFloat
    let duration: Double
    let usePulse: Bool

    init(
        width: CGFloat? = nil,
        height: CGFloat,
        cornerRadius: CGFloat = V1Theme.cornerMedium,
        duration: Double = 1.8,
        usePulse: Bool = false
    ) {
        self.width = width
        self.height = height
        self.cornerRadius = cornerRadius
        self.duration = duration
        self.usePulse = usePulse
    }

    var body: some View {
        shimmerShape(
            RoundedRectangle(cornerRadius: cornerRadius)
        )
        .frame(width: width, height: height)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func shimmerShape<S: Shape>(_ shape: S) -> some View {
        let base = V4Color.border
        let highlight = Color(nsColor: NSColor(base).blended(withFraction: 0.3, of: .white) ?? .white)

        shape
            .fill(base)
            .if(!usePulse) { view in
                view.modifier(
                    ShimmerEffect(
                        baseColor: base,
                        highlightColor: highlight,
                        duration: duration,
                        direction: .leftToRight
                    )
                )
            }
            .if(usePulse) { view in
                view.modifier(
                    PulseBreath(
                        minValue: 0.7,
                        maxValue: 1.0,
                        duration: duration * 0.7,
                        animateScale: false
                    )
                )
            }
    }
}

// MARK: - Skeleton Circle

/// A circular skeleton placeholder for avatars, icons, or profile images.
struct SkeletonCircle: View {
    let diameter: CGFloat
    let duration: Double
    let usePulse: Bool

    init(
        diameter: CGFloat,
        duration: Double = 1.8,
        usePulse: Bool = false
    ) {
        self.diameter = diameter
        self.duration = duration
        self.usePulse = usePulse
    }

    var body: some View {
        shimmerShape(
            Circle()
        )
        .frame(width: diameter, height: diameter)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func shimmerShape<S: Shape>(_ shape: S) -> some View {
        let base = V4Color.border
        let highlight = Color(nsColor: NSColor(base).blended(withFraction: 0.3, of: .white) ?? .white)

        shape
            .fill(base)
            .if(!usePulse) { view in
                view.modifier(
                    ShimmerEffect(
                        baseColor: base,
                        highlightColor: highlight,
                        duration: duration,
                        direction: .leftToRight
                    )
                )
            }
            .if(usePulse) { view in
                view.modifier(
                    PulseBreath(
                        minValue: 0.7,
                        maxValue: 1.0,
                        duration: duration * 0.7,
                        animateScale: false
                    )
                )
            }
    }
}

// MARK: - Skeleton Text

/// Multiple text lines that simulate paragraph content.
/// Lines have varying widths to mimic natural text distribution.
struct SkeletonText: View {
    let lineCount: Int
    let lineHeight: CGFloat
    let lastLineWidth: SkeletonLine.WidthStyle
    let spacing: CGFloat
    let duration: Double
    let usePulse: Bool

    init(
        lineCount: Int = 3,
        lineHeight: CGFloat = 12,
        lastLineWidth: SkeletonLine.WidthStyle = .medium,
        spacing: CGFloat = 6,
        duration: Double = 1.8,
        usePulse: Bool = false
    ) {
        self.lineCount = max(1, lineCount)
        self.lineHeight = lineHeight
        self.lastLineWidth = lastLineWidth
        self.spacing = spacing
        self.duration = duration
        self.usePulse = usePulse
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            ForEach(0..<lineCount, id: \.self) { index in
                let isLast = index == lineCount - 1
                let style: SkeletonLine.WidthStyle = isLast ? lastLineWidth : .long

                SkeletonLine(
                    style: style,
                    height: lineHeight,
                    duration: duration,
                    usePulse: usePulse
                )
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Skeleton Avatar

/// User avatar placeholder with optional name and subtitle lines.
/// Perfect for user lists, chat participants, or profile cards.
struct SkeletonAvatar: View {
    enum Size {
        case small    // 28pt
        case medium   // 40pt
        case large    // 56pt

        var diameter: CGFloat {
            switch self {
            case .small: return 28
            case .medium: return 40
            case .large: return 56
            }
        }

        var lineHeight: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 12
            case .large: return 14
            }
        }
    }

    let size: Size
    let showName: Bool
    let showSubtitle: Bool
    let spacing: CGFloat
    let duration: Double
    let usePulse: Bool
    let alignment: HorizontalAlignment

    init(
        size: Size = .medium,
        showName: Bool = true,
        showSubtitle: Bool = true,
        spacing: CGFloat = 12,
        duration: Double = 1.8,
        usePulse: Bool = false,
        alignment: HorizontalAlignment = .leading
    ) {
        self.size = size
        self.showName = showName
        self.showSubtitle = showSubtitle
        self.spacing = spacing
        self.duration = duration
        self.usePulse = usePulse
        self.alignment = alignment
    }

    var body: some View {
        HStack(alignment: .center, spacing: spacing) {
            SkeletonCircle(diameter: size.diameter, duration: duration, usePulse: usePulse)

            if showName || showSubtitle {
                VStack(alignment: alignment == .leading ? .leading : .trailing, spacing: ParietalSpacing.xs) {
                    if showName {
                        SkeletonLine(
                            style: .medium,
                            height: size.lineHeight,
                            cornerRadius: 3,
                            duration: duration,
                            usePulse: usePulse
                        )
                    }
                    if showSubtitle {
                        SkeletonLine(
                            style: .short,
                            height: size.lineHeight - 2,
                            cornerRadius: 3,
                            duration: duration,
                            usePulse: usePulse
                        )
                    }
                }
            }

            Spacer()
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Skeleton Card

/// Card layout placeholder with header, content, and optional footer.
/// Ideal for dashboard cards, feed items, or content blocks.
struct SkeletonCard: View {
    let headerHeight: CGFloat
    let contentLines: Int
    let showFooter: Bool
    let footerHeight: CGFloat
    let padding: CGFloat
    let spacing: CGFloat
    let duration: Double
    let usePulse: Bool

    init(
        headerHeight: CGFloat = 40,
        contentLines: Int = 4,
        showFooter: Bool = true,
        footerHeight: CGFloat = 32,
        padding: CGFloat = 16,
        spacing: CGFloat = 12,
        duration: Double = 1.8,
        usePulse: Bool = false
    ) {
        self.headerHeight = headerHeight
        self.contentLines = max(1, contentLines)
        self.showFooter = showFooter
        self.footerHeight = footerHeight
        self.padding = padding
        self.spacing = spacing
        self.duration = duration
        self.usePulse = usePulse
    }

    var body: some View {
        VStack(alignment: .leading, spacing: spacing) {
            // Header
            SkeletonRectangle(
                width: .infinity,
                height: headerHeight,
                cornerRadius: V1Theme.cornerSmall,
                duration: duration,
                usePulse: usePulse
            )

            // Content lines
            SkeletonText(
                lineCount: contentLines,
                spacing: ParietalSpacing.sm - 2,
                duration: duration,
                usePulse: usePulse
            )

            // Footer
            if showFooter {
                HStack(spacing: ParietalSpacing.sm) {
                    SkeletonRectangle(
                        width: 60,
                        height: footerHeight,
                        cornerRadius: footerHeight / 2,
                        duration: duration,
                        usePulse: usePulse
                    )
                    Spacer()
                    SkeletonRectangle(
                        width: 80,
                        height: footerHeight,
                        cornerRadius: footerHeight / 2,
                        duration: duration,
                        usePulse: usePulse
                    )
                }
            }
        }
        .padding(padding)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .fill(V4Color.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                        .stroke(V4Color.border, lineWidth: 1)
                )
        )
        .accessibilityHidden(true)
    }
}

// MARK: - Skeleton List

/// List of skeleton items, perfect for table rows, message lists, or feed items.
struct SkeletonList: View {
    let itemCount: Int
    let itemHeight: CGFloat
    let spacing: CGFloat
    let showLeading: Bool
    let showTrailing: Bool
    let duration: Double
    let usePulse: Bool

    init(
        itemCount: Int = 5,
        itemHeight: CGFloat = 60,
        spacing: CGFloat = 8,
        showLeading: Bool = true,
        showTrailing: Bool = false,
        duration: Double = 1.8,
        usePulse: Bool = false
    ) {
        self.itemCount = max(1, itemCount)
        self.itemHeight = itemHeight
        self.spacing = spacing
        self.showLeading = showLeading
        self.showTrailing = showTrailing
        self.duration = duration
        self.usePulse = usePulse
    }

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(0..<itemCount, id: \.self) { _ in
                SkeletonListItem(
                    height: itemHeight,
                    showLeading: showLeading,
                    showTrailing: showTrailing,
                    duration: duration,
                    usePulse: usePulse
                )
            }
        }
        .accessibilityHidden(true)
    }

    /// Individual list item skeleton
    struct SkeletonListItem: View {
        let height: CGFloat
        let showLeading: Bool
        let showTrailing: Bool
        let duration: Double
        let usePulse: Bool

        var body: some View {
            HStack(spacing: ParietalSpacing.md) {
                if showLeading {
                    SkeletonCircle(
                        diameter: height * 0.5,
                        duration: duration,
                        usePulse: usePulse
                    )
                }

                VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
                    SkeletonLine(
                        style: .medium,
                        height: 12,
                        duration: duration,
                        usePulse: usePulse
                    )
                    SkeletonLine(
                        style: .long,
                        height: 10,
                        duration: duration,
                        usePulse: usePulse
                    )
                }

                Spacer()

                if showTrailing {
                    SkeletonRectangle(
                        width: 50,
                        height: 24,
                        cornerRadius: 6,
                        duration: duration,
                        usePulse: usePulse
                    )
                }
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .fill(V4Color.surface)
            )
        }
    }
}

// MARK: - Skeleton Grid

/// Grid layout of skeleton items, perfect for gallery views or card grids.
struct SkeletonGrid: View {
    let columns: Int
    let itemCount: Int
    let itemHeight: CGFloat
    let spacing: CGFloat
    let duration: Double
    let usePulse: Bool

    init(
        columns: Int = 2,
        itemCount: Int = 6,
        itemHeight: CGFloat = 120,
        spacing: CGFloat = 12,
        duration: Double = 1.8,
        usePulse: Bool = false
    ) {
        self.columns = max(1, columns)
        self.itemCount = max(1, itemCount)
        self.itemHeight = itemHeight
        self.spacing = spacing
        self.duration = duration
        self.usePulse = usePulse
    }

    var body: some View {
        let rows = (itemCount + columns - 1) / columns

        VStack(spacing: spacing) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: spacing) {
                    ForEach(0..<columns, id: \.self) { col in
                        let index = row * columns + col
                        if index < itemCount {
                            SkeletonRectangle(
                                width: .infinity,
                                height: itemHeight,
                                cornerRadius: V1Theme.cornerMedium,
                                duration: duration + Double(index) * 0.1, // Stagger animations
                                usePulse: usePulse
                            )
                        } else {
                            Color.clear.frame(maxWidth: .infinity)
                        }
                    }
                }
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Conditional Skeleton View

/// A wrapper that conditionally shows content or skeleton based on loading state.
struct SkeletonView<Content: View, Placeholder: View>: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    let isLoading: Bool
    let showDelay: TimeInterval
    let content: () -> Content
    let placeholder: () -> Placeholder

    @State private var showSkeleton = false

    init(
        isLoading: Bool,
        showDelay: TimeInterval = 0.15,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder placeholder: @escaping () -> Placeholder
    ) {
        self.isLoading = isLoading
        self.showDelay = showDelay
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if isLoading && showSkeleton {
                placeholder()
            } else {
                content()
            }
        }
        .onChange(of: isLoading) { _, newValue in
            if newValue {
                // Delay showing skeleton to prevent flash for fast loads
                Task {
                    try? await Task.sleep(for: .seconds(showDelay))
                    if isLoading {
                        showSkeleton = true
                    }
                }
            } else {
                showSkeleton = false
            }
        }
    }
}

// MARK: - Convenience Extensions

extension View {
    /// Applies a skeleton loading state to the view.
    /// - Parameters:
    ///   - isLoading: Whether content is loading
    ///   - showDelay: Delay before showing skeleton (prevents flash)
    ///   - skeleton: The skeleton placeholder to show
    @ViewBuilder
    func skeleton<Content: View>(
        isLoading: Bool,
        showDelay: TimeInterval = 0.15,
        @ViewBuilder skeleton: @escaping () -> Content
    ) -> some View {
        SkeletonView(isLoading: isLoading, showDelay: showDelay) {
            self
        } placeholder: {
            skeleton()
        }
    }

    /// Applies pulse breath animation to any view.
    func pulseBreath(
        minValue: CGFloat = 0.7,
        maxValue: CGFloat = 1.0,
        duration: Double = 1.5,
        animateScale: Bool = false
    ) -> some View {
        modifier(PulseBreath(
            minValue: minValue,
            maxValue: maxValue,
            duration: duration,
            animateScale: animateScale
        ))
    }

    /// Conditional view modifier (for internal use)
    @ViewBuilder
    fileprivate func `if`<Transform: View>(
        _ condition: Bool,
        transform: (Self) -> Transform
    ) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Preview Helpers

#if DEBUG

/// Preview provider for skeleton components
struct SkeletonLoaderView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ParietalSpacing.xl) {
            // Basic shapes
            HStack(spacing: ParietalSpacing.lg) {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Skeleton Line").font(.caption)
                    SkeletonLine(style: .long)
                }

                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Skeleton Rectangle").font(.caption)
                    SkeletonRectangle(width: 80, height: ParietalSpacing.largeFrame)
                }

                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Skeleton Circle").font(.caption)
                    SkeletonCircle(diameter: 50)
                }
            }

            // Text lines
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Text("Skeleton Text").font(.caption)
                SkeletonText(lineCount: 4)
            }

            // Avatar
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Text("Skeleton Avatar").font(.caption)
                SkeletonAvatar(size: .medium)
            }

            // Card
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Text("Skeleton Card").font(.caption)
                SkeletonCard(headerHeight: 36, contentLines: 3)
                    .frame(width: ParietalSpacing.panelWidth)
            }

            // List
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Text("Skeleton List").font(.caption)
                SkeletonList(itemCount: 3, showLeading: true)
                    .frame(width: ParietalSpacing.panelWidth)
            }

            // Pulse variant
            HStack(spacing: ParietalSpacing.lg) {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Pulse Animation").font(.caption)
                    SkeletonLine(style: .medium, usePulse: true)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(V4Color.background)
    }
}

#endif
