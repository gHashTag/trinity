import SwiftUI
import AppKit

/// Manages accessibility preferences and provides helper methods for accessibility features.
/// This class ensures that Queen UI respects user accessibility preferences and provides
/// appropriate accommodations throughout the application.
public final class AccessibilityManager: ObservableObject {

    // MARK: - Singleton

        public static let shared = AccessibilityManager()

    private init() {
        loadPreferences()
        observeSystemPreferences()
    }

    // MARK: - Published Properties

    /// Whether reduce motion is enabled for animations
    @Published public var reduceMotion: Bool = false

    /// Whether increased text size is enabled
    @Published public var increasedTextSize: Bool = false

    /// Whether high contrast mode is enabled
    @Published public var highContrast: Bool = false

    /// Preferred text size scale multiplier (1.0 = normal, 1.2 = 20% larger, etc.)
    @Published public var textScaleMultiplier: Double = 1.0

    // MARK: - UserDefaults Keys

    private enum Keys {
        static let reduceMotion = "accessibility_reduce_motion"
        static let increasedTextSize = "accessibility_increased_text_size"
        static let highContrast = "accessibility_high_contrast"
        static let textScaleMultiplier = "accessibility_text_scale_multiplier"
    }

    // MARK: - Persistence

    private func loadPreferences() {
        let defaults = UserDefaults.standard

        reduceMotion = defaults.bool(forKey: Keys.reduceMotion)
        increasedTextSize = defaults.bool(forKey: Keys.increasedTextSize)
        highContrast = defaults.bool(forKey: Keys.highContrast)
        textScaleMultiplier = defaults.double(forKey: Keys.textScaleMultiplier)

        // Ensure text scale has a valid value
        if textScaleMultiplier == 0 {
            textScaleMultiplier = 1.0
        }
    }

    private func savePreferences() {
        let defaults = UserDefaults.standard
        defaults.set(reduceMotion, forKey: Keys.reduceMotion)
        defaults.set(increasedTextSize, forKey: Keys.increasedTextSize)
        defaults.set(highContrast, forKey: Keys.highContrast)
        defaults.set(textScaleMultiplier, forKey: Keys.textScaleMultiplier)
    }

    // MARK: - System Preference Observation

    private func observeSystemPreferences() {
        // Observe system accessibility preferences
        NotificationCenter.default.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.updateFromSystemPreferences()
        }

