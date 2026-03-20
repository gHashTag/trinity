import SwiftUI

struct TechTreeScreen: View {
    @State private var techTree: TechTree?

    struct TechTree: Codable {
        let version: Int?
        let updated_at: String?
        let epics: [Epic]?
    }

    struct Epic: Codable, Identifiable {
        let issue: Int
        let title: String?
        let priority: String?
        let children: [EpicChild]?
        let status: String?

        var id: Int { issue }
    }

    struct EpicChild: Codable, Identifiable {
        let issue: Int
        let title: String?
        let priority: String?
        let prereqs: [Int]?
        let status: String?

        var id: Int { issue }
        var isClosed: Bool { status == "closed" }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                // Header
                HStack {
                    Text("🌳")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("TECH TREE")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("Issue DAG — Prerequisites & Critical Path")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    if let tree = techTree {
                        VStack(alignment: .trailing) {
                            Text("\(tree.epics?.count ?? 0)")
                                .font(.title.weight(.bold).monospacedDigit())
                                .foregroundStyle(V4Color.golden)
                            Text("epics")
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                    }
                }
                .padding()

                // Summary
                if let tree = techTree, let epics = tree.epics {
                    let totalChildren = epics.flatMap { $0.children ?? [] }
                    let closed = totalChildren.filter(\.isClosed).count

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
                        StatCard(label: "Epics", value: "\(epics.count)", accent: V4Color.golden)
                        StatCard(label: "Tasks", value: "\(totalChildren.count)", accent: V4Color.accent)
                        StatCard(
                            label: "Completed",
                            value: "\(closed)/\(totalChildren.count)",
                            accent: V4Color.statusOK
                        )
                    }
                    .padding(.horizontal)

                    // Progress bar
                    if !totalChildren.isEmpty {
                        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                            let progress = Double(closed) / Double(totalChildren.count)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(V4Color.bgCard)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(V4Color.accent)
                                        .frame(width: geo.size.width * progress)
                                }
                            }
                            .frame(height: 8)
                            Text(String(format: "%.0f%% complete", Double(closed) / Double(totalChildren.count) * 100))
                                .font(.caption)
                                .foregroundStyle(V4Color.textSecondary)
                        }
                        .padding(.horizontal)
                    }

                    // Epics
                    ForEach(epics) { epic in
                        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                            // Epic header
                            HStack {
                                Text(priorityEmoji(epic.priority))
                                Text("#\(epic.issue)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(V4Color.purple)
                                Text(epic.title ?? "Untitled")
                                    .font(.headline)
                                    .foregroundStyle(V4Color.textPrimary)
                                Spacer()
                                Text(epic.priority ?? "")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(priorityColor(epic.priority))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(priorityColor(epic.priority).opacity(V2Depth.bgSidebarHover))
                                    .clipShape(SwiftUI.Capsule())
                            }

                            // Children
                            if let children = epic.children, !children.isEmpty {
                                ForEach(children) { child in
                                    HStack(spacing: ParietalSpacing.sm) {
                                        Image(systemName: child.isClosed ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(child.isClosed ? V4Color.statusOK : V4Color.textSecondary)
                                            .font(.caption)

                                        Text("#\(child.issue)")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(V4Color.purple)

                                        Text(child.title ?? "")
                                            .font(.caption)
                                            .foregroundStyle(child.isClosed ? V4Color.textSecondary : V4Color.textPrimary)
                                            .strikethrough(child.isClosed)

                                        Spacer()

                                        if let prereqs = child.prereqs, !prereqs.isEmpty {
                                            Text("← \(prereqs.map { "#\($0)" }.joined(separator: ", "))")
                                                .font(.caption2)
                                                .foregroundStyle(V4Color.textSecondary)
                                        }
                                    }
                                    .padding(.leading, 16)
                                }
                            }
                        }
                        .padding()
                        .background(V4Color.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: ParietalSpacing.md) {
                        Text("No tech tree data")
                            .font(.headline)
                            .foregroundStyle(V4Color.textPrimary)
                        Text(".trinity/tech_tree.json not found")
                            .font(.caption)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .onAppear { loadTree() }
    }

    private func loadTree() {
        let path = "\(FileManager.default.currentDirectoryPath)/.trinity/tech_tree.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        techTree = try? JSONDecoder().decode(TechTree.self, from: data)
    }

    private func priorityEmoji(_ p: String?) -> String {
        switch p {
        case "P0": return "🔴"
        case "P1": return "🟡"
        case "P2": return "🟢"
        default: return "⚪"
        }
    }

    private func priorityColor(_ p: String?) -> Color {
        switch p {
        case "P0": return V4Color.statusError
        case "P1": return V4Color.statusWarn
        case "P2": return V4Color.statusOK
        default: return V4Color.textSecondary
        }
    }
}
