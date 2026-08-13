import Foundation
import SwiftUI

// ===========================================================================
// HIVE ORCHESTRATOR - the Queen running her own development, around the clock.
//
// One cycle:
//   scan -> rank -> materialise the top targets as tasks -> spawn bees up to the
//   guardrails -> harvest what finished -> persist -> sleep until the next cycle.
//
// Every guardrail is in `HivePolicy`, every decision lands in the audit log,
// and nothing leaves the machine: bees commit on their own branch and the
// Queen holds the result for review.
// ===========================================================================

@MainActor
final class HiveOrchestrator: ObservableObject {

    static let shared = HiveOrchestrator()

    // MARK: - Published state

    @Published private(set) var policy: HivePolicy
    @Published private(set) var tasks: [HiveTask] = []
    @Published private(set) var targets: [HiveTarget] = []
    @Published private(set) var bees: [Bee] = []
    @Published private(set) var events: [HiveEvent] = []
    @Published private(set) var isScanning = false
    @Published private(set) var lastCycleAt: Date?
    @Published private(set) var nextCycleAt: Date?
    @Published private(set) var lastScanAt: Date?
    @Published private(set) var statusLine: String = "idle"
    /// Set when the hive cannot run at all - missing binary, signed-out CLI.
    @Published private(set) var blocker: String?
    @Published private(set) var authState: HiveAuthState?

    // MARK: - Internals

    /// Consecutive bee failures. Trips the breaker at the policy limit so a
    /// systemic fault (signed-out CLI, broken worktree, wedged toolchain)
    /// cannot burn the whole task list one attempt at a time.
    @Published private(set) var consecutiveFailures = 0
    /// Bees in a row whose work could not be checked at all. Counted apart from
    /// failures because an absent checker is the Queen's gap, not the bee's
    /// fault - and because collapsing the two lets a machine with no toolchain
    /// run all day with the breaker permanently at zero.
    @Published private(set) var consecutiveUnverifiable = 0
    @Published private(set) var spentToday: Double = 0
    /// The last dispatch decision, kept so the UI can show the loop's own words
    /// rather than a sentence composed for the screen.
    @Published private(set) var lastDecision: HiveDispatchDecision = .idle("not started")

    private let store: HiveStore
    private let scanner: HiveRepoScanner
    private let verifier: HiveVerifier
    private var spendByDay: [String: Double] = [:]
    /// What each live bee was charged at dispatch, and the day it was charged
    /// to, so reconciliation cannot credit the wrong day across midnight.
    private var reservations: [String: (day: String, amount: Double)] = [:]
    /// Read once per cycle rather than once per review row, so a list of twenty
    /// tasks does not run twenty `git rev-parse` calls.
    private var currentHead: String?
    private var rateLimiter = HiveRateLimiter()
    private var timer: Timer?
    private var runners: [String: BeeRunner] = [:]
    private var chats: [String: HiveChatWriter] = [:]
    private var cycleInFlight = false

    init(
        store: HiveStore = HiveStore(),
        scanner: HiveRepoScanner = HiveRepoScanner(),
        verifier: HiveVerifier = HiveVerifier()
    ) {
        self.store = store
        self.scanner = scanner
        self.verifier = verifier
        let state = store.load()
        self.policy = state.policy
        self.tasks = state.tasks
        self.spendByDay = state.spendByDay
        self.spentToday = state.spent()
        self.events = store.recentEvents(limit: 60)
    }

    // MARK: - Derived

    var runningCount: Int { bees.filter { !$0.status.isTerminal }.count }

    var schedulableTasks: [HiveTask] {
        tasks
            .filter(\.isSchedulable)
            .filter { task in !bees.contains { $0.taskID == task.id && !$0.status.isTerminal } }
            .sorted { $0.score > $1.score }
    }

    /// Ranked targets minus the ones the operator has ruled out.
    var eligibleTargets: [HiveTarget] {
        targets.filter { policy.skippedModules[$0.module] == nil }
    }