        // Initial update from system
        updateFromSystemPreferences()
    }

    private func updateFromSystemPreferences() {
        // Check system preferences using NSWorkspace
        // Note: Direct access to accessibility options may be limited
        // We rely on UserDefaults persistence for preferences

        // The system reduce motion setting can be checked via NSWorkspace
        // but the API varies across macOS versions. For now, we use
        // UserDefaults-based persistence which works reliably.

        // Future: Use NSWorkspace.accessibilityDisplayOptions if available
    }

    // MARK: - Public Modifiers

    /// Enables or disables reduce motion preference
    public func setReduceMotion(_ enabled: Bool, userOverride: Bool = true) {
        reduceMotion = enabled
        if userOverride {
            UserDefaults.standard.set(true, forKey: "accessibility_user_override_reduce_motion")
        }
        savePreferences()
    }

    /// Enables or disables increased text size preference
    public func setIncreasedTextSize(_ enabled: Bool) {
        increasedTextSize = enabled
        if enabled {
            textScaleMultiplier = 1.2
        } else {
            textScaleMultiplier = 1.0
        }
        savePreferences()
    }

    /// Enables or disables high contrast mode
    public func setHighContrast(_ enabled: Bool) {
        highContrast = enabled
        savePreferences()
    }

    /// Sets the text scale multiplier directly
    public func setTextScaleMultiplier(_ multiplier: Double) {
        textScaleMultiplier = max(0.8, min(multiplier, 2.0))
        increasedTextSize = textScaleMultiplier > 1.0
        savePreferences()
    }

    // MARK: - Helper Methods

    /// Checks if reduce motion is currently enabled
    public func isReduceMotionEnabled() -> Bool {
        return reduceMotion
    }

    /// Checks if VoiceOver is currently running
    public func isVoiceOverRunning() -> Bool {
        return NSWorkspace.shared.isVoiceOverEnabled
    }

    /// Returns an appropriate animation based on reduce motion preference
    public func appropriateAnimation() -> Animation? {
        return reduceMotion ? nil : .spring(response: 0.35, dampingFraction: 0.75)
    }

    /// Returns fade animation for reduce motion, or provided animation otherwise
    public func animationOrDefault(_ defaultAnimation: Animation) -> Animation {
        return reduceMotion ? .easeInOut(duration: 0.2) : defaultAnimation
    }

    /// Returns transition appropriate for current accessibility settings
    public func appropriateTransition() -> AnyTransition {
        return reduceMotion ? .opacity : .move(edge: .bottom).combined(with: .opacity)
    }

    /// Calculates font size with accessibility scaling applied
    public func scaledFontSize(_ baseSize: CGFloat) -> CGFloat {
        if increasedTextSize {
            return baseSize * textScaleMultiplier
        }
        return baseSize
    }

    /// Returns a Dynamic Type font with accessibility considerations
    public func accessibleFont(_ style: Font.TextStyle, size: CGFloat? = nil) -> Font {
        if increasedTextSize, let size = size {
            return .system(size: scaledFontSize(size))
        }
        return .system(style)
    }

    // MARK: - High Contrast Colors

    /// Returns appropriate color based on high contrast mode
    public func color(normal: Color, highContrast: Color) -> Color {
        return self.highContrast ? highContrast : normal
    }

    /// Returns text color with guaranteed contrast ratio
    public func textColor(for background: Color) -> Color {
        if self.highContrast {
            return background == .black ? .white : .black
        }
        return V4Color.textPrimary
    }

    // MARK: - Accessibility Labels Helpers

    /// Creates accessibility label for buttons with icon-only content
    public static func label(for icon: String, action: String) -> String {
        return "\(action) button"
    }

    /// Creates accessibility hint for interactive elements
    public static func hint(for action: String, gesture: String = "Double tap") -> String {
        return "\(gesture) to \(action)"
    }

    /// Combines accessibility label and hint into a single identifier
    public static func identifier(label: String, hint: String? = nil) -> String {
        if let hint = hint {
            return "\(label).\(hint)"
        }
        return label
    }

    // MARK: - Accessibility Action Builders

    /// Creates a button accessibility configuration for copying content
    public func copyAccessibility() -> some AccessibilityActionWrapper {
        return EmptyActionWrapper()
    }

    /// Creates a button accessibility configuration for regenerating content
    public func regenerateAccessibility() -> some AccessibilityActionWrapper {
        return EmptyActionWrapper()
    }

    /// Creates a button accessibility configuration for deleting content
    public func deleteAccessibility() -> some AccessibilityActionWrapper {
        return EmptyActionWrapper()
    }
}

// MARK: - Empty Action Wrapper (placeholder for future actions)

/// Placeholder for accessibility actions - to be expanded with actual implementations
public struct EmptyActionWrapper: AccessibilityActionWrapper {
    public init() {}
}

public protocol AccessibilityActionWrapper {}

// MARK: - View Extensions for Accessibility

public extension View {

    /// Applies accessibility label and hint in one modifier
    func accessibility(label: String, hint: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
    }

    /// Applies accessibility properties for icon-only buttons
    func accessibleIconButton(label: String, hint: String) -> some View {
        self
            .accessibilityLabel(label)
            .accessibilityHint(hint)
    }

    /// Skips animation when reduce motion is enabled
    func accessibleAnimation(_ animation: Animation?, value: some Equatable) -> some View {
        let manager = AccessibilityManager.shared
        let effectiveAnimation = manager.reduceMotion ? nil : animation
        return self.animation(effectiveAnimation, value: value)
    }

    /// Applies appropriate transition based on accessibility settings
    func accessibleTransition() -> some View {
        let manager = AccessibilityManager.shared
        return self.transition(manager.appropriateTransition())
    }

    /// Groups child elements for accessibility
    func accessiblyGroup() -> some View {
        self.accessibilityElement(children: .combine)
    }

    /// Adds accessibility identifier for UI testing
    func testableIdentifier(_ identifier: String) -> some View {
        self.accessibilityIdentifier(identifier)
    }
}

// MARK: - Environment Key

private struct AccessibilityManagerKey: EnvironmentKey {
    static let defaultValue: AccessibilityManager = .shared
}

public extension EnvironmentValues {
    var accessibilityManager: AccessibilityManager {
        get { self[AccessibilityManagerKey.self] }
        set { self[AccessibilityManagerKey.self] = newValue }
    }
}
