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
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            HStack(spacing: ParietalSpacing.sm + 2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(WernickeTypography.size20)
                        .foregroundStyle(V4Color.accent)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(WernickeTypography.bodyEmphasized)
                        .foregroundStyle(V4Color.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }

                Spacer()
            }

            if let content = content {
                Text(content)
                    .font(WernickeTypography.size13)
                    .foregroundStyle(V4Color.textSecondary)
                    .lineLimit(3)
            }
        }
        .padding(ParietalSpacing.lg)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
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
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .fill(V4Color.border.opacity(V2Depth.stateHover))
                    .frame(height: 120)

                if let iconName = iconName {
                    Image(systemName: iconName)
                        .font(WernickeTypography.size40)
                        .foregroundStyle(V4Color.accent.opacity(V2Depth.stateDisabled))
                }

                if let overlayText = overlayText {
                    Text(overlayText)
                        .font(WernickeTypography.captionMedium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, ParietalSpacing.sm)
                        .padding(.vertical, ParietalSpacing.xs)
                        .background(
                            SwiftUI.Capsule()
                                .fill(.black.opacity(V1Theme.opacityTextSecondary))
                        )
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))

            // Text area
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text(title)
                    .font(WernickeTypography.body14Semibold)
                    .foregroundStyle(V4Color.textPrimary)
                    .lineLimit(1)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                        .lineLimit(2)
                }
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm + 2)
        }
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
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
            .padding(ParietalSpacing.lg)
            .background(V4Color.surface)
            .cornerRadius(V1Theme.cornerMedium)
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .stroke(configuration.isPressed ? V4Color.accent : V4Color.border, lineWidth: 1)
            )
            .scaleEffect(configuration.isPressed ? 0.98 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
            .shadow(color: .black.opacity(V2Depth.bgSubtle), radius: configuration.isPressed ? 2 : 4, y: configuration.isPressed ? 1 : 2)
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
            case .positive: return V4Color.success
            case .negative: return V4Color.error
            case .neutral: return V4Color.textSecondary
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
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .textCase(.uppercase)

                Spacer()

                if let icon = icon {
                    Image(systemName: icon)
                        .font(WernickeTypography.size14)
                        .foregroundStyle(V4Color.accent)
                }
            }

            Text(value)
                .font(WernickeTypography.h3Bold)
                .foregroundStyle(V4Color.textPrimary)

            if let change = change, let changeType = changeType {
                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: changeType.icon)
                        .font(WernickeTypography.miniSemibold)

                    Text(change)
                        .font(.caption)
                }
                .foregroundStyle(changeType.color)
            }
        }
        .padding(ParietalSpacing.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
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
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            HStack(spacing: ParietalSpacing.sm + 2) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(WernickeTypography.size20)
                        .foregroundStyle(V4Color.accent)
                }

                Text(title)
                    .font(WernickeTypography.bodyEmphasized)
                    .foregroundStyle(V4Color.textPrimary)
            }

            Text(message)
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textSecondary)

            HStack(spacing: ParietalSpacing.sm) {
                Button(action: primaryAction.action) {
                    Text(primaryAction.title)
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(primaryAction.isDestructive ? .white : V4Color.accent)
                        .padding(.horizontal, ParietalSpacing.md)
                        .padding(.vertical, ParietalSpacing.xs + 2)
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(primaryAction.isDestructive ? V4Color.error : V4Color.accent.opacity(V2Depth.bgSubtle))
                        )
                }
                .buttonStyle(.plain)

                if let secondaryAction = secondaryAction {
                    Button(action: secondaryAction.action) {
                        Text(secondaryAction.title)
                            .font(WernickeTypography.size13)
                            .foregroundStyle(V4Color.textSecondary)
                            .padding(.horizontal, ParietalSpacing.md)
                            .padding(.vertical, ParietalSpacing.xs + 2)
                            .background(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(V4Color.border)
                            )
                    }
                    .buttonStyle(.plain)
                }

                Spacer()
            }
        }
        .padding(ParietalSpacing.lg)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.border, lineWidth: 1)
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
        HStack(spacing: ParietalSpacing.md) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(WernickeTypography.size18)
                    .foregroundStyle(isEnabled ? V4Color.accent : V4Color.textSecondary)
                    .frame(width: 28)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(WernickeTypography.body14Medium)
                    .foregroundStyle(isEnabled ? V4Color.textPrimary : V4Color.textSecondary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            Spacer()

            Toggle("", isOn: $isEnabled)
                .toggleStyle(.switch)
        }
        .padding(14)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isEnabled ? V4Color.accent.opacity(V2Depth.stateHover) : V4Color.border, lineWidth: 1)
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
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .stroke(V4Color.border, lineWidth: bordered ? 1 : 0)
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
            VStack(spacing: ParietalSpacing.md) {
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
            HStack(spacing: ParietalSpacing.md) {
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
            HStack(spacing: ParietalSpacing.md) {
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
                    VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                        Text("Click Me!")
                            .font(WernickeTypography.body14Semibold)
                            .foregroundStyle(V4Color.textPrimary)
                        Text("Interactive card example")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(WernickeTypography.size12)
                        .foregroundStyle(V4Color.textSecondary)
                }
            } action: {
                // Action
            }
            .frame(width: ParietalSpacing.xl * 10)

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
            VStack(spacing: ParietalSpacing.sm) {
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
            .frame(width: ParietalSpacing.xl * 12)
        }
        .padding()
        .background(V4Color.background)
    }
}
