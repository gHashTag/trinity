import Foundation

// ===========================================================================
// DISPATCH DECISION - "should a bee go out right now, and for what?"
//
// Pure. No clock of its own, no disk, no processes, no actor. The orchestrator
// that owns the timer and the child processes asks this type what to do and
// then does it, which is the only reason the decision can be tested at all.
//
// Before this existed the same logic lived inline in a MainActor
// ObservableObject and had no tests. Every guardrail was therefore asserted
// about a policy struct rather than about the code that reads it.
// ===========================================================================

enum HiveDispatchDecision: Equatable {
    /// Send a bee for this task.
    case dispatch(HiveTask)
    /// Nothing is wrong; there is simply nothing to do.
    case idle(String)
    /// The loop must not dispatch, and this is why.
    case blocked(String)

    var isDispatch: Bool {
        if case .dispatch = self { return true }
        return false
    }

    var isBlocked: Bool {
        if case .blocked = self { return true }
        return false
    }

    var reason: String {
        switch self {
        case .dispatch(let task): return task.id
        case .idle(let why), .blocked(let why): return why
        }
    }
}

struct HiveDispatchContext: Equatable {
    var policy: HivePolicy
    var tasks: [HiveTask]
    /// Bees alive right now, counted by the orchestrator from live processes
    /// rather than from task state, so a crashed bee cannot hold a slot.
    var liveBees: Int
    var spentToday: Double
    var spawnsInLastHour: Int
    var consecutiveFailures: Int
    /// Consecutive bees whose work could not be checked at all. Its own
    /// breaker: a loop that cannot grade itself should slow down, not speed up.
    var consecutiveUnverifiable: Int
    /// Whether the CLI preflight passed. Three states, so "not yet probed" is
    /// not silently treated as "signed in".
    var auth: HiveAuthState?

    init(
        policy: HivePolicy,
        tasks: [HiveTask],
        liveBees: Int,
        spentToday: Double,
        spawnsInLastHour: Int,
        consecutiveFailures: Int,
        consecutiveUnverifiable: Int = 0,
        auth: HiveAuthState?
    ) {
        self.policy = policy
        self.tasks = tasks
        self.liveBees = liveBees
        self.spentToday = spentToday
        self.spawnsInLastHour = spawnsInLastHour
        self.consecutiveFailures = consecutiveFailures
        self.consecutiveUnverifiable = consecutiveUnverifiable
        self.auth = auth
    }
}

// MARK: - The clock

/// What the operator is told about the loop's clock.
///
/// `policy.enabled` is a persisted wish, not a running clock. It is written to
/// hive.json and read back on launch, while the timer that actually drives the
/// cycle is created only when an operator arms the loop. So after a rebuild, a
/// crash, or a watchdog relaunch, the state file says enabled and nothing is
/// scheduled - and a badge derived from the policy reads 24/7 ARMED over a
/// queue that will never be dispatched again without a human.
///
/// Three states, so "armed but not ticking" has a name, an event and a remedy
/// instead of looking exactly like health.
enum HiveLoopStatus: String, Equatable {
    /// Not armed. Nothing is scheduled and nothing should be.
    case idle
    /// Armed, and a cycle is scheduled.
    case ticking
    /// Armed in the state file, with no cycle scheduled.
    case resumeRequired

    static func of(enabled: Bool, ticking: Bool) -> HiveLoopStatus {
        guard enabled else { return .idle }
        return ticking ? .ticking : .resumeRequired
    }

    var label: String {
        switch self {
        case .idle: return "IDLE"
        case .ticking: return "24/7 ARMED"
        case .resumeRequired: return "ARMED, NOT TICKING"
        }
    }

    /// True only when a cycle is really scheduled. Every badge, countdown and
    /// Run button reads this rather than the policy flag.
    var isTicking: Bool { self == .ticking }

    /// Whether the operator has to do something to restore the loop.
    var needsOperator: Bool { self == .resumeRequired }

    var advice: String? {
        guard self == .resumeRequired else { return nil }
        return "the loop is armed in the state file but no cycle is scheduled - "
            + "it will not dispatch until someone presses Run 24/7"
    }
}

/// The cycle mutex, with a deadline.
///
/// A bare `cycleInFlight` boolean is a lock nothing can ever release once the
/// cycle holding it wedges - a git subprocess that ignores SIGTERM leaves the
/// loop showing 24/7 ARMED with a stale status line, `Cycle now` doing
/// literally nothing, and Pause-then-Run re-arming a timer that returns at the
/// same guard. The only exit was killing the app.
///
/// The generation token exists because forcing the latch open creates two
/// claimants: the wedged cycle, if it ever returns, must not release a latch a
/// newer cycle now holds.
struct HiveCycleLatch: Equatable {
    private(set) var startedAt: Date?
    private(set) var generation = 0

    var isInFlight: Bool { startedAt != nil }

