import Testing
import Foundation
@testable import QueenUILib

// The dispatch rule and the standing invariants are the two places where the
// loop decides to spend money on its own initiative. Both are pure, so both
// can be asserted about directly rather than about the policy struct they read.

private func makeTask(
    _ id: String,
    score: Double = 0.5,
    state: HiveTaskState = .pending,
    attempts: Int = 0,
    module: String? = nil,
    createdAt: Date? = nil
) -> HiveTask {
    var task = HiveTask(
        id: id,
        title: id,
        module: module ?? id,
        path: id,
        realm: "Core",
        signalKind: "testGap",
        reason: "r",
        score: score,
        confidence: 1,
        prompt: "p"
    )
    task.state = state
    task.attempts = attempts
    if let createdAt { task.createdAt = createdAt }
    return task
}

private func armedPolicy() -> HivePolicy {
    var policy = HivePolicy.default
    policy.enabled = true
    return policy
}

private func context(
    policy: HivePolicy,
    tasks: [HiveTask] = [],
    liveBees: Int = 0,
    spentToday: Double = 0,
    spawnsInLastHour: Int = 0,
    consecutiveFailures: Int = 0,
    consecutiveUnverifiable: Int = 0,
    auth: HiveAuthState? = .loggedIn(method: "oauth")
) -> HiveDispatchContext {
    HiveDispatchContext(
        policy: policy,
        tasks: tasks,
        liveBees: liveBees,
        spentToday: spentToday,
        spawnsInLastHour: spawnsInLastHour,
        consecutiveFailures: consecutiveFailures,
        consecutiveUnverifiable: consecutiveUnverifiable,
        auth: auth
    )
}

@Suite("Hive - standing invariants")
struct HiveInvariantTests {

    @Test func aSaneConfigurationViolatesNothing() {
        let violations = HiveInvariants.check(
            policy: .default,
            tasks: [makeTask("a"), makeTask("b")],
            spentToday: 1.0
        )
        #expect(violations.isEmpty)
    }

    @Test func aPerBeeBudgetAboveTheDailyCeilingIsAViolation() {
        var policy = HivePolicy.default
        policy.maxBudgetUSDPerBee = 40
        policy.dailyBudgetUSD = 25
        let ids = HiveInvariants.check(policy: policy, tasks: [], spentToday: 0).map(\.id)
        #expect(ids.contains("budget-ordering"))
    }

    @Test func spendingPastTheCeilingIsAViolation() {
        let ids = HiveInvariants.check(policy: .default, tasks: [], spentToday: 99).map(\.id)
        #expect(ids.contains("daily-ceiling"))
    }

    @Test func aSchedulableTaskPastItsAttemptBudgetIsAViolation() {
        var policy = HivePolicy.default
        policy.maxAttemptsPerTask = 2
        let over = makeTask("over", state: .failed, attempts: 5)
        let ids = HiveInvariants.check(policy: policy, tasks: [over], spentToday: 0).map(\.id)
        #expect(ids.contains("attempts-exceeded"))
    }

    @Test func loweringTheAttemptBudgetDoesNotDeadlockOnTasksThatAreAlreadyDead() {
        // Three toxic tasks with three attempts each, and the operator drags the
        // stepper down to two. Nothing will ever change a toxic task's counter,
        // so an invariant that counted them would block every future dispatch
        // for ever, naming tasks that have been dead for days, with no in-app
        // remedy at all.
        var policy = HivePolicy.default
        policy.maxAttemptsPerTask = 2
        let dead = (0..<3).map { makeTask("dead\($0)", state: .toxic, attempts: 3) }

        let violations = HiveInvariants.check(policy: policy, tasks: dead, spentToday: 0)
        #expect(violations.isEmpty)
        #expect(HiveDispatch.decide(context(policy: armedPolicy(), tasks: dead)).isBlocked == false)
    }

    @Test func reachingReviewWithNoVerdictIsAViolationWhileCheckingIsOn() {
        var task = makeTask("t", state: .review)
        task.verification = nil
        let ids = HiveInvariants.check(policy: .default, tasks: [task], spentToday: 0).map(\.id)
        #expect(ids.contains("review-without-verdict"))
    }

