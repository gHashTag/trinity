import SwiftUI

struct StatCard: View, Equatable {
    let label: String
    let value: String
    var accent: Color = TrinityTheme.accent
    var history: [Double] = []

    static func == (lhs: StatCard, rhs: StatCard) -> Bool {
        lhs.label == rhs.label && lhs.value == rhs.value && lhs.history == rhs.history
    }

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 3, height: 16)
                Text(label)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .padding(.leading, 8)
            }
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(TrinityTheme.textPrimary)
                .accessibilityLabel(label)
                .accessibilityValue(value)

            // Sparkline (Canvas-based, zero SwiftUI diffing cost)
            if history.count >= 2 {
                Canvas { ctx, size in
                    let mn = history.min() ?? 0
                    let mx = history.max() ?? 1
                    let rng = mx - mn > 0 ? mx - mn : 1
                    let spacing = size.width / CGFloat(max(history.count - 1, 1))

                    var path = Path()
                    for (i, v) in history.enumerated() {
                        let pt = CGPoint(
                            x: CGFloat(i) * spacing,
                            y: size.height - ((v - mn) / rng) * size.height
                        )
                        if i == 0 { path.move(to: pt) }
                        else { path.addLine(to: pt) }
                    }
                    ctx.stroke(
                        path,
                        with: .color(accent.opacity(0.7)),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                }
                .frame(height: 28)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}
