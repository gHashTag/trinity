// Data Visualization View — Charts and Graphs
import SwiftUI

// MARK: - Line Chart

struct DataLineChart: View {
    let data: [CGFloat]
    let showPoints: Bool
    let showGrid: Bool
    let showLabels: Bool
    let lineStyle: LineStyle
    let color: Color

    enum LineStyle {
        case solid, dashed
    }

    init(
        data: [CGFloat],
        showPoints: Bool = true,
        showGrid: Bool = true,
        showLabels: Bool = false,
        lineStyle: LineStyle = .solid,
        color: Color = TrinityTheme.accent
    ) {
        self.data = data
        self.showPoints = showPoints
        self.showGrid = showGrid
        self.showLabels = showLabels
        self.lineStyle = lineStyle
        self.color = color
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxValue = data.max() ?? 1
            let minValue = data.min() ?? 0
            let range = maxValue - minValue

            ZStack {
                // Grid lines
                if showGrid {
                    ForEach(0..<5) { index in
                        let y = height * CGFloat(index) / 4
                        Path { path in
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: width, y: y))
                        }
                        .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                    }
                }

                // Line
                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                        let y = height - (height * (value - minValue) / range)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    color,
                    style: StrokeStyle(
                        lineWidth: 2,
                        lineCap: .round,
                        lineJoin: .round,
                        dash: lineStyle == .dashed ? [5, 5] : []
                    )
                )

                // Points
                if showPoints {
                    ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                        let x = width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                        let y = height - (height * (value - minValue) / range)

                        Circle()
                            .fill(color)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }

                // Y-axis labels
                if showLabels {
                    VStack {
                        ForEach(0..<5) { index in
                            let value = minValue + range * (1 - CGFloat(index) / 4)
                            Text(String(format: "%.1f", value))
                                .font(.caption2)
                                .foregroundStyle(TrinityTheme.textMuted)
                                .position(x: 30, y: height * CGFloat(index) / 4)

                            Spacer()
                        }
                    }
                    .frame(width: 40)
                }
            }
        }
        .frame(height: 200)
    }
}

// MARK: - Bar Chart

struct DataBarChart: View {
    let data: [CGFloat]
    let labels: [String]
    let colors: [Color]

    init(
        data: [CGFloat],
        labels: [String] = [],
        colors: [Color] = []
    ) {
        self.data = data
        self.labels = labels
        self.colors = colors.isEmpty ? [TrinityTheme.accent] : colors
    }

    @State private var animatedValues: [CGFloat] = []

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                let color = colors[index % colors.count]

                VStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: maxBarHeight * (animatedValues.isEmpty ? value : animatedValues[index]))
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatedValues[index])

                    if index < labels.count {
                        Text(labels[index])
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(height: 200)
        .padding(.vertical, 8)
        .onAppear {
            withAnimation {
                animatedValues = data.map { _ in 1.0 }
            }
        }
    }

    private var maxBarHeight: CGFloat {
        160
    }
}

// MARK: - Pie Chart

struct DataPieChart: View {
    let data: [(label: String, value: Double, color: Color)]
    let showPercentages: Bool
    let showLegend: Bool

    init(
        data: [(label: String, value: Double, color: Color)],
        showPercentages: Bool = true,
        showLegend: Bool = true
    ) {
        self.data = data
        self.showPercentages = showPercentages
        self.showLegend = showLegend
    }

    var body: some View {
        HStack(spacing: 20) {
            // Pie
            ZStack {
                ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                    let startAngle = angle(for: data.prefix(index).map { $0.value })
                    let endAngle = angle(for: data.prefix(index + 1).map { $0.value })

                    Path { path in
                        let center = CGPoint(x: 100, y: 100)
                        let radius = CGFloat(80)

                        path.addArc(
                            center: center,
                            radius: radius,
                            startAngle: .degrees(startAngle),
                            endAngle: .degrees(endAngle),
                            clockwise: false
                        )
                        path.addLine(to: center)
                        path.closeSubpath()
                    }
                    .fill(item.color)
                }
            }
            .frame(width: 200, height: 200)

            // Legend
            if showLegend {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(data, id: \.label) { item in
                        HStack(spacing: 8) {
                            Circle()
                                .fill(item.color)
                                .frame(width: 12, height: 12)

                            Text(item.label)
                                .font(.caption)
                                .foregroundStyle(TrinityTheme.textPrimary)

                            if showPercentages {
                                let total = data.reduce(0) { $0 + $1.value }
                                let percentage = item.value / total * 100
                                Text(String(format: "%.0f%%", percentage))
                                    .font(.caption)
                                    .foregroundStyle(TrinityTheme.textMuted)
                            }
                        }
                    }
                }
            }
        }
    }

    private func angle(for values: [Double]) -> Double {
        let total = values.reduce(into: 0.0) { $0 + $1 }
        return values.reduce(into: 0.0) { $0 + ($1 / total) * 360 }
    }
}

// MARK: - Donut Chart

