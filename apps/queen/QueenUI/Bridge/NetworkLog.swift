import Foundation

/// Tracks API request history, latency, and token usage.
/// Persists to Application Support/QueenUI/network_log.jsonl
@MainActor
class NetworkLog: ObservableObject {
    static let shared = NetworkLog()

    @Published var entries: [Entry] = []
    @Published var providerHealth: [String: ProviderStatus] = [:]

    private let logURL: URL
    private let maxEntries = 200

    struct Entry: Codable, Identifiable {
        let ts: Int
        let provider: String
        let model: String
        let inputTokens: Int
        let outputTokens: Int
        let ttfbMs: Int          // Time to first token
        let totalMs: Int
        let status: String       // "ok", "error", "timeout", "cancelled"
        let errorMessage: String?

        var id: String { "\(ts)-\(model)" }

        var tokensPerSec: Double {
            guard totalMs > ttfbMs, outputTokens > 0 else { return 0 }
            let genMs = totalMs - ttfbMs
            guard genMs > 0 else { return 0 }
            return Double(outputTokens) / (Double(genMs) / 1000.0)
        }
    }

    struct ProviderStatus {
        let name: String
        var isUp: Bool
        var lastCheck: Date
        var latencyMs: Int
        var remainingRequests: Int?
    }

    init() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("QueenUI", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        logURL = dir.appendingPathComponent("network_log.jsonl")
        loadRecent()
    }

    func record(
        provider: String,
        model: String,
        inputTokens: Int,
        outputTokens: Int,
        ttfbMs: Int,
        totalMs: Int,
        status: String,
        errorMessage: String? = nil
    ) {
        let entry = Entry(
            ts: Int(Date().timeIntervalSince1970),
            provider: provider,
            model: model,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
            ttfbMs: ttfbMs,
            totalMs: totalMs,
            status: status,
            errorMessage: errorMessage
        )

        entries.append(entry)
        if entries.count > maxEntries {
            entries = Array(entries.suffix(maxEntries))
        }

        // Append to JSONL
        if let data = try? JSONEncoder().encode(entry),
           let line = String(data: data, encoding: .utf8) {
            if let fh = try? FileHandle(forWritingTo: logURL) {
                fh.seekToEndOfFile()
                fh.write((line + "\n").data(using: .utf8)!)
                try? fh.close()
            } else {
                try? (line + "\n").data(using: .utf8)?.write(to: logURL)
            }
        }
    }

    /// Check health of all providers
    func checkAllProviders() {
        let endpoints: [(String, String)] = [
            ("Anthropic", "https://api.anthropic.com"),
            ("z.ai", "https://api.z.ai"),
            ("Perplexity", "https://api.perplexity.ai"),
            ("xAI", "https://api.x.ai"),
        ]

        for (name, urlStr) in endpoints {
            Task {
                let start = Date()
                var isUp = false
                var latency = 0

                if let url = URL(string: urlStr) {
                    var request = URLRequest(url: url)
                    request.httpMethod = "HEAD"
                    request.timeoutInterval = 5
                    do {
                        let (_, response) = try await URLSession.shared.data(for: request)
                        isUp = (response as? HTTPURLResponse)?.statusCode != nil
                        latency = Int(Date().timeIntervalSince(start) * 1000)
                    } catch {
                        isUp = false
                        latency = 5000
                    }
                }

                await MainActor.run {
                    providerHealth[name] = ProviderStatus(
                        name: name,
                        isUp: isUp,
                        lastCheck: Date(),
                        latencyMs: latency,
                        remainingRequests: nil
                    )
                }
            }
        }
    }

    /// Update rate limit info from response headers
    func updateRateLimit(provider: String, remaining: Int?) {
        if var status = providerHealth[provider] {
            status.remainingRequests = remaining
            providerHealth[provider] = status
        }
    }

    // Stats

    var todayEntries: [Entry] {
        let dayStart = Calendar.current.startOfDay(for: Date())
        let ts = Int(dayStart.timeIntervalSince1970)
        return entries.filter { $0.ts >= ts }
    }

    var todayTokens: Int {
        todayEntries.reduce(0) { $0 + $1.inputTokens + $1.outputTokens }
    }

    var avgTTFB: Int {
        let valid = todayEntries.filter { $0.ttfbMs > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0) { $0 + $1.ttfbMs } / valid.count
    }

    var avgTokPerSec: Double {
        let valid = todayEntries.filter { $0.tokensPerSec > 0 }
        guard !valid.isEmpty else { return 0 }
        return valid.reduce(0.0) { $0 + $1.tokensPerSec } / Double(valid.count)
    }

    /// Recent TTFB values for a specific model (for sparkline)
    func recentTTFB(for modelID: String, count: Int = 7) -> [Int] {
        entries
            .filter { $0.model == modelID && $0.ttfbMs > 0 && $0.status == "ok" }
            .suffix(count)
            .map(\.ttfbMs)
    }

    /// Recent TTFB values for a provider
    func recentTTFBForProvider(_ provider: String, count: Int = 7) -> [Int] {
        entries
            .filter { $0.provider == provider && $0.ttfbMs > 0 && $0.status == "ok" }
            .suffix(count)
            .map(\.ttfbMs)
    }

