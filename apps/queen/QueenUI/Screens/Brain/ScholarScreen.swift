import SwiftUI

struct ScholarScreen: View {
    @EnvironmentObject var watcher: StateWatcher

    private var heartbeat: AgentHeartbeat? {
        watcher.heartbeats.first(where: { $0.displayName == "scholar" })
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("📚")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("SCHOLAR")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("Research Agent — Perplexity Sonar API")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    ActionButton(icon: "🔍", label: "Research", color: V4Color.accent,
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
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("CAPABILITIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.golden)

                    ForEach([
                        ("🔍", "perplexity_search", "Find URLs, facts, recent news"),
                        ("💬", "perplexity_ask", "Quick AI-answered questions"),
                        ("📊", "perplexity_research", "Multi-source deep investigation"),
                        ("🧠", "perplexity_reason", "Step-by-step logic analysis"),
                    ], id: \.1) { emoji, tool, desc in
                        HStack(spacing: ParietalSpacing.md) {
                            Text(emoji)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(tool)
                                    .font(.headline.monospaced())
                                    .foregroundStyle(V4Color.textPrimary)
                                Text(desc)
                                    .font(.caption)
                                    .foregroundStyle(V4Color.textSecondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(V4Color.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                    }
                }
                .padding(.horizontal)

                // Research focus areas
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("RESEARCH FOCUS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)

                    ForEach([
                        "DESI dark energy (w₀ = -0.618 prediction)",
                        "DUNE CP violation (δ_CP = 248.75° prediction)",
                        "NANOGrav gravitational waves",
                        "Ternary AI competitors (BitNet, Falcon, PBT)",
                        "FPGA inference benchmarks",
                    ], id: \.self) { topic in
                        HStack(spacing: ParietalSpacing.sm) {
                            Text("●")
                                .foregroundStyle(V4Color.purple)
                            Text(topic)
                                .font(.body)
                                .foregroundStyle(V4Color.textPrimary)
                        }
                        .padding(.horizontal)
                    }
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
    }
}
