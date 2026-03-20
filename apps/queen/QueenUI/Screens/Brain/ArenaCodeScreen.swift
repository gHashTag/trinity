import SwiftUI

struct ArenaCodeScreen: View {
    @State private var arenaResult: ArenaCodeResult?

    struct ArenaCodeResult: Codable {
        let task_id: String?
        let solver: String?
        let solved: Bool?
        let time_seconds: Int?
        let tokens_used: Int?
        let test_pass_rate: Double?
        let code_quality: Double?
        let cost_usd: Double?
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                // Header
                HStack {
                    Text("💻")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("ARENA CODE")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.purple)
                        Text("Code Solving Benchmark — SWE-bench Style")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                }
                .padding()

                if let result = arenaResult {
                    // Result gauges
                    HStack(spacing: ParietalSpacing.xl) {
                        MetricGauge(
                            label: "Quality",
                            value: (result.code_quality ?? 0) * 100,
                            maxValue: 100,
                            accent: V4Color.accent
                        )
                        MetricGauge(
                            label: "Test Pass",
                            value: (result.test_pass_rate ?? 0) * 100,
                            maxValue: 100,
                            accent: V4Color.golden
                        )
                        MetricGauge(
                            label: "Time (s)",
                            value: Double(result.time_seconds ?? 0),
                            maxValue: 60,
                            accent: V4Color.purple
                        )
                    }
                    .padding()

                    // Detail cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                        StatCard(label: "Task", value: result.task_id ?? "—")
                        StatCard(label: "Solver", value: result.solver ?? "—", accent: V4Color.purple)
                        StatCard(
                            label: "Status",
                            value: (result.solved ?? false) ? "SOLVED" : "FAILED",
                            accent: (result.solved ?? false) ? V4Color.statusOK : V4Color.statusError
                        )
                        StatCard(label: "Time", value: "\(result.time_seconds ?? 0)s", accent: V4Color.golden)
                        StatCard(
                            label: "Test Pass Rate",
                            value: String(format: "%.1f%%", (result.test_pass_rate ?? 0) * 100)
                        )
                        StatCard(
                            label: "Code Quality",
                            value: String(format: "%.1f%%", (result.code_quality ?? 0) * 100),
                            accent: V4Color.accent
                        )
                        StatCard(label: "Tokens", value: "\(result.tokens_used ?? 0)")
                        StatCard(
                            label: "Cost",
                            value: String(format: "$%.4f", result.cost_usd ?? 0),
                            accent: V4Color.golden
                        )
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: ParietalSpacing.md) {
                        Text("No code arena results")
                            .font(.headline)
                            .foregroundStyle(V4Color.textPrimary)
                        Text("Run: tri arena code-battle")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                }

                // Benchmark categories
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("TASK CATEGORIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)

                    let categories = [
                        ("Math", 7, "🔢"), ("Coding", 7, "💻"), ("Reasoning", 6, "🧠")
                    ]

                    ForEach(categories, id: \.0) { name, count, emoji in
                        HStack(spacing: ParietalSpacing.md) {
                            Text(emoji)
                                .font(.title2)
                            Text(name)
                                .font(.headline)
                                .foregroundStyle(V4Color.textPrimary)
                            Spacer()
                            Text("\(count) tasks")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(V4Color.textSecondary)
                        }
                        .padding()
                        .background(V4Color.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .onAppear { loadResult() }
    }

    private func loadResult() {
        let path = "\(FileManager.default.currentDirectoryPath)/.trinity/arena_results.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        arenaResult = try? JSONDecoder().decode(ArenaCodeResult.self, from: data)
    }
}
