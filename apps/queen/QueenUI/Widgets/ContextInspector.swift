import SwiftUI

/// Shows what files/context Queen has read for the current conversation.
/// Displays: attached files, build status, recent commits, open issues count.
struct ContextInspector: View {
    @StateObject private var trinityCtx = TrinityContext.shared
    @State private var recentCommits: [String] = []
    @State private var isExpanded = true

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            Button {
                withAnimation(.easeInOut(duration: 0.15)) { isExpanded.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(TrinityTheme.textMuted)
                    Text("CONTEXT")
                        .font(.system(size: 10, weight: .bold, design: .monospaced))
                        .foregroundStyle(TrinityTheme.accent)
                    Spacer()
                    if !trinityCtx.attachedFiles.isEmpty {
                        Text("\(trinityCtx.attachedFiles.count)")
                            .font(.system(size: 9, weight: .bold, design: .monospaced))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(TrinityTheme.accent)
                            .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(Color.white.opacity(0.06))

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        // Build status
                        buildStatusRow

                        // Score + Farm
                        liveMetricsRow

                        // Attached files
                        if !trinityCtx.attachedFiles.isEmpty {
                            attachedFilesSection
                        }

                        // Recent commits
                        if !recentCommits.isEmpty {
                            commitsSection
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                }
            }
        }
        .background(Color(hex: 0x0A0A0A))
        .onAppear {
            trinityCtx.refresh()
            loadCommits()
        }
    }

    // MARK: - Build Status

    private var buildStatusRow: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(buildColor)
                .frame(width: 8, height: 8)
            Text("Build")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.6))
            Spacer()
            Text(buildLabel)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(buildColor)
        }
    }

    private var buildColor: Color {
        switch trinityCtx.buildOK {
        case true: return TrinityTheme.statusOK
        case false: return TrinityTheme.statusError
        default: return TrinityTheme.textMuted
        }
    }

    private var buildLabel: String {
        switch trinityCtx.buildOK {
        case true: return "PASSING"
        case false: return "BROKEN"
        default: return "UNKNOWN"
        }
    }

    // MARK: - Live Metrics

    private var liveMetricsRow: some View {
        HStack(spacing: 12) {
            if let score = trinityCtx.ouroborosScore {
                miniMetric(String(format: "%.0f", score), "Score", TrinityTheme.golden)
            }
            if let ppl = trinityCtx.bestPPL {
                miniMetric(String(format: "%.1f", ppl), "PPL", TrinityTheme.accent)
            }
            if let issues = trinityCtx.openIssues {
                miniMetric("\(issues)", "Issues", TrinityTheme.purple)
            }
            if let dirty = trinityCtx.dirtyFiles {
                miniMetric("\(dirty)", "Dirty", dirty > 30 ? TrinityTheme.statusWarn : TrinityTheme.textMuted)
            }
            Spacer()
        }
    }

    private func miniMetric(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: 1) {
            Text(value)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
            Text(label)
                .font(.system(size: 8))
                .foregroundStyle(Color.white.opacity(0.3))
        }
    }

    // MARK: - Attached Files

    private var attachedFilesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("ATTACHED FILES")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.3))

            ForEach(trinityCtx.attachedFiles.suffix(8)) { file in
                HStack(spacing: 4) {
                    Image(systemName: fileIcon(file.path))
                        .font(.system(size: 9))
                        .foregroundStyle(TrinityTheme.accent.opacity(0.7))
                    Text(shortenPath(file.path))
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.5))
                        .lineLimit(1)
                    Spacer()
                    Text("\(file.sizeKB)KB")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(Color.white.opacity(0.2))
                }
            }
        }
    }

    // MARK: - Commits

    private var commitsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("RECENT COMMITS")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.3))

            ForEach(recentCommits.prefix(5), id: \.self) { commit in
                Text(commit)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Helpers

    private func loadCommits() {
        Task {
            let pipe = Pipe()
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["log", "--oneline", "-5"]
            process.standardOutput = pipe
            process.standardError = FileHandle.nullDevice
            do {
                try process.run()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else {
                    await MainActor.run { recentCommits = ["(git exited with \(process.terminationStatus))"] }
                    return
                }
                let output = String(data: data, encoding: .utf8) ?? ""
                await MainActor.run {
                    recentCommits = output.components(separatedBy: "\n").filter { !$0.isEmpty }
                    if recentCommits.isEmpty { recentCommits = ["(no commits)"] }
                }
            } catch {
                await MainActor.run { recentCommits = ["(git not available)"] }
            }
        }
    }

    private func fileIcon(_ path: String) -> String {
        if path.hasSuffix(".zig") { return "chevron.left.forwardslash.chevron.right" }
        if path.hasSuffix(".swift") { return "swift" }
        if path.hasSuffix(".md") { return "doc.text" }
        if path.hasSuffix(".json") { return "curlybraces" }
        return "doc"
    }

    private func shortenPath(_ path: String) -> String {
        let components = path.components(separatedBy: "/")
        if components.count <= 3 { return path }
        return ".../" + components.suffix(3).joined(separator: "/")
    }
}
