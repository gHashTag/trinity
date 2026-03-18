import SwiftUI

struct SwarmScreen: View {
    @EnvironmentObject var watcher: StateWatcher
    @State private var cells: [CellInfo] = []
    @State private var selectedCell: CellInfo?
    @State private var taskInput = ""

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                // Header
                HStack {
                    Text("\u{1F41D}")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("HONEYCOMB")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("Cell Ecosystem Browser")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    StatCard(label: "Cells", value: "\(cells.count)")
                        .frame(width: 80)
                    ActionButton(icon: "+", label: "New Cell", color: TrinityTheme.accent,
                                 action: "cell_create")
                }
                .padding()

                // Cell Grid
                cellGridSection

                // Selected cell detail
                if let sel = selectedCell {
                    cellDetailCard(sel)
                        .padding(.horizontal)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }

                // Agent Pool
                agentPoolSection

                // Task Decomposer
                taskDecomposerSection

                // Stats bar
                statsBar
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
        .onAppear { loadCells() }
    }

    // MARK: - Cell Grid

    private var cellGridSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("CELL REGISTRY")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.golden)
                .padding(.horizontal)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 8), count: 3)
            LazyVGrid(columns: columns, spacing: 8) {
                ForEach(cells) { cell in
                    cellCard(cell)
                }
            }
            .padding(.horizontal)
        }
    }

    private func cellCard(_ cell: CellInfo) -> some View {
        let isSelected = selectedCell?.id == cell.id

        return Button {
            withAnimation(.easeInOut(duration: 0.15)) {
                selectedCell = isSelected ? nil : cell
            }
        } label: {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(cell.emoji)
                        .font(.title2)
                    Spacer()
                    AgentStatusDot(status: cell.agentStatus)
                }

                Text(cell.name)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .lineLimit(1)

                Text(cell.description)
                    .font(.system(size: 9))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .lineLimit(2)

                if !cell.tags.isEmpty {
                    HStack(spacing: 3) {
                        ForEach(cell.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(TrinityTheme.accent)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(TrinityTheme.accent.opacity(0.1))
                                .clipShape(SwiftUI.Capsule())
                        }
                    }
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(TrinityTheme.bgCard)
            .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cardCorner)
                    .stroke(isSelected ? TrinityTheme.accent : TrinityTheme.bgCardBorder, lineWidth: isSelected ? 2 : 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func cellDetailCard(_ cell: CellInfo) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(cell.emoji)
                    .font(.largeTitle)
                VStack(alignment: .leading) {
                    Text(cell.name)
                        .font(.headline)
                        .foregroundStyle(TrinityTheme.textPrimary)
                    Text(cell.status.uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(cell.agentStatus.color)
                }
                Spacer()
                Button {
                    withAnimation { selectedCell = nil }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }

            Text(cell.description)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)

            // Tags
            HStack(spacing: 4) {
                ForEach(cell.tags, id: \.self) { tag in
                    Text(tag)
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(TrinityTheme.accent)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(TrinityTheme.accent.opacity(0.1))
                        .clipShape(SwiftUI.Capsule())
                }
            }

            // File path
            HStack(spacing: 4) {
                Text("Path:")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
                Text(cell.path)
                    .font(.caption2.monospaced())
                    .foregroundStyle(TrinityTheme.purple)
            }

            // Dependencies
            if !cell.dependencies.isEmpty {
                HStack(spacing: 4) {
                    Text("Deps:")
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                    Text(cell.dependencies.joined(separator: ", "))
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textPrimary)
                }
            }
        }
        .padding()
        .background(TrinityTheme.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cardCorner)
                .stroke(TrinityTheme.accent.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Agent Pool

    private var agentPoolSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("AGENT POOL")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.purple)
                .padding(.horizontal)

            let agents: [(name: String, emoji: String, role: String, caps: String)] = [
                ("Ralph", "\u{1F916}", "Implementation", "code, git, deploy"),
                ("Scholar", "\u{1F4DA}", "Research", "search, papers, analysis"),
                ("MU", "\u{1F9E0}", "Memory", "patterns, learning, recall"),
                ("Linter", "\u{1F50D}", "Quality", "lint, format, review"),
                ("Oracle", "\u{1F52E}", "Watchdog", "monitor, alert, heal"),
                ("Swarm", "\u{1F41D}", "Coordination", "decompose, assign, track"),
            ]

            ForEach(agents, id: \.name) { agent in
                let beat = watcher.heartbeats.first { $0.displayName.lowercased() == agent.name.lowercased() }
                let isUp = beat != nil

                HStack(spacing: 12) {
                    Text(agent.emoji)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(agent.name.uppercased())
                            .font(.headline)
                            .foregroundStyle(TrinityTheme.textPrimary)
                        Text(agent.role)
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(TrinityTheme.purple)
                        Text(agent.caps)
                            .font(.caption2)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }

                    Spacer()

                    if let beat {
                        Text("Wake #\(beat.wake ?? 0)")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(TrinityTheme.textMuted)
                    }

                    AgentStatusDot(status: isUp ? .up : .stub)
                    StatusBadge(status: isUp ? .up : .stub)
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
    }

    // MARK: - Task Decomposer

    private var taskDecomposerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("TASK DECOMPOSER")
                .font(.caption.weight(.bold))
                .foregroundStyle(TrinityTheme.accent)
                .padding(.horizontal)

            HStack(spacing: 8) {
                TextField("Describe task...", text: $taskInput)
                    .font(.caption.monospaced())
                    .textFieldStyle(.plain)
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .padding(8)
                    .background(TrinityTheme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .onSubmit { submitTask() }

                ActionButton(icon: "\u{1F41D}", label: "Decompose", color: TrinityTheme.accent,
                             action: "swarm_decompose", params: ["task": taskInput])
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Stats Bar

    private var statsBar: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            StatCard(
                label: "Total Cells",
                value: "\(cells.count)",
                accent: TrinityTheme.accent
            )
            StatCard(
                label: "Active Agents",
                value: "\(watcher.heartbeats.count)",
                accent: TrinityTheme.purple
            )
            StatCard(
                label: "Completed",
                value: "\(watcher.swarmState?.completed_tasks ?? 0)",
                accent: TrinityTheme.golden
            )
        }
        .padding(.horizontal)
    }

    // MARK: - Data Loading

    private func loadCells() {
        watcher.reload()
        cells = scanCellTriFiles()
    }

    private func submitTask() {
        let task = taskInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !task.isEmpty else { return }
        ActionQueue.shared.enqueue("swarm_decompose", params: ["task": task])
        taskInput = ""
    }

    /// Scan src/*/cell.tri files to discover honeycomb cells
    private func scanCellTriFiles() -> [CellInfo] {
        let cwd = FileManager.default.currentDirectoryPath
        let srcDir = "\(cwd)/src"
        let fm = FileManager.default

        guard let modules = try? fm.contentsOfDirectory(atPath: srcDir) else { return [] }

        var found: [CellInfo] = []
        for module in modules.sorted() {
            let cellPath = "\(srcDir)/\(module)/cell.tri"
            guard fm.fileExists(atPath: cellPath) else { continue }
            let info = parseCellTri(path: cellPath, module: module)
            found.append(info)
        }

        // Also check top-level tool cells
        let toolsDir = "\(cwd)/tools/mcp/trinity_mcp"
        let toolCell = "\(toolsDir)/cell.tri"
        if fm.fileExists(atPath: toolCell) {
            found.append(parseCellTri(path: toolCell, module: "trinity-mcp"))
        }

        // Check fpga cell
        let fpgaCell = "\(cwd)/fpga/openxc7-synth/cell.tri"
        if fm.fileExists(atPath: fpgaCell) {
            found.append(parseCellTri(path: fpgaCell, module: "fpga-synth"))
        }

        return found
    }

    private func parseCellTri(path: String, module: String) -> CellInfo {
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return CellInfo(name: module, emoji: "\u{1F4E6}", description: "Cell module",
                            status: "stub", tags: [], dependencies: [], path: path)
        }

        var name = module
        var emoji = "\u{1F4E6}"
        var desc = "Cell module"
        var status = "active"
        var tags: [String] = []
        var deps: [String] = []

        for line in content.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("name:") {
                name = trimmed.replacingOccurrences(of: "name:", with: "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
            } else if trimmed.hasPrefix("emoji:") {
                emoji = trimmed.replacingOccurrences(of: "emoji:", with: "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
            } else if trimmed.hasPrefix("description:") || trimmed.hasPrefix("desc:") {
                desc = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
            } else if trimmed.hasPrefix("status:") {
                status = trimmed.replacingOccurrences(of: "status:", with: "").trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "")
            } else if trimmed.hasPrefix("tags:") {
                let tagStr = trimmed.replacingOccurrences(of: "tags:", with: "").trimmingCharacters(in: .whitespaces)
                tags = tagStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "") }.filter { !$0.isEmpty }
            } else if trimmed.hasPrefix("depends:") || trimmed.hasPrefix("deps:") {
                let depStr = trimmed.components(separatedBy: ":").dropFirst().joined(separator: ":").trimmingCharacters(in: .whitespaces)
                deps = depStr.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "\"", with: "") }.filter { !$0.isEmpty }
            }
        }

        return CellInfo(name: name, emoji: emoji, description: desc,
                        status: status, tags: tags, dependencies: deps, path: path)
    }
}

// MARK: - CellInfo Model

struct CellInfo: Identifiable {
    let name: String
    let emoji: String
    let description: String
    let status: String
    let tags: [String]
    let dependencies: [String]
    let path: String

    var id: String { name }

    var agentStatus: AgentRow.AgentStatus {
        switch status.lowercased() {
        case "active", "running": return .up
        case "planned", "stub": return .stub
        default: return .down
        }
    }
}
