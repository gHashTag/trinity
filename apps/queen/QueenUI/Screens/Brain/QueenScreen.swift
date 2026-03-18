import SwiftUI

struct QueenScreen: View {
    @EnvironmentObject var watcher: StateWatcher
    @State private var actions: [QueenActionDef] = []
    @State private var policy: QueenPolicy?
    @State private var selectedAction: QueenActionDef?

    private let bridge = QueenBridge.shared

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                // Header + Daemon Status
                daemonHeader

                // Policy Map: 29 actions × 3 levels
                policyMapSection

                // Audit Trail
                auditTrailSection

                // Incident Memory (24h stats)
                incidentSection

                // Approval Queue (L2 pending)
                approvalQueueSection

                // Hard Bans
                hardBansSection
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
        .onAppear { loadData() }
    }

    // MARK: - Daemon Header

    private var daemonHeader: some View {
        HStack(spacing: 20) {
            // Status ring
            ZStack {
                Circle()
                    .stroke(TrinityTheme.bgCard, lineWidth: 8)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: daemonRunning ? 1.0 : 0.0)
                    .stroke(
                        daemonRunning ? TrinityTheme.statusOK : TrinityTheme.statusError,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .frame(width: 80, height: 80)
                    .animation(.easeInOut(duration: 0.8), value: daemonRunning)
                Text(daemonRunning ? "ON" : "OFF")
                    .font(.title3.weight(.black))
                    .foregroundStyle(daemonRunning ? TrinityTheme.statusOK : TrinityTheme.statusError)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text("QUEEN SECURITY")
                    .font(.title.weight(.bold))
                    .foregroundStyle(TrinityTheme.golden)
                Text("Policy Engine & Audit Command Center")
                    .font(.subheadline)
                    .foregroundStyle(TrinityTheme.textMuted)

                HStack(spacing: 16) {
                    miniStat("Cycle", "\(watcher.queenState?.cycle ?? 0)")
                    miniStat("Uptime", watcher.queenState?.uptimeFormatted ?? "N/A")
                    miniStat("Auto/hr", "\(watcher.queenState?.auto_actions_this_hour ?? 0)")
                    miniStat("Level", policyLevelLabel)
                }
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Policy Map

    private var policyMapSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("POLICY MAP")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.golden)
                Spacer()
                Text("\(actions.count) actions")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .padding(.horizontal)

            // Legend
            HStack(spacing: 16) {
                legendDot(color: TrinityTheme.statusOK, label: "L0 Auto")
                legendDot(color: TrinityTheme.golden, label: "L1 Notify")
                legendDot(color: TrinityTheme.statusError, label: "L2 Approve")
            }
            .padding(.horizontal)

            // Grid of actions
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 5)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(actions, id: \.stableId) { action in
                    actionCell(action)
                }
            }
            .padding(.horizontal)

            // Selected action detail
            if let sel = selectedAction {
                actionDetailCard(sel)
                    .padding(.horizontal)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func actionCell(_ action: QueenActionDef) -> some View {
        let isSelected = selectedAction?.stableId == action.stableId
        let levelColor = colorForLevel(action.level)

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedAction = isSelected ? nil : action
            }
        } label: {
            VStack(spacing: 2) {
                Text(action.emoji ?? "⚡")
                    .font(.title3)
                Text(action.label ?? action.stableId)
                    .font(.system(size: 8, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(levelColor.opacity(isSelected ? 0.3 : 0.1))
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? levelColor : levelColor.opacity(0.3), lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func actionDetailCard(_ action: QueenActionDef) -> some View {
        HStack(spacing: 16) {
            Text(action.emoji ?? "⚡")
                .font(.largeTitle)

            VStack(alignment: .leading, spacing: 4) {
                Text(action.label ?? action.stableId)
                    .font(.headline)
                    .foregroundStyle(TrinityTheme.textPrimary)
                HStack(spacing: 12) {
                    detailTag("Level", action.levelLabel, color: colorForLevel(action.level))
                    detailTag("Rate", "\(action.max_per_hour ?? 0)/hr", color: TrinityTheme.accent)
                    detailTag("Cooldown", "\(action.cooldown_sec ?? 0)s", color: TrinityTheme.purple)
                }
            }
            Spacer()
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cardCorner)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Audit Trail

    private var auditTrailSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("AUDIT TRAIL")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.accent)
                Spacer()
                Text("\(watcher.auditEntries.count) entries")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .padding(.horizontal)

            if watcher.auditEntries.isEmpty {
                Text("No audit entries yet")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .padding()
            } else {
                ForEach(watcher.auditEntries.reversed()) { entry in
                    auditRow(entry)
                }
            }
        }
    }

    private func auditRow(_ entry: AuditEntry) -> some View {
        HStack(spacing: 8) {
            // Timestamp
            if let ts = entry.ts {
                Text(formatTime(ts))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(TrinityTheme.textMuted)
                    .frame(width: 60, alignment: .leading)
            }

            // Icon
            Text(entry.icon)
                .font(.caption)

            // Action
            Text(entry.action ?? "—")
                .font(.caption.weight(.medium).monospaced())
                .foregroundStyle(TrinityTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Verdict badge
            if let verdict = entry.verdict ?? entry.kind {
                Text(verdict.uppercased())
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(verdictColor(verdict))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(verdictColor(verdict).opacity(0.15))
                    .clipShape(SwiftUI.Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal)
    }

    // MARK: - Incident Memory

    private var incidentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("24H INCIDENTS")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.statusError)
                .padding(.horizontal)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                StatCard(
                    label: "Build Breaks",
                    value: "\(countAuditKind("alert"))",
                    accent: TrinityTheme.statusError
                )
                StatCard(
                    label: "Heal Cycles",
                    value: "\(watcher.queenState?.last_build_heal_cycle ?? 0)",
                    accent: TrinityTheme.golden
                )
                StatCard(
                    label: "Escalations",
                    value: "\(countAuditKind("auto_pending"))",
                    accent: TrinityTheme.purple
                )
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Approval Queue

    private var approvalQueueSection: some View {
        let pendingEntries = watcher.auditEntries.filter { $0.kind == "auto_pending" }

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("APPROVAL QUEUE")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.golden)
                Spacer()
                if !pendingEntries.isEmpty {
                    Text("\(pendingEntries.count) pending")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(TrinityTheme.golden)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(TrinityTheme.golden.opacity(0.15))
                        .clipShape(SwiftUI.Capsule())
                }
            }
            .padding(.horizontal)

            if pendingEntries.isEmpty {
                HStack {
                    Text("No pending approvals")
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                    Spacer()
                }
                .padding()
                .background(TrinityTheme.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                .padding(.horizontal)
            } else {
                ForEach(pendingEntries) { entry in
                    HStack(spacing: 12) {
                        Text(entry.icon)
                            .font(.title3)
                        VStack(alignment: .leading) {
                            Text(entry.action ?? "Unknown action")
                                .font(.headline)
                                .foregroundStyle(TrinityTheme.textPrimary)
                            if let detail = entry.detail {
                                Text(detail)
                                    .font(.caption)
                                    .foregroundStyle(TrinityTheme.textMuted)
                            }
                        }
                        Spacer()
                        ActionButton(icon: "✅", label: "Approve", color: TrinityTheme.statusOK,
                                     action: "queen_approve", params: ["action": entry.action ?? ""])
                        ActionButton(icon: "❌", label: "Deny", color: TrinityTheme.statusError,
                                     action: "queen_deny", params: ["action": entry.action ?? ""])
                    }
                    .padding()
                    .background(TrinityTheme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                    .overlay(
                        RoundedRectangle(cornerRadius: TrinityTheme.cardCorner)
                            .stroke(TrinityTheme.golden.opacity(0.3), lineWidth: 1)
                    )
                    .padding(.horizontal)
                }
            }
        }
    }

    // MARK: - Hard Bans

    private var hardBansSection: some View {
        let bans = [
            ("🚫", "Delete running service"),
            ("🚫", "Force-push to main"),
            ("🚫", "Flat LR schedule"),
            ("🚫", "Set startCommand"),
            ("🚫", "Deploy without env vars"),
            ("🚫", "Skip hooks (--no-verify)"),
            ("🚫", "Delete .trinity/ state"),
            ("🚫", "Disable auto-deploy guard"),
            ("🚫", "Commit secrets (.env)"),
            ("🚫", "Edit generated/ files"),
            ("🚫", "Create .sh scripts"),
            ("🚫", "Drop database/state"),
        ]

        return VStack(alignment: .leading, spacing: 8) {
            Text("HARD BANS (NEVER UNLOCK)")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.statusError)
                .padding(.horizontal)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(bans, id: \.1) { emoji, label in
                    HStack(spacing: 6) {
                        Text(emoji)
                            .font(.caption)
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.textPrimary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
                    .background(TrinityTheme.statusError.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(TrinityTheme.statusError.opacity(0.3), lineWidth: 1)
                    )
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Helpers

    private var daemonRunning: Bool {
        watcher.queenState?.isRunning ?? false
    }

    private var policyLevelLabel: String {
        guard let p = policy else { return "—" }
        if p.god_mode == true { return "GOD" }
        return "L\(p.max_auto_level ?? 0)"
    }

    private func colorForLevel(_ level: Int?) -> Color {
        switch level {
        case 0: return TrinityTheme.statusOK
        case 1: return TrinityTheme.golden
        case 2: return TrinityTheme.statusError
        default: return TrinityTheme.textMuted
        }
    }

    private func verdictColor(_ verdict: String) -> Color {
        switch verdict.lowercased() {
        case "auto", "allowed", "ok": return TrinityTheme.statusOK
        case "auto_denied", "denied", "blocked": return TrinityTheme.statusError
        case "auto_pending", "pending": return TrinityTheme.golden
        default: return TrinityTheme.textMuted
        }
    }

    private func countAuditKind(_ kind: String) -> Int {
        watcher.auditEntries.filter { $0.kind == kind }.count
    }

    private func formatTime(_ ts: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: date)
    }

    private func miniStat(_ label: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(TrinityTheme.textPrimary)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(TrinityTheme.textMuted)
        }
    }

    private func legendDot(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)
        }
    }

    private func detailTag(_ label: String, _ value: String, color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.caption.weight(.bold))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(TrinityTheme.textMuted)
        }
    }

    private func loadData() {
        watcher.reload()
        actions = bridge.loadActions()
        policy = bridge.loadPolicy()
    }
}