    var doneCount: Int { tasks.filter { $0.state == .done }.count }
    var toxicCount: Int { tasks.filter { $0.state == .toxic }.count }
    var reviewCount: Int { tasks.filter { $0.state == .review }.count }
    var spawnsThisHour: Int { rateLimiter.spawnsInLastHour() }

    /// Everything the pure decision function needs, gathered from the parts of
    /// the orchestrator that cannot be pure: live processes, a rate limiter, a
    /// spend ledger and an auth probe.
    var dispatchContext: HiveDispatchContext {
        HiveDispatchContext(
            policy: policy,
            tasks: tasks,
            liveBees: runningCount,
            spentToday: spentToday,
            spawnsInLastHour: rateLimiter.spawnsInLastHour(),
            consecutiveFailures: consecutiveFailures,
            consecutiveUnverifiable: consecutiveUnverifiable,
            auth: authState
        )
    }

    /// The standing invariants evaluated against right now. An empty result is
    /// the only state in which the loop may dispatch.
    var invariantViolations: [HiveInvariantViolation] {
        HiveInvariants.check(policy: policy, tasks: tasks, spentToday: spentToday)
    }

    /// Whether a task's recorded verdict still describes the current tree.
    func evidenceState(for task: HiveTask) -> HiveEvidenceState {
        guard task.verification != nil else { return .unrecorded }
        return HiveVerifier.evidenceState(
            verifiedAt: task.verifiedAtCommit,
            currentHead: currentHead
        )
    }

    // MARK: - Control

    func start() {
        var updated = policy
        updated.enabled = true
        // Arming is the operator's statement that the cause was addressed, so
        // it is also the only thing that clears either breaker.
        consecutiveFailures = 0
        consecutiveUnverifiable = 0
        blocker = nil
        apply(updated)
        record(kind: "hive_start", detail: "24/7 loop armed - interval \(policy.cycleIntervalSeconds)s, max \(policy.maxConcurrentBees) bees")
        scheduleTimer()
        Task { await runCycle(trigger: "start") }
    }

    func pause() {
        var updated = policy
        updated.enabled = false
        apply(updated)
        timer?.invalidate()
        timer = nil
        nextCycleAt = nil
        statusLine = "paused - \(runningCount) bee(s) still finishing"
        record(kind: "hive_pause", detail: "loop paused by operator; running bees were left to finish")
    }

    /// Stops the loop *and* every live bee. The blunt instrument.
    func stopAll() {
        pause()
        for bee in bees where !bee.status.isTerminal {
            bee.cancel()
        }
        record(kind: "hive_stop_all", detail: "all bees terminated by operator")
        statusLine = "stopped"
    }

    func updatePolicy(_ new: HivePolicy) {
        apply(new)
        if policy.enabled { scheduleTimer() }
    }

    func runCycleNow() {
        Task { await runCycle(trigger: "manual") }
    }

    func cancel(_ bee: Bee) {
        bee.cancel()
        record(kind: "bee_cancelled", taskID: bee.taskID, detail: "cancelled by operator")
    }

    /// Dispatches one ranked target immediately, outside the cycle.
    func sendBee(to target: HiveTarget) async {
        guard let task = HiveTaskFactory.makeTask(from: target, policy: policy) else { return }
        guard let executable = await preflight() else { return }
        if !tasks.contains(where: { $0.id == task.id }) {
            tasks.append(task)
            record(kind: "task_created", taskID: task.id, detail: task.reason)
        }
        spawn(task, executable: executable)
    }

    /// Records the operator's judgement that a module is not worth a bee.
    /// The ranking cannot measure value; this is where value enters.
    func skip(module: String, why: String) {
        var updated = policy
        updated.skippedModules[module] = why
        apply(updated)
        // Any queued-but-unstarted task for that module goes with it.
        for index in tasks.indices
        where tasks[index].module == module && tasks[index].isSchedulable {
            tasks[index].state = .toxic
            tasks[index].lastError = "module skipped by operator: \(why)"
            tasks[index].updatedAt = Date()
        }
        persist()
        record(kind: "module_skipped", detail: "\(module): \(why)")
    }

