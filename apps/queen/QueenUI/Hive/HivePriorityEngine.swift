import Foundation

/// Ranks the parts of the Queen's own system by how much they need work.
///
/// Pure: facts in, ranked targets out. No disk, no clock, no network - so the
/// ranking is reproducible and testable. `HiveRepoScanner` supplies the facts.
///
/// Two rules the arithmetic enforces:
///   1. An unmeasured signal is excluded from the score, not counted as zero.
///      Its weight is removed from the denominator and shows up as lost
///      confidence instead.
///   2. Normalization is against a fixed declared scale per signal
///      (`HiveSignal.Kind.scale`), not against the scanned set. A score is
///      therefore a property of the module and survives both the removal of
///      another module and the passage of a scan cycle.
enum HivePriorityEngine {

    static func rank(_ facts: [HiveModuleFacts]) -> [HiveTarget] {
        guard !facts.isEmpty else { return [] }

        let raws = facts.map { rawReadings(for: $0) }

        var targets: [HiveTarget] = []
        for (index, fact) in facts.enumerated() {
            let readings = raws[index]
            var signals: [HiveSignal] = []

            for kind in HiveSignal.Kind.allCases {
                let raw = readings[kind] ?? .unmeasured("not read")
                let normalized: HiveSignalState
                switch raw {
                case .unmeasured(let why):
                    normalized = .unmeasured(why)
                case .measured(let value):
                    // A signal with no declared scale is already in 0...1 and
                    // passes straight through; dividing it again by whatever
                    // the set happened to contain would destroy the only
                    // absolute calibration the instrument has.
                    if let scale = kind.scale, scale > 0 {
                        normalized = .measured(min(1.0, max(0.0, value / scale)))
                    } else {
                        normalized = .measured(min(1.0, max(0.0, value)))
                    }
                }
                signals.append(HiveSignal(kind: kind, raw: raw, normalized: normalized))
            }

            let measuredWeight = signals
                .filter { $0.normalized.isMeasured }
                .reduce(0.0) { $0 + $1.kind.weight }
            let totalWeight = HiveSignal.Kind.allCases.reduce(0.0) { $0 + $1.weight }

            let weighted = signals.reduce(0.0) { acc, signal in
                guard let n = signal.normalized.value else { return acc }
                return acc + n * signal.kind.weight
            }

            // Renormalize over the measured subset: a module we could only
            // half-measure is not thereby half as urgent.
            let score = measuredWeight > 0 ? weighted / measuredWeight : 0
            let confidence = totalWeight > 0 ? measuredWeight / totalWeight : 0

            targets.append(
                HiveTarget(
                    module: fact.module,
                    path: fact.path,
                    realm: fact.realm,
                    signals: signals,
                    score: score,
                    confidence: confidence
                )
            )
        }

        // Ordered on the full-weight reading, so thin evidence cannot buy a
        // place at the top of the queue. Confidence breaks ties so a
        // well-measured target wins over an equally-scored guess, and the
        // module name makes the result deterministic.
        return targets.sorted {
            if $0.rankingScore != $1.rankingScore { return $0.rankingScore > $1.rankingScore }
            if $0.confidence != $1.confidence { return $0.confidence > $1.confidence }
            return $0.module < $1.module
        }
    }

    // MARK: - Raw readings

    /// Turn measured facts into per-signal raw readings, carrying the reason
    /// forward whenever the scanner could not read something.
    static func rawReadings(for fact: HiveModuleFacts) -> [HiveSignal.Kind: HiveSignalState] {
        var out: [HiveSignal.Kind: HiveSignalState] = [:]
        let kilolines = Double(fact.lines ?? 0) / 1000.0

        // TODO density - markers per thousand lines.
        if let todos = fact.todos, let lines = fact.lines, lines > 0 {
            out[.todoDensity] = .measured(Double(todos) / max(kilolines, 0.001))
        } else {
            out[.todoDensity] = .unmeasured(
                fact.unmeasuredReasons[.todoDensity] ?? "no line count for this module"
            )
        }

        // Churn - commits touching the module in the last 30 days.
        if let churn = fact.churn30d {
            out[.churn] = .measured(Double(churn))
        } else {
            out[.churn] = .unmeasured(
                fact.unmeasuredReasons[.churn] ?? "git history not read"
            )
        }

        // Test gap - inverse of test density, so more tests means less need.
        if let tests = fact.testBlocks, let lines = fact.lines, lines > 0 {
            let density = Double(tests) / max(kilolines, 0.001)
            // 6 test blocks per kLOC is treated as saturated coverage.
            out[.testGap] = .measured(max(0, 1.0 - min(density / 6.0, 1.0)))
        } else {
            out[.testGap] = .unmeasured(
                fact.unmeasuredReasons[.testGap] ?? "test blocks not counted"
            )
        }

        // Size risk - raw scale, normalized against the largest module.
        if let lines = fact.lines {
            out[.sizeRisk] = .measured(Double(lines))
        } else {
            out[.sizeRisk] = .unmeasured(
                fact.unmeasuredReasons[.sizeRisk] ?? "module not sized"
            )
        }

        // Declared incomplete - the cell's own word about itself.
        if let status = fact.declaredStatus?.lowercased(), !status.isEmpty {
            let incomplete = ["stub", "planned", "todo", "draft", "wip"].contains(status)
            out[.declaredIncomplete] = .measured(incomplete ? 1 : 0)
        } else {
            out[.declaredIncomplete] = .unmeasured(
                fact.unmeasuredReasons[.declaredIncomplete] ?? "no cell.tri status declared"
            )
        }

        // Open issues bound to the module.
        if let issues = fact.openIssues {
            out[.openIssues] = .measured(Double(issues))
        } else {
            out[.openIssues] = .unmeasured(
                fact.unmeasuredReasons[.openIssues] ?? "issues snapshot absent"
            )
        }

        return out
    }
}