    enum Admission: Equatable {
        case admitted(token: Int)
        case busy(heldFor: TimeInterval)
        case forced(token: Int, heldFor: TimeInterval)

        var token: Int? {
            switch self {
            case .admitted(let token): return token
            case .forced(let token, _): return token
            case .busy: return nil
            }
        }
    }

    /// How long a cycle may hold the latch before a later cycle forces it open.
    ///
    /// Derived rather than guessed. A cycle's own work is a repository scan
    /// whose git calls each cap at 30s, so its honest bound scales with the
    /// number of modules and cannot be written as one constant. What can be
    /// written down is that a cycle still holding the latch after an hour, and
    /// after two of its own intervals, has stopped being slow and started
    /// being wedged.
    static func wedgeDeadline(cycleIntervalSeconds: Int) -> TimeInterval {
        max(3600, TimeInterval(cycleIntervalSeconds) * 2)
    }

    mutating func enter(now: Date = Date(), deadline: TimeInterval) -> Admission {
        if let startedAt {
            let held = now.timeIntervalSince(startedAt)
            guard held >= deadline else { return .busy(heldFor: held) }
            generation += 1
            self.startedAt = now
            return .forced(token: generation, heldFor: held)
        }
        generation += 1
        startedAt = now
        return .admitted(token: generation)
    }

    /// Only the cycle that currently holds the latch may clear it.
    mutating func leave(token: Int) {
        guard token == generation else { return }
        startedAt = nil
    }
}

// MARK: - Reservation repair

/// What a bee's transcript says about a bee the Queen can no longer supervise.
struct HiveTranscriptSummary: Equatable {
    /// Non-empty stream lines the bee wrote.
    var lines: Int
    /// The last `total_cost_usd` the bee reported, if it reported one.
    var lastCostUSD: Double?

    /// No transcript file at all.
    static let absent = HiveTranscriptSummary(lines: 0, lastCostUSD: nil)
}

/// How to settle a reservation whose bee the Queen cannot ask.
enum HiveReservationRepair: Equatable {
    /// The transcript reported a cost. Charge exactly that and refund the rest.
    case charge(Double)
    /// The bee wrote nothing at all, so it cannot have spent anything.
    case refundInFull
    /// The bee produced real output and never reported a cost. Absent is not
    /// zero: the reservation stands.
    case keep
}

/// What a finished bee does to the failure streak.
///
/// Three values, not a Bool. A bee whose work could not be checked has neither
/// earned a failure nor cleared one, and collapsing that into "not a failure"
/// resets the breaker on every unverifiable result - so on the machines where
/// nothing can be checked, which is exactly where the breaker matters most, it
/// never trips at all.
enum HiveStreakEffect: Equatable {
    case increment
    case hold
    case clear
}

enum HiveDispatch {

    /// Consecutive unverifiable results before the loop pauses itself.
    static let maxConsecutiveUnverifiable = 3

    /// The single decision point. Order matters: the cheapest and most
    /// dangerous refusals are checked first, so a signed-out CLI or a tripped
    /// breaker can never be masked by an empty queue.
    static func decide(_ context: HiveDispatchContext) -> HiveDispatchDecision {
        guard context.policy.enabled else {
            return .idle("the loop is not armed")
        }
        if let refusal = guardrails(context) { return refusal }
        guard let next = nextTask(in: context) else {
            return .idle("nothing schedulable in the queue")
        }
        return .dispatch(next)
    }

    /// Everything that must hold before any bee goes out, whoever asked for it.
    /// Returns nil when the envelope is clear.
    ///
    /// Split out of `decide` so the operator's buttons cross the same
    /// guardrails as the cycle. `Send a bee` and a typed instruction used to
    /// reach `spawn` directly, which meant an operator could walk past the
    /// daily ceiling, the concurrency limit, the rate window and both breakers
    /// by clicking. An operator chooses WHICH task runs; the safety envelope is
    /// not theirs to choose. The armed flag is deliberately not part of this:
    /// sending one bee by hand while the loop is paused is the point of the
    /// button.
    static func guardrails(_ context: HiveDispatchContext) -> HiveDispatchDecision? {
        let policy = context.policy

        let violations = HiveInvariants.check(
            policy: policy,
            tasks: context.tasks,
            spentToday: context.spentToday
        )
        if let first = violations.first {
            return .blocked(
                "standing invariant `\(first.id)` is violated: \(first.detail)"
                    + (violations.count > 1 ? " (and \(violations.count - 1) more)" : "")
            )
        }

        guard let auth = context.auth else {
            return .blocked("the claude CLI has not been probed yet")
        }
        guard auth.canSpawn else {
            return .blocked(auth.blockerText ?? "the claude CLI cannot spawn")
        }

        guard context.consecutiveFailures < policy.maxConsecutiveFailures else {
            return .blocked(
                "circuit breaker: \(context.consecutiveFailures) bees failed in a row "
                    + "(limit \(policy.maxConsecutiveFailures)) - fix the cause, then re-arm"
            )
        }

        guard context.consecutiveUnverifiable < maxConsecutiveUnverifiable else {
            return .blocked(
                "circuit breaker: \(context.consecutiveUnverifiable) bees in a row finished with no "
                    + "runnable check - the loop cannot grade its own work, so it stops rather than "
                    + "filling the review list with unchecked claims"
            )
        }

        guard context.spentToday < policy.dailyBudgetUSD else {
            return .blocked(
                String(
                    format: "daily ceiling reached - $%.2f of $%.2f spent today",
                    context.spentToday, policy.dailyBudgetUSD
                )
            )
        }

        guard context.liveBees < policy.maxConcurrentBees else {
            return .idle("all \(policy.maxConcurrentBees) bee slots are busy")
        }

        guard context.spawnsInLastHour < policy.maxBeesPerHour else {
            return .idle(
                "\(context.spawnsInLastHour) bees already started this hour "
                    + "(limit \(policy.maxBeesPerHour))"
            )
        }

        return nil
    }

