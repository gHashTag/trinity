// Utility View — Helper Views and Utilities
import SwiftUI

// MARK: - Divider with Text

struct LabeledDivider: View {
    let label: String

    var body: some View {
        HStack {
            Rectangle()
                .fill(V4Color.border)
                .frame(height: 1)

            Text(label)
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
                .padding(.horizontal, ParietalSpacing.sm)

            Rectangle()
                .fill(V4Color.border)
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
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            if let title = title {
                Text(title)
                    .font(WernickeTypography.body14Semibold)
                    .foregroundStyle(V4Color.textPrimary)
            }

            content
        }
        .padding(ParietalSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .fill(backgroundColor ?? V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .stroke(V4Color.border, lineWidth: 1)
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
                    .fill(V4Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(V4Color.border, lineWidth: 1)
            )
            .shadow(color: .black.opacity(shadowRadius > 0 ? 0.1 : 0), radius: shadowRadius)
    }
}

// MARK: - Separator

struct Separator: View {
    let color: Color
    let thickness: CGFloat

    init(color: Color = V4Color.border, thickness: CGFloat = 1) {
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
                .font(WernickeTypography.miniBold)
                .foregroundStyle(.white)
                .padding(.horizontal, ParietalSpacing.xs + 2)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                        .fill(V4Color.error)
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

    init(color: Color = V4Color.accent, padding: EdgeInsets = EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12), @ViewBuilder content: @escaping () -> some View) {
        self.color = color
        self.padding = padding
        self.content = { AnyView(content()) }
    }

    var body: some View {
        content()
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(color.opacity(V2Depth.bgSidebarHover))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(color.opacity(V2Depth.stateDisabled), lineWidth: 1)
            )
    }
}

// MARK: - Tag

struct Tag: View {
    let text: String
    let color: Color
    let onRemove: (() -> Void)?

    init(_ text: String, color: Color = V4Color.accent, onRemove: (() -> Void)? = nil) {
        self.text = text
        self.color = color
        self.onRemove = onRemove
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Text(text)
                .font(WernickeTypography.size11)
                .foregroundStyle(color)

            if let onRemove = onRemove {
                Button {
                    onRemove()
                } label: {
                    Image(systemName: "xmark")
                        .font(WernickeTypography.size8)
                        .foregroundStyle(color)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                .fill(color.opacity(V2Depth.bgSidebarHover))
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
            case .info: return V4Color.info
            case .success: return V4Color.success
            case .warning: return V4Color.warning
            case .error: return V4Color.error
            }
        }
    }

    init(_ text: String, style: BadgeStyle = .info) {
        self.text = text
        self.style = style
    }

    var body: some View {
        Text(text)
            .font(WernickeTypography.miniMedium)
            .foregroundStyle(.white)
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xs)
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
            HStack(spacing: ParietalSpacing.xs) {
                Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                    .font(WernickeTypography.size11)

                Text(isCopied ? "Copied!" : "Copy")
                    .font(WernickeTypography.size11)
            }
            .foregroundStyle(isCopied ? V4Color.success : V4Color.textSecondary)
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
                Color.black.opacity(V1Theme.opacityTextTertiary)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isVisible.wrappedValue = false
                    }

                VStack(spacing: 0) {
                    if let title = title {
                        Text(title)
                            .font(WernickeTypography.body14Semibold)
                            .foregroundStyle(V4Color.textPrimary)
                            .padding(.top, 16)
                            .frame(maxWidth: .infinity)
                    }

                    if let message = message {
                        Text(message)
                            .font(WernickeTypography.size13)
                            .foregroundStyle(V4Color.textSecondary)
                            .padding(.vertical, ParietalSpacing.sm)
                            .frame(maxWidth: .infinity)
                    }

                    Divider()

                    ForEach(actions) { action in
                        Button {
                            action.action()
                            isVisible.wrappedValue = false
                        } label: {
                            Text(action.title)
                                .font(WernickeTypography.size13)
                                .foregroundStyle(action.style == .destructive ? V4Color.error : V4Color.accent)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, ParietalSpacing.md)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(V4Color.surface)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(V4Color.border, lineWidth: 1)
                )
                .padding(.horizontal, ParietalSpacing.xxl)
            }
        }
    }
}

// MARK: - Preview

struct UtilityView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
                LabeledDivider(label: "Utilities")

                SectionContainer("Tags") {
                    HStack(spacing: ParietalSpacing.sm) {
                        Tag("SwiftUI")
                        Tag("Animation")
                        Tag("Layout")
                    }
                }

                HStack(spacing: ParietalSpacing.md) {
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
        .background(V4Color.background)
    }
}
