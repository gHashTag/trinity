import SwiftUI

/// A modifier that applies a flash highlight animation to a view when triggered.
/// Used to draw attention to specific messages when navigating via sidebar search.
struct MessageHighlightModifier: ViewModifier {
    /// Whether this view should be highlighted
    var isHighlighted: Bool

    /// Accessibility setting to respect reduced motion preferences
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Internal state for the animation lifecycle
    @State private var opacity: Double = 0
    @State private var scale: CGFloat = 1.0

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .fill(TrinityTheme.accent.opacity(opacity))
                    .animation(reduceMotion ? nil : animation, value: opacity)
            )
            .scaleEffect(scale)
            .animation(reduceMotion ? nil : scaleAnimation, value: scale)
            .onChange(of: isHighlighted) { _, newValue in
                guard newValue else { return }
                triggerHighlight()
            }
            .onAppear {
                if isHighlighted {
                    triggerHighlight()
                }
            }
    }

    /// Trigger the highlight flash animation
    private func triggerHighlight() {
        guard !reduceMotion else {
            // For reduced motion, just show a static highlight
            opacity = 0.2
            Task { @MainActor in
                try? await Task.sleep(for: .seconds(1))
                opacity = 0
            }
            return
        }

        // Reset animation state
        opacity = 0
        scale = 1.0

        // Flash sequence: fade in, slight pulse, fade out
        Task { @MainActor in
            // Initial flash
            opacity = 0.3
            scale = 1.02

            // Hold briefly
            try? await Task.sleep(for: .milliseconds(200))

            // Pulse effect
            opacity = 0.15
            scale = 1.01

            // Second pulse
            try? await Task.sleep(for: .milliseconds(150))
            opacity = 0.25
            scale = 1.015

            // Fade out
            try? await Task.sleep(for: .milliseconds(200))
            opacity = 0.12

            // Final fade
            try? await Task.sleep(for: .milliseconds(150))
            opacity = 0
        }
    }

    /// Animation for the opacity flash
    private var animation: Animation {
        .spring(response: 0.4, dampingFraction: 0.7)
    }

    /// Animation for the subtle scale effect
    private var scaleAnimation: Animation {
        .spring(response: 0.5, dampingFraction: 0.6)
    }
}

// MARK: - View Extension

extension View {
    /// Applies a highlight flash animation to the view when `isHighlighted` is true.
    /// - Parameter isHighlighted: Whether to trigger the highlight animation
    /// - Returns: A view with the highlight modifier applied
    func messageHighlight(isHighlighted: Bool) -> some View {
        self.modifier(MessageHighlightModifier(isHighlighted: isHighlighted))
    }
}
