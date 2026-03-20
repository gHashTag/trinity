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
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            HStack(spacing: ParietalSpacing.sm) {
                TextField(placeholder, text: $value)
                    .textFieldStyle(.plain)
                    .padding(.horizontal, ParietalSpacing.md)
                    .padding(.vertical, ParietalSpacing.sm + 2)
                    .background(
                        RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                            .fill(V4Color.surface)
                            .stroke(
                                showError ? V4Color.error :
                                    isFocused ? V4Color.accent :
                                        V4Color.border,
                                lineWidth: showError ? 2 : 1
                            )
                    )
                    .foregroundColor(V4Color.textPrimary)
                    .font(.system(size: WernickeTypography.bodySize()))
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
                        .font(WernickeTypography.size16)
                        .foregroundColor(isValid ? V4Color.success : V4Color.error)
                        .accessibilityLabel(isValid ? "Valid" : "Invalid")
                }
            }

            // Inline error message with animation
            if showError {
                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(WernickeTypography.size10)
                    Text(errorMessage)
                        .font(.system(size: WernickeTypography.captionSize()))
                }
                .foregroundColor(V4Color.error)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(MTMotion.quickSpring, value: showError)
        .animation(MTMotion.quickSpring, value: isFocused)
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
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack(spacing: ParietalSpacing.sm) {
                Group {
                    if isVisible {
                        TextField("Password", text: $value)
                    } else {
                        SecureField("Password", text: $value)
                    }
                }
                .textFieldStyle(.plain)
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm + 2)
                .background(
                    RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                        .fill(V4Color.surface)
                        .stroke(V4Color.border, lineWidth: 1)
                )
                .foregroundColor(V4Color.textPrimary)
                .font(.system(size: WernickeTypography.bodySize()))

                Button {
                    withAnimation(MTMotion.quickSpring) {
                        isVisible.toggle()
                    }
                } label: {
                    Image(systemName: isVisible ? "eye.slash.fill" : "eye.fill")
                        .font(WernickeTypography.size14)
                        .foregroundColor(V4Color.textSecondary)
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(isVisible ? "Hide password" : "Show password")
            }

            // Password strength indicator with animated bars
            if !value.isEmpty {
                HStack(spacing: ParietalSpacing.sm) {
                    Text("Strength:")
                        .font(.system(size: WernickeTypography.captionSize()))
                        .foregroundColor(V4Color.textSecondary)

                    strengthBar(for: .weak)
                    strengthBar(for: .medium)
                    strengthBar(for: .strong)
                    strengthBar(for: .secure)

                    Text(passwordStrength.label)
                        .font(.system(size: WernickeTypography.captionSize(), weight: .medium))
                        .foregroundColor(passwordStrength.color)
                        .transition(.scale.combined(with: .opacity))

                    Spacer()
                }
                .animation(MTMotion.standardSpring, value: passwordStrength)
            }
        }
    }

    @ViewBuilder
    private func strengthBar(for level: PasswordStrength) -> some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(passwordStrength >= level ? passwordStrength.color : Color.gray.opacity(V2Depth.stateHover))
            .frame(width: 32, height: 4)
    }

    enum PasswordStrength: Comparable {
        case weak
        case medium
        case strong
        case secure

        var color: Color {
            switch self {
            case .weak: return V4Color.error
            case .medium: return V4Color.warning
            case .strong: return Color.orange
            case .secure: return V4Color.success
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
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.sm + 2)
                .frame(minWidth: 80)
                .background(
                    Rectangle()
                        .fill(V4Color.surface)
                )
                .foregroundColor(V4Color.textPrimary)
                .font(.system(size: WernickeTypography.bodySize(), design: .monospaced))
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
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(V4Color.surface)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))
    }

    @ViewBuilder
    private func stepperButton(systemName: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(WernickeTypography.captionMedium)
                .foregroundColor(V4Color.textSecondary)
                .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)
                .background(
                    RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                        .fill(V4Color.border.opacity(V2Depth.stateDisabled))
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
        HStack(spacing: ParietalSpacing.sm + 2) {
            Image(systemName: "magnifyingglass")
                .font(WernickeTypography.size14)
                .foregroundColor(V4Color.textSecondary)

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundColor(V4Color.textPrimary)
                .font(.system(size: WernickeTypography.bodySize()))
                .focused($isFocused)
                .onSubmit {
                    onSubmit?()
                }

            if !text.isEmpty {
                Button {
                    withAnimation(MTMotion.quickSpring) {
                        text = ""
                    }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(WernickeTypography.size14)
                        .foregroundColor(V4Color.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(V4Color.surface)
                .stroke(
                    isFocused ? V4Color.accent : V4Color.border,
                    lineWidth: isFocused ? 2 : 1
                )
        )
        .animation(MTMotion.quickSpring, value: isFocused)
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
        VStack(alignment: .trailing, spacing: ParietalSpacing.sm - 2) {
            ZStack(alignment: .topLeading) {
                if text.isEmpty {
                    Text(placeholder)
                        .foregroundColor(V4Color.textSecondary.opacity(V1Theme.opacityTextSecondary))
                        .font(.system(size: WernickeTypography.bodySize()))
                        .padding(.horizontal, ParietalSpacing.md)
                        .padding(.vertical, ParietalSpacing.sm + 2)
                        .allowsHitTesting(false)
                }

                TextEditor(text: $text)
                    .font(.system(size: WernickeTypography.bodySize()))
                    .foregroundColor(V4Color.textPrimary)
                    .background(Color.clear)
                    .padding(.horizontal, ParietalSpacing.sm)
                    .padding(.vertical, ParietalSpacing.xs + 2)
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
                RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                    .fill(V4Color.surface)
                    .stroke(
                        isFocused ? V4Color.accent : V4Color.border,
                        lineWidth: isFocused ? 2 : 1
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerMedium))

            // Character count with color warning near limit
            if let maxLength = maxLength {
                HStack(spacing: ParietalSpacing.xs) {
                    Spacer()
                    Text("\(text.count)/\(maxLength)")
                        .font(.system(size: WernickeTypography.captionSize()))
                        .foregroundColor(textCountColor)
                        .animation(MTMotion.quickSpring, value: text.count)
                }
            }
        }
        .animation(MTMotion.quickSpring, value: isFocused)
    }

    private var textCountColor: Color {
        guard let maxLength = maxLength else { return V4Color.textSecondary }
        let percentage = Double(text.count) / Double(maxLength)
        if percentage >= 1.0 { return V4Color.error }
        if percentage >= 0.9 { return V4Color.warning }
        return V4Color.textSecondary
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
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            if let label = label {
                Text(label)
                    .font(.system(size: WernickeTypography.captionSize(), weight: .medium))
                    .foregroundColor(V4Color.textSecondary)
            }

            Button {
                withAnimation(MTMotion.standardSpring) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    Text(selection.isEmpty ? "Select..." : selection)
                        .foregroundColor(selection.isEmpty ? V4Color.textSecondary : V4Color.textPrimary)
                        .font(.system(size: WernickeTypography.bodySize()))

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(WernickeTypography.caption2Semibold)
                        .foregroundColor(V4Color.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm + 2)
                .background(
                    RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                        .fill(V4Color.surface)
                        .stroke(
                            isExpanded ? V4Color.accent : V4Color.border,
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
                            withAnimation(MTMotion.standardSpring) {
                                selection = option
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                Text(option)
                                    .foregroundColor(option == selection ? V4Color.accent : V4Color.textPrimary)
                                    .font(.system(size: WernickeTypography.bodySize()))
                                Spacer()
                                if option == selection {
                                    Image(systemName: "checkmark")
                                        .font(WernickeTypography.size12)
                                        .foregroundColor(V4Color.accent)
                                }
                            }
                            .padding(.horizontal, ParietalSpacing.md)
                            .padding(.vertical, ParietalSpacing.sm + 2)
                            .background(
                                option == selection ?
                                    V4Color.accent.opacity(V2Depth.bgSubtle) : Color.clear
                            )
                        }
                        .buttonStyle(.plain)

                        if option != options.last {
                            Divider()
                                .overlay(V4Color.border)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                        .fill(V4Color.surface)
                        .shadow(color: .black.opacity(V2Depth.stateHover), radius: 8, y: 2)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                        .stroke(V4Color.border, lineWidth: 1)
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
            VStack(spacing: ParietalSpacing.xl) {
                // ValidatedTextField
                VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
            Text("ValidatedTextField")
                .font(.system(size: WernickeTypography.headingSize(), weight: .semibold))
                .foregroundColor(V4Color.textPrimary)

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
            .overlay(V4Color.border)

        // SecurePasswordField
        VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
            Text("SecurePasswordField")
                .font(.system(size: WernickeTypography.headingSize(), weight: .semibold))
                .foregroundColor(V4Color.textPrimary)

            SecurePasswordField(value: .constant("weak"))
            SecurePasswordField(value: .constant("Medium123"))
            SecurePasswordField(value: .constant("Str0ng!Password#99"))
        }

        Divider()
            .overlay(V4Color.border)

        // NumericTextField
        VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
            Text("NumericTextField")
                .font(.system(size: WernickeTypography.headingSize(), weight: .semibold))
                .foregroundColor(V4Color.textPrimary)

            NumericTextField(value: .constant(50.0), min: 0, max: 100, step: 5)
            NumericTextField(value: .constant(1.5), min: -10, max: 10, step: 0.5)
            NumericTextField(value: .constant(0.75), min: 0, max: 1, step: 0.05)
        }

        Divider()
            .overlay(V4Color.border)

        // SearchField
        VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
            Text("SearchField")
                .font(.system(size: WernickeTypography.headingSize(), weight: .semibold))
                .foregroundColor(V4Color.textPrimary)

            SearchField(text: .constant(""), placeholder: "Search...")
            SearchField(text: .constant("query"), placeholder: "Search...")
        }

        Divider()
            .overlay(V4Color.border)

        // TextArea
        VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
            Text("TextArea")
                .font(.system(size: WernickeTypography.headingSize(), weight: .semibold))
                .foregroundColor(V4Color.textPrimary)

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
            .overlay(V4Color.border)

        // PickerField
        VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
            Text("PickerField")
                .font(.system(size: WernickeTypography.headingSize(), weight: .semibold))
                .foregroundColor(V4Color.textPrimary)

            PickerField(
                selection: .constant("Option 1"),
                options: ["Option 1", "Option 2", "Option 3"],
                label: "Choose an option"
            )
        }
    }
    .padding(24)
    .frame(width: 500, height: 900)
    .background(V4Color.background)
        }
    }
}