    @Test func aVerdictThatOutlivedItsOwnAttemptIsAViolation() {
        // Attempt 1 passed and was recorded. The operator sent the task back,
        // switched checking off, and attempt 2 finished. Without this the review
        // list shows VERIFIED with a real test tally over code that no longer
        // exists.
        var task = makeTask("t", state: .review)
        task.verification = "VERIFIED: Test run with 242 tests passed"
        task.verified = true
        task.verifiedAt = Date(timeIntervalSince1970: 1_000)
        task.verifiedAtCommit = "abc123"
        task.lastDispatchAt = Date(timeIntervalSince1970: 2_000)

        let ids = HiveInvariants.check(policy: .default, tasks: [task], spentToday: 0).map(\.id)
        #expect(ids.contains("verdict-outlived-its-attempt"))
    }

    @Test func aVerdictRecordedAfterItsOwnDispatchIsFine() {
        var task = makeTask("t", state: .review)
        task.verification = "VERIFIED: passed"
        task.verified = true
        task.lastDispatchAt = Date(timeIntervalSince1970: 1_000)
        task.verifiedAt = Date(timeIntervalSince1970: 2_000)

        let ids = HiveInvariants.check(policy: .default, tasks: [task], spentToday: 0).map(\.id)
        #expect(!ids.contains("verdict-outlived-its-attempt"))
    }

    @Test func aPassingVerdictWithNoTimestampAtAllIsTreatedAsStale() {
        var task = makeTask("t", state: .review)
        task.verification = "VERIFIED: passed"
        task.verified = true
        task.lastDispatchAt = Date()
        // verifiedAt deliberately absent: a verdict that cannot be placed in
        // time is not thereby current.
        let ids = HiveInvariants.check(policy: .default, tasks: [task], spentToday: 0).map(\.id)
        #expect(ids.contains("verdict-outlived-its-attempt"))
    }

    @Test func duplicateTaskIDsAreAViolation() {
        let ids = HiveInvariants.check(
            policy: .default,
            tasks: [makeTask("same"), makeTask("same")],
            spentToday: 0
        ).map(\.id)
        #expect(ids.contains("duplicate-tasks"))
    }

    @Test func moreRunningTasksThanSlotsIsAViolation() {
        var policy = HivePolicy.default
        policy.maxConcurrentBees = 1
        let running = [makeTask("a", state: .running), makeTask("b", state: .running)]
        let ids = HiveInvariants.check(policy: policy, tasks: running, spentToday: 0).map(\.id)
        #expect(ids.contains("running-over-limit"))
    }

    // MARK: - Anchor-free retries

    @Test func aPromptCarryingThePreviousFailureIsNotAnchorFree() {
        let error = "swift build failed: cannot find 'HiveOrchestrator' in scope"
        #expect(!HiveInvariants.promptIsAnchorFree("Fix this: \(error)", previousError: error))
    }

    @Test func aFreshPromptIsAnchorFree() {
        #expect(HiveInvariants.promptIsAnchorFree("add the tests this module lacks", previousError: "swift build failed"))
        #expect(HiveInvariants.promptIsAnchorFree("anything", previousError: nil))
        #expect(HiveInvariants.promptIsAnchorFree("anything", previousError: ""))
    }

    @Test func theTaskFactoryNeverAnchorsARetryOnTheLastFailure() {
        var facts = HiveModuleFacts(module: "src/tri", path: "src/tri", realm: .core)
        facts.lines = 1000
        facts.todos = 30
        facts.testBlocks = 0
        facts.churn30d = 4
        facts.declaredStatus = "active"
        facts.openIssues = 1

        let target = try! #require(HivePriorityEngine.rank([facts]).first)
        let task = try! #require(HiveTaskFactory.makeTask(from: target, policy: .default))
        #expect(HiveInvariants.promptIsAnchorFree(task.prompt, previousError: "`swift build` failed:\nerror: x"))
    }
}

@Suite("Hive - dispatch decision")
struct HiveDispatchDecisionTests {

    @Test func aDisarmedLoopIsIdleNotBlocked() {
        let decision = HiveDispatch.decide(context(policy: .default, tasks: [makeTask("a")]))
        #expect(!decision.isDispatch)
        #expect(!decision.isBlocked)
        #expect(decision.reason.contains("not armed"))
    }

