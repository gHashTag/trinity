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
            HStack(spacing: 12) {
                leading()

                content()

                Spacer()

                trailing()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
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
        HStack(spacing: 12) {
            // Icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundStyle(isSelected ? TrinityTheme.accent : TrinityTheme.textMuted)
                    .frame(width: 28)
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: isSelected ? .medium : .regular))
                    .foregroundStyle(isSelected ? TrinityTheme.accent : TrinityTheme.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }

            Spacer()

            // Badge
            if let badge = badge {
                Text(badge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(TrinityTheme.accent)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(
            isSelected ? TrinityTheme.accent.opacity(0.1) : TrinityTheme.bgCard
        )
        .overlay(
            Rectangle()
                .fill(isSelected ? TrinityTheme.accent : .clear)
                .frame(width: 3),
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
            VStack(spacing: 4) {
                Image(systemName: action.icon)
                    .font(.system(size: 16))
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
                    .listRowBackground(TrinityTheme.bgCard)
            }
            .onMove(perform: onMove)
            .onDelete(perform: onDelete)
        }
        .listStyle(.plain)
        .background(TrinityTheme.bgWindow)
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

                Divider().background(TrinityTheme.bgCardBorder)

                SimpleListItem(
                    id: "2",
                    title: "FPGA Synthesis",
                    subtitle: "Processing...",
                    icon: "cpu"
                )

                Divider().background(TrinityTheme.bgCardBorder)

                SimpleListItem(
                    id: "3",
                    title: "HSLM Training",
                    subtitle: "Step 45,289 of 100,000",
                    icon: "chart.line.uptrend.xyaxis"
                )
            }
            .frame(width: 350)
            .padding()
            .background(TrinityTheme.bgWindow)

            // Swipeable list item
            SwipeableListItem(
                id: "swipe1",
                leftActions: [
                    .init(title: "Archive", icon: "archivebox", color: TrinityTheme.accent) {},
                    .init(title: "Flag", icon: "flag", color: TrinityTheme.statusWarn) {}
                ],
                rightActions: [
                    .init(title: "Delete", icon: "trash", color: TrinityTheme.statusError) {}
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
            .background(TrinityTheme.bgWindow)
        }
    }
}
