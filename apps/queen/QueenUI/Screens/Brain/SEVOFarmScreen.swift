import SwiftUI

struct SEVOFarmScreen: View {
    @EnvironmentObject var watcher: StateWatcher
    private let bridge = QueenBridge.shared

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                // Header
                HStack {
                    Text("🧬")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("SEVO FARM")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("Sacred EVolutionary Objective — Population-Based Training")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    VStack(spacing: ParietalSpacing.sm - 2) {
                        ActionButton(icon: "🧬", label: "Evolve", color: V4Color.accent,
                                     action: "farm_evolve")
                        ActionButton(icon: "💀", label: "Kill Idle", color: V4Color.statusError,
                                     action: "farm_kill_idle")
                    }
                }
                .padding()

                // Evolution metrics
                if let evo = bridge.loadEvolutionState() {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                        StatCard(
                            label: "Generation",
                            value: "\(evo["generation"] as? Int ?? evo["cycle"] as? Int ?? 0)",
                            accent: V4Color.accent
                        )
                        StatCard(
                            label: "Best PPL",
                            value: formatPPL(evo["best_ppl"] as? Double),
                            accent: V4Color.golden
                        )
                        StatCard(
                            label: "Population",
                            value: "\(evo["population_size"] as? Int ?? 0)",
                            accent: V4Color.purple
                        )
                    }
                    .padding(.horizontal)

                    // Strategy & stagnation
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                        StatCard(
                            label: "Strategy",
                            value: evo["strategy"] as? String ?? "—"
                        )
                        StatCard(
                            label: "Stagnation",
                            value: "\(evo["stagnation"] as? Int ?? 0)",
                            accent: (evo["stagnation"] as? Int ?? 0) > 3
                                ? V4Color.statusError
                                : V4Color.statusOK
                        )
                    }
                    .padding(.horizontal)

                    // Top services
                    if let services = evo["services"] as? [[String: Any]] {
                        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                            Text("TOP SERVICES")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(V4Color.golden)
                                .padding(.horizontal)

                            ForEach(Array(services.prefix(10).enumerated()), id: \.offset) { idx, svc in
                                HStack(spacing: ParietalSpacing.md) {
                                    Text(idx < 3 ? "🏆" : "📡")
                                    VStack(alignment: .leading) {
                                        Text(svc["name"] as? String ?? "service-\(idx)")
                                            .font(.body.weight(.medium).monospaced())
                                            .foregroundStyle(V4Color.textPrimary)
                                        HStack(spacing: ParietalSpacing.sm) {
                                            if let lr = svc["lr"] as? Double {
                                                Text("LR \(String(format: "%.1e", lr))")
                                                    .font(.caption2)
                                                    .foregroundStyle(V4Color.textSecondary)
                                            }
                                            if let sched = svc["schedule"] as? String {
                                                Text(sched)
                                                    .font(.caption2)
                                                    .foregroundStyle(V4Color.purple)
                                            }
                                        }
                                    }
                                    Spacer()
                                    if let ppl = svc["ppl"] as? Double {
                                        Text(String(format: "PPL %.2f", ppl))
                                            .font(.body.weight(.bold).monospacedDigit())
                                            .foregroundStyle(V4Color.golden)
                                    }
                                    if let step = svc["step"] as? Int {
                                        Text("\(step / 1000)K")
                                            .font(.caption.monospacedDigit())
                                            .foregroundStyle(V4Color.textSecondary)
                                    }
                                }
                                .padding()
                                .background(V4Color.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
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
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("FARM EVENT LOG")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                            .padding(.horizontal)

                        ForEach(events) { event in
                            HStack(spacing: ParietalSpacing.sm) {
                                Text(eventEmoji(event.type))
                                Text(event.type ?? "event")
                                    .font(.caption.weight(.medium))
                                    .foregroundStyle(V4Color.textPrimary)
                                if let svc = event.service {
                                    Text(svc)
                                        .font(.caption2.monospaced())
                                        .foregroundStyle(V4Color.textSecondary)
                                }
                                Spacer()
                                if let ppl = event.ppl {
                                    Text(String(format: "%.2f", ppl))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(V4Color.golden)
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
        .background(V4Color.bgWindow)
        .onAppear { watcher.reload() }
    }

    private var noDataView: some View {
        VStack(spacing: ParietalSpacing.md) {
            Text("No evolution state found")
                .font(.headline)
                .foregroundStyle(V4Color.textPrimary)
            Text(".trinity/evolution_state.json not found")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
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
