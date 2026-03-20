import SwiftUI

struct ArenaLLMScreen: View {
    @State private var battles: [ArenaBattle] = []
    @State private var leaderboard: [FighterELO] = []
    @State private var isLoading = false
    private let bridge = QueenBridge.shared

    struct ArenaBattle: Codable, Identifiable {
        let id: Int?
        let fighter_a: String?
        let fighter_b: String?
        let task_id: String?
        let category: String?
        let status: String?
        let verdict: String?
        let latency_a_ms: Int?
        let latency_b_ms: Int?
        let timestamp: Int?

        var stableID: String { "\(timestamp ?? 0)-\(fighter_a ?? "")-\(fighter_b ?? "")" }
    }

    struct FighterELO: Identifiable {
        let name: String
        var elo: Double
        var wins: Int
        var losses: Int
        var battles: Int

        var id: String { name }
        var winRate: Double { battles > 0 ? Double(wins) / Double(battles) * 100 : 0 }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                // Header
                HStack {
                    Text("⚔️")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("ARENA LLM")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("LMSYS-compatible ELO Battle Platform")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    MetricGauge(
                        label: "Battles",
                        value: Double(battles.count),
                        maxValue: max(Double(battles.count), 1),
                        accent: V4Color.golden
                    )
                }
                .padding()

                // ELO Leaderboard
                if !leaderboard.isEmpty {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("ELO LEADERBOARD")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(V4Color.golden)
                            .padding(.horizontal)

                        ELOChart(entries: leaderboard.map { ($0.name, $0.elo) })
                            .padding(.horizontal)
                    }

                    // Fighter details
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                        ForEach(leaderboard) { fighter in
                            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                                HStack {
                                    Text(fighter.name)
                                        .font(.headline)
                                        .foregroundStyle(V4Color.textPrimary)
                                    Spacer()
                                    Text(String(format: "%.0f", fighter.elo))
                                        .font(.title3.weight(.bold).monospacedDigit())
                                        .foregroundStyle(V4Color.golden)
                                }
                                HStack(spacing: ParietalSpacing.lg) {
                                    Label("\(fighter.wins)W", systemImage: "checkmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(V4Color.statusOK)
                                    Label("\(fighter.losses)L", systemImage: "xmark.circle")
                                        .font(.caption)
                                        .foregroundStyle(V4Color.statusError)
                                    Text(String(format: "%.0f%%", fighter.winRate))
                                        .font(.caption.weight(.bold))
                                        .foregroundStyle(V4Color.textSecondary)
                                }
                            }
                            .padding()
                            .background(V4Color.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                        }
                    }
                    .padding(.horizontal)
                }

                // Recent battles
                if !battles.isEmpty {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("RECENT BATTLES")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                            .padding(.horizontal)

                        ForEach(battles.suffix(15).reversed(), id: \.stableID) { battle in
                            HStack(spacing: ParietalSpacing.sm) {
                                Text(verdictEmoji(battle.verdict))
                                VStack(alignment: .leading, spacing: 2) {
                                    HStack(spacing: ParietalSpacing.xs) {
                                        Text(battle.fighter_a ?? "?")
                                            .font(.caption.weight(battle.verdict == "a_wins" ? .bold : .regular))
                                            .foregroundStyle(battle.verdict == "a_wins" ? V4Color.accent : V4Color.textPrimary)
                                        Text("vs")
                                            .font(.caption2)
                                            .foregroundStyle(V4Color.textSecondary)
                                        Text(battle.fighter_b ?? "?")
                                            .font(.caption.weight(battle.verdict == "b_wins" ? .bold : .regular))
                                            .foregroundStyle(battle.verdict == "b_wins" ? V4Color.accent : V4Color.textPrimary)
                                    }
                                    if let cat = battle.category {
                                        Text(cat)
                                            .font(.caption2)
                                            .foregroundStyle(V4Color.purple)
                                    }
                                }
                                Spacer()
                                if let ms = battle.latency_a_ms, ms > 0 {
                                    Text("\(ms)ms")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(V4Color.textSecondary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }

                if battles.isEmpty && leaderboard.isEmpty {
                    VStack(spacing: ParietalSpacing.md) {
                        Text("No arena results found")
                            .font(.headline)
                            .foregroundStyle(V4Color.textPrimary)
                        Text("Run battles via: tri arena battle")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .onAppear { loadData() }
    }

    private func loadData() {
        loadBattles()
        computeLeaderboard()
    }

    private func loadBattles() {
        let path = "\(FileManager.default.currentDirectoryPath)/data/arena/arena_results.jsonl"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }

        let decoder = JSONDecoder()
        battles = content.components(separatedBy: "\n").compactMap { line -> ArenaBattle? in
            guard !line.isEmpty, let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(ArenaBattle.self, from: data)
        }
    }

    private func computeLeaderboard() {
        var fighters: [String: FighterELO] = [:]
        let K: Double = 32

        for battle in battles {
            guard let a = battle.fighter_a, let b = battle.fighter_b else { continue }

            if fighters[a] == nil { fighters[a] = FighterELO(name: a, elo: 1200, wins: 0, losses: 0, battles: 0) }
            if fighters[b] == nil { fighters[b] = FighterELO(name: b, elo: 1200, wins: 0, losses: 0, battles: 0) }

            let eA = fighters[a]!.elo
            let eB = fighters[b]!.elo
            let expectedA = 1.0 / (1.0 + pow(10, (eB - eA) / 400.0))

            let scoreA: Double
            switch battle.verdict {
            case "a_wins": scoreA = 1.0
            case "b_wins": scoreA = 0.0
            default: scoreA = 0.5
            }

            fighters[a]!.elo += K * (scoreA - expectedA)
            fighters[b]!.elo += K * ((1 - scoreA) - (1 - expectedA))
            fighters[a]!.battles += 1
            fighters[b]!.battles += 1

            if scoreA == 1.0 { fighters[a]!.wins += 1; fighters[b]!.losses += 1 }
            else if scoreA == 0.0 { fighters[b]!.wins += 1; fighters[a]!.losses += 1 }
        }

        leaderboard = fighters.values.sorted { $0.elo > $1.elo }
    }

    private func verdictEmoji(_ verdict: String?) -> String {
        switch verdict {
        case "a_wins": return "🏆"
        case "b_wins": return "🥈"
        case "draw": return "🤝"
        default: return "⚔️"
        }
    }
}
