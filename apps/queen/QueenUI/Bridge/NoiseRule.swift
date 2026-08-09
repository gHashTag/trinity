import Foundation

// MARK: - NoiseRule

/// A user-defined or auto-suggested rule that suppresses repetitive log entries
/// from a specific source. Persisted to UserDefaults so rules survive app restarts.
struct NoiseRule: Codable, Identifiable, Equatable, Hashable {
    let id: String
    let source: String       // e.g. "NetworkLog", "EventStream", "AuditLog"
    let pattern: String      // Normalized pattern to match against message text
    let matchType: MatchType
    let label: String        // Human-readable description
    let createdAt: Date
    var isEnabled: Bool

    enum MatchType: String, Codable, CaseIterable {
        case exact
        case contains
        case prefix
    }

    init(
        id: String = UUID().uuidString,
        source: String,
        pattern: String,
        matchType: MatchType,
        label: String,
        createdAt: Date = Date(),
        isEnabled: Bool = true
    ) {
        self.id = id
        self.source = source
        self.pattern = pattern
        self.matchType = matchType
        self.label = label
        self.createdAt = createdAt
        self.isEnabled = isEnabled
    }

    /// Tests whether a raw message string is suppressed by this rule.
    func matches(_ message: String) -> Bool {
        guard isEnabled else { return false }
        switch matchType {
        case .exact:
            return message == pattern
        case .contains:
            return message.localizedCaseInsensitiveContains(pattern)
        case .prefix:
            return message.lowercased().hasPrefix(pattern.lowercased())
        }
    }
}

// MARK: - NoiseRuleStore

/// Singleton that owns the active noise-rule set, persists it to UserDefaults,
/// and provides filtering for any collection of log entries.
@MainActor
final class NoiseRuleStore: ObservableObject {

    static let shared = NoiseRuleStore()

    @Published private(set) var rules: [NoiseRule] = []

    private let storageKey = "queen.logs.noiseRules"
    private let defaults = UserDefaults.standard

    private init() {
        load()
    }

    // MARK: - CRUD

    func add(_ rule: NoiseRule) {
        guard !rules.contains(where: { $0.id == rule.id }) else { return }
        rules.append(rule)
        save()
    }

    func remove(_ rule: NoiseRule) {
        rules.removeAll { $0.id == rule.id }
        save()
    }

    func toggle(_ rule: NoiseRule) {
        guard let idx = rules.firstIndex(where: { $0.id == rule.id }) else { return }
        rules[idx].isEnabled.toggle()
        save()
    }

    func rulesFor(source: String) -> [NoiseRule] {
        rules.filter { $0.source == source }
    }

    func clearAll() {
        rules.removeAll()
        save()
    }

    // MARK: - Filtering

    /// Returns `true` when the message should be **suppressed** (hidden) by any
    /// active rule for the given source. The raw message is normalized before
    /// matching so that patterns containing masked tokens (e.g. `<n>`, `<ts>`)
    /// correctly match their concrete counterparts.
    func isSuppressed(_ message: String, source: String) -> Bool {
        let normalized = NoiseRuleSuggester.normalize(message)
        return rules.contains { rule in
            rule.source == source && (rule.matches(message) || rule.matches(normalized))
        }
    }

    // MARK: - Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(rules) {
            defaults.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data = defaults.data(forKey: storageKey) else { return }
        rules = (try? JSONDecoder().decode([NoiseRule].self, from: data)) ?? []
    }
}
