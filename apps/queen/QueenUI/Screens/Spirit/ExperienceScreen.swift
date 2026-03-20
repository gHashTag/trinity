import SwiftUI

struct ExperienceScreen: View {
    @State private var episodes: [EpisodeFile] = []

    struct EpisodeFile: Identifiable {
        let name: String
        let size: Int
        let modified: Date
        var id: String { name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("💎")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("EXPERIENCE")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.purple)
                        Text("Agent Experience Episodes — FPGA & Operations")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    StatCard(label: "Episodes", value: "\(episodes.count)")
                        .frame(width: ParietalSpacing.xxLargeFrame)
                }
                .padding()

                // Protocol
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("EXPERIENCE-FIRST PROTOCOL")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.golden)

                    ForEach([
                        ("1", "Read hardware_state.json — check blockers"),
                        ("2", "Read experience.json — check if tried before"),
                        ("3", "If blocker → SKIP, log BLOCKED"),
                        ("4", "If same op FAILED before → DON'T RETRY"),
                        ("5", "After every operation → append episode"),
                        ("6", "Max 3 attempts on new failures"),
                    ], id: \.0) { step, desc in
                        HStack(spacing: ParietalSpacing.sm) {
                            Text(step)
                                .font(.caption.weight(.bold).monospacedDigit())
                                .foregroundStyle(V4Color.accent)
                                .frame(width: ParietalSpacing.buttonSmallWidth)
                            Text(desc)
                                .font(.caption)
                                .foregroundStyle(V4Color.textPrimary)
                        }
                    }
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)

                // Known anti-patterns
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("KNOWN ANTI-PATTERNS")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.statusError)

                    ForEach([
                        "openFPGALoader --cable xpc → ALWAYS FAILS",
                        "fxload -D flag → ALWAYS FAILS (use -d)",
                        "sudo without -S → ALWAYS FAILS",
                        "UART without soldered headers → NO ECHO",
                        "CPLD 0xFFFE → normal for DLC10 clones",
                    ], id: \.self) { pattern in
                        HStack(spacing: ParietalSpacing.sm) {
                            Text("🚫")
                            Text(pattern)
                                .font(.caption)
                                .foregroundStyle(V4Color.textPrimary)
                        }
                    }
                }
                .padding()
                .background(V4Color.bgCard)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                .padding(.horizontal)

                // Episode list
                if !episodes.isEmpty {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("EPISODES")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                            .padding(.horizontal)

                        ForEach(episodes) { ep in
                            HStack {
                                Text("💎")
                                Text(ep.name)
                                    .font(.caption.monospaced())
                                    .foregroundStyle(V4Color.textPrimary)
                                Spacer()
                                Text(formatDate(ep.modified))
                                    .font(.caption2)
                                    .foregroundStyle(V4Color.textSecondary)
                            }
                            .padding(.horizontal)
                        }
                    }
                } else {
                    Text("No episodes recorded yet")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                        .padding()
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .onAppear { loadEpisodes() }
    }

    private func loadEpisodes() {
        let path = "\(FileManager.default.currentDirectoryPath)/.trinity/experience/episodes"
        let fm = FileManager.default
        guard let items = try? fm.contentsOfDirectory(atPath: path) else { return }

        episodes = items.filter { $0.hasSuffix(".json") }.compactMap { name -> EpisodeFile? in
            let full = "\(path)/\(name)"
            guard let attrs = try? fm.attributesOfItem(atPath: full) else { return nil }
            return EpisodeFile(
                name: name,
                size: attrs[.size] as? Int ?? 0,
                modified: attrs[.modificationDate] as? Date ?? Date()
            )
        }.sorted { $0.modified > $1.modified }
    }

    private func formatDate(_ date: Date) -> String {
        let fmt = RelativeDateTimeFormatter()
        fmt.unitsStyle = .abbreviated
        return fmt.localizedString(for: date, relativeTo: Date())
    }
}
