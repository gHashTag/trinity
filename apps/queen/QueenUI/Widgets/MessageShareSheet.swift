import SwiftUI
import AppKit

// MARK: - Share Options

enum ShareOption: String, CaseIterable, Identifiable {
    case text = "Copy as Text"
    case markdown = "Copy as Markdown"
    case codeOnly = "Copy Code Only"
    case withCitations = "Copy with Citations"
    case file = "Save as File"
    case image = "Share to..."

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .text: return "doc.plaintext"
        case .markdown: return "doc.richtext"
        case .codeOnly: return "chevron.left.forwardslash.chevron.right"
        case .withCitations: return "link"
        case .file: return "arrow.down.doc"
        case .image: return "square.and.arrow.up"
        }
    }

    var accessibilityLabel: String {
        switch self {
        case .text: return "Copy message as plain text"
        case .markdown: return "Copy message with markdown formatting"
        case .codeOnly: return "Extract and copy only code blocks"
        case .withCitations: return "Copy message with citation links"
        case .file: return "Save message content to a file"
        case .image: return "Open native macOS share sheet"
        }
    }
}

// MARK: - Share Sheet View

struct MessageShareSheet: View {
    @Binding var isPresented: Bool
    let message: ChatMessage
    let onShare: (ShareOption) -> Void

    @State private var flashOpacity: Double = 0
    @State private var lastSharedOption: ShareOption?

    private var hasCodeBlocks: Bool {
        !extractCodeBlocks(from: message.text).isEmpty
    }

    private var hasCitations: Bool {
        !(message.citations?.isEmpty ?? true)
    }

    var body: some View {
        Menu {
            Button {
                performShare(.text)
            } label: {
                Label(ShareOption.text.rawValue, systemImage: ShareOption.text.icon)
            }
            .accessibilityLabel(ShareOption.text.accessibilityLabel)

            Button {
                performShare(.markdown)
            } label: {
                Label(ShareOption.markdown.rawValue, systemImage: ShareOption.markdown.icon)
            }
            .accessibilityLabel(ShareOption.markdown.accessibilityLabel)

            Button {
                performShare(.codeOnly)
            } label: {
                Label(ShareOption.codeOnly.rawValue, systemImage: ShareOption.codeOnly.icon)
            }
            .disabled(!hasCodeBlocks)
            .accessibilityLabel(ShareOption.codeOnly.accessibilityLabel)

            Divider()

            Button {
                performShare(.withCitations)
            } label: {
                Label(ShareOption.withCitations.rawValue, systemImage: ShareOption.withCitations.icon)
            }
            .disabled(!hasCitations)
            .accessibilityLabel(ShareOption.withCitations.accessibilityLabel)

            Divider()

            Button {
                performShare(.file)
            } label: {
                Label(ShareOption.file.rawValue, systemImage: ShareOption.file.icon)
            }
            .accessibilityLabel(ShareOption.file.accessibilityLabel)

            Button {
                performShare(.image)
            } label: {
                Label(ShareOption.image.rawValue, systemImage: ShareOption.image.icon)
            }
            .accessibilityLabel(ShareOption.image.accessibilityLabel)
        } label: {
            ZStack {
                Image(systemName: "square.and.arrow.up")
                    .foregroundColor(V4Color.textSecondary)
                    .opacity(flashOpacity > 0 ? 0 : 1)

                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(V4Color.success)
                    .opacity(flashOpacity)
            }
            .frame(width: 28, height: 28)
        }
        .menuStyle(.borderlessButton)
        .help("Share options")
        .onChange(of: isPresented) { _, newValue in
            if !newValue {
                flashOpacity = 0
                lastSharedOption = nil
            }
        }
    }

    private func performShare(_ option: ShareOption) {
        onShare(option)
        lastSharedOption = option

        withAnimation(.easeOut(duration: 0.15)) {
            flashOpacity = 1
        }

        Task {
            try? await Task.sleep(for: .milliseconds(200))
            await MainActor.run {
                withAnimation(.easeOut(duration: 0.3)) {
                    flashOpacity = 0
                }
            }
        }

        SoundCueManager.shared.playCopy()
    }

    // MARK: - Helper Functions

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
}

// MARK: - Share Sheet Wrapper (NSPopover)

struct ShareSheetWrapper: View {
    @Binding var isPresented: Bool
    let message: ChatMessage
    let onShare: (ShareOption) -> Void

    var body: some View {
        EmptyView()
            .sheet(isPresented: $isPresented) {
                ShareSheetContentView(message: message, onShare: onShare, isPresented: $isPresented)
            }
    }
}

