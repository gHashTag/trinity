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
            VStack(spacing: TrinityTheme.spacing) {
                // Header
                HStack {
                    Text("🧠")
                        .font(.system(size: 48))
                    VStack(alignment: .leading) {
                        Text("MU MEMORY")
                            .font(.title.weight(.bold))
                            .foregroundStyle(TrinityTheme.purple)
                        Text("Learning Database — Pattern Recognition & Fixes")
                            .font(.subheadline)
                            .foregroundStyle(TrinityTheme.textMuted)
                    }
                    Spacer()
                }
                .padding()

                // Heartbeat status
                if let hb = watcher.heartbeats.first(where: { $0.displayName == "mu" }) {
                    AgentRow(
                        name: "MU",
                        status: hb.isUp ? .up : .down,
                        wakeCount: hb.wake,
                        detail: muDetail(hb)
                    )
                    .padding(.horizontal)
                }

                if let db = learningDB {
                    // Summary
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        StatCard(
                            label: "Rules",
                            value: "\(db.rules_count ?? db.rules?.count ?? 0)",
                            accent: TrinityTheme.accent
                        )
                        StatCard(
                            label: "Errors Scanned",
                            value: "\(db.total_errors_scanned ?? 0)",
                            accent: TrinityTheme.golden
                        )
                        StatCard(
                            label: "Version",
                            value: db.version ?? "—",
                            accent: TrinityTheme.purple
                        )
                    }
                    .padding(.horizontal)

                    // Category frequency
                    if let cats = db.category_frequency, !cats.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("CATEGORY FREQUENCY")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TrinityTheme.golden)
                                .padding(.horizontal)

                            ForEach(cats.sorted(by: { $0.value > $1.value }), id: \.key) { cat, count in
                                HStack {
                                    Text(categoryEmoji(cat))
                                    Text(cat)
                                        .font(.caption.weight(.medium))
                                        .foregroundStyle(TrinityTheme.textPrimary)
                                    Spacer()
                                    Text("\(count)")
                                        .font(.caption.weight(.bold).monospacedDigit())
                                        .foregroundStyle(count > 0 ? TrinityTheme.accent : TrinityTheme.textMuted)
                                }
                                .padding(.horizontal)
                                .padding(.vertical, 2)
                            }
                        }
                    }

                    // Learning rules
                    if let rules = db.rules, !rules.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("LEARNING RULES (\(rules.count))")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(TrinityTheme.accent)
                                .padding(.horizontal)

                            ForEach(rules) { rule in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(rule.id)
                                            .font(.caption.weight(.bold).monospaced())
                                            .foregroundStyle(TrinityTheme.accent)
                                        Spacer()
                                        if let cat = rule.category {
                                            Text(cat)
                                                .font(.caption2)
                                                .foregroundStyle(TrinityTheme.purple)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(TrinityTheme.purple.opacity(0.15))
                                                .clipShape(Capsule())
                                        }
                                    }
                                    if let desc = rule.description {
                                        Text(desc)
                                            .font(.caption)
                                            .foregroundStyle(TrinityTheme.textMuted)
                                    }
                                    HStack(spacing: 4) {
                                        Text(rule.pattern ?? "")
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(TrinityTheme.statusError)
                                        Text("→")
                                            .font(.caption2)
                                            .foregroundStyle(TrinityTheme.textMuted)
                                        Text(rule.replacement ?? "")
                                            .font(.caption2.monospaced())
                                            .foregroundStyle(TrinityTheme.statusOK)
                                    }
                                }
                                .padding()
                                .background(TrinityTheme.bgCard)
                                .clipShape(RoundedRectangle(cornerRadius: TrinityTheme.cardCorner))
                                .padding(.horizontal)
                            }
                        }
                    }
                } else {
                    VStack(spacing: 12) {
                        Text("No MU learning data")
                            .font(.headline)
                            .foregroundStyle(TrinityTheme.textPrimary)
                        Text(".trinity/mu/learning_db.json not found")
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
        .onAppear { loadLearningDB() }
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
