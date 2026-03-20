//
// MT/V5 — Motion Processing Area
// Defines animation tokens for motion processing
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - MT Motion Processing

/// MT/V5 — Motion Processing Area in visual cortex
/// MT processes motion information, detecting speed and direction
///
/// This file defines animation tokens used throughout Trinity Queen UI.
/// Animations respect the reduceMotion accessibility preference.
public enum MTMotion {

    // MARK: - Spring Animations

    /// Quick spring for snappy interactions
    /// - Response: 0.3s (fast)
    /// - Damping: 0.7 (slightly underdamped for bounce)
    public static var quickSpring: Animation {
        Animation.spring(response: 0.3, dampingFraction: 0.7, blendDuration: 0.2)
    }

    /// Standard spring for most UI interactions
    /// - Response: 0.45s (balanced)
    /// - Damping: 0.75 (smooth with minimal overshoot)
    public static var standardSpring: Animation {
        Animation.spring(response: 0.45, dampingFraction: 0.75, blendDuration: 0.35)
    }

    /// Gentle spring for subtle animations
    /// - Response: 0.6s (slow)
    /// - Damping: 0.8 (heavily damped, no bounce)
    public static var gentleSpring: Animation {
        Animation.spring(response: 0.6, dampingFraction: 0.8, blendDuration: 0.4)
    }

    /// Bouncy spring for playful interactions
    /// - Response: 0.35s (fast)
    /// - Damping: 0.6 (more bounce)
    public static var bouncySpring: Animation {
        Animation.spring(response: 0.35, dampingFraction: 0.6, blendDuration: 0.25)
    }

    /// Ultra quick spring for instant feedback
    /// - Response: 0.25s (ultra fast)
    /// - Damping: 0.8 (no bounce)
    public static var ultraQuickSpring: Animation {
        Animation.spring(response: 0.25, dampingFraction: 0.8, blendDuration: 0.15)
    }

    /// Quick gentle spring for subtle feedback
    /// - Response: 0.3s (fast)
    /// - Damping: 0.8 (no bounce)
    public static var quickGentleSpring: Animation {
        Animation.spring(response: 0.3, dampingFraction: 0.8, blendDuration: 0.2)
    }

    /// Slow bouncy spring for playful delays
    /// - Response: 0.5s (slow)
    /// - Damping: 0.6 (more bounce)
    public static var slowBouncySpring: Animation {
        Animation.spring(response: 0.5, dampingFraction: 0.6, blendDuration: 0.4)
    }

    // MARK: - Ease Animations

    /// Quick ease for micro-interactions
    public static var quickEase: Animation {
        .easeOut(duration: 0.15)
    }

    /// Standard ease for transitions
    public static var standardEase: Animation {
        .easeInOut(duration: 0.25)
    }

    /// Slow ease for deliberate animations
    public static var slowEase: Animation {
        .easeInOut(duration: 0.4)
    }

    // MARK: - Specialized Animations

    /// Fade animation for reduced motion
    public static var fade: Animation {
        .easeInOut(duration: 0.2)
    }

    /// Scale animation for entrance
    public static var scaleEntrance: Animation {
        .spring(response: 0.4, dampingFraction: 0.7)
    }

    /// Slide animation for navigation
    public static var slide: Animation {
        .easeOut(duration: 0.3)
    }

    /// Message entrance animation (cascade effect)
    public static var messageEntrance: Animation {
        .spring(response: 0.45, dampingFraction: 0.75, blendDuration: 0.35)
    }

    /// Accordion expand/collapse animation
    public static var accordion: Animation {
        .easeInOut(duration: 0.25)
    }

