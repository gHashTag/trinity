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
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(WernickeTypography.microBold)
                        .foregroundStyle(V4Color.textSecondary)
                    Text("CONTEXT")
                        .font(WernickeTypography.miniBoldMono)
                        .foregroundStyle(V4Color.accent)
                    Spacer()
                    if !trinityCtx.attachedFiles.isEmpty {
                        Text("\(trinityCtx.attachedFiles.count)")
                            .font(WernickeTypography.microBoldMono)
                            .foregroundStyle(.black)
                            .padding(.horizontal, 5)
                            .padding(.vertical, 1)
                            .background(V4Color.accent)
                            .clipShape(SwiftUI.Capsule())
                    }
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().background(Color.white.opacity(V2Depth.bgCard))

                ScrollView {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm + 2) {
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
                    .padding(.horizontal, ParietalSpacing.md)
                    .padding(.vertical, ParietalSpacing.sm)
                }
            }
        }
        .background(V4Color.background)
        .onAppear {
            trinityCtx.refresh()
            loadCommits()
        }
    }

    // MARK: - Build Status

    private var buildStatusRow: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            Circle()
                .fill(buildColor)
                .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)
            Text("Build")
                .font(WernickeTypography.miniMedium)
                .foregroundStyle(Color.white.opacity(V1Theme.opacityTextSecondary))
            Spacer()
            Text(buildLabel)
                .font(WernickeTypography.miniBoldMono)
                .foregroundStyle(buildColor)
        }
    }

    private var buildColor: Color {
        switch trinityCtx.buildOK {
        case true: return V4Color.success
        case false: return V4Color.error
        default: return V4Color.textSecondary
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
        HStack(spacing: ParietalSpacing.md) {
            if let score = trinityCtx.ouroborosScore {
                miniMetric(String(format: "%.0f", score), "Score", V4Color.golden)
            }
            if let ppl = trinityCtx.bestPPL {
                miniMetric(String(format: "%.1f", ppl), "PPL", V4Color.accent)
            }
            if let issues = trinityCtx.openIssues {
                miniMetric("\(issues)", "Issues", V4Color.purple)
            }
            if let dirty = trinityCtx.dirtyFiles {
                miniMetric("\(dirty)", "Dirty", dirty > 30 ? V4Color.warning : V4Color.textSecondary)
            }
            Spacer()
        }
    }

    private func miniMetric(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(spacing: ParietalSpacing.xxxxs) {
            Text(value)
                .font(WernickeTypography.caption2BoldMono)
                .foregroundStyle(color)
            Text(label)
                .font(WernickeTypography.size8)
                .foregroundStyle(Color.white.opacity(V2Depth.stateHover))
        }
    }

    // MARK: - Attached Files

    private var attachedFilesSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Text("ATTACHED FILES")
                .font(WernickeTypography.microBold)
                .foregroundStyle(Color.white.opacity(V2Depth.stateHover))

            ForEach(trinityCtx.attachedFiles.suffix(8)) { file in
                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: fileIcon(file.path))
                        .font(WernickeTypography.size9)
                        .foregroundStyle(V4Color.accent.opacity(0.7))
                    Text(shortenPath(file.path))
                        .font(WernickeTypography.size10Mono)
                        .foregroundStyle(Color.white.opacity(V2Depth.stateDisabled))
                        .lineLimit(1)
                    Spacer()
                    Text("\(file.sizeKB)KB")
                        .font(WernickeTypography.size9Mono)
                        .foregroundStyle(V4Color.white20)
                }
            }
        }
    }

    // MARK: - Commits

    private var commitsSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Text("RECENT COMMITS")
                .font(WernickeTypography.microBold)
                .foregroundStyle(Color.white.opacity(V2Depth.stateHover))

            ForEach(recentCommits.prefix(5), id: \.self) { commit in
                Text(commit)
                    .font(WernickeTypography.size10Mono)
                    .foregroundStyle(Color.white.opacity(V1Theme.opacityTextTertiary))
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
