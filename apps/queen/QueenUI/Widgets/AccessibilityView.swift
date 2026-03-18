// Accessibility View — A11y Support Components
import SwiftUI

// MARK: - Accessibility Label

struct A11yLabel: View {
    let text: String
    let icon: String?

    var body: some View {
        HStack(spacing: 6) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.accent)
                    .accessibility(hidden: true)
            }

            Text(text)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textPrimary)
                .accessibilityLabel(text)
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Accessible Button

struct A11yButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    let a11yHint: String?

    init(
        title: String,
        icon: String? = nil,
        a11yHint: String? = nil,
        action: @escaping () -> Void
    ) {
        self.title = title
        self.icon = icon
        self.a11yHint = a11yHint
        self.action = action
    }

    var body: some View {
        Button {
            action()
        } label: {
            HStack(spacing: 6) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                }

                Text(title)
                    .font(.system(size: 14))
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityHint(a11yHint ?? "")
    }
}

// MARK: - Screen Reader Only

struct ScreenReaderOnly: View {
    let content: String

    var body: some View {
        Text(content)
            .font(.system(size: 0))
            .foregroundStyle(.clear)
            .accessibilityLabel(content)
    }
}

// MARK: - A11y Group

struct A11yGroup: View {
    let label: String
    let content: () -> AnyView

    init(label: String, @ViewBuilder content: @escaping () -> some View) {
        self.label = label
        self.content = { AnyView(content()) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
                .accessibilityAddTraits(.isHeader)

            content()
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(label)
    }
}

// MARK: - A11y Heading

struct A11yHeading: View {
    let title: String
    let level: HeadingLevel

    enum HeadingLevel {
        case h1, h2, h3, h4, h5, h6

        var fontSize: CGFloat {
            switch self {
            case .h1: return 24
            case .h2: return 20
            case .h3: return 18
            case .h4: return 16
            case .h5: return 14
            case .h6: return 12
            }
        }
    }

    var body: some View {
        Text(title)
            .font(.system(size: level.fontSize, weight: .semibold))
            .foregroundStyle(TrinityTheme.textPrimary)
            .accessibilityAddTraits(.isHeader)
            #if os(iOS)
            .accessibilityHeading(level.accessibilityLevel)
            #endif
    }

    #if os(iOS)
    var accessibilityLevel: AccessibilityHeadingLevel {
        switch self {
        case .h1: return .h1
        case .h2: return .h2
        case .h3: return .h3
        case .h4: return .h4
        case .h5: return .h5
        case .h6: return .h6
        }
    }
    #endif
}

// MARK: - A11y Live Region

struct A11yLiveRegion: View {
    let message: String
    let priority: Priority

    enum Priority {
        case polite, assertive
    }

    var body: some View {
        Text(message)
            .font(.system(size: 13))
            .foregroundStyle(TrinityTheme.textPrimary)
            #if os(iOS)
            .accessibilityLiveRegion(priority == .assertive ? .assertive : .polite)
            #endif
            .onAppear {
                #if os(macOS)
                NSAccessibility.post(element: message, notification: .announcementRequested)
                #endif
            }
    }
}

// MARK: - A11y Value Indicator

struct A11yValueIndicator: View {
    let label: String
    let value: String
    let minValue: String?
    let maxValue: String?

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)

            Spacer()

            Text(value)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textPrimary)
                .accessibilityLabel("\(label), \(value)")
                .accessibilityValue(accessibilityValueText)
        }
    }

    private var accessibilityValueText: String {
        if let min = minValue, let max = maxValue {
            return "\(value), range \(min) to \(max)"
        } else if let min = minValue {
            return "\(value), minimum \(min)"
        } else if let max = maxValue {
            return "\(value), maximum \(max)"
        }
        return value
    }
}

// MARK: - Skip Link

struct SkipLink: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button {
            action()
        } label: {
            Text(label)
                .font(.system(size: 14))
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(TrinityTheme.accent)
                .foregroundStyle(.white)
                .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Skip to main content")
    }
}

// MARK: - Focus Trap Container

struct FocusTrapContainer: View {
    let isFocused: Bool
    let content: () -> AnyView

    init(isFocused: Bool, @ViewBuilder content: @escaping () -> some View) {
        self.isFocused = isFocused
        self.content = { AnyView(content()) }
    }

    var body: some View {
        content()
            .focusSection()
            .accessibilityElement(children: .contain)
    }
}

// MARK: - A11y Image

struct A11yImage: View {
    let image: Image
    let label: String
    let isDecorative: Bool

    var body: some View {
        image
            .accessibilityLabel(isDecorative ? "" : label)
            .accessibilityHidden(isDecorative)
    }
}

// MARK: - A11y Progress

struct A11yProgress: View {
    let value: Double
    let total: Double
    let label: String

    var body: some View {
        ProgressView(value: value, total: total)
            .progressViewStyle(.linear)
            .accessibilityLabel(label)
            .accessibilityValue("\(Int(value/total * 100)) percent")
    }
}

// MARK: - Preview

struct AccessibilityView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                A11yHeading(title: "Accessibility Components", level: .h1)

                A11yGroup(label: "Buttons") {
                    VStack(spacing: 8) {
                        A11yButton(title: "Save", icon: "checkmark", a11yHint: "Save your changes") {}
                        A11yButton(title: "Cancel", icon: "xmark", a11yHint: "Discard changes") {}
                    }
                }

                A11yValueIndicator(
                    label: "Progress",
                    value: "50%",
                    minValue: "0",
                    maxValue: "100"
                )
            }
            .padding()
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
