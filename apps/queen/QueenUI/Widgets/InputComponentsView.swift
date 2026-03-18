// MARK: - Input Components View
// Form Input Widgets for Queen UI
import SwiftUI

// MARK: - ValidatedTextField

/// Text field with real-time validation and inline error display.
/// Validates on focus loss and shows error state with message.
public struct ValidatedTextField: View {
    @Binding var value: String
    let placeholder: String
    let validation: (String) -> Bool
    let errorMessage: String

    @State private var isFocused: Bool = false
    @State private var hasEdited: Bool = false

    private var isValid: Bool {
        validation(value)
    }

    private var showError: Bool {
        hasEdited && !isValid && !value.isEmpty
    }

    public init(
        value: Binding<String>,
        placeholder: String,
        validation: @escaping (String) -> Bool,
        errorMessage: String
    ) {
        self._value = value
        self.placeholder = placeholder
        self.validation = validation
        self.errorMessage = errorMessage
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                TextField(placeholder, text: $value)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background(
                        RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                            .fill(TrinityTheme.bgCard)
                            .stroke(
                                showError ? TrinityTheme.statusError :
                                    isFocused ? TrinityTheme.accent :
                                        TrinityTheme.bgCardBorder,
                                lineWidth: showError ? 2 : 1
                            )
                    )
                    .foregroundColor(TrinityTheme.textPrimary)
                    .font(.system(size: TrinityTheme.bodySize()))
                    .onFocusChange { focused in
                        isFocused = focused
                        if !focused {
                            hasEdited = true
                        }
                    }
                    .onChange(of: value) { oldValue, newValue in
                        if hasEdited && !newValue.isEmpty {
                            // Validation triggers on edit after first submission
                        }
                    }

                // Validation status icon
                if hasEdited && !value.isEmpty {
                    Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(isValid ? TrinityTheme.statusOK : TrinityTheme.statusError)
                        .accessibilityLabel(isValid ? "Valid" : "Invalid")
                }
            }

            // Inline error message with animation
            if showError {
                HStack(spacing: 4) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10))
                    Text(errorMessage)
                        .font(.system(size: TrinityTheme.captionSize()))
                }
                .foregroundColor(TrinityTheme.statusError)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(TrinityTheme.quickSpring(), value: showError)
        .animation(TrinityTheme.quickSpring(), value: isFocused)
    }
}

// MARK: - SecurePasswordField

/// Secure password field with visibility toggle and strength indicator.
/// Shows 4-level strength indicator (weak/medium/strong/secure).
public struct SecurePasswordField: View {
    @Binding var value: String
    @State private var isVisible: Bool = false

    private var passwordStrength: PasswordStrength {
        PasswordStrength.calculate(value)
    }

    public init(value: Binding<String>) {
        self._value = value
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Group {
                    if isVisible {
                        TextField("Password", text: $value)
                    } else {
                        SecureField("Password", text: $value)
                    }
                }
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                        .fill(TrinityTheme.bgCard)
                        .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                )
                .foregroundColor(TrinityTheme.textPrimary)
                .font(.system(size: TrinityTheme.bodySize()))

