import SwiftUI

struct OracleScreen: View {
    @EnvironmentObject var watcher: StateWatcher

    private var senses: QueenSenses? { watcher.queenSenses }
    private var daemonState: QueenDaemonState? { watcher.queenState }
    private var audit: [AuditEntry] { Array(watcher.auditEntries.suffix(5).reversed()) }

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                // Header
                headerSection

                // Daemon status
                daemonStatusSection

                // 3 Metric Gauges
                gaugesSection

                // Health badge
                healthBadge

                // Senses grid
                sensesGrid

                // Auto-Decision
                autoDecisionSection

                // Recent audit
                recentAuditSection
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
        .onAppear { watcher.reload() }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            Text("\u{1F52E}")
                .font(.system(size: 48))
            VStack(alignment: .leading) {
                Text("QUEEN v4 COMMAND CENTER")
                    .font(.title.weight(.bold))
                    .foregroundStyle(TrinityTheme.golden)
                Text("18 Senses | 29 Actions | 12 Rules")
                    .font(.subheadline)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Daemon Status

    private var daemonStatusSection: some View {
        HStack(spacing: 12) {
            let running = daemonState?.isRunning ?? false
            Circle()
                .fill(running ? TrinityTheme.statusOK : TrinityTheme.statusError)
                .frame(width: 12, height: 12)
            Text(running ? "DAEMON RUNNING" : "DAEMON STOPPED")
                .font(.caption.weight(.bold))
                .foregroundStyle(running ? TrinityTheme.statusOK : TrinityTheme.statusError)

            if let cycle = daemonState?.cycle {
                Text("Cycle #\(cycle)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            if let state = daemonState {
                Text("Uptime: \(state.uptimeFormatted)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            Spacer()
        }
        .padding(.horizontal)
    }

    // MARK: - Gauges

    private var gaugesSection: some View {
        HStack(spacing: 24) {
            MetricGauge(
                label: "Ouroboros",
                value: senses?.ouroboros_score ?? 0,
                maxValue: 100,
                accent: TrinityTheme.golden
            )
            MetricGauge(
                label: "Best PPL",
                value: senses?.farm_best_ppl ?? 999,
                maxValue: 100,
                accent: TrinityTheme.accent
            )
            MetricGauge(
                label: "Tests",
                value: Double(senses?.test_rate ?? 0),
                maxValue: 100,
                accent: TrinityTheme.purple
            )
        }
        .padding()
    }

    // MARK: - Health Badge

    private var healthBadge: some View {
        let status = senses?.healthStatus ?? "UNKNOWN"
        let color: Color = {
            switch senses?.healthColor {
            case "green": return TrinityTheme.statusOK
            case "yellow": return TrinityTheme.statusWarn
            case "red": return TrinityTheme.statusError
            default: return TrinityTheme.textMuted
            }
        }()

        return Text(status)
            .font(.title2.weight(.bold))
            .foregroundStyle(color)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(color.opacity(0.15))
            .clipShape(Capsule())
    }

    // MARK: - Senses Grid

    private var sensesGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SENSES (18)")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.golden)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                senseCard(icon: "\u{1F527}", name: "Build", value: (senses?.build_ok ?? false) ? "OK" : "FAIL",
                         ok: senses?.build_ok ?? false)
                senseCard(icon: "\u{2699}\u{FE0F}", name: "Tests", value: "\(senses?.test_rate ?? 0)%",
                         ok: (senses?.test_rate ?? 0) >= 80)
                senseCard(icon: "\u{1F4BE}", name: "Dirty", value: "\(senses?.dirty_files ?? 0)",
                         ok: (senses?.dirty_files ?? 0) < 50)
                senseCard(icon: "\u{1F4CB}", name: "Issues", value: "\(senses?.open_issues ?? 0)", ok: true)
                senseCard(icon: "\u{1F916}", name: "Agents", value: "\(senses?.agent_count ?? 0)/5",
                         ok: (senses?.agent_count ?? 0) >= 2)
                senseCard(icon: "\u{1F9EC}", name: "Farm", value: "\(senses?.farm_services ?? 0) srv", ok: true)
                senseCard(icon: "\u{1F3C6}", name: "PPL", value: String(format: "%.1f", senses?.farm_best_ppl ?? 999),
                         ok: (senses?.farm_best_ppl ?? 999) < 10)
                senseCard(icon: "\u{2694}\u{FE0F}", name: "Arena", value: "\(senses?.arena_battles ?? 0)", ok: true)
                senseCard(icon: "\u{2B50}", name: "Ouroboros", value: String(format: "%.1f", senses?.ouroboros_score ?? 0),
                         ok: (senses?.ouroboros_score ?? 0) >= 70)
                senseCard(icon: "\u{1F4BE}", name: "Disk", value: String(format: "%.1f GB", senses?.disk_free_gb ?? 0),
                         ok: (senses?.disk_free_gb ?? 0) > 10)
                senseCard(icon: "\u{1F511}", name: "Keys", value: "\(senses?.keys_present ?? 0)/\(senses?.keys_total ?? 5)",
                         ok: senses?.keys_present == senses?.keys_total)
                senseCard(icon: "\u{1F9E0}", name: "XP", value: "\(senses?.experience_episodes ?? 0)", ok: true)
                senseCard(icon: "\u{1F6B6}", name: "Farm Idle", value: "\(senses?.farm_idle_count ?? 0)",
                         ok: (senses?.farm_idle_count ?? 0) <= 3)
                senseCard(icon: "\u{23F0}", name: "Arena Stale", value: "\(senses?.stale_arena_hours ?? 0)h",
                         ok: (senses?.stale_arena_hours ?? 0) <= 24)
                senseCard(icon: "\u{1F916}", name: "Spawn", value: "\(senses?.agent_spawn_issues ?? 0)",
                         ok: (senses?.agent_spawn_issues ?? 0) == 0)
                senseCard(icon: "\u{1F5D1}", name: "Finished", value: "\(senses?.finished_containers ?? 0)",
                         ok: (senses?.finished_containers ?? 0) <= 5)
                senseCard(icon: "\u{1F310}", name: "Network", value: (senses?.network_ok ?? false) ? "OK" : "DOWN",
                         ok: senses?.network_ok ?? false)
                senseCard(icon: "\u{1F4E4}", name: "Last Push", value: pushAgo(),
                         ok: pushAgoSec() < 86400)
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Auto-Decision

    private var autoDecisionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            let autoCount = daemonState?.auto_actions_this_hour ?? 0

            Text("AUTO-ACTIONS")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.accent)
                .padding(.horizontal)

            HStack {
                Text("\u{26A1}")
                Text("\(autoCount)/3 this hour")
                    .font(.body.monospacedDigit())
                    .foregroundStyle(TrinityTheme.textPrimary)
                Spacer()
            }
            .padding()
            .background(TrinityTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
            .padding(.horizontal)
        }
    }

    // MARK: - Recent Audit

    private var recentAuditSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("RECENT ACTIONS")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.purple)
                .padding(.horizontal)

