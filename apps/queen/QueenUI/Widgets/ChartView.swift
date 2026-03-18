// Chart View — Data Visualization
import SwiftUI

// MARK: - Line Chart

struct LineChart: View {
    let data: [ChartDataPoint]
    let color: Color
    let showArea: Bool

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    var body: some View {
        GeometryReader { geometry in
            let max = data.map(\.value).max() ?? 1
            let min = data.map(\.value).min() ?? 0
            let range = max - min

            ZStack {
                // Grid lines
                ForEach(0..<5) { index in
                    Rectangle()
                        .fill(TrinityTheme.bgCardBorder)
                        .frame(height: 1)
                        .position(
                            x: geometry.size.width / 2,
                            y: CGFloat(index) * geometry.size.height / 4
                        )
                }

                // Line
                Path { path in
                    for (index, point) in data.enumerated() {
                        let x = CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width
                        let y = geometry.size.height - CGFloat((point.value - min) / range) * geometry.size.height * 0.8 - geometry.size.height * 0.1

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Area fill
                if showArea {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geometry.size.height))

                        for (index, point) in data.enumerated() {
                            let x = CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width
                            let y = geometry.size.height - CGFloat((point.value - min) / range) * geometry.size.height * 0.8 - geometry.size.height * 0.1
                            path.addLine(to: CGPoint(x: x, y: y))
                        }

                        path.addLine(to: CGPoint(x: geometry.size.width, y: geometry.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // Points
                ForEach(Array(data.enumerated()), id: \.element.id) { index, point in
                    let x = CGFloat(index) / CGFloat(data.count - 1) * geometry.size.width
                    let y = geometry.size.height - CGFloat((point.value - min) / range) * geometry.size.height * 0.8 - geometry.size.height * 0.1

                    Circle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .position(x: x, y: y)
                }
            }
        }
        .frame(height: 150)
    }
}

// MARK: - Bar Chart

struct BarChart: View {
    let data: [BarData]
    let color: Color

    struct BarData: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
    }

    var body: some View {
        GeometryReader { geometry in
            let max = data.map(\.value).max() ?? 1
            let barWidth = geometry.size.width / CGFloat(data.count) * 0.7
            let spacing = geometry.size.width / CGFloat(data.count)

            HStack(alignment: .bottom, spacing: 0) {
                ForEach(data) { item in
                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(color)
                            .frame(width: barWidth)
                            .frame(height: CGFloat(item.value / max) * geometry.size.height * 0.8)
                            .cornerRadius(4)

                        Text(item.label)
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .lineLimit(1)
                    }
                    .frame(width: spacing)
                }
            }
        }
        .frame(height: 150)
    }
}

// MARK: - Pie Chart

struct PieChart: View {
    let data: [PieData]

    struct PieData: Identifiable {
        let id = UUID()
        let label: String
        let value: Double
        let color: Color
    }

    var body: some View {
        GeometryReader { geometry in
            let total = data.map(\.value).reduce(0, +)
            let center = CGPoint(x: geometry.size.width / 2, y: geometry.size.height / 2)
            let radius = min(geometry.size.width, geometry.size.height) / 2

            ZStack {
                ForEach(Array(data.enumerated()), id: \.element.id) { index, item in
                    let startAngle = angle(for: index, in: data)
                    let endAngle = angle(for: index + 1, in: data)

                    Path { path in
                        path.move(to: center)
                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: Angle(radians: startAngle),
                            endAngle: Angle(radians: endAngle),
                            clockwise: false
                        )
                        path.closeSubpath()
                    }
                    .fill(item.color)
                }

                // Center circle for donut effect
                Circle()
                    .fill(TrinityTheme.bgCard)
                    .frame(width: radius * 0.6, height: radius * 0.6)
            }
        }
        .frame(height: 150)
    }

    private func angle(for index: Int, in data: [PieData]) -> Double {
        let total = data.map(\.value).reduce(0, +)
        let valueBefore = data[0..<index].reduce(0.0) { $0 + $1.value }
        return (valueBefore / total) * 2 * .pi - .pi / 2
    }
}

// MARK: - Stat Card

struct ChartStatCard: View {
    let title: String
    let value: String
    let change: String?
    let changeType: ChangeType?
    let icon: String?
    let color: Color

    enum ChangeType {
        case increase, decrease, neutral
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundStyle(color)
                        .frame(width: 32, height: 32)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(color.opacity(0.15))
                        )
                }

                Spacer()

                if let change = change, let changeType = changeType {
                    HStack(spacing: 2) {
                        Image(systemName: changeIcon(for: changeType))
                            .font(.system(size: 10))
                        Text(change)
                            .font(.caption)
                    }
                    .foregroundStyle(changeType == .increase ? TrinityTheme.statusOK : changeType == .decrease ? TrinityTheme.statusError : TrinityTheme.textMuted)
                }
            }

            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text(title)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }

    private func changeIcon(for type: ChangeType) -> String {
        switch type {
        case .increase: return "arrow.up.right"
        case .decrease: return "arrow.down.right"
        case .neutral: return "minus"
        }
    }
}

// MARK: - Progress Ring

struct ChartProgressRing: View {
    let progress: Double
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 4)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: progress)
        }
    }
}

// MARK: - Gauge Chart

struct GaugeChart: View {
    let value: Double
    let min: Double
    let max: Double
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background arc
                Path { path in
                    path.addArc(
                        center: CGPoint(x: 60, y: 60),
                        radius: 50,
                        startAngle: Angle(radians: .pi * 0.75),
                        endAngle: Angle(radians: .pi * 2.25),
                        clockwise: false
                    )
                }
                .stroke(TrinityTheme.bgCardBorder, style: StrokeStyle(lineWidth: 8))

                // Value arc
                Path { path in
                    let normalized = (value - min) / (max - min)
                    let endAngle = .pi * 0.75 + normalized * .pi * 1.5

                    path.addArc(
                        center: CGPoint(x: 60, y: 60),
                        radius: 50,
                        startAngle: Angle(radians: .pi * 0.75),
                        endAngle: Angle(radians: endAngle),
                        clockwise: false
                    )
                }
                .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))

                Text(String(format: "%.0f%%", (value - min) / (max - min) * 100))
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .offset(y: 10)
            }
            .frame(width: 120, height: 80)

            Text(label)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
        }
    }
}

// MARK: - Preview

struct ChartView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            LineChart(
                data: [
                    LineChart.ChartDataPoint(label: "Mon", value: 10),
                    LineChart.ChartDataPoint(label: "Tue", value: 25),
                    LineChart.ChartDataPoint(label: "Wed", value: 15),
                    LineChart.ChartDataPoint(label: "Thu", value: 40),
                    LineChart.ChartDataPoint(label: "Fri", value: 30)
                ],
                color: TrinityTheme.accent,
                showArea: true
            )
            .frame(width: 300)

            BarChart(
                data: [
                    BarChart.BarData(label: "A", value: 30),
                    BarChart.BarData(label: "B", value: 50),
                    BarChart.BarData(label: "C", value: 25),
                    BarChart.BarData(label: "D", value: 40)
                ],
                color: TrinityTheme.accent
            )
            .frame(width: 300)

            PieChart(
                data: [
                    PieChart.PieData(label: "A", value: 30, color: .blue),
                    PieChart.PieData(label: "B", value: 50, color: .purple),
                    PieChart.PieData(label: "C", value: 20, color: .orange)
                ]
            )
            .frame(width: 150)
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
