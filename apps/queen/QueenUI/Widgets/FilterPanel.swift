// Filter Panel — Filter Controls for Data Views
import SwiftUI

// MARK: - Filter Option

struct FilterOption: Identifiable, Equatable {
    let id: String
    let title: String
    let icon: String?
    let type: FilterType
    var isSelected: Bool

    enum FilterType {
        case checkbox
        case toggle
        case radio
        case range(min: Double, max: Double)
        case date
        case select(options: [String])
    }

    init(
        id: String,
        title: String,
        icon: String? = nil,
        type: FilterType,
        isSelected: Bool = false
    ) {
        self.id = id
        self.title = title
        self.icon = icon
        self.type = type
        self.isSelected = isSelected
    }

    static func == (lhs: FilterOption, rhs: FilterOption) -> Bool {
        lhs.id == rhs.id && lhs.isSelected == rhs.isSelected
    }
}

// MARK: - Filter Panel

struct FilterPanel: View {
    @Binding var filters: [FilterOption]
    let title: String
    let showClearAll: Bool
    let onClearAll: () -> Void

    init(
        filters: Binding<[FilterOption]>,
        title: String = "Filters",
        showClearAll: Bool = true,
        onClearAll: @escaping () -> Void = {}
    ) {
        self._filters = filters
        self.title = title
        self.showClearAll = showClearAll
        self.onClearAll = onClearAll
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            // Header
            HStack {
                Text(title)
                    .font(WernickeTypography.smallSemibold)
                    .foregroundStyle(V4Color.textPrimary)

                Spacer()

                if showClearAll && hasActiveFilters {
                    Button {
                        onClearAll()
                    } label: {
                        Text("Clear All")
                            .font(WernickeTypography.caption2)
                    }
                    .buttonStyle(.plain)
                }
            }

            // Filters
            VStack(spacing: 0) {
                ForEach(filters.indices, id: \.self) { index in
                    FilterRow(filter: $filters[index])
                        .padding(.vertical, ParietalSpacing.xs)

                    if index < filters.count - 1 {
                        Divider()
                            .background(V4Color.border)
                    }
                }
            }
        }
        .padding(ParietalSpacing.md)
        .background(V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.border, lineWidth: 1)
        )
    }

    private var hasActiveFilters: Bool {
        filters.contains { $0.isSelected }
    }
}

// MARK: - Filter Row

struct FilterRow: View {
    @Binding var filter: FilterOption

    var body: some View {
        HStack(spacing: ParietalSpacing.sm + 2) {
            // Icon
            if let icon = filter.icon {
                Image(systemName: icon)
                    .font(WernickeTypography.small)
                    .foregroundStyle(filter.isSelected ? V4Color.accent : V4Color.textSecondary)
                    .frame(width: ParietalSpacing.buttonSmallWidth)
            }

            // Title
            Text(filter.title)
                .font(WernickeTypography.small)
                .foregroundStyle(filter.isSelected ? V4Color.accent : V4Color.textPrimary)

            Spacer()

            // Control
            filterControl
        }
    }

    @ViewBuilder
    private var filterControl: some View {
        switch filter.type {
        case .checkbox:
            Button {
                withAnimation {
                    filter.isSelected.toggle()
                }
            } label: {
                Image(systemName: filter.isSelected ? "checkmark.square.fill" : "square")
                    .font(WernickeTypography.size16)
                    .foregroundStyle(filter.isSelected ? V4Color.accent : V4Color.textSecondary)
            }
            .buttonStyle(.plain)

        case .toggle:
            Toggle("", isOn: Binding(
                get: { filter.isSelected },
                set: { newValue in
                    withAnimation {
                        filter.isSelected = newValue
                    }
                }
            ))
            .toggleStyle(.switch)

        case .radio:
            Button {
                withAnimation {
                    filter.isSelected = true
                }
            } label: {
                Circle()
                    .fill(filter.isSelected ? V4Color.accent : .clear)
                    .frame(width: ParietalSpacing.icon, height: ParietalSpacing.icon)
                    .overlay(
                        Circle()
                            .stroke(V4Color.textSecondary, lineWidth: 2)
                            .opacity(filter.isSelected ? 0 : 1)
                    )
                    .overlay(
                        Circle()
                            .fill(.white)
                            .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)
                            .opacity(filter.isSelected ? 1 : 0)
                    )
            }
            .buttonStyle(.plain)

        case .range(let min, let max):
            Text("\(Int(min)) - \(Int(max))")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

        case .date:
            Image(systemName: "calendar")
                .font(WernickeTypography.small)
                .foregroundStyle(V4Color.textSecondary)

        case .select(let options):
            Menu {
                ForEach(options, id: \.self) { option in
                    Button(option) {
                        // Handle selection
                    }
                }
            } label: {
                HStack(spacing: ParietalSpacing.xs) {
                    Text("Select")
                        .font(.caption)
                    Image(systemName: "chevron.down")
                        .font(WernickeTypography.size9)
                }
                .foregroundStyle(V4Color.textSecondary)
            }
        }
    }
}

// MARK: - Quick Filter Chips