    func unskip(module: String) {
        var updated = policy
        updated.skippedModules[module] = nil
        apply(updated)
        record(kind: "module_unskipped", detail: module)
    }

    /// Clears a task's toxic mark so the Queen may try it again.
    func rehabilitate(_ taskID: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].state = .pending
        tasks[index].attempts = 0
        tasks[index].lastError = nil
        tasks[index].updatedAt = Date()
        persist()
        record(kind: "task_rehabilitated", taskID: taskID, detail: "attempt counter reset by operator")
    }

    /// Accepts a bee's work: the task is closed and will not be re-picked.
    func accept(_ taskID: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].state = .done
        tasks[index].updatedAt = Date()
        persist()
        record(kind: "task_accepted", taskID: taskID, detail: "operator accepted the result")
    }

    /// Rejects a bee's work: back to the queue, attempt already counted.
    func reject(_ taskID: String, why: String) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].state = tasks[index].attempts >= policy.maxAttemptsPerTask ? .toxic : .pending
        tasks[index].lastError = why
        tasks[index].updatedAt = Date()
        persist()
        record(kind: "task_rejected", taskID: taskID, detail: why)
    }

    // MARK: - Scan & rank

    /// Re-measures the system. Safe to call at any time; never spawns anything.
    func rescan() async {
        guard !isScanning else { return }
        isScanning = true
        statusLine = "scanning the system..."
        let scanner = self.scanner
        let facts = await Task.detached(priority: .utility) { scanner.scan() }.value
        targets = HivePriorityEngine.rank(facts)
        lastScanAt = Date()
        isScanning = false

        let fullyMeasured = targets.filter { $0.confidence >= 0.999 }.count
        statusLine = "ranked \(targets.count) modules - \(fullyMeasured) fully measured"
    }

    // MARK: - The cycle

    func runCycle(trigger: String) async {
        guard !cycleInFlight else { return }
        cycleInFlight = true
        defer { cycleInFlight = false }

        lastCycleAt = Date()
        harvest()

        // The day key is read from the clock every cycle, not cached from the
        // last bee that finished. A loop that hit the ceiling at 23:40 held a
        // stale `spentToday` for ever: the persisted ledger rolled over at
        // midnight but nothing asked it again, so the block outlived the day it
        // belonged to and only a relaunch could clear it.
        spentToday = HiveState(policy: policy, tasks: tasks, spendByDay: spendByDay).spent()

        let verifier = self.verifier
        currentHead = await Task.detached(priority: .utility) {
            verifier.head(at: verifier.projectRoot)
        }.value

        await rescan()
        materialiseTasks()

        guard policy.enabled else {
            lastDecision = .idle("the loop is not armed")
            statusLine = "paused - \(schedulableTasks.count) task(s) queued"
            persist()
            return
        }

        guard let executable = await preflight() else {
            lastDecision = .blocked(blocker ?? "preflight failed")
            statusLine = "blocked"
            return
        }

        // One decision function, asked repeatedly. Each spawn changes the very
        // counters `decide` reads - live bees, the rate window, the reserved
        // spend - so the loop re-asks rather than deciding once and acting
        // several times against a snapshot that is no longer true. The bound is
        // the concurrency limit; it exists so a bug in the state machine cannot
        // turn this into an unbounded spawn loop.
        var spawned = 0
        var decision = HiveDispatch.decide(dispatchContext)
        while case .dispatch(let task) = decision, spawned < policy.maxConcurrentBees {
            spawn(task, executable: executable)
            spawned += 1
            decision = HiveDispatch.decide(dispatchContext)
        }
        lastDecision = decision

        switch decision {
        case .blocked(let why):
            if blocker != why { record(kind: "hive_blocked", detail: why) }
            blocker = why
            if consecutiveFailures >= policy.maxConsecutiveFailures
                || consecutiveUnverifiable >= HiveDispatch.maxConsecutiveUnverifiable {
                tripBreaker(why)
            }
        case .idle, .dispatch:
            blocker = nil
        }

        statusLine = spawned > 0
            ? "cycle (\(trigger)): \(spawned) bee(s) spawned, \(runningCount) working"
            : "cycle (\(trigger)): \(decision.reason), \(runningCount) working"
        persist()
        scheduleTimer()
    }

    /// Turns the top-ranked targets into tasks, without duplicating a task that
    /// already exists for the same module-and-weakness.
    func materialiseTasks() {
        // Every existing task is re-scored from this scan, not only the ones
        // that happen to be in today's top slice. A score computed in one cycle
        // and left frozen is compared, in the queue, against scores computed in
        // another - so a task could keep the rank it earned during a busy month
        // long after the tree it described went quiet.
        var byModuleAndKind: [String: HiveTarget] = [:]
        for target in targets {
            guard let kind = target.dominantKind else { continue }
            byModuleAndKind[HiveTaskFactory.taskID(module: target.module, kind: kind)] = target
        }
        for index in tasks.indices {
            guard let target = byModuleAndKind[tasks[index].id] else { continue }
            tasks[index].score = target.score
            tasks[index].confidence = target.confidence
            tasks[index].reason = target.reason
        }

        // The confidence filter runs before the window, not after it. Taking
        // the top three and then declining two of them for thin evidence leaves
        // one bee dispatched where three were budgeted, and the targets that
        // were displaced never get looked at.
        var created = 0
        var considered = 0
        for target in eligibleTargets {
            guard considered < policy.targetsPerCycle else { break }
            guard let candidate = HiveTaskFactory.makeTask(from: target, policy: policy) else {
                if let why = HiveTaskFactory.rejection(for: target) {
                    record(kind: "target_declined", detail: "\(target.module): \(why)")
                }
                continue
            }
            considered += 1
            if let existing = tasks.firstIndex(where: { $0.id == candidate.id }) {
                // Refresh the ranking metadata; leave state and attempts alone.
                tasks[existing].score = candidate.score
                tasks[existing].confidence = candidate.confidence
                tasks[existing].reason = candidate.reason
                tasks[existing].prompt = candidate.prompt
                continue
            }
            tasks.append(candidate)
            created += 1
            record(kind: "task_created", taskID: candidate.id, detail: candidate.reason)
        }
        if created > 0 { persist() }
    }

    // MARK: - Preflight

    /// Resolves the CLI and confirms it can actually work, returning nil (and
    /// setting `blocker`) otherwise. Runs before any spawn so an environmental
    /// fault never gets charged to a task's attempt budget.
    @discardableResult
    func preflight() async -> String? {
        guard let executable = HiveProcess.resolve("claude", overrideEnvKey: "CLAUDE_EXECUTABLE") else {
            let why = "claude CLI not found - looked in ~/.local/bin, /opt/homebrew/bin, /usr/local/bin, ~/.claude/local"
            if blocker != why { record(kind: "hive_blocked", detail: why) }
            blocker = why
            authState = nil
            return nil
        }

        let state = await Task.detached(priority: .utility) {
            HiveAuthProbe.check(executable: executable)
        }.value
        authState = state

        guard let why = state.blockerText else {
            blocker = nil
            return executable
        }
        if blocker != why { record(kind: "hive_blocked", detail: why) }
        blocker = why
        return nil
    }

    // MARK: - Spawning

    func spawn(_ task: HiveTask, executable: String) {
        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        guard tasks[index].attempts < policy.maxAttemptsPerTask else {
            tasks[index].state = .toxic
            record(
                kind: "task_toxic",
                taskID: task.id,
                detail: "\(tasks[index].attempts) attempts without success - never picked again"
            )
            persist()
            return
        }

        let sessionID = UUID().uuidString
        let worktree = policy.useWorktree ? "hive-\(task.id)" : nil

        let configuration = BeeRunner.Configuration(
            executable: executable,
            workingDirectory: TrinityRuntimePaths.projectRoot,
            prompt: task.prompt,
            sessionID: sessionID,
            model: policy.model,
            permissionMode: policy.permissionMode,
            maxBudgetUSD: policy.maxBudgetUSDPerBee,
            timeoutSeconds: policy.beeTimeoutSeconds,
            worktreeName: worktree,
            displayName: "bee/\(task.id)"
        )

        let runner = BeeRunner(configuration: configuration)
        let bee = Bee(task: task, sessionID: sessionID, branch: worktree, runner: runner)

        tasks[index].state = .running
        tasks[index].attempts += 1
        tasks[index].sessionID = sessionID
        tasks[index].branch = worktree
        tasks[index].updatedAt = Date()
        tasks[index].lastDispatchAt = Date()
        // A verdict grades one attempt. Left in place across a re-dispatch it
        // becomes a VERIFIED badge, with a real test tally under it, describing
        // code the next bee is about to overwrite.
        tasks[index].clearVerdict()

        // Charge the full per-bee budget now, and reconcile downward when the
        // bee reports what it actually cost. Debiting only what a bee reports
        // means a bee that hangs, is killed on the wall clock, or dies without
        // a result line costs the ledger nothing while costing real money at
        // the provider: two such bees an hour spend ten times the daily ceiling
        // while the dashboard reads zero. Absent is not zero here either.
        reserve(policy.maxBudgetUSDPerBee, for: task.id)

        if policy.openChatPerTask,
           let chat = HiveChatWriter(task: tasks[index], sessionID: sessionID) {
            chats[task.id] = chat
            tasks[index].threadID = chat.threadID
        }

        bees.insert(bee, at: 0)
        runners[task.id] = runner
        rateLimiter.record()

        record(
            kind: "bee_spawned",
            taskID: task.id,
            detail: "session \(sessionID)\(worktree.map { ", worktree \($0)" } ?? ""), attempt \(tasks[index].attempts)"
        )
        persist()

        runner.start(
            onEvent: { [weak self, weak bee] event in
                bee?.append(event)
                self?.chats[task.id]?.append(event)
            },
            onFinish: { [weak self, weak bee] outcome in
                bee?.finish(outcome)
                self?.chats[task.id]?.finish(outcome)
                self?.complete(taskID: task.id, outcome: outcome)
            }
        )
    }

    /// Spawns a bee for an arbitrary instruction the operator typed, outside
    /// the ranking. Same guardrails, same chat, same audit trail.
    func spawnManualTask(title: String, instruction: String) async {
        guard let executable = await preflight() else { return }
        let trimmed = instruction.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let slug = title
            .lowercased()
            .replacingOccurrences(of: " ", with: "-")
            .filter { $0.isLetter || $0.isNumber || $0 == "-" }
        var task = HiveTask(
            id: "hive-manual-\(slug.isEmpty ? UUID().uuidString.prefix(8).lowercased() : slug)",
            title: title.isEmpty ? "operator task" : title,
            module: "operator",
            path: ".",
            realm: "Operator",
            signalKind: "manual",
            reason: "queued by the operator, outside the ranking",
            score: 1.0,
            confidence: 1.0,
            prompt: trimmed
        )
        if tasks.contains(where: { $0.id == task.id }) {
            task.id += "-\(Int(Date().timeIntervalSince1970))"
        }
        tasks.append(task)
        spawn(task, executable: executable)
    }

    // MARK: - Harvest

    private func complete(taskID: String, outcome: BeeOutcome) {
        guard outcome.status.isTerminal else { return }
        runners[taskID] = nil
        chats[taskID] = nil
        reconcile(taskID: taskID, reported: outcome.costUSD)

        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        tasks[index].resultSummary = String(outcome.summary.prefix(2000))
        tasks[index].costUSD = outcome.costUSD
        tasks[index].durationMs = outcome.durationMs
        tasks[index].updatedAt = Date()

        let succeeded = outcome.status == .succeeded
        record(
            kind: succeeded ? "bee_succeeded" : "bee_finished",
            taskID: taskID,
            detail: "\(outcome.status.label): \(String(outcome.summary.prefix(300)))"
        )

        guard succeeded, policy.verifyBeforeReview else {
            resolve(taskID: taskID, outcome: outcome, verdict: nil)
            return
        }

        let task = tasks[index]
        tasks[index].state = .running   // still occupied: the check is work
        persist()
        Task { await runVerification(for: task, outcome: outcome) }
    }

    /// Executes the project's own checks against the bee's tree. Runs off the
    /// main actor: `swift build` can take minutes and must not freeze the UI.
    private func runVerification(for task: HiveTask, outcome: BeeOutcome) async {
        let verifier = self.verifier
        record(kind: "verify_started", taskID: task.id, detail: "running the project's own checks")

        let verdict = await Task.detached(priority: .utility) {
            verifier.verify(task: task)
        }.value
        let head = await Task.detached(priority: .utility) {
            verifier.head(at: verifier.projectRoot)
        }.value

        guard let index = tasks.firstIndex(where: { $0.id == task.id }) else { return }
        tasks[index].verification = "\(verdict.label): \(String(verdict.detail.prefix(1500)))"
        tasks[index].verified = verdict.isPass ? true : (verdict.isFail ? false : nil)
        // Stamp what the verdict was measured against, so a review opened days
        // later can say whether the evidence still describes the tree.
        tasks[index].verifiedAtCommit = head
        tasks[index].verifiedAt = Date()
        tasks[index].updatedAt = Date()

        record(
            kind: verdict.isPass ? "verify_passed" : (verdict.isFail ? "verify_failed" : "verify_unavailable"),
            taskID: task.id,
            detail: String(verdict.detail.prefix(300))
        )
        resolve(taskID: task.id, outcome: outcome, verdict: verdict)
    }

    /// Applies the pure state machine's answer, and moves the two breakers.
    private func resolve(taskID: String, outcome: BeeOutcome, verdict: HiveVerdict?) {
        guard let index = tasks.firstIndex(where: { $0.id == taskID }) else { return }
        let succeeded = outcome.status == .succeeded
        let resolution = HiveDispatch.outcomeState(
            for: tasks[index],
            verdict: verdict,
            beeSucceeded: succeeded,
            policy: policy
        )
        tasks[index].state = resolution.state
        tasks[index].updatedAt = Date()

        if resolution.state == .review, !policy.verifyBeforeReview {
            tasks[index].verification = "verification disabled by policy"
            tasks[index].verified = nil
        }

        switch resolution.streak {
        case .increment:
            tasks[index].lastError = String((verdict?.detail ?? outcome.summary).prefix(500))
            consecutiveFailures += 1
            consecutiveUnverifiable = 0
            record(
                kind: resolution.state == .toxic ? "task_toxic" : "bee_failed",
                taskID: taskID,
                detail: "\(outcome.status.label): \(String((verdict?.detail ?? outcome.summary).prefix(300)))"
            )
        case .clear:
            tasks[index].lastError = nil
            consecutiveFailures = 0
            consecutiveUnverifiable = 0
        case .hold:
            // The bee finished and nothing could grade it. That neither earns a
            // failure nor clears one; it moves the second breaker instead, so a
            // machine where nothing is checkable pauses rather than running all
            // day producing review items nobody verified.
            consecutiveUnverifiable += 1
        }

        if consecutiveFailures >= policy.maxConsecutiveFailures {
            tripBreaker(
                "circuit breaker: \(consecutiveFailures) bees failed in a row - the loop paused itself. "
                    + "Fix the cause, then Run 24/7 again (that also resets the counter)."
            )
        } else if consecutiveUnverifiable >= HiveDispatch.maxConsecutiveUnverifiable {
            tripBreaker(
                "circuit breaker: \(consecutiveUnverifiable) bees in a row finished with no runnable "
                    + "check - the loop cannot grade its own work, so it paused itself rather than "
                    + "filling the review list with unchecked claims."
            )
        }

        persist()
        fillFreedSlot()
    }

    // MARK: - Spend

    /// Charges the full per-bee budget the moment a bee goes out.
    private func reserve(_ amount: Double, for taskID: String) {
        guard amount > 0 else { return }
        let day = HiveState.dayKey()
        var state = HiveState(policy: policy, tasks: tasks, spendByDay: spendByDay)
        state.record(spend: amount)
        spendByDay = state.spendByDay
        spentToday = state.spent()
        reservations[taskID] = (day: day, amount: amount)
    }

    /// Settles a reservation against what the bee actually reported.
    ///
    /// A terminal bee that reported no cost at all keeps its whole reservation.
    /// `costUSD == nil` means the bee hung, was killed, or died before printing
    /// a result line - none of which are free, and all of which the provider
    /// bills. Treating that absence as a zero is the same mistake the signal
    /// scanner refuses to make.
    private func reconcile(taskID: String, reported: Double?) {
        guard let reservation = reservations.removeValue(forKey: taskID) else {
            guard let reported, reported > 0 else { return }
            var state = HiveState(policy: policy, tasks: tasks, spendByDay: spendByDay)
            state.record(spend: reported)
            spendByDay = state.spendByDay
            spentToday = state.spent()
            return
        }
        guard let reported else { return }
        var state = HiveState(policy: policy, tasks: tasks, spendByDay: spendByDay)
        if reported < reservation.amount {
            state.refund(reservation.amount - reported, forDay: reservation.day)
        } else if reported > reservation.amount {
            state.record(spend: reported - reservation.amount)
        }
        spendByDay = state.spendByDay
        spentToday = state.spent()
    }

    /// Stops the loop after repeated failures and says why, instead of chewing
    /// through every task at three attempts each on a fault none of them caused.
    private func tripBreaker(_ why: String) {
        if policy.enabled {
            var updated = policy
            updated.enabled = false
            apply(updated)
            timer?.invalidate()
            timer = nil
            nextCycleAt = nil
        }
        blocker = why
        statusLine = "breaker tripped"
        record(kind: "breaker_tripped", detail: why)
    }

    private func fillFreedSlot() {
        guard policy.enabled, runningCount < policy.maxConcurrentBees else { return }
        Task { await runCycle(trigger: "slot-free") }
    }

    /// Drops finished bees older than an hour from the live list, and prunes
    /// the artefacts a long-running loop leaves on disk. Their record lives in
    /// the task list and the audit log, not in this array.
    private func harvest() {
        let cutoff = Date().addingTimeInterval(-3600)
        bees.removeAll { $0.status.isTerminal && $0.startedAt < cutoff }

        let retention = HiveRetention(threadsDirectory: HiveChatWriter.defaultThreadsDirectory())
        let pruned = retention.prune(olderThanDays: policy.retainTranscriptDays)
        if !pruned.isEmpty {
            record(
                kind: "retention",
                detail: "pruned \(pruned.transcriptsRemoved) transcript(s) and \(pruned.threadsRemoved) hive chat(s) older than \(policy.retainTranscriptDays)d"
            )
        }
    }

    // MARK: - Plumbing

    private func apply(_ new: HivePolicy) {
        policy = new.sanitized()
        persist()
    }

    private func scheduleTimer() {
        timer?.invalidate()
        guard policy.enabled else { return }
        let interval = TimeInterval(policy.cycleIntervalSeconds)
        nextCycleAt = Date().addingTimeInterval(interval)
        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            Task { @MainActor in await self?.runCycle(trigger: "timer") }
        }
        // .common keeps the loop ticking while a menu or sheet is open.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    private func persist() {
        var state = HiveState(policy: policy, tasks: tasks, spendByDay: spendByDay)
        state.updatedAt = Date()
        store.save(state)
    }

    private func record(kind: String, taskID: String? = nil, detail: String) {
        let event = HiveEvent(kind: kind, taskID: taskID, detail: detail)
        store.append(event)
        events.insert(event, at: 0)
        if events.count > 200 { events.removeLast(events.count - 200) }
    }
}
