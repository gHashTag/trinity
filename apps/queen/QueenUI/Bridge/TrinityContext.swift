import Foundation

/// Reads live Trinity state from .trinity/ files for chat context injection.
/// Provides Queen with real-time awareness of build, farm, arena, issues.
@MainActor
class TrinityContext: ObservableObject {
    static let shared = TrinityContext()

    @Published var buildOK: Bool?
    @Published var ouroborosScore: Double?
    @Published var bestPPL: Double?
    @Published var bestRun: String?
    @Published var openIssues: Int?
    @Published var farmServices: Int?
    @Published var arenaBattles: Int?
    @Published var dirtyFiles: Int?
    @Published var lastRefresh: Date?
    @Published var attachedFiles: [AttachedFile] = []

    struct AttachedFile: Identifiable {
        let path: String
        let sizeKB: Int
        let timestamp: Date
        var id: String { path }
    }

    private let trinityPath: String

    init() {
        let cwd = FileManager.default.currentDirectoryPath
        self.trinityPath = "\(cwd)/.trinity"
    }

    /// Refresh all state from .trinity/ files
    func refresh() {
        loadSenses()
        loadEvolution()
        lastRefresh = Date()
    }

    /// Record that a file was attached to context
    func recordAttachedFile(_ path: String, size: Int) {
        let file = AttachedFile(path: path, sizeKB: size / 1024, timestamp: Date())
        if !attachedFiles.contains(where: { $0.path == path }) {
            attachedFiles.append(file)
            if attachedFiles.count > 20 {
                attachedFiles.removeFirst()
            }
        }
    }

    func clearAttachedFiles() {
        attachedFiles.removeAll()
    }

    /// Build a context summary for injection into system prompt
    func buildContextSummary() -> String {
        var parts: [String] = []

        parts.append("## Live Trinity State")

        // Build
        if let ok = buildOK {
            parts.append("Build: \(ok ? "PASSING" : "BROKEN")")
        }

        // Score
        if let score = ouroborosScore {
            parts.append("Ouroboros Score: \(String(format: "%.1f", score))/100")
        }

        // Farm
        if let ppl = bestPPL, let run = bestRun {
            parts.append("Best Run: \(run) PPL=\(String(format: "%.2f", ppl))")
        }
        if let svc = farmServices, svc > 0 {
            parts.append("Farm: \(svc) active services")
        }

        // Arena
        if let battles = arenaBattles, battles > 0 {
            parts.append("Arena: \(battles) battles")
        }

        // Issues
        if let issues = openIssues {
            parts.append("Open Issues: \(issues)")
        }

        // Dirty
        if let dirty = dirtyFiles {
            parts.append("Dirty Files: \(dirty)")
        }

        if parts.count <= 1 { return "" } // only header, no data
        return parts.joined(separator: "\n")
    }

    /// Get recent farm events as context
    func recentFarmEvents(count: Int = 5) -> String {
        let path = "\(trinityPath)/farm/events.jsonl"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return "" }

        let lines = content.components(separatedBy: "\n").suffix(count)
        var events: [String] = []
        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let type = json["type"] as? String ?? "?"
                let service = json["service"] as? String ?? "?"
                let ppl = json["ppl"] as? Double
                let step = json["step"] as? Int
                var desc = "\(type): \(service)"
                if let p = ppl { desc += " PPL=\(String(format: "%.2f", p))" }
                if let s = step { desc += " step=\(s)" }
                events.append(desc)
            }
        }
        return events.isEmpty ? "" : "## Recent Farm Events\n" + events.joined(separator: "\n")
    }

    /// Get build error summary from senses.json
    func buildErrorSummary() -> String? {
        guard buildOK == false else { return nil }
        // Try to read last build log
        let logPath = "\(trinityPath)/queen/build_log.txt"
        if let content = try? String(contentsOfFile: logPath, encoding: .utf8) {
            let lines = content.components(separatedBy: "\n")
            let errorLines = lines.filter { $0.contains("error") || $0.contains("Error") }
            if !errorLines.isEmpty {
                return errorLines.prefix(10).joined(separator: "\n")
            }
            return String(content.suffix(500))
        }
        return "Build is broken (no log available)"
    }

    /// Last build output (for @build mention)
    func lastBuildLog() -> String {
        let logPath = "\(trinityPath)/queen/build_log.txt"
        if let content = try? String(contentsOfFile: logPath, encoding: .utf8) {
            return String(content.suffix(4000))
        }
        // Fallback: run tri build status
        let pipe = Pipe()
        let process = Process()
        let cwd = FileManager.default.currentDirectoryPath
        let triPath = "\(cwd)/zig-out/bin/tri"
        guard FileManager.default.fileExists(atPath: triPath) else { return "tri binary not found" }
        process.executableURL = URL(fileURLWithPath: triPath)
        process.arguments = ["build", "status"]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    /// Farm snapshot (for @farm mention)
    func farmSnapshot() -> String {
        return recentFarmEvents(count: 10)
    }

    /// Open issues summary (for @issues mention)
    func openIssuesSummary() -> String {
        let pipe = Pipe()
        let process = Process()
        let cwd = FileManager.default.currentDirectoryPath
        let triPath = "\(cwd)/zig-out/bin/tri"
        guard FileManager.default.fileExists(atPath: triPath) else { return "" }
        process.executableURL = URL(fileURLWithPath: triPath)
        process.arguments = ["issue", "list"]
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    /// Git diff HEAD (for @gitdiff mention)
    func headDiff() -> String {
        let pipe = Pipe()
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = ["diff", "HEAD"]
        let cwd = FileManager.default.currentDirectoryPath
        process.currentDirectoryURL = URL(fileURLWithPath: cwd)
        process.standardOutput = pipe
        process.standardError = pipe
        try? process.run()
        process.waitUntilExit()
        return String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
    }

    // MARK: - Loaders

    private func loadSenses() {
        let path = "\(trinityPath)/queen/senses.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        buildOK = json["build_ok"] as? Bool
        ouroborosScore = json["ouroboros_score"] as? Double
        openIssues = json["open_issues"] as? Int
        farmServices = json["farm_services"] as? Int
        bestPPL = json["farm_best_ppl"] as? Double
        arenaBattles = json["arena_battles"] as? Int
        dirtyFiles = json["dirty_files"] as? Int
    }

    private func loadEvolution() {
        let path = "\(trinityPath)/evolution_state.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }

        if let services = json["services"] as? [[String: Any]] {
            // Find best by PPL
            var best: (name: String, ppl: Double)? = nil
            for svc in services {
                guard let name = svc["name"] as? String,
                      let ppl = svc["ppl"] as? Double,
                      ppl > 0 else { continue }
                if best == nil || ppl < best!.ppl {
                    best = (name, ppl)
                }
            }
            if let b = best {
                bestRun = b.name
                bestPPL = b.ppl
            }
        }
    }
}
