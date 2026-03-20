//
// Thalamus — Sensory Gateway
// Standardized button component for Trinity UI
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Thalamus Button

/// Thalamus — Sensory Gateway
///
/// The thalamus is the central relay station for sensory information.
/// All sensory signals (except smell) pass through the thalamus before
/// reaching the cerebral cortex.
///
/// This component provides a standardized button with:
/// - Consistent styling with V4 color tokens
/// - MTMotion animations
/// - Accessibility support
/// - Multiple style variants
public struct ThalamusButton: View {
    let title: String
    let icon: String?
    let style: ButtonStyle
    let action: () -> Void
    let isDisabled: Bool

    public enum ButtonStyle {
        case primary
        case secondary
        case ghost
        case danger
    }

    public init(
        _ title: String,
        icon: String? = nil,
        style: ButtonStyle = .primary,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.style = style
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button {
            action()
        } label: {
            labelView
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }

    @ViewBuilder
    private var labelView: some View {
        HStack(spacing: ParietalSpacing.xs) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(WernickeTypography.size14)
            }
            Text(title)
                .font(WernickeTypography.body)
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.xs)
        .background(style.backgroundColor)
        .foregroundStyle(style.foregroundColor)
        .cornerRadius(V1Theme.cornerMedium)
    }
}

// MARK: - Thalamus Icon Button

/// Icon-only button variant
public struct ThalamusIconButton: View {
    let icon: String
    let style: ThalamusButton.ButtonStyle
    let action: () -> Void
    let isDisabled: Bool

    public init(
        icon: String,
        style: ThalamusButton.ButtonStyle = .ghost,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.style = style
        self.isDisabled = isDisabled
        self.action = action
    }

    public var body: some View {
        Button {
            action()
        } label: {
            Image(systemName: icon)
                .font(WernickeTypography.size14)
                .foregroundStyle(isDisabled ? V4Color.textTertiary : style.foregroundColor)
                .frame(width: ParietalSpacing.touchFrame, height: 32)
                .background(style.backgroundColor)
                .cornerRadius(V1Theme.cornerSmall)
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
    }
}

// MARK: - Button Style Extensions

extension ThalamusButton.ButtonStyle {
    var backgroundColor: Color {
        switch self {
        case .primary: return V4Color.accent
        case .secondary: return V4Color.surface
        case .ghost: return Color.clear
        case .danger: return V4Color.error
        }
    }

    var foregroundColor: Color {
        switch self {
        case .primary: return .white
        case .secondary: return V4Color.textPrimary
        case .ghost: return V4Color.accent
        case .danger: return .white
        }
    }
}
