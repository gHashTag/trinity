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
                .font(.system(size: 11))
                .foregroundStyle(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
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
            VStack(alignment: .leading, spacing: 8) {
                if let title = title {
                    HStack(spacing: 6) {
                        if let icon = icon {
                            Image(systemName: icon)
                                .font(.system(size: 11))
                        }
                        Text(title)
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                }

                Text(message)
                    .font(.system(size: 10))
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
                                .font(.system(size: 10))
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
            .shadow(color: .black.opacity(0.3), radius: 8)
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
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "info.circle.fill")
                        .font(.system(size: 12))
                    Text(title)
                        .font(.caption)
                        .underline()
                }
                .foregroundStyle(TrinityTheme.accent)
            }
            .buttonStyle(.plain)

            if isExpanded {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(TrinityTheme.textMuted)
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
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textMuted)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showTooltip) {
            Text(helpText)
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.textPrimary)
                .padding()
                .frame(width: 200)
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
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 3)
                            .fill(TrinityTheme.bgCardBorder)
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
        VStack(alignment: .leading, spacing: 16) {
            ForEach(sections) { section in
                VStack(alignment: .leading, spacing: 6) {
                    Text(section.title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    ForEach(section.items, id: \.self) { item in
                        HStack(spacing: 6) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 8))
                                .foregroundStyle(TrinityTheme.textMuted)
                            Text(item)
                                .font(.caption2)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
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
                .frame(width: 150)
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
            .frame(width: 250)
            .padding()

            HStack {
                Text("Field label")
                HelpButton(helpText: "This field controls the display format")
            }
            .padding()
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
