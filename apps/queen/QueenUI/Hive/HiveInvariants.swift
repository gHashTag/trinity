import Foundation

// ===========================================================================
// STANDING INVARIANTS - the guardrails, machine-checked, every cycle.
//
// A self-improving runtime's safety claims are usually self-graded: a policy
// struct, a comment, a promise in a README. `HivePolicy` is exactly such a
// file. These invariants are the falsifiable version: pre-declared, checked
// before every dispatch, and able to halt the loop rather than merely describe
// what it ought to do.
//
// They are deliberately about the loop's *own* configuration and bookkeeping,
// not about the code it edits. An invariant that needs a model to evaluate it
// is not an invariant.
// ===========================================================================

struct HiveInvariantViolation: Equatable, Identifiable {
    let id: String
    let detail: String
}

enum HiveInvariants {

    /// Below this, the ranking has read too little of a module to justify
    /// spending a bee on it.
    ///
    /// Harness optimisers have been shown to invent failures that never
    /// happened when the input merely *resembles* a rule they know. A target
    /// whose dominant driver is a weakly-measured signal is the same shape of
    /// mistake: work proposed against evidence that was never gathered.
    static let minimumDispatchConfidence = 0.5

    /// Evaluates every standing invariant. An empty result is the only state
    /// in which the loop may dispatch.
    static func check(policy: HivePolicy, tasks: [HiveTask], spentToday: Double) -> [HiveInvariantViolation] {
        var violations: [HiveInvariantViolation] = []

        func require(_ condition: Bool, _ id: String, _ detail: @autoclosure () -> String) {
            if !condition { violations.append(HiveInvariantViolation(id: id, detail: detail())) }
        }

        // The policy must be self-consistent. A per-bee budget above the daily
        // ceiling lets one bee spend the day before the ceiling is consulted.
        require(
            policy.maxBudgetUSDPerBee <= policy.dailyBudgetUSD,
            "budget-ordering",
            "per-bee budget $\(policy.maxBudgetUSDPerBee) exceeds the daily ceiling $\(policy.dailyBudgetUSD)"
        )
        require(
            spentToday <= policy.dailyBudgetUSD,
            "daily-ceiling",
            "spent $\(String(format: "%.2f", spentToday)) against a ceiling of $\(policy.dailyBudgetUSD)"
        )
        require(policy.maxConcurrentBees >= 1, "concurrency", "concurrency is \(policy.maxConcurrentBees)")
        require(
            policy.maxAttemptsPerTask >= 1,
            "attempt-budget",
            "attempt budget is \(policy.maxAttemptsPerTask)"
        )

        // Bookkeeping the loop itself maintains. A breach here means the state
        // machine has drifted, and drifted state is how a loop starts doing
        // work nobody asked for.
        //
        // Scoped to tasks that can still be dispatched. An unscoped version
        // deadlocks the whole loop the moment the operator lowers the attempt
        // budget below the attempts of a task that is already toxic: nothing
        // will ever change a toxic task's counter, so the only exit is to raise
        // the stepper back or edit hive.json by hand, and the UI says neither.
        let overspentAttempts = tasks.filter { $0.isSchedulable && $0.attempts > policy.maxAttemptsPerTask }
        require(
            overspentAttempts.isEmpty,
            "attempts-exceeded",
            "\(overspentAttempts.count) schedulable task(s) past the attempt budget: "
                + overspentAttempts.prefix(3).map(\.id).joined(separator: ", ")
        )

        let unverifiedInReview = tasks.filter { $0.state == .review && $0.verification == nil }
        require(
            !policy.verifyBeforeReview || unverifiedInReview.isEmpty,
            "review-without-verdict",
            "\(unverifiedInReview.count) task(s) reached review with no recorded verdict while "
                + "verification is switched on: " + unverifiedInReview.prefix(3).map(\.id).joined(separator: ", ")
        )

        // A verdict grades one attempt. If it survived into a later dispatch it
        // is describing code that no longer exists, and the review list shows a
        // green tick over work nothing ever checked.
        let staleVerdicts = tasks.filter { task in
            guard task.state == .review, task.verified == true else { return false }
            guard let dispatched = task.lastDispatchAt else { return false }
            guard let verified = task.verifiedAt else { return true }
            return verified < dispatched
        }
        require(
            staleVerdicts.isEmpty,
            "verdict-outlived-its-attempt",
            "\(staleVerdicts.count) task(s) show a passing verdict recorded before their own last "
                + "dispatch: " + staleVerdicts.prefix(3).map(\.id).joined(separator: ", ")
        )

        let duplicateIDs = Dictionary(grouping: tasks, by: \.id).filter { $0.value.count > 1 }
        require(
            duplicateIDs.isEmpty,
            "duplicate-tasks",
            "duplicate task ids: " + duplicateIDs.keys.sorted().prefix(3).joined(separator: ", ")
        )

        // Two bees on one task would race on the same files.
        let running = tasks.filter { $0.state == .running }
        require(
            running.count <= policy.maxConcurrentBees,
            "running-over-limit",
            "\(running.count) task(s) marked running against a limit of \(policy.maxConcurrentBees)"
        )

        return violations
    }

    /// A prompt handed to a retry must not carry the previous attempt.
    ///
    /// Returning a failed attempt to the model for correction reproduces a
    /// near-identical program in a third to two thirds of retries; a fresh
    /// attempt at the same task, with no memory of the last one, does better
    /// and costs less. The Hive gets this right by construction - each attempt
    /// is a new session with the original prompt - and this check exists so a
    /// later "improvement" that pastes `lastError` into the prompt fails a
    /// test instead of quietly degrading every retry.
    static func promptIsAnchorFree(_ prompt: String, previousError: String?) -> Bool {
        guard let previousError, !previousError.isEmpty else { return true }
        let needle = String(previousError.prefix(60))
        return !prompt.contains(needle)
    }
}
