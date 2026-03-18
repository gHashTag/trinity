import SwiftUI

struct FacultyScreen: View {
    @EnvironmentObject var watcher: StateWatcher

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                // Header
                HStack {
                    Text("🎓")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("FACULTY BOARD")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("Agent Status Dashboard")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(watcher.heartbeats.filter(\.isUp).count)/\(watcher.heartbeats.count)")
                            .font(.title.weight(.bold).monospacedDigit())
                            .foregroundStyle(TrinityTheme.accent)
                        Text("agents online")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }
                .padding()

                // Summary stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(
                        label: "Total Agents",
                        value: "\(watcher.heartbeats.count)",
                        accent: TrinityTheme.accent
                    )
                    StatCard(
                        label: "Online",
                        value: "\(watcher.heartbeats.filter(\.isUp).count)",
                        accent: TrinityTheme.statusOK
                    )
                    StatCard(
                        label: "Offline",
                        value: "\(watcher.heartbeats.filter { !$0.isUp }.count)",
                        accent: TrinityTheme.statusError
                    )
                }
                .padding(.horizontal)

                // Agent list
                VStack(alignment: .leading, spacing: 8) {
                    Text("AGENT HEARTBEATS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)
                        .padding(.horizontal)

                    ForEach(watcher.heartbeats) { beat in
                        AgentRow(
                            name: beat.displayName,
                            status: beat.isUp ? .up : .down,
                            wakeCount: beat.wake,
                            detail: formatTimestamp(beat.timestamp)
                        )
                        .padding(.horizontal)
                    }

                    if watcher.heartbeats.isEmpty {
                        VStack(spacing: 12) {
                            Text("No agents detected")
                                .font(.headline)
                                .foregroundStyle(TrinityTheme.textPrimary)
                            Text("Heartbeat files not found in .trinity/")
                                .font(.caption)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(32)
                    }
                }

                // Farm events
                if !watcher.farmEvents.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("RECENT FARM EVENTS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TrinityTheme.golden)
                            .padding(.horizontal)

                        ForEach(watcher.farmEvents.suffix(10)) { event in
                            HStack {
                                Text(eventEmoji(event.type))
                                VStack(alignment: .leading) {
                                    Text(event.type ?? "event")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(TrinityTheme.textPrimary)
                                    if let svc = event.service {
                                        Text(svc)
                                            .font(.caption2)
                                            .foregroundStyle(TrinityTheme.textMuted)
                                    }
                                }
                                Spacer()
                                if let ppl = event.ppl {
                                    Text(String(format: "PPL %.2f", ppl))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(TrinityTheme.golden)
                                }
                                if let step = event.step {
                                    Text("step \(step)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(TrinityTheme.textMuted)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
        .onAppear { watcher.reload() }
    }

    private func formatTimestamp(_ ts: Int?) -> String {
        guard let ts else { return "No heartbeat" }
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }

    private func eventEmoji(_ type: String?) -> String {
        switch type {
        case "evolve": return "🧬"
        case "kill": return "💀"
        case "spawn": return "🐣"
        case "record": return "🏆"
        case "checkpoint": return "💾"
        default: return "📡"
        }
    }
}