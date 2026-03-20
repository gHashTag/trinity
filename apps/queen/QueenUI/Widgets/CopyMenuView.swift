import SwiftUI
import AppKit

// MARK: - Copy Action Types

enum CopyAction: String, CaseIterable {
    case markdown = "Copy as Markdown"
    case plainText = "Copy Plain Text"
    case codeOnly = "Copy Code Only"
    case withCitations = "Copy with Citations"

    var icon: String {
        switch self {
        case .markdown: return "doc.richtext"
        case .plainText: return "doc.plaintext"
        case .codeOnly: return "chevron.left.forwardslash.chevron.right"
        case .withCitations: return "link"
        }
    }

    var tooltip: String {
        switch self {
        case .markdown: return "Copy preserving markdown formatting"
        case .plainText: return "Copy as plain text (strips formatting)"
        case .codeOnly: return "Extract and copy all code blocks"
        case .withCitations: return "Copy with citation markers"
        }
    }
}

// MARK: - Copy Menu View

struct CopyMenuView: View {
    let message: ChatMessage
    let onCopy: (String, CopyAction) -> Void
    @Binding var isShowing: Bool
    @Binding var didCopy: Bool
    @Binding var lastCopyAction: CopyAction?

    private var hasCodeBlocks: Bool {
        !extractCodeBlocks(from: message.text).isEmpty
    }

    private var hasCitations: Bool {
        !(message.citations?.isEmpty ?? true)
    }

    var body: some View {
        Menu {
            Button {
                performCopy(.markdown)
            } label: {
                Label(CopyAction.markdown.rawValue, systemImage: CopyAction.markdown.icon)
            }

            Button {
                performCopy(.plainText)
            } label: {
                Label(CopyAction.plainText.rawValue, systemImage: CopyAction.plainText.icon)
            }

            Button {
                performCopy(.codeOnly)
            } label: {
                Label(CopyAction.codeOnly.rawValue, systemImage: CopyAction.codeOnly.icon)
            }
            .disabled(!hasCodeBlocks)

            Divider()

            Button {
                performCopy(.withCitations)
            } label: {
                Label(CopyAction.withCitations.rawValue, systemImage: CopyAction.withCitations.icon)
            }
            .disabled(!hasCitations)
        } label: {
            Image(systemName: didCopy ? "checkmark" : "doc.on.doc")
                .foregroundColor(didCopy ? V4Color.success : V4Color.textSecondary)
        }
        .menuStyle(.borderlessButton)
        .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)
        .help("Copy options")
        .onChange(of: isShowing) { _, newValue in
            if !newValue {
                // Reset when menu closes
                didCopy = false
            }
        }
    }

    private func performCopy(_ action: CopyAction) {
        let content: String

        switch action {
        case .markdown:
            content = message.text

        case .plainText:
            content = stripMarkdown(from: message.text)

        case .codeOnly:
            let blocks = extractCodeBlocks(from: message.text)
            content = blocks.joined(separator: "\n\n")

        case .withCitations:
            content = addCitations(to: message.text, citations: message.citations ?? [])
        }

        onCopy(content, action)

        // Update UI state
        lastCopyAction = action
        didCopy = true

        // Reset after delay
        Task {
            try? await Task.sleep(for: .seconds(2))
            await MainActor.run {
                didCopy = false
            }
        }

        // Play sound
        SoundCueManager.shared.playCopy()
    }

    // MARK: - Helper Functions

    private func stripMarkdown(from text: String) -> String {
        var result = text

        // Remove code blocks but keep content
        result = result.replacingOccurrences(of: "```[\\w]*\\n([^`]*)```", with: "$1", options: .regularExpression)

        // Remove inline code
        result = result.replacingOccurrences(of: "`([^`]*)`", with: "$1", options: .regularExpression)

        // Remove headers
        result = result.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)

        // Remove bold/italic
        result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "__([^_]+)__", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)

        // Remove strikethrough
        result = result.replacingOccurrences(of: "~~([^~]+)~~", with: "$1", options: .regularExpression)

        // Remove links but keep text
        result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)

        // Clean up extra whitespace
        result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func extractCodeBlocks(from text: String) -> [String] {
        var blocks: [String] = []
        let lines = text.components(separatedBy: "\n")
        var inBlock = false
        var current: [String] = []

        for line in lines {
            if line.hasPrefix("```") {
                if inBlock {
                    blocks.append(current.joined(separator: "\n"))
                    current = []
                    inBlock = false
                } else {
                    inBlock = true
                }
            } else if inBlock {
                current.append(line)
            }
        }

        return blocks
    }

    private func addCitations(to text: String, citations: [Citation]) -> String {
        guard !citations.isEmpty else { return text }

        var result = text
        let citationSuffix = "\n\n---\n**Citations:**\n" + citations.enumerated().map { index, citation in
            let num = index + 1
            let display = citation.title ?? citation.url
            return "[\(num)] \(display)"
        }.joined(separator: "\n")

        return result + citationSuffix
    }
}

