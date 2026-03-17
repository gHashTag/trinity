import Foundation
import SwiftUI

struct ChatThread: Identifiable, Codable {
    var id: UUID
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date
    var isPinned: Bool
    var tags: [String]
    var folderID: UUID?
    var personaID: UUID?
    var isArchived: Bool
    var summary: String?
    var customSystemPrompt: String?

    init(id: UUID = UUID(), title: String = "New Thread") {
        self.id = id
        self.title = title
        self.messages = []
        self.createdAt = Date()
        self.updatedAt = Date()
        self.isPinned = false
        self.tags = []
        self.folderID = nil
        self.personaID = nil
        self.isArchived = false
        self.summary = nil
        self.customSystemPrompt = nil
    }

    // Backwards-compatible decoding (existing threads lack pinned/tags/folderID/personaID)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        messages = try c.decode([ChatMessage].self, forKey: .messages)
        createdAt = try c.decode(Date.self, forKey: .createdAt)
        updatedAt = try c.decode(Date.self, forKey: .updatedAt)
        isPinned = try c.decodeIfPresent(Bool.self, forKey: .isPinned) ?? false
        tags = try c.decodeIfPresent([String].self, forKey: .tags) ?? []
        folderID = try c.decodeIfPresent(UUID.self, forKey: .folderID)
        personaID = try c.decodeIfPresent(UUID.self, forKey: .personaID)
        isArchived = try c.decodeIfPresent(Bool.self, forKey: .isArchived) ?? false
        summary = try c.decodeIfPresent(String.self, forKey: .summary)
        customSystemPrompt = try c.decodeIfPresent(String.self, forKey: .customSystemPrompt)
    }
}

// MARK: - Persona

struct Persona: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var icon: String
    var systemPrompt: String
    var modelID: String?
    var temperature: Double?

    init(name: String, icon: String, systemPrompt: String, modelID: String? = nil, temperature: Double? = nil) {
        self.id = UUID()
        self.name = name
        self.icon = icon
        self.systemPrompt = systemPrompt
        self.modelID = modelID
        self.temperature = temperature
    }

    static let builtIn: [Persona] = [
        Persona(name: "CTO", icon: "crown.fill", systemPrompt: "You are a CTO advisor. Be direct, focus on architecture, scalability, and technical debt. Flag risks early."),
        Persona(name: "Code Reviewer", icon: "magnifyingglass.circle", systemPrompt: "You are a senior code reviewer. Focus on bugs, security issues, performance problems, and style. Be constructive but thorough."),
        Persona(name: "Security Auditor", icon: "lock.shield", systemPrompt: "You are a security auditor. Identify vulnerabilities, suggest mitigations, check for OWASP top 10. Be paranoid."),
        Persona(name: "Doc Writer", icon: "doc.text", systemPrompt: "You are a technical writer. Write clear, concise documentation. Use examples. Target developer audience."),
        Persona(name: "Mentor", icon: "graduationcap", systemPrompt: "You are a patient programming mentor. Explain concepts clearly, use analogies, encourage learning. Never just give the answer — guide understanding."),
    ]
}

// MARK: - Prompt Template

struct PromptTemplate: Identifiable, Codable, Equatable {
    var id: UUID
    var title: String
    var body: String  // Contains {{variable}} placeholders
    var category: String
    var icon: String
    var isBuiltIn: Bool

    init(title: String, body: String, category: String, icon: String, isBuiltIn: Bool = false) {
        self.id = UUID()
        self.title = title
        self.body = body
        self.category = category
        self.icon = icon
        self.isBuiltIn = isBuiltIn
    }

