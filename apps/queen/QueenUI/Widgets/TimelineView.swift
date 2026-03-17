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
                    .fill(TrinityTheme.bgCardBorder)
                    .frame(width: 2)
            }
            .padding(.vertical, 8)

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
        iconColor: Color = TrinityTheme.accent,
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
        HStack(alignment: .top, spacing: 12) {
            // Timeline marker
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.2))
                    .frame(width: 28, height: 28)

                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 12))
                        .foregroundStyle(iconColor)
                } else {
                    Circle()
                        .fill(iconColor)
                        .frame(width: 10, height: 10)
                }
            }
            .overlay(
                Circle()
                    .stroke(TrinityTheme.bgCard, lineWidth: 3)
            )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundStyle(TrinityTheme.textMuted)
                }

                Text(timeString)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted.opacity(0.7))
            }
            .padding(.top, 2)

            Spacer()

            if !isLast {
                Rectangle()
                    .fill(TrinityTheme.bgCardBorder)
                    .frame(width: 2)
                    .padding(.leading, 13)
                    .frame(maxHeight: .infinity)
                    .offset(x: -16)
            }
        }
        .padding(.vertical, 4)
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
        HStack(spacing: 12) {
            // User avatar or icon
            ZStack {
                Circle()
                    .fill(activity.color.opacity(0.15))
                    .frame(width: 36, height: 36)

                Image(systemName: activity.icon)
                    .font(.system(size: 14))
                    .foregroundStyle(activity.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(activity.user)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    Text(activity.action)
                        .font(.system(size: 13))
                        .foregroundStyle(TrinityTheme.textMuted)

                    if let target = activity.target {
                        Text(target)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TrinityTheme.accent)
                    }
                }

                Text(relativeTime)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted.opacity(0.7))
            }

            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
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
        HStack(alignment: .top, spacing: 12) {
            ZStack {
                Circle()
                    .fill(activity.color.opacity(0.15))
                    .frame(width: 40, height: 40)

                Image(systemName: activity.icon)
                    .font(.system(size: 16))
                    .foregroundStyle(activity.color)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Text(activity.user)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    Text(activity.action)
                        .font(.system(size: 13))
                        .foregroundStyle(TrinityTheme.textMuted)

                    if let target = activity.target {
                        Text(target)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(TrinityTheme.accent)
                    }
                }

                Text(relativeTime)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .padding(.top, 4)

            Spacer()
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
        .padding(.horizontal, 4)
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
                .fill((current.isCompleted && next.isCompleted) ? TrinityTheme.accent : TrinityTheme.bgCardBorder)
                .frame(height: 24)
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
        HStack(alignment: .top, spacing: 16) {
            // Milestone marker
            ZStack {
                Circle()
                    .fill(milestone.isCompleted ? TrinityTheme.accent.opacity(0.2) : TrinityTheme.bgCardBorder.opacity(0.5))
                    .frame(width: 32, height: 32)

                if milestone.isCompleted {
                    Image(systemName: "checkmark")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(TrinityTheme.accent)
                } else if milestone.isCurrent {
                    Circle()
                        .fill(TrinityTheme.accent)
                        .frame(width: 12, height: 12)
                } else {
                    Circle()
                        .fill(TrinityTheme.bgCardBorder)
                        .frame(width: 10, height: 10)
                }
            }
            .overlay(
                Circle()
                    .stroke(TrinityTheme.bgCard, lineWidth: 3)
            )

            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(milestone.title)
                    .font(.system(size: 14, weight: milestone.isCurrent ? .semibold : .regular))
                    .foregroundStyle(milestone.isCurrent ? TrinityTheme.textPrimary : TrinityTheme.textMuted)

                if let description = milestone.description, isSelected {
                    Text(description)
                        .font(.system(size: 12))
                        .foregroundStyle(TrinityTheme.textMuted)
                }

                Text(dateString)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted.opacity(0.7))
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
        VStack(spacing: 16) {
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
        HStack(spacing: 12) {
            phaseIndicator
                .overlay(
                    Circle()
                        .stroke(TrinityTheme.bgCard, lineWidth: 3)
                )

            Text(phase.title)
                .font(.system(size: 14))
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
                    .font(.system(size: 12, weight: .bold))
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
        case .completed: return TrinityTheme.accent
        case .inProgress: return TrinityTheme.accent
        case .pending: return TrinityTheme.bgCardBorder
        }
    }

    private var textColor: Color {
        switch phase.status {
        case .completed: return TrinityTheme.textPrimary
        case .inProgress: return TrinityTheme.textPrimary
        case .pending: return TrinityTheme.textMuted
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
                return TrinityTheme.accent
            }
            return TrinityTheme.bgCardBorder
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
            .background(TrinityTheme.bgCard)

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
        .background(TrinityTheme.bgWindow)
    }
}
