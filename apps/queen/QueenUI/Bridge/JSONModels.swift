import Foundation

// MARK: - Ouroboros State

struct OuroborosState: Codable {
    let cycle: Int?
    let initial: Double?
    let current: Double?
    let stagnation: Int?
    let strategy: String?
    let started: Int?

    var score: Double { current ?? 0 }
    var scoreFormatted: String { String(format: "%.1f", score) }
}

// MARK: - Agent Heartbeat

struct AgentHeartbeat: Codable, Identifiable {
    var name: String?
    let agent: String?
    let wake: Int?
    let timestamp: Int?
    let errors_scanned: Int?
    let fixes_applied: Int?
    let build_ok: Bool?
    let test_ok: Bool?

    var id: String { name ?? agent ?? UUID().uuidString }
    var displayName: String { name ?? agent ?? "unknown" }
    var isUp: Bool { timestamp != nil }

    enum CodingKeys: String, CodingKey {
        case agent, wake, timestamp, errors_scanned, fixes_applied, build_ok, test_ok
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        agent = try c.decodeIfPresent(String.self, forKey: .agent)
        wake = try c.decodeIfPresent(Int.self, forKey: .wake)
        timestamp = try c.decodeIfPresent(Int.self, forKey: .timestamp)
        errors_scanned = try c.decodeIfPresent(Int.self, forKey: .errors_scanned)
        fixes_applied = try c.decodeIfPresent(Int.self, forKey: .fixes_applied)
        build_ok = try c.decodeIfPresent(Bool.self, forKey: .build_ok)
        test_ok = try c.decodeIfPresent(Bool.self, forKey: .test_ok)
        name = agent
    }
}

// MARK: - Farm Event

struct FarmEvent: Codable, Identifiable {
    let type: String?
    let service: String?
    let timestamp: Int?
    let ppl: Double?
    let step: Int?
    let message: String?

    var id: String { "\(timestamp ?? 0)-\(service ?? "")" }

    enum CodingKeys: String, CodingKey {
        case type, service, timestamp, ppl, step, message
    }
}

// MARK: - Queen v4 Senses

struct QueenSenses: Codable {
    let ts: Int?
    let build_ok: Bool?
    let test_rate: Int?
    let dirty_files: Int?
    let open_issues: Int?
    let agent_count: Int?
    let farm_services: Int?
    let farm_best_ppl: Double?
    let arena_battles: Int?
    let ouroboros_score: Double?
    let disk_free_gb: Double?
    let keys_present: Int?
    let keys_total: Int?
    let experience_episodes: Int?
    let network_ok: Bool?
    let farm_idle_count: Int?
    let stale_arena_hours: Int?
    let agent_spawn_issues: Int?
    let finished_containers: Int?
    let last_git_push_ts: Int?

    var healthStatus: String {
        guard build_ok == true else { return "BUILD BROKEN" }
        if (ouroboros_score ?? 0) >= 70 { return "HEALTHY" }
        if (ouroboros_score ?? 0) >= 40 { return "RECOVERING" }
        return "NEEDS ATTENTION"
    }

    var healthColor: String {
        guard build_ok == true else { return "red" }
        if (ouroboros_score ?? 0) >= 70 { return "green" }
        if (ouroboros_score ?? 0) >= 40 { return "yellow" }
        return "orange"
    }
}

// MARK: - Queen v4 Daemon State

struct QueenDaemonState: Codable {
    let cycle: Int?
    let started_at: Int?
    let last_heartbeat: Int?
    let prev_build_ok: Bool?
    let auto_actions_this_hour: Int?
    let last_auto_action_ts: Int?
    let last_build_heal_cycle: Int?
    let tg_last_update_id: Int?

    var isRunning: Bool {
        guard let ts = last_heartbeat, ts > 0 else { return false }
        return Int(Date().timeIntervalSince1970) - ts < 900 // 15 min timeout
    }

    var uptimeFormatted: String {
        guard let start = started_at, start > 0 else { return "N/A" }
        let secs = Int(Date().timeIntervalSince1970) - start
        let h = secs / 3600
        let m = (secs % 3600) / 60
        return "\(h)h \(m)m"
    }
}

// MARK: - Queen v4 Action Definition

struct QueenActionDef: Codable, Identifiable {
    let id: String?
    let label: String?
    let emoji: String?
    let level: Int?
    let max_per_hour: Int?
    let cooldown_sec: Int?

    var stableId: String { id ?? UUID().uuidString }

    var levelLabel: String {
        switch level {
        case 0: return "L0"
        case 1: return "L1"
        case 2: return "L2"
        default: return "L?"
        }
    }
}

// MARK: - Queen v4 Audit Entry

struct AuditEntry: Codable, Identifiable {
    let ts: Int?
    let kind: String?
    let action: String?
    let verdict: String?
    let success: Bool?
    let detail: String?

    var id: String { "\(ts ?? 0)-\(action ?? "")" }

    var icon: String {
        switch kind {
        case "alert": return "🚨"
        case "auto": return "⚡"
        case "auto_pending": return "⏳"
        case "auto_denied": return "🛑"
        default: return "📋"
        }
    }
}

// MARK: - Queen v4 Actions File Wrapper

struct QueenActionsFile: Codable {
    let version: Int?
    let generated_at: Int?
    let actions: [QueenActionDef]?
}

// MARK: - Queen v4 Policy

struct QueenPolicy: Codable {
    let max_auto_level: Int?
    let require_human_approval: Bool?
    let god_mode: Bool?
}

// MARK: - Build Status

struct BuildStatus: Codable {
    let binaries: [String]?
    let binary_count: Int?
    let build_ok: Bool?

    var count: Int { binary_count ?? binaries?.count ?? 0 }
}

// MARK: - Agent Event (v3 Event Stream)

struct AgentEvent: Codable, Identifiable, Equatable {
    let ts: Int?
    let seq: Int?
    let agent: String?
    let kind: String?
    let text: String?
    let cmd: String?
    let tool: String?
    let args: String?
    let file: String?
    let added: Int?
    let removed: Int?
    let preview: String?
    let result: String?
    let output: String?     // Tool stdout/result (truncated)
    let ms: Int?
    let exit: Int?
    let status: String?
    let source: String?
    let step: Int?          // Cycle step number (1-based)
    let total: Int?         // Total steps in cycle
    // Legacy fields
    let event: String?
    let action: String?
    let detail: String?

    var id: String {
        if let s = seq { return "seq-\(s)" }
        return "\(ts ?? 0)-\(kind ?? event ?? "")-\(agent ?? "")"
    }

    var resolvedKind: String {
        if let k = kind { return k }
        if event == "queen_cycle" { return "queen_cycle" }
        if action != nil { return "report" }
        return "unknown"
    }

    var isCompleted: Bool { result != nil || exit != nil }

    var stepProgress: String? {
        guard let s = step, let t = total else { return nil }
        return "Step \(s)/\(t)"
    }
}

// MARK: - Queen Todo (from .trinity/queen/todos.json)

struct QueenTodo: Codable, Identifiable {
    let text: String
    let source: String
    let status: String
    let id: String
}

struct QueenTodosFile: Codable {
    let generated_at: Int?
    let items: [QueenTodo]?
}

// MARK: - Swarm State (shared model)

struct SwarmState: Codable {
    let active_tasks: Int?
    let completed_tasks: Int?
    let agents: [SwarmAgent]?
}

struct SwarmAgent: Codable, Identifiable {
    let name: String?
    let role: String?
    let status: String?
    let current_task: String?

    var id: String { name ?? UUID().uuidString }
}
