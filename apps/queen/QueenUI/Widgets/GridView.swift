// Grid View — Adaptive Grid Layout with Responsive Columns
import SwiftUI

// MARK: - Grid Cell

struct GridCell: View {
    let title: String
    let subtitle: String?
    let icon: String?
    let iconColor: Color
    let isSelected: Bool

    init(
        title: String,
        subtitle: String? = nil,
        icon: String? = nil,
        iconColor: Color = V4Color.accent,
        isSelected: Bool = false
    ) {
        self.title = title
        self.subtitle = subtitle
        self.icon = icon
        self.iconColor = iconColor
        self.isSelected = isSelected
    }

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm + 2) {
            // Icon
            if let icon = icon {
                Image(systemName: icon)
                    .font(WernickeTypography.size28)
                    .foregroundStyle(iconColor)
                    .frame(width: ParietalSpacing.avatarMedium - 4, height: ParietalSpacing.avatarMedium - 4)
                    .background(iconColor.opacity(V2Depth.bgSidebarHover))
                    .cornerRadius(V1Theme.cornerMedium)
            }

            // Title and subtitle
            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text(title)
                    .font(WernickeTypography.body14Medium)
                    .foregroundStyle(isSelected ? V4Color.accent : V4Color.textPrimary)
                    .lineLimit(2)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(ParietalSpacing.sm)
        .background(isSelected ? V4Color.accent.opacity(V2Depth.bgSubtle) : V4Color.surface)
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(isSelected ? V4Color.accent : V4Color.border, lineWidth: isSelected ? 2 : 1)
        )
    }
}

// MARK: - Adaptive Grid View

struct AdaptiveGridView<Data: RandomAccessCollection, Content: View>: View where Data.Element: Identifiable {
    let data: Data
    let minItemWidth: CGFloat
    let spacing: CGFloat
    let content: (Data.Element) -> Content

    init(
        data: Data,
        minItemWidth: CGFloat = 150,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping (Data.Element) -> Content
    ) {
        self.data = data
        self.minItemWidth = minItemWidth
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        GeometryReader { geometry in
            let columns = max(1, Int(geometry.size.width / (minItemWidth + spacing)))
            let itemWidth = (geometry.size.width - spacing * CGFloat(columns - 1)) / CGFloat(columns)

            LazyVGrid(
                columns: Array(repeating: SwiftUI.GridItem(.fixed(itemWidth), spacing: spacing), count: columns),
                spacing: spacing
            ) {
                ForEach(data) { item in
                    content(item)
                        .frame(width: itemWidth)
                }
            }
        }
    }
}

// MARK: - Fixed Grid View

struct FixedGridView<Content: View>: View {
    let columns: Int
    let spacing: CGFloat
    let content: () -> Content

    init(
        columns: Int = 3,
        spacing: CGFloat = 12,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.columns = columns
        self.spacing = spacing
        self.content = content
    }

    var body: some View {
        LazyVGrid(
            columns: Array(repeating: SwiftUI.GridItem(.flexible(), spacing: spacing), count: columns),
            spacing: spacing
        ) {
            content()
        }
    }
}

// MARK: - Draggable Grid Item (simple version)

struct DraggableGridCell: View {
    let title: String
    let icon: String
    let isSelected: Bool
    @Binding var isDragging: Bool

    var body: some View {
        GridCell(title: title, icon: icon, isSelected: isSelected)
            .scaleEffect(isDragging ? 1.1 : 1.0)
            .opacity(isDragging ? 0.8 : 1.0)
            .animation(.easeInOut(duration: 0.15), value: isDragging)
            .onDrag {
                isDragging = true
                return NSItemProvider(object: title as NSString)
            }
    }
}

// MARK: - Preview

struct GridView_Previews: PreviewProvider {
    static var previews: some View {
        FixedGridView(columns: 3, spacing: ParietalSpacing.md) {
            GridCell(title: "Neural Net", icon: "brain.head.profile", iconColor: .blue)
            GridCell(title: "FPGA", icon: "cpu", iconColor: .purple)
            GridCell(title: "Training", icon: "chart.line.uptrend.xyaxis", iconColor: .green)
            GridCell(title: "Inference", icon: "bolt.fill", iconColor: .orange)
            GridCell(title: "Models", icon: "cube.fill", iconColor: .red)
            GridCell(title: "Datasets", icon: "doc.fill", iconColor: .cyan)
        }
        .frame(width: ParietalSpacing.xl * 20)
        .padding()
        .background(V4Color.background)
    }
}

struct GridItemData: Identifiable {
    let id: String
    let title: String
    let icon: String
}
