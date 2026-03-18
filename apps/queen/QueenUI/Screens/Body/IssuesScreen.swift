import SwiftUI

struct IssuesScreen: View {
    @State private var issues: [Issue] = []

    struct Issue: Codable, Identifiable {
        let number: Int
        let title: String?
        let assignees: [Assignee]?
        let labels: [IssueLabel]?

        var id: Int { number }
    }

    struct Assignee: Codable {
        let login: String?
    }

    struct IssueLabel: Codable {
        let name: String?
        let color: String?
    }

    var body: some View {
        ScrollView {
            VStack(spacing: TrinityTheme.spacing) {
                HStack {
                    Text("📋")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("ISSUES")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.accent)
                        Text("GitHub Issue Queue")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                    ActionButton(icon: "🔄", label: "Refresh", color: TrinityTheme.accent,
                                 action: "issues_refresh")
                    StatCard(label: "Open", value: "\(issues.count)")
                        .frame(width: 100)
                }
                .padding()

                // Label summary
                let labelCounts = countLabels()
                if !labelCounts.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 8) {
                        ForEach(labelCounts.sorted(by: { $0.value > $1.value }).prefix(6), id: \.key) { label, count in
                            HStack {
                                Text(label)
                                    .font(.caption2)
                                    .foregroundStyle(TrinityTheme.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(count)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(TrinityTheme.accent)
                            }
                            .padding(8)
                            .background(TrinityTheme.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal)
                }

                // Issue list
                ForEach(issues) { issue in
                    HStack(spacing: 12) {
                        Text("#\(issue.number)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(TrinityTheme.purple)
                            .frame(width: 50, alignment: .leading)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(issue.title ?? "Untitled")
                                .font(.body)
                                .foregroundStyle(TrinityTheme.textPrimary)
                                .lineLimit(2)

                            if let labels = issue.labels, !labels.isEmpty {
                                HStack(spacing: 4) {
                                    ForEach(labels.prefix(3), id: \.name) { label in
                                        Text(label.name ?? "")
                                            .font(.caption2)
                                            .foregroundStyle(TrinityTheme.textMuted)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(TrinityTheme.bgSidebar)
                                            .clipShape(SwiftUI.Capsule())
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(TrinityTheme.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .background(TrinityTheme.bgWindow)
        .onAppear { loadIssues() }
    }

    private func loadIssues() {
        let path = "\(FileManager.default.currentDirectoryPath)/.trinity/issues_snapshot.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        issues = (try? JSONDecoder().decode([Issue].self, from: data)) ?? []
    }

    private func countLabels() -> [String: Int] {
        var counts: [String: Int] = [:]
        for issue in issues {
            for label in issue.labels ?? [] {
                if let name = label.name {
                    counts[name, default: 0] += 1
                }
            }
        }
        return counts
    }
}
