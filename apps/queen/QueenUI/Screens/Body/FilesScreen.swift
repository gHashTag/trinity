import SwiftUI

struct FilesScreen: View {
    @State private var topDirs: [DirInfo] = []

    struct DirInfo: Identifiable {
        let name: String
        let fileCount: Int
        let description: String

        var id: String { name }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("📁")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("FILES")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("Project Structure")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                }
                .padding()

                ForEach(topDirs) { dir in
                    HStack(spacing: ParietalSpacing.md) {
                        Text(dirIcon(dir.name))
                            .font(.title2)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dir.name + "/")
                                .font(.headline.monospaced())
                                .foregroundStyle(V4Color.textPrimary)
                            Text(dir.description)
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                        Spacer()
                        if dir.fileCount > 0 {
                            Text("\(dir.fileCount)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    }
                    .padding()
                    .background(V4Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .onAppear { scanProject() }
    }

    private func scanProject() {
        let dirs: [(String, String)] = [
            ("src", "Core Zig source — VSA, VM, CLI, agents"),
            ("src/tri", "TRI CLI — 310+ commands"),
            ("src/tri-api", "Claude Code replacement (11 files, 2,555 LOC)"),
            ("src/hslm", "HSLM training — ternary LLM"),
            ("src/arena", "Arena 2.0 — LLM battle platform"),
            ("specs", ".tri specifications (source of truth)"),
            ("fpga", "FPGA — Verilog, synthesis, bitstreams"),
            ("papers", "Research papers — HSLM, FPGA, patent"),
            ("apps/queen", "Queen UI — SwiftUI dashboard (this app)"),
            ("libs/swift", "Swift packages — TrinityVSA, TrinityBridge"),
            ("libs/c", "C headers — libtrinity-vsa, libtrinity-queen"),
            ("tools/mcp", "MCP server — 47+ tools"),
            ("docs", "Documentation site (GitHub Pages)"),
            ("data", "Arena results, training data"),
            (".trinity", "Runtime state — heartbeats, events, scores"),
            (".ralph", "Agent Ralph — memory, identity, handover"),
        ]

        let fm = FileManager.default
        let cwd = fm.currentDirectoryPath

        topDirs = dirs.map { name, desc in
            let path = "\(cwd)/\(name)"
            let count = (try? fm.contentsOfDirectory(atPath: path))?.count ?? 0
            return DirInfo(name: name, fileCount: count, description: desc)
        }
    }

    private func dirIcon(_ name: String) -> String {
        switch name {
        case "src": return "⚡"
        case "fpga": return "🔌"
        case "papers": return "📝"
        case "apps/queen": return "👑"
        case "specs": return "📐"
        case ".trinity": return "🔮"
        case ".ralph": return "🤖"
        case "docs": return "📖"
        case "data": return "💾"
        default: return "📁"
        }
    }
}
