// Timeline View — Chronological Events Display
import SwiftUI

// MARK: - Timeline

struct TimelineView<Content: View>: View {
    let content: Content
    let style: TimelineStyle

    enum TimelineStyle {
        case plain
        case compact
        case detailed
    }

    init(style: TimelineStyle = .plain, @ViewBuilder content: () -> Content) {
        self.style = style
        self.content = content()
    }

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            // Timeline line
            VStack(spacing: 0) {
                Rectangle()
                    .fill(V4Color.border)
                    .frame(width: 2)
            }
            .padding(.vertical, ParietalSpacing.sm)

            content
        }
    }
}

// MARK: - Timeline Item

struct TimelineItem: View {
    let title: String
    let subtitle: String?
    let time: Date
    let icon: String?
    let iconColor: Color
    let isLast: Bool

    init(
        title: String,
        subtitle: String? = nil,
        time: Date,
        icon: String? = nil,
        iconColor: Color = V4Color.accent,
        isLast: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.time = time
        self.icon = icon
        self.iconColor = iconColor
        self.isLast = isLast
    }

    var body: some View {
        HStack(alignment: .top, spacing: ParietalSpacing.md) {
            // Timeline marker
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 28, height: 28)

                if let icon = icon {
                    Image(systemName: icon)
                        .font(WernickeTypography.size12)
                        .foregroundStyle(iconColor)
                } else {
                    Circle()
                        .fill(iconColor)
                        .frame(width: 10, height: 10)
                }
            }
            .overlay(
                Circle()
                    .stroke(V4Color.surface, lineWidth: 3)
            )

            // Content
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text(title)
                    .font(WernickeTypography.body14Medium)
                    .foregroundStyle(V4Color.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(WernickeTypography.size12)
                        .foregroundStyle(V4Color.textSecondary)
                }

                Text(timeString)
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary.opacity(0.7))
            }
            .padding(.top, 2)

            Spacer()

            if !isLast {
                Rectangle()
                    .fill(V4Color.border)
                    .frame(width: 2)
                    .padding(.leading, 13)
                    .frame(maxHeight: .infinity)
                    .offset(x: -16)
            }
        }
        .padding(.vertical, ParietalSpacing.xs)
    }

    private var timeString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: time, relativeTo: Date())
    }
}

// MARK: - Activity Feed

struct ActivityFeed: View {
    let activities: [Activity]
    let style: FeedStyle

    enum FeedStyle {
        case list
        case cards
    }

    struct Activity: Identifiable {
        let id = UUID()
        let user: String
        let action: String
        let target: String?
        let time: Date
        let icon: String
        let color: Color
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(activities.enumerated()), id: \.element.id) { index, activity in
                if style == .list {
                    ActivityRow(activity: activity)
                } else {
                    ActivityCard(activity: activity)
                }

                if index < activities.count - 1 {
                    Divider()
                        .padding(.leading, style == .list ? 60 : 0)
                }
            }
        }
    }
}

// MARK: - Activity Row

struct ActivityRow: View {
    let activity: ActivityFeed.Activity

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            // User avatar or icon
            ZStack {
                Circle()
                    .fill(activity.color.opacity(V2Depth.bgSidebarHover))
                    .frame(width: 36, height: 36)

                Image(systemName: activity.icon)
                    .font(WernickeTypography.size14)
                    .foregroundStyle(activity.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: ParietalSpacing.xs) {
                    Text(activity.user)
                        .font(WernickeTypography.smallMedium)
                        .foregroundStyle(V4Color.textPrimary)

                    Text(activity.action)
                        .font(WernickeTypography.size13)
                        .foregroundStyle(V4Color.textSecondary)

                    if let target = activity.target {
                        Text(target)
                            .font(WernickeTypography.smallMedium)
                            .foregroundStyle(V4Color.accent)
                    }
                }

                Text(relativeTime)
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary.opacity(0.7))
            }

            Spacer()
        }
        .padding(.vertical, ParietalSpacing.sm)
        .padding(.horizontal, ParietalSpacing.md)
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: activity.time, relativeTo: Date())
    }
}