    @Test func anUnprobedCLIBlocksRatherThanBeingAssumedSignedIn() {
        let decision = HiveDispatch.decide(context(policy: armedPolicy(), tasks: [makeTask("a")], auth: nil))
        #expect(decision.isBlocked)
        #expect(decision.reason.contains("has not been probed"))
    }

    @Test func aSignedOutCLIBlocksWithItsOwnFix() {
        let decision = HiveDispatch.decide(
            context(policy: armedPolicy(), tasks: [makeTask("a")], auth: .loggedOut)
        )
        #expect(decision.isBlocked)
        #expect(decision.reason.contains("claude auth login"))
    }

    @Test func aViolatedInvariantBlocksBeforeAnythingElseIsConsidered() {
        var policy = armedPolicy()
        policy.maxBudgetUSDPerBee = 40
        policy.dailyBudgetUSD = 25
        // Signed out too: the invariant must be the reason that surfaces.
        let decision = HiveDispatch.decide(
            context(policy: policy, tasks: [makeTask("a")], auth: .loggedOut)
        )
        #expect(decision.isBlocked)
        #expect(decision.reason.contains("budget-ordering"))
    }

    @Test func theFailureBreakerBlocks() {
        var policy = armedPolicy()
        policy.maxConsecutiveFailures = 3
        let decision = HiveDispatch.decide(
            context(policy: policy, tasks: [makeTask("a")], consecutiveFailures: 3)
        )
        #expect(decision.isBlocked)
        #expect(decision.reason.contains("failed in a row"))
    }

    @Test func aLoopThatCannotCheckItsOwnWorkStopsRatherThanRunningFaster() {
        // Every bee comes back unverifiable - no toolchain, no checker for the
        // realm, no resolvable worktree. The failure breaker never sees any of
        // it, which is exactly the configuration where a breaker matters most.
        let decision = HiveDispatch.decide(
            context(
                policy: armedPolicy(),
                tasks: [makeTask("a")],
                consecutiveUnverifiable: HiveDispatch.maxConsecutiveUnverifiable
            )
        )
        #expect(decision.isBlocked)
        #expect(decision.reason.contains("no runnable check"))
    }

    @Test func theDailyCeilingBlocks() {
        var policy = armedPolicy()
        policy.dailyBudgetUSD = 25
        let decision = HiveDispatch.decide(
            context(policy: policy, tasks: [makeTask("a")], spentToday: 25)
        )
        #expect(decision.isBlocked)
        #expect(decision.reason.contains("daily ceiling"))
    }

    @Test func busySlotsAreIdleNotBlocked() {
        var policy = armedPolicy()
        policy.maxConcurrentBees = 2
        let decision = HiveDispatch.decide(
            context(policy: policy, tasks: [makeTask("a")], liveBees: 2)
        )
        #expect(!decision.isDispatch)
        #expect(!decision.isBlocked)
        #expect(decision.reason.contains("bee slots are busy"))
    }

    @Test func theHourlyRateLimitIsIdleNotBlocked() {
        var policy = armedPolicy()
        policy.maxBeesPerHour = 6
        let decision = HiveDispatch.decide(
            context(policy: policy, tasks: [makeTask("a")], spawnsInLastHour: 6)
        )
        #expect(!decision.isDispatch)
        #expect(decision.reason.contains("already started this hour"))
    }

    @Test func anEmptyQueueIsIdle() {
        let decision = HiveDispatch.decide(context(policy: armedPolicy()))
        #expect(decision.reason.contains("nothing schedulable"))
    }

    @Test func theHighestScoringSchedulableTaskGoesOut() {
        let decision = HiveDispatch.decide(
            context(policy: armedPolicy(), tasks: [
                makeTask("low", score: 0.2),
                makeTask("high", score: 0.9),
                makeTask("running", score: 1.0, state: .running),
            ])
        )
        #expect(decision.reason == "high")
    }

    @Test func aTieIsBrokenByAgeSoNoTaskStarves() {
        let old = makeTask("old", score: 0.5, createdAt: Date(timeIntervalSince1970: 1_000))
        let new = makeTask("new", score: 0.5, createdAt: Date(timeIntervalSince1970: 2_000))
        let decision = HiveDispatch.decide(context(policy: armedPolicy(), tasks: [new, old]))
        #expect(decision.reason == "old")
    }

