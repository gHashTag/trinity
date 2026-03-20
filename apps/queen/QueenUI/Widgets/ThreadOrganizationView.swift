import SwiftUI

// MARK: - Thread Tags Manager

struct ThreadTagsManager: View {
    let thread: ChatThread
    let onTagsUpdated: ([String]) -> Void

    @State private var availableTags: [String] = []
    @State private var newTagText = ""
    @State private var showTagEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            // Current tags
            if !thread.tags.isEmpty {
                VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                    Text("Current Tags")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)

                    FlowLayout(spacing: ParietalSpacing.sm) {
                        ForEach(thread.tags, id: \.self) { tag in
                            tagChip(tag, isSelected: true)
                        }
                    }
                }
            }

            // Add tag button
            Button {
                showTagEditor = true
            } label: {
                HStack(spacing: ParietalSpacing.sm - 2) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Tag")
                }
                .font(.caption)
                .foregroundStyle(V4Color.accent)
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showTagEditor) {
            tagEditorSheet
        }
        .onAppear {
            loadAvailableTags()
        }
    }

    private func tagChip(_ tag: String, isSelected: Bool) -> some View {
        Button {
            if isSelected {
                onTagsUpdated(thread.tags.filter { $0 != tag })
            }
        } label: {
            HStack(spacing: ParietalSpacing.xs) {
                Text("#\(tag)")
                    .font(.caption)
                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
            }
            .foregroundStyle(isSelected ? V4Color.accent : V4Color.textSecondary)
            .padding(.horizontal, ParietalSpacing.sm + 2)
            .padding(.vertical, ParietalSpacing.xs + 2)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(isSelected ? V4Color.accent.opacity(V2Depth.bgSidebarHover) : V4Color.surface)
            )
        }
        .buttonStyle(.plain)
    }

    private var tagEditorSheet: some View {
        NavigationStack {
            VStack(spacing: ParietalSpacing.lg) {
                // New tag input
                HStack {
                    TextField("New tag name", text: $newTagText)
                        .textFieldStyle(.roundedBorder)

                    Button("Add") {
                        addNewTag()
                    }
                    .disabled(newTagText.isEmpty)
                    .buttonStyle(.borderedProminent)
                }

                Divider()

                // Available tags
                ScrollView {
                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        ForEach(availableTags, id: \.self) { tag in
                            availableTagRow(tag)
                        }
                    }
                }
            }
            .padding()
            .navigationTitle("Edit Tags")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        showTagEditor = false
                    }
                }
            }
        }
        .frame(width: 400, height: 500)
    }

    private func availableTagRow(_ tag: String) -> some View {
        let isSelected = thread.tags.contains(tag)

        return Button {
            if isSelected {
                onTagsUpdated(thread.tags.filter { $0 != tag })
            } else {
                onTagsUpdated(thread.tags + [tag])
            }
        } label: {
            HStack {
                Text("#\(tag)")
                    .foregroundStyle(isSelected ? V4Color.accent : V4Color.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(V4Color.accent)
                }
            }
            .padding(.vertical, ParietalSpacing.sm)
        }
        .buttonStyle(.plain)
    }

    private func addNewTag() {
        let trimmed = newTagText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty && !thread.tags.contains(trimmed) else { return }

        onTagsUpdated(thread.tags + [trimmed])
        availableTags.append(trimmed)
        newTagText = ""
    }

    private func loadAvailableTags() {
        if let data = UserDefaults.standard.data(forKey: "availableThreadTags"),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            availableTags = decoded
        } else {
            availableTags = ["fpga", "debug", "documentation", "idea", "todo", "question", "resolved", "work-in-progress"]
        }
    }

    private func saveAvailableTags() {
        if let encoded = try? JSONEncoder().encode(availableTags) {
            UserDefaults.standard.set(encoded, forKey: "availableThreadTags")
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            maxWidth: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            maxWidth: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x, y: bounds.minY + result.positions[index].y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize
        var positions: [CGPoint] = []

        init(maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth && currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
            }

            self.size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

// MARK: - Thread Color Labels

struct ThreadColorLabelPicker: View {
    @Binding var selectedColor: String?

    private let colors: [(name: String, color: Color)] = [
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("green", .green),
        ("blue", .blue),
        ("purple", .purple),
        ("pink", .pink),
        ("gray", .gray)
    ]

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            ForEach(colors, id: \.name) { color in
                colorButton(color)
            }
        }
    }

    private func colorButton(_ color: (name: String, color: Color)) -> some View {
        Button {
            withAnimation {
                if selectedColor == color.name {
                    selectedColor = nil
                } else {
                    selectedColor = color.name
                }
            }
        } label: {
            Circle()
                .fill(color.color)
                .frame(width: ParietalSpacing.lg, height: ParietalSpacing.lg)
                .overlay(
                    Circle()
                        .stroke(selectedColor == color.name ? V4Color.accent : Color.white.opacity(V2Depth.stateHover), lineWidth: 2)
                )
                .scaleEffect(selectedColor == color.name ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
        .help(color.name.capitalized)
    }
}

// MARK: - Thread Folder View

struct ThreadFolderView: View {
    let folders: [ThreadFolder]
    let onFolderSelect: (ThreadFolder?) -> Void
    @Binding var selectedFolder: ThreadFolder?

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            Text("Folders")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)
                .padding(.horizontal, ParietalSpacing.md)

            // All threads
            folderButton(name: "All Threads", icon: "tray.full", count: nil) {
                selectedFolder = nil
                onFolderSelect(nil)
            }

            Divider()
                .background(V4Color.border)
                .padding(.horizontal, ParietalSpacing.md)

            // Custom folders
            ForEach(folders) { folder in
                folderButton(name: folder.name, icon: "folder.fill", count: nil) {
                    selectedFolder = folder
                    onFolderSelect(folder)
                }
            }

            // Create new folder
            Button {
                createNewFolder()
            } label: {
                HStack(spacing: ParietalSpacing.sm) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(V4Color.textSecondary)
                    Text("New Folder")
                        .font(.caption)
                        .foregroundStyle(V4Color.textSecondary)
                }
                .padding(.horizontal, ParietalSpacing.md)
                .padding(.vertical, ParietalSpacing.sm)
            }
            .buttonStyle(.plain)
        }
    }

    private func folderButton(name: String, icon: String, count: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: ParietalSpacing.sm + 2) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .frame(width: ParietalSpacing.buttonSmallWidth)

                Text(name)
                    .font(.caption)
                    .foregroundStyle(selectedFolder?.name == name ? V4Color.accent : V4Color.textPrimary)

                Spacer()

                if let count = count {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }
            .padding(.horizontal, ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm)
            .background(selectedFolder?.name == name ? V4Color.accent.opacity(V2Depth.bgSidebarHover) : Color.clear)
        }
        .buttonStyle(.plain)
    }

    private func createNewFolder() {
        // Implementation would show a dialog for folder creation
    }
}

