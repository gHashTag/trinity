import SwiftUI

struct RainbowBridgeScreen: View {
    @State private var events: [FarmEvent] = []
    private let bridge = QueenBridge.shared

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                HStack {
                    Text("🌈")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("RAINBOW BRIDGE")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.golden)
                        Text("GitHub ↔ Farm ↔ Arena Event Pipeline")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                }
                .padding()

                // Architecture
                VStack(alignment: .leading, spacing: 12) {
                    Text("BRIDGE FLOW")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

                    ForEach([
                        ("🧬", "SEVO → GitHub", "Farm evolve step auto-posts to #357"),
                        ("⚔️", "Arena → GitHub", "Judged battles auto-post to issues"),
                        ("📋", "GitHub → Arena", "--from-issue N reads issue as battle prompt"),
                        ("💬", "All → Telegram", "tri notify pipeline for alerts"),
                    ], id: \.1) { emoji, title, desc in
                        HStack(spacing: 12) {
                            Text(emoji)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(title)
                                    .font(.headline)
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

                // trinity-meta format
                VStack(alignment: .leading, spacing: 8) {
                    Text("TRINITY-META FORMAT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.purple)

                    Text("<!-- trinity-meta {\"type\":\"...\", ...} -->")
                        .font(.caption.monospaced())
                        .foregroundStyle(TrinityTheme.accent)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(TrinityTheme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Machine-parseable metadata in GitHub comments")
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .padding(.horizontal)

                // Event log
                if !events.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECENT EVENTS (\(events.count))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TrinityTheme.golden)
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
                                    Text(String(format: "PPL %.2f", ppl))
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
        .onAppear { events = bridge.loadFarmEvents(lastN: 30) }
    }

    private func eventEmoji(_ type: String?) -> String {
        switch type {
        case "evolve": return "🧬"
        case "kill": return "💀"
        case "spawn": return "🐣"
        case "record": return "🏆"
        case "arena": return "⚔️"
        default: return "🌈"
        }
    }
}
