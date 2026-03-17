// Rich Text Input View
// Enhanced text input with markdown support, autocomplete, and validation

import SwiftUI
import AppKit

// MARK: - Rich Text Input View

struct RichTextInputView: View {
    @Binding var text: String
    let placeholder: String
    let maxLength: Int
    let showMarkdownPreview: Bool
    let onCommit: () -> Void
    
    @State private var showPreview = false
    @State private var showEmojiPicker = false
    @State private var isFocused = false
    @State private var draftKey = "rich_text_draft"
    @FocusState private var focus: Bool
    
    @State private var recentEmojis: [String] = ["👍", "❤️", "🎉", "🔥", "✅", "🚀", "💡", "👀"]
    
    var characterCount: Int { text.count }
    var wordCount: Int { text.components(separatedBy: .whitespacesAndNewlines).filter { !$0.isEmpty }.count }
    var isNearLimit: Bool { maxLength > 0 && characterCount > Int(Double(maxLength) * 0.9) }
    
    init(
        text: Binding<String>,
        placeholder: String = "Type your message...",
        maxLength: Int = 5000,
        showMarkdownPreview: Bool = true,
        onCommit: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.maxLength = maxLength
        self.showMarkdownPreview = showMarkdownPreview
        self.onCommit = onCommit
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Format toolbar
            if isFocused && !showPreview {
                formatToolbar
            }
            
            Divider().background(TrinityTheme.bgCardBorder)
            
            // Text editor or preview
            if showPreview {
                markdownPreview
            } else {
                textEditor
            }
            
            // Footer
            footer
        }
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(isFocused ? TrinityTheme.accent : TrinityTheme.bgCardBorder, lineWidth: 1)
        )
        .onAppear {
            loadDraft()
        }
        .onChange(of: text) { _, _ in
            saveDraft()
        }
        .onChange(of: focus) { _, newValue in
            isFocused = newValue
        }
    }
    
    private var textEditor: some View {
        NSTextViewWrapper(
            text: $text,
            placeholder: placeholder,
            font: .systemFont(ofSize: 14)
        )
        .focused($focus)
        .frame(minHeight: 120)
        .padding(12)
    }
    
    private var markdownPreview: some View {
        ScrollView {
            MarkdownTextView(text: text)
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minHeight: 120)
        .background(TrinityTheme.bgWindow.opacity(0.5))
    }
    
    private var formatToolbar: some View {
        HStack(spacing: 4) {
            formatButton("bold", icon: "bold") {
                insertFormat("**", "**")
            }
            
            formatButton("italic", icon: "italic") {
                insertFormat("_", "_")
            }
            
            formatButton("code", icon: "curlybraces") {
                insertFormat("`", "`")
            }
            
            formatButton("link", icon: "link") {
                insertFormat("[", "](url)")
            }
            
            Divider()
                .frame(height: 20)
            
            formatButton("quote", icon: "quote.opening") {
                insertPrefix("> ")
            }
            
            formatButton("list", icon: "list.bullet") {
                insertPrefix("- ")
            }
            
            formatButton("numbered list", icon: "list.number") {
                insertPrefix("1. ")
            }
            
            Divider()
                .frame(height: 20)
            
            Button {
                showEmojiPicker.toggle()
            } label: {
                Image(systemName: "face.smiling")
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .frame(width: 28, height: 24)
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showEmojiPicker) {
                emojiPicker
            }
            
            Spacer()
            
            if showMarkdownPreview {
                Button {
                    withAnimation {
                        showPreview.toggle()
                    }
                } label: {
                    Image(systemName: "eye")
                        .font(.system(size: 13))
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(TrinityTheme.bgCard)
    }
    
    private var footer: some View {
        HStack {
            // Character count
            Text("\(characterCount)\(maxLength > 0 ? "/\(maxLength)" : "")")
                .font(.caption2)
                .foregroundStyle(isNearLimit ? TrinityTheme.statusError : TrinityTheme.textMuted)
            
            // Word count
            if wordCount > 0 {
                Text("• \(wordCount) words")
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            
            Spacer()
            
            // Draft saved indicator
            if hasDraft {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                    Text("Draft")
                        .font(.caption2)
                }
                .foregroundStyle(TrinityTheme.accent.opacity(0.7))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(TrinityTheme.bgWindow.opacity(0.5))
    }
    
    private var emojiPicker: some View {
        VStack(spacing: 8) {
            // Recent emojis
            if !recentEmojis.isEmpty {
                HStack(spacing: 4) {
                    ForEach(recentEmojis, id: \.self) { emoji in
                        Button {
                            insertText(emoji)
                            showEmojiPicker = false
                        } label: {
                            Text(emoji)
                                .font(.system(size: 20))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                
                Divider()
            }
            
            // Common categories
            ScrollView([.horizontal]) {
                HStack(spacing: 12) {
                    emojiCategory("😀", ["😀", "😃", "😄", "😁", "😅", "😂", "🤣", "😊", "😇", "🙂", "😉", "😌"])
                    emojiCategory("❤️", ["❤️", "🧡", "💛", "💚", "💙", "💜", "🖤", "🤍", "🤎", "💔", "❣️", "💕"])
                    emojiCategory("👍", ["👍", "👎", "👏", "🙌", "🤝", "✌️", "🤞", "🤟", "🤘", "🤙", "👈", "👉"])
                    emojiCategory("🎉", ["🎉", "🎊", "🎈", "🎁", "🏆", "🥇", "🥈", "🥉", "🏅", "🎖️", "🎗️", "🎫"])
                    emojiCategory("🔥", ["🔥", "⭐", "🌟", "✨", "💫", "💥", "💢", "💯", "✅", "❌", "❗", "❓"])
                }
            }
        }
        .padding(12)
        .frame(width: 300)
    }
    
    private func emojiCategory(_ icon: String, _ emojis: [String]) -> some View {
        VStack(spacing: 4) {
            Button {
                insertText(icon)
                showEmojiPicker = false
            } label: {
                Text(icon)
                    .font(.system(size: 24))
            }
            .buttonStyle(.plain)
            
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 24))], spacing: 4) {
                ForEach(emojis, id: \.self) { emoji in
                    Button {
                        insertText(emoji)
                        showEmojiPicker = false
                    } label: {
                        Text(emoji)
                            .font(.system(size: 18))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
    
    private func formatButton(_ name: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(width: 28, height: 24)
        }
        .buttonStyle(.plain)
        .help(name)
    }
    
    private func insertFormat(_ prefix: String, _ suffix: String) {
        // Simple format insertion at cursor or selection
        insertText(prefix + suffix)
    }
    
    private func insertPrefix(_ prefix: String) {
        if let currentLine = text.components(separatedBy: .newlines).last {
            if !currentLine.hasPrefix(prefix) {
                insertText(prefix)
            }
        } else {
            insertText(prefix)
        }
    }
    
    private func insertText(_ insertion: String) {
        text += insertion
    }
    
    private var hasDraft: Bool {
        UserDefaults.standard.string(forKey: draftKey) != nil
    }
    
    private func loadDraft() {
        if let draft = UserDefaults.standard.string(forKey: draftKey), !text.isEmpty {
            text = draft
        }
    }
    
    private func saveDraft() {
        UserDefaults.standard.set(text.isEmpty ? nil : text, forKey: draftKey)
    }
    
    func clearDraft() {
        UserDefaults.standard.removeObject(forKey: draftKey)
    }
}

// MARK: - NSTextView Wrapper

struct NSTextViewWrapper: NSViewRepresentable {
    @Binding var text: String
    let placeholder: String
    let font: NSFont

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        let textView = NSTextView()

        textView.delegate = context.coordinator
        textView.font = font
        textView.textColor = NSColor(TrinityTheme.textPrimary)
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.textContainer?.lineFragmentPadding = 0

        scrollView.documentView = textView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false

        context.coordinator.textView = textView
        context.coordinator.textViewString = text

        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let textView = scrollView.documentView as? NSTextView else { return }

        if textView.string != text {
            textView.string = text
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: NSTextViewWrapper
        weak var textView: NSTextView?
        var textViewString: String = ""

        init(_ parent: NSTextViewWrapper) {
            self.parent = parent
        }

        func textDidChange(_ notification: Notification) {
            guard let textView = notification.object as? NSTextView else { return }
            parent.text = textView.string
        }
    }
}

// MARK: - Input Validator

struct InputValidator {
    let minLength: Int
    let maxLength: Int
    let allowedPattern: String?
    let customValidation: (String) -> String?
    
    init(
        minLength: Int = 0,
        maxLength: Int = 5000,
        allowedPattern: String? = nil,
        customValidation: @escaping (String) -> String? = { _ in nil }
    ) {
        self.minLength = minLength
        self.maxLength = maxLength
        self.allowedPattern = allowedPattern
        self.customValidation = customValidation
    }
    
    func validate(_ input: String) -> String? {
        // Length check
        if input.count < minLength {
            return "Minimum \(minLength) characters required"
        }
        
        if input.count > maxLength {
            return "Maximum \(maxLength) characters allowed"
        }
        
        // Pattern check
        if let pattern = allowedPattern {
            let predicate = NSPredicate(format: "SELF MATCHES %@", pattern)
            if !predicate.evaluate(with: input) {
                return "Invalid format"
            }
        }
        
        // Custom validation
        return customValidation(input)
    }
}

// MARK: - Input Field with Validation

struct ValidatedInputField: View {
    let title: String
    @Binding var text: String
    let validator: InputValidator
    let isSecure: Bool
    
    @State private var error: String?
    @State private var showError = false
    
    init(
        title: String,
        text: Binding<String>,
        validator: InputValidator,
        isSecure: Bool = false
    ) {
        self.title = title
        self._text = text
        self.validator = validator
        self.isSecure = isSecure
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
            
            if isSecure {
                SecureField(title, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) { _, _ in
                        validate()
                    }
            } else {
                TextField(title, text: $text)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: text) { _, _ in
                        validate()
                    }
            }
            
            if let error = error, showError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption2)
                    Text(error)
                        .font(.caption)
                }
                .foregroundStyle(TrinityTheme.statusError)
                .transition(.opacity)
            }
        }
    }
    
    private func validate() {
        error = validator.validate(text)
        withAnimation {
            showError = error != nil
        }
    }
}

// MARK: - Preview

struct RichTextInputView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            RichTextInputView(
                text: .constant(""),
                placeholder: "Type your message..."
            )
            .frame(width: 500, height: 200)
            .previewDisplayName("Empty")
            
            RichTextInputView(
                text: .constant("# Hello World\n\nThis is **bold** and this is *italic*.\n\n- List item 1\n- List item 2"),
                placeholder: "Type your message...",
                showMarkdownPreview: true
            )
            .frame(width: 500, height: 300)
            .previewDisplayName("With Markdown")
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
