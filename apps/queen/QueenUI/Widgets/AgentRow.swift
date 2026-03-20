import SwiftUI

struct AgentRow: View {
    let name: String
    let status: AgentStatus
    let wakeCount: Int?
    let detail: String?

    @State private var isHovered = false

    enum AgentStatus: Equatable {
        case up, down, stub

        var color: Color {
            switch self {
            case .up: return V4Color.statusOK
            case .down: return V4Color.statusError
            case .stub: return V4Color.textSecondary
            }
        }

        var label: String {
            switch self {
            case .up: return "UP"
            case .down: return "DOWN"
            case .stub: return "STUB"
            }
        }
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            Text(agentEmoji)
                .font(WernickeTypography.h2)

            VStack(alignment: .leading, spacing: ParietalSpacing.xxxs) {
                Text(name.uppercased())
                    .font(WernickeTypography.h5)
                    .foregroundStyle(V4Color.textPrimary)
                if let detail {
                    Text(detail)
                        .font(WernickeTypography.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            Spacer()

            if let wakeCount {
                Text("Wake #\(wakeCount)")
                    .font(WernickeTypography.captionMono)
                    .foregroundStyle(V4Color.textSecondary)
            }

            // Pulsing status dot
            AgentStatusDot(status: status)

            StatusBadge(status: status)
        }
        .padding()
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.bgCardBorder, lineWidth: 1)
        )
        .scaleEffect(isHovered ? MTMotion.hoverScale : 1.0)
        .onHover { isHovered = $0 }
        .animation(MTMotion.quick, value: isHovered)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(name) agent")
        .accessibilityValue("\(status.label), wake \(wakeCount ?? 0)")
    }

    private var agentEmoji: String {
        switch name.lowercased() {
        case "mu": return "\u{1F9E0}"
        case "scholar": return "\u{1F4DA}"
        case "ralph": return "\u{1F916}"
        case "oracle": return "\u{1F52E}"
        case "queen": return "\u{1F451}"
        default: return "\u{1F41D}"
        }
    }
}

// MARK: - Pulsing Status Dot

struct AgentStatusDot: View {
    let status: AgentRow.AgentStatus
    @State private var pulse = false

    var body: some View {
        ZStack {
            // Outer pulse ring (only for non-UP states)
            if status != .up {
                Circle()
                    .stroke(dotColor.opacity(V4Color.opacity30), lineWidth: 1)
                    .frame(width: ParietalSpacing.avatarSmall - 14, height: ParietalSpacing.avatarSmall - 14)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0 : V4Color.opacity70)
            }

            // Inner solid dot
            Circle()
                .fill(dotColor)
                .frame(width: ParietalSpacing.statusDot, height: ParietalSpacing.statusDot)
        }
        .frame(width: ParietalSpacing.icon + 4, height: ParietalSpacing.icon + 4)
        .onAppear {
            if status != .up {
                withAnimation(pulseAnimation) {
                    pulse = true
                }
            }
        }
    }

    private var dotColor: Color {
        status.color
    }

    private var pulseAnimation: Animation {
        switch status {
        case .up:
            return .default
        case .stub:
            return Animation.easeInOut(duration: MTMotion.durationExtraSlow).repeatForever(autoreverses: true)
        case .down:
            return Animation.easeInOut(duration: MTMotion.durationSlow).repeatForever(autoreverses: true)
        }
    }
}
