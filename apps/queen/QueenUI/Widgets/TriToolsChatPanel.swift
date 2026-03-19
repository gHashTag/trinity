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
        ("Core", "crown.fill", TrinityTheme.accent),
        ("Git", "arrow.triangle.branch", Color(hex: 0xF05033)),
        ("Farm", "server.rack", Color(hex: 0x34D399)),
        ("Cloud", "cloud", Color(hex: 0x38BDF8)),
        ("Math", "function", Color(hex: 0xA78BFA)),
        ("Bio", "dna", Color(hex: 0x4ADE80)),
        ("Science", "atom", Color(hex: 0x60A5FA)),
        ("Agent", "robot", Color(hex: 0xF472B6)),
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
            withAnimation(TrinityTheme.quickSpring()) {
                isExpanded.toggle()
            }
        }) {
            HStack {
                Image(systemName: "crown.fill")
                    .font(.system(size: 11))
                    .foregroundColor(TrinityTheme.accent)

                Text("Tri CLI")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(TrinityTheme.textPrimary)

                Spacer()

                if !lastCommand.isEmpty {
                    Circle()
                        .fill(isRunning ? TrinityTheme.accent : TrinityTheme.statusOK)
                        .frame(width: 6, height: 6)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(TrinityTheme.textMuted)
                    .rotationEffect(.degrees(isExpanded ? 90 : 0))
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Actions Row

    private var quickActionsRow: some View {
        HStack(spacing: 4) {
            ForEach(quickCommands, id: \.name) { cmd in
                QuickActionButton(icon: cmd.icon, isRunning: isRunning && lastCommand == cmd.name) {
                    executeCommand(cmd.cmd)
                }
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 4) {
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
            .padding(.horizontal, 6)
        }
        .padding(.vertical, 4)
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
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(TrinityTheme.textMuted)

                Spacer()

                Button(action: {
                    withAnimation {
                        showOutputPanel = false
                        commandOutput = ""
                    }
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 9))
                        .foregroundColor(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TrinityTheme.bgCardBorder.opacity(0.3))

            ScrollView {
                Text(commandOutput.isEmpty ? "No output yet..." : commandOutput)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundColor(commandOutput.isEmpty ? TrinityTheme.textMuted : TrinityTheme.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(8)
            }
            .frame(maxHeight: 150)
            .background(TrinityTheme.bgCard.opacity(0.5))
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
                        .font(.system(size: 11))
                }
            }
            .frame(width: 28, height: 28)
            .background(isRunning ? TrinityTheme.accent : TrinityTheme.bgCardBorder.opacity(0.4))
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
                    .font(.system(size: 8))
                Text(name)
                    .font(.system(size: 9, weight: isSelected ? .semibold : .regular))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isSelected ? color : color.opacity(0.15))
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
            HStack(spacing: 6) {
                Image(systemName: "chevron.right")
                    .font(.system(size: 7))
                    .foregroundColor(TrinityTheme.textMuted.opacity(0.5))

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(TrinityTheme.textPrimary)

                    Text(desc)
                        .font(.system(size: 8))
                        .foregroundColor(TrinityTheme.textMuted)
                        .lineLimit(1)
                }

                Spacer()

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.5)
                        .tint(TrinityTheme.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(TrinityTheme.bgCardBorder.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 4))
        }
        .buttonStyle(.plain)
    }
}
