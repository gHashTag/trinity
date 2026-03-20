// Tooltip View — Contextual Help and Information
import SwiftUI

// MARK: - Tooltip

struct TooltipView: View {
    let content: String
    let position: Edge
    @Binding var isVisible: Bool

    enum Edge {
        case top, bottom, leading, trailing

        var alignment: Alignment {
            switch self {
            case .top: return .bottom
            case .bottom: return .top
            case .leading: return .trailing
            case .trailing: return .leading
            }
        }
    }

    init(
        content: String,
        position: Edge = .top,
        isVisible: Binding<Bool>
    ) {
        self.content = content
        self.position = position
        self._isVisible = isVisible
    }

    var body: some View {
        if isVisible {
            Text(content)
                .font(WernickeTypography.size11)
                .foregroundStyle(.white)
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xs)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(.black.opacity(0.85))
                )
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Tooltip Modifier

struct TooltipModifier: ViewModifier {
    let content: String
    let position: TooltipView.Edge
    @State private var isVisible = false

    func body(content: Content) -> some View {
        ZStack {
            content
                .onHover { hovering in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        isVisible = hovering
                    }
                }

            TooltipView(
                content: self.content,
                position: position,
                isVisible: $isVisible
            )
        }
    }
}

extension View {
    func tooltip(_ content: String, position: TooltipView.Edge = .top) -> some View {
        self.modifier(TooltipModifier(content: content, position: position))
    }
}

// MARK: - Rich Tooltip

struct RichTooltip: View {
    let title: String?
    let message: String
    let icon: String?
    let actions: [TooltipAction]
    @Binding var isVisible: Bool

    struct TooltipAction: Identifiable {
        let id = UUID()
        let title: String
        let action: () -> Void
    }

    init(
        title: String? = nil,
        message: String,
        icon: String? = nil,
        actions: [TooltipAction] = [],
        isVisible: Binding<Bool>
    ) {
        self.title = title
        self.message = message
        self.icon = icon
        self.actions = actions
        self._isVisible = isVisible
    }

    var body: some View {
        if isVisible {
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                if let title = title {
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(WernickeTypography.size11)
                        }
                        Text(title)
                            .font(WernickeTypography.miniSemibold)
                    }
                    .foregroundStyle(.white)
                }

                Text(message)
                    .font(WernickeTypography.size10)
                    .foregroundStyle(.white.opacity(0.9))

                if !actions.isEmpty {
                    Divider()
                        .background(.white.opacity(0.2))

                    ForEach(actions) { action in
                        Button {
                            action.action()
                            isVisible = false
                        } label: {
                            Text(action.title)
                                .font(WernickeTypography.size10)
                                .foregroundStyle(.white)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(.black.opacity(0.9))
            )
            .frame(maxWidth: 200)
            .shadow(color: .black.opacity(V2Depth.stateHover), radius: 8)
            .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - Inline Help

struct InlineHelp: View {
    let title: String
    let description: String
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: ParietalSpacing.xs) {
                    Image(systemName: "info.circle.fill")
                        .font(WernickeTypography.size12)
                    Text(title)
                        .font(.caption)
                        .underline()
                }
                .foregroundStyle(V4Color.accent)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
                    .transition(.opacity)
            }
        }
    }
}

// MARK: - Help Button

struct HelpButton: View {
    let helpText: String
    @State private var showTooltip = false

    var body: some View {
        Button {
            showTooltip.toggle()
        } label: {
            Image(systemName: "questionmark.circle")
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textSecondary)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTooltip) {
            Text(helpText)
                .font(WernickeTypography.size12)
                .foregroundStyle(V4Color.textPrimary)
                .padding()
                .frame(width: ParietalSpacing.xl * 8)
        }
    }
}

// MARK: - Keyboard Shortcut Hint

struct KeyboardShortcutTooltipHint: View {
    let shortcut: String

    var body: some View {
        HStack(spacing: 3) {
            ForEach(shortcut.components(separatedBy: "+"), id: \.self) { key in
                Text(key.uppercased())
                    .font(WernickeTypography.size9Mono.weight(.medium))
                    .foregroundStyle(V4Color.textSecondary)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(V4Color.border)
                    )
            }
        }
    }
}

// MARK: - Contextual Help

struct ContextualHelpView: View {
    let sections: [HelpSection]

    struct HelpSection: Identifiable {
        let id = UUID()
        let title: String
        let items: [String]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.lg) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
                    Text(section.title)
                        .font(WernickeTypography.miniSemibold)
                        .foregroundStyle(V4Color.textPrimary)

                    ForEach(section.items, id: \.self) { item in
                        HStack(spacing: ParietalSpacing.sm - 2) {
                            Image(systemName: "checkmark")
                                .font(WernickeTypography.size8)
                                .foregroundStyle(V4Color.textSecondary)
                            Text(item)
                                .font(.caption2)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    }
                }
            }
        }
        .padding(ParietalSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }
}

// MARK: - Preview

struct TooltipView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            Button("Hover me") {}
                .padding()
                .tooltip("This is a helpful tooltip")
                .frame(width: ParietalSpacing.panelWidth)
                .padding()

            ContextualHelpView(
                sections: [
                    ContextualHelpView.HelpSection(
                        title: "Keyboard Shortcuts",
                        items: ["⌘K - Command palette", "⌘/ - Search"]
                    ),
                    ContextualHelpView.HelpSection(
                        title: "Tips",
                        items: ["Press ESC to focus", "Use arrows to navigate"]
                    )
                ]
            )
            .frame(width: ParietalSpacing.xl * 10)
            .padding()

            HStack {
                Text("Field label")
                HelpButton(helpText: "This field controls the display format")
            }
            .padding()
        }
        .padding()
        .background(V4Color.background)
    }
}
