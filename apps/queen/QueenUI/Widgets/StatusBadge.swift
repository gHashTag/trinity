import SwiftUI

struct StatusBadge: View {
    let status: AgentRow.AgentStatus

    var body: some View {
        Text(status.label)
            .font(.caption2.weight(.bold))
            .foregroundStyle(status.color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(status.color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}