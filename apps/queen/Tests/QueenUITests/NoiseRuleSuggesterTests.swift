import Testing
import Foundation
@testable import QueenUILib

@Suite("NoiseRuleSuggester")
struct NoiseRuleSuggesterTests {

    // MARK: - normalize()

    @Test func normalizeReplacesNumbers() {
        let result = NoiseRuleSuggester.normalize("Request took 1234ms and used 56 tokens")
        #expect(result == "Request took <n>ms and used <n> tokens")
    }

    @Test func normalizeReplacesTimestamps() {
        let result = NoiseRuleSuggester.normalize("2026-07-29T12:34:56Z cycle started")
        #expect(result == "<ts> cycle started")
    }

    @Test func normalizeReplacesEpochSeconds() {
        let result = NoiseRuleSuggester.normalize("ts=1722256496 ok")
        #expect(result == "ts=<ts> ok")
    }

    @Test func normalizeReplacesHexHashes() {
        let result = NoiseRuleSuggester.normalize("commit abc123def456 merged")
        #expect(result == "commit <hex> merged")
    }

    @Test func normalizeReplacesUUIDs() {
        let result = NoiseRuleSuggester.normalize("task 550e8400-e29b-41d4-a716-446655440000 done")
        #expect(result == "task <uuid> done")
    }

    @Test func normalizeReplacesPaths() {
        let result = NoiseRuleSuggester.normalize("wrote /Users/playra/trinity/src/main.zig")
        #expect(result.contains("<path>"))
        #expect(!result.contains("playra"))
    }

    @Test func normalizeReplacesURLs() {
        let result = NoiseRuleSuggester.normalize("fetched https://api.example.com/v1/models")
        #expect(result == "fetched <url>")
    }

    @Test func normalizeCollapsesWhitespace() {
        let result = NoiseRuleSuggester.normalize("too   much    space")
        #expect(result == "too much space")
    }

    @Test func normalizeTruncatesLongMessages() {
        // Use a realistic long message with repeated words (not all-hex)
        let long = String(repeating: "the quick brown fox ", count: 10)
        let result = NoiseRuleSuggester.normalize(long)
        #expect(result.count <= 121) // 120 chars + ellipsis
        #expect(result.hasSuffix("…"))
    }

    // MARK: - suggest()

    @Test func suggestFindsHighFrequencyPatterns() {
        let entries = (0..<10).map { i in
            LogEntry(
                id: "e-\(i)",
                source: "EventStream",
                timestamp: Date(),
                message: "Heartbeat from agent mu at step \(i)"
            )
        }

        let suggestions = NoiseRuleSuggester.suggest(
            entries: entries,
            existingRules: [],
            minFrequency: 5
        )

        #expect(suggestions.count == 1)
        let s = suggestions[0]
        #expect(s.source == "EventStream")
        #expect(s.matchCount == 10)
        #expect(s.pattern.contains("<n>"))
    }

    @Test func suggestRespectsMinFrequency() {
        var entries: [LogEntry] = []
        // 3 repetitions of pattern A
        for i in 0..<3 {
            entries.append(LogEntry(id: "a-\(i)", source: "S", timestamp: Date(), message: "Pattern A at \(i)"))
        }
        // 6 repetitions of pattern B
        for i in 0..<6 {
            entries.append(LogEntry(id: "b-\(i)", source: "S", timestamp: Date(), message: "Pattern B at \(i)"))
        }

        let suggestions = NoiseRuleSuggester.suggest(
            entries: entries,
            existingRules: [],
            minFrequency: 5
        )

        // Only pattern B meets threshold
        #expect(suggestions.count == 1)
        #expect(suggestions[0].matchCount == 6)
    }

    @Test func suggestGroupsBySource() {
        var entries: [LogEntry] = []
        for i in 0..<7 {
            entries.append(LogEntry(id: "n-\(i)", source: "NetworkLog", timestamp: Date(), message: "Request to model-\(i) failed"))
            entries.append(LogEntry(id: "e-\(i)", source: "EventStream", timestamp: Date(), message: "Agent heartbeat \(i)"))
        }

        let suggestions = NoiseRuleSuggester.suggest(
            entries: entries,
            existingRules: [],
            minFrequency: 5
        )

        let sources = Set(suggestions.map(\.source))
        #expect(sources.contains("NetworkLog"))
        #expect(sources.contains("EventStream"))
    }

    @Test func suggestExcludesPatternsCoveredByExistingRules() {
        let entries = (0..<10).map { i in
            LogEntry(id: "e-\(i)", source: "S", timestamp: Date(), message: "Repeated message \(i)")
        }

        let existingRule = NoiseRule(
            source: "S",
            pattern: NoiseRuleSuggester.normalize("Repeated message 0"),
            matchType: .contains,
            label: "existing"
        )

        let suggestions = NoiseRuleSuggester.suggest(
            entries: entries,
            existingRules: [existingRule],
            minFrequency: 5
        )

        #expect(suggestions.isEmpty)
    }

