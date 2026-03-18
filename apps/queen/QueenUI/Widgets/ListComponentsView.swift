// List Components View — Advanced List Rows
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Swipeable Row

struct SwipeableRow<Content: View>: View {
    let content: Content
    let leadingActions: [SwipeAction]
    let trailingActions: [SwipeAction]
    @State private var offset: CGFloat = 0
    @State private var isShowingLeading = false

    struct SwipeAction: Identifiable {
        let id = UUID()
        let title: String
        let icon: String
        let color: Color
        let action: () -> Void
    }

    init(
        leadingActions: [SwipeAction] = [],
        trailingActions: [SwipeAction] = [],
        @ViewBuilder content: () -> Content
    ) {
        self.leadingActions = leadingActions
        self.trailingActions = trailingActions
        self.content = content()
    }

    var body: some View {
        HStack(spacing: 0) {
            // Leading actions
            if !leadingActions.isEmpty {
                HStack(spacing: 0) {
                    ForEach(leadingActions) { action in
                        Button {
                            action.action()
                            withAnimation {
                                offset = 0
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: action.icon)
                                Text(action.title)
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(action.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: max(0, -offset))
                .clipped()
            }

            // Content
            content
                .background(TrinityTheme.bgCard)
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            if value.translation.width > 0 && !leadingActions.isEmpty {
                                offset = min(value.translation.width, 80)
                            } else if value.translation.width < 0 && !trailingActions.isEmpty {
                                offset = max(value.translation.width, -80)
                            }
                        }
                        .onEnded { value in
                            withAnimation {
                                if abs(value.translation.width) > 40 {
                                    if value.translation.width > 0 {
                                        offset = 80
                                    } else {
                                        offset = -80
                                    }
                                } else {
                                    offset = 0
                                }
                            }
                        }
                )

            // Trailing actions
            if !trailingActions.isEmpty {
                HStack(spacing: 0) {
                    ForEach(trailingActions) { action in
                        Button {
                            action.action()
                            withAnimation {
                                offset = 0
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: action.icon)
                                Text(action.title)
                            }
                            .font(.system(size: 13))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .background(action.color)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(width: max(0, offset))
                .clipped()
            }
        }
    }
}

// MARK: - Expandable Row

struct ExpandableRow<Content: View>: View {
    let title: String
    let subtitle: String?
    let content: Content
    @Binding var isExpanded: Bool

    init(
        title: String,
        subtitle: String? = nil,
        isExpanded: Binding<Bool>,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.subtitle = subtitle
        self._isExpanded = isExpanded
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title)
                            .font(.system(size: 14))
                            .foregroundStyle(TrinityTheme.textPrimary)

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundStyle(TrinityTheme.textMuted)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(TrinityTheme.bgWindow)
                    .transition(.opacity)
            }
        }
        .background(TrinityTheme.bgCard)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }
}

// MARK: - Checkable Row

struct CheckableRow: View {
    let title: String
    let subtitle: String?
    @Binding var isChecked: Bool

