import SwiftUI

/// Modifier that adds smart autocomplete to any text input
/// Shows suggestion popup on @ and / triggers, handles Tab/Enter navigation
struct InputAutocompleteModifier: ViewModifier {
    @Binding var input: String
    @FocusState.Binding var focused: Bool
    @Binding var showPopup: Bool
    var onSelect: (String) -> Void

    @State private var cursorPosition: Int? = nil

    func body(content: Content) -> some View {
        ZStack(alignment: .topLeading) {
            content

            // Suggestion popup overlay
            if showPopup && focused {
                GeometryReader { geom in
                    SmartSuggestionPopup(
                        input: input,
                        cursorPosition: cursorPosition,
                        isPresented: $showPopup,
                        onSelect: { replacement in
                            applySuggestion(replacement)
                        }
                    )
                    .offset(y: 36) // Position below input
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(height: 200) // Reserve space for popup
            }
        }
        .onChange(of: input) { _, newValue in
            updatePopupState(for: newValue)
        }
        .onChange(of: focused) { _, newValue in
            if !newValue {
                showPopup = false
            }
        }
    }

    private func updatePopupState(for text: String) {
        // Check if we should show popup
        let shouldShow = shouldShowPopup(for: text)
        if !shouldShow && showPopup {
            showPopup = false
        } else if shouldShow && !showPopup && focused {
            showPopup = true
        }
    }

    private func shouldShowPopup(for text: String) -> Bool {
        // Show on @ or / when not empty after
        if text.contains("@") {
            if let atRange = text.range(of: "@", options: .backwards) {
                let afterAt = text[atRange.upperBound...]
                // Show popup if there's something after @ or just @
                return !afterAt.contains(" ") || afterAt.isEmpty
            }
        }
        if text.contains("/") {
            if let slashRange = text.range(of: "/", options: .backwards) {
                let afterSlash = text[slashRange.upperBound...]
                // Only show if / is at start of line or after space
                let beforeSlash = text[..<slashRange.lowerBound]
                let isStartOfLine = beforeSlash.isEmpty || beforeSlash.hasSuffix(" ") || beforeSlash.hasSuffix("\n")
                return isStartOfLine && !afterSlash.contains(" ")
            }
        }
        return false
    }

    private func applySuggestion(_ replacement: String) {
        // Replace the @mention or /command with the suggestion
        let text = input

        if let atRange = text.range(of: "@", options: .backwards) {
            let beforeAt = text[..<atRange.lowerBound]
            let afterAt = text[atRange.upperBound...]

            // Find the end of the current mention (space or end)
            let endIdx = afterAt.firstIndex(where: { $0.isWhitespace }) ?? afterAt.endIndex
            let mention = afterAt[..<endIdx]

            // If replacement starts with @, keep it; otherwise replace the mention part
            if replacement.hasPrefix("@") {
                input = String(beforeAt) + replacement + String(afterAt[endIdx...])
            } else {
                // Replace just the query part after @type:
                if mention.contains(":") {
                    if let colonIdx = mention.firstIndex(of: ":") {
                        let prefix = String(mention[...colonIdx])
                        input = String(beforeAt) + "@\(prefix):\(replacement)" + String(afterAt[endIdx...])
                    }
                } else {
                    input = String(beforeAt) + replacement + " " + String(afterAt[endIdx...])
                }
            }
        } else if let slashRange = text.range(of: "/", options: .backwards) {
            let beforeSlash = text[..<slashRange.lowerBound]
            let afterSlash = text[slashRange.upperBound...]

            let endIdx = afterSlash.firstIndex(where: { $0.isWhitespace }) ?? afterSlash.endIndex

            input = String(beforeSlash) + replacement + String(afterSlash[endIdx...])
        } else {
            // Just append
            input = text + " " + replacement
        }

        onSelect(replacement)
    }
}

extension View {
    /// Adds smart autocomplete popup to text input
    /// - Parameters:
    ///   - input: Binding to the text being edited
    ///   - focused: Focus state binding
    ///   - showPopup: Binding to control popup visibility
    ///   - onSelect: Callback when suggestion is selected
    func inputAutocomplete(
        input: Binding<String>,
        focused: FocusState<Bool>.Binding,
        showPopup: Binding<Bool>,
        onSelect: @escaping (String) -> Void
    ) -> some View {
        self.modifier(InputAutocompleteModifier(
            input: input,
            focused: focused,
            showPopup: showPopup,
            onSelect: onSelect
        ))
    }
}

// MARK: - Tab Key Handler for NSTextView

/// NSTextView subclass that handles Tab key for autocomplete
class AutocompleteTextView: NSTextView {
    var onTab: (() -> Void)?
    var onShiftTab: (() -> Void)?

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 48 { // Tab key
            if event.modifierFlags.contains(.shift) {
                onShiftTab?()
            } else {
                onTab?()
            }
            return
        }
        super.keyDown(with: event)
    }
}

/// NSRepresentable for NSTextField with custom tab handling
struct AutocompleteTextField: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String
    var onSubmit: () -> Void
    var onTab: (() -> Void)?
    var onShiftTab: (() -> Void)?
    var onFocusChange: ((Bool) -> Void)?
    @FocusState.Binding var focused: Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = AutocompleteTextView()
        textView.delegate = context.coordinator
        textView.font = .systemFont(ofSize: 15)
        textView.textColor = .white
        textView.backgroundColor = .clear
        textView.isEditable = true
        textView.isSelectable = true
        textView.defaultParagraphStyle = .default
        textView.textContainer?.lineFragmentPadding = 0
        textView.textContainerInset = NSSize(width: 8, height: 8)

        // Handle Tab for autocomplete
        textView.onTab = onTab
        textView.onShiftTab = onShiftTab

        scrollView.documentView = textView

        // Set placeholder
        context.coordinator.placeholder = placeholder

        DispatchQueue.main.async {
            context.coordinator.textView = textView
            textView.string = text
        }

        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        guard let textView = nsView.documentView as? AutocompleteTextView else { return }

        if textView.string != text {
            let selectedRange = textView.selectedRange()
            textView.string = text
            textView.setSelectedRange(selectedRange)
        }

        context.coordinator.placeholder = placeholder
        context.coordinator.onSubmit = onSubmit
        context.coordinator.onFocusChange = onFocusChange
    }

    class Coordinator: NSObject, NSTextViewDelegate {
        var parent: AutocompleteTextField
        weak var textView: AutocompleteTextView?
        var placeholder: String = ""
        var onSubmit: () -> Void = {}
        var onFocusChange: ((Bool) -> Void)?

        init(_ parent: AutocompleteTextField) {
            self.parent = parent
            super.init()
        }

        func textDidChange(_ notification: Notification) {
            parent.text = textView?.string ?? ""
        }

        func textView(_ textView: NSTextView, doCommandBy commandSelector: Selector) -> Bool {
            if commandSelector == #selector(NSResponder.insertNewline(_:)) {
                // Enter without modifier = submit
                if NSEvent.modifierFlags.contains(.shift) {
                    return false // Allow default (newline)
                } else {
                    onSubmit()
                    return true // Prevent default
                }
            }
            if commandSelector == #selector(NSResponder.insertTab(_:)) {
                // Tab handled by AutocompleteTextView
                return true
            }
            return false
        }

        func textDidBeginEditing(_ notification: Notification) {
            onFocusChange?(true)
        }

        func textDidEndEditing(_ notification: Notification) {
            onFocusChange?(false)
        }
    }
}
