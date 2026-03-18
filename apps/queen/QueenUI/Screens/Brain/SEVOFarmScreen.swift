import SwiftUI

struct SEVOFarmScreen: View {
    @EnvironmentObject var watcher: StateWatcher
    private let bridge = QueenBridge.shared

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                // Header
                HStack {
                    Text("🧬")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("SEVO FARM")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("Sacred EVolutionary Objective — Population-Based Training")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    VStack(spacing: 6) {
                        ActionButton(icon: "🧬", label: "Evolve", color: TrinityTheme.accent,
                                     action: "farm_evolve")
                        ActionButton(icon: "💀", label: "Kill Idle", color: TrinityTheme.statusError,
                                     action: "farm_kill_idle")
                    }
                }
                .padding()

                // Evolution metrics
                if let evo = bridge.loadEvolutionState() {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            label: "Generation",
                            value: "\(evo["generation"] as? Int ?? evo["cycle"] as? Int ?? 0)",
                            accent: TrinityTheme.accent
                        )
                        StatCard(
                            label: "Best PPL",
                            value: formatPPL(evo["best_ppl"] as? Double),
                            accent: TrinityTheme.golden
                        )
                        StatCard(
                            label: "Population",
                            value: "\(evo["population_size"] as? Int ?? 0)",
                            accent: TrinityTheme.purple
                        )
                    }
                    .padding(.horizontal)

                    // Strategy & stagnation
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            label: "Strategy",
                            value: evo["strategy"] as? String ?? "—"
                        )
                        StatCard(
                            label: "Stagnation",
                            value: "\(evo["stagnation"] as? Int ?? 0)",
                            accent: (evo["stagnation"] as? Int ?? 0) > 3
                                ? TrinityTheme.statusError
                                : TrinityTheme.statusOK
                        )
                    }
                    .padding(.horizontal)

                    // Top services
                    if let services = evo["services"] as? [[String: Any]] {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("TOP SERVICES")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TrinityTheme.golden)
                                .padding(.horizontal)

                            ForEach(Array(services.prefix(10).enumerated()), id: \.offset) { idx, svc in
                                HStack(spacing: 12) {
                                    Text(idx < 3 ? "🏆" : "📡")
                                    VStack(alignment: .leading) {
                                        Text(svc["name"] as? String ?? "service-\(idx)")
                                            .font(.body.weight(.medium).monospaced())
                                            .foregroundStyle(TrinityTheme.textPrimary)
                                        HStack(spacing: 8) {
                                            if let lr = svc["lr"] as? Double {
                                                Text("LR \(String(format: "%.1e", lr))")
                                                    .font(.caption2)
                                                    .foregroundStyle(TrinityTheme.textMuted)
                                            }
                                            if let sched = svc["schedule"] as? String {
                                                Text(sched)
                                                    .font(.caption2)
                                                    .foregroundStyle(TrinityTheme.purple)
                                            }
                                        }
                                    }
                                    Spacer()
                                    if let ppl = svc["ppl"] as? Double {
                                        Text(String(format: "PPL %.2f", ppl))
                                            .font(.body.weight(.bold).monospacedDigit())
                                            .foregroundStyle(TrinityTheme.golden)
                                    }
                                    if let step = svc["step"] as? Int {
                                        Text("\(step / 1000)K")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(TrinityTheme.textMuted)
                                    }
                                }
                                .padding()
                                .background(TrinityTheme.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                                .padding(.horizontal)
                            }
                        }
                    }
                } else {
                    noDataView
                }

                // PPL Loss Chart
                PPLChart(events: watcher.farmEvents)
                    .padding(.horizontal)

                // Recent farm events
                let events = bridge.loadFarmEvents(lastN: 15)
                if !events.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("FARM EVENT LOG")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                            .padding(.horizontal)

                        ForEach(events) { event in
                            HStack(spacing: 8) {
                                Text(eventEmoji(event.type))
                                Text(event.type ?? "event")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(TrinityTheme.textPrimary)
                                if let svc = event.service {
                                    Text(svc)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(TrinityTheme.textMuted)
                                }
                                Spacer()
                                if let ppl = event.ppl {
                                    Text(String(format: "%.2f", ppl))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(TrinityTheme.golden)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 2)
                        }
                    }
                }
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
        .onAppear { watcher.reload() }
    }

    private var noDataView: some View {
        VStack(spacing: 12) {
            Text("No evolution state found")
                .font(.headline)
                .foregroundStyle(TrinityTheme.textPrimary)
            Text(".trinity/evolution_state.json not found")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
    }

    private func formatPPL(_ ppl: Double?) -> String {
        guard let ppl else { return "—" }
        return String(format: "%.2f", ppl)
    }

    private func eventEmoji(_ type: String?) -> String {
        switch type {
        case "evolve": return "🧬"
        case "kill": return "💀"
        case "spawn": return "🐣"
        case "record": return "🏆"
        case "checkpoint": return "💾"
        case "recycle": return "♻️"
        case "inject": return "💉"
        default: return "📡"
        }
    }
}
