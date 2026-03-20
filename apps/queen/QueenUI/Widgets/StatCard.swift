import SwiftUI

struct StatCard: View, Equatable {
    let label: String
    let value: String
    var accent: Color = V4Color.accent
    var history: [Double] = []

    static func == (lhs: StatCard, rhs: StatCard) -> Bool {
        lhs.label == rhs.label && lhs.value == rhs.value && lhs.history == rhs.history
    }

    @State private var isHovered = false

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack(spacing: 0) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(accent)
                    .frame(width: 3, height: ParietalSpacing.icon)
                Text(label)
                    .font(WernickeTypography.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .padding(.leading, ParietalSpacing.xs)
            }
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(V4Color.textPrimary)
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
                        with: .color(accent.opacity(V4Color.opacity70)),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                }
                .frame(height: 28)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
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
        .accessibilityLabel(label)
        .accessibilityValue(value)
    }
}
