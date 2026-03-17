import Testing
import Foundation
@testable import QueenUILib

@Suite("ActionQueue & JSON Models")
struct ActionQueueTests {

    @Test func actionEntry_jsonFormat() throws {
        let entry: [String: Any] = [
            "ts": 1710000000,
            "action": "farm_recycle",
            "params": ["service_id": "abc-123"],
        ]

        let data = try JSONSerialization.data(withJSONObject: entry)
        let decoded = try JSONSerialization.jsonObject(with: data) as! [String: Any]

        #expect(decoded["action"] as? String == "farm_recycle")
        #expect(decoded["ts"] as? Int == 1710000000)
        let params = decoded["params"] as? [String: String]
        #expect(params?["service_id"] == "abc-123")
    }

    @Test func actionQueue_jsonArray() throws {
        let queue: [[String: Any]] = [
            ["ts": 1710000000, "action": "build", "params": [:] as [String: String]],
            ["ts": 1710000001, "action": "test", "params": [:] as [String: String]],
        ]

        let data = try JSONSerialization.data(withJSONObject: queue, options: [.prettyPrinted])
        let decoded = try JSONSerialization.jsonObject(with: data) as! [[String: Any]]

        #expect(decoded.count == 2)
        #expect(decoded[0]["action"] as? String == "build")
        #expect(decoded[1]["action"] as? String == "test")
    }

    @Test func ouroborosState_decode() throws {
        let json = """
        {"cycle": 19, "initial": 41.0, "current": 67.5, "stagnation": 2, "strategy": "heal", "started": 1710000000}
        """
        let state = try JSONDecoder().decode(OuroborosState.self, from: json.data(using: .utf8)!)

        #expect(state.cycle == 19)
        #expect(state.score == 67.5)
        #expect(state.scoreFormatted == "67.5")
        #expect(state.strategy == "heal")
    }

    @Test func agentEvent_resolvedKind() throws {
        let json1 = """
        {"ts": 1710000000, "kind": "tool_call", "agent": "mu"}
        """
        let ev1 = try JSONDecoder().decode(AgentEvent.self, from: json1.data(using: .utf8)!)
        #expect(ev1.resolvedKind == "tool_call")

        let json2 = """
        {"ts": 1710000001, "event": "queen_cycle"}
        """
        let ev2 = try JSONDecoder().decode(AgentEvent.self, from: json2.data(using: .utf8)!)
        #expect(ev2.resolvedKind == "queen_cycle")

        let json3 = """
        {"ts": 1710000002, "action": "heal"}
        """
        let ev3 = try JSONDecoder().decode(AgentEvent.self, from: json3.data(using: .utf8)!)
        #expect(ev3.resolvedKind == "report")
    }

    @Test func queenSenses_healthStatus() throws {
        let json1 = """
        {"ts": 1, "build_ok": false, "ouroboros_score": 90}
        """
        let s1 = try JSONDecoder().decode(QueenSenses.self, from: json1.data(using: .utf8)!)
        #expect(s1.healthStatus == "BUILD BROKEN")

        let json2 = """
        {"ts": 1, "build_ok": true, "ouroboros_score": 75}
        """
        let s2 = try JSONDecoder().decode(QueenSenses.self, from: json2.data(using: .utf8)!)
        #expect(s2.healthStatus == "HEALTHY")

        let json3 = """
        {"ts": 1, "build_ok": true, "ouroboros_score": 50}
        """
        let s3 = try JSONDecoder().decode(QueenSenses.self, from: json3.data(using: .utf8)!)
        #expect(s3.healthStatus == "RECOVERING")

        let json4 = """
        {"ts": 1, "build_ok": true, "ouroboros_score": 30}
        """
        let s4 = try JSONDecoder().decode(QueenSenses.self, from: json4.data(using: .utf8)!)
        #expect(s4.healthStatus == "NEEDS ATTENTION")
    }
}
