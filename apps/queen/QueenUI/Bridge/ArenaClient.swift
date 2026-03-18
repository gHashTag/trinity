import Foundation

/// HTTP client for Arena API at :8080
actor ArenaClient {
    let baseURL: URL

    init(host: String = "localhost", port: Int = 8080) {
        baseURL = URL(string: "http://\(host):\(port)")!
    }

    func leaderboard() async throws -> [[String: Any]] {
        let url = baseURL.appendingPathComponent("leaderboard")
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return json
    }

    func battle(prompt: String, fighters: [String] = []) async throws -> [String: Any] {
        let url = baseURL.appendingPathComponent("battle")
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var body: [String: Any] = ["prompt": prompt]
        if !fighters.isEmpty { body["fighters"] = fighters }
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, _) = try await URLSession.shared.data(for: request)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    func tasks() async throws -> [[String: Any]] {
        let url = baseURL.appendingPathComponent("tasks")
        let (data, _) = try await URLSession.shared.data(from: url)
        guard let json = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] else {
            return []
        }
        return json
    }
}
