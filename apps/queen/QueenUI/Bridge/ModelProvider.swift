import Foundation
import SwiftUI

enum AIProvider: String, CaseIterable, Identifiable, Codable {
    case anthropic = "Anthropic"
    case zai = "z.ai"
    case perplexity = "Perplexity"
    case xai = "xAI"

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
        AIModel(id: "grok-3-latest", displayName: "Grok 3", provider: .xai),
        AIModel(id: "grok-2-image", displayName: "Grok Image", provider: .xai),
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
        default:           (inPrice, outPrice) = (3.0, 15.0)
        }
        return (Double(inputTokens) * inPrice + Double(outputTokens) * outPrice) / 1_000_000.0
    }
}

@MainActor
class ModelManager: ObservableObject {
    @Published var availableModels: [AIModel] = []
    @Published var selectedModel: AIModel
    let env: [String: String]

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
        }

        request.httpBody = body
        return request
    }

    var hasAnyKey: Bool { !availableModels.isEmpty }

    func providerHasKey(_ provider: AIProvider) -> Bool {
        availableModels.contains(where: { $0.provider == provider })
    }

    /// Get xAI API key directly (for image generation)
    var xaiKey: String? { env["XAI_API_KEY"] }

    /// Auto-failover: if selected provider is down, pick best available alternative
    /// Tries ALL providers, scored by recent TTFB (fastest first)
    func failoverModel() -> AIModel? {
        let health = NetworkLog.shared.providerHealth
        let currentProvider = selectedModel.provider.rawValue

        // If current provider is up, no failover needed
        if let status = health[currentProvider], status.isUp { return nil }

        // Find all candidates whose provider is up and has a key
        let candidates = availableModels.filter { model in
            model.id != selectedModel.id &&
            !model.isImageModel &&
            (health[model.provider.rawValue]?.isUp ?? true)
        }

        // Score by recent average TTFB (lower = better)
        let scored = candidates.map { model -> (AIModel, Int) in
            let ttfbs = NetworkLog.shared.recentTTFB(for: model.id)
            let avg = ttfbs.isEmpty ? 1000 : ttfbs.reduce(0, +) / ttfbs.count
            return (model, avg)
        }
        .sorted { $0.1 < $1.1 }

        return scored.first?.0
    }

    /// Full failover chain: returns ALL available alternatives sorted by speed
    func failoverChain(excluding: Set<String> = []) -> [AIModel] {
        let health = NetworkLog.shared.providerHealth
        let excluded = excluding.union([selectedModel.id])

        return availableModels
            .filter { model in
                !excluded.contains(model.id) &&
                !model.isImageModel &&
                (health[model.provider.rawValue]?.isUp ?? true)
            }
            .sorted { a, b in
                let aAvg = NetworkLog.shared.recentTTFB(for: a.id).isEmpty ? 1000 :
                    NetworkLog.shared.recentTTFB(for: a.id).reduce(0, +) / NetworkLog.shared.recentTTFB(for: a.id).count
                let bAvg = NetworkLog.shared.recentTTFB(for: b.id).isEmpty ? 1000 :
                    NetworkLog.shared.recentTTFB(for: b.id).reduce(0, +) / NetworkLog.shared.recentTTFB(for: b.id).count
                return aAvg < bAvg
            }
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
