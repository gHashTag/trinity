import SwiftUI

struct StatusBadge: View {
    let status: AgentRow.AgentStatus

    var body: some View {
        Text(status.label)
            .font(WernickeTypography.caption2Bold)
            .foregroundStyle(status.color)
            .padding(.horizontal, ParietalSpacing.xs)
            .padding(.vertical, ParietalSpacing.xxs)
            .background(status.color.opacity(V4Color.opacity15))
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
    }
}