    /// The single admission gate every spawn passes, whoever asked for it.
    ///
    /// Returns the refusal, or nil when the bee may go out. The operator paths
    /// - `Send a bee` on a ranked target, and a typed instruction - used to
    /// reach `spawn` with only the attempt budget between them and a process,
    /// so pressing the button twice put two `claude -p` sessions in one
    /// worktree, made two SwiftUI rows share an identity, and left a
    /// reservation no completion would ever settle. An operator chooses WHICH
    /// task runs; they do not choose the safety envelope.
    static func admissionRefusal(
        taskID: String,
        liveTaskIDs: Set<String>,
        reservedTaskIDs: Set<String>
    ) -> String? {
        if liveTaskIDs.contains(taskID) {
            return "a bee is already working on \(taskID) - two sessions would edit the same files"
        }
        if reservedTaskIDs.contains(taskID) {
            return "\(taskID) still holds an unsettled budget reservation from an earlier bee"
        }
        return nil
    }

    /// How to settle a reservation from the evidence its bee left behind.
    ///
    /// Three absences, kept apart. A bee that wrote nothing never ran and is
    /// refunded whole; a bee whose transcript carries a cost line is charged
    /// exactly that; a bee that produced real output and no cost line keeps its
    /// reservation, because what it spent is unknown and unknown is not zero.
    static func repair(_ summary: HiveTranscriptSummary) -> HiveReservationRepair {
        if let cost = summary.lastCostUSD { return .charge(max(0, cost)) }
        return summary.lines == 0 ? .refundInFull : .keep
    }

    /// Highest score first among tasks that may still be attempted, skipping
    /// anything the operator has ruled out and anything already running.
    static func nextTask(in context: HiveDispatchContext) -> HiveTask? {
        context.tasks
            .filter(\.isSchedulable)
            .filter { context.policy.skippedModules[$0.module] == nil }
            .filter { $0.attempts < context.policy.maxAttemptsPerTask }
            .sorted {
                // Score first, then the oldest task, so a tie cannot starve one
                // module forever behind another with the same score.
                if $0.score != $1.score { return $0.score > $1.score }
                if $0.createdAt != $1.createdAt { return $0.createdAt < $1.createdAt }
                return $0.id < $1.id
            }
            .first
    }

    /// How a finished bee changes a task. Kept here, beside the dispatch rule,
    /// because the two together are the whole state machine.
    static func outcomeState(
        for task: HiveTask,
        verdict: HiveVerdict?,
        beeSucceeded: Bool,
        policy: HivePolicy
    ) -> (state: HiveTaskState, streak: HiveStreakEffect) {
        guard beeSucceeded else {
            let exhausted = task.attempts >= policy.maxAttemptsPerTask
            return (exhausted ? .toxic : .failed, .increment)
        }
        guard policy.verifyBeforeReview else {
            // Checking is switched off, so the operator has said in advance
            // that a clean exit is the whole standard. That is a real verdict
            // against the policy in force, and it clears the streak.
            return (.review, .clear)
        }
        switch verdict {
        case .some(.passed):
            return (.review, .clear)
        case .some(.failed):
            // The bee claimed success and the checks disagree. Checks win.
            let exhausted = task.attempts >= policy.maxAttemptsPerTask
            return (exhausted ? .toxic : .failed, .increment)
        case .some(.unavailable), .none:
            // Neither pass nor fail. It reaches review flagged unchecked, and
            // it neither earns a failure nor clears one.
            return (.review, .hold)
        }
    }

    /// Whether a finished bee counted as an unverifiable result, for the
    /// second breaker.
    static func isUnverifiable(verdict: HiveVerdict?, beeSucceeded: Bool, policy: HivePolicy) -> Bool {
        guard beeSucceeded, policy.verifyBeforeReview else { return false }
        switch verdict {
        case .some(.unavailable), .none: return true
        default: return false
        }
    }
}
