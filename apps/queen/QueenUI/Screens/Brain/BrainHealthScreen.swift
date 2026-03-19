import SwiftUI

/// S³AI Brain Health Monitoring Screen
/// Displays neuroanatomy region status with telemetry
struct BrainHealthScreen: View {
    @EnvironmentObject var watcher: StateWatcher
    @State private var brainData: BrainHealthData?
    @State private var isLoading = false

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.medium) {
                // Header
                HStack {
                    Text("🧠")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("S³AI NEUROANATOMY")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V1Theme.accent)
                        Text("Brain Region Health Monitor v5.1")
                            .font(.subheadline)
                            .foregroundStyle(V1Theme.textMuted)
                    }
                    Spacer()
                }
                .padding()

                // Overall Health Score
                if let data = brainData {
                    HealthScoreCard(score: data.healthScore, healthy: data.healthy)
                        .padding(.horizontal)
                } else if isLoading {
                    ProgressView("Loading brain telemetry...")
                        .padding()
                } else {
                    Text("No brain health data available")
                        .font(.caption)
                        .foregroundStyle(V1Theme.textMuted)
                        .padding()
                }

                // Brain Atlas Grid
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 12
                ) {
                    BrainRegionCard(
                        name: "Thalamus",
                        function: "Sensory Relay",
                        status: .healthy,
                        detail: "Railway logs active"
                    )
                    BrainRegionCard(
                        name: "Basal Ganglia",
                        function: "Action Selection",
                        status: regionStatus("basal_ganglia"),
                        detail: activeClaims()
                    )
                    BrainRegionCard(
                        name: "Reticular Formation",
                        function: "Broadcast Alerting",
                        status: regionStatus("reticular"),
                        detail: eventsBuffered()
                    )
                    BrainRegionCard(
                        name: "Locus Coeruleus",
                        function: "Arousal Regulation",
                        status: .healthy,
                        detail: "Backoff policy active"
                    )
                    BrainRegionCard(
                        name: "Amygdala",
                        function: "Emotional Salience",
                        status: .healthy,
                        detail: "Priority detection"
                    )
                    BrainRegionCard(
                        name: "Prefrontal Cortex",
                        function: "Executive Function",
                        status: regionStatus("prefrontal"),
                        detail: executiveDecision()
                    )
                    BrainRegionCard(
                        name: "Hippocampus",
                        function: "Memory Persistence",
                        status: regionStatus("hippocampus"),
                        detail: memorySnapshot()
                    )
                    BrainRegionCard(
                        name: "Corpus Callosum",
                        function: "Telemetry",
                        status: regionStatus("telemetry"),
                        detail: trendIndicator()
                    )
                }
                .padding(.horizontal)

                // Trend Chart (if available)
                if let data = brainData, !data.history.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("HEALTH TREND")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(V1Theme.accent)

                        TrendLine(data: data.history.map { $0.healthScore })
                            .frame(height: 120)
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Brain Health")
        .onAppear {
            loadBrainData()
        }
        .refreshable {
            loadBrainData()
        }
    }

    // MARK: - Data Loading

    private func loadBrainData() {
        isLoading = true

        // Read from .trinity/brain_health_history.jsonl
        let path = ".trinity/brain_health_history.jsonl"
        if let fileContent = try? String(contentsOfFile: path, encoding: .utf8) {
            let lines = fileContent.components(separatedBy: "\n").filter { !$0.isEmpty }

            let snapshots = lines.compactMap { line -> HealthSnapshot? in
                guard let data = line.data(using: .utf8),
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let health = json["health"] as? Double,
                      let ok = json["ok"] as? Bool,
                      let claims = json["claims"] as? Int,
                      let eventsPub = json["events_pub"] as? Int,
                      let eventsBuf = json["events_buf"] as? Int else {
                    return nil
                }

                return HealthSnapshot(
                    timestamp: (json["ts"] as? Double) ?? 0,
                    healthScore: Float(health),
                    healthy: ok,
                    activeClaims: claims,
                    eventsPublished: eventsPub,
                    eventsBuffered: eventsBuf
                )
            }

            if let latest = snapshots.last {
                brainData = BrainHealthData(
                    healthScore: latest.healthScore,
                    healthy: latest.healthy,
                    activeClaims: latest.activeClaims,
                    eventsPublished: latest.eventsPublished,
                    eventsBuffered: latest.eventsBuffered,
                    history: snapshots
                )
            }
        }

        isLoading = false
    }

    // MARK: - Region Status Helpers

    private func regionStatus(_ region: String) -> RegionStatus {
        guard let data = brainData else { return .unknown }

        switch region {
        case "basal_ganglia":
            return data.activeClaims < 100 ? .healthy : .warning
        case "reticular":
            return data.eventsBuffered < 1000 ? .healthy : .warning
        case "hippocampus":
            return data.healthy ? .healthy : .error
        case "telemetry":
            return !data.history.isEmpty ? .healthy : .unknown
        default:
            return .unknown
        }
    }

    private func activeClaims() -> String {
        guard let data = brainData else { return "N/A" }
        return "\(data.activeClaims) claims"
    }

    private func eventsBuffered() -> String {
        guard let data = brainData else { return "N/A" }
        return "\(data.eventsBuffered) events"
    }

    private func memorySnapshot() -> String {
        guard let data = brainData else { return "No snapshots" }
        return "\(data.history.count) records"
    }

    private func executiveDecision() -> String {
        guard let data = brainData else { return "No decision" }
        if data.healthScore >= 90 { return "PROCEED" }
        if data.healthScore >= 70 { return "THROTTLE" }
        return "PAUSE"
    }

    private func trendIndicator() -> String {
        guard let data = brainData, data.history.count >= 3 else { return "Insufficient data" }

        let recent = data.history.suffix(10)
        let firstHalf = recent.prefix(recent.count / 2)
        let secondHalf = recent.suffix(recent.count / 2)

        let firstAvg = firstHalf.reduce(0.0) { $0 + $1.healthScore } / Float(firstHalf.count)
        let secondAvg = secondHalf.reduce(0.0) { $0 + $1.healthScore } / Float(secondHalf.count)

        let diff = secondAvg - firstAvg
        if diff > 5 { return "↗ Improving" }
        if diff < -5 { return "↘ Declining" }
        return "→ Stable"
    }
}