struct QuickFilterChips: View {
    let options: [String]
    @Binding var selected: String?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: ParietalSpacing.sm) {
                ForEach(options, id: \.self) { option in
                    FilterChip(
                        title: option,
                        isSelected: selected == option
                    ) {
                        withAnimation {
                            selected = selected == option ? nil : option
                        }
                    }
                }
            }
            .padding(.horizontal, 1)
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button {
            onTap()
        } label: {
            Text(title)
                .font(isSelected ? WernickeTypography.captionMedium : WernickeTypography.caption)
                .foregroundStyle(isSelected ? .white : V4Color.textPrimary)
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.xs)
                .background(isSelected ? V4Color.accent : V4Color.border)
                .cornerRadius(V1Theme.cornerXLarge)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Multi Select Filter

struct MultiSelectFilter: View {
    let title: String
    let options: [String]
    @Binding var selected: Set<String>

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text(title)
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)

            FilterFlowLayout(spacing: ParietalSpacing.sm - 2) {
                ForEach(options, id: \.self) { option in
                    FilterChip(
                        title: option,
                        isSelected: selected.contains(option)
                    ) {
                        if selected.contains(option) {
                            selected.remove(option)
                        } else {
                            selected.insert(option)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Range Slider Filter

struct RangeSliderFilter: View {
    let title: String
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)

                Spacer()

                Text("\(Int(range.lowerBound)) - \(Int(range.upperBound))")
                    .font(.caption)
                    .foregroundStyle(V4Color.textPrimary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Rectangle()
                        .fill(V4Color.border)
                        .frame(height: ParietalSpacing.xs)

                    // Fill
                    Rectangle()
                        .fill(V4Color.accent)
                        .frame(width: width(for: range, in: geometry.size.width), height: 4)

                    // Lower thumb
                    Circle()
                        .fill(.white)
                        .frame(width: ParietalSpacing.icon, height: ParietalSpacing.icon)
                        .shadow(color: .black.opacity(V2Depth.bgSubtle), radius: 2)
                        .offset(x: offset(for: range.lowerBound, in: geometry.size.width) - 8)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    updateLower(value.location.x, in: geometry.size.width)
                                }
                        )

                    // Upper thumb
                    Circle()
                        .fill(.white)
                        .frame(width: ParietalSpacing.icon, height: ParietalSpacing.icon)
                        .shadow(color: .black.opacity(V2Depth.bgSubtle), radius: 2)
                        .offset(x: offset(for: range.upperBound, in: geometry.size.width) - 8)
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    updateUpper(value.location.x, in: geometry.size.width)
                                }
                        )
                }
            }
            .frame(height: 20)
        }
    }

    private func offset(for value: Double, in width: CGFloat) -> CGFloat {
        let percentage = (value - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)
        return percentage * width
    }

    private func width(for range: ClosedRange<Double>, in totalWidth: CGFloat) -> CGFloat {
        let lowerOffset = offset(for: range.lowerBound, in: totalWidth)
        let upperOffset = offset(for: range.upperBound, in: totalWidth)
        return upperOffset - lowerOffset
    }

    private func updateLower(_ x: CGFloat, in width: CGFloat) {
        let percentage = max(0, min(1, x / width))
        let value = bounds.lowerBound + percentage * (bounds.upperBound - bounds.lowerBound)
        range = min(value, range.upperBound - 0.01)...range.upperBound
    }

    private func updateUpper(_ x: CGFloat, in width: CGFloat) {
        let percentage = max(0, min(1, x / width))
        let value = bounds.lowerBound + percentage * (bounds.upperBound - bounds.lowerBound)
        range = range.lowerBound...max(value, range.lowerBound + 0.01)
    }
}

// MARK: - Flow Layout (for tags)

struct FilterFlowLayout: Layout {
    let spacing: CGFloat

    init(spacing: CGFloat = 6) {
        self.spacing = spacing
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        return CGSize(width: proposal.width ?? 0, height: rows.reduce(0) { max($0, $1.height) + spacing })
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = computeRows(proposal: proposal, subviews: subviews)
        var y = bounds.minY

        for row in rows {
            var x = bounds.minX

            for (item, size) in row.items {
                subviews[item].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }

            y += row.height + spacing
        }
    }

    private func computeRows(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var currentItems: [(Int, CGSize)] = []
        var currentX: CGFloat = 0
        var currentHeight: CGFloat = 0

        let maxWidth = proposal.width ?? 0

        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth && !currentItems.isEmpty {
                rows.append(Row(items: currentItems, height: currentHeight))
                currentItems = []
                currentX = 0
                currentHeight = 0
            }

            currentItems.append((index, size))
            currentX += size.width + spacing
            currentHeight = max(currentHeight, size.height)
        }

        if !currentItems.isEmpty {
            rows.append(Row(items: currentItems, height: currentHeight))
        }

        return rows
    }

    struct Row {
        let items: [(Int, CGSize)]
        let height: CGFloat
    }
}

// MARK: - Preview

struct FilterPanel_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            FilterPanel(
                filters: .constant([
                    FilterOption(id: "1", title: "Active Only", type: .toggle),
                    FilterOption(id: "2", title: "Has Attachments", icon: "paperclip", type: .checkbox),
                    FilterOption(id: "3", title: "From Me", type: .radio),
                    FilterOption(id: "4", title: "Date Range", icon: "calendar", type: .date)
                ])
            )
            .frame(width: ParietalSpacing.xl * 10)
            .padding()
            .background(V4Color.background)

            QuickFilterChips(
                options: ["All", "Active", "Completed", "Pending", "Cancelled"],
                selected: .constant("Active")
            )
            .frame(width: ParietalSpacing.xl * 16)
            .padding()
            .background(V4Color.background)
        }
    }
}
