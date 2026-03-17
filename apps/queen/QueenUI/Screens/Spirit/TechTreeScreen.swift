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
            VStack(spacing: TrinityTheme.spacing) {
                // Header
                HStack {
                    Text("🌳")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("TECH TREE")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("Issue DAG — Prerequisites & Critical Path")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    if let tree = techTree {
                        VStack(alignment: .trailing) {
                            Text("\(tree.epics?.count ?? 0)")
                                .font(.title.weight(.bold).monospacedDigit())
                                .foregroundStyle(TrinityTheme.golden)
                            Text("epics")
                                .font(.caption)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                    }
                }
                .padding()

                // Summary
                if let tree = techTree, let epics = tree.epics {
                    let totalChildren = epics.flatMap { $0.children ?? [] }
                    let closed = totalChildren.filter(\.isClosed).count

                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(label: "Epics", value: "\(epics.count)", accent: TrinityTheme.golden)
                        StatCard(label: "Tasks", value: "\(totalChildren.count)", accent: TrinityTheme.accent)
                        StatCard(
                            label: "Completed",
                            value: "\(closed)/\(totalChildren.count)",
                            accent: TrinityTheme.statusOK
                        )
                    }
                    .padding(.horizontal)

                    // Progress bar
                    if !totalChildren.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            let progress = Double(closed) / Double(totalChildren.count)
                            GeometryReader { geo in
                                ZStack(alignment: .leading) {
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(TrinityTheme.bgCard)
                                    RoundedRectangle(cornerRadius: 4)
                                        .fill(TrinityTheme.accent)
                                        .frame(width: geo.size.width * progress)
                                }
                            }
                            .frame(height: 8)
                            Text(String(format: "%.0f%% complete", Double(closed) / Double(totalChildren.count) * 100))
                                .font(.caption)
                                .foregroundStyle(TrinityTheme.textMuted)
                        }
                        .padding(.horizontal)
                    }

                    // Epics
                    ForEach(epics) { epic in
                        VStack(alignment: .leading, spacing: 8) {
                            // Epic header
                            HStack {
                                Text(priorityEmoji(epic.priority))
                                Text("#\(epic.issue)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(TrinityTheme.purple)
                                Text(epic.title ?? "Untitled")
                                    .font(.headline)
                                    .foregroundStyle(TrinityTheme.textPrimary)
                                Spacer()
                                Text(epic.priority ?? "")
                                    .font(.caption2.weight(.bold))
                                    .foregroundStyle(priorityColor(epic.priority))
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(priorityColor(epic.priority).opacity(0.15))
                                    .clipShape(Capsule())
                            }

                            // Children
                            if let children = epic.children, !children.isEmpty {
                                ForEach(children) { child in
                                    HStack(spacing: 8) {
                                        Image(systemName: child.isClosed ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(child.isClosed ? TrinityTheme.statusOK : TrinityTheme.textMuted)
                                            .font(.caption)

                                        Text("#\(child.issue)")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(TrinityTheme.purple)

                                        Text(child.title ?? "")
                                            .font(.caption)
                                            .foregroundStyle(child.isClosed ? TrinityTheme.textMuted : TrinityTheme.textPrimary)
                                            .strikethrough(child.isClosed)

                                        Spacer()

                                        if let prereqs = child.prereqs, !prereqs.isEmpty {
                                            Text("← \(prereqs.map { "#\($0)" }.joined(separator: ", "))")
                                                .font(.caption2)
                                                .foregroundStyle(TrinityTheme.textMuted)
                                        }
                                    }
                                    .padding(.leading, 16)
                                }
                            }
                        }
                        .padding()
                        .background(TrinityTheme.bgCard)
                        .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                        .padding(.horizontal)
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("No tech tree data")
                            .font(.headline)
                            .foregroundStyle(TrinityTheme.textPrimary)
                        Text(".trinity/tech_tree.json not found")
                            .font(.caption)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(32)
                }
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
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
        case "P0": return TrinityTheme.statusError
        case "P1": return TrinityTheme.statusWarn
        case "P2": return TrinityTheme.statusOK
        default: return TrinityTheme.textMuted
        }
    }
}
