// Table View — Data Table with Sorting, Filtering, Selection
import SwiftUI

// MARK: - Table Column

struct TableColumn<ID: Hashable>: Identifiable {
    let id: ID
    let title: String
    let width: CGFloat?
    let alignment: HorizontalAlignment
    let sortable: Bool
    let valueKey: String  // Key to look up in values dictionary

    init(
        id: ID,
        title: String,
        width: CGFloat? = nil,
        alignment: HorizontalAlignment = .leading,
        sortable: Bool = true,
        valueKey: String
    ) {
        self.id = id
        self.title = title
        self.width = width
        self.alignment = alignment
        self.sortable = sortable
        self.valueKey = valueKey
    }
}

// MARK: - Table Cell Data

struct TableCellData: Equatable {
    let id: String
    let values: [String: String]

    init(id: String, values: [String: String]) {
        self.id = id
        self.values = values
    }
}

// MARK: - Table Row

struct TableRow<Content: View>: View, Identifiable {
    let id: String
    let isSelected: Bool
    let isHighlighted: Bool
    let content: () -> Content
    let onTap: () -> Void
    let onDoubleClick: () -> Void

    init(
        id: String,
        isSelected: Bool = false,
        isHighlighted: Bool = false,
        @ViewBuilder content: @escaping () -> Content,
        onTap: @escaping () -> Void = {},
        onDoubleClick: @escaping () -> Void = {}
    ) {
        self.id = id
        self.isSelected = isSelected
        self.isHighlighted = isHighlighted
        self.content = content
        self.onTap = onTap
        self.onDoubleClick = onDoubleClick
    }

    var body: some View {
        content()
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm + 2)
            .background(
                isSelected ? V4Color.accent.opacity(V2Depth.bgSidebarHover) :
                    isHighlighted ? V4Color.border.opacity(V2Depth.stateDisabled) :
                        V4Color.surface
            )
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .stroke(isSelected ? V4Color.accent : .clear, lineWidth: 1)
            )
            .contentShape(Rectangle())
            .onTapGesture(perform: onTap)
            .onTapGesture(count: 2, perform: onDoubleClick)
    }
}

// MARK: - Table Header

struct TableHeader: View {
    let columns: [TableColumn<String>]
    let sortColumn: String?
    let sortAscending: Bool
    let onSort: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            ForEach(columns) { column in
                Button {
                    guard column.sortable else { return }
                    onSort(column.id)
                } label: {
                    HStack(spacing: ParietalSpacing.sm - 2) {
                        Text(column.title)
                            .font(WernickeTypography.caption2Semibold)
                            .foregroundStyle(V4Color.textPrimary)

                        if sortColumn == column.id {
                            Image(systemName: sortAscending ? "chevron.up" : "chevron.down")
                                .font(WernickeTypography.size9)
                                .foregroundStyle(V4Color.accent)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, ParietalSpacing.md)
                    .padding(.vertical, ParietalSpacing.sm)
                    .frame(width: column.width, alignment: .leading)
                    .background(column.sortable ? V4Color.background.opacity(V2Depth.stateDisabled) : .clear)
                }
                .buttonStyle(.plain)
            }
        }
        .background(V4Color.surface)
        .overlay(
            Rectangle()
                .fill(V4Color.border)
                .frame(height: 1),
            alignment: .bottom
        )
    }
}

// MARK: - Data Table View

struct DataTableView: View {
    let columns: [TableColumn<String>]
    let data: [TableCellData]
    let selectable: Bool
    let searchable: Bool

    @State private var selectedIds: Set<String> = []
    @State private var sortColumn: String? = nil
    @State private var sortAscending: Bool = true
    @State private var searchText: String = ""
    @State private var hoveredId: String? = nil

    init(
        columns: [TableColumn<String>],
        data: [TableCellData],
        selectable: Bool = true,
        searchable: Bool = true
    ) {
        self.columns = columns
        self.data = data
        self.selectable = selectable
        self.searchable = searchable
    }

    var body: some View {
        VStack(spacing: 0) {
            // Search bar
            if searchable {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(V4Color.textSecondary)

                    TextField("Search...", text: $searchText)
                        .textFieldStyle(.plain)

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(V4Color.textSecondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm)
                .background(V4Color.surface)
                .overlay(
                    Rectangle()
                        .fill(V4Color.border)
                        .frame(height: 1),
                    alignment: .bottom
                )
            }

            // Header
            TableHeader(
                columns: columns,
                sortColumn: sortColumn,
                sortAscending: sortAscending,
                onSort: handleSort
            )

            // Rows
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(filteredData, id: \.id) { row in
                        TableRow(
                            id: row.id,
                            isSelected: selectedIds.contains(row.id),
                            isHighlighted: hoveredId == row.id
                        ) {
                            HStack(spacing: 0) {
                                ForEach(columns) { column in
                                    Text(row.values[column.valueKey] ?? "")
                                        .font(WernickeTypography.size13)
                                        .foregroundStyle(V4Color.textPrimary)
                                        .frame(width: column.width, alignment: .leading)
                                        .lineLimit(1)
                                }
                            }
                        } onTap: {
                            handleTap(row.id)
                        } onDoubleClick: {
                            // Double click action
                        }
                        .onHover { hovering in
                            hoveredId = hovering ? row.id : nil
                        }

                        if row.id != filteredData.last?.id {
                            Divider()
                                .background(V4Color.border)
                        }
                    }
                }
            }
        }
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }

    private var filteredData: [TableCellData] {
        if searchText.isEmpty {
            return data
        }
        return data.filter { row in
            row.values.values.contains { value in
                value.localizedCaseInsensitiveContains(searchText)
            }
        }
    }

    private func handleSort(_ columnId: String) {
        if sortColumn == columnId {
            sortAscending.toggle()
        } else {
            sortColumn = columnId
            sortAscending = true
        }
    }

    private func handleTap(_ id: String) {
        guard selectable else { return }
        if selectedIds.contains(id) {
            selectedIds.remove(id)
        } else {
            selectedIds.insert(id)
        }
    }
}

// MARK: - Preview

struct TableView_Previews: PreviewProvider {
    static var previews: some View {
        let columns = [
            TableColumn(id: "name", title: "Name", width: 200, valueKey: "name"),
            TableColumn(id: "status", title: "Status", width: 100, valueKey: "status"),
            TableColumn(id: "value", title: "Value", width: 100, valueKey: "value"),
            TableColumn(id: "date", title: "Date", width: 150, valueKey: "date")
        ]

        let data = [
            TableCellData(id: "1", values: ["name": "Project Alpha", "status": "Active", "value": "85%", "date": "2024-03-18"]),
            TableCellData(id: "2", values: ["name": "Project Beta", "status": "Pending", "value": "42%", "date": "2024-03-17"]),
            TableCellData(id: "3", values: ["name": "Project Gamma", "status": "Complete", "value": "100%", "date": "2024-03-15"]),
            TableCellData(id: "4", values: ["name": "Project Delta", "status": "Active", "value": "67%", "date": "2024-03-16"]),
            TableCellData(id: "5", values: ["name": "Project Epsilon", "status": "Failed", "value": "0%", "date": "2024-03-14"])
        ]

        return DataTableView(columns: columns, data: data)
            .frame(width: ParietalSpacing.extraWideSheet, height: ParietalSpacing.wideSheetWidth)
            .padding()
            .background(V4Color.background)
    }
}
