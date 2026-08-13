import Foundation

// MARK: - The queue

/// What one scan produced: the part of the system the evidence can rank, and
/// the part where the fault is in the instrument rather than in the code.
///
/// Two lists rather than one, because they have different remedies. A weak
/// module wants a bee. A module the scanner could not read wants its probe
/// fixed, and ranking it beside the others - with a position and a score -
/// states a comparison the scan never made.
struct HiveQueue: Equatable {
    /// Dispatchable, in order. Every row cleared the confidence gate.
    let ranked: [HiveRankedTarget]
    /// Below the confidence floor: not ranked, not dropped. Least-measured
    /// first, which orders the instrument, not the modules.
    let instrumentFaults: [HiveTarget]

    static let empty = HiveQueue(ranked: [], instrumentFaults: [])

    /// Every target from the scan, ranked ones first.
    var allTargets: [HiveTarget] { ranked.map(\.target) + instrumentFaults }

    var hasUnsettledPairs: Bool { ranked.contains { $0.separation != .settled } }

    /// The line the screen prints over the list. It has to name the assumption
    /// the order makes, because the order cannot be read off the numbers
    /// beside it: three different keys are on display and only one of them
    /// sorts.
    static let orderingSentence =
        "Ranked on the weakness actually measured, plus a written-down typical value for "
        + "every probe that failed - never zero, never the module's own average; "
        + "'not settled' means the unread signals could still flip this pair."
}

/// One row of the ranked queue: a target, its position, and what the evidence
/// does or does not settle about it against the row above.
struct HiveRankedTarget: Identifiable, Equatable {
    let target: HiveTarget
    /// 1-based position in the queue.
    let position: Int
    /// This row against the one immediately above it.
    let separation: HiveSeparation

    var id: String { target.module }
}

/// Whether the evidence actually separates a row from the one above it.
///
/// Reported, never used as a comparator: overlap is intransitive, so it is not
/// a strict weak ordering, and a dispatcher must still produce a next item.
enum HiveSeparation: Equatable {
    /// The first row, or two intervals that do not touch.
    case settled
    /// The intervals overlap: the unread signals could still flip this pair.
    /// `breakEven` is the reading that would do it, when one exists.
    case notSettled(breakEven: HiveBreakEven?)

    var isSettled: Bool {
        if case .settled = self { return true }
        return false
    }
}

/// The imputation at which a row would draw level with the row above it.
struct HiveBreakEven: Equatable {
    /// The normalised reading, uniform across every unread signal of the lower
    /// row.
    let normalized: Double
    /// The same reading in each unread signal's own units.
    let readings: [Reading]

    struct Reading: Equatable {
        let kind: HiveSignal.Kind
        /// `normalized` mapped back through `kind.scale`. For a signal that is
        /// already absolute, the two are the same number.
        let inOwnUnits: Double
    }

    /// "Churn (30d) 11.4 of 20, Open issues 5.7 of 10".
    var summary: String {
        readings.map { reading in
            if let scale = reading.kind.scale {
                return "\(reading.kind.label) \(String(format: "%.1f", reading.inOwnUnits)) "
                    + "of \(String(format: "%g", scale))"
            }
            return "\(reading.kind.label) \(String(format: "%.2f", reading.inOwnUnits))"
        }
        .joined(separator: ", ")
    }
}

/// Ranks the parts of the Queen's own system by how much they need work.
///
/// Pure: facts in, ranked targets out. No disk, no clock, no network - so the
/// ranking is reproducible and testable. `HiveRepoScanner` supplies the facts.
///
/// Three rules the arithmetic enforces:
///   1. An unmeasured signal is excluded from the score, not counted as zero.
///      Its weight is removed from the denominator and shows up as lost
///      confidence instead.
///   2. Normalization is against a fixed declared scale per signal
///      (`HiveSignal.Kind.scale`), not against the scanned set. A score is
///      therefore a property of the module and survives both the removal of
///      another module and the passage of a scan cycle.
///   3. The ORDER is taken from `HiveTarget.priorImputedScore`, which imputes a
///      declared per-signal prior - never zero, and never the module's own
///      average - for each probe that failed. Rule 1 governs the reported
///      numbers; rule 3 governs the sort, and for six cycles they contradicted
///      each other because no test was written against the second one.
enum HivePriorityEngine {

    /// Every scanned target: the ranked queue first, in dispatch order, then
    /// the instrument faults.
    ///
    /// This is the flat view, kept for counting and for callers that want the
    /// whole scan. The queue the Queen dispatches from is `queue(_:)`, which
    /// keeps the two lists apart - a target below the confidence floor is not
    /// ranked at all, and printing a rank number beside it was the
    /// presentation half of the bug this wave fixed.
    static func rank(_ facts: [HiveModuleFacts]) -> [HiveTarget] {
        queue(facts).allTargets
    }

    /// Scan facts in, the operator's queue out.
    static func queue(_ facts: [HiveModuleFacts]) -> HiveQueue {
        queue(of: measure(facts))
    }

