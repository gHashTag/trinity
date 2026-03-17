// Badge System — Various Badge Styles for UI Indicators
import SwiftUI

// MARK: - Count Badge

struct CountBadge: View {
    let count: Int
    let size: BadgeSize
    let color: Color
    let hideWhenZero: Bool

    enum BadgeSize {
        case small
        case medium
        case large

        var fontSize: CGFloat {
            switch self {
            case .small: return 9
            case .medium: return 10
            case .large: return 11
            }
        }

        var padding: CGFloat {
            switch self {
            case .small: return 3
            case .medium: return 4
            case .large: return 5
            }
        }

        var minWidth: CGFloat {
            switch self {
            case .small: return 16
            case .medium: return 18
            case .large: return 20
            }
        }
    }

    init(_ count: Int, size: BadgeSize = .medium, color: Color = TrinityTheme.statusError, hideWhenZero: Bool = true) {
        self.count = count
        self.size = size
        self.color = color
        self.hideWhenZero = hideWhenZero
    }

    var body: some View {
        if count != 0 || !hideWhenZero {
            Text(displayText)
                .font(.system(size: size.fontSize, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, size.padding)
                .frame(minWidth: size.minWidth)
                .background(
                    Capsule()
                        .fill(color)
                )
                .accessibilityLabel("Notification count")
                .accessibilityValue("\(count)")
        }
    }

    private var displayText: String {
        count > 99 ? "99+" : "\(count)"
    }
}

// MARK: - Status Indicator

struct StatusIndicator: View {
    let status: Status
    let size: BadgeSize

    enum Status {
        case success
        case warning
        case error
        case info
        case processing
        case disabled

        var color: Color {
            switch self {
            case .success: return TrinityTheme.statusOK
            case .warning: return TrinityTheme.statusWarn
            case .error: return TrinityTheme.statusError
            case .info: return TrinityTheme.accent
            case .processing: return TrinityTheme.accent
            case .disabled: return TrinityTheme.textMuted
            }
        }

        var icon: String {
            switch self {
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            case .info: return "info.circle.fill"
            case .processing: return "hourglass"
            case .disabled: return "minus.circle.fill"
            }
        }
    }

    enum BadgeSize {
        case small
        case medium
        case large

        var font: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 11
            case .large: return 12
            }
        }

        var iconSize: CGFloat {
            switch self {
            case .small: return 10
            case .medium: return 11
            case .large: return 12
            }
        }

        var padding: (horizontal: CGFloat, vertical: CGFloat) {
            switch self {
            case .small: return (6, 3)
            case .medium: return (8, 4)
            case .large: return (10, 5)
            }
        }
    }

    init(_ status: Status) {
        self.status = status
        self.size = .medium
    }

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: status.icon)
                .font(.system(size: size.iconSize))

            Text(labelText)
                .font(.system(size: size.font, weight: .medium))
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, size.padding.horizontal)
        .padding(.vertical, size.padding.vertical)
        .background(
            Capsule()
                .fill(status.color.opacity(0.15))
        )
        .accessibilityLabel("Status")
        .accessibilityValue(labelText)
    }

    private var labelText: String {
        switch status {
        case .success: return "Success"
        case .warning: return "Warning"
        case .error: return "Error"
        case .info: return "Info"
        case .processing: return "Processing"
        case .disabled: return "Disabled"
        }
    }
}

// MARK: - Pill Badge

struct PillBadge: View {
    let text: String
    let color: Color
    let size: PillSize

    enum PillSize {
        case small
        case medium
        case large

        var font: Font {
            switch self {
            case .small: return .caption2
            case .medium: return .caption
            case .large: return .subheadline
            }
        }

        var padding: (horizontal: CGFloat, vertical: CGFloat) {
            switch self {
            case .small: return (6, 3)
            case .medium: return (8, 4)
            case .large: return (10, 5)
            }
        }
    }

    init(_ text: String, color: Color = TrinityTheme.accent, size: PillSize = .medium) {
        self.text = text
        self.color = color
        self.size = size
    }

