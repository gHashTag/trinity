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
            case .up: return TrinityTheme.statusOK
            case .down: return TrinityTheme.statusError
            case .stub: return TrinityTheme.textMuted
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
        HStack(spacing: 12) {
            Text(agentEmoji)
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text(name.uppercased())
                    .font(.headline)
                    .foregroundStyle(TrinityTheme.textPrimary)
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }

            Spacer()

            if let wakeCount {
                Text("Wake #\(wakeCount)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            // Pulsing status dot
            AgentStatusDot(status: status)

            StatusBadge(status: status)
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cardCorner)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
        .scaleEffect(isHovered ? 1.01 : 1.0)
        .onHover { isHovered = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovered)
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
                    .stroke(dotColor.opacity(0.3), lineWidth: 1)
                    .frame(width: 18, height: 18)
                    .scaleEffect(pulse ? 1.6 : 1.0)
                    .opacity(pulse ? 0 : 0.7)
            }

            // Inner solid dot
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
        }
        .frame(width: 20, height: 20)
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
            return .easeInOut(duration: 2.0).repeatForever(autoreverses: true)
        case .down:
            return .easeInOut(duration: 0.7).repeatForever(autoreverses: true)
        }
    }
}
