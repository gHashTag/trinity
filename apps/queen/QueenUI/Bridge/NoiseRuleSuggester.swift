import Foundation

// MARK: - LogEntry

/// Unified representation of a single log line from any source.
/// Produced by `LogEntryCollector` from NetworkLog entries, agent events,
/// audit entries, and farm events so the suggester and UI can treat them
/// uniformly.
struct LogEntry: Identifiable, Equatable {
    let id: String
    let source: String     // "NetworkLog", "EventStream", "AuditLog", "FarmEvents"
    let timestamp: Date
    let message: String    // Raw message text used for pattern matching
    let severity: Severity

    enum Severity: String, Codable {
        case info
        case warning
        case error

        var icon: String {
            switch self {
            case .info:    return "ℹ️"
            case .warning: return "⚠️"
            case .error:   return "❌"
            }
        }
    }

    init(id: String, source: String, timestamp: Date, message: String, severity: Severity = .info) {
        self.id = id
        self.source = source
        self.timestamp = timestamp
        self.message = message
        self.severity = severity
    }
}

// MARK: - NoiseRuleSuggestion

/// A computed suggestion shown in the noise-profile sheet.
/// Each suggestion represents a high-frequency message pattern that the user
/// can suppress with a single tap.
struct NoiseRuleSuggestion: Identifiable, Equatable {
    let id: String
    let source: String
    let pattern: String        // Normalized pattern text
    let label: String          // Human-readable description
    let matchCount: Int        // How many entries matched
    let sampleText: String     // One real entry for preview
    let matchType: NoiseRule.MatchType

    /// The ready-to-apply rule derived from this suggestion.
    var asRule: NoiseRule {
        NoiseRule(
            source: source,
            pattern: pattern,
            matchType: matchType,
            label: label
        )
    }
}

// MARK: - NoiseRuleSuggester

/// Pure, side-effect-free analyzer that scans a batch of `LogEntry` values and
/// produces ranked noise-rule suggestions per source.
///
/// Algorithm:
/// 1. Group entries by `source`.
/// 2. For each source, normalize every message to a canonical form
///    (numbers → `<n>`, timestamps → `<ts>`, hex hashes → `<hex>`, paths → `<path>`).
/// 3. Count occurrences of each normalized pattern.
/// 4. Patterns at or above `minFrequency` become suggestions.
/// 5. Patterns already covered by an existing rule are excluded.
/// 6. Sort descending by match count.
struct NoiseRuleSuggester {

    /// Minimum number of occurrences for a pattern to be considered "noise".
    static let defaultMinFrequency = 5

    // MARK: - Public API

    static func suggest(
        entries: [LogEntry],
        existingRules: [NoiseRule],
        minFrequency: Int = defaultMinFrequency
    ) -> [NoiseRuleSuggestion] {
        // Group by source
        let grouped = Dictionary(grouping: entries, by: { $0.source })

        var suggestions: [NoiseRuleSuggestion] = []

        for (source, sourceEntries) in grouped {
            let sourceSuggestions = suggestForSource(
                source: source,
                entries: sourceEntries,
                existingRules: existingRules,
                minFrequency: minFrequency
            )
            suggestions.append(contentsOf: sourceSuggestions)
        }

        // Sort: highest matchCount first, then alphabetical by label
        return suggestions.sorted {
            if $0.matchCount != $1.matchCount {
                return $0.matchCount > $1.matchCount
            }
            return $0.label < $1.label
        }
    }

    // MARK: - Per-source analysis

