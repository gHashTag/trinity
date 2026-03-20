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
                            HStack(spacing: ParietalSpacing.xs) {
                                Image(systemName: action.icon)
                                Text(action.title)
                            }
                            .font(WernickeTypography.size13)
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
                .background(V4Color.surface)
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
                            HStack(spacing: ParietalSpacing.xs) {
                                Image(systemName: action.icon)
                                Text(action.title)
                            }
                            .font(WernickeTypography.size13)
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
                    VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                        Text(title)
                            .font(WernickeTypography.size14)
                            .foregroundStyle(V4Color.textPrimary)

                        if let subtitle = subtitle {
                            Text(subtitle)
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(WernickeTypography.size12)
                        .foregroundStyle(V4Color.textSecondary)
                        .rotationEffect(.degrees(isExpanded ? 90 : 0))
                }
                .padding(.horizontal, ParietalSpacing.lg)
                .padding(.vertical, ParietalSpacing.md)
            }
            .buttonStyle(.plain)

            if isExpanded {
                content
                    .padding(.horizontal, ParietalSpacing.lg)
                    .padding(.vertical, ParietalSpacing.md)
                    .background(V4Color.background)
                    .transition(.opacity)
            }
        }
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerBase)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(V4Color.border, lineWidth: 1)
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
            HStack(spacing: ParietalSpacing.md) {
                // Custom checkbox
                RoundedRectangle(cornerRadius: 4)
                    .fill(isChecked ? V4Color.accent : V4Color.border)
                    .frame(width: ParietalSpacing.icon + 4, height: ParietalSpacing.icon + 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(V4Color.border, lineWidth: 2)
                    )
                    .overlay {
                        if isChecked {
                            Image(systemName: "checkmark")
                                .font(WernickeTypography.captionBold)
                                .foregroundStyle(.white)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(WernickeTypography.size14)
                        .foregroundStyle(V4Color.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
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
            HStack(spacing: ParietalSpacing.md) {
                // Selection indicator
                Circle()
                    .stroke(isSelected ? V4Color.accent : V4Color.border, lineWidth: 2)
                    .frame(width: ParietalSpacing.icon + 4, height: ParietalSpacing.icon + 4)
                    .overlay {
                        if isSelected {
                            Circle()
                                .fill(V4Color.accent)
                                .frame(width: ParietalSpacing.sm, height: ParietalSpacing.sm)
                        }
                    }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(WernickeTypography.size14)
                        .foregroundStyle(isSelected ? V4Color.accent : V4Color.textPrimary)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
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
        HStack(spacing: ParietalSpacing.md) {
            Image(systemName: "line.3.horizontal")
                .font(WernickeTypography.size12)
                .foregroundStyle(V4Color.textSecondary)
                .opacity(V1Theme.opacityTextSecondary)

            content

            Spacer()
        }
        .padding(.horizontal, ParietalSpacing.lg)
        .padding(.vertical, ParietalSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(isDragging ? V4Color.accent.opacity(V2Depth.bgSubtle) : V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isDragging ? V4Color.accent : V4Color.border, lineWidth: isDragging ? 2 : 1)
        )
        .scaleEffect(isDragging ? 1.02 : 1)
        .gesture(
            DragGesture(minimumDistance: 20)
                .onChanged { _ in
                    isDragging = true
                }
                .onEnded { _ in
                    onDrag()
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
                                .font(WernickeTypography.caption2Semibold)
                                .foregroundStyle(V4Color.textSecondary)

                            Spacer()

                            Image(systemName: "chevron.right")
                                .font(WernickeTypography.size10)
                                .foregroundStyle(V4Color.textSecondary)
                                .rotationEffect(.degrees(section.isExpanded ? 90 : 0))
                        }
                        .padding(.horizontal, ParietalSpacing.lg)
                        .padding(.vertical, ParietalSpacing.sm)
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
                                                .font(WernickeTypography.size14)
                                                .foregroundStyle(V4Color.textPrimary)

                                            if let subtitle = item.subtitle {
                                                Text(subtitle)
                                                    .font(.caption)
                                                    .foregroundStyle(V4Color.textSecondary)
                                            }
                                        }

                                        Spacer()
                                    }
                                    .padding(.horizontal, ParietalSpacing.lg)
                                    .padding(.vertical, ParietalSpacing.md)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .background(V4Color.surface)
                .cornerRadius(V1Theme.cornerBase)
                .padding(.vertical, ParietalSpacing.xs)
            }
        }
    }
}

// MARK: - Preview

struct ListComponentsView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
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
        .background(V4Color.background)
    }
}
