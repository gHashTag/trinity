import SwiftUI

struct ToolCallRow: View {
    let event: AgentEvent
    @State private var expanded = false

    private let maxCollapsedLines = 3

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Main row: icon + command + duration + status
            Button {
                if event.output != nil { withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() } }
            } label: {
                HStack(spacing: 8) {
                    Text(event.resolvedKind == "cli" ? "\u{25B6}" : "\u{25CF}")
                        .font(.caption.monospaced())
                        .foregroundStyle(iconColor)

                    Text(commandText)
                        .font(.caption.monospaced())
                        .foregroundStyle(TrinityTheme.textPrimary)
                        .lineLimit(1)

                    Spacer(minLength: 4)

                    if event.isCompleted {
                        Text(durationText)
                            .font(.caption2.monospaced())
                            .foregroundStyle(TrinityTheme.textMuted)
                        Text(statusIcon)
                            .font(.caption)
                    } else {
                        ThinkingDots()
                    }

                    // Chevron if output available
                    if event.output != nil {
                        Image(systemName: expanded ? "chevron.down" : "chevron.right")
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }
            }
            .buttonStyle(.plain)

            // Collapsible output
            if expanded, let output = event.output, !output.isEmpty {
                let lines = output.components(separatedBy: "\n")
                let visibleLines = lines.prefix(maxCollapsedLines)

                VStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(visibleLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.caption2.monospaced())
                            .foregroundStyle(TrinityTheme.textMuted)
                            .lineLimit(1)
                    }
                    if lines.count > maxCollapsedLines {
                        Text("... \(lines.count - maxCollapsedLines) more lines")
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.accent.opacity(0.7))
                    }
                }
                .padding(.top, 4)
                .padding(.leading, 20)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var commandText: String {
        if let cmd = event.cmd { return cmd }
        if let tool = event.tool {
            if let args = event.args { return "\(tool) \(args)" }
            return tool
        }
        return "..."
    }

    private var durationText: String {
        guard let ms = event.ms else { return "" }
        if ms >= 1000 {
            return String(format: "%.1fs", Double(ms) / 1000.0)
        }
        return "\(ms)ms"
    }

    private var statusIcon: String {
        if let exit = event.exit { return exit == 0 ? "\u{2713}" : "\u{2717}" }
        if let result = event.result { return result == "OK" ? "\u{2713}" : "\u{2717}" }
        return "?"
    }

    private var iconColor: Color {
        if !event.isCompleted { return TrinityTheme.accent }
        if let exit = event.exit { return exit == 0 ? TrinityTheme.statusOK : TrinityTheme.statusError }
        if let result = event.result { return result == "OK" ? TrinityTheme.statusOK : TrinityTheme.statusError }
        return TrinityTheme.textMuted
    }
}
