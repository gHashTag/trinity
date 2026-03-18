import SwiftUI

// MARK: - Thread Tags Manager

struct ThreadTagsManager: View {
    let thread: ChatThread
    let onTagsUpdated: ([String]) -> Void

    @State private var availableTags: [String] = []
    @State private var newTagText = ""
    @State private var showTagEditor = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Current tags
            if !thread.tags.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Current Tags")
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)

                    FlowLayout(spacing: 8) {
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
                HStack(spacing: 6) {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Tag")
                }
                .font(.caption)
                .foregroundStyle(TrinityTheme.accent)
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
            HStack(spacing: 4) {
                Text("#\(tag)")
                    .font(.caption)
                if isSelected {
                    Image(systemName: "xmark.circle.fill")
                        .font(.caption2)
                }
            }
            .foregroundStyle(isSelected ? TrinityTheme.accent : TrinityTheme.textMuted)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 12).fill(isSelected ? TrinityTheme.accent.opacity(0.15) : TrinityTheme.bgCard)
            )
        }
        .buttonStyle(.plain)
    }

    private var tagEditorSheet: some View {
        NavigationStack {
            VStack(spacing: 16) {
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
                    VStack(alignment: .leading, spacing: 8) {
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
                    .foregroundStyle(isSelected ? TrinityTheme.accent : TrinityTheme.textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(TrinityTheme.accent)
                }
            }
            .padding(.vertical, 8)
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
            maxWidth: proposal.replacingUnspecifiedDimensions().width ?? 0,
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
        HStack(spacing: 8) {
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
                .frame(width: 24, height: 24)
                .overlay(
                    Circle()
                        .stroke(selectedColor == color.name ? TrinityTheme.accent : Color.white.opacity(0.3), lineWidth: 2)
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Folders")
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)
                .padding(.horizontal, 12)

            // All threads
            folderButton(name: "All Threads", icon: "tray.full", count: nil) {
                selectedFolder = nil
                onFolderSelect(nil)
            }

            Divider()
                .background(TrinityTheme.bgCardBorder)
                .padding(.horizontal, 12)

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
                HStack(spacing: 8) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(TrinityTheme.textMuted)
                    Text("New Folder")
                        .font(.caption)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
            }
            .buttonStyle(.plain)
        }
    }

    private func folderButton(name: String, icon: String, count: Int?, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(TrinityTheme.textMuted)
                    .frame(width: 20)

                Text(name)
                    .font(.caption)
                    .foregroundStyle(selectedFolder?.name == name ? TrinityTheme.accent : TrinityTheme.textPrimary)

                Spacer()

                if let count = count {
                    Text("\(count)")
                        .font(.caption2)
                        .foregroundStyle(TrinityTheme.textMuted)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(selectedFolder?.name == name ? TrinityTheme.accent.opacity(0.15) : Color.clear)
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
            case .low: return TrinityTheme.textMuted
            case .medium: return .blue
            case .high: return .orange
            case .urgent: return TrinityTheme.statusError
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
        HStack(spacing: 4) {
            Image(systemName: priority.icon)
                .font(.caption2)
            Text(priority.rawValue.uppercased())
                .font(.caption2)
        }
        .foregroundStyle(priority.color)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(
            Capsule()
                .fill(priority.color.opacity(0.15))
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
            case .completed: return TrinityTheme.accent
            case .blocked: return TrinityTheme.statusError
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
        HStack(spacing: 6) {
            Circle()
                .fill(status.color)
                .frame(width: 8, height: 8)

            Text(status.label)
                .font(.caption2)
                .foregroundStyle(TrinityTheme.textMuted)
        }
    }
}

// MARK: - Preview

struct ThreadOrganizationView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            ThreadTagsManager(
                thread: ChatThread(title: "Sample Thread"),
                onTagsUpdated: { _ in }
            )

            ThreadColorLabelPicker(selectedColor: .constant("blue"))

            ThreadPriorityBadge(priority: .high)

            ThreadStatusIndicator(status: .active)
        }
        .padding()
        .background(TrinityTheme.bgWindow)
    }
}