// MARK: - Copy Button (Standalone)

struct CopyButton: View {
    let message: ChatMessage
    let onCopy: (String, CopyAction) -> Void

    @State private var isShowingMenu = false
    @State private var didCopy = false
    @State private var lastCopyAction: CopyAction?

    var body: some View {
        CopyMenuView(
            message: message,
            onCopy: onCopy,
            isShowing: $isShowingMenu,
            didCopy: $didCopy,
            lastCopyAction: $lastCopyAction
        )
    }
}

// MARK: - Compact Copy Action (for Context Menu)

@ViewBuilder
func copyActionMenuItems(
    message: ChatMessage,
    onCopy: @escaping (String) -> Void
) -> some View {
    Group {
        Button {
            onCopy(message.text)
            SoundCueManager.shared.playCopy()
        } label: {
            Label("Copy as Markdown", systemImage: "doc.richtext")
        }

        Button {
            onCopy(stripMarkdown(from: message.text))
            SoundCueManager.shared.playCopy()
        } label: {
            Label("Copy Plain Text", systemImage: "doc.plaintext")
        }

        let codeBlocks = extractCodeBlocks(from: message.text)
        if !codeBlocks.isEmpty {
            Button {
                onCopy(codeBlocks.joined(separator: "\n\n"))
                SoundCueManager.shared.playCopy()
            } label: {
                Label("Copy Code Only", systemImage: "chevron.left.forwardslash.chevron.right")
            }
        }

        if let citations = message.citations, !citations.isEmpty {
            Button {
                let withCitations = message.text + "\n\n---\n**Citations:**\n" +
                    citations.enumerated().map { "[\($0.offset + 1)] \($0.element.title ?? $0.element.url)" }
                        .joined(separator: "\n")
                onCopy(withCitations)
                SoundCueManager.shared.playCopy()
            } label: {
                Label("Copy with Citations", systemImage: "link")
            }
        }
    }
}

// MARK: - Helper for Context Menu Use

private func stripMarkdown(from text: String) -> String {
    var result = text

    // Remove code blocks but keep content
    result = result.replacingOccurrences(of: "```[\\w]*\\n([^`]*)```", with: "$1", options: .regularExpression)

    // Remove inline code
    result = result.replacingOccurrences(of: "`([^`]*)`", with: "$1", options: .regularExpression)

    // Remove headers
    result = result.replacingOccurrences(of: "^#{1,6}\\s+", with: "", options: .regularExpression)

    // Remove bold/italic
    result = result.replacingOccurrences(of: "\\*\\*([^*]+)\\*\\*", with: "$1", options: .regularExpression)
    result = result.replacingOccurrences(of: "\\*([^*]+)\\*", with: "$1", options: .regularExpression)
    result = result.replacingOccurrences(of: "__([^_]+)__", with: "$1", options: .regularExpression)
    result = result.replacingOccurrences(of: "_([^_]+)_", with: "$1", options: .regularExpression)

    // Remove strikethrough
    result = result.replacingOccurrences(of: "~~([^~]+)~~", with: "$1", options: .regularExpression)

    // Remove links but keep text
    result = result.replacingOccurrences(of: "\\[([^\\]]+)\\]\\([^)]+\\)", with: "$1", options: .regularExpression)

    // Clean up extra whitespace
    result = result.replacingOccurrences(of: "\\n{3,}", with: "\n\n", options: .regularExpression)

    return result.trimmingCharacters(in: .whitespacesAndNewlines)
}

private func extractCodeBlocks(from text: String) -> [String] {
    var blocks: [String] = []
    let lines = text.components(separatedBy: "\n")
    var inBlock = false
    var current: [String] = []

    for line in lines {
        if line.hasPrefix("```") {
            if inBlock {
                blocks.append(current.joined(separator: "\n"))
                current = []
                inBlock = false
            } else {
                inBlock = true
            }
        } else if inBlock {
            current.append(line)
        }
    }

    return blocks
}
