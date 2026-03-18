import Foundation
import SwiftUI

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case anthropic = "Anthropic"
    case zai = "z.ai"
    case perplexity = "Perplexity"
    case xai = "xAI"
    case ollama = "Ollama"

    var id: String { rawValue }
}

struct AIModel: Identifiable, Codable, Equatable, Hashable {
    let id: String
    let displayName: String
    let provider: AIProvider

    static let allModels: [AIModel] = [
        // Anthropic
        AIModel(id: "claude-sonnet-4-20250514", displayName: "Sonnet 4", provider: .anthropic),
        AIModel(id: "claude-haiku-4-5-20251001", displayName: "Haiku 4.5", provider: .anthropic),
        // z.ai
        AIModel(id: "glm-5", displayName: "GLM-5", provider: .zai),
        // Perplexity
        AIModel(id: "sonar-pro", displayName: "Sonar Pro", provider: .perplexity),
        AIModel(id: "sonar-reasoning-pro", displayName: "Sonar Reasoning", provider: .perplexity),
        // xAI (Grok)
        AIModel(id: "grok-3", displayName: "Grok 3", provider: .xai),
        AIModel(id: "grok-3-mini", displayName: "Grok 3 Mini", provider: .xai),
        AIModel(id: "grok-4-0709", displayName: "Grok 4", provider: .xai),
        AIModel(id: "grok-4-fast-reasoning", displayName: "Grok 4 Fast", provider: .xai),
        AIModel(id: "grok-code-fast-1", displayName: "Grok Code", provider: .xai),
        AIModel(id: "grok-imagine-image", displayName: "Grok Image", provider: .xai),
    ]

    /// Whether this model generates images instead of text
    var isImageModel: Bool { id.contains("image") }

    /// Estimate cost in USD for given token counts (per 1M tokens pricing)
    static func estimateCost(provider: String, inputTokens: Int, outputTokens: Int) -> Double {
        // Approximate $/1M token pricing
        let (inPrice, outPrice): (Double, Double)
        switch provider {
        case "Anthropic":  (inPrice, outPrice) = (3.0, 15.0)   // Sonnet 4
        case "z.ai":       (inPrice, outPrice) = (1.0, 2.0)    // GLM proxy
        case "Perplexity": (inPrice, outPrice) = (3.0, 15.0)   // Sonar Pro
        case "xAI":        (inPrice, outPrice) = (3.0, 15.0)   // Grok 3
        case "Ollama":     (inPrice, outPrice) = (0.0, 0.0)    // Local — free
        default:           (inPrice, outPrice) = (3.0, 15.0)
        }
        return (Double(inputTokens) * inPrice + Double(outputTokens) * outPrice) / 1_000_000.0
    }
}

@MainActor
class ModelManager: ObservableObject {
    @Published var availableModels: [AIModel] = []
    @Published var selectedModel: AIModel
    @Published var ollamaAvailable: Bool = false
    /// Set when cloud-to-local fallback fires; UI can display inline notice
    @Published var cloudFallbackNotice: String? = nil
    let env: [String: String]

    private var ollamaDetectionTask: Task<Void, Never>?

    init() {
        let loaded = EnvLoader.load()
        self.env = loaded

        // Determine available models based on keys
        var models: [AIModel] = []
        for model in AIModel.allModels {
            switch model.provider {
            case .anthropic:
                if loaded["ANTHROPIC_API_KEY"] != nil { models.append(model) }
            case .zai:
                if (1...6).contains(where: { loaded["ZAI_KEY_\($0)"] != nil }) {
                    models.append(model)
                }
            case .perplexity:
                if loaded["PERPLEXITY_API_KEY"] != nil { models.append(model) }
            case .xai:
                if loaded["XAI_API_KEY"] != nil { models.append(model) }
            case .ollama:
                break // handled below
            }
        }

        // Add Ollama models if enabled
        if UserDefaults.standard.bool(forKey: "ollamaEnabled"),
           let ollamaNames = UserDefaults.standard.stringArray(forKey: "ollamaModels") {
            for name in ollamaNames {
                models.append(AIModel(id: "ollama:\(name)", displayName: name, provider: .ollama))
            }
        }

        self.availableModels = models

        // Restore saved selection or pick first available
        let savedID = UserDefaults.standard.string(forKey: "selectedModelID")
        if let saved = savedID, let match = models.first(where: { $0.id == saved }) {
            self.selectedModel = match
        } else {
            self.selectedModel = models.first ?? AIModel.allModels[0]
        }

        // Start periodic Ollama detection
        startOllamaDetection()
    }