                Button {
                    withAnimation(TrinityTheme.quickSpring()) {
                        isVisible.toggle()
                    }
                } label: {
                    Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                        .font(.system(size: 14))
                        .foregroundColor(TrinityTheme.textMuted)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isVisible ? "Hide password" : "Show password")
            }

            // Password strength indicator with animated bars
            if !value.isEmpty {
                HStack(spacing: 8) {
                    Text("Strength:")
                        .font(.system(size: TrinityTheme.captionSize()))
                        .foregroundColor(TrinityTheme.textMuted)

                    strengthBar(for: .weak)
                    strengthBar(for: .medium)
                    strengthBar(for: .strong)
                    strengthBar(for: .secure)

                    Text(passwordStrength.label)
                        .font(.system(size: TrinityTheme.captionSize(), weight: .medium))
                        .foregroundColor(passwordStrength.color)
                        .transition(.scale.combined(with: .opacity))

                    Spacer()
                }
                .animation(TrinityTheme.springAnimation(), value: passwordStrength)
            }
        }
    }

    @ViewBuilder
    private func strengthBar(for level: PasswordStrength) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(passwordStrength >= level ? passwordStrength.color : Color.gray.opacity(0.3))
            .frame(width: 32, height: 4)
    }

    enum PasswordStrength: Comparable {
        case weak
        case medium
        case strong
        case secure

        var color: Color {
            switch self {
            case .weak: return TrinityTheme.statusError
            case .medium: return TrinityTheme.statusWarn
            case .strong: return Color.orange
            case .secure: return TrinityTheme.statusOK
            }
        }

        var label: String {
            switch self {
            case .weak: return "Weak"
            case .medium: return "Medium"
            case .strong: return "Strong"
            case .secure: return "Secure"
            }
        }

        static func < (lhs: PasswordStrength, rhs: PasswordStrength) -> Bool {
            switch (lhs, rhs) {
            case (.weak, _): return rhs != .weak
            case (.medium, .strong), (.medium, .secure): return true
            case (.strong, .secure): return true
            default: return false
            }
        }

        static func calculate(_ password: String) -> PasswordStrength {
            guard !password.isEmpty else { return .weak }

            var score = 0
            if password.count >= 8 { score += 1 }
            if password.count >= 12 { score += 1 }
            if password.range(of: "[A-Z]", options: .regularExpression) != nil { score += 1 }
            if password.range(of: "[a-z]", options: .regularExpression) != nil { score += 1 }
            if password.range(of: "[0-9]", options: .regularExpression) != nil { score += 1 }
            if password.range(of: "[^A-Za-z0-9]", options: .regularExpression) != nil { score += 1 }

            switch score {
            case 0...2: return .weak
            case 3...4: return .medium
            case 5: return .strong
            default: return .secure
            }
        }
    }
}

// MARK: - NumericTextField

/// Numeric input field with increment/decrement buttons and range validation.
/// Supports min/max bounds and step increment.
public struct NumericTextField: View {
    @Binding var value: Double
    let min: Double?
    let max: Double?
    let step: Double
    let format: String

    @State private var textValue: String = ""
    @FocusState private var isFocused: Bool

    public init(
        value: Binding<Double>,
        min: Double? = nil,
        max: Double? = nil,
        step: Double = 1.0,
        format: String = "%.2f"
    ) {
        self._value = value
        self.min = min
        self.max = max
        self.step = step
        self.format = format
    }

    public var body: some View {
        HStack(spacing: 0) {
            // Decrement button
            stepperButton(systemName: "minus", action: decrement)
                .accessibilityLabel("Decrement")

            // Text field
            TextField("", text: $textValue)
                .textFieldStyle(.plain)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
                .padding(.vertical, 10)
                .frame(minWidth: 80)
                .background(
                    Rectangle()
                        .fill(TrinityTheme.bgCard)
                )
                .foregroundColor(TrinityTheme.textPrimary)
                .font(.system(size: TrinityTheme.bodySize(), design: .monospaced))
                .focused($isFocused)
                .onSubmit {
                    commitText()
                }
                .onChange(of: isFocused) { _, newValue in
                    if !newValue {
                        commitText()
                    }
                }
                .onChange(of: value) { _, newValue in
                    if !isFocused {
                        textValue = String(format: format, newValue)
                    }
                }
                .onAppear {
                    textValue = String(format: format, value)
                }

            // Increment button
            stepperButton(systemName: "plus", action: increment)
                .accessibilityLabel("Increment")
        }
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .fill(TrinityTheme.bgCard)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))
    }

    @ViewBuilder
    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(TrinityTheme.textMuted)
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                        .fill(TrinityTheme.bgCardBorder.opacity(0.5))
                )
        }
        .buttonStyle(.plain)
        .disabled(isAtLimit(for: systemName))
    }

    private func increment() {
        let newValue = value + step
        if let maximum = max {
            value = Swift.min(newValue, maximum)
        } else {
            value = newValue
        }
        textValue = String(format: format, value)
    }

    private func decrement() {
        let newValue = value - step
        if let minimum = min {
            value = Swift.max(newValue, minimum)
        } else {
            value = newValue
        }
        textValue = String(format: format, value)
    }

    private func commitText() {
        if let doubleValue = Double(textValue.replacingOccurrences(of: ",", with: ".")) {
            var newValue = doubleValue
            if let minimum = min { newValue = Swift.max(newValue, minimum) }
            if let maximum = max { newValue = Swift.min(newValue, maximum) }
            value = newValue
        }
        textValue = String(format: format, value)
    }

    private func isAtLimit(for systemName: String) -> Bool {
        if systemName == "minus", let minimum = min, value <= minimum { return true }
        if systemName == "plus", let maximum = max, value >= maximum { return true }
        return false
    }
}