    var body: some View {
        Button {
            withAnimation {
                isChecked.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                // Custom checkbox
                RoundedRectangle(cornerRadius: 4)
                    .fill(isChecked ? TrinityTheme.accent : TrinityTheme.bgCardBorder)
                    .frame(width: 20, height: 20)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(TrinityTheme.bgCardBorder, lineWidth: 2)
                    )
                    .overlay {
                        if isChecked {
                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundStyle(TrinityTheme.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Selectable Row

struct SelectableRow: View {
    let title: String
    let subtitle: String?
    @Binding var isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button {
            action()
            withAnimation {
                isSelected.toggle()
            }
        } label: {
            HStack(spacing: 12) {
                // Selection indicator
                Circle()
                    .stroke(isSelected ? TrinityTheme.accent : TrinityTheme.bgCardBorder, lineWidth: 2)
                    .frame(width: 20, height: 20)
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(TrinityTheme.accent)
                                .frame(width: 12, height: 12)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 14))
                        .foregroundStyle(isSelected ? TrinityTheme.accent : TrinityTheme.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                }

                Spacer()
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - DnD List Row

struct DNDListRow<Content: View>: View {
    let content: Content
    let onDrag: () -> Void
    let onDrop: () -> Bool

    @State private var isDragging = false

    init(
        @ViewBuilder content: () -> Content,
        onDrag: @escaping () -> Void,
        onDrop: @escaping () -> Bool
    ) {
        self.content = content()
        self.onDrag = onDrag
        self.onDrop = onDrop
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "line.3.horizontal")
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.textMuted)
                .opacity(0.6)

            content

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDragging ? TrinityTheme.accent.opacity(0.1) : TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDragging ? TrinityTheme.accent : TrinityTheme.bgCardBorder, lineWidth: isDragging ? 2 : 1)
        )
        .scaleEffect(isDragging ? 1.02 : 1)
        .gesture(DragGesture(minimumDistance: 0)
            onChanged { _ in
                if isDragging {
                    onDrag()
                }
            }
        )
        .onDrop(of: [UTType.text], delegate: ListDropDelegate(onDrop: onDrop))
    }
}

struct ListDropDelegate: SwiftUI.DropDelegate {
    let onDrop: () -> Bool

    func performDrop(info: DropInfo) -> Bool {
        onDrop()
    }

    func validateDrop(info: DropInfo) -> Bool {
        return true
    }
}

// MARK: - Sectioned List

struct SectionedList: View {
    let sections: [ListSection]

    struct ListSection: Identifiable {
        let id = UUID()
        let title: String
        let items: [ListItem]
        let isCollapsible: Bool
        @State var isExpanded: Bool = true

        struct ListItem: Identifiable {
            let id = UUID()
            let title: String
            let subtitle: String?
            let action: () -> Void
        }
    }

    init(sections: [ListSection]) {
        self.sections = sections
    }

    var body: some View {
        VStack(spacing: 0) {
            ForEach(sections) { section in
                VStack(spacing: 0) {
                    // Section header
                    Button {
                        withAnimation {
                            section.isExpanded.toggle()
                        }
                    } label: {
                        HStack {
                            Text(section.title.uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(TrinityTheme.textMuted)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(.system(size: 10))
                                .foregroundStyle(TrinityTheme.textMuted)
                                .rotationEffect(.degrees(section.isExpanded ? 90 : 0))
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                    }
                    .buttonStyle(.plain)

                    // Section items
                    if section.isExpanded {
                        VStack(spacing: 0) {
                            ForEach(section.items) { item in
                                Button {
                                    item.action()
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.title)
                                                .font(.system(size: 14))
                                                .foregroundStyle(TrinityTheme.textPrimary)

                                            if let subtitle = item.subtitle {
                                                Text(subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(TrinityTheme.textMuted)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 12)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .background(TrinityTheme.bgCard)
                .cornerRadius(8)
                .padding(.vertical, 4)
            }
        }
    }
}

// MARK: - Preview

struct ListComponentsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: 20) {
                CheckableRow(
                    title: "Enable notifications",
                    subtitle: "Receive push notifications",
                    isChecked: .constant(true)
                )

                SelectableRow(
                    title: "Dark Mode",
                    subtitle: "Use dark theme",
                    isSelected: .constant(false),
                    action: {}
                )

                SectionedList(sections: [
                    SectionedList.ListSection(
                        title: "Account",
                        items: [
                            SectionedList.ListSection.ListItem(
                                title: "Profile",
                                subtitle: "Edit your profile",
                                action: {}
                            ),
                            SectionedList.ListSection.ListItem(
                                title: "Settings",
                                subtitle: "App preferences",
                                action: {}
                            )
                        ],
                        isCollapsible: true
                    )
                ])
            }
            .padding()
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
