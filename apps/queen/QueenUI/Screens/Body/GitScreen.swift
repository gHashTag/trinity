import SwiftUI

struct GitScreen: View {
    @EnvironmentObject var watcher: StateWatcher

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("🌿")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("GIT")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("Repository Status")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    HStack(spacing: ParietalSpacing.sm) {
                        ActionButton(icon: "💾", label: "Commit", color: V4Color.accent,
                                     action: "git_commit")
                        ActionButton(icon: "🚀", label: "Push", color: V4Color.golden,
                                     action: "git_push")
                    }
                }
                .padding()

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                    StatCard(label: "Branch", value: currentBranch)
                    StatCard(label: "Dirty Files",
                             value: "\(watcher.queenSenses?.dirty_files ?? 0)",
                             accent: (watcher.queenSenses?.dirty_files ?? 0) > 0
                                ? V4Color.statusWarn : V4Color.statusOK)
                    StatCard(label: "Last Push", value: lastPushAgo,
                             accent: V4Color.purple)
                }
                .padding(.horizontal)

                // Branch info
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("BRANCHES")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(V4Color.accent)
                        .padding(.horizontal)

                    let branches = localBranches
                    ForEach(branches, id: \.self) { branch in
                        HStack(spacing: ParietalSpacing.sm) {
                            Text(branch == currentBranch ? "●" : "○")
                                .font(.caption2)
                                .foregroundStyle(branch == currentBranch
                                    ? V4Color.accent : V4Color.textSecondary)
                            Text(branch)
                                .font(.caption.monospaced())
                                .foregroundStyle(V4Color.textPrimary)
                                .lineLimit(1)
                        }
                        .padding(.horizontal)
                    }

                    if branches.isEmpty {
                        Text("No branch info available")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                            .padding(.horizontal)
                    }
                }

                // Senses summary
                if let senses = watcher.queenSenses {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        Text("REPOSITORY HEALTH")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(V4Color.golden)
                            .padding(.horizontal)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                            StatCard(label: "Open Issues", value: "\(senses.open_issues ?? 0)")
                            StatCard(label: "Build", value: (senses.build_ok ?? false) ? "OK" : "BROKEN",
                                     accent: (senses.build_ok ?? false) ? V4Color.statusOK : V4Color.statusError)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
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