// MARK: - Thread Priority Badge

struct ThreadPriorityBadge: View {
    enum Priority: String, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"
        case urgent = "urgent"

        var color: Color {
            switch self {
            case .low: return V4Color.textSecondary
            case .medium: return .blue
            case .high: return .orange
            case .urgent: return V4Color.error
            }
        }

        var icon: String {
            switch self {
            case .low: return "flag"
            case .medium: return "flag.fill"
            case .high: return "flag.fill"
            case .urgent: return "exclamationmark.triangle.fill"
            }
        }
    }

    let priority: Priority

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: priority.icon)
                .font(.caption2)
            Text(priority.rawValue.uppercased())
                .font(.caption2)
        }
        .foregroundStyle(priority.color)
        .padding(.horizontal, ParietalSpacing.xs + 2)
        .padding(.vertical, 3)
        .background(
            priority.color.opacity(V2Depth.bgSidebarHover),
            in: SwiftUI.Capsule()
        )
    }
}

// MARK: - Thread Status Indicator

struct ThreadStatusIndicator: View {
    enum Status {
        case active
        case waiting
        case completed
        case blocked

        var color: Color {
            switch self {
            case .active: return .green
            case .waiting: return .yellow
            case .completed: return V4Color.accent
            case .blocked: return V4Color.error
            }
        }

        var label: String {
            switch self {
            case .active: return "Active"
            case .waiting: return "Waiting"
            case .completed: return "Done"
            case .blocked: return "Blocked"
            }
        }
    }

    let status: Status

    var body: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            Circle()
                .fill(status.color)
                .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)

            Text(status.label)
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)
        }
    }
}

// MARK: - Preview

struct ThreadOrganizationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            ThreadTagsManager(
                thread: ChatThread(title: "Sample Thread"),
                onTagsUpdated: { _ in }
            )

            ThreadColorLabelPicker(selectedColor: .constant("blue"))

            ThreadPriorityBadge(priority: .high)

            ThreadStatusIndicator(status: .active)
        }
        .padding()
        .background(V4Color.background)
    }
}
