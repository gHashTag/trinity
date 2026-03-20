// TriToolsChatPanel — Enhanced Tri CLI Tools for Chat Sidebar
import SwiftUI

struct TriToolsChatPanel: View {
    @State private var isExpanded = false
    @State private var selectedCategory: String? = nil
    @State private var commandOutput = ""
    @State private var isRunning = false
    @State private var lastCommand = ""
    @State private var showOutputPanel = false

    private let quickCommands: [(name: String, icon: String, cmd: String)] = [
        ("status", "arrow.triangle.branch", "status"),
        ("build", "hammer", "build"),
        ("test", "checkmark.circle", "test"),
        ("farm", "server.rack", "farm status"),
        ("doctor", "stethoscope", "doctor"),
    ]

    private let categories: [(name: String, icon: String, color: Color)] = [
        ("Core", "crown.fill", V4Color.accent),
        ("Git", "arrow.triangle.branch", V4Color.error),
        ("Farm", "server.rack", V4Color.success),
        ("Cloud", "cloud", V4Color.info),
        ("Math", "function", V4Color.purple),
        ("Bio", "dna", V4Color.success),
        ("Science", "atom", V4Color.info),
        ("Agent", "robot", V4Color.purple),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            header

            if isExpanded {
                Divider()

                // Quick actions row
                quickActionsRow

                Divider()

                // Category filter chips
                categoryFilter

                Divider()

                // Commands list with search
                commandsList

                // Output panel (shown when there's output)
                if showOutputPanel {
                    outputPanel
                }
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        Button(action: {
            withAnimation(MTMotion.quickSpring) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(WernickeTypography.size11)
                    .foregroundColor(V4Color.accent)

                Text("Tri CLI")
                    .font(WernickeTypography.caption2Semibold)
                    .foregroundColor(V4Color.textPrimary)

                Spacer()

                if !lastCommand.isEmpty {
                    Circle()
                        .fill(isRunning ? V4Color.accent : V4Color.success)
                        .frame(width: ParietalSpacing.dotSize, height: 6)
                }

                Image(systemName: "chevron.right")
                    .font(WernickeTypography.miniSemibold)
                    .foregroundColor(V4Color.textSecondary)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, ParietalSpacing.sm + 2)
            .padding(.vertical, ParietalSpacing.xs + 2)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions Row

    private var quickActionsRow: some View {
        HStack(spacing: ParietalSpacing.xs) {
            ForEach(quickCommands, id: \.name) { cmd in
                QuickActionButton(icon: cmd.icon, isRunning: isRunning && lastCommand == cmd.name) {
                    executeCommand(cmd.cmd)
                }
            }
        }
        .padding(.horizontal, ParietalSpacing.xs + 2)
        .padding(.vertical, ParietalSpacing.xs)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ParietalSpacing.xs) {
                ForEach(categories, id: \.name) { category in
                    CategoryButton(
                        name: category.name,
                        icon: category.icon,
                        color: category.color,
                        isSelected: selectedCategory == category.name
                    ) {
                        withAnimation {
                            selectedCategory = selectedCategory == category.name ? nil : category.name
                        }
                    }
                }
            }
            .padding(.horizontal, ParietalSpacing.xs + 2)
        }
        .padding(.vertical, ParietalSpacing.xs)
    }

    // MARK: - Commands List

    private var commandsList: some View {
        ScrollView {
            VStack(spacing: 2) {
                ForEach(getCommandsForCategory(selectedCategory), id: \.name) { cmd in
                    CommandButton(
                        name: cmd.name,
                        desc: cmd.desc,
                        isRunning: isRunning && lastCommand == cmd.name
                    ) {
                        executeCommand(cmd.cmd)
                    }
                }
            }
        }
    }

    // MARK: - Output Panel

    private var outputPanel: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Output")
                    .font(WernickeTypography.miniMedium)
                    .foregroundColor(V4Color.textSecondary)

                Spacer()

                Button(action: {
                    withAnimation {
                        showOutputPanel = false
                        commandOutput = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size9)
                        .foregroundColor(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
            .background(V4Color.border.opacity(V2Depth.stateHover))

            ScrollView {
                Text(commandOutput.isEmpty ? "No output yet..." : commandOutput)
                    .font(WernickeTypography.size10Mono)
                    .foregroundColor(commandOutput.isEmpty ? V4Color.textSecondary : V4Color.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(ParietalSpacing.sm)
            }
            .frame(maxHeight: 150)
            .background(V4Color.surface.opacity(V2Depth.stateDisabled))
        }
    }

    // MARK: - Command Execution

    private func executeCommand(_ cmd: String) {
        isRunning = true
        lastCommand = cmd.split(separator: " ").first.map { String($0) } ?? cmd
        commandOutput = ""

        Task {
            do {
                let triPath = "/Users/playra/trinity-w1/zig-out/bin/tri"
                guard FileManager.default.fileExists(atPath: triPath) else {
                    await MainActor.run {
                        isRunning = false
                        commandOutput = "Error: tri not found at \(triPath)"
                        showOutputPanel = true
                    }
                    return
                }

                let process = Process()
                process.executableURL = URL(fileURLWithPath: triPath)

                let parts = cmd.split(separator: " ").map { String($0) }
                process.arguments = parts

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                try process.run()

                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                process.waitUntilExit()

                await MainActor.run {
                    isRunning = false
                    let output = String(data: data, encoding: .utf8) ?? ""

                    // Parse and format output
                    if output.isEmpty {
                        commandOutput = "✓ Command completed successfully"
                    } else {
                        commandOutput = output
                    }

                    showOutputPanel = true

                    // Play sound feedback
                    if process.terminationStatus == 0 {
                        SoundCueManager.shared.playCopy()
                    } else {
                        SoundCueManager.shared.playError()
                    }
                }
            } catch {
                await MainActor.run {
                    isRunning = false
                    commandOutput = "Error: \(error.localizedDescription)"
                    showOutputPanel = true
                    SoundCueManager.shared.playError()
                }
            }
        }
    }

    private func getCommandsForCategory(_ category: String?) -> [(name: String, cmd: String, desc: String)] {
        if let cat = category {
            switch cat {
            case "Core":
                return [
                    ("status", "status", "Git status --short"),
                    ("build", "build", "Build project"),
                    ("test", "test", "Run tests"),
                    ("clean", "clean", "Clean build"),
                    ("verify", "verify", "Run verification")
                ]
            case "Git":
                return [
                    ("status", "status", "Git status"),
                    ("diff", "diff", "Git diff"),
                    ("log", "log", "Git log --oneline"),
                    ("commit", "commit", "Git commit (prompt)"),
                    ("push", "git push", "Push to remote")
                ]
            case "Farm":
                return [
                    ("status", "farm status", "Farm status summary"),
                    ("list", "farm list", "List all services"),
                    ("recycle", "farm recycle", "Recycle farm"),
                    ("notify", "farm notify", "Send notification")
                ]
            case "Cloud":
                return [
                    ("status", "cloud status", "Cloud dashboard"),
                    ("agents", "cloud agents", "List agents"),
                    ("spawn", "cloud spawn", "Spawn container"),
                    ("kill", "cloud kill", "Kill container")
                ]
            case "Math":
                return [
                    ("constants", "constants", "Sacred constants φ, π, e"),
                    ("phi", "phi 10", "φ¹⁰ (golden ratio power)"),
                    ("fib", "fib 50", "Fibonacci F(50)"),
                    ("lucas", "lucas 10", "Lucas L(10)"),
                    ("spiral", "spiral 5", "φ-spiral coordinates")
                ]
            case "Bio":
                return [
                    ("dna", "bio dna ACGT", "Analyze DNA sequence"),
                    ("codon", "bio codon AUG", "RNA codon lookup"),
                    ("protein", "bio protein", "Protein analyze"),
                    ("mass", "chem mass H2O", "Molar mass")
                ]
            case "Science":
                return [
                    ("periodic", "chem periodic all", "Periodic table"),
                    ("element Au", "chem element Au", "Gold element"),
                    ("quantum", "quantum constants", "h, ħ, α"),
                    ("bell states", "bell states", "4 Bell states")
                ]
            case "Agent":
                return [
                    ("list", "agent list", "List agents"),
                    ("run", "agent run", "Run agent cycle"),
                    ("scan", "doctor scan", "Health scan"),
                    ("heal", "doctor heal", "Auto-fix issues")
                ]
            default:
                return []
            }
        }
        return [
            ("status", "status", "Git status"),
            ("build", "build", "Build project"),
            ("test", "test", "Run tests"),
            ("farm status", "farm status", "Farm status"),
            ("doctor", "doctor", "Health check"),
            ("constants", "constants", "Sacred constants")
        ]
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isRunning {
                    ProgressView()
                        .scaleEffect(0.6)
                        .tint(.white)
                } else {
                    Image(systemName: icon)
                        .font(WernickeTypography.size11)
                }
            }
            .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)
            .background(isRunning ? V4Color.accent : V4Color.border.opacity(V1Theme.opacityTextTertiary))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Category Button

struct CategoryButton: View {
    let name: String
    let icon: String
    let color: Color
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: icon)
                    .font(WernickeTypography.size8)
                Text(name)
                    .font(isSelected ? WernickeTypography.microSemibold : WernickeTypography.micro)
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, ParietalSpacing.xs + 2)
            .padding(.vertical, 3)
            .background(isSelected ? color : color.opacity(V2Depth.bgSidebarHover))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Command Button

struct CommandButton: View {
    let name: String
    let desc: String
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: ParietalSpacing.sm - 2) {
                Image(systemName: "chevron.right")
                    .font(WernickeTypography.size7)
                    .foregroundColor(V4Color.textSecondary.opacity(V2Depth.stateDisabled))

                VStack(alignment: .leading, spacing: ParietalSpacing.xxxxs) {
                    Text(name)
                        .font(WernickeTypography.miniMedium)
                        .foregroundColor(V4Color.textPrimary)

                    Text(desc)
                        .font(WernickeTypography.size8)
                        .foregroundColor(V4Color.textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(V4Color.accent)
                }
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
            .background(V4Color.border.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