    /// Total cost estimate for today's session (USD)
    func todayCostEstimate() -> Double {
        todayEntries.reduce(0.0) { total, entry in
            total + AIModel.estimateCost(
                provider: entry.provider,
                inputTokens: entry.inputTokens,
                outputTokens: entry.outputTokens
            )
        }
    }

    /// Get error entries (for network dashboard)
    var recentErrors: [Entry] {
        entries.filter { $0.status == "error" || $0.status == "timeout" }.suffix(10).reversed()
    }

    /// Per-provider stats summary
    func providerStats(_ provider: String) -> (requests: Int, errors: Int, avgTTFB: Int, avgTPS: Double) {
        let provEntries = todayEntries.filter { $0.provider == provider }
        let requests = provEntries.count
        let errors = provEntries.filter { $0.status != "ok" && $0.status != "cancelled" }.count
        let validTTFB = provEntries.filter { $0.ttfbMs > 0 && $0.status == "ok" }
        let avgTTFB = validTTFB.isEmpty ? 0 : validTTFB.reduce(0) { $0 + $1.ttfbMs } / validTTFB.count
        let validTPS = provEntries.filter { $0.tokensPerSec > 0 }
        let avgTPS = validTPS.isEmpty ? 0.0 : validTPS.reduce(0.0) { $0 + $1.tokensPerSec } / Double(validTPS.count)
        return (requests, errors, avgTTFB, avgTPS)
    }

    /// Check if rate limit is running low for a provider
    func isRateLimitLow(_ provider: String) -> (low: Bool, remaining: Int?) {
        guard let status = providerHealth[provider] else { return (false, nil) }
        guard let remaining = status.remainingRequests else { return (false, nil) }
        return (remaining < 10, remaining)
    }

    /// Rate limit ETA predictor: estimate minutes until rate limit exhaustion
    func rateLimitETA(_ provider: String) -> Int? {
        guard let status = providerHealth[provider],
              let remaining = status.remainingRequests, remaining > 0 else { return nil }

        // Calculate request rate: requests per minute in last 10 entries
        let recent = entries.filter { $0.provider == provider && $0.status == "ok" }.suffix(10)
        guard recent.count >= 2 else { return nil }
        let firstTs = recent.first!.ts
        let lastTs = recent.last!.ts
        let spanSec = lastTs - firstTs
        guard spanSec > 0 else { return nil }

        let requestsPerMin = Double(recent.count) / (Double(spanSec) / 60.0)
        guard requestsPerMin > 0 else { return nil }

        return Int(Double(remaining) / requestsPerMin)
    }

    /// Track previous provider state for recovery detection
    @Published var recoveredProviders: [String] = []

    /// Detect provider recovery: was down, now up
    func checkRecovery() {
        for (name, status) in providerHealth {
            if status.isUp && !recoveredProviders.contains(name) {
                // Check if it was recently down (within last 5 minutes of entries)
                let recentErrors = entries.filter {
                    $0.provider == name &&
                    ($0.status == "error" || $0.status == "timeout") &&
                    $0.ts > Int(Date().timeIntervalSince1970) - 300
                }
                if !recentErrors.isEmpty {
                    recoveredProviders.append(name)
                    // Auto-clear after 30s
                    Task { @MainActor in
                        try? await Task.sleep(for: .seconds(30))
                        recoveredProviders.removeAll { $0 == name }
                    }
                }
            }
        }
    }

    private func loadRecent() {
        rotateIfNeeded()
        guard let content = try? String(contentsOf: logURL, encoding: .utf8) else { return }
        let decoder = JSONDecoder()
        let lines = content.components(separatedBy: "\n").suffix(maxEntries)
        entries = lines.compactMap { line -> Entry? in
            guard !line.isEmpty, let data = line.data(using: .utf8) else { return nil }
            return try? decoder.decode(Entry.self, from: data)
        }
    }

    /// Rotate log daily: archive yesterday's log, delete logs >7 days old
    private func rotateIfNeeded() {
        let fm = FileManager.default
        guard fm.fileExists(atPath: logURL.path) else { return }

        // Check last rotation date
        let lastRotateKey = "networkLog.lastRotate"
        let lastRotate = UserDefaults.standard.string(forKey: lastRotateKey) ?? ""
        let today = ISO8601DateFormatter().string(from: Date()).prefix(10)  // "2026-03-17"
        guard lastRotate != String(today) else { return }

        // Archive current log
        let archiveURL = logURL.deletingLastPathComponent()
            .appendingPathComponent("network_log_\(lastRotate.isEmpty ? "old" : lastRotate).jsonl")
        try? fm.moveItem(at: logURL, to: archiveURL)

        // Delete archives older than 7 days
        let logDir = logURL.deletingLastPathComponent()
        if let files = try? fm.contentsOfDirectory(at: logDir, includingPropertiesForKeys: [.creationDateKey]) {
            let cutoff = Date().addingTimeInterval(-7 * 86400)
            for file in files where file.lastPathComponent.hasPrefix("network_log_") && file.lastPathComponent != logURL.lastPathComponent {
                if let attrs = try? fm.attributesOfItem(atPath: file.path),
                   let created = attrs[.creationDate] as? Date,
                   created < cutoff {
                    try? fm.removeItem(at: file)
                }
            }
        }

        UserDefaults.standard.set(String(today), forKey: lastRotateKey)
    }
}