    private static func suggestForSource(
        source: String,
        entries: [LogEntry],
        existingRules: [NoiseRule],
        minFrequency: Int
    ) -> [NoiseRuleSuggestion] {

        // Normalize and count
        var patternCounts: [String: Int] = [:]
        var patternSamples: [String: String] = [:]

        for entry in entries {
            let normalized = normalize(entry.message)
            patternCounts[normalized, default: 0] += 1
            // Keep the first real sample for each pattern
            if patternSamples[normalized] == nil {
                patternSamples[normalized] = entry.message
            }
        }

        // Existing patterns for this source — skip those already suppressed
        let existingPatterns = Set(
            existingRules
                .filter { $0.source == source }
                .map { $0.pattern }
        )

        var results: [NoiseRuleSuggestion] = []

        for (pattern, count) in patternCounts {
            guard count >= minFrequency else { continue }
            guard !existingPatterns.contains(pattern) else { continue }

            let sample = patternSamples[pattern] ?? pattern
            let matchType = bestMatchType(for: pattern)
            let label = humanLabel(pattern: pattern, source: source, count: count)

            results.append(NoiseRuleSuggestion(
                id: "\(source)::\(pattern)",
                source: source,
                pattern: pattern,
                label: label,
                matchCount: count,
                sampleText: sample,
                matchType: matchType
            ))
        }

        return results
    }

    // MARK: - Normalization

    /// Reduces a raw log message to a canonical pattern by masking
    /// variable portions (numbers, timestamps, hex, paths, UUIDs).
    static func normalize(_ message: String) -> String {
        var result = message

        // UUIDs — must run before hex (UUID segments look like hex)
        result = result.replacingOccurrences(
            of: #"\b[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}\b"#,
            with: "<uuid>",
            options: .regularExpression
        )
        // URLs — must run before paths (URLs contain path-like segments)
        result = result.replacingOccurrences(
            of: #"https?://[^\s]+"#,
            with: "<url>",
            options: .regularExpression
        )
        // ISO timestamps: 2026-07-29T12:34:56Z or 12:34:56.789
        result = result.replacingOccurrences(
            of: #"\d{4}-\d{2}-\d{2}[T ]\d{2}:\d{2}:\d{2}(\.\d+)?Z?"#,
            with: "<ts>",
            options: .regularExpression
        )
        // Epoch seconds / milliseconds: 1234567890 or 1234567890123
        result = result.replacingOccurrences(
            of: #"\b\d{10,13}\b"#,
            with: "<ts>",
            options: .regularExpression
        )
        // Hex hashes: 0x prefixed
        result = result.replacingOccurrences(
            of: #"0x[0-9a-fA-F]+"#,
            with: "<hex>",
            options: .regularExpression
        )
        // Hex hashes: standalone 8+ hex chars (but not the masked tokens themselves)
        result = result.replacingOccurrences(
            of: #"\b[0-9a-fA-F]{8,}\b"#,
            with: "<hex>",
            options: .regularExpression
        )
        // File paths: /Users/foo/bar or ./relative/path
        result = result.replacingOccurrences(
            of: #"(?:\.{0,2}/)?(?:[\w.-]+/)+[\w.-]+"#,
            with: "<path>",
            options: .regularExpression
        )
        // Remaining numbers (including decimals): 42, 3.14, 1_000, 1234ms
        // No trailing \b so "1234ms" → "<n>ms"
        result = result.replacingOccurrences(
            of: #"\d[\d_]*(?:\.\d+)?"#,
            with: "<n>",
            options: .regularExpression
        )
        // Collapse runs of whitespace
        result = result.replacingOccurrences(
            of: #"\s+"#,
            with: " ",
            options: .regularExpression
        )
        .trimmingCharacters(in: .whitespaces)

        // Truncate very long patterns to keep suggestions readable
        let maxLen = 120
        if result.count > maxLen {
            result = String(result.prefix(maxLen)) + "…"
        }

        return result
    }

    // MARK: - Heuristics

    /// Picks the most efficient match type for a pattern.
    /// If the pattern is short (≤40 chars), `.exact` is safest.
    /// If it contains masked tokens mid-string, `.contains` is better.
    private static func bestMatchType(for pattern: String) -> NoiseRule.MatchType {
        if pattern.count <= 40 && !pattern.contains("<") {
            return .exact
        }
        return .contains
    }

    /// Generates a short human-readable label for a suggestion.
    private static func humanLabel(pattern: String, source: String, count: Int) -> String {
        // Use the first meaningful words of the pattern
        let words = pattern
            .split(separator: " ")
            .prefix(5)
            .joined(separator: " ")
        return "Suppress \"\(words)\" in \(source) (\(count)×)"
    }
}