    /// The per-module measurement pass: facts in, targets out, in input order
    /// and with no ordering applied. Split from the ordering so a test can hold
    /// one of them still while it moves the other.
    static func measure(_ facts: [HiveModuleFacts]) -> [HiveTarget] {
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
                    confidence: confidence,
                    weightedTotal: weighted
                )
            )
        }

        return targets
    }

    /// The ranked queue, as its own function so a test can assert on the ORDER
    /// rather than only on the numbers behind it.
    static func ordered(_ targets: [HiveTarget]) -> [HiveTarget] {
        queue(of: targets).ranked.map(\.target)
    }

    /// Splits the scan into the part the evidence can rank and the part where
    /// the fault is in the instrument, then orders the first.
    ///
    /// L0, THE GATE. A target below `HiveInvariants.minimumDispatchConfidence`
    /// leaves the ranked queue entirely. `HiveTaskFactory.rejection` already
    /// refused it a bee; what it did not do was stop the queue printing a
    /// position and a number beside it, which reads as a ranking of modules
    /// when it is a ranking of how well the scanner happened to work. Its
    /// remedy is to repair the probe, so it is listed where that can be read.
    ///
    /// L1, THE KEY. `priorImputedScore` - see the derivation there. Confidence
    /// breaks ties, so between two targets of equal expected weakness the
    /// better-measured one goes first; the module name makes the rest
    /// deterministic.
    ///
    /// L2, THE REPORT. Every adjacent pair whose intervals overlap is marked
    /// `notSettled`. Interval dominance is the honest statement of what the
    /// evidence settles, but it cannot BE the order: on real scans the overlap
    /// relation is intransitive (A ~ B and B ~ C while A is settled against C),
    /// so it is not a strict weak ordering and `sorted(by:)` may not be given
    /// it. A dispatcher must still produce a next item. So the queue is ordered
    /// on the key and says out loud which neighbours the evidence did not
    /// separate, rather than picking one silently and presenting it as a rank.
    static func queue(of targets: [HiveTarget]) -> HiveQueue {
        let survivors = targets
            .filter { !$0.isInstrumentFault }
            .sorted(by: precedes)

        // Least-measured first. This is an ordering on the INSTRUMENT - which
        // probe to go and fix - not on the modules' need for work, and it must
        // not be read as one.
        let faults = targets
            .filter(\.isInstrumentFault)
            .sorted {
                if $0.confidence != $1.confidence { return $0.confidence < $1.confidence }
                return $0.module < $1.module
            }

        var rows: [HiveRankedTarget] = []
        rows.reserveCapacity(survivors.count)
        for (index, target) in survivors.enumerated() {
            guard index > 0 else {
                // Nothing above it, so there is no pair to leave unsettled.
                rows.append(HiveRankedTarget(target: target, position: 1, separation: .settled))
                continue
            }
            let above = survivors[index - 1]
            let separation: HiveSeparation = intervalsOverlap(above, target)
                ? .notSettled(breakEven: breakEven(below: target, above: above))
                : .settled
            rows.append(
                HiveRankedTarget(target: target, position: index + 1, separation: separation)
            )
        }
        return HiveQueue(ranked: rows, instrumentFaults: faults)
    }

    /// The comparator, named so it can be tested directly.
    ///
    /// The tie-breaks reach at all only because the key is one sum and one
    /// division. Computed as score*confidence, two mathematically equal keys
    /// differed in the last bit (0.88*0.55 is 0.48400000000000004, while
    /// 0.484*1.0 is 0.484), the comparison never reached the confidence rule,
    /// and the target with a FAILED probe was placed above the fully measured
    /// one.
    static func precedes(_ lhs: HiveTarget, _ rhs: HiveTarget) -> Bool {
        if lhs.priorImputedScore != rhs.priorImputedScore {
            return lhs.priorImputedScore > rhs.priorImputedScore
        }
        if lhs.confidence != rhs.confidence { return lhs.confidence > rhs.confidence }
        return lhs.module < rhs.module
    }

    /// Whether what the evidence leaves open for these two still overlaps.
    static func intervalsOverlap(_ lhs: HiveTarget, _ rhs: HiveTarget) -> Bool {
        lhs.lowerBound <= rhs.upperBound && rhs.lowerBound <= lhs.upperBound
    }

    /// The reading every unread signal of `below` would have to take for it to
    /// draw level with `above`.
    ///
    ///     p* = (key_above - lower_below) / unmeasuredShare_below
    ///
    /// `nil` when `below` has nothing left unread (no reading of ITS could
    /// change the pair - the doubt belongs to the row above), or when no
    /// reading in 0...1 would do it.
    static func breakEven(below: HiveTarget, above: HiveTarget) -> HiveBreakEven? {
        let unreadShare = below.unmeasuredShare
        guard unreadShare > 0 else { return nil }
        let point = (above.priorImputedScore - below.lowerBound) / unreadShare
        guard point > 0, point <= 1 else { return nil }
        return HiveBreakEven(
            normalized: point,
            readings: below.unreadProbes.map { probe in
                HiveBreakEven.Reading(
                    kind: probe.kind,
                    // Back into the signal's own units, so the operator is told
                    // "about 11 commits", not "0.57 of something".
                    inOwnUnits: point * (probe.kind.scale ?? 1)
                )
            }
        )
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
