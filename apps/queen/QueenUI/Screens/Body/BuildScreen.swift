import SwiftUI

struct BuildScreen: View {
    @EnvironmentObject var watcher: StateWatcher

    private let binaries: [(String, String, String)] = [
        ("trinity-mcp", "MCP server, 47+ tools, Oracle watchdog", "zig-out/bin/trinity-mcp"),
        ("ralph-agent", "Sleep-wake daemon, picks GitHub issues", "zig-out/bin/ralph-agent"),
        ("ralph-hook", "Hook events → Telegram notifications", "zig-out/bin/ralph-hook"),
        ("tri-bot", "Telegram bot, SSE streaming to Anthropic API", "zig-out/bin/tri-bot"),
        ("tri-api", "Standalone agentic loop (2,555 LOC, 11 files)", "zig-out/bin/tri-api"),
        ("hslm-entrypoint", "Railway training entrypoint", "zig-out/bin/hslm-entrypoint"),
    ]

    private var buildOk: Bool {
        watcher.queenSenses?.build_ok ?? false
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                // Header
                HStack {
                    Text("🔨")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("BUILD STATUS")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("6 binaries from one build.zig")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()

                    ActionButton(icon: "🔨", label: "Rebuild", color: buildOk ? TrinityTheme.accent : TrinityTheme.statusError,
                                 action: "build")

                    MetricGauge(
                        label: "Build",
                        value: buildOk ? 100 : 0,
                        maxValue: 100,
                        accent: buildOk ? TrinityTheme.statusOK : TrinityTheme.statusError
                    )
                }
                .padding()

                // Summary
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(label: "Language", value: "Zig 0.15.x")
                    StatCard(label: "Dependencies", value: "0 external", accent: TrinityTheme.golden)
                    StatCard(label: "Build System", value: "build.zig", accent: TrinityTheme.purple)
                    StatCard(label: "Status", value: buildOk ? "OK" : "BROKEN",
                             accent: buildOk ? TrinityTheme.statusOK : TrinityTheme.statusError)
                }
                .padding(.horizontal)

                // Binary list
                VStack(alignment: .leading, spacing: 8) {
                    Text("BINARIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)
                        .padding(.horizontal)

                    ForEach(binaries, id: \.0) { name, description, path in
                        let mtime = binaryMtime(path)
                        HStack(spacing: 12) {
                            Text("⚡")
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.headline.monospaced())
                                    .foregroundStyle(TrinityTheme.textPrimary)
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(TrinityTheme.textMuted)
                            }

                            Spacer()

                            if let mtime {
                                Text(mtime)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(TrinityTheme.textMuted)
                            }

                            StatusBadge(status: mtime != nil ? .up : .down)
                        }
                        .padding()
                        .background(TrinityTheme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                        .padding(.horizontal)
                    }
                }

                // Libraries
                VStack(alignment: .leading, spacing: 8) {
                    Text("LIBRARIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.golden)
                        .padding(.horizontal)

                    ForEach([
                        ("libtrinity-vsa", "C API — VSA operations (shared + static)"),
                        ("libtrinity-queen", "C API — Queen dashboard data (shared + static)"),
                    ], id: \.0) { name, desc in
                        HStack(spacing: 12) {
                            Text("📦")
                            VStack(alignment: .leading) {
                                Text(name)
                                    .font(.headline.monospaced())
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
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
    }

    private func binaryMtime(_ relativePath: String) -> String? {
        let cwd = FileManager.default.currentDirectoryPath
        let fullPath = "\(cwd)/\(relativePath)"
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: fullPath),
              let date = attrs[.modificationDate] as? Date else { return nil }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