// MARK: - Task synthesis

/// Turns a ranked target into the task and the prompt a bee will execute.
enum HiveTaskFactory {

    /// Deterministic id so the same weakness on the same module is one task,
    /// not a new one every cycle.
    static func taskID(module: String, kind: HiveSignal.Kind) -> String {
        let slug = module
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "-")
            .lowercased()
        return "hive-\(slug)-\(kind.rawValue)"
    }

    /// Why a target produced no task. `nil` means it did.
    ///
    /// Returning the reason rather than a bare nil lets the caller record what
    /// the Queen declined to work on, which is itself a reading: a module the
    /// scanner keeps failing to measure is a fault in the instrument, and it
    /// should be visible instead of vanishing between cycles.
    static func rejection(for target: HiveTarget) -> String? {
        guard target.dominantKind != nil else {
            return "no signal drove the score"
        }
        guard target.confidence >= HiveInvariants.minimumDispatchConfidence else {
            return String(
                format: "confidence %.0f%% is below the %.0f%% floor - too little of this module was measured to justify a bee",
                target.confidence * 100,
                HiveInvariants.minimumDispatchConfidence * 100
            )
        }
        return nil
    }

    static func makeTask(from target: HiveTarget, policy: HivePolicy) -> HiveTask? {
        guard rejection(for: target) == nil, let kind = target.dominantKind else { return nil }
        let title = "\(target.module): \(kind.label.lowercased())"
        return HiveTask(
            id: taskID(module: target.module, kind: kind),
            title: title,
            module: target.module,
            path: target.path,
            realm: target.realm.rawValue,
            signalKind: kind.rawValue,
            reason: target.reason,
            score: target.score,
            confidence: target.confidence,
            prompt: prompt(for: target, kind: kind, policy: policy)
        )
    }

    /// The bee's brief. Repo rules are NOT restated here - the bee runs inside
    /// the repository, so CLAUDE.md and .claude/rules/ load themselves, and a
    /// second copy here could drift out of step with them.
    static func prompt(for target: HiveTarget, kind: HiveSignal.Kind, policy: HivePolicy) -> String {
        let measured = target.signals.compactMap { signal -> String? in
            switch signal.raw {
            case .measured(let v):
                let text = v == v.rounded() ? String(Int(v)) : String(format: "%.2f", v)
                return "  - \(signal.kind.label): \(text)"
            case .unmeasured:
                return nil
            }
        }.joined(separator: "\n")

        let unmeasured = target.signals.compactMap { signal -> String? in
            if case .unmeasured(let why) = signal.raw {
                return "  - \(signal.kind.label): NOT MEASURED (\(why))"
            }
            return nil
        }.joined(separator: "\n")

        let pushRule = policy.allowPush
            ? "Push is permitted by policy, but never force-push and never merge to main."
            : "Do NOT push, do NOT open a PR, do NOT merge. The Queen reviews before anything leaves this machine."

        return """
        You are a hive bee working under the Trinity Queen. You have exactly one task.

        TASK: \(target.module) - \(kind.label.lowercased())
        PATH: \(target.path)
        WHAT TO DO: \(kind.remedy).

        WHY THE QUEEN PICKED THIS
        Measured signals for this module:
        \(measured.isEmpty ? "  - (none)" : measured)
        \(unmeasured.isEmpty ? "" : "Signals she could NOT read - treat these as unknown, not as zero:\n\(unmeasured)")
        Ranking confidence: \(Int(target.confidence * 100))% of the signal weight was actually measured.

        HOW TO WORK
        1. Read \(target.path) and whatever tests already cover it.
        2. Measure the current state of the thing you are about to change, and write the number down.
        3. Make the smallest change that improves it. Stay inside \(target.path) unless a caller must change too.
        4. Run this project's own checks for this module and report what passed and what failed.
        5. Measure again. Report before and after.
        6. Commit with a bilingual message as CLAUDE.md requires.

        RULES
        - This repository's CLAUDE.md and .claude/rules/ govern. If anything here contradicts them, they win.
        - \(pushRule)
        - Stage named paths only. Never `git add -A` - other sessions share this working copy.
        - If you cannot improve this honestly, change nothing and say so. A result you did not measure is not a zero, and "no change needed" is a valid, valuable answer.
        - Do NOT optimise the signal that selected this task. The Queen picked it from a measurement, and a measurement stops meaning anything the moment work is aimed at the number instead of the thing. Trivial tests that raise coverage, TODO markers deleted without resolving what they described, files split to lower a size score - all of these move the metric and improve nothing. Fix the underlying weakness or report that there is none.

        FINISH BY REPORTING
        One paragraph: what you changed, the before and after numbers, what you deliberately did not do, and anything the Queen should re-prioritise as a result.
        """
    }
}