    @Test func suggestReturnsEmptyForUniqueEntries() {
        // Each message has a structurally different template so normalization
        // produces 5 distinct patterns — none repeated enough to trigger.
        let messages = [
            "Build completed successfully in 42 seconds",
            "Agent mu deployed new version with hash abc12345",
            "Farm service train-ONE reached ppl 2.8943",
            "Heartbeat received from scholar at 12:00:00",
            "Audit verdict auto_pending for action deploy"
        ]
        let entries = messages.enumerated().map { i, msg in
            LogEntry(id: "e-\(i)", source: "S", timestamp: Date(), message: msg)
        }

        let suggestions = NoiseRuleSuggester.suggest(
            entries: entries,
            existingRules: [],
            minFrequency: 5
        )

        #expect(suggestions.isEmpty)
    }

    @Test func suggestSortsByMatchCountDescending() {
        var entries: [LogEntry] = []
        // Pattern A: 8 occurrences
        for i in 0..<8 {
            entries.append(LogEntry(id: "a-\(i)", source: "S", timestamp: Date(), message: "Frequent pattern \(i)"))
        }
        // Pattern B: 15 occurrences
        for i in 0..<15 {
            entries.append(LogEntry(id: "b-\(i)", source: "S", timestamp: Date(), message: "Very frequent pattern \(i)"))
        }

        let suggestions = NoiseRuleSuggester.suggest(
            entries: entries,
            existingRules: [],
            minFrequency: 5
        )

        #expect(suggestions.count == 2)
        #expect(suggestions[0].matchCount >= suggestions[1].matchCount)
    }

    @Test func suggestionAsRuleProducesWorkingRule() {
        let suggestion = NoiseRuleSuggestion(
            id: "test",
            source: "EventStream",
            pattern: "Heartbeat from agent",
            label: "test label",
            matchCount: 10,
            sampleText: "Heartbeat from agent 5",
            matchType: .contains
        )

        let rule = suggestion.asRule
        #expect(rule.source == "EventStream")
        #expect(rule.pattern == "Heartbeat from agent")
        #expect(rule.matchType == .contains)
        // contains match against raw message
        #expect(rule.matches("Heartbeat from agent 42 ok"))
        #expect(!rule.matches("Unrelated message"))
    }
}

@Suite("NoiseRule")
struct NoiseRuleTests {

    @Test func exactMatch() {
        let rule = NoiseRule(source: "S", pattern: "exact text", matchType: .exact, label: "test")
        #expect(rule.matches("exact text"))
        #expect(!rule.matches("exact text extra"))
        #expect(!rule.matches("EXACT TEXT"))
    }

    @Test func containsMatchIsCaseInsensitive() {
        let rule = NoiseRule(source: "S", pattern: "error", matchType: .contains, label: "test")
        #expect(rule.matches("An ERROR occurred"))
        #expect(rule.matches("error in module"))
        #expect(!rule.matches("all good"))
    }

    @Test func prefixMatch() {
        let rule = NoiseRule(source: "S", pattern: "WARN:", matchType: .prefix, label: "test")
        #expect(rule.matches("WARN: something happened"))
        #expect(rule.matches("warn: lowercase"))
        #expect(!rule.matches("ERROR: something"))
    }

    @Test func disabledRuleDoesNotMatch() {
        var rule = NoiseRule(source: "S", pattern: "test", matchType: .exact, label: "test")
        rule.isEnabled = false
        #expect(!rule.matches("test"))
    }
}

@MainActor
@Suite("NoiseRuleStore")
struct NoiseRuleStoreTests {

    @Test func storePersistsAndFilters() {
        let store = NoiseRuleStore.shared
        store.clearAll()

        let rule = NoiseRule(
            source: "EventStream",
            pattern: "repetitive noise",
            matchType: .contains,
            label: "test"
        )

        store.add(rule)
        #expect(store.rules.count == 1)
        #expect(store.isSuppressed("This is repetitive noise here", source: "EventStream"))
        #expect(!store.isSuppressed("This is fine", source: "EventStream"))
        // Different source — should not suppress
        #expect(!store.isSuppressed("repetitive noise", source: "OtherSource"))

        store.remove(rule)
        #expect(store.rules.isEmpty)
        #expect(!store.isSuppressed("repetitive noise", source: "EventStream"))

        store.clearAll()
    }

    @Test func storeToggleEnablesDisables() {
        let store = NoiseRuleStore.shared
        store.clearAll()

        let rule = NoiseRule(source: "S", pattern: "x", matchType: .exact, label: "t")
        store.add(rule)
        #expect(store.rules[0].isEnabled == true)

        store.toggle(rule)
        #expect(store.rules[0].isEnabled == false)

        store.clearAll()
    }
}
