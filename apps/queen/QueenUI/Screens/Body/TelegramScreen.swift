import SwiftUI

struct TelegramScreen: View {
    @EnvironmentObject var watcher: StateWatcher

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                HStack {
                    Text("\u{1F4AC}")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("TELEGRAM")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("Bot & Notification Pipeline")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        ActionButton(icon: "📨", label: "Send Test", color: TrinityTheme.accent,
                                     action: "telegram_test")
                        ActionButton(icon: "🤖", label: "Check Bot", color: TrinityTheme.golden,
                                     action: "telegram_check")
                    }
                }
                .padding()

                // Queen Daemon card
                daemonCard

                // Bot info
                VStack(alignment: .leading, spacing: 12) {
                    Text("TRI-BOT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.golden)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(label: "Binary", value: "tri-bot")
                        StatCard(label: "API", value: "SSE Streaming", accent: TrinityTheme.purple)
                        StatCard(label: "Backend", value: "Anthropic API", accent: TrinityTheme.golden)
                        StatCard(label: "Keyboard", value: "ReplyKeyboard", accent: TrinityTheme.accent)
                    }
                }
                .padding(.horizontal)

                // Incident History
                incidentHistory

                // Notification hooks
                VStack(alignment: .leading, spacing: 12) {
                    Text("NOTIFICATION HOOKS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)

                    ForEach([
                        ("Stop", "macOS notification + Telegram alert"),
                        ("PostToolUse (.zig)", "Auto zig fmt"),
                        ("PostToolUse (Bash/Edit/Write)", "ralph-hook \u{2192} Telegram"),
                        ("PreToolUse (Write/Edit)", "Block editing generated/ output/"),
                    ], id: \.0) { hook, desc in
                        HStack(spacing: 12) {
                            Text("\u{26A1}")
                            VStack(alignment: .leading) {
                                Text(hook)
                                    .font(.body.weight(.medium))
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

                // Rules
                VStack(alignment: .leading, spacing: 8) {
                    Text("RULES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.statusError)

                    HStack {
                        Text("\u{1F6AB}")
                        Text("FORBIDDEN: InlineKeyboardMarkup")
                            .font(.body.weight(.medium))
                            .foregroundStyle(TrinityTheme.statusError)
                    }
                    HStack {
                        Text("\u{2705}")
                        Text("ONLY: ReplyKeyboardMarkup")
                            .font(.body.weight(.medium))
                            .foregroundStyle(TrinityTheme.statusOK)
                    }
                    HStack {
                        Text("\u{1F6AB}")
                        Text("No [emoji mood] signature in messages")
                            .font(.body.weight(.medium))
                            .foregroundStyle(TrinityTheme.statusError)
                    }
                    HStack {
                        Text("\u{1F6AB}")
                        Text("No duplicate notifications (dedup by PPL/step)")
                            .font(.body.weight(.medium))
                            .foregroundStyle(TrinityTheme.statusError)
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

    // MARK: - Daemon Card

    private var daemonCard: some View {
        let state = watcher.queenState
        let running = state?.isRunning ?? false

        return VStack(alignment: .leading, spacing: 8) {
            Text("QUEEN DAEMON")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.golden)

            HStack(spacing: 12) {
                Circle()
                    .fill(running ? TrinityTheme.statusOK : TrinityTheme.statusError)
                    .frame(width: 12, height: 12)
                Text(running ? "RUNNING" : "STOPPED")
                    .font(.body.weight(.bold))
                    .foregroundStyle(running ? TrinityTheme.statusOK : TrinityTheme.statusError)

                Spacer()

                if let cycle = state?.cycle {
                    Text("Cycle #\(cycle)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }

            if let state = state {
                Text("Uptime: \(state.uptimeFormatted)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(TrinityTheme.textMuted)
            }
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
        .padding(.horizontal)
    }

    // MARK: - Incident History

    private var incidentHistory: some View {
        let entries = Array(watcher.auditEntries.suffix(20).reversed())

        return VStack(alignment: .leading, spacing: 8) {
            Text("INCIDENT HISTORY")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.purple)

            if entries.isEmpty {
                Text("No incidents recorded")
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
            } else {
                ForEach(entries) { entry in
                    HStack(spacing: 8) {
                        Text(entry.icon)
                            .font(.caption)
                        Text(entry.action ?? "unknown")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(TrinityTheme.textPrimary)
                        Spacer()
                        if let success = entry.success {
                            Text(success ? "\u{2705}" : "\u{274C}")
                                .font(.caption)
                        }
                        if let ts = entry.ts {
                            Text(timeAgo(ts))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
        .padding(.horizontal)
    }

    private func timeAgo(_ ts: Int) -> String {
        let secs = Int(Date().timeIntervalSince1970) - ts
        if secs < 60 { return "\(secs)s ago" }
        if secs < 3600 { return "\(secs / 60)m ago" }
        if secs < 86400 { return "\(secs / 3600)h ago" }
        return "\(secs / 86400)d ago"
    }
}
