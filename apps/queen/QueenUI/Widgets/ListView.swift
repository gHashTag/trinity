// List View — Enhanced List with Swipe Actions, Drag Reordering
import SwiftUI

// MARK: - List Item

struct ListItem<Content: View, Leading: View, Trailing: View>: View, Identifiable {
    let id: String
    let content: () -> Content
    let leading: () -> Leading
    let trailing: () -> Trailing
    let isSeparatorVisible: Bool
    let onTap: () -> Void
    let onSecondaryTap: () -> Void

    init(
        id: String,
        isSeparatorVisible: Bool = true,
        @ViewBuilder content: @escaping () -> Content,
        @ViewBuilder leading: @escaping () -> Leading,
        @ViewBuilder trailing: @escaping () -> Trailing,
        onTap: @escaping () -> Void = {},
        onSecondaryTap: @escaping () -> Void = {}
    ) {
        self.id = id
        self.isSeparatorVisible = isSeparatorVisible
        self.content = content
        self.leading = leading
        self.trailing = trailing
        self.onTap = onTap
        self.onSecondaryTap = onSecondaryTap
    }

    var body: some View {
        Button {
            onTap()
        } label: {
            HStack(spacing: ParietalSpacing.md) {
                leading()

                content()

                Spacer()

                trailing()
            }
            .padding(.horizontal, ParietalSpacing.lg)
            .padding(.vertical, ParietalSpacing.md)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .contextMenu {
            Button {
                onSecondaryTap()
            } label: {
                Text("More Options")
                Image(systemName: "ellipsis")
            }
        }
    }
}

// MARK: - Simple List Item

struct SimpleListItem: View, Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String?
    let badge: String?
    let isSelected: Bool

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        badge: String? = nil,
        isSelected: Bool = false
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.badge = badge
        self.isSelected = isSelected
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            // Icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(WernickeTypography.size18)
                    .foregroundStyle(isSelected ? V4Color.accent : V4Color.textSecondary)
                    .frame(width: 28)
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(isSelected ? WernickeTypography.body14Medium : WernickeTypography.size14)
                    .foregroundStyle(isSelected ? V4Color.accent : V4Color.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            Spacer()

            // Badge
            if let badge = badge {
                Text(badge)
                    .font(WernickeTypography.miniSemibold)
                    .foregroundStyle(.white)
                    .padding(.horizontal, ParietalSpacing.xs + 2)
                    .padding(.vertical, 2)
                    .background(V4Color.accent)
                    .cornerRadius(V1Theme.cornerTiny)
            }
        }
        .padding(.horizontal, ParietalSpacing.lg)
        .padding(.vertical, ParietalSpacing.sm + 2)
        .background(
            isSelected ? V4Color.accent.opacity(V2Depth.bgSubtle) : V4Color.surface
        )
        .overlay(
            Rectangle()
                .fill(isSelected ? V4Color.accent : .clear)
                .frame(width: ParietalSpacing.xxxs),
            alignment: .leading
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Swipeable List Item

struct SwipeableListItem<Content: View>: View, Identifiable {
    let id: String
    let content: () -> Content
    let leftActions: [SwipeAction]
    let rightActions: [SwipeAction]

    struct SwipeAction {
        let title: String
        let icon: String
        let color: Color
        let action: () -> Void

        init(title: String, icon: String, color: Color, action: @escaping () -> Void) {
            self.title = title
            self.icon = icon
            self.color = color
            self.action = action
        }
    }

    @State private var offset: CGFloat = 0
    @State private var isLeftSwiped = false
    @State private var isRightSwiped = false

    init(
        id: String,
        leftActions: [SwipeAction] = [],
        rightActions: [SwipeAction] = [],
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.id = id
        self.leftActions = leftActions
        self.rightActions = rightActions
        self.content = content
    }

    var body: some View {
        ZStack {
            // Background actions
            HStack {
                if !rightActions.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(rightActions.indices, id: \.self) { index in
                            ActionButton(action: rightActions[index]) {
                                resetPosition()
                            }
                        }
                    }
                    .offset(x: offset > 0 ? offset : 0)
                }

                Spacer()

                if !leftActions.isEmpty {
                    HStack(spacing: 0) {
                        ForEach(leftActions.indices.reversed(), id: \.self) { index in
                            ActionButton(action: leftActions[index]) {
                                resetPosition()
                            }
                        }
                    }
                    .offset(x: offset < 0 ? offset : 0)
                }
            }

            // Content
            content()
                .offset(x: offset)
                .gesture(
                    DragGesture()
                        .onChanged { value in
                            offset = value.translation.width
                        }
                        .onEnded { value in
                            handleSwipeEnd(value: value)
                        }
                )
        }
        .clipped()
        .animation(.easeInOut(duration: 0.2), value: offset)
    }

