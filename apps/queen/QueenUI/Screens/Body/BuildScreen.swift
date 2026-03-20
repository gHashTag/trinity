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
            VStack(spacing: ParietalSpacing.standard) {
                // Header
                HStack {
                    Text("🔨")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("BUILD STATUS")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("6 binaries from one build.zig")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()

                    ActionButton(icon: "🔨", label: "Rebuild", color: buildOk ? V4Color.accent : V4Color.statusError,
                                 action: "build")

                    MetricGauge(
                        label: "Build",
                        value: buildOk ? 100 : 0,
                        maxValue: 100,
                        accent: buildOk ? V4Color.statusOK : V4Color.statusError
                    )
                }
                .padding()

                // Summary
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                    StatCard(label: "Language", value: "Zig 0.15.x")
                    StatCard(label: "Dependencies", value: "0 external", accent: V4Color.golden)
                    StatCard(label: "Build System", value: "build.zig", accent: V4Color.purple)
                    StatCard(label: "Status", value: buildOk ? "OK" : "BROKEN",
                             accent: buildOk ? V4Color.statusOK : V4Color.statusError)
                }
                .padding(.horizontal)

                // Binary list
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("BINARIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)
                        .padding(.horizontal)

                    ForEach(binaries, id: \.0) { name, description, path in
                        let mtime = binaryMtime(path)
                        HStack(spacing: ParietalSpacing.md) {
                            Text("⚡")
                                .font(.title2)

                            VStack(alignment: .leading, spacing: 2) {
                                Text(name)
                                    .font(.headline.monospaced())
                                    .foregroundStyle(V4Color.textPrimary)
                                Text(description)
                                    .font(.caption)
                                    .foregroundStyle(V4Color.textSecondary)
                            }

                            Spacer()

                            if let mtime {
                                Text(mtime)
                                    .font(.caption2.monospacedDigit())
                                    .foregroundStyle(V4Color.textSecondary)
                            }

                            StatusBadge(status: mtime != nil ? .up : .down)
                        }
                        .padding()
                        .background(V4Color.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                        .padding(.horizontal)
                    }
                }

                // Libraries
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("LIBRARIES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.golden)
                        .padding(.horizontal)

                    ForEach([
                        ("libtrinity-vsa", "C API — VSA operations (shared + static)"),
                        ("libtrinity-queen", "C API — Queen dashboard data (shared + static)"),
                    ], id: \.0) { name, desc in
                        HStack(spacing: ParietalSpacing.md) {
                            Text("📦")
                            VStack(alignment: .leading) {
                                Text(name)
                                    .font(.headline.monospaced())
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
                        .padding(.horizontal)
                    }
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
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