// MARK: - SearchField

/// Search field with icon, clear button, and real-time filtering.
/// Focused state shows accent border.
public struct SearchField: View {
    @Binding var text: String
    let placeholder: String
    let onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSubmit: (() -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSubmit = onSubmit
    }

    public var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundColor(TrinityTheme.textMuted)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(TrinityTheme.textPrimary)
                .font(.system(size: TrinityTheme.bodySize()))
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    withAnimation(TrinityTheme.quickSpring()) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(TrinityTheme.textMuted)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .fill(TrinityTheme.bgCard)
                .stroke(
                    isFocused ? TrinityTheme.accent : TrinityTheme.bgCardBorder,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .animation(TrinityTheme.quickSpring(), value: isFocused)
    }
}

// MARK: - TextArea

/// Multi-line text input with character counter and line limit.
/// Supports placeholder and max character length with visual feedback.
public struct TextArea: View {
    @Binding var text: String
    let placeholder: String
    let lineLimit: ClosedRange<Int>
    let maxLength: Int?

    @State private var isFocused: Bool = false
    @FocusState private var isFocusedBinding: Bool

    public init(
        text: Binding<String>,
        placeholder: String = "",
        lineLimit: ClosedRange<Int> = 1...6,
        maxLength: Int? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.lineLimit = lineLimit
        self.maxLength = maxLength
    }

    public var body: some View {
        VStack(alignment: .trailing, spacing: 6) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(TrinityTheme.textMuted.opacity(0.6))
                        .font(.system(size: TrinityTheme.bodySize()))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(.system(size: TrinityTheme.bodySize()))
                    .foregroundColor(TrinityTheme.textPrimary)
                    .background(Color.clear)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .scrollContentBackground(.hidden)
                    .focused($isFocusedBinding)
                    .onChange(of: isFocusedBinding) { _, newValue in
                        isFocused = newValue
                    }
                    .onChange(of: text) { oldValue, newValue in
                        if let maxLength = maxLength, newValue.count > maxLength {
                            text = String(newValue.prefix(maxLength))
                        }
                    }
            }
            .frame(minHeight: CGFloat(lineLimit.lowerBound) * 20, maxHeight: CGFloat(lineLimit.upperBound) * 24)
            .background(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .fill(TrinityTheme.bgCard)
                    .stroke(
                        isFocused ? TrinityTheme.accent : TrinityTheme.bgCardBorder,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium))

            // Character count with color warning near limit
            if let maxLength = maxLength {
                HStack(spacing: 4) {
                    Spacer()
                    Text("\(text.count)/\(maxLength)")
                        .font(.system(size: TrinityTheme.captionSize()))
                        .foregroundColor(textCountColor)
                        .animation(TrinityTheme.quickSpring(), value: text.count)
                }
            }
        }
        .animation(TrinityTheme.quickSpring(), value: isFocused)
    }

    private var textCountColor: Color {
        guard let maxLength = maxLength else { return TrinityTheme.textMuted }
        let percentage = Double(text.count) / Double(maxLength)
        if percentage >= 1.0 { return TrinityTheme.statusError }
        if percentage >= 0.9 { return TrinityTheme.statusWarn }
        return TrinityTheme.textMuted
    }
}

// MARK: - PickerField

/// Custom dropdown picker with styled options and checkmark for selection.
/// Animated expansion with shadow.
public struct PickerField: View {
    @Binding var selection: String
    let options: [String]
    let label: String?

    @State private var isExpanded: Bool = false

