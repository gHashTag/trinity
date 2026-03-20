import SwiftUI

struct MetricGauge: View {
    let label: String
    let value: Double
    let maxValue: Double
    var accent: Color = V4Color.accent

    private var fraction: Double { min(max(value / maxValue, 0), 1) }

    var body: some View {
        VStack(spacing: ParietalSpacing.sm) {
            ZStack {
                Circle()
                    .stroke(V4Color.bgCard, lineWidth: 6)

                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(MTMotion.slow, value: fraction)

                Text(String(format: "%.0f", value))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(V4Color.textPrimary)
            }
            .frame(width: ParietalSpacing.avatarMedium * 1.33, height: ParietalSpacing.avatarMedium * 1.33)

            Text(label)
                .font(WernickeTypography.caption)
                .foregroundStyle(V4Color.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(String(format: "%.0f of %.0f", value, maxValue))
        .accessibilityAddTraits(.updatesFrequently)
    }
}
