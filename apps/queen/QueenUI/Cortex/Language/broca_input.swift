//
// Broca's Area — Speech Production
// Standardized text input for Trinity Queen UI
// φ² + 1/φ² = 3 = TRINITY
//

import SwiftUI

// MARK: - Broca Input

/// Broca's Area — Speech Production
///
/// Broca's area is responsible for speech production.
/// This component provides a standardized text input for Trinity Queen UI.
///
/// Features:
/// - Auto-focus on appear
/// - Placeholder text
/// - Submit on enter
/// - Respects accessibility preferences
/// - Consistent styling with V4 color tokens
public struct BrocaInput: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let isEnabled: Bool
    let isSecure: Bool

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Enter text...",
        onSubmit: @escaping () -> Void = {},
        isEnabled: Bool = true,
        isSecure: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.isEnabled = isEnabled
        self.isSecure = isSecure
    }

    public var body: some View {
        Group {
            if isSecure {
                SecureField("", text: $text)
                    .focused($isFocused)
            } else {
                TextField("", text: $text)
                    .focused($isFocused)
            }
        }
        .font(WernickeTypography.body)
        .foregroundStyle(V4Color.textPrimary)
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(V4Color.input)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isFocused ? V4Color.borderFocus : V4Color.border, lineWidth: 1)
        )
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.5)
        .onSubmit(onSubmit)
        .task {
            // Auto-focus on appear
            isFocused = true
        }
        .accessibilityLabel(placeholder)
        .accessibilityHint("Text field")
    }
}

// MARK: - Broca Text Area

/// Multi-line text input variant
public struct BrocaTextArea: View {
    @Binding var text: String
    let placeholder: String
    let axis: Axis
    let isEnabled: Bool

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Enter text...",
        axis: Axis = .vertical,
        isEnabled: Bool = true
    ) {
        self._text = text
        self.placeholder = placeholder
        self.axis = axis
        self.isEnabled = isEnabled
    }

    public var body: some View {
        TextEditor(text: $text)
            .font(WernickeTypography.body)
            .foregroundStyle(V4Color.textPrimary)
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
            .background(V4Color.input)
            .cornerRadius(V1Theme.cornerMedium)
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .stroke(isFocused ? V4Color.borderFocus : V4Color.border, lineWidth: 1)
            )
            .scrollContentBackground(.hidden)
            .disabled(!isEnabled)
            .opacity(isEnabled ? 1 : 0.5)
            .focused($isFocused)
            .task {
                isFocused = true
            }
            .overlay(
                Group {
                    if text.isEmpty {
                        Text(placeholder)
                            .font(WernickeTypography.body)
                            .foregroundStyle(V4Color.textSecondary)
                            .padding(.horizontal, ParietalSpacing.sm + 4)
                            .padding(.vertical, ParietalSpacing.xs + 4)
                            .allowsHitTesting(false)
                    }
                },
                alignment: .topLeading
            )
            .accessibilityLabel(placeholder)
            .accessibilityHint("Text area")
    }
}

// MARK: - Broca Search Input

/// Search input with icon
public struct BrocaSearchInput: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onChange: () -> Void

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSubmit: @escaping () -> Void = {},
        onChange: @escaping () -> Void = {}
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onChange = onChange
    }

    public var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: "magnifyingglass")
                .font(WernickeTypography.iconLabel)
                .foregroundStyle(V4Color.textSecondary)
                .frame(width: ParietalSpacing.icon)

            TextField("", text: $text)
                .focused($isFocused)
                .font(WernickeTypography.body)
                .foregroundStyle(V4Color.textPrimary)
                .onChange(of: text) { _, _ in
                    onChange()
                }
                .onSubmit(onSubmit)
                .task {
                    isFocused = true
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.iconLabel)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(V4Color.input)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isFocused ? V4Color.borderFocus : V4Color.border, lineWidth: 1)
        )
        .accessibilityLabel(placeholder)
        .accessibilityHint("Search field")
    }
}

// MARK: - Chat Input Bar (Compact)

/// Compact chat input bar - for Angular Gyrus chat screen
public struct BrocaChatInput: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: () -> Void
    let onAttach: () -> Void
    let isStreaming: Bool

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Type a message...",
        onSubmit: @escaping () -> Void = {},
        onAttach: @escaping () -> Void = {},
        isStreaming: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
        self.onAttach = onAttach
        self.isStreaming = isStreaming
    }

    public var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            // Attach button
            Button {
                onAttach()
            } label: {
                Image(systemName: "paperclip")
                    .font(WernickeTypography.size16)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)
            }
            .buttonStyle(.plain)

            // Text input
            TextField("", text: $text)
                .focused($isFocused)
                .font(WernickeTypography.body)
                .foregroundStyle(V4Color.textPrimary)
                .disabled(isStreaming)
                .onSubmit {
                    if !text.isEmpty {
                        onSubmit()
                    }
                }
                .task {
                    isFocused = true
                }

            if !text.isEmpty && !isStreaming {
                // Send button
                Button {
                    onSubmit()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(WernickeTypography.size20)
                        .foregroundStyle(V4Color.accent)
                }
                .buttonStyle(.plain)
            } else if isStreaming {
                // Loading indicator
                ProgressView()
                    .scaleEffect(MTMotion.entranceScale)
            }
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerXL)
                .fill(V4Color.surfaceElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerXL)
                .stroke(isFocused ? V4Color.borderFocus : V4Color.border, lineWidth: 1)
        )
        .accessibilityLabel("Chat input")
        .accessibilityHint("Type a message and press enter to send")
    }
}

// MARK: - Preview
// NOTE: Preview blocks removed for CLI build compatibility