// MARK: - Activity Card

struct ActivityCard: View {
    let activity: ActivityFeed.Activity

    var body: some View {
        HStack(alignment: .top, spacing: ParietalSpacing.md) {
            ZStack {
                Circle()
                    .fill(activity.color.opacity(V2Depth.bgSidebarHover))
                    .frame(width: 40, height: 40)

                Image(systemName: activity.icon)
                    .font(WernickeTypography.size16)
                    .foregroundStyle(activity.color)
            }

            VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
                HStack(spacing: ParietalSpacing.xs) {
                    Text(activity.user)
                        .font(WernickeTypography.smallSemibold)
                        .foregroundStyle(V4Color.textPrimary)

                    Text(activity.action)
                        .font(WernickeTypography.size13)
                        .foregroundStyle(V4Color.textSecondary)

                    if let target = activity.target {
                        Text(target)
                            .font(WernickeTypography.smallMedium)
                            .foregroundStyle(V4Color.accent)
                    }
                }

                Text(relativeTime)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .padding(.horizontal, ParietalSpacing.xs)
    }

    private var relativeTime: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: activity.time, relativeTo: Date())
    }
}

// MARK: - Milestone Timeline

struct MilestoneTimeline: View {
    let milestones: [Milestone]
    @State private var selectedIndex: Int?

    struct Milestone: Identifiable {
        let id = UUID()
        let title: String
        let date: Date
        let description: String?
        let isCompleted: Bool
        let isCurrent: Bool
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(milestones.enumerated()), id: \.element.id) { index, milestone in
                MilestoneRow(
                    milestone: milestone,
                    isSelected: selectedIndex == index
                ) {
                    withAnimation {
                        selectedIndex = index
                    }
                }

                if index < milestones.count - 1 {
                    milestoneConnector(for: milestone, and: milestones[index + 1])
                }
            }
        }
    }

    private func milestoneConnector(for current: Milestone, and next: Milestone) -> some View {
        VStack(spacing: 0) {
            Rectangle()
                .fill((current.isCompleted && next.isCompleted) ? V4Color.accent : V4Color.border)
                .frame(height: ParietalSpacing.iconLarge)
        }
        .frame(width: 2)
        .padding(.leading, 15)
    }
}

// MARK: - Milestone Row

struct MilestoneRow: View {
    let milestone: MilestoneTimeline.Milestone
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: ParietalSpacing.lg) {
            // Milestone marker
            ZStack {
                Circle()
                    .fill(milestone.isCompleted ? V4Color.accent.opacity(0.2) : V4Color.border.opacity(V2Depth.stateDisabled))
                    .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)

                if milestone.isCompleted {
                    Image(systemName: "checkmark")
                        .font(WernickeTypography.captionBold)
                        .foregroundStyle(V4Color.accent)
                } else if milestone.isCurrent {
                    Circle()
                        .fill(V4Color.accent)
                        .frame(width: ParietalSpacing.sm, height: ParietalSpacing.sm)
                } else {
                    Circle()
                        .fill(V4Color.border)
                        .frame(width: 10, height: 10)
                }
            }
            .overlay(
                Circle()
                    .stroke(V4Color.surface, lineWidth: 3)
            )

            // Content
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text(milestone.title)
                    .font(milestone.isCurrent ? WernickeTypography.body14Semibold : WernickeTypography.size14)
                    .foregroundStyle(milestone.isCurrent ? V4Color.textPrimary : V4Color.textSecondary)

                if let description = milestone.description, isSelected {
                    Text(description)
                        .font(WernickeTypography.size12)
                        .foregroundStyle(V4Color.textSecondary)
                }

                Text(dateString)
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary.opacity(0.7))
            }
            .padding(.top, 4)

            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: onTap)
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: milestone.date)
    }
}

// MARK: - Progress Timeline

struct ProgressTimeline: View {
    let phases: [Phase]

