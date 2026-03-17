// Tree View — Hierarchical Data with Expand/Collapse
import SwiftUI

// MARK: - Tree Item Data

struct TreeItemData: Identifiable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String?
    let badge: String?
    let children: [TreeItemData]?

    init(
        id: String,
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        badge: String? = nil,
        children: [TreeItemData]? = nil
    ) {
        self.id = id
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.badge = badge
        self.children = children
    }
}

// MARK: - Tree View Row

struct TreeViewRow<Content: View>: View {
    let content: () -> Content
    let indent: CGFloat
    let isExpanded: Bool
    let hasChildren: Bool
    let isSelected: Bool
    let onToggle: () -> Void

    init(
        indent: CGFloat = 0,
        isExpanded: Bool = false,
        hasChildren: Bool = false,
        isSelected: Bool = false,
        @ViewBuilder content: @escaping () -> Content,
        onToggle: @escaping () -> Void = {}
    ) {
        self.indent = indent
        self.isExpanded = isExpanded
        self.hasChildren = hasChildren
        self.isSelected = isSelected
        self.content = content
        self.onToggle = onToggle
    }

    var body: some View {
        HStack(spacing: 0) {
            // Indent
            Rectangle()
                .fill(.clear)
                .frame(width: indent)

            // Expand/collapse chevron
            Button {
                onToggle()
            } label: {
                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(hasChildren ? TrinityTheme.textMuted : .clear)
                    .frame(width: 16)
            }
            .buttonStyle(.plain)
            .disabled(!hasChildren)

            // Content
            content()
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? TrinityTheme.accent.opacity(0.1) : .clear)
        .overlay(
            Rectangle()
                .fill(isSelected ? TrinityTheme.accent : .clear)
                .frame(width: 2),
            alignment: .leading
        )
    }
}

// MARK: - Simple Tree Row

struct SimpleTreeRow: View {
    let item: TreeItemData
    let level: Int
    let isExpanded: Bool
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 8) {
            // Indent
            Rectangle()
                .fill(.clear)
                .frame(width: CGFloat(level) * 20)

            // Chevron
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(item.children != nil ? TrinityTheme.textMuted : .clear)
                .frame(width: 16)

            // Icon
            if let icon = item.icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundStyle(isSelected ? TrinityTheme.accent : TrinityTheme.textMuted)
                    .frame(width: 20)
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: 2) {
                Text(item.title)
                    .font(.system(size: 13))
                    .foregroundStyle(isSelected ? TrinityTheme.accent : TrinityTheme.textPrimary)

                if let subtitle = item.subtitle {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }

            Spacer()

            // Badge
            if let badge = item.badge {
                Text(badge)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 1)
                    .background(TrinityTheme.accent)
                    .cornerRadius(3)
            }
        }
        .padding(.vertical, 5)
    }
}

// MARK: - Tree View

struct TreeView: View {
    let rootItems: [TreeItemData]
    let selectable: Bool

    @State private var expandedIds: Set<String> = []
    @State private var selectedId: String? = nil

