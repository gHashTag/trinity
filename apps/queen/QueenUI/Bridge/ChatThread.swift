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
    }
}
