import SwiftUI

/// Proactive suggestion bar — shows contextual actions based on Trinity state.
/// "Build broken → Fix?", "New PPL record → Deploy?", "Stale arena → Run battle?"
struct SmartSuggestions: View {
    @StateObject private var trinityCtx = TrinityContext.shared
    var onSuggestion: (String) -> Void

    var body: some View {
        let suggestions = buildSuggestions()
        if suggestions.isEmpty { return AnyView(EmptyView()) }

        return AnyView(
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(suggestions, id: \.text) { suggestion in
                        Button {
                            onSuggestion(suggestion.prompt)
                        } label: {
                            HStack(spacing: 5) {
                                Text(suggestion.icon)
                                    .font(.system(size: 11))
                                Text(suggestion.text)
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(suggestion.urgent ? Color.black : Color.white.opacity(0.7))
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 5)
                            .background(suggestion.urgent ? suggestion.color : suggestion.color.opacity(0.12))
                            .clipShape(Capsule())
                            .overlay(
                                Capsule()
                                    .stroke(suggestion.color.opacity(0.3), lineWidth: suggestion.urgent ? 0 : 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 60)
                .padding(.vertical, 6)
            }
        )
    }

    struct Suggestion {
        let icon: String
        let text: String
        let prompt: String
        let color: Color
        let urgent: Bool
    }

    private func buildSuggestions() -> [Suggestion] {
        trinityCtx.refresh()
        var result: [Suggestion] = []

        // Build broken → urgent
        if trinityCtx.buildOK == false {
            result.append(Suggestion(
                icon: "\u{1F6A8}",
                text: "Build broken — diagnose?",
                prompt: "The build is broken. Please analyze the errors and suggest a fix.",
                color: TrinityTheme.statusError,
                urgent: true
            ))
        }

        // Best PPL improved recently
        if let ppl = trinityCtx.bestPPL, let run = trinityCtx.bestRun, ppl < 5.0 {
            result.append(Suggestion(
                icon: "\u{1F3C6}",
                text: "\(run) PPL=\(String(format: "%.1f", ppl)) — deploy?",
                prompt: "Run \(run) has PPL=\(String(format: "%.2f", ppl)). Should we deploy this as the production config? What's the risk?",
                color: TrinityTheme.golden,
                urgent: false
            ))
        }

        // Many dirty files
        if let dirty = trinityCtx.dirtyFiles, dirty > 30 {
            result.append(Suggestion(
                icon: "\u{1F9F9}",
                text: "\(dirty) dirty files — review?",
                prompt: "There are \(dirty) dirty files in the working tree. Help me review and organize these changes.",
                color: TrinityTheme.statusWarn,
                urgent: false
            ))
        }

        // Stale arena
        if let battles = trinityCtx.arenaBattles, battles == 0 {
            result.append(Suggestion(
                icon: "\u{2694}",
                text: "Arena idle — run battle?",
                prompt: "The arena has no recent battles. Let's run a comparison between trinity-hslm and the latest challenger.",
                color: TrinityTheme.purple,
                urgent: false
            ))
        }

        // Many open issues
        if let issues = trinityCtx.openIssues, issues > 20 {
            result.append(Suggestion(
                icon: "\u{1F4CB}",
                text: "\(issues) open issues — triage?",
                prompt: "We have \(issues) open issues. Help me prioritize and triage the most important ones.",
                color: TrinityTheme.accent,
                urgent: false
            ))
        }

        // Low score
        if let score = trinityCtx.ouroborosScore, score < 50 {
            result.append(Suggestion(
                icon: "\u{1F4C9}",
                text: "Score \(Int(score)) — improve?",
                prompt: "The Ouroboros score is only \(Int(score))/100. What are the top 3 things we should fix to improve it?",
                color: TrinityTheme.statusError,
                urgent: false
            ))
        }

        return result
    }
}
