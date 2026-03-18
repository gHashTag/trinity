import SwiftUI

struct GitScreen: View {
    @EnvironmentObject var watcher: StateWatcher

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                HStack {
                    Text("🌿")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("GIT")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("Repository Status")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    HStack(spacing: 8) {
                        ActionButton(icon: "💾", label: "Commit", color: TrinityTheme.accent,
                                     action: "git_commit")
                        ActionButton(icon: "🚀", label: "Push", color: TrinityTheme.golden,
                                     action: "git_push")
                    }
                }
                .padding()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    StatCard(label: "Branch", value: currentBranch)
                    StatCard(label: "Dirty Files",
                             value: "\(watcher.queenSenses?.dirty_files ?? 0)",
                             accent: (watcher.queenSenses?.dirty_files ?? 0) > 0
                                ? TrinityTheme.statusWarn : TrinityTheme.statusOK)
                    StatCard(label: "Last Push", value: lastPushAgo,
                             accent: TrinityTheme.purple)
                }
                .padding(.horizontal)

                // Branch info
                VStack(alignment: .leading, spacing: 8) {
                    Text("BRANCHES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(TrinityTheme.accent)
                        .padding(.horizontal)

                    let branches = localBranches
                    ForEach(branches, id: \.self) { branch in
                        HStack(spacing: 8) {
                            Text(branch == currentBranch ? "●" : "○")
                                .font(.caption2)
                                .foregroundStyle(branch == currentBranch
                                    ? TrinityTheme.accent : TrinityTheme.textMuted)
                            Text(branch)
                                .font(.caption.monospaced())
                                .foregroundStyle(TrinityTheme.textPrimary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                    }

                    if branches.isEmpty {
                        Text("No branch info available")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                            .padding(.horizontal)
                    }
                }

                // Senses summary
                if let senses = watcher.queenSenses {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("REPOSITORY HEALTH")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TrinityTheme.golden)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            StatCard(label: "Open Issues", value: "\(senses.open_issues ?? 0)")
                            StatCard(label: "Build", value: (senses.build_ok ?? false) ? "OK" : "BROKEN",
                                     accent: (senses.build_ok ?? false) ? TrinityTheme.statusOK : TrinityTheme.statusError)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
    }

    private var currentBranch: String {
        let cwd = FileManager.default.currentDirectoryPath
        let headPath = "\(cwd)/.git/HEAD"
        guard let content = try? String(contentsOfFile: headPath, encoding: .utf8).trimmingCharacters(in: .whitespacesAndNewlines) else {
            return "main"
        }
        // "ref: refs/heads/main" → "main"
        if content.hasPrefix("ref: refs/heads/") {
            return String(content.dropFirst("ref: refs/heads/".count))
        }
        // Detached HEAD — show short hash
        return String(content.prefix(8))
    }

    private var localBranches: [String] {
        let cwd = FileManager.default.currentDirectoryPath
        let refsPath = "\(cwd)/.git/refs/heads"
        guard let entries = try? FileManager.default.contentsOfDirectory(atPath: refsPath) else {
            return []
        }
        return entries.sorted()
    }

    private var lastPushAgo: String {
        guard let ts = watcher.queenSenses?.last_git_push_ts, ts > 0 else { return "—" }
        let pushDate = Date(timeIntervalSince1970: TimeInterval(ts))
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: pushDate, relativeTo: Date())
    }
}