    struct Phase: Identifiable {
        let id = UUID()
        let title: String
        let status: PhaseStatus

        enum PhaseStatus {
            case pending, inProgress, completed
        }
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.lg) {
            ForEach(Array(phases.enumerated()), id: \.element.id) { index, phase in
                PhaseRow(phase: phase, isLast: index == phases.count - 1)

                if index < phases.count - 1 {
                    PhaseConnector(phases: phases, currentIndex: index)
                }
            }
        }
    }
}

// MARK: - Phase Row

struct PhaseRow: View {
    let phase: ProgressTimeline.Phase
    let isLast: Bool

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            phaseIndicator
                .overlay(
                    Circle()
                        .stroke(V4Color.surface, lineWidth: 3)
                )

            Text(phase.title)
                .font(WernickeTypography.size14)
                .foregroundStyle(textColor)

            Spacer()
        }
    }

    private var phaseIndicator: some View {
        ZStack {
            Circle()
                .fill(backgroundColor)
                .frame(width: 28, height: 28)

            switch phase.status {
            case .completed:
                Image(systemName: "checkmark")
                    .font(WernickeTypography.captionBold)
                    .foregroundStyle(.white)
            case .inProgress:
                ProgressView()
                    .scaleEffect(0.7)
                    .tint(.white)
            case .pending:
                EmptyView()
            }
        }
    }

    private var backgroundColor: Color {
        switch phase.status {
        case .completed: return V4Color.accent
        case .inProgress: return V4Color.accent
        case .pending: return V4Color.border
        }
    }

    private var textColor: Color {
        switch phase.status {
        case .completed: return V4Color.textPrimary
        case .inProgress: return V4Color.textPrimary
        case .pending: return V4Color.textSecondary
        }
    }
}

// MARK: - Phase Connector

struct PhaseConnector: View {
    let phases: [ProgressTimeline.Phase]
    let currentIndex: Int

    var body: some View {
        let currentPhase = phases[currentIndex]
        let nextPhase = phases[currentIndex + 1]

        let color: Color = {
            if currentPhase.status == .completed && nextPhase.status != .pending {
                return V4Color.accent
            }
            return V4Color.border
        }()

        return Rectangle()
            .fill(color)
            .frame(width: 2, height: 24)
            .padding(.leading, 13)
    }
}

// MARK: - Preview

struct TimelineView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            TimelineView {
                VStack(spacing: 0) {
                    TimelineItem(
                        title: "Project Started",
                        subtitle: "Initial setup complete",
                        time: Date().addingTimeInterval(-86400 * 5),
                        icon: "play.fill",
                        iconColor: .green
                    )
                    TimelineItem(
                        title: "Design Phase",
                        subtitle: "UI/UX mockups completed",
                        time: Date().addingTimeInterval(-86400 * 3),
                        icon: "paintbrush.fill",
                        iconColor: .blue
                    )
                    TimelineItem(
                        title: "Development",
                        subtitle: "Currently in progress",
                        time: Date(),
                        icon: "hammer.fill",
                        iconColor: .orange,
                        isLast: true
                    )
                }
                .padding(.leading, 16)
            }
            .padding()
            .background(V4Color.surface)

            MilestoneTimeline(
                milestones: [
                    MilestoneTimeline.Milestone(title: "Planning", date: Date().addingTimeInterval(-10), description: "Requirements gathering", isCompleted: true, isCurrent: false),
                    MilestoneTimeline.Milestone(title: "Design", date: Date().addingTimeInterval(-5), description: "UI mockups created", isCompleted: true, isCurrent: false),
                    MilestoneTimeline.Milestone(title: "Development", date: Date(), description: "Active development phase", isCompleted: false, isCurrent: true),
                    MilestoneTimeline.Milestone(title: "Launch", date: Date().addingTimeInterval(10), description: "Product launch", isCompleted: false, isCurrent: false)
                ]
            )
            .padding()
        }
        .padding()
        .background(V4Color.background)
    }
}