    var body: some View {
        Text(text)
            .font(size.font.weight(.medium))
            .foregroundStyle(color)
            .padding(.horizontal, size.padding.horizontal)
            .padding(.vertical, size.padding.vertical)
            .background(
                Capsule()
                    .fill(color.opacity(0.15))
            )
            .accessibilityLabel("Badge")
            .accessibilityValue(text)
    }
}

// MARK: - Dot Badge

struct DotBadge: View {
    let color: Color
    let size: CGFloat
    let isAnimated: Bool

    init(color: Color = TrinityTheme.statusError, size: CGFloat = 8, isAnimated: Bool = false) {
        self.color = color
        self.size = size
        self.isAnimated = isAnimated
    }

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .opacity(isAnimated ? 0 : 1)
            )
            .overlay(
                Circle()
                    .stroke(color, lineWidth: 2)
                    .scaleEffect(isAnimated ? 2 : 0)
                    .opacity(isAnimated ? 0 : 1)
            )
            .animation(isAnimated ? .easeOut(duration: 1).repeatForever(autoreverses: false) : .default, value: isAnimated)
            .accessibilityLabel("Status indicator")
            .accessibilityValue("Active")
    }
}

// MARK: - Icon Badge

struct IconBadge: View {
    let icon: String
    let count: Int?
    let color: Color

    init(icon: String, count: Int? = nil, color: Color = TrinityTheme.statusError) {
        self.icon = icon
        self.count = count
        self.color = color
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundStyle(TrinityTheme.textMuted)

            if let count = count, count > 0 {
                Text(count > 99 ? "99+" : "\(count)")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 3)
                    .padding(.vertical, 1)
                    .background(
                        Capsule()
                            .fill(color)
                    )
                    .offset(x: 4, y: -4)
            }
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - View Modifiers

extension View {
    func badge(_ count: Int) -> some View {
        overlay(alignment: .topTrailing) {
            CountBadge(count)
                .offset(x: 8, y: -8)
        }
    }

    func statusBadge(_ status: StatusIndicator.Status) -> some View {
        overlay(alignment: .topTrailing) {
            StatusIndicator(status)
                .offset(x: 4, y: -4)
        }
    }

    func dotBadge(color: Color = TrinityTheme.statusError, isAnimated: Bool = false) -> some View {
        overlay(alignment: .topTrailing) {
            DotBadge(color: color, isAnimated: isAnimated)
                .offset(x: 6, y: -6)
        }
    }
}

// MARK: - Preview

struct BadgeSystem_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Count badges
            HStack(spacing: 16) {
                CountBadge(0)
                CountBadge(1)
                CountBadge(5)
                CountBadge(99)
                CountBadge(150)
                CountBadge(3, size: .small)
                CountBadge(3, size: .large)
            }
            .padding()

            // Status indicators
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    StatusIndicator(.success)
                    StatusIndicator(.warning)
                    StatusIndicator(.error)
                    StatusIndicator(.info)
                    StatusIndicator(.processing)
                    StatusIndicator(.disabled)
                }
            }
            .padding()

            // Pill badges
            HStack(spacing: 8) {
                PillBadge("New")
                PillBadge("Updated", color: TrinityTheme.accent)
                PillBadge("Beta", color: TrinityTheme.statusWarn)
                PillBadge("Deprecated", color: TrinityTheme.statusError)
            }
            .padding()

            // Dot badges
            HStack(spacing: 16) {
                DotBadge()
                DotBadge(color: TrinityTheme.statusOK)
                DotBadge(color: TrinityTheme.accent)
                DotBadge(isAnimated: true)
            }
            .padding()

            // Icon badges
            HStack(spacing: 24) {
                IconBadge(icon: "bell.fill")
                IconBadge(icon: "bell.fill", count: 1)
                IconBadge(icon: "bell.fill", count: 5)
                IconBadge(icon: "envelope.fill", count: 99, color: TrinityTheme.accent)
            }
            .padding()
        }
        .background(TrinityTheme.bgWindow)
    }
}
