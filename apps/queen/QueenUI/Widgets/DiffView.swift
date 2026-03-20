import SwiftUI

struct DiffView: View {
    let event: AgentEvent
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            // Header: file path + counts
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { expanded.toggle() }
            } label: {
                HStack(spacing: ParietalSpacing.sm) {
                    Text("\u{1F4DD}")
                        .font(.caption)
                    Text(event.file ?? "unknown")
                        .font(.caption.monospaced())
                        .foregroundStyle(V4Color.textPrimary)
                        .lineLimit(1)

                    Spacer()

                    if let added = event.added, added > 0 {
                        Text("+\(added)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(V4Color.success)
                    }
                    if let removed = event.removed, removed > 0 {
                        Text("-\(removed)")
                            .font(.caption2.monospaced())
                            .foregroundStyle(V4Color.error)
                    }
                }
            }
            .buttonStyle(.plain)

            // Preview lines (expanded)
            if expanded, let preview = event.preview, !preview.isEmpty {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(preview.components(separatedBy: "\n"), id: \.self) { line in
                        Text(line)
                            .font(.caption2.monospaced())
                            .foregroundStyle(lineColor(line))
                    }
                }
                .padding(.leading, 20)
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.xs + 2)
        .background(V4Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func lineColor(_ line: String) -> Color {
        if line.hasPrefix("+") { return V4Color.success }
        if line.hasPrefix("-") { return V4Color.error }
        return V4Color.textSecondary
    }
}