    public init(
        selection: Binding<String>,
        options: [String],
        label: String? = nil
    ) {
        self._selection = selection
        self.options = options
        self.label = label
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let label = label {
                Text(label)
                    .font(.system(size: TrinityTheme.captionSize(), weight: .medium))
                    .foregroundColor(TrinityTheme.textMuted)
            }

            Button {
                withAnimation(TrinityTheme.springAnimation()) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Select..." : selection)
                        .foregroundColor(selection.isEmpty ? TrinityTheme.textMuted : TrinityTheme.textPrimary)
                        .font(.system(size: TrinityTheme.bodySize()))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(TrinityTheme.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                        .fill(TrinityTheme.bgCard)
                        .stroke(
                            isExpanded ? TrinityTheme.accent : TrinityTheme.bgCardBorder,
                            lineWidth: isExpanded ? 2 : 1
                        )
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label ?? "Picker")
            .accessibilityValue(selection)

            // Dropdown options
            if isExpanded {
                VStack(spacing: 0) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            withAnimation(TrinityTheme.springAnimation()) {
                                selection = option
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                Text(option)
                                    .foregroundColor(option == selection ? TrinityTheme.accent : TrinityTheme.textPrimary)
                                    .font(.system(size: TrinityTheme.bodySize()))
                                Spacer()
                                if option == selection {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 12))
                                        .foregroundColor(TrinityTheme.accent)
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                option == selection ?
                                    TrinityTheme.accent.opacity(0.1) : Color.clear
                            )
                        }
                        .buttonStyle(.plain)

                        if option != options.last {
                            Divider()
                                .overlay(TrinityTheme.bgCardBorder)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                        .fill(TrinityTheme.bgCard)
                        .shadow(color: .black.opacity(0.3), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                        .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                )
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Preview Provider

struct InputComponentsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 24) {
                // ValidatedTextField
                VStack(alignment: .leading, spacing: 16) {
            Text("ValidatedTextField")
                .font(.system(size: TrinityTheme.headingSize(), weight: .semibold))
                .foregroundColor(TrinityTheme.textPrimary)

            ValidatedTextField(
                value: .constant("test@email.com"),
                placeholder: "Email address",
                validation: { $0.contains("@") && $0.contains(".") },
                errorMessage: "Please enter a valid email address"
            )

            ValidatedTextField(
                value: .constant("invalid"),
                placeholder: "Email address",
                validation: { $0.contains("@") && $0.contains(".") },
                errorMessage: "Please enter a valid email address"
            )
        }

        Divider()
            .overlay(TrinityTheme.bgCardBorder)

        // SecurePasswordField
        VStack(alignment: .leading, spacing: 16) {
            Text("SecurePasswordField")
                .font(.system(size: TrinityTheme.headingSize(), weight: .semibold))
                .foregroundColor(TrinityTheme.textPrimary)

            SecurePasswordField(value: .constant("weak"))
            SecurePasswordField(value: .constant("Medium123"))
            SecurePasswordField(value: .constant("Str0ng!Password#99"))
        }

        Divider()
            .overlay(TrinityTheme.bgCardBorder)

        // NumericTextField
        VStack(alignment: .leading, spacing: 16) {
            Text("NumericTextField")
                .font(.system(size: TrinityTheme.headingSize(), weight: .semibold))
                .foregroundColor(TrinityTheme.textPrimary)

            NumericTextField(value: .constant(50.0), min: 0, max: 100, step: 5)
            NumericTextField(value: .constant(1.5), min: -10, max: 10, step: 0.5)
            NumericTextField(value: .constant(0.75), min: 0, max: 1, step: 0.05)
        }

        Divider()
            .overlay(TrinityTheme.bgCardBorder)

        // SearchField
        VStack(alignment: .leading, spacing: 16) {
            Text("SearchField")
                .font(.system(size: TrinityTheme.headingSize(), weight: .semibold))
                .foregroundColor(TrinityTheme.textPrimary)

            SearchField(text: .constant(""), placeholder: "Search...")
            SearchField(text: .constant("query"), placeholder: "Search...")
        }

        Divider()
            .overlay(TrinityTheme.bgCardBorder)

        // TextArea
        VStack(alignment: .leading, spacing: 16) {
            Text("TextArea")
                .font(.system(size: TrinityTheme.headingSize(), weight: .semibold))
                .foregroundColor(TrinityTheme.textPrimary)

            TextArea(
                text: .constant(""),
                placeholder: "Enter your message...",
                lineLimit: 3...6,
                maxLength: 200
            )

            TextArea(
                text: .constant("This is a pre-filled text area with some content already inside."),
                placeholder: "Enter your message...",
                lineLimit: 3...6,
                maxLength: 200
            )
        }

        Divider()
            .overlay(TrinityTheme.bgCardBorder)

        // PickerField
        VStack(alignment: .leading, spacing: 16) {
            Text("PickerField")
                .font(.system(size: TrinityTheme.headingSize(), weight: .semibold))
                .foregroundColor(TrinityTheme.textPrimary)

            PickerField(
                selection: .constant("Option 1"),
                options: ["Option 1", "Option 2", "Option 3"],
                label: "Choose an option"
            )
        }
    }
    .padding(24)
    .frame(width: 500, height: 900)
    .background(TrinityTheme.bgWindow)
        }
    }
}
