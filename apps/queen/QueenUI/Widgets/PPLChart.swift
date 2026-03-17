import SwiftUI
import Charts

struct LossPoint: Identifiable {
    let step: Int
    let ppl: Double

    var id: Int { step }
}

struct PPLChart: View {
    let events: [FarmEvent]

    private var points: [LossPoint] {
        let raw = events.compactMap { event -> LossPoint? in
            guard let ppl = event.ppl, let step = event.step else { return nil }
            return LossPoint(step: step, ppl: ppl)
        }
        // Cap at 200 points, keep newest
        return Array(raw.suffix(200))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("PPL LOSS CURVE")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.golden)

            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("Step", point.step),
                        y: .value("PPL", point.ppl)
                    )
                    .foregroundStyle(TrinityTheme.accent)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Step", point.step),
                        y: .value("PPL", point.ppl)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [TrinityTheme.accent.opacity(0.3), TrinityTheme.accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(TrinityTheme.textMuted)
                        AxisGridLine()
                            .foregroundStyle(TrinityTheme.textMuted.opacity(0.2))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(TrinityTheme.textMuted)
                        AxisGridLine()
                            .foregroundStyle(TrinityTheme.textMuted.opacity(0.2))
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("PPL loss curve")
                .accessibilityValue(points.last.map { "Latest PPL \(String(format: "%.2f", $0.ppl)) at step \($0.step)" } ?? "No data")
            } else {
                Text("Waiting for PPL data from farm events...")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            }

            if let last = points.last {
                HStack {
                    Text("Latest:")
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                    Text(String(format: "PPL %.2f @ step %d", last.ppl, last.step))
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(TrinityTheme.golden)
                }
            }
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
    }
}
