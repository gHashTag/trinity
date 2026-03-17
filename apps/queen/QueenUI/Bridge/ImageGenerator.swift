import Foundation
import AppKit

/// xAI Grok Aurora image generation client
@MainActor
class ImageGenerator: ObservableObject {
    static let shared = ImageGenerator()

    @Published var isGenerating = false
    @Published var lastError: String?

    struct GeneratedImage {
        let url: String
        let revisedPrompt: String?
    }

    /// Generate images via xAI Grok API
    /// Returns array of image URLs
    func generate(
        prompt: String,
        count: Int = 1,
        key: String
    ) async throws -> [GeneratedImage] {
        isGenerating = true
        defer { isGenerating = false }

        let body: [String: Any] = [
            "model": "grok-2-image",
            "prompt": prompt,
            "n": min(count, 4),
            "response_format": "url",
        ]

        let bodyData = try JSONSerialization.data(withJSONObject: body)

        var request = URLRequest(url: URL(string: "https://api.x.ai/v1/images/generations")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.httpBody = bodyData
        request.timeoutInterval = 60

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ImageGenError.invalidResponse
        }

        if http.statusCode != 200 {
            let errorBody = String(data: data, encoding: .utf8) ?? "unknown"
            lastError = "API \(http.statusCode): \(errorBody)"
            throw ImageGenError.apiError(http.statusCode, errorBody)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let dataArray = json["data"] as? [[String: Any]] else {
            throw ImageGenError.parseError
        }

        return dataArray.compactMap { item in
            guard let url = item["url"] as? String else { return nil }
            let revised = item["revised_prompt"] as? String
            return GeneratedImage(url: url, revisedPrompt: revised)
        }
    }

    enum ImageGenError: LocalizedError {
        case invalidResponse
        case apiError(Int, String)
        case parseError
        case noKey

        var errorDescription: String? {
            switch self {
            case .invalidResponse: return "Invalid response from xAI"
            case .apiError(let code, let msg): return "xAI API \(code): \(msg)"
            case .parseError: return "Failed to parse image response"
            case .noKey: return "XAI_API_KEY not set in .env"
            }
        }
    }
}

/// Downloads an image from URL and returns NSImage
func downloadImage(from urlString: String) async -> NSImage? {
    guard let url = URL(string: urlString) else { return nil }

    // Try with timeout and HTTP status validation
    var request = URLRequest(url: url)
    request.timeoutInterval = 15

    guard let (data, response) = try? await URLSession.shared.data(for: request) else { return nil }

    // Validate HTTP response
    if let httpResponse = response as? HTTPURLResponse {
        guard (200...299).contains(httpResponse.statusCode) else { return nil }
    }

    guard !data.isEmpty else { return nil }
    return NSImage(data: data)
}