    private func handleSwipeEnd(value: DragGesture.Value) {
        let threshold: CGFloat = 80

        if value.translation.width > threshold {
            if let firstRightAction = rightActions.first {
                offset = 80
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    firstRightAction.action()
                    resetPosition()
                }
                return
            }
        } else if value.translation.width < -threshold {
            if let firstLeftAction = leftActions.first {
                offset = -80
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    firstLeftAction.action()
                    resetPosition()
                }
                return
            }
        }

        resetPosition()
    }

    private func resetPosition() {
        withAnimation {
            offset = 0
        }
    }

    @ViewBuilder
    private func ActionButton(action: SwipeAction, onTap: @escaping () -> Void) -> some View {
        Button {
            action.action()
            onTap()
        } label: {
            VStack(spacing: ParietalSpacing.xs) {
                Image(systemName: action.icon)
                    .font(WernickeTypography.size16)
                Text(action.title)
                    .font(.caption2)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(action.color)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Reorderable List View

struct ReorderableListView<Item: Identifiable & Equatable, Content: View>: View {
    let items: [Item]
    let content: (Item) -> Content
    let onMove: (IndexSet, Int) -> Void
    let onDelete: (IndexSet) -> Void

    @State private var itemsState: [Item]

    init(
        items: [Item],
        @ViewBuilder content: @escaping (Item) -> Content,
        onMove: @escaping (IndexSet, Int) -> Void,
        onDelete: @escaping (IndexSet) -> Void
    ) {
        self.items = items
        self.content = content
        self.onMove = onMove
        self.onDelete = onDelete
        self._itemsState = State(initialValue: items)
    }

    var body: some View {
        List {
            ForEach(itemsState) { item in
                content(item)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))
                    .listRowBackground(V4Color.surface)
            }
            .onMove(perform: onMove)
            .onDelete(perform: onDelete)
        }
        .listStyle(.plain)
        .background(V4Color.background)
        .onChange(of: items) { _, newItems in
            itemsState = newItems
        }
    }
}

// MARK: - Preview

struct ListView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Simple list items
            VStack(spacing: 0) {
                SimpleListItem(
                    id: "1",
                    title: "Trinity Neural Network",
                    subtitle: "Updated 2 hours ago",
                    icon: "brain.head.profile",
                    badge: "New"
                )

                Divider().background(V4Color.border)

                SimpleListItem(
                    id: "2",
                    title: "FPGA Synthesis",
                    subtitle: "Processing...",
                    icon: "cpu"
                )

                Divider().background(V4Color.border)

                SimpleListItem(
                    id: "3",
                    title: "HSLM Training",
                    subtitle: "Step 45,289 of 100,000",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
            .frame(width: 350)
            .padding()
            .background(V4Color.background)

            // Swipeable list item
            SwipeableListItem(
                id: "swipe1",
                leftActions: [
                    .init(title: "Archive", icon: "archivebox", color: V4Color.accent) {},
                    .init(title: "Flag", icon: "flag", color: V4Color.warning) {}
                ],
                rightActions: [
                    .init(title: "Delete", icon: "trash", color: V4Color.error) {}
                ]
            ) {
                SimpleListItem(
                    id: "swipe1",
                    title: "Swipe me left or right",
                    subtitle: "<- Swipe ->",
                    icon: "hand.tap"
                )
            }
            .frame(width: 350)
            .padding()
            .background(V4Color.background)
        }
    }
}
