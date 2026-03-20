import SwiftUI

struct ELOChart: View {
    let entries: [(name: String, elo: Double)]

    private var maxElo: Double { entries.map(\.elo).max() ?? 1200 }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                HStack(spacing: ParietalSpacing.md) {
                    Text("#\(idx + 1)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(idx == 0 ? V4Color.golden : V4Color.textSecondary)
                        .frame(width: ParietalSpacing.touchFrame)

                    Text(entry.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(V4Color.textPrimary)
                        .frame(maxWidth: 120, alignment: .leading)

                    GeometryReader { geo in
                        let width = geo.size.width * (entry.elo / maxElo)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(idx))
                            .frame(width: max(width, 4), height: ParietalSpacing.smallIndicatorHeight)
                    }
                    .frame(height: ParietalSpacing.icon)

                    Text(String(format: "%.0f", entry.elo))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(V4Color.accent)
                        .frame(width: ParietalSpacing.mediumFrame, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(V4Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }

    private func barColor(_ idx: Int) -> Color {
        switch idx {
        case 0: return V4Color.golden
        case 1: return V4Color.accent
        case 2: return V4Color.purple
        default: return V4Color.textSecondary
        }
    }
}