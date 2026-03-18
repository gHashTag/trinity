import SwiftUI

struct ScholarScreen: View {
    @EnvironmentObject var watcher: StateWatcher

    private var heartbeat: AgentHeartbeat? {
        watcher.heartbeats.first(where: { $0.displayName == "scholar" })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                HStack {
                    Text("📚")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("SCHOLAR")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("Research Agent — Perplexity Sonar API")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    ActionButton(icon: "🔍", label: "Research", color: TrinityTheme.accent,
                                 action: "scholar_research")
                }
                .padding()

                // Heartbeat
                if let hb = heartbeat {
                    AgentRow(
                        name: "Scholar",
                        status: hb.isUp ? .up : .down,
                        wakeCount: hb.wake,
                        detail: "Errors: \(hb.errors_scanned ?? 0), Fixes: \(hb.fixes_applied ?? 0)"
                    )
                    .padding(.horizontal)
                } else {
                    AgentRow(name: "Scholar", status: .down, wakeCount: nil, detail: "No heartbeat")
                        .padding(.horizontal)
                }

                // Capabilities
                VStack(alignment: .leading, spacing: 12) {
                    Text("CAPABILITIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.golden)

                    ForEach([
                        ("🔍", "perplexity_search", "Find URLs, facts, recent news"),
                        ("💬", "perplexity_ask", "Quick AI-answered questions"),
                        ("📊", "perplexity_research", "Multi-source deep investigation"),
                        ("🧠", "perplexity_reason", "Step-by-step logic analysis"),
                    ], id: \.1) { emoji, tool, desc in
                        HStack(spacing: 12) {
                            Text(emoji)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(tool)
                                    .font(.headline.monospaced())
                                    .foregroundStyle(TrinityTheme.textPrimary)
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(TrinityTheme.textMuted)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(TrinityTheme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                    }
                }
                .padding(.horizontal)

                // Research focus areas
                VStack(alignment: .leading, spacing: 8) {
                    Text("RESEARCH FOCUS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

                    ForEach([
                        "DESI dark energy (w₀ = -0.618 prediction)",
                        "DUNE CP violation (δ_CP = 248.75° prediction)",
                        "NANOGrav gravitational waves",
                        "Ternary AI competitors (BitNet, Falcon, PBT)",
                        "FPGA inference benchmarks",
                    ], id: \.self) { topic in
                        HStack(spacing: 8) {
                            Text("●")
                                .foregroundStyle(TrinityTheme.purple)
                            Text(topic)
                                .font(.body)
                                .foregroundStyle(TrinityTheme.textPrimary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
    }
}