    /// Modal presentation animation
    public static var modal: Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }

    /// Toast notification animation
    public static var toast: Animation {
        .spring(response: 0.35, dampingFraction: 0.7)
    }

    // MARK: - Duration-Based Animations

    /// Instant animation (100ms)
    public static var instant: Animation {
        .easeOut(duration: durationInstant)
    }

    /// Quick animation (150ms)
    public static var quick: Animation {
        .easeOut(duration: durationQuick)
    }

    /// Fast animation (200ms)
    public static var fast: Animation {
        .easeOut(duration: durationFast)
    }

    /// Medium animation (300ms)
    public static var medium: Animation {
        .easeInOut(duration: durationMedium)
    }

    /// Slow animation (400ms)
    public static var slow: Animation {
        .easeInOut(duration: durationSlow)
    }

    // MARK: - Timing Values

    /// Stagger delay for list items (ms)
    public static let staggerDelay: Double = 0.05

    /// Message entrance stagger delay (ms)
    public static let messageStaggerDelay: Double = 0.05

    /// Hover transition duration (ms)
    public static let hoverDuration: Double = 0.15

    /// Focus transition duration (ms)
    public static let focusDuration: Double = 0.2

    // MARK: - Scale Values

    /// Scale for message entrance
    public static let entranceScale: CGFloat = 0.92

    /// Scale for message exit
    public static let exitScale: CGFloat = 0.98

    /// Scale for button press
    public static let pressScale: CGFloat = 0.95

    /// Scale for hover effect
    public static let hoverScale: CGFloat = 1.02

    // MARK: - Duration Tokens

    /// 100ms - instant
    public static let durationInstant: Double = 0.1

    /// 150ms - quick
    public static let durationQuick: Double = 0.15

    /// 200ms - fast
    public static let durationFast: Double = 0.2

    /// 300ms - medium
    public static let durationMedium: Double = 0.3

    /// 400ms - slow
    public static let durationSlow: Double = 0.4

    /// 750ms - very slow
    public static let durationVerySlow: Double = 0.75

    /// 800ms - extra slow
    public static let durationExtraSlow: Double = 0.8

    /// 1s - second
    public static let durationSecond: Double = 1.0

    // MARK: - Adaptive Animations

    /// Returns appropriate animation based on reduce motion setting
    public static func adaptive(_ standard: Animation, reduced: Animation = .easeInOut(duration: 0.2)) -> Animation {
        NSWorkspace.shared.accessibilityDisplayShouldReduceMotion ? reduced : standard
    }

    /// Quick spring that respects reduce motion
    public static func adaptiveQuickSpring() -> Animation {
        adaptive(quickSpring)
    }

    /// Standard spring that respects reduce motion
    public static func adaptiveStandardSpring() -> Animation {
        adaptive(standardSpring)
    }

    /// Gentle spring that respects reduce motion
    public static func adaptiveGentleSpring() -> Animation {
        adaptive(gentleSpring)
    }
}

// MARK: - Animation View Extensions

extension View {

    /// Applies animation based on reduce motion preference
    @ViewBuilder
    func adaptiveAnimation() -> some View {
        animation(MTMotion.adaptive(MTMotion.standardSpring), value: UUID())
    }

    /// Applies quick spring animation
    @ViewBuilder
    func quickSpringAnimation() -> some View {
        animation(MTMotion.adaptiveQuickSpring(), value: UUID())
    }

    /// Applies standard spring animation
    @ViewBuilder
    func standardSpringAnimation() -> some View {
        animation(MTMotion.adaptiveStandardSpring(), value: UUID())
    }

    /// Applies fade animation
    @ViewBuilder
    func fadeAnimation() -> some View {
        animation(MTMotion.fade, value: UUID())
    }
}

// MARK: - Transition Extensions

extension View {

    /// Default fade transition
    var fadeTransition: some View {
        transition(.opacity)
    }

    /// Scale and fade transition
    var scaleFadeTransition: some View {
        transition(.scale.combined(with: .opacity))
    }

    /// Slide and fade transition from edge
    func slideFadeTransition(edge: Edge = .trailing) -> some View {
        transition(.move(edge: edge).combined(with: .opacity))
    }
}

// MARK: - Legacy Compatibility

/// Backward compatibility with V1Theme animation tokens
extension MTMotion {

    /// Spring response value (bridged from V1Theme)
    public static let springResponse: Double = 0.45

    /// Spring damping fraction (bridged from V1Theme)
    public static let springDampingFraction: Double = 0.75

    /// Spring blend duration (bridged from V1Theme)
    public static let springBlendDuration: Double = 0.35
}