    init(
        rootItems: [TreeItemData],
        selectable: Bool = true
    ) {
        self.rootItems = rootItems
        self.selectable = selectable
    }

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(flattenedItems, id: \.id) { item in
                    Button {
                        handleTap(item: item)
                    } label: {
                        SimpleTreeRow(
                            item: item.data,
                            level: item.level,
                            isExpanded: expandedIds.contains(item.data.id),
                            isSelected: selectedId == item.data.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(TrinityTheme.bgCard)
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
    }

    private func handleTap(item: FlattenedItem) {
        // Toggle expand/collapse
        if item.data.children != nil {
            withAnimation {
                if expandedIds.contains(item.data.id) {
                    expandedIds.remove(item.data.id)
                } else {
                    expandedIds.insert(item.data.id)
                }
            }
        }

        // Select if selectable
        if selectable {
            withAnimation {
                selectedId = item.data.id
            }
        }
    }

    private var flattenedItems: [FlattenedItem] {
        var result: [FlattenedItem] = []
        func flatten(_ items: [TreeItemData], level: Int) {
            for item in items {
                result.append(FlattenedItem(data: item, level: level))
                if expandedIds.contains(item.id), let children = item.children {
                    flatten(children, level: level + 1)
                }
            }
        }
        flatten(rootItems, level: 0)
        return result
    }

    struct FlattenedItem: Identifiable {
        let id: String
        let data: TreeItemData
        let level: Int

        init(data: TreeItemData, level: Int) {
            self.id = UUID().uuidString + "-" + data.id
            self.data = data
            self.level = level
        }
    }
}

// MARK: - File Tree View (with icons)

struct FileTreeView: View {
    let items: [TreeItemData]
    @State private var expandedIds: Set<String> = []
    @State private var selectedId: String? = nil

    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                ForEach(flattenedItems, id: \.id) { item in
                    Button {
                        handleTap(item: item)
                    } label: {
                        FileTreeRow(
                            item: item.data,
                            level: item.level,
                            isExpanded: expandedIds.contains(item.data.id),
                            isSelected: selectedId == item.data.id
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .background(TrinityTheme.bgCard)
    }

    private func handleTap(item: FlattenedItem) {
        if item.data.children != nil {
            withAnimation {
                if expandedIds.contains(item.data.id) {
                    expandedIds.remove(item.data.id)
                } else {
                    expandedIds.insert(item.data.id)
                }
            }
        }
        withAnimation {
            selectedId = item.data.id
        }
    }

    private var flattenedItems: [FlattenedItem] {
        var result: [FlattenedItem] = []
        func flatten(_ items: [TreeItemData], level: Int) {
            for item in items {
                result.append(FlattenedItem(data: item, level: level))
                if expandedIds.contains(item.id), let children = item.children {
                    flatten(children, level: level + 1)
                }
            }
        }
        flatten(items, level: 0)
        return result
    }

    struct FlattenedItem: Identifiable {
        let id: String
        let data: TreeItemData
        let level: Int

        init(data: TreeItemData, level: Int) {
            self.id = UUID().uuidString + "-" + data.id
            self.data = data
            self.level = level
        }
    }

    struct FileTreeRow: View {
        let item: TreeItemData
        let level: Int
        let isExpanded: Bool
        let isSelected: Bool

        var body: some View {
            HStack(spacing: 6) {
                Rectangle()
                    .fill(.clear)
                    .frame(width: CGFloat(level) * 16)

                Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(item.children != nil ? TrinityTheme.textMuted : .clear)
                    .frame(width: 12)

                Image(systemName: iconName)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? TrinityTheme.accent : iconColor)
                    .frame(width: 16)

                Text(item.title)
                    .font(.system(size: 12))
                    .foregroundStyle(isSelected ? TrinityTheme.accent : TrinityTheme.textPrimary)

                Spacer()
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isSelected ? TrinityTheme.accent.opacity(0.1) : .clear)
        }

        private var iconName: String {
            if item.children != nil {
                return isExpanded ? "folder.fill" : "folder"
            }
            return "doc.fill"
        }

        private var iconColor: Color {
            if item.children != nil {
                return .blue
            }
            switch item.title.components(separatedBy: ".").last {
            case "swift": return .orange
            case "zig": return .yellow
            case "json": return .green
            default: return TrinityTheme.textMuted
            }
        }
    }
}

// MARK: - Preview

struct TreeView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Simple tree
            TreeView(
                rootItems: [
                    TreeItemData(
                        id: "src",
                        title: "src",
                        icon: "folder.fill",
                        children: [
                            TreeItemData(id: "tri", title: "tri", icon: "folder.fill", children: [
                                TreeItemData(id: "main.zig", title: "main.zig", icon: "doc.fill"),
                                TreeItemData(id: "vsa.zig", title: "vsa.zig", icon: "doc.fill")
                            ]),
                            TreeItemData(id: "tools", title: "tools", icon: "folder.fill", children: [
                                TreeItemData(id: "mcp", title: "mcp", icon: "folder.fill", children: [
                                    TreeItemData(id: "server.zig", title: "server.zig", icon: "doc.fill", badge: "New")
                                ])
                            ])
                        ]
                    ),
                    TreeItemData(
                        id: "specs",
                        title: "specs",
                        icon: "folder.fill",
                        children: [
                            TreeItemData(id: "tri", title: "tri", icon: "folder.fill", children: [
                                TreeItemData(id: "cell.tri", title: "cell.tri", icon: "doc.fill"),
                                TreeItemData(id: "dna.tri", title: "dna.tri", icon: "doc.fill")
                            ])
                        ]
                    )
                ]
            )
            .frame(width: 300, height: 400)
            .padding()
            .background(TrinityTheme.bgWindow)

            // File tree
            FileTreeView(
                items: [
                    TreeItemData(id: "apps", title: "apps", icon: "folder.fill", children: [
                        TreeItemData(id: "queen", title: "queen", icon: "folder.fill", children: [
                            TreeItemData(id: "QueenUI.swift", title: "QueenUI.swift", icon: "doc.fill"),
                            TreeItemData(id: "ChatScreen.swift", title: "ChatScreen.swift", icon: "doc.fill")
                        ])
                    ]),
                    TreeItemData(id: "src", title: "src", icon: "folder.fill", children: [
                        TreeItemData(id: "main.zig", title: "main.zig", icon: "doc.fill"),
                        TreeItemData(id: "vsa.zig", title: "vsa.zig", icon: "doc.fill")
                    ])
                ]
            )
            .frame(width: 250, height: 300)
            .padding()
            .background(TrinityTheme.bgWindow)
        }
    }
}