    @Test func aSkippedModuleIsNeverDispatched() {
        var policy = armedPolicy()
        policy.skippedModules["src/skipme"] = "not worth a bee"
        let decision = HiveDispatch.decide(
            context(policy: policy, tasks: [makeTask("t", score: 1.0, module: "src/skipme")])
        )
        #expect(!decision.isDispatch)
    }

    @Test func aTaskOutOfAttemptsIsNeverDispatched() {
        var policy = armedPolicy()
        policy.maxAttemptsPerTask = 3
        let decision = HiveDispatch.decide(
            context(policy: policy, tasks: [makeTask("t", state: .failed, attempts: 3)])
        )
        #expect(!decision.isDispatch)
    }
}

@Suite("Hive - outcome state machine")
struct HiveOutcomeStateTests {

    @Test func aFailedBeeCostsAnAttemptAndMovesTheBreaker() {
        let result = HiveDispatch.outcomeState(
            for: makeTask("t", attempts: 1), verdict: nil, beeSucceeded: false, policy: .default
        )
        #expect(result.state == .failed)
        #expect(result.streak == .increment)
    }

    @Test func aFailedBeeOnTheLastAttemptGoesToxic() {
        var policy = HivePolicy.default
        policy.maxAttemptsPerTask = 3
        let result = HiveDispatch.outcomeState(
            for: makeTask("t", attempts: 3), verdict: nil, beeSucceeded: false, policy: policy
        )
        #expect(result.state == .toxic)
        #expect(result.streak == .increment)
    }

    @Test func aPassingCheckClearsTheStreak() {
        let result = HiveDispatch.outcomeState(
            for: makeTask("t"), verdict: .passed("242 tests"), beeSucceeded: true, policy: .default
        )
        #expect(result.state == .review)
        #expect(result.streak == .clear)
    }

    @Test func theChecksWinOverTheBeesOwnClaim() {
        let result = HiveDispatch.outcomeState(
            for: makeTask("t", attempts: 1),
            verdict: .failed("`swift build` failed"),
            beeSucceeded: true,
            policy: .default
        )
        #expect(result.state == .failed)
        #expect(result.streak == .increment)
    }

    @Test func anUncheckableResultNeitherEarnsAFailureNorClearsOne() {
        // The whole point of the three-valued effect: returning "not a failure"
        // here reset the breaker on every unverifiable bee, so on a machine
        // where nothing can be checked the breaker never tripped at all.
        let result = HiveDispatch.outcomeState(
            for: makeTask("t"),
            verdict: .unavailable("swift toolchain not found"),
            beeSucceeded: true,
            policy: .default
        )
        #expect(result.state == .review)
        #expect(result.streak == .hold)
    }

    @Test func aMissingVerdictHoldsTheStreakToo() {
        let result = HiveDispatch.outcomeState(
            for: makeTask("t"), verdict: nil, beeSucceeded: true, policy: .default
        )
        #expect(result.state == .review)
        #expect(result.streak == .hold)
    }

    @Test func checkingSwitchedOffIsARealVerdictAgainstThePolicyInForce() {
        var policy = HivePolicy.default
        policy.verifyBeforeReview = false
        let result = HiveDispatch.outcomeState(
            for: makeTask("t"), verdict: nil, beeSucceeded: true, policy: policy
        )
        #expect(result.state == .review)
        #expect(result.streak == .clear)
    }

    @Test func onlyAnUngradableSuccessCountsTowardTheSecondBreaker() {
        var off = HivePolicy.default
        off.verifyBeforeReview = false

        #expect(HiveDispatch.isUnverifiable(verdict: nil, beeSucceeded: true, policy: .default))
        #expect(HiveDispatch.isUnverifiable(verdict: .unavailable("x"), beeSucceeded: true, policy: .default))
        #expect(!HiveDispatch.isUnverifiable(verdict: .passed("x"), beeSucceeded: true, policy: .default))
        #expect(!HiveDispatch.isUnverifiable(verdict: nil, beeSucceeded: false, policy: .default))
        #expect(!HiveDispatch.isUnverifiable(verdict: nil, beeSucceeded: true, policy: off))
    }
}
