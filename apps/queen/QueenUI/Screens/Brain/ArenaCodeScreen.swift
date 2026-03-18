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
            VStack(spacing: TrinityTheme.spacing) {
                // Header
                HStack {
                    Text("💻")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("ARENA CODE")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.purple)
                        Text("Code Solving Benchmark — SWE-bench Style")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                }
                .padding()

                if let result = arenaResult {
                    // Result gauges
                    HStack(spacing: 24) {
                        MetricGauge(
                            label: "Quality",
                            value: (result.code_quality ?? 0) * 100,
                            maxValue: 100,
                            accent: TrinityTheme.accent
                        )
                        MetricGauge(
                            label: "Test Pass",
                            value: (result.test_pass_rate ?? 0) * 100,
                            maxValue: 100,
                            accent: TrinityTheme.golden
                        )
                        MetricGauge(
                            label: "Time (s)",
                            value: Double(result.time_seconds ?? 0),
                            maxValue: 60,
                            accent: TrinityTheme.purple
                        )
                    }
                    .padding()

                    // Detail cards
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(label: "Task", value: result.task_id ?? "—")
                        StatCard(label: "Solver", value: result.solver ?? "—", accent: TrinityTheme.purple)
                        StatCard(
                            label: "Status",
                            value: (result.solved ?? false) ? "SOLVED" : "FAILED",
                            accent: (result.solved ?? false) ? TrinityTheme.statusOK : TrinityTheme.statusError
                        )
                        StatCard(label: "Time", value: "\(result.time_seconds ?? 0)s", accent: TrinityTheme.golden)
                        StatCard(
                            label: "Test Pass Rate",
                            value: String(format: "%.1f%%", (result.test_pass_rate ?? 0) * 100)
                        )
                        StatCard(
                            label: "Code Quality",
                            value: String(format: "%.1f%%", (result.code_quality ?? 0) * 100),
                            accent: TrinityTheme.accent
                        )
                        StatCard(label: "Tokens", value: "\(result.tokens_used ?? 0)")
                        StatCard(
                            label: "Cost",
                            value: String(format: "$%.4f", result.cost_usd ?? 0),
                            accent: TrinityTheme.golden
                        )
                    }
                    .padding(.horizontal)
                } else {
                    VStack(spacing: 12) {
                        Text("No code arena results")
                            .font(.headline)
                            .foregroundStyle(TrinityTheme.textPrimary)
                        Text("Run: tri arena code-battle")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                }

                // Benchmark categories
                VStack(alignment: .leading, spacing: 12) {
                    Text("TASK CATEGORIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

                    let categories = [
                        ("Math", 7, "🔢"), ("Coding", 7, "💻"), ("Reasoning", 6, "🧠")
                    ]

                    ForEach(categories, id: \.0) { name, count, emoji in
                        HStack(spacing: 12) {
                            Text(emoji)
                                .font(.title2)
                            Text(name)
                                .font(.headline)
                                .foregroundStyle(TrinityTheme.textPrimary)
                            Spacer()
                            Text("\(count) tasks")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                        .padding()
                        .background(TrinityTheme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                    }
                }
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
        .onAppear { loadResult() }
    }

    private func loadResult() {
        let path = "\(FileManager.default.currentDirectoryPath)/.trinity/arena_results.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        arenaResult = try? JSONDecoder().decode(ArenaCodeResult.self, from: data)
    }
}
