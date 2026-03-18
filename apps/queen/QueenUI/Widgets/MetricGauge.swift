import SwiftUI

struct MetricGauge: View {
    let label: String
    let value: Double
    let maxValue: Double
    var accent: Color = TrinityTheme.accent

    private var fraction: Double { min(max(value / maxValue, 0), 1) }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(TrinityTheme.bgCard, lineWidth: 6)

                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(accent, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: fraction)

                Text(String(format: "%.0f", value))
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(TrinityTheme.textPrimary)
            }
            .frame(width: 64, height: 64)

            Text(label)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(label)
        .accessibilityValue(String(format: "%.0f of %.0f", value, maxValue))
        .accessibilityAddTraits(.updatesFrequently)
    }
}