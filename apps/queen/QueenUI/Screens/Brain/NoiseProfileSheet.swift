import SwiftUI

// MARK: - NoiseProfileSheet

/// Modal sheet shown from the LOGS tab. Displays active noise rules and
/// auto-generated suggestions computed on-demand from currently loaded logs.
/// Users can apply suggestions with one tap to suppress repetitive noise.
struct NoiseProfileSheet: View {
    let entries: [LogEntry]
    @ObservedObject var ruleStore: NoiseRuleStore

    @State private var suggestions: [NoiseRuleSuggestion] = []
    @State private var isComputing = false
    @State private var minFrequency = NoiseRuleSuggester.defaultMinFrequency

    var body: some View {
        VStack(spacing: 0) {
            // Header
            sheetHeader

            Divider()

            // Content
            ScrollView {
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    // Active rules
                    activeRulesSection

                    // Auto-suggestions
                    if !suggestions.isEmpty {
                        suggestionsSection
                    } else if !isComputing {
                        noSuggestionsState
                    }
                }
                .padding()
            }
        }
        .background(V4Color.bgWindow)
        .frame(minWidth: 480, idealWidth: 560, minHeight: 400, idealHeight: 560)
        .onAppear { computeSuggestions() }
    }

    // MARK: - Header

    private var sheetHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Noise Profile")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(V4Color.textPrimary)
                Text("\(entries.count) entries analyzed across " +
                     "\(Set(entries.map(\.source)).count) source\(Set(entries.map(\.source)).count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
            }

            Spacer()

            Button {
                computeSuggestions()
            } label: {
                HStack(spacing: ParietalSpacing.xxs) {
                    if isComputing {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.caption)
                    }
                    Text("Re-scan")
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(V4Color.accent)
            }
            .buttonStyle(.plain)
            .disabled(isComputing)
        }
        .padding()
    }

    // MARK: - Active Rules

    private var activeRulesSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            Text("ACTIVE RULES")
                .font(.caption.weight(.bold))
                .foregroundStyle(V4Color.accent)

            if ruleStore.rules.isEmpty {
                Text("No noise rules active. Suggestions below are computed from current logs.")
                    .font(.caption)
                    .foregroundStyle(V4Color.textSecondary)
                    .padding(ParietalSpacing.sm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(V4Color.bgCard)
                    .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
            } else {
                ForEach(ruleStore.rules) { rule in
                    ActiveRuleRow(rule: rule, ruleStore: ruleStore)
                }
            }
        }
    }

    // MARK: - Suggestions

    private var suggestionsSection: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            HStack {
                Text("SUGGESTED (\(suggestions.count))")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(V4Color.statusWarn)

                Spacer()

                Text("Based on \(minFrequency)+ repeats")
                    .font(.caption2)
                    .foregroundStyle(V4Color.textSecondary)
            }

            ForEach(suggestions) { suggestion in
                SuggestionRow(suggestion: suggestion, ruleStore: ruleStore) {
                    applySuggestion(suggestion)
                }
            }
        }
    }

    private var noSuggestionsState: some View {
        VStack(spacing: ParietalSpacing.xs) {
            Image(systemName: "checkmark.seal.fill")
                .font(.title2)
                .foregroundStyle(V4Color.statusOK)
            Text("No repetitive noise detected")
                .font(.caption.weight(.semibold))
                .foregroundStyle(V4Color.textPrimary)
            Text("All current patterns are unique or already suppressed.")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(ParietalSpacing.xl)
    }

    // MARK: - Actions

    private func computeSuggestions() {
        isComputing = true
        // Run on next tick so the ProgressView can appear
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            let new = NoiseRuleSuggester.suggest(
                entries: entries,
                existingRules: ruleStore.rules,
                minFrequency: minFrequency
            )
            withAnimation(.easeInOut(duration: 0.2)) {
                suggestions = new
            }
            isComputing = false
        }
    }

    private func applySuggestion(_ suggestion: NoiseRuleSuggestion) {
        ruleStore.add(suggestion.asRule)
        // Remove from the list so it doesn't show again
        withAnimation {
            suggestions.removeAll { $0.id == suggestion.id }
        }
    }
}

// MARK: - Active Rule Row

private struct ActiveRuleRow: View {
    let rule: NoiseRule
    @ObservedObject var ruleStore: NoiseRuleStore

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            Image(systemName: rule.isEnabled ? "speaker.slash.fill" : "speaker.wave.2.fill")
                .font(.caption)
                .foregroundStyle(rule.isEnabled ? V4Color.accent : V4Color.textSecondary)

            VStack(alignment: .leading, spacing: 2) {
                Text(rule.label)
                    .font(.caption)
                    .foregroundStyle(V4Color.textPrimary)
                    .lineLimit(2)

                HStack(spacing: ParietalSpacing.xxs) {
                    Text(rule.source)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(V4Color.accent)
                    Text("•")
                        .foregroundStyle(V4Color.textSecondary)
                    Text(rule.matchType.rawValue)
                        .font(.caption2)
                        .foregroundStyle(V4Color.textSecondary)
                }
            }

            Spacer()

            // Toggle
            Toggle("", isOn: Binding(
                get: { rule.isEnabled },
                set: { _ in ruleStore.toggle(rule) }
            ))
            .labelsHidden()
            .controlSize(.small)

            // Delete
            Button {
                withAnimation {
                    ruleStore.remove(rule)
                }
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundStyle(V4Color.statusError)
            }
            .buttonStyle(.plain)
        }
        .padding(ParietalSpacing.sm)
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .opacity(rule.isEnabled ? 1.0 : 0.5)
    }
}

// MARK: - Suggestion Row

private struct SuggestionRow: View {
    let suggestion: NoiseRuleSuggestion
    @ObservedObject var ruleStore: NoiseRuleStore
    let onApply: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: ParietalSpacing.xs) {
            VStack(alignment: .leading, spacing: ParietalSpacing.xxs) {
                // Label
                Text(suggestion.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(V4Color.textPrimary)

                // Sample text
                Text(suggestion.sampleText)
                    .font(.caption2.monospaced())
                    .foregroundStyle(V4Color.textSecondary)
                    .lineLimit(2)

                // Meta
                HStack(spacing: ParietalSpacing.xxs) {
                    NoiseBadge(text: suggestion.source, color: V4Color.accent)
                    NoiseBadge(text: "\(suggestion.matchCount)×", color: V4Color.statusWarn)
                    NoiseBadge(text: suggestion.matchType.rawValue, color: V4Color.textSecondary)
                }
            }

            Spacer(minLength: ParietalSpacing.sm)

            // Apply button
            Button(action: onApply) {
                HStack(spacing: ParietalSpacing.xxs) {
                    Image(systemName: "speaker.slash.fill")
                        .font(.caption2)
                    Text("Suppress")
                        .font(.caption2.weight(.bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.vertical, ParietalSpacing.xs)
                .background(V4Color.accent)
                .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
            }
            .buttonStyle(.plain)
        }
        .padding(ParietalSpacing.sm)
        .background(V4Color.bgCard)
        .clipShape(RoundedRectangle(cornerRadius: V1Theme.cornerSmall))
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                .stroke(V4Color.border.opacity(0.5), lineWidth: 1)
        )
    }
}

// MARK: - NoiseBadge

private struct NoiseBadge: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.system(size: 9, weight: .bold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(color.opacity(0.15))
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}
