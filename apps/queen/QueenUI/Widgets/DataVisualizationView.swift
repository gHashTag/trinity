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
        color: Color = V4Color.accent
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
                        .stroke(V4Color.border, lineWidth: 1)
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
                            .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)
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
                                .foregroundStyle(V4Color.textSecondary)
                                .position(x: 30, y: height * CGFloat(index) / 4)

                            Spacer()
                        }
                    }
                    .frame(width: ParietalSpacing.buttonMediumWidth)
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
        self.colors = colors.isEmpty ? [V4Color.accent] : colors
    }

    @State private var animatedValues: [CGFloat] = []

    var body: some View {
        HStack(alignment: .bottom, spacing: ParietalSpacing.sm) {
            ForEach(Array(data.enumerated()), id: \.offset) { index, value in
                let color = colors[index % colors.count]

                VStack(spacing: ParietalSpacing.xs) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: maxBarHeight * (animatedValues.isEmpty ? value : animatedValues[index]))
                        .animation(.spring(response: 0.6, dampingFraction: 0.7), value: animatedValues[index])

                    if index < labels.count {
                        Text(labels[index])
                            .font(.caption2)
                            .foregroundStyle(V4Color.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .frame(height: 200)
        .padding(.vertical, ParietalSpacing.sm)
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
        HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
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
            .frame(width: ParietalSpacing.modalFrame, height: ParietalSpacing.modalFrame)

            // Legend
            if showLegend {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    ForEach(data, id: \.label) { item in
                        HStack(spacing: ParietalSpacing.sm) {
                            Circle()
                                .fill(item.color)
                                .frame(width: ParietalSpacing.sm, height: ParietalSpacing.sm)

                            Text(item.label)
                                .font(.caption)
                                .foregroundStyle(V4Color.textPrimary)

                            if showPercentages {
                                let total = data.reduce(0) { $0 + $1.value }
                                let percentage = item.value / total * 100
                                Text(String(format: "%.0f%%", percentage))
                                    .font(.caption)
                                    .foregroundStyle(V4Color.textSecondary)
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
                        .font(WernickeTypography.size20.weight(.bold))
                        .foregroundStyle(V4Color.textPrimary)

                    if let centerSubtext = centerSubtext {
                        Text(centerSubtext)
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }
            }
        }
        .frame(width: ParietalSpacing.modalFrame, height: ParietalSpacing.modalFrame)
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
            Zone(range: 0...0.3, color: V4Color.error, label: "Poor"),
            Zone(range: 0.3...0.7, color: V4Color.warning, label: "Fair"),
            Zone(range: 0.7...1.0, color: V4Color.success, label: "Good")
        ]
    ) {
        self.value = max(0, min(1, value))
        self.label = label
        self.zones = zones
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.sm) {
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
                .stroke(V4Color.border, lineWidth: 16)

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
                        .font(WernickeTypography.h3Bold)
                        .foregroundStyle(zoneColor)
                        .offset(y: 40)
                }
            }
            .frame(width: ParietalSpacing.modalFrame, height: ParietalSpacing.xxxLargeFrame)

            // Zone labels
            HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                ForEach(zones, id: \.label) { zone in
                    HStack(spacing: ParietalSpacing.xs) {
                        Circle()
                            .fill(zone.color)
                            .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)

                        Text(zone.label)
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
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
        return V4Color.textSecondary
    }
}

// MARK: - Sparkline

struct Sparkline: View {
    let data: [CGFloat]
    let color: Color
    let showArea: Bool

    init(
        data: [CGFloat],
        color: Color = V4Color.accent,
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
        .frame(height: ParietalSpacing.avatarMedium - 8)
    }
}

// MARK: - Preview

struct DataVisualizationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
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
        .background(V4Color.background)
    }
}
