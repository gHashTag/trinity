import SwiftUI

struct TelegramScreen: View {
    @EnvironmentObject var watcher: StateWatcher

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("\u{1F4AC}")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("TELEGRAM")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("Bot & Notification Pipeline")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: ParietalSpacing.sm) {
                        ActionButton(icon: "📨", label: "Send Test", color: V4Color.accent,
                                     action: "telegram_test")
                        ActionButton(icon: "🤖", label: "Check Bot", color: V4Color.golden,
                                     action: "telegram_check")
                    }
                }
                .padding()

                // Queen Daemon card
                daemonCard

                // Bot info
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("TRI-BOT")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.golden)

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                        StatCard(label: "Binary", value: "tri-bot")
                        StatCard(label: "API", value: "SSE Streaming", accent: V4Color.purple)
                        StatCard(label: "Backend", value: "Anthropic API", accent: V4Color.golden)
                        StatCard(label: "Keyboard", value: "ReplyKeyboard", accent: V4Color.accent)
                    }
                }
                .padding(.horizontal)

                // Incident History
                incidentHistory

                // Notification hooks
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("NOTIFICATION HOOKS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)

                    ForEach([
                        ("Stop", "macOS notification + Telegram alert"),
                        ("PostToolUse (.zig)", "Auto zig fmt"),
                        ("PostToolUse (Bash/Edit/Write)", "ralph-hook \u{2192} Telegram"),
                        ("PreToolUse (Write/Edit)", "Block editing generated/ output/"),
                    ], id: \.0) { hook, desc in
                        HStack(spacing: ParietalSpacing.md) {
                            Text("\u{26A1}")
                            VStack(alignment: .leading) {
                                Text(hook)
                                    .font(.body.weight(.medium))
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

                // Rules
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("RULES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.statusError)

                    HStack {
                        Text("\u{1F6AB}")
                        Text("FORBIDDEN: InlineKeyboardMarkup")
                            .font(.body.weight(.medium))
                            .foregroundStyle(V4Color.statusError)
                    }
                    HStack {
                        Text("\u{2705}")
                        Text("ONLY: ReplyKeyboardMarkup")
                            .font(.body.weight(.medium))
                            .foregroundStyle(V4Color.statusOK)
                    }
                    HStack {
                        Text("\u{1F6AB}")
                        Text("No [emoji mood] signature in messages")
                            .font(.body.weight(.medium))
                            .foregroundStyle(V4Color.statusError)
                    }
                    HStack {
                        Text("\u{1F6AB}")
                        Text("No duplicate notifications (dedup by PPL/step)")
                            .font(.body.weight(.medium))
                            .foregroundStyle(V4Color.statusError)
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

    // MARK: - Daemon Card

    private var daemonCard: some View {
        let state = watcher.queenState
        let running = state?.isRunning ?? false

        return VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text("QUEEN DAEMON")
                .font(.caption.weight(.bold))
                .foregroundStyle(V4Color.golden)

            HStack(spacing: ParietalSpacing.md) {
                Circle()
                    .fill(running ? V4Color.statusOK : V4Color.statusError)
                    .frame(width: ParietalSpacing.mediumBadge, height: ParietalSpacing.badgeHeight)
                Text(running ? "RUNNING" : "STOPPED")
                    .font(.body.weight(.bold))
                    .foregroundStyle(running ? V4Color.statusOK : V4Color.statusError)

                Spacer()

                if let cycle = state?.cycle {
                    Text("Cycle #\(cycle)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            if let state = state {
                Text("Uptime: \(state.uptimeFormatted)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .padding(.horizontal)
    }

    // MARK: - Incident History

    private var incidentHistory: some View {
        let entries = Array(watcher.auditEntries.suffix(20).reversed())

        return VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text("INCIDENT HISTORY")
                .font(.caption.weight(.bold))
                .foregroundStyle(V4Color.purple)

            if entries.isEmpty {
                Text("No incidents recorded")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            } else {
                ForEach(entries) { entry in
                    HStack(spacing: ParietalSpacing.sm) {
                        Text(entry.icon)
                            .font(.caption)
                        Text(entry.action ?? "unknown")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(V4Color.textPrimary)
                        Spacer()
                        if let success = entry.success {
                            Text(success ? "\u{2705}" : "\u{274C}")
                                .font(.caption)
                        }
                        if let ts = entry.ts {
                            Text(timeAgo(ts))
                                .font(.caption2.monospacedDigit())
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
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
