// Card Patterns — Various Card Styles for Queen UI
import SwiftUI

// MARK: - Content Card

struct ContentCard: View {
    let title: String
    let subtitle: String?
    let content: String?
    let icon: String?
    let elevated: Bool
    let bordered: Bool

    init(
        title: String,
        subtitle: String? = nil,
        content: String? = nil,
        icon: String? = nil,
        elevated: Bool = true,
        bordered: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.content = content
        self.icon = icon
        self.elevated = elevated
        self.bordered = bordered
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(TrinityTheme.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }

                Spacer()
            }

            if let content = content {
                Text(content)
                    .font(.system(size: 13))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .lineLimit(3)
            }
        }
        .padding(16)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
        .cardModifier(elevated: elevated, bordered: bordered)
    }
}

// MARK: - Media Card

struct MediaCard: View {
    let title: String
    let subtitle: String?
    let iconName: String?
    let overlayText: String?
    let elevated: Bool

    init(
        title: String,
        subtitle: String? = nil,
        iconName: String? = nil,
        overlayText: String? = nil,
        elevated: Bool = true
    ) {
        self.title = title
        self.subtitle = subtitle
        self.iconName = iconName
        self.overlayText = overlayText
        self.elevated = elevated
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Media area
            ZStack {
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .fill(TrinityTheme.bgCardBorder.opacity(0.3))
                    .frame(height: 120)

                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(.system(size: 40))
                        .foregroundStyle(TrinityTheme.accent.opacity(0.5))
                }

                if let overlayText = overlayText {
                    Text(overlayText)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(.black.opacity(0.6))
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))

            // Text area
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
        .cardModifier(elevated: elevated, bordered: false)
    }
}

// MARK: - Interactive Card

struct InteractiveCard<Content: View>: View {
    let content: () -> Content
    let action: () -> Void
    @State private var isPressed = false
    @State private var isHovered = false

    init(@ViewBuilder content: @escaping () -> Content, action: @escaping () -> Void) {
        self.content = content
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            content()
        }
        .buttonStyle(InteractiveCardButtonStyle())
    }
}

struct InteractiveCardButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(16)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerMedium)
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .stroke(configuration.isPressed ? TrinityTheme.accent : TrinityTheme.bgCardBorder, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(color: .black.opacity(0.1), radius: configuration.isPressed ? 2 : 4, y: configuration.isPressed ? 1 : 2)
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let title: String
    let value: String
    let change: String?
    let changeType: ChangeType?
    let icon: String?

    enum ChangeType {
        case positive
        case negative
        case neutral

        var color: Color {
            switch self {
            case .positive: return TrinityTheme.statusOK
            case .negative: return TrinityTheme.statusError
            case .neutral: return TrinityTheme.textMuted
            }
        }

        var icon: String {
            switch self {
            case .positive: return "arrow.up.right"
            case .negative: return "arrow.down.right"
            case .neutral: return "minus"
            }
        }
    }

    init(
        title: String,
        value: String,
        change: String? = nil,
        changeType: ChangeType? = nil,
        icon: String? = nil
    ) {
        self.title = title
        self.value = value
        self.change = change
        self.changeType = changeType
        self.icon = icon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .textCase(.uppercase)

                Spacer()

                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundStyle(TrinityTheme.accent)
                }
            }

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(TrinityTheme.textPrimary)

            if let change = change, let changeType = changeType {
                HStack(spacing: 4) {
                    Image(systemName: changeType.icon)
                        .font(.system(size: 10, weight: .semibold))

                    Text(change)
                        .font(.caption)
                }
                .foregroundStyle(changeType.color)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}

// MARK: - Action Card

struct ActionCard: View {
    let title: String
    let message: String
    let primaryAction: ActionConfig
    let secondaryAction: ActionConfig?
    let icon: String?

    struct ActionConfig {
        let title: String
        let action: () -> Void
        let isDestructive: Bool

        init(_ title: String, isDestructive: Bool = false, action: @escaping () -> Void) {
            self.title = title
            self.action = action
            self.isDestructive = isDestructive
        }
    }