            if audit.isEmpty {
                Text("No audit entries yet")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .padding(.horizontal)
            } else {
                ForEach(audit) { entry in
                    HStack(spacing: 8) {
                        Text(entry.icon)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.action ?? "unknown")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(TrinityTheme.textPrimary)
                            if let detail = entry.detail, !detail.isEmpty {
                                Text(detail)
                                    .font(.caption2)
                                    .foregroundStyle(TrinityTheme.textMuted)
                                    .lineLimit(1)
                            }
                        }
                        Spacer()
                        if let success = entry.success {
                            Text(success ? "\u{2705}" : "\u{274C}")
                        }
                    }
                    .padding(.horizontal)
                    .padding(.vertical, 4)
                }
            }
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
        .padding(.horizontal)
    }

    // MARK: - Helpers

    private func senseCard(icon: String, name: String, value: String, ok: Bool) -> some View {
        HStack(spacing: 6) {
            Text(icon)
                .font(.caption)
            VStack(alignment: .leading, spacing: 1) {
                Text(name)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
                Text(value)
                    .font(.caption.weight(.bold).monospacedDigit())
                    .foregroundStyle(ok ? TrinityTheme.statusOK : TrinityTheme.statusWarn)
            }
            Spacer()
        }
        .padding(6)
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private func pushAgoSec() -> Int {
        guard let ts = senses?.last_git_push_ts, ts > 0 else { return 999999 }
        return Int(Date().timeIntervalSince1970) - ts
    }

    private func pushAgo() -> String {
        let secs = pushAgoSec()
        if secs > 86400 { return "\(secs / 86400)d" }
        if secs > 3600 { return "\(secs / 3600)h" }
        return "\(secs / 60)m"
    }
}