    /// Probe localhost:11434 for Ollama availability and discover models
    func detectOllama() async -> Bool {
        let base = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        guard let url = URL(string: base + "/api/tags") else { return false }
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else { return false }
            guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let models = json["models"] as? [[String: Any]] else { return false }
            let names = models.compactMap { $0["name"] as? String }
            guard !names.isEmpty else { return false }

            // Update available Ollama models on main actor
            UserDefaults.standard.set(true, forKey: "ollamaEnabled")
            UserDefaults.standard.set(names, forKey: "ollamaModels")
            self.availableModels.removeAll { $0.provider == .ollama }
            for name in names {
                self.availableModels.append(AIModel(id: "ollama:\(name)", displayName: name, provider: .ollama))
            }
            self.ollamaAvailable = true
            return true
        } catch {
            self.availableModels.removeAll { $0.provider == .ollama }
            self.ollamaAvailable = false
            return false
        }
    }

    /// Start background task that probes Ollama every 60 seconds
    private func startOllamaDetection() {
        ollamaDetectionTask?.cancel()
        ollamaDetectionTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { break }
                _ = await self.detectOllama()
                do {
                    try await Task.sleep(for: .seconds(60))
                } catch {
                    break  // Task was cancelled
                }
            }
        }
    }

    deinit {
        ollamaDetectionTask?.cancel()
    }

    /// Best available Ollama model (prefers larger models)
    func bestOllamaModel() -> AIModel? {
        availableModels.first(where: { $0.provider == .ollama })
    }

    /// True when all cloud providers are down or circuit-broken
    var allCloudDown: Bool {
        let cloudModels = availableModels.filter { $0.provider != .ollama && !$0.isImageModel }
        guard !cloudModels.isEmpty else { return true }
        let health = NetworkLog.shared.providerHealth
        return cloudModels.allSatisfy { model in
            let provName = model.provider.rawValue
            let circuitOpen = NetworkLog.shared.isCircuitOpen(provider: provName)
            let isDown = health[provName].map { !$0.isUp } ?? false
            return circuitOpen || isDown
        }
    }

    func persistSelection() {
        UserDefaults.standard.set(selectedModel.id, forKey: "selectedModelID")
    }

    func apiKey(for model: AIModel) -> String? {
        switch model.provider {
        case .anthropic:
            return env["ANTHROPIC_API_KEY"]
        case .zai:
            for i in 1...6 {
                if let key = env["ZAI_KEY_\(i)"] { return key }
            }
            return nil
        case .perplexity:
            return env["PERPLEXITY_API_KEY"]
        case .xai:
            return env["XAI_API_KEY"]
        case .ollama:
            return "ollama" // No key needed, return non-nil to pass checks
        }
    }

    func baseURL(for model: AIModel) -> String {
        switch model.provider {
        case .anthropic:
            return "https://api.anthropic.com/v1/messages"
        case .zai:
            return "https://api.z.ai/api/anthropic/v1/messages"
        case .perplexity:
            return "https://api.perplexity.ai/chat/completions"
        case .xai:
            if model.isImageModel {
                return "https://api.x.ai/v1/images/generations"
            }
            return "https://api.x.ai/v1/chat/completions"
        case .ollama:
            let base = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
            return base + "/api/chat"
        }
    }

    func buildRequest(for model: AIModel, body: Data) -> URLRequest? {
        guard let key = apiKey(for: model) else { return nil }
        let url = URL(string: baseURL(for: model))!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30  // Prevent indefinite hangs
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        switch model.provider {
        case .anthropic, .zai:
            request.setValue(key, forHTTPHeaderField: "x-api-key")
            request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        case .perplexity, .xai:
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        case .ollama:
            break // No auth needed for local Ollama
        }

        request.httpBody = body
        return request
    }

    /// Ollama model name (strip "ollama:" prefix)
    func ollamaModelName(_ model: AIModel) -> String {
        if model.id.hasPrefix("ollama:") {
            return String(model.id.dropFirst(7))
        }
        return model.id
    }

    /// Refresh Ollama model list dynamically
    func refreshOllamaModels() {
        let base = UserDefaults.standard.string(forKey: "ollamaURL") ?? "http://localhost:11434"
        guard let url = URL(string: base + "/api/tags") else { return }
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        URLSession.shared.dataTask(with: request) { [weak self] data, _, error in
            let hasModels: Bool
            if let data,
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let models = json["models"] as? [[String: Any]] {
                let names = models.compactMap { $0["name"] as? String }
                UserDefaults.standard.set(names, forKey: "ollamaModels")
                UserDefaults.standard.set(true, forKey: "ollamaEnabled")
                hasModels = !names.isEmpty
                DispatchQueue.main.async {
                    self?.availableModels.removeAll { $0.provider == .ollama }
                    for name in names {
                        self?.availableModels.append(AIModel(id: "ollama:\(name)", displayName: name, provider: .ollama))
                    }
                    self?.ollamaAvailable = hasModels
                }
            } else {
                DispatchQueue.main.async {
                    self?.ollamaAvailable = false
                }
            }
        }.resume()
    }

    var hasAnyKey: Bool { !availableModels.isEmpty }

    func providerHasKey(_ provider: AIProvider) -> Bool {
        availableModels.contains(where: { $0.provider == provider })
    }

    /// Get xAI API key directly (for image generation)
    var xaiKey: String? { env["XAI_API_KEY"] }

    /// Auto-failover: if selected provider is down or circuit-open, pick best available alternative
    /// Tries ALL providers, scored by recent TTFB (fastest first).
    /// Falls back to Ollama as last resort when all cloud providers are unavailable.
    func failoverModel() -> AIModel? {
        let health = NetworkLog.shared.providerHealth
        let currentProvider = selectedModel.provider.rawValue

        // If current provider is up and circuit is closed, no failover needed
        let circuitOpen = NetworkLog.shared.isCircuitOpen(provider: currentProvider)
        if !circuitOpen, let status = health[currentProvider], status.isUp { return nil }

        // Find all cloud candidates whose provider is up, circuit is closed, and has a key
        let candidates = availableModels.filter { model in
            model.id != selectedModel.id &&
            model.provider != .ollama &&
            !model.isImageModel &&
            !NetworkLog.shared.isCircuitOpen(provider: model.provider.rawValue) &&
            (health[model.provider.rawValue]?.isUp ?? true)
        }

        // Score by recent average TTFB (lower = better)
        let scored = candidates.map { model -> (AIModel, Int) in
            let ttfbs = NetworkLog.shared.recentTTFB(for: model.id)
            let avg = ttfbs.isEmpty ? 1000 : ttfbs.reduce(0, +) / ttfbs.count
            return (model, avg)
        }
        .sorted { $0.1 < $1.1 }

        if let best = scored.first?.0 { return best }

        // Last resort: if Ollama is available and all cloud is down, use local model
        if ollamaAvailable, let ollama = bestOllamaModel() {
            cloudFallbackNotice = "Cloud unavailable, using local model: \(ollama.displayName)"
            return ollama
        }

        return nil
    }

    /// Full failover chain: returns ALL available alternatives sorted by speed.
    /// Excludes providers with open circuit breakers.
    /// Ollama models appear at the end as last-resort local fallback.
    func failoverChain(excluding: Set<String> = []) -> [AIModel] {
        let health = NetworkLog.shared.providerHealth
        let excluded = excluding.union([selectedModel.id])

        // Cloud models first, sorted by TTFB
        let cloudModels = availableModels
            .filter { model in
                !excluded.contains(model.id) &&
                model.provider != .ollama &&
                !model.isImageModel &&
                !NetworkLog.shared.isCircuitOpen(provider: model.provider.rawValue) &&
                (health[model.provider.rawValue]?.isUp ?? true)
            }
            .sorted { a, b in
                let aAvg = NetworkLog.shared.recentTTFB(for: a.id).isEmpty ? 1000 :
                    NetworkLog.shared.recentTTFB(for: a.id).reduce(0, +) / NetworkLog.shared.recentTTFB(for: a.id).count
                let bAvg = NetworkLog.shared.recentTTFB(for: b.id).isEmpty ? 1000 :
                    NetworkLog.shared.recentTTFB(for: b.id).reduce(0, +) / NetworkLog.shared.recentTTFB(for: b.id).count
                return aAvg < bAvg
            }

        // Append Ollama models at the end (local fallback)
        let ollamaModels = ollamaAvailable ? availableModels.filter { model in
            !excluded.contains(model.id) &&
            model.provider == .ollama &&
            !model.isImageModel
        } : []

        return cloudModels + ollamaModels
    }

    /// Parse rate limit headers from HTTP response
    func parseRateLimitHeaders(_ response: HTTPURLResponse, provider: AIProvider) {
        var remaining: Int?
        if let val = response.value(forHTTPHeaderField: "x-ratelimit-remaining-requests") {
            remaining = Int(val)
        } else if let val = response.value(forHTTPHeaderField: "x-ratelimit-remaining") {
            remaining = Int(val)
        }
        if let remaining {
            NetworkLog.shared.updateRateLimit(provider: provider.rawValue, remaining: remaining)
        }
    }
}
