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
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text("PPL LOSS CURVE")
                .font(.caption.weight(.bold))
                .foregroundStyle(V4Color.golden)

            if points.count >= 2 {
                Chart(points) { point in
                    LineMark(
                        x: .value("Step", point.step),
                        y: .value("PPL", point.ppl)
                    )
                    .foregroundStyle(V4Color.accent)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Step", point.step),
                        y: .value("PPL", point.ppl)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [V4Color.accent.opacity(V2Depth.stateHover), V4Color.accent.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)
                }
                .chartYAxis {
                    AxisMarks(position: .leading) { _ in
                        AxisValueLabel()
                            .foregroundStyle(V4Color.textSecondary)
                        AxisGridLine()
                            .foregroundStyle(V4Color.textSecondary.opacity(0.2))
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisValueLabel()
                            .foregroundStyle(V4Color.textSecondary)
                        AxisGridLine()
                            .foregroundStyle(V4Color.textSecondary.opacity(0.2))
                    }
                }
                .frame(height: 180)
                .accessibilityLabel("PPL loss curve")
                .accessibilityValue(points.last.map { "Latest PPL \(String(format: "%.2f", $0.ppl)) at step \($0.step)" } ?? "No data")
            } else {
                Text("Waiting for PPL data from farm events...")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(height: 180)
                    .frame(maxWidth: .infinity)
            }

            if let last = points.last {
                HStack {
                    Text("Latest:")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                    Text(String(format: "PPL %.2f @ step %d", last.ppl, last.step))
                        .font(.caption2.weight(.bold).monospacedDigit())
                        .foregroundStyle(V4Color.golden)
                }
            }
        }
        .padding()
        .background(V4Color.surface)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
    }
}
