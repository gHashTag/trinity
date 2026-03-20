import SwiftUI

struct MUMemoryScreen: View {
    @EnvironmentObject var watcher: StateWatcher
    @State private var learningDB: LearningDB?

    struct LearningDB: Codable {
        let version: String?
        let total_errors_scanned: Int?
        let rules_count: Int?
        let category_frequency: [String: Int]?
        let rules: [LearningRule]?
    }

    struct LearningRule: Codable, Identifiable {
        let id: String
        let pattern: String?
        let replacement: String?
        let category: String?
        let description: String?
    }

    var body: some View {
        ScrollView {
            VStack(spacing: ParietalSpacing.standard) {
                headerView
                heartbeatView
                contentView
            }
            .padding(.bottom)
        }
        .background(V4Color.bgWindow)
        .onAppear { loadLearningDB() }
    }

    private var headerView: some View {
        HStack {
            Text("🧠")
                .font(WernickeTypography.size48)
            VStack(alignment: .leading) {
                Text("MU MEMORY")
                    .font(.title.weight(.bold))
                    .foregroundStyle(V4Color.purple)
                Text("Learning Database — Pattern Recognition & Fixes")
                    .font(.subheadline)
                    .foregroundStyle(V4Color.textSecondary)
            }
            Spacer()
        }
        .padding()
    }

    private var heartbeatView: some View {
        Group {
            if let hb = watcher.heartbeats.first(where: { $0.displayName == "mu" }) {
                AgentRow(
                    name: "MU",
                    status: hb.isUp ? .up : .down,
                    wakeCount: hb.wake,
                    detail: muDetail(hb)
                )
                .padding(.horizontal)
            }
        }
    }

    @ViewBuilder
    private var contentView: some View {
        if let db = learningDB {
            summaryView(db: db)
            categoryFrequencyView(db: db)
            learningRulesView(db: db)
        } else {
            emptyStateView
        }
    }

    private func summaryView(db: LearningDB) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: ParietalSpacing.md) {
            StatCard(
                label: "Rules",
                value: "\(db.rules_count ?? db.rules?.count ?? 0)",
                accent: V4Color.accent
            )
            StatCard(
                label: "Errors Scanned",
                value: "\(db.total_errors_scanned ?? 0)",
                accent: V4Color.golden
            )
            StatCard(
                label: "Version",
                value: db.version ?? "—",
                accent: V4Color.purple
            )
        }
        .padding(.horizontal)
    }

    @ViewBuilder
    private func categoryFrequencyView(db: LearningDB) -> some View {
        if let cats = db.category_frequency, !cats.isEmpty {
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Text("CATEGORY FREQUENCY")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.golden)
                    .padding(.horizontal)

                ForEach(cats.sorted(by: { $0.value > $1.value }), id: \.key) { cat, count in
                    categoryRow(cat: cat, count: count)
                }
            }
        }
    }

    private func categoryRow(cat: String, count: Int) -> some View {
        HStack {
            Text(categoryEmoji(cat))
            Text(cat)
                .font(.caption.weight(.medium))
                .foregroundStyle(V4Color.textPrimary)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.bold).monospacedDigit())
                .foregroundStyle(count > 0 ? V4Color.accent : V4Color.textSecondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func learningRulesView(db: LearningDB) -> some View {
        if let rules = db.rules, !rules.isEmpty {
            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                Text("LEARNING RULES (\(rules.count))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.accent)
                    .padding(.horizontal)

                ForEach(rules) { rule in
                    ruleRow(rule: rule)
                }
            }
        }
    }

    private func ruleRow(rule: LearningRule) -> some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack {
                Text(rule.id)
                    .font(.caption.weight(.bold).monospaced())
                    .foregroundStyle(V4Color.accent)
                Spacer()
                if let cat = rule.category {
                    Text(cat)
                        .font(.caption2)
                        .foregroundStyle(V4Color.purple)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(V4Color.purple.opacity(V2Depth.bgSidebarHover))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            if let desc = rule.description {
                Text(desc)
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }
            HStack(spacing: ParietalSpacing.xs) {
                Text(rule.pattern ?? "")
                    .font(.caption2.monospaced())
                    .foregroundStyle(V4Color.statusError)
                Text("→")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
                Text(rule.replacement ?? "")
                    .font(.caption2.monospaced())
                    .foregroundStyle(V4Color.statusOK)
            }
        }
        .padding()
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerLarge))
        .padding(.horizontal)
    }

    private var emptyStateView: some View {
        VStack(spacing: ParietalSpacing.md) {
            Text("No MU learning data")
                .font(.headline)
                .foregroundStyle(V4Color.textPrimary)
            Text(".trinity/mu/learning_db.json not found")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(ParietalSpacing.xxl)
    }

    private func loadLearningDB() {
        let cwd = FileManager.default.currentDirectoryPath
        if let data = try? Data(contentsOf: URL(fileURLWithPath: "\(cwd)/.trinity/mu/learning_db.json")) {
            learningDB = try? JSONDecoder().decode(LearningDB.self, from: data)
        }
    }

    private func muDetail(_ hb: AgentHeartbeat) -> String {
        var parts: [String] = []
        if let b = hb.build_ok { parts.append(b ? "Build OK" : "Build FAIL") }
        if let t = hb.test_ok { parts.append(t ? "Tests OK" : "Tests FAIL") }
        return parts.isEmpty ? "Active" : parts.joined(separator: ", ")
    }

    private func categoryEmoji(_ cat: String) -> String {
        switch cat {
        case "TYPE_MAPPING": return "🔤"
        case "UNDEFINED_IDENTIFIER": return "❓"
        case "SYNTAX_ERROR": return "⚠️"
        case "FORMAT_ERROR": return "📝"
        case "IMPORT_ERROR": return "📦"
        case "MEMORY_ERROR": return "💾"
        case "TEST_FAILURE": return "🧪"
        case "GEN_FAILURE": return "⚙️"
        default: return "📡"
        }
    }
}
