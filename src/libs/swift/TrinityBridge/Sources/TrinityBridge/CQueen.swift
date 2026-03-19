import Foundation
import CTrinityQueen

/// Swift wrapper around libtrinity-queen C FFI
public final class TrinityQueenBridge {
    private let bufferSize = 64 * 1024 // 64 KB

    public init() {}

    /// Get library version
    public var version: String {
        String(cString: trinity_queen_version())
    }

    /// Get sacred mathematical constants
    public func sacredConstants() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_sacred_constants(buf, len)
        }
    }

    /// Get ouroboros cycle state
    public func ouroborosState() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_ouroboros_state(buf, len)
        }
    }

    /// Get faculty agent snapshot
    public func facultySnapshot() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_faculty_snapshot(buf, len)
        }
    }

    /// Get last N farm events
    public func farmEvents(lastN: Int = 20) -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_farm_events(buf, len, lastN)
        }
    }

    /// Get swarm state
    public func swarmState() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_swarm_state(buf, len)
        }
    }

    /// Get build status
    public func buildStatus() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_build_status(buf, len)
        }
    }

    /// Get patent filing status
    public func patentStatus() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_patent_status(buf, len)
        }
    }

    /// Get tech tree
    public func techTree() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_tech_tree(buf, len)
        }
    }

    /// Get arena leaderboard
    public func arenaLeaderboard() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_arena_leaderboard(buf, len)
        }
    }

    /// Get recent experience episodes
    public func experienceRecent(n: Int = 20) -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_experience_recent(buf, len, n)
        }
    }

    /// Get Queen v4 senses snapshot
    public func senses() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_senses(buf, len)
        }
    }

    /// Get Queen daemon state
    public func queenState() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_queen_state(buf, len)
        }
    }

    /// Get all 29 actions with levels and rate limits
    public func actionsList() -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_actions_list(buf, len)
        }
    }

    /// Get last N audit entries
    public func auditRecent(n: Int = 20) -> [String: Any]? {
        callJSON { buf, len in
            trinity_queen_audit_recent(n, buf, len)
        }
    }

    // MARK: - Internal

    private func callJSON(_ fn: (UnsafeMutablePointer<CChar>, Int) -> Int) -> [String: Any]? {
        let buf = UnsafeMutablePointer<CChar>.allocate(capacity: bufferSize)
        defer { buf.deallocate() }

        let written = fn(buf, bufferSize)
        guard written > 0 else { return nil }

        let data = Data(bytes: buf, count: written)
        return try? JSONSerialization.jsonObject(with: data) as? [String: Any]
    }
}