struct DonutChart: View {
    let data: [(label: String, value: Double, color: Color)]
    let centerText: String?
    let centerSubtext: String?

    init(
        data: [(label: String, value: Double, color: Color)],
        centerText: String? = nil,
        centerSubtext: String? = nil
    ) {
        self.data = data
        self.centerText = centerText
        self.centerSubtext = centerSubtext
    }

    var body: some View {
        ZStack {
            // Donut segments
            ForEach(Array(data.enumerated()), id: \.offset) { index, item in
                let startAngle = angle(for: data.prefix(index).map { $0.value })
                let endAngle = angle(for: data.prefix(index + 1).map { $0.value })

                Path { path in
                    let center = CGPoint(x: 100, y: 100)
                    let outerRadius: CGFloat = 80
                    let innerRadius: CGFloat = 50

                    path.addArc(
                        center: center,
                        radius: outerRadius,
                        startAngle: .degrees(startAngle),
                        endAngle: .degrees(endAngle),
                        clockwise: false
                    )
                    path.addArc(
                        center: center,
                        radius: innerRadius,
                        startAngle: .degrees(endAngle),
                        endAngle: .degrees(startAngle),
                        clockwise: true
                    )
                    path.closeSubpath()
                }
                .fill(item.color)
            }

            // Center text
            if let centerText = centerText {
                VStack(spacing: 2) {
                    Text(centerText)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    if let centerSubtext = centerSubtext {
                        Text(centerSubtext)
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }
            }
        }
        .frame(width: 200, height: 200)
    }

    private func angle(for values: [Double]) -> Double {
        let total = values.reduce(into: 0.0) { $0 + $1 }
        return values.reduce(into: 0.0) { $0 + ($1 / total) * 360 }
    }
}

// MARK: - Progress Gauge

struct ProgressGauge: View {
    let value: Double
    let label: String?
    let zones: [Zone]

    struct Zone {
        let range: ClosedRange<Double>
        let color: Color
        let label: String
    }

    init(
        value: Double,
        label: String? = nil,
        zones: [Zone] = [
            Zone(range: 0...0.3, color: TrinityTheme.statusError, label: "Poor"),
            Zone(range: 0.3...0.7, color: TrinityTheme.statusWarn, label: "Fair"),
            Zone(range: 0.7...1.0, color: TrinityTheme.statusOK, label: "Good")
        ]
    ) {
        self.value = max(0, min(1, value))
        self.label = label
        self.zones = zones
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Background arc
                Path { path in
                    path.addArc(
                        center: CGPoint(x: 100, y: 100),
                        radius: 80,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                }
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 16)

                // Value arc
                Path { path in
                    path.addArc(
                        center: CGPoint(x: 100, y: 100),
                        radius: 80,
                        startAngle: .degrees(180),
                        endAngle: .degrees(180 + value * 180),
                        clockwise: false
                    )
                }
                .stroke(zoneColor, lineWidth: 16)
                .animation(.easeInOut(duration: 0.5), value: value)

                // Label
                if let label = label {
                    Text(label)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(zoneColor)
                        .offset(y: 40)
                }
            }
            .frame(width: 200, height: 120)

            // Zone labels
            HStack(spacing: 20) {
                ForEach(zones, id: \.label) { zone in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(zone.color)
                            .frame(width: 8, height: 8)

                        Text(zone.label)
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }
            }
        }
    }

    private var zoneColor: Color {
        for zone in zones {
            if zone.range.contains(value) {
                return zone.color
            }
        }
        return TrinityTheme.textMuted
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    let data: [CGFloat]
    let color: Color
    let showArea: Bool

    init(
        data: [CGFloat],
        color: Color = TrinityTheme.accent,
        showArea: Bool = true
    ) {
        self.data = data
        self.color = color
        self.showArea = showArea
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let maxValue = data.max() ?? 1
            let minValue = data.min() ?? 0
            let range = maxValue - minValue

            ZStack {
                if showArea {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: height))

                        for (index, value) in data.enumerated() {
                            let x = width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                            let y = height - (height * (value - minValue) / range)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }

                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(color.opacity(0.2))
                }

                Path { path in
                    for (index, value) in data.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(max(data.count - 1, 1))
                        let y = height - (height * (value - minValue) / range)

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(color, lineWidth: 2)
            }
        }
        .frame(height: 40)
    }
}

// MARK: - Preview

struct DataVisualizationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 20) {
                DataLineChart(
                    data: [10, 25, 15, 30, 20, 40, 35],
                    showLabels: true
                )
                .frame(height: 220)

                DataBarChart(
                    data: [30, 50, 25, 60, 40],
                    labels: ["Mon", "Tue", "Wed", "Thu", "Fri"],
                    colors: [.blue, .purple, .pink, .orange, .green]
                )

                DataPieChart(
                    data: [
                        ("Sales", 40, .blue),
                        ("Marketing", 25, .purple),
                        ("Development", 20, .pink),
                        ("Support", 15, .orange)
                    ]
                )
            }
            .padding()
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
