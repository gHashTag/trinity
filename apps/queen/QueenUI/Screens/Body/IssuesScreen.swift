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
            VStack(spacing: ParietalSpacing.standard) {
                HStack {
                    Text("📋")
                        .font(WernickeTypography.size48)
                    VStack(alignment: .leading) {
                        Text("ISSUES")
                            .font(.title.weight(.bold))
                            .foregroundStyle(V4Color.accent)
                        Text("GitHub Issue Queue")
                            .font(.subheadline)
                            .foregroundStyle(V4Color.textSecondary)
                    }
                    Spacer()
                    ActionButton(icon: "🔄", label: "Refresh", color: V4Color.accent,
                                 action: "issues_refresh")
                    StatCard(label: "Open", value: "\(issues.count)")
                        .frame(width: ParietalSpacing.xxLargeFrame)
                }
                .padding()

                // Label summary
                let labelCounts = countLabels()
                if !labelCounts.isEmpty {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: ParietalSpacing.sm) {
                        ForEach(labelCounts.sorted(by: { $0.value > $1.value }).prefix(6), id: \.key) { label, count in
                            HStack {
                                Text(label)
                                    .font(.caption2)
                                    .foregroundStyle(V4Color.textPrimary)
                                    .lineLimit(1)
                                Spacer()
                                Text("\(count)")
                                    .font(.caption.weight(.bold).monospacedDigit())
                                    .foregroundStyle(V4Color.accent)
                            }
                            .padding(8)
                            .background(V4Color.bgCard)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal)
                }

                // Issue list
                ForEach(issues) { issue in
                    HStack(spacing: ParietalSpacing.md) {
                        Text("#\(issue.number)")
                            .font(.caption.weight(.bold).monospacedDigit())
                            .foregroundStyle(V4Color.purple)
                            .frame(width: ParietalSpacing.mediumFrame, alignment: .leading)

                        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                            Text(issue.title ?? "Untitled")
                                .font(.body)
                                .foregroundStyle(V4Color.textPrimary)
                                .lineLimit(2)

                            if let labels = issue.labels, !labels.isEmpty {
                                HStack(spacing: ParietalSpacing.xs) {
                                    ForEach(labels.prefix(3), id: \.name) { label in
                                        Text(label.name ?? "")
                                            .font(.caption2)
                                            .foregroundStyle(V4Color.textSecondary)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(V4Color.sidebar)
                                            .clipShape(SwiftUI.Capsule())
                                    }
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding()
                    .background(V4Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
                    .padding(.horizontal)
                }
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
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