// MARK: - Data Models

struct BrainHealthData {
    let healthScore: Float
    let healthy: Bool
    let activeClaims: Int
    let eventsPublished: Int
    let eventsBuffered: Int
    let history: [HealthSnapshot]
}

struct HealthSnapshot {
    let timestamp: Double
    let healthScore: Float
    let healthy: Bool
    let activeClaims: Int
    let eventsPublished: Int
    let eventsBuffered: Int
}

enum RegionStatus {
    case healthy
    case warning
    case error
    case unknown

    var color: Color {
        switch self {
        case .healthy: return V1Theme.statusOK
        case .warning: return V1Theme.golden
        case .error: return V1Theme.statusError
        case .unknown: return V1Theme.textMuted
        }
    }

    var icon: String {
        switch self {
        case .healthy: return "🟢"
        case .warning: return "🟡"
        case .error: return "🔴"
        case .unknown: return "⚪"
        }
    }
}

// MARK: - Components

struct HealthScoreCard: View {
    let score: Float
    let healthy: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text("OVERALL HEALTH")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V1Theme.textMuted)

                Text("\(Int(score))/100")
                    .font(.system(size: 48, weight: .bold, design: .rounded))
                    .foregroundStyle(healthy ? V1Theme.statusOK : V1Theme.statusError)
            }

            Spacer()

            VStack(alignment: .trailing) {
                Text(healthy ? "✅ HEALTHY" : "⚠️ UNHEALTHY")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(healthy ? V1Theme.statusOK : V1Theme.statusError)

                Text("Brain circuit operational")
                    .font(.caption)
                    .foregroundStyle(V1Theme.textMuted)
            }
        }
        .padding()
        .background(V1Theme.bgCard)
        .cornerRadius(12)
    }
}

struct BrainRegionCard: View {
    let name: String
    let function: String
    let status: RegionStatus
    let detail: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(status.icon)
                    .font(.title3)
                VStack(alignment: .leading) {
                    Text(name)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(V1Theme.textPrimary)
                    Text(function)
                        .font(.caption2)
                        .foregroundStyle(V1Theme.textMuted)
                }
                Spacer()
            }

            Text(detail)
                .font(.caption)
                .foregroundStyle(status.color)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(V1Theme.bgCard)
        .cornerRadius(12)
    }
}

struct TrendLine: View {
    let data: [Float]

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let min = data.min() ?? 0
            let max = data.max() ?? 100
            let range = max - min

            ZStack {
                // Grid lines
                Path { path in
                    for i in 0...4 {
                        let y = height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                }
                .stroke(V1Theme.textMuted.opacity(0.2), lineWidth: 1)

                // Trend line
                if data.count > 1 {
                    Path { path in
                        for (i, value) in data.enumerated() {
                            let x = width * CGFloat(i) / CGFloat(data.count - 1)
                            let normalized = range > 0 ? (value - min) / range : 0.5
                            let y = height * (1 - CGFloat(normalized))

                            if i == 0 {
                                path.move(to: CGPoint(x: x, y: y))
                            } else {
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                        }
                    }
                    .stroke(V1Theme.accent, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            }
        }
        .padding()
        .background(V1Theme.bgCard)
        .cornerRadius(12)
    }
}
