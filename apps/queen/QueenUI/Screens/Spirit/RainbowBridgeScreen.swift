import SwiftUI

struct RainbowBridgeScreen: View {
    @State private var events: [FarmEvent] = []
    private let bridge = QueenBridge.shared

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("🌈")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("RAINBOW BRIDGE")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.golden)
                        Text("GitHub ↔ Farm ↔ Arena Event Pipeline")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                }
                .padding()

                // Architecture
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("BRIDGE FLOW")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)

                    ForEach([
                        ("🧬", "SEVO → GitHub", "Farm evolve step auto-posts to #357"),
                        ("⚔️", "Arena → GitHub", "Judged battles auto-post to issues"),
                        ("📋", "GitHub → Arena", "--from-issue N reads issue as battle prompt"),
                        ("💬", "All → Telegram", "tri notify pipeline for alerts"),
                    ], id: \.1) { emoji, title, desc in
                        HStack(spacing: ParietalSpacing.md) {
                            Text(emoji)
                                .font(.title2)
                            VStack(alignment: .leading) {
                                Text(title)
                                    .font(.headline)
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

                // trinity-meta format
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("TRINITY-META FORMAT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.purple)

                    Text("<!-- trinity-meta {\"type\":\"...\", ...} -->")
                        .font(.caption.monospaced())
                        .foregroundStyle(V4Color.accent)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(V4Color.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    Text("Machine-parseable metadata in GitHub comments")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .padding(.horizontal)

                // Event log
                if !events.isEmpty {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("RECENT EVENTS (\(events.count))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(V4Color.golden)
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
                                    Text(String(format: "PPL %.2f", ppl))
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