    init(
        title: String,
        message: String,
        primaryAction: ActionConfig,
        secondaryAction: ActionConfig? = nil,
        icon: String? = nil
    ) {
        self.title = title
        self.message = message
        self.primaryAction = primaryAction
        self.secondaryAction = secondaryAction
        self.icon = icon
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 20))
                        .foregroundStyle(TrinityTheme.accent)
                }

                Text(title)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)
            }

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textMuted)

            HStack(spacing: 8) {
                Button(action: primaryAction.action) {
                    Text(primaryAction.title)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(primaryAction.isDestructive ? .white : TrinityTheme.accent)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(primaryAction.isDestructive ? TrinityTheme.statusError : TrinityTheme.accent.opacity(0.1))
                        )
                }
                .buttonStyle(.plain)

                if let secondaryAction = secondaryAction {
                    Button(action: secondaryAction.action) {
                        Text(secondaryAction.title)
                            .font(.system(size: 13))
                            .foregroundStyle(TrinityTheme.textMuted)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(TrinityTheme.bgCardBorder)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .padding(16)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Settings Card

struct SettingsCard: View {
    let title: String
    let subtitle: String?
    @Binding var isEnabled: Bool
    let icon: String?

    init(
        title: String,
        subtitle: String? = nil,
        isEnabled: Binding<Bool>,
        icon: String? = nil
    ) {
        self.title = title
        self.subtitle = subtitle
        self._isEnabled = isEnabled
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isEnabled ? TrinityTheme.accent : TrinityTheme.textMuted)
                    .frame(width: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isEnabled ? TrinityTheme.textPrimary : TrinityTheme.textMuted)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
        }
        .padding(14)
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(isEnabled ? TrinityTheme.accent.opacity(0.3) : TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Card Modifier

private struct CardModifier: ViewModifier {
    let elevated: Bool
    let bordered: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: bordered ? 1 : 0)
            )
            .shadow(
                color: .black.opacity(elevated ? 0.1 : 0),
                radius: elevated ? 8 : 0,
                y: elevated ? 4 : 0
            )
    }
}

extension View {
    fileprivate func cardModifier(elevated: Bool, bordered: Bool) -> some View {
        modifier(CardModifier(elevated: elevated, bordered: bordered))
    }
}

// MARK: - Preview

struct CardPatterns_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Content cards
            VStack(spacing: 12) {
                ContentCard(
                    title: "Welcome to Trinity",
                    subtitle: "Getting Started",
                    content: "Learn the basics of the Trinity AI system and start building autonomous agents.",
                    icon: "sparkles"
                )

                ContentCard(
                    title: "Quick Setup",
                    icon: "gearshape.fill",
                    elevated: false,
                    bordered: true
                )
            }
            .frame(width: 350)

            // Media cards
            HStack(spacing: 12) {
                MediaCard(
                    title: "Neural Networks",
                    subtitle: "Deep Learning",
                    iconName: "brain.head.profile",
                    overlayText: "AI"
                )

                MediaCard(
                    title: "FPGA Synthesis",
                    subtitle: "Hardware Acceleration",
                    iconName: "cpu"
                )
            }
            .frame(width: 350)

            // Metric cards
            HStack(spacing: 12) {
                MetricCard(
                    title: "Total Requests",
                    value: "24,589",
                    change: "+12.5%",
                    changeType: .positive,
                    icon: "chart.line.uptrend.xyaxis"
                )

                MetricCard(
                    title: "Error Rate",
                    value: "0.02%",
                    change: "-0.01%",
                    changeType: .positive,
                    icon: "checkmark.shield.fill"
                )

                MetricCard(
                    title: "Latency",
                    value: "45ms",
                    change: "+5ms",
                    changeType: .negative,
                    icon: "speedometer"
                )
            }
            .frame(width: 600)

            // Interactive card
            InteractiveCard {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Click Me!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TrinityTheme.textPrimary)
                        Text("Interactive card example")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            } action: {
                // Action
            }
            .frame(width: 250)

            // Action card
            ActionCard(
                title: "Delete Thread",
                message: "This action cannot be undone. All messages will be permanently removed.",
                primaryAction: .init("Delete", isDestructive: true) { },
                secondaryAction: .init("Cancel") { },
                icon: "trash.fill"
            )
            .frame(width: 320)

            // Settings card
            VStack(spacing: 8) {
                SettingsCard(
                    title: "Auto-save",
                    subtitle: "Automatically save drafts",
                    isEnabled: .constant(true),
                    icon: "externaldrive.fill"
                )

                SettingsCard(
                    title: "Notifications",
                    subtitle: "Receive push notifications",
                    isEnabled: .constant(false),
                    icon: "bell.fill"
                )
            }
            .frame(width: 300)
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
