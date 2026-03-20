import SwiftUI

struct FacultyScreen: View {
    @EnvironmentObject var watcher: StateWatcher

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                // Header
                HStack {
                    Text("🎓")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("FACULTY BOARD")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("Agent Status Dashboard")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()

                    VStack(alignment: .trailing) {
                        Text("\(watcher.heartbeats.filter(\.isUp).count)/\(watcher.heartbeats.count)")
                            .font(.title.weight(.bold).monospacedDigit())
                            .foregroundStyle(V4Color.accent)
                        Text("agents online")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                }
                .padding()

                // Summary stats
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                    StatCard(
                        label: "Total Agents",
                        value: "\(watcher.heartbeats.count)",
                        accent: V4Color.accent
                    )
                    StatCard(
                        label: "Online",
                        value: "\(watcher.heartbeats.filter(\.isUp).count)",
                        accent: V4Color.statusOK
                    )
                    StatCard(
                        label: "Offline",
                        value: "\(watcher.heartbeats.filter { !$0.isUp }.count)",
                        accent: V4Color.statusError
                    )
                }
                .padding(.horizontal)

                // Agent list
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("AGENT HEARTBEATS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)
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
                        VStack(spacing: ParietalSpacing.md) {
                            Text("No agents detected")
                                .font(.headline)
                                .foregroundStyle(V4Color.textPrimary)
                            Text("Heartbeat files not found in .trinity/")
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(ParietalSpacing.xxl)
                    }
                }

                // Farm events
                if !watcher.farmEvents.isEmpty {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("RECENT FARM EVENTS")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(V4Color.golden)
                            .padding(.horizontal)

                        ForEach(watcher.farmEvents.suffix(10)) { event in
                            HStack {
                                Text(eventEmoji(event.type))
                                VStack(alignment: .leading) {
                                    Text(event.type ?? "event")
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(V4Color.textPrimary)
                                    if let svc = event.service {
                                        Text(svc)
                                            .font(.caption2)
                                            .foregroundStyle(V4Color.textSecondary)
                                    }
                                }
                                Spacer()
                                if let ppl = event.ppl {
                                    Text(String(format: "PPL %.2f", ppl))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(V4Color.golden)
                                }
                                if let step = event.step {
                                    Text("step \(step)")
                                        .font(.caption2.monospacedDigit())
                                        .foregroundStyle(V4Color.textSecondary)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, ParietalSpacing.xxs)
                        }
                    }
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
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