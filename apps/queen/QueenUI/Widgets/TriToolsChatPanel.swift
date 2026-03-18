// TriToolsChatPanel — Compact Tri CLI Tools for Chat Sidebar
import SwiftUI

struct TriToolsChatPanel: View {
    @State private var isExpanded = true
    @State private var selectedCategory: String? = nil
    @State private var commandOutput = ""
    @State private var isRunning = false

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
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
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

                    Image(systemName: "chevron.right")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(TrinityTheme.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider()

                // Quick actions
                HStack(spacing: 4) {
                    ForEach(quickCommands, id: \.name) { cmd in
                        QuickActionButton(icon: cmd.icon, action: {
                            executeCommand(cmd.cmd)
                        })
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)

                Divider()

                // Category filter
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

                // Commands list
                ScrollView {
                    VStack(spacing: 2) {
                        ForEach(getCommandsForCategory(selectedCategory), id: \.name) { cmd in
                            CommandButton(name: cmd.name, desc: cmd.desc, isRunning: isRunning) {
                                executeCommand(cmd.cmd)
                            }
                        }
                    }
                }

                // Output area
                if !commandOutput.isEmpty {
                    Divider()
                    ScrollView {
                        Text(commandOutput)
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundColor(TrinityTheme.textPrimary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                    }
                    .frame(maxHeight: 120)
                    .background(TrinityTheme.bgCard.opacity(0.5))
                }
            }
        }
    }

    private func executeCommand(_ cmd: String) {
        isRunning = true
        commandOutput = ""

        Task {
            do {
                let triPath = "/Users/playra/trinity-w1/zig-out/bin/tri"
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
                    commandOutput = String(data: data, encoding: .utf8) ?? ""
                }
            } catch {
                await MainActor.run {
                    isRunning = false
                    commandOutput = "Error: \(error.localizedDescription)"
                }
            }
        }
    }

    private func getCommandsForCategory(_ category: String?) -> [(name: String, cmd: String, desc: String)] {
        if let cat = category {
            switch cat {
            case "Core":
                return [("status", "status", "Git status"),
                        ("build", "build", "Build project"),
                        ("test", "test", "Run tests"),
                        ("commit", "commit", "Git commit")]
            case "Git":
                return [("status", "status", "Git status"),
                        ("diff", "diff", "Git diff"),
                        ("log", "log", "Git log"),
                        ("commit", "commit", "Git commit")]
            case "Farm":
                return [("status", "farm status", "Farm status"),
                        ("list", "farm list", "List services"),
                        ("recycle", "farm recycle", "Recycle farm")]
            case "Math":
                return [("constants", "constants", "Sacred constants"),
                        ("phi", "phi", "Golden ratio"),
                        ("fib", "fib", "Fibonacci"),
                        ("formula", "formula", "Evaluate formula")]
            case "Bio":
                return [("dna", "bio dna", "DNA analyze"),
                        ("codon", "bio codon", "RNA codon"),
                        ("protein", "bio protein", "Protein analyze")]
            default:
                return []
            }
        }
        return [("status", "status", "Git status"),
                ("build", "build", "Build project"),
                ("test", "test", "Run tests")]
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundColor(TrinityTheme.accent)
                .frame(width: 28, height: 28)
                .background(TrinityTheme.bgCardBorder.opacity(0.3))
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
            HStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 8))
                Text(name)
                    .font(.system(size: 9))
            }
            .foregroundColor(isSelected ? .white : color)
            .padding(.horizontal, 6)
            .padding(.vertical, 3)
            .background(isSelected ? color : color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
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
                    .foregroundColor(TrinityTheme.textMuted)

                VStack(alignment: .leading, spacing: 1) {
                    Text(name)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(TrinityTheme.textPrimary)

                    Text(desc)
                        .font(.system(size: 8))
                        .foregroundColor(TrinityTheme.textMuted)
                }

                Spacer()

                if isRunning {
                    ProgressView()
                        .scaleEffect(0.4)
                        .tint(TrinityTheme.accent)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
        }
        .buttonStyle(.plain)
    }
}
