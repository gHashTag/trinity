import SwiftUI

struct BridgeScreen: View {
    @EnvironmentObject var watcher: StateWatcher
    @State private var envKeys: [String: String] = [:]
    @State private var events: [AgentEvent] = []

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                // Header
                HStack {
                    Text("\u{1F310}")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("INTEGRATIONS")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("Integration Hub & Event Monitor")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    StatCard(label: "Channels", value: "5")
                        .frame(width: 80)
                }
                .padding()

                // Integration Cards
                integrationsGrid

                // Unified Event Log
                eventLogSection

                // SSH Bridge
                sshBridgeSection
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
        .onAppear { loadData() }
    }

    // MARK: - Integration Cards

    private var integrationsGrid: some View {
        VStack(spacing: 8) {
            // Row 1: Telegram + GitHub
            HStack(spacing: 8) {
                integrationCard(
                    emoji: "\u{1F916}",
                    name: "Telegram",
                    statusOk: hasTelegramToken,
                    details: [
                        ("Bot", hasTelegramToken ? "Connected" : "No token"),
                        ("Chat ID", envKeys["TG_CHAT_ID"] ?? "—"),
                        ("Last", formatTs(watcher.queenState?.tg_last_update_id)),
                    ],
                    actionLabel: "Send Test",
                    actionName: "telegram_test"
                )

                integrationCard(
                    emoji: "\u{1F419}",
                    name: "GitHub",
                    statusOk: hasGitHubToken,
                    details: [
                        ("Token", hasGitHubToken ? "Present" : "Missing"),
                        ("Repo", "gHashTag/trinity"),
                        ("Issues", "\(watcher.queenSenses?.open_issues ?? 0) open"),
                    ],
                    actionLabel: "Refresh",
                    actionName: "issues_refresh"
                )
            }
            .padding(.horizontal)

            // Row 2: Railway + Arena
            HStack(spacing: 8) {
                integrationCard(
                    emoji: "\u{1F682}",
                    name: "Railway",
                    statusOk: hasRailwayToken,
                    details: [
                        ("Token", hasRailwayToken ? "Present" : "Missing"),
                        ("Services", "\(watcher.queenSenses?.farm_services ?? 0) active"),
                        ("Best PPL", String(format: "%.2f", watcher.queenSenses?.farm_best_ppl ?? 0)),
                    ],
                    actionLabel: "Redeploy",
                    actionName: "farm_redeploy"
                )

                integrationCard(
                    emoji: "\u{2694}",
                    name: "Arena",
                    statusOk: watcher.queenSenses?.network_ok ?? false,
                    details: [
                        ("Endpoint", ":8080"),
                        ("Battles", "\(watcher.queenSenses?.arena_battles ?? 0) total"),
                        ("Stale", "\(watcher.queenSenses?.stale_arena_hours ?? 0)h"),
                    ],
                    actionLabel: "Run Battle",
                    actionName: "arena_battle"
                )
            }
            .padding(.horizontal)

            // Row 3: Action Queue (full width)
            actionQueueCard
                .padding(.horizontal)
        }
    }

    private func integrationCard(
        emoji: String,
        name: String,
        statusOk: Bool,
        details: [(String, String)],
        actionLabel: String,
        actionName: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack(spacing: 8) {
                Text(emoji)
                    .font(.title2)
                Text(name)
                    .font(.headline)
                    .foregroundStyle(TrinityTheme.textPrimary)
                Spacer()
                AgentStatusDot(status: statusOk ? .up : .down)
            }

            // Details
            ForEach(details, id: \.0) { label, value in
                HStack {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                        .frame(width: 60, alignment: .leading)
                    Text(value)
                        .font(.caption.monospaced())
                        .foregroundStyle(TrinityTheme.textPrimary)
                        .lineLimit(1)
                    Spacer()
                }
            }

            // Action button
            HStack {
                Spacer()
                ActionButton(icon: emoji, label: actionLabel, color: statusOk ? TrinityTheme.accent : TrinityTheme.textMuted,
                             action: actionName)
            }
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cardCorner)
                .stroke(statusOk ? TrinityTheme.accent.opacity(0.2) : TrinityTheme.statusError.opacity(0.2), lineWidth: 1)
        )
    }

    private var actionQueueCard: some View {
        HStack(spacing: 12) {
            Text("\u{1F517}")
                .font(.title2)

            VStack(alignment: .leading, spacing: 2) {
                Text("Action Queue")
                    .font(.headline)
                    .foregroundStyle(TrinityTheme.textPrimary)
                Text("Pending commands for Queen daemon")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            }

            Spacer()

            AgentStatusDot(status: .up)

            ActionButton(icon: "\u{1F5D1}", label: "Clear", color: TrinityTheme.statusWarn,
                         action: "queue_clear")
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cardCorner)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }

    // MARK: - Event Log

    private var eventLogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("UNIFIED EVENT LOG")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.accent)
                Spacer()
                Text("\(events.count) events")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .padding(.horizontal)

            if events.isEmpty {
                Text("No recent events")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .padding()
            } else {
                ForEach(events.suffix(20).reversed()) { event in
                    eventRow(event)
                }
            }
        }
    }

    private func eventRow(_ event: AgentEvent) -> some View {
        HStack(spacing: 8) {
            // Timestamp
            if let ts = event.ts {
                Text(formatTime(ts))
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(TrinityTheme.textMuted)
                    .frame(width: 60, alignment: .leading)
            }

            // Source icon
            Text(sourceIcon(event))
                .font(.caption)

            // Kind
            Text(event.resolvedKind)
                .font(.caption2.weight(.medium).monospaced())
                .foregroundStyle(TrinityTheme.accent)
                .frame(width: 60, alignment: .leading)

            // Text
            Text(event.text ?? event.action ?? event.detail ?? "—")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textPrimary)
                .lineLimit(1)

            Spacer()

            // Agent badge
            if let agent = event.agent {
                Text(agent)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.purple)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(TrinityTheme.purple.opacity(0.1))
                    .clipShape(Capsule())
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 3)
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .padding(.horizontal)
    }

    // MARK: - SSH Bridge

    private var sshBridgeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SSH BRIDGE")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.golden)
                .padding(.horizontal)

            VStack(alignment: .leading, spacing: 8) {
                sshRow("Host", "gondola.proxy.rlwy.net")
                sshRow("Port", "35344")
                sshRow("User", "trinity")
                sshRow("Key", "~/.ssh/id_ed25519")

                Divider().background(TrinityTheme.bgCardBorder)

                HStack {
                    Text("$")
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(TrinityTheme.accent)
                    Text("ssh -i ~/.ssh/id_ed25519 -p 35344 trinity@gondola.proxy.rlwy.net")
                        .font(.caption2.monospaced())
                        .foregroundStyle(TrinityTheme.textPrimary)
                        .lineLimit(1)
                }
            }
            .padding()
            .background(TrinityTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cardCorner)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
            )
            .padding(.horizontal)
        }
    }

    private func sshRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(width: 50, alignment: .leading)
            Text(value)
                .font(.caption.monospaced())
                .foregroundStyle(TrinityTheme.textPrimary)
            Spacer()
        }
    }

    // MARK: - Helpers

    private var hasTelegramToken: Bool {
        envKeys["TG_BOT_TOKEN"] != nil || envKeys["TELEGRAM_BOT_TOKEN"] != nil
    }

    private var hasGitHubToken: Bool {
        envKeys["GITHUB_TOKEN"] != nil || envKeys["AGENT_GH_TOKEN"] != nil || envKeys["GH_TOKEN"] != nil
    }

    private var hasRailwayToken: Bool {
        envKeys["RAILWAY_TOKEN"] != nil || envKeys["RAILWAY_API_TOKEN"] != nil
    }

    private func sourceIcon(_ event: AgentEvent) -> String {
        switch event.agent?.lowercased() {
        case "queen": return "\u{1F451}"
        case "ralph": return "\u{1F916}"
        case "scholar": return "\u{1F4DA}"
        case "mu": return "\u{1F9E0}"
        default:
            switch event.resolvedKind {
            case "cli", "mcp": return "\u{2699}"
            case "diff": return "\u{1F4DD}"
            default: return "\u{2022}"
            }
        }
    }

    private func formatTime(_ ts: Int) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        return fmt.string(from: date)
    }

    private func formatTs(_ value: Int?) -> String {
        guard let v = value, v > 0 else { return "—" }
        return "\(v)"
    }

    private func loadData() {
        watcher.reload()
        envKeys = EnvLoader.load()
        events = Array(watcher.eventStream.suffix(20))
    }
}