    // Backwards-compatible decoding (existing templates lack isBuiltIn)
    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        body = try c.decode(String.self, forKey: .body)
        category = try c.decode(String.self, forKey: .category)
        icon = try c.decode(String.self, forKey: .icon)
        isBuiltIn = try c.decodeIfPresent(Bool.self, forKey: .isBuiltIn) ?? false
    }

    /// Extract variable names from {{variable}} placeholders
    var variables: [String] {
        let regex = try? NSRegularExpression(pattern: "\\{\\{(\\w+)\\}\\}")
        let matches = regex?.matches(in: body, range: NSRange(body.startIndex..., in: body)) ?? []
        return matches.compactMap { match in
            guard let range = Range(match.range(at: 1), in: body) else { return nil }
            return String(body[range])
        }
    }

    /// Substitute variables with values
    func substitute(_ values: [String: String]) -> String {
        var result = body
        for (key, value) in values {
            result = result.replacingOccurrences(of: "{{\(key)}}", with: value)
        }
        return result
    }

    static let builtIn: [PromptTemplate] = [
        PromptTemplate(title: "Review PR", body: "Review PR #{{number}}. Focus on bugs, security, and performance. Be thorough.", category: "Code", icon: "arrow.triangle.pull", isBuiltIn: true),
        PromptTemplate(title: "Write Tests", body: "Write comprehensive tests for {{file}}. Cover edge cases and error paths.", category: "Code", icon: "checkmark.circle", isBuiltIn: true),
        PromptTemplate(title: "Explain Code", body: "Explain how {{file}} works. Focus on the architecture and key design decisions.", category: "Code", icon: "questionmark.circle", isBuiltIn: true),
        PromptTemplate(title: "Debug Error", body: "I'm getting this error:\n```\n{{error}}\n```\nHelp me debug it.", category: "Debug", icon: "ladybug", isBuiltIn: true),
        PromptTemplate(title: "Refactor", body: "Refactor {{file}} to improve {{aspect}}. Keep the API stable.", category: "Code", icon: "arrow.triangle.2.circlepath", isBuiltIn: true),
        PromptTemplate(title: "Architecture Decision", body: "I need to decide between {{option_a}} and {{option_b}} for {{feature}}. Compare trade-offs.", category: "Design", icon: "square.3.layers.3d", isBuiltIn: true),
        PromptTemplate(title: "Write Docs", body: "Write documentation for {{module}}. Include usage examples and API reference.", category: "Docs", icon: "doc.text", isBuiltIn: true),
        PromptTemplate(title: "Performance Audit", body: "Analyze {{file}} for performance issues. Suggest optimizations with benchmarks.", category: "Debug", icon: "gauge.with.dots.needle.50percent", isBuiltIn: true),
        PromptTemplate(title: "Git Commit Message", body: "Write a commit message for these changes:\n{{changes}}", category: "Git", icon: "arrow.triangle.branch", isBuiltIn: true),
        PromptTemplate(title: "Issue Description", body: "Write a GitHub issue for: {{description}}. Include acceptance criteria and technical notes.", category: "Git", icon: "exclamationmark.circle", isBuiltIn: true),
    ]
}

// MARK: - Thread Folder

struct ThreadFolder: Identifiable, Codable, Equatable {
    var id: UUID
    var name: String
    var color: String  // hex string like "00FF88"
    var isCollapsed: Bool

    init(name: String, color: String = "00FF88") {
        self.id = UUID()
        self.name = name
        self.color = color
        self.isCollapsed = false
    }

    var swiftColor: Color {
        let hex = UInt32(color, radix: 16) ?? 0x00FF88
        return Color(hex: hex)
    }
}

/// Citation from search mode (Perplexity-style sources)
struct Citation: Codable, Identifiable {
    var id: String { url }
    let url: String
    let title: String?
    let domain: String?
}

/// Structured error kind for message-level error display
enum MessageErrorKind: String, Codable {
    case unauthorized       // 401 — bad/expired key
    case rateLimited        // 429 — rate limit
    case serverError        // 5xx
    case timeout            // connection or TTFB timeout
    case connectionFailed   // no network
    case contextOverflow    // too many tokens
    case cancelled          // user cancelled

    var icon: String {
        switch self {
        case .unauthorized: return "key.slash"
        case .rateLimited: return "clock.badge.exclamationmark"
        case .serverError: return "exclamationmark.icloud"
        case .timeout: return "clock.arrow.circlepath"
        case .connectionFailed: return "wifi.slash"
        case .contextOverflow: return "arrow.up.right.and.arrow.down.left"
        case .cancelled: return "xmark.circle"
        }
    }

    var label: String {
        switch self {
        case .unauthorized: return "API key invalid"
        case .rateLimited: return "Rate limited"
        case .serverError: return "Server error"
        case .timeout: return "Timed out"
        case .connectionFailed: return "No connection"
        case .contextOverflow: return "Context too long"
        case .cancelled: return "Cancelled"
        }
    }

    var color: Color {
        switch self {
        case .rateLimited, .timeout: return TrinityTheme.statusWarn
        default: return TrinityTheme.statusError
        }
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
    var ttfbMs: Int?
    var tokPerSec: Double?
    var outputTokens: Int?
    var totalMs: Int?
    var citations: [Citation]?
    var branchID: UUID?
    var branchIndex: Int?
    var thinkingText: String?
    var errorKind: MessageErrorKind?
    var feedbackCategory: String?

    enum Role: String, Codable {
        case user, assistant
    }

    /// Whether this message has a structured error
    var hasError: Bool { errorKind != nil }

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
        self.errorKind = nil
        self.feedbackCategory = nil
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
        errorKind = try c.decodeIfPresent(MessageErrorKind.self, forKey: .errorKind)
        feedbackCategory = try c.decodeIfPresent(String.self, forKey: .feedbackCategory)
    }
}
