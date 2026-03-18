import Foundation

struct EnvLoader {
    /// Parse .env file and return key=value pairs, skipping comments and empty lines
    static func load() -> [String: String] {
        guard let url = findEnvFile() else { return [:] }
        guard let contents = try? String(contentsOf: url, encoding: .utf8) else { return [:] }

        var env: [String: String] = [:]
        for line in contents.split(separator: "\n", omittingEmptySubsequences: false) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty || trimmed.hasPrefix("#") { continue }
            guard let eqIndex = trimmed.firstIndex(of: "=") else { continue }
            let key = String(trimmed[trimmed.startIndex..<eqIndex]).trimmingCharacters(in: .whitespaces)
            var value = String(trimmed[trimmed.index(after: eqIndex)...]).trimmingCharacters(in: .whitespaces)
            // Strip surrounding quotes
            if (value.hasPrefix("\"") && value.hasSuffix("\"")) ||
               (value.hasPrefix("'") && value.hasSuffix("'")) {
                value = String(value.dropFirst().dropLast())
            }
            if !key.isEmpty {
                env[key] = value
            }
        }
        return env
    }

    /// Walk up from the app bundle looking for .env, fallback to ~/trinity-w1/.env
    static func findEnvFile() -> URL? {
        // Try walking up from bundle location
        var dir = Bundle.main.bundleURL.deletingLastPathComponent()
        for _ in 0..<10 {
            let candidate = dir.appendingPathComponent(".env")
            if FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            let parent = dir.deletingLastPathComponent()
            if parent == dir { break }
            dir = parent
        }
        // Fallback to known project root
        let fallback = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("trinity-w1/.env")
        if FileManager.default.fileExists(atPath: fallback.path) {
            return fallback
        }
        return nil
    }
}