private struct ShareSheetContentView: View {
    let message: ChatMessage
    let onShare: (ShareOption) -> Void
    @Binding var isPresented: Bool
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: ParietalSpacing.md) {
            Text("Share Message")
                .font(.headline)
                .foregroundColor(V4Color.textPrimary)

            Divider()

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                ShareOptionButton(option: .text, message: message) {
                    performShare(.text)
                }

                ShareOptionButton(option: .markdown, message: message) {
                    performShare(.markdown)
                }

                ShareOptionButton(option: .codeOnly, message: message) {
                    performShare(.codeOnly)
                }

                ShareOptionButton(option: .withCitations, message: message) {
                    performShare(.withCitations)
                }

                ShareOptionButton(option: .file, message: message) {
                    performShare(.file)
                }

                ShareOptionButton(option: .image, message: message) {
                    performShare(.image)
                }
            }
            .padding()

            Divider()

            Button("Cancel") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
        .frame(width: 400, height: 280)
        .background(V4Color.surface)
    }

    private func performShare(_ option: ShareOption) {
        onShare(option)
        dismiss()
    }
}

private struct ShareOptionButton: View {
    let option: ShareOption
    let message: ChatMessage
    let action: () -> Void

    private var isEnabled: Bool {
        switch option {
        case .codeOnly:
            return !extractCodeBlocks(from: message.text).isEmpty
        case .withCitations:
            return !(message.citations?.isEmpty ?? true)
        default:
            return true
        }
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: ParietalSpacing.sm) {
                Image(systemName: option.icon)
                    .font(WernickeTypography.size24)
                    .foregroundColor(isEnabled ? V4Color.accent : V4Color.textSecondary)

                Text(option.rawValue)
                    .font(.caption)
                    .foregroundColor(V4Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .fill(V4Color.border.opacity(V2Depth.stateDisabled))
            )
        }
        .disabled(!isEnabled)
        .accessibilityLabel(option.accessibilityLabel)
    }
}

// MARK: - Native NSSharingServicePicker Bridge

struct NativeSharePicker: NSViewRepresentable {
    let items: [Any]
    let onComplete: () -> Void

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        view.isHidden = true
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            showSharingPicker()
        }
    }

    private func showSharingPicker() {
        guard let window = NSApp.keyWindow,
              let contentView = window.contentView else { return }

        let picker = NSSharingServicePicker(items: items)
        picker.show(relativeTo: CGRect(x: window.frame.midX, y: window.frame.midY, width: 1, height: 1),
                     of: contentView,
                     preferredEdge: .minY)

        // Detect when picker is dismissed
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            onComplete()
        }
    }
}

// MARK: - Standalone Share Button

struct ShareButton: View {
    let message: ChatMessage
    let onShare: (ShareOption) -> Void

    @State private var isShowingSheet = false

    var body: some View {
        MessageShareSheet(
            isPresented: $isShowingSheet,
            message: message,
            onShare: onShare
        )
    }
}

// MARK: - Context Menu Share Items

@ViewBuilder
func shareMenuItems(
    message: ChatMessage,
    onShare: @escaping (ShareOption) -> Void
) -> some View {
    Group {
        Button {
            onShare(.text)
            SoundCueManager.shared.playCopy()
        } label: {
            Label("Copy as Text", systemImage: "doc.plaintext")
        }
        .accessibilityLabel("Copy message as plain text")

        Button {
            onShare(.markdown)
            SoundCueManager.shared.playCopy()
        } label: {
            Label("Copy as Markdown", systemImage: "doc.richtext")
        }
        .accessibilityLabel("Copy message with markdown formatting")

        let codeBlocks = extractCodeBlocks(from: message.text)
        if !codeBlocks.isEmpty {
            Button {
                onShare(.codeOnly)
                SoundCueManager.shared.playCopy()
            } label: {
                Label("Copy Code Only", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .accessibilityLabel("Extract and copy only code blocks")
        }

        if let citations = message.citations, !citations.isEmpty {
            Button {
                onShare(.withCitations)
                SoundCueManager.shared.playCopy()
            } label: {
                Label("Copy with Citations", systemImage: "link")
            }
            .accessibilityLabel("Copy message with citation links")
        }

        Divider()

        Button {
            onShare(.file)
            SoundCueManager.shared.playCopy()
        } label: {
            Label("Save as File", systemImage: "arrow.down.doc")
        }
        .accessibilityLabel("Save message content to a file")

        Button {
            onShare(.image)
        } label: {
            Label("Share to...", systemImage: "square.and.arrow.up")
        }
        .accessibilityLabel("Open native macOS share sheet")
    }
}

// MARK: - Helper Functions

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
