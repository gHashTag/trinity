import SwiftUI

struct ELOChart: View {
    let entries: [(name: String, elo: Double)]

    private var maxElo: Double { entries.map(\.elo).max() ?? 1200 }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(entries.enumerated()), id: \.offset) { idx, entry in
                HStack(spacing: 12) {
                    Text("#\(idx + 1)")
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(idx == 0 ? TrinityTheme.golden : TrinityTheme.textMuted)
                        .frame(width: 30)

                    Text(entry.name)
                        .font(.body.weight(.medium))
                        .foregroundStyle(TrinityTheme.textPrimary)
                        .frame(maxWidth: 120, alignment: .leading)

                    GeometryReader { geo in
                        let width = geo.size.width * (entry.elo / maxElo)

                        RoundedRectangle(cornerRadius: 3)
                            .fill(barColor(idx))
                            .frame(width: max(width, 4), height: 16)
                    }
                    .frame(height: 16)

                    Text(String(format: "%.0f", entry.elo))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(TrinityTheme.accent)
                        .frame(width: 50, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cardCorner)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }

    private func barColor(_ idx: Int) -> Color {
        switch idx {
        case 0: return TrinityTheme.golden
        case 1: return TrinityTheme.accent
        case 2: return TrinityTheme.purple
        default: return TrinityTheme.textMuted
        }
    }
}