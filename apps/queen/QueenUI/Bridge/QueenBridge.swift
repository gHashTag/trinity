import Foundation

/// Unified data bridge — reads .trinity/ JSON files directly.
/// When libtrinity-queen.dylib is linked (Phase 2+), FFI calls
/// replace file reads for computed data (sacred constants, ELO, etc.)
final class QueenBridge: ObservableObject {
    static let shared = QueenBridge()

    private let trinityPath: String
    private let decoder = JSONDecoder()

    init(trinityPath: String? = nil) {
        let cwd = FileManager.default.currentDirectoryPath
        self.trinityPath = trinityPath ?? "\(cwd)/.trinity"
    }

    // MARK: - Sacred Constants (computed, no file)

    struct SacredConstants {
        let phi: Double = (1.0 + sqrt(5.0)) / 2.0
        var phiSquared: Double { phi * phi }
        var invPhiSquared: Double { 1.0 / phiSquared }
        var trinityIdentity: Double { phiSquared + invPhiSquared } // = 3.0
        let bitsPerTrit: Double = 1.58496
        let maxDim: Int = 59049
        let dim3k: [Int] = [3, 9, 27, 81, 243, 729, 2187, 6561, 19683, 59049]
        let deltaCP: Double = 248.75
        let w0: Double = -0.618
    }

    let sacred = SacredConstants()

    // MARK: - Evolution State

    struct EvolutionService: Codable, Identifiable {
        let name: String?
        let ppl: Double?
        let step: Int?
        let lr: Double?
        let schedule: String?
        let status: String?

        var id: String { name ?? UUID().uuidString }
    }

    func loadEvolutionState() -> [String: Any]? {
        readJSON("evolution_state.json")
    }

    // MARK: - Swarm State (model in JSONModels.swift)

    func loadSwarmState() -> SwarmState? {
        guard let data = readFile("swarm_state.json") else { return nil }
        return try? decoder.decode(SwarmState.self, from: data)
    }

    // MARK: - Tech Tree

    func loadTechTree() -> [String: Any]? {
        readJSON("tech_tree.json")
    }

    // MARK: - Patent Status

    struct PatentStatus: Codable {
        let filings: [PatentFiling]?
        let budget: String?
        let next_deadline: String?
    }

    struct PatentFiling: Codable, Identifiable {
        let id: String
        let title: String?
        let priority: String?
        let claims: Int?
        let status: String?
    }

    func loadPatentStatus() -> [String: Any]? {
        readJSON("patent/status.json")
    }

    // MARK: - Pipeline State

    func loadPipelineState() -> [String: Any]? {
        readJSON("pipeline_state.json")
    }

    // MARK: - Issues Snapshot

    func loadIssuesSnapshot() -> [String: Any]? {
        readJSON("issues_snapshot.json")
    }

    // MARK: - Farm Events (last N lines from JSONL)

    struct FarmEventBridge: Identifiable {
        let type: String
        let service: String
        let ppl: Double?
        let step: Int?
        let timestamp: Int
        var id: String { "\(timestamp)-\(service)" }
    }

    func loadFarmEvents(lastN: Int = 20) -> [FarmEvent] {
        let path = "\(trinityPath)/farm/events.jsonl"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }

        let lines = content.components(separatedBy: "\n").suffix(lastN)
        return lines.compactMap { line -> FarmEvent? in
            guard !line.isEmpty, let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(FarmEvent.self, from: data)
        }
    }

    // MARK: - Queen v4

    func loadSenses() -> QueenSenses? {
        guard let data = readFile("queen/senses.json") else { return nil }
        return try? decoder.decode(QueenSenses.self, from: data)
    }

    func loadQueenState() -> QueenDaemonState? {
        guard let data = readFile("queen_state.json") else { return nil }
        return try? decoder.decode(QueenDaemonState.self, from: data)
    }

    func loadActions() -> [QueenActionDef] {
        guard let data = readFile("queen/actions.json") else { return [] }
        let wrapper = try? decoder.decode(QueenActionsFile.self, from: data)
        return wrapper?.actions ?? []
    }

    func loadAudit(lastN: Int = 20) -> [AuditEntry] {
        let path = "\(trinityPath)/queen/audit.jsonl"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return [] }
        let lines = content.components(separatedBy: "\n").suffix(lastN)
        return lines.compactMap { line -> AuditEntry? in
            guard !line.isEmpty, let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(AuditEntry.self, from: data)
        }
    }

    func loadPolicy() -> QueenPolicy? {
        guard let data = readFile("queen/policy.json") else { return nil }
        return try? decoder.decode(QueenPolicy.self, from: data)
    }

    // MARK: - Helpers

    private func readFile(_ relativePath: String) -> Data? {
        try? Data(contentsOf: URL(fileURLWithPath: "\(trinityPath)/\(relativePath)"))
    }

    private func readJSON(_ relativePath: String) -> [String: Any]? {
        guard let data = readFile(relativePath) else { return nil }
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
