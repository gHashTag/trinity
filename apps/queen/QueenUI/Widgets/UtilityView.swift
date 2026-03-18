// Utility View — Helper Views and Utilities
import SwiftUI

// MARK: - Divider with Text

struct LabeledDivider: View {
    let label: String

    var body: some View {
        HStack {
            Rectangle()
                .fill(TrinityTheme.bgCardBorder)
                .frame(height: 1)

            Text(label)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
                .padding(.horizontal, 8)

            Rectangle()
                .fill(TrinityTheme.bgCardBorder)
                .frame(height: 1)
        }
    }
}

// MARK: - Spacer with Height

struct VSpacer: View {
    let height: CGFloat?

    init(_ height: CGFloat? = nil) {
        self.height = height
    }

    var body: some View {
        Spacer()
            .frame(height: height)
    }
}

// MARK: - Horizontal Padding

struct HPadding: View {
    let amount: CGFloat

    init(_ amount: CGFloat = 16) {
        self.amount = amount
    }

    var body: some View {
        HStack { Spacer().frame(width: amount) }
    }
}

// MARK: - Vertical Padding

struct VPadding: View {
    let amount: CGFloat

    init(_ amount: CGFloat = 16) {
        self.amount = amount
    }

    var body: some View {
        VStack { Spacer().frame(height: amount) }
    }
}

// MARK: - Inset Group

struct InsetGroup: View {
    let insets: EdgeInsets
    let content: () -> AnyView

    init(insets: EdgeInsets = EdgeInsets(top: 16, leading: 16, bottom: 16, trailing: 16), @ViewBuilder content: @escaping () -> some View) {
        self.insets = insets
        self.content = { AnyView(content()) }
    }

    var body: some View {
        content()
            .padding(insets)
    }
}

// MARK: - Section Container

struct SectionContainer<Content: View>: View {
    let title: String?
    let content: Content
    let backgroundColor: Color?

    init(
        _ title: String? = nil,
        backgroundColor: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.backgroundColor = backgroundColor
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title = title {
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)
            }

            content
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(backgroundColor ?? TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Card Container

struct CardContainer<Content: View>: View {
    let content: Content
    let cornerRadius: CGFloat
    let shadowRadius: CGFloat

    init(
        cornerRadius: CGFloat = 12,
        shadowRadius: CGFloat = 8,
        @ViewBuilder content: () -> Content
    ) {
        self.content = content()
        self.cornerRadius = cornerRadius
        self.shadowRadius = shadowRadius
    }

    var body: some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(TrinityTheme.bgCard)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
            )
            .shadow(color: .black.opacity(shadowRadius > 0 ? 0.1 : 0), radius: shadowRadius)
    }
}

// MARK: - Separator

struct Separator: View {
    let color: Color
    let thickness: CGFloat

    init(color: Color = TrinityTheme.bgCardBorder, thickness: CGFloat = 1) {
        self.color = color
        self.thickness = thickness
    }

    var body: some View {
        Rectangle()
            .fill(color)
            .frame(height: thickness)
    }
}

// MARK: - Badge Overlay

struct BadgeOverlay: View {
    let count: Int
    let position: BadgePosition

    enum BadgePosition {
        case topLeading, topTrailing, bottomLeading, bottomTrailing

        var alignment: Alignment {
            switch self {
            case .topLeading: return .topLeading
            case .topTrailing: return .topTrailing
            case .bottomLeading: return .bottomLeading
            case .bottomTrailing: return .bottomTrailing
            }
        }
    }

    var body: some View {
        if count > 0 {
            Text("\(count > 99 ? "99+" : "\(count)")")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(TrinityTheme.statusError)
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: position.alignment)
        }
    }
}

// MARK: - Capsule

struct Capsule: View {
    let content: () -> AnyView
    let color: Color
    let padding: EdgeInsets

    init(color: Color = TrinityTheme.accent, padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12), @ViewBuilder content: @escaping () -> some View) {
        self.color = color
        self.padding = padding
        self.content = { AnyView(content()) }
    }

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(0.15))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(0.5), lineWidth: 1)
            )
    }
}

// MARK: - Tag

struct Tag: View {
    let text: String
    let color: Color
    let onRemove: (() -> Void)?

    init(_ text: String, color: Color = TrinityTheme.accent, onRemove: (() -> Void)? = nil) {
        self.text = text
        self.color = color
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(color)

            if let onRemove = onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 8))
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(color.opacity(0.15))
        )
    }
}

// MARK: - Badge

struct Badge: View {
    let text: String
    let style: BadgeStyle

    enum BadgeStyle {
        case info, success, warning, error

        var color: Color {
            switch self {
            case .info: return Color(hex: 0x00D9FF)
            case .success: return TrinityTheme.statusOK
            case .warning: return TrinityTheme.statusWarn
            case .error: return TrinityTheme.statusError
            }
        }
    }

    init(_ text: String, style: BadgeStyle = .info) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(.system(size: 10, weight: .medium))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(style.color)
            )
    }
}

// MARK: - Quick Copy Button

struct QuickCopyButton: View {
    let text: String
    @State private var isCopied = false

    var body: some View {
        Button {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(text, forType: .string)

            withAnimation {
                isCopied = true
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                withAnimation {
                    isCopied = false
                }
            }
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(.system(size: 11))

                Text(isCopied ? "Copied!" : "Copy")
                    .font(.system(size: 11))
            }
            .foregroundStyle(isCopied ? TrinityTheme.statusOK : TrinityTheme.textMuted)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Action Sheet

struct ActionSheet: View {
    let title: String?
    let message: String?
    let actions: [Action]
    let isVisible: Binding<Bool>

    struct Action: Identifiable {
        let id = UUID()
        let title: String
        let style: ActionStyle
        let action: () -> Void

        enum ActionStyle {
            case normal, destructive, cancel
        }
    }

    var body: some View {
        if isVisible.wrappedValue {
            ZStack {
                Color.black.opacity(0.4)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isVisible.wrappedValue = false
                    }

                VStack(spacing: 0) {
                    if let title = title {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(TrinityTheme.textPrimary)
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity)
                    }

                    if let message = message {
                        Text(message)
                            .font(.system(size: 13))
                            .foregroundStyle(TrinityTheme.textMuted)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity)
                    }

                    Divider()

                    ForEach(actions) { action in
                        Button {
                            action.action()
                            isVisible.wrappedValue = false
                        } label: {
                            Text(action.title)
                                .font(.system(size: 13))
                                .foregroundStyle(action.style == .destructive ? TrinityTheme.statusError : TrinityTheme.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(TrinityTheme.bgCard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
                )
                .padding(.horizontal, 40)
            }
        }
    }
}

// MARK: - Preview

struct UtilityView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(alignment: .leading, spacing: 16) {
                LabeledDivider(label: "Utilities")

                SectionContainer("Tags") {
                    HStack(spacing: 8) {
                        Tag("SwiftUI")
                        Tag("Animation")
                        Tag("Layout")
                    }
                }

                HStack(spacing: 12) {
                    Badge("New", style: .info)
                    Badge("Success", style: .success)
                    Badge("Warning", style: .warning)
                    Badge("Error", style: .error)
                }

                QuickCopyButton(text: "Copy this text")
            }
            .padding()
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
