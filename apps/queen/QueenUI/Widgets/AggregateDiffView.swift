import SwiftUI

/// Aggregate Diff View (Cursor 2.0 pattern)
/// Groups all diff events into a single file-change summary card.
struct AggregateDiffView: View {
    let events: [AgentEvent]
    @State private var expandedFile: String?

    private var diffEvents: [AgentEvent] {
        events.filter { $0.resolvedKind == "diff" }
    }

    private var totalAdded: Int { diffEvents.compactMap(\.added).reduce(0, +) }
    private var totalRemoved: Int { diffEvents.compactMap(\.removed).reduce(0, +) }

    var body: some View {
        if diffEvents.isEmpty { EmptyView() } else {
            VStack(alignment: .leading, spacing: 6) {
                // Header
                HStack(spacing: 8) {
                    Text("\u{1F4C1} FILES CHANGED")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)
                    Spacer()
                    Text("\(diffEvents.count) files")
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                    Text("+\(totalAdded)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(TrinityTheme.statusOK)
                    Text("-\(totalRemoved)")
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(TrinityTheme.statusError)
                }

                // File list
                ForEach(diffEvents) { diff in
                    VStack(alignment: .leading, spacing: 2) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.15)) {
                                expandedFile = expandedFile == diff.id ? nil : diff.id
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: expandedFile == diff.id ? "chevron.down" : "chevron.right")
                                    .font(.caption2)
                                    .foregroundStyle(TrinityTheme.textMuted)
                                    .frame(width: 10)

                                Text(shortPath(diff.file ?? ""))
                                    .font(.caption2.monospaced())
                                    .foregroundStyle(TrinityTheme.textPrimary)
                                    .lineLimit(1)

                                Spacer()

                                if let a = diff.added, a > 0 {
                                    Text("+\(a)")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(TrinityTheme.statusOK)
                                }
                                if let r = diff.removed, r > 0 {
                                    Text("-\(r)")
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(TrinityTheme.statusError)
                                }
                            }
                        }
                        .buttonStyle(.plain)

                        // Expanded preview
                        if expandedFile == diff.id, let preview = diff.preview, !preview.isEmpty {
                            VStack(alignment: .leading, spacing: 1) {
                                ForEach(preview.components(separatedBy: "\n").prefix(8), id: \.self) { line in
                                    Text(line)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(diffLineColor(line))
                                }
                            }
                            .padding(.leading, 16)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(10)
            .background(TrinityTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cardCorner)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
            )
        }
    }

    private func shortPath(_ path: String) -> String {
        let parts = path.components(separatedBy: "/")
        if parts.count <= 3 { return path }
        return parts.suffix(3).joined(separator: "/")
    }

    private func diffLineColor(_ line: String) -> Color {
        if line.hasPrefix("+") { return TrinityTheme.statusOK }
        if line.hasPrefix("-") { return TrinityTheme.statusError }
        return TrinityTheme.textMuted
    }
}
