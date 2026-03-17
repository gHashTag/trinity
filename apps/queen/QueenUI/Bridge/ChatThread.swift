import Foundation

struct ChatThread: Identifiable, Codable {
    var id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var tags: [String]

    init(id: UUID = UUID(), title: String = "New Thread") {
        self.id = id
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.tags = []
    }

    // Backwards-compatible decoding (existing threads lack pinned/tags)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        messages = try c.decode([ChatMessage].self, forKey: .messages)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
    }
}

/// Citation from search mode (Perplexity-style sources)
struct Citation: Codable, Identifiable {
    var id: String { url }
    let url: String
    let title: String?
    let domain: String?
}

struct ChatMessage: Identifiable, Codable {
    var id: UUID
    let role: Role
    var text: String
    let timestamp: Date
    var modelID: String?
    var isLiked: Bool?
    var comments: [ChatMessage]?
    var imageURLs: [String]?
    var isBookmarked: Bool?
    var ttfbMs: Int?
    var tokPerSec: Double?
    var outputTokens: Int?
    var totalMs: Int?
    var citations: [Citation]?
    var branchID: UUID?
    var branchIndex: Int?
    var thinkingText: String?

    enum Role: String, Codable {
        case user, assistant
    }

    init(role: Role, text: String, modelID: String? = nil, imageURLs: [String]? = nil) {
        self.id = UUID()
        self.role = role
        self.text = text
        self.timestamp = Date()
        self.modelID = modelID
        self.isLiked = nil
        self.comments = nil
        self.imageURLs = imageURLs
        self.isBookmarked = nil
        self.ttfbMs = nil
        self.tokPerSec = nil
        self.outputTokens = nil
        self.totalMs = nil
        self.citations = nil
        self.branchID = nil
        self.branchIndex = nil
        self.thinkingText = nil
    }

    // Backwards-compatible decoding
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        role = try c.decode(Role.self, forKey: .role)
        text = try c.decode(String.self, forKey: .text)
        timestamp = try c.decode(Date.self, forKey: .timestamp)
        modelID = try c.decodeIfPresent(String.self, forKey: .modelID)
        isLiked = try c.decodeIfPresent(Bool.self, forKey: .isLiked)
        comments = try c.decodeIfPresent([ChatMessage].self, forKey: .comments)
        imageURLs = try c.decodeIfPresent([String].self, forKey: .imageURLs)
        isBookmarked = try c.decodeIfPresent(Bool.self, forKey: .isBookmarked)
        ttfbMs = try c.decodeIfPresent(Int.self, forKey: .ttfbMs)
        tokPerSec = try c.decodeIfPresent(Double.self, forKey: .tokPerSec)
        outputTokens = try c.decodeIfPresent(Int.self, forKey: .outputTokens)
        totalMs = try c.decodeIfPresent(Int.self, forKey: .totalMs)
        citations = try c.decodeIfPresent([Citation].self, forKey: .citations)
        branchID = try c.decodeIfPresent(UUID.self, forKey: .branchID)
        branchIndex = try c.decodeIfPresent(Int.self, forKey: .branchIndex)
        thinkingText = try c.decodeIfPresent(String.self, forKey: .thinkingText)
    }
}
