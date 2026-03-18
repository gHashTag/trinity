import Foundation
import AppKit

/// Markdown export utility for chat threads and messages.
/// Provides formatted markdown output with metadata preservation.
enum MarkdownExporter {

    // MARK: - Constants

    private static let trinityVersion = "2.0.3"
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd 'at' HH:mm"
        return formatter
    }()

    private static let exportDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        return formatter
    }()

    // MARK: - Public API

    /// Export a complete thread to markdown format.
    /// - Parameters:
    ///   - thread: The chat thread to export
    ///   - messages: Array of messages (can be thread.messages or filtered subset)
    /// - Returns: Formatted markdown string
    static func exportThreadToMarkdown(thread: ChatThread, messages: [ChatMessage]) -> String {
        var output = [String]()

        // Header
        output.append("# \(thread.title)")
        output.append("")

        // Metadata section
        output.append("## Thread Metadata")
        output.append("")
        output.append("| Property | Value |")
        output.append("|----------|-------|")
        output.append("| **Created** | \(dateFormatter.string(from: thread.createdAt)) |")
        output.append("| **Updated** | \(dateFormatter.string(from: thread.updatedAt)) |")
        output.append("| **Messages** | \(messages.count) |")
        output.append("| **Thread ID** | `\(thread.id.uuidString)` |")

        if thread.isPinned {
            output.append("| **Pinned** | Yes |")
        }

        if !thread.tags.isEmpty {
            output.append("| **Tags** | \(thread.tags.map { "`\($0)`" }.joined(separator: ", ")) |")
        }

        if let folderID = thread.folderID {
            output.append("| **Folder ID** | `\(folderID.uuidString)` |")
        }

        if let personaID = thread.personaID {
            output.append("| **Persona ID** | `\(personaID.uuidString)` |")
        }

        if let summary = thread.summary, !summary.isEmpty {
            output.append("| **Summary** | \(summary.replacingOccurrences(of: "|", with: "\\|")) |")
        }

        if let systemPrompt = thread.customSystemPrompt, !systemPrompt.isEmpty {
            let truncated = String(systemPrompt.prefix(100)) + (systemPrompt.count > 100 ? "..." : "")
            output.append("| **System Prompt** | \(truncated.replacingOccurrences(of: "|", with: "\\|")) |")
        }

        output.append("")
        output.append("---")
        output.append("")

        // Collect all citations for footnotes
        var allCitations: [Citation] = []
        for msg in messages {
            if let citations = msg.citations {
                allCitations.append(contentsOf: citations)
            }
        }

        // Messages section
        if messages.isEmpty {
            output.append("*No messages in this thread.*")
            output.append("")
        } else {
            output.append("## Conversation")
            output.append("")

            for (index, message) in messages.enumerated() {
                output.append(renderMessage(message, index: index))
                output.append("")
            }
        }

        // Citations section
        if !allCitations.isEmpty {
            output.append("---")
            output.append("")
            output.append("## Sources")
            output.append("")

            for (index, citation) in allCitations.enumerated() {
                output.append("[\(index + 1)] **\(citation.title ?? "Untitled")**")
                if let domain = citation.domain {
                    output.append("    - Domain: \(domain)")
                }
                output.append("    - URL: \(citation.url)")
                output.append("")
            }
        }

        // Footer
        output.append("---")
        output.append("")
        output.append(renderFooter())

        return output.joined(separator: "\n")
    }

    /// Export a single message to markdown format.
    /// - Parameter message: The message to export
    /// - Returns: Formatted markdown string
    static func exportSingleMessage(_ message: ChatMessage) -> String {
        var output = [String]()

        output.append("# Message Export")
        output.append("")

        // Metadata
        output.append("## Metadata")
        output.append("")
        output.append("| Property | Value |")
        output.append("|----------|-------|")
        output.append("| **Role** | \(message.role == .user ? "User" : "Assistant") |")
        output.append("| **Timestamp** | \(dateFormatter.string(from: message.timestamp)) |")
        output.append("| **Message ID** | `\(message.id.uuidString)` |")

        if let modelID = message.modelID {
            output.append("| **Model** | \(modelID) |")
        }

        if let ttfb = message.ttfbMs {
            output.append("| **TTFB** | \(ttfb) ms |")
        }

        if let tps = message.tokPerSec {
            output.append("| **Speed** | \(String(format: "%.1f", tps)) tok/s |")
        }

        if let outputTokens = message.outputTokens {
            output.append("| **Output Tokens** | \(outputTokens) |")
        }

        if let totalMs = message.totalMs {
            output.append("| **Total Time** | \(totalMs) ms |")
        }

        if let branchID = message.branchID {
            output.append("| **Branch ID** | `\(branchID.uuidString)` |")
            if let branchIndex = message.branchIndex {
                output.append("| **Branch Index** | \(branchIndex) |")
            }
        }

        if let errorKind = message.errorKind {
            output.append("| **Error** | \(errorKind.label) |")
        }

        if let feedback = message.feedbackCategory {
            output.append("| **Feedback** | \(feedback) |")
        }

        output.append("")

        // Thinking section
        if let thinking = message.thinkingText, !thinking.isEmpty {
            output.append("## Thinking")
            output.append("")
            output.append("```")
            output.append(thinking)
            output.append("```")
            output.append("")
        }

        // Content section
        output.append("## Content")
        output.append("")
        output.append(formatMessageContent(message.text))
        output.append("")

        // Citations
        if let citations = message.citations, !citations.isEmpty {
            output.append("---")
            output.append("")
            output.append("## Sources")
            output.append("")

            for (index, citation) in citations.enumerated() {
                output.append("[\(index + 1)] **\(citation.title ?? "Untitled")**")
                if let domain = citation.domain {
                    output.append("   - Domain: \(domain)")
                }
                output.append("   - URL: \(citation.url)")
                output.append("")
            }
        }

        // Footer
        output.append("---")
        output.append("")
        output.append(renderFooter())

        return output.joined(separator: "\n")
    }

    /// Save content to macOS clipboard.
    /// - Parameter content: The string content to copy
    /// - Returns: True if successful, false otherwise
    @discardableResult
    static func saveToClipboard(_ content: String) -> Bool {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        return pasteboard.setString(content, forType: .string)
    }

    /// Save content to a file.
    /// - Parameters:
    ///   - content: The string content to save
    ///   - filename: The filename (without extension)
    /// - Throws: File I/O errors
    static func saveToFile(_ content: String, filename: String) throws {
        let fileManager = FileManager.default

        // Get downloads directory
        guard let downloadsURL = fileManager.urls(for: .downloadsDirectory, in: .userDomainMask).first else {
            throw ExportError.couldNotAccessDownloads
        }

        // Ensure .md extension
        let sanitizedFilename = filename.trimmingCharacters(in: .illegalCharacters)
        let finalFilename = sanitizedFilename.hasSuffix(".md")
            ? sanitizedFilename
            : "\(sanitizedFilename).md"
        let fileURL = downloadsURL.appendingPathComponent(finalFilename)

        // Handle duplicate filenames
        var finalURL = fileURL
        var counter = 1
        while fileManager.fileExists(atPath: finalURL.path) {
            let base = (sanitizedFilename as NSString).deletingPathExtension
            let ext = (sanitizedFilename as NSString).pathExtension
            finalURL = downloadsURL.appendingPathComponent("\(base)-\(counter)).\(ext)")
            counter += 1
        }

        // Write file
        try content.write(to: finalURL, atomically: true, encoding: .utf8)
    }

    // MARK: - Private Helpers

    /// Render a single message with proper formatting.
    private static func renderMessage(_ message: ChatMessage, index: Int) -> String {
        var lines = [String]()

        let roleHeader = message.role == .user ? "### User" : "### Assistant"
        let timestamp = dateFormatter.string(from: message.timestamp)

        lines.append("#### \(roleHeader)")
        lines.append("")
        lines.append("**Time:** \(timestamp)")

        // Add model info for assistant messages
        if message.role == .assistant, let modelID = message.modelID {
            lines.append(" | **Model:** `\(modelID)`")
        } else {
            lines.append("  ")
        }

        lines.append("")

        // Add thinking block if present
        if let thinking = message.thinkingText, !thinking.isEmpty {
            lines.append("<details>")
            lines.append("<summary>Thinking Process</summary>")
            lines.append("")
            lines.append("```")
            lines.append(thinking)
            lines.append("```")
            lines.append("")
            lines.append("</details>")
            lines.append("")
        }

        // Add error banner if present
        if let errorKind = message.errorKind {
            lines.append("> [!ERROR] \(errorKind.label)")
            lines.append("> This message encountered an error during generation.")
            lines.append("")
        }

        // Add performance metrics for assistant messages
        if message.role == .assistant {
            var metrics: [String] = []
            if let ttfb = message.ttfbMs { metrics.append("TTFB: \(ttfb)ms") }
            if let tps = message.tokPerSec { metrics.append("Speed: \(String(format: "%.1f", tps)) tok/s") }
            if let tokens = message.outputTokens { metrics.append("Tokens: \(tokens)") }
            if let total = message.totalMs { metrics.append("Total: \(total)ms") }

            if !metrics.isEmpty {
                lines.append("*\(metrics.joined(separator: " • "))*")
                lines.append("")
            }
        }

        // Format main content
        lines.append(formatMessageContent(message.text))

        // Add citations inline
        if let citations = message.citations, !citations.isEmpty {
            lines.append("")
            lines.append("**Sources:**")
            for citation in citations {
                let title = citation.title ?? "Untitled"
                lines.append(" - [\(title)](\(citation.url))")
            }
        }

        return lines.joined(separator: "\n")
    }

    /// Format message content preserving code blocks and structure.
    private static func formatMessageContent(_ text: String) -> String {
        // Already formatted markdown - return as-is
        // The markdown is preserved from the original message
        return text
    }

    /// Render the footer with export metadata.
    private static func renderFooter() -> String {
        var lines = [String]()

        lines.append("*Exported on \(exportDateFormatter.string(from: Date()))*")
        lines.append("")
        lines.append("---")
        lines.append("")
        lines.append("<div align=\"center\">")
        lines.append("")
        lines.append("<small>Generated by [Trinity](https://github.com/gHashTag/trinity) v\(trinityVersion)")
        lines.append("Pure Zig Autonomous AI Agent Swarm</small>")
        lines.append("")
        lines.append("</div>")

        return lines.joined(separator: "\n")
    }
}

// MARK: - Errors

enum ExportError: LocalizedError {
    case couldNotAccessDownloads

    var errorDescription: String? {
        switch self {
        case .couldNotAccessDownloads:
            return "Could not access Downloads directory."
        }
    }
}

// MARK: - Character Set Extension

private extension CharacterSet {
    static let illegalCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
}
