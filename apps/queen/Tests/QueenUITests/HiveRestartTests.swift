import Testing
import Foundation
@testable import QueenUILib

// ===========================================================================
// THE RESTART TRAP.
//
// Every claim the Hive makes about rates, money and progress is a claim about
// a process. A relaunch is not an exceptional event on this machine - a
// watchdog restores the app within 60s of it dying - so any bound that lives
// only in memory is a bound the machine does not have.
//
// These tests are written against a state file, not against an object, so they
// fail if the persistence is removed rather than if the arithmetic changes.
// ===========================================================================

private func pendingTask(
    _ id: String = "hive-demo-testGap",
    score: Double = 0.9
) -> HiveTask {
    HiveTask(
        id: id, title: id, module: "demo", path: "demo", realm: "Core",
        signalKind: "testGap", reason: "r", score: score, confidence: 1, prompt: "p"
    )
}

private func temporaryRoot() -> URL {
    FileManager.default.temporaryDirectory
        .appendingPathComponent("hive-tests-\(UUID().uuidString)", isDirectory: true)
}

@Suite("Hive - the rate window survives a restart")
struct HiveSpawnWindowPersistenceTests {

    /// The headline claim: the hourly bound composes across process
    /// lifetimes. Delete the persistence and this test dispatches a seventh
    /// bee in the same hour.
    @Test func theHourlyBoundHoldsAcrossARestart() {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HiveStore(stateRoot: root.path)

        var policy = HivePolicy.default
        policy.enabled = true
        policy.maxBeesPerHour = 6

        // Six bees went out over the last ten minutes, then the process died.
        var limiter = HiveRateLimiter()
        let now = Date()
        for minute in 0..<6 { limiter.record(now.addingTimeInterval(-Double(minute) * 60)) }
        #expect(limiter.spawnsInLastHour(now) == 6)
        #expect(
            store.save(
                HiveState(policy: policy, tasks: [pendingTask()], spawnWindow: limiter.spawnTimes)
            )
        )

        // The watchdog relaunches the app within the minute.
        let reloaded = store.load()
        let restarted = HiveRateLimiter(spawnTimes: reloaded.spawnWindow, now: now)
        #expect(restarted.spawnsInLastHour(now) == 6)

        let decision = HiveDispatch.decide(
            HiveDispatchContext(
                policy: policy,
                tasks: reloaded.tasks,
                liveBees: 0,
                spentToday: 0,
                spawnsInLastHour: restarted.spawnsInLastHour(now),
                consecutiveFailures: 0,
                auth: .loggedIn(method: "oauth")
            )
        )
        #expect(!decision.isDispatch)
        #expect(decision.reason.contains("already started this hour"))
    }

    /// The reason a persisted window must be pruned on load rather than
    /// trusted: a file written on Monday would otherwise hand Thursday's
    /// limiter six spawns that never happened this hour.
    @Test func aWindowFromThreeDaysAgoCannotBeReplayed() {
        let now = Date()
        let window = [
            now.addingTimeInterval(-3 * 86_400),
            now.addingTimeInterval(-7200),
            now.addingTimeInterval(-3601),
            now.addingTimeInterval(-1800),
            now.addingTimeInterval(-60),
        ]
        let pruned = HiveState.prunedSpawnWindow(window, now: now)
        #expect(pruned.count == 2)
        #expect(HiveRateLimiter(spawnTimes: pruned, now: now).spawnsInLastHour(now) == 2)
    }

    /// A clock that moved backwards must not leave entries that never expire.
    @Test func aWindowFromTheFutureIsDropped() {
        let now = Date()
        let pruned = HiveState.prunedSpawnWindow([now.addingTimeInterval(600)], now: now)
        #expect(pruned.isEmpty)
    }

    /// Pruning happens at the one place every load passes through, so nothing
    /// downstream has to remember to do it.
    @Test func theStorePrunesTheWindowOnLoad() {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HiveStore(stateRoot: root.path)
        let now = Date()

        let stale = HiveState(
            policy: .default,
            tasks: [],
            spawnWindow: [now.addingTimeInterval(-86_400), now.addingTimeInterval(-120)]
        )
        #expect(store.save(stale))
        #expect(store.load().spawnWindow.count == 1)
    }

    /// The key is really written. A round trip that passes because both sides
    /// forgot the field would be no evidence at all.
    @Test func theWindowIsNamedInTheStateFile() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HiveStore(stateRoot: root.path)
        #expect(store.save(HiveState(policy: .default, tasks: [], spawnWindow: [Date()])))

        let text = try String(contentsOf: store.stateURL, encoding: .utf8)
        #expect(text.contains("spawnWindow"))
    }

    /// A state file written before the window was persisted must still load.
    /// Throwing here would silently hand the operator a default policy, which
    /// reads exactly like they never configured anything.
    @Test func anOlderStateFileWithoutTheWindowStillLoads() throws {
        let json = """
        {
          "policy": { "enabled": true, "maxBeesPerHour": 4 },
          "tasks": [],
          "spendByDay": { "2026-08-13": 3.5 }
        }
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let state = try decoder.decode(HiveState.self, from: Data(json.utf8))
        #expect(state.policy.enabled)
        #expect(state.policy.maxBeesPerHour == 4)
        #expect(state.spawnWindow.isEmpty)
        #expect(state.reservations.isEmpty)
    }

    /// The limiter seeded from disk prunes what it was handed, so a caller
    /// that skips `HiveStore.load` cannot smuggle an old window past it.
    @Test func theLimiterPrunesWhatItIsSeededWith() {
        let now = Date()
        let limiter = HiveRateLimiter(
            spawnTimes: [now.addingTimeInterval(-7200), now.addingTimeInterval(-30)],
            now: now
        )
        #expect(limiter.spawnTimes.count == 1)
    }
}

/// The orchestrator's own wiring, driven through a temporary state root.
///
/// The tests above prove the state file can carry a window and that the
/// limiter honours one. These prove the running object actually reads it and
/// writes it back - the two lines a later refactor is most likely to drop,
/// and which no assertion about `HiveState` alone would notice.
@Suite("Hive - the orchestrator reads and writes what it claims to")
@MainActor
struct HiveOrchestratorRestartTests {

    private func orchestrator(root: URL) -> HiveOrchestrator {
        HiveOrchestrator(store: HiveStore(stateRoot: root.path))
    }

    @Test func theWindowIsSeededOnLoadAndWrittenBackOnPersist() {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HiveStore(stateRoot: root.path)

        var policy = HivePolicy.default
        policy.maxBeesPerHour = 6
        let now = Date()
        #expect(
            store.save(
                HiveState(
                    policy: policy,
                    tasks: [],
                    spawnWindow: [now.addingTimeInterval(-120), now.addingTimeInterval(-60)]
                )
            )
        )

        let hive = orchestrator(root: root)
        // Seeded: the limiter inherited this hour's real spawns.
        #expect(hive.spawnsThisHour == 2)
        #expect(hive.dispatchContext.spawnsInLastHour == 2)

        // Written back: any persist keeps the window in the file.
        hive.updatePolicy(policy)
        #expect(store.load().spawnWindow.count == 2)
    }

    /// The critical one. A file that says armed, with no clock behind it,
    /// must say so in the audit log and in the badge.
    @Test func armedInTheFileWithNoClockAsksForAResume() {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HiveStore(stateRoot: root.path)

        var policy = HivePolicy.default
        policy.enabled = true
        #expect(store.save(HiveState(policy: policy, tasks: [pendingTask()])))

        let hive = orchestrator(root: root)
        #expect(hive.policy.enabled)
        #expect(hive.loopStatus == .resumeRequired)
        #expect(!hive.loopStatus.isTicking)
        #expect(hive.events.contains { $0.kind == "hive_resume_required" })
    }

    /// A disarmed file says nothing and asks for nothing.
    @Test func aDisarmedFileIsSilent() {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HiveStore(stateRoot: root.path)
        #expect(store.save(HiveState(policy: .default, tasks: [pendingTask()])))

        let hive = orchestrator(root: root)
        #expect(hive.loopStatus == .idle)
        #expect(!hive.events.contains { $0.kind == "hive_resume_required" })
    }

    /// Three restarts with two bees in flight each used to leave $30 charged
    /// against a $25 ceiling for about $2.40 of real work, with no breaker
    /// tripped and nothing on screen saying the money was never spent.
    @Test func orphanedReservationsAreSettledOnLoadNotInherited() {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HiveStore(stateRoot: root.path)

        let day = HiveState.dayKey()
        var state = HiveState(
            policy: .default,
            tasks: [],
            spendByDay: [day: 30],
            reservations: [
                // No transcript exists for either session, and no pid, so
                // both bees provably wrote nothing.
                "a": HiveReservation(taskID: "a", sessionID: UUID().uuidString, day: day, amount: 5, pid: nil),
                "b": HiveReservation(taskID: "b", sessionID: UUID().uuidString, day: day, amount: 5, pid: nil),
            ]
        )
        state.updatedAt = Date()
        #expect(store.save(state))

        let hive = orchestrator(root: root)
        #expect(hive.spentToday == 20)
        #expect(hive.events.filter { $0.kind == "reservation_refunded" }.count == 2)
        // Settled reservations do not survive into the new process, so they
        // cannot block a fresh bee on the same task for ever.
        #expect(store.load().reservations.isEmpty)
    }
}

@Suite("Hive - armed is not ticking")
struct HiveLoopStatusTests {

    /// `policy.enabled` is a persisted wish. Only a live timer is a clock.
    @Test func armedWithoutAClockIsItsOwnState() {
        #expect(HiveLoopStatus.of(enabled: false, ticking: false) == .idle)
        #expect(HiveLoopStatus.of(enabled: true, ticking: true) == .ticking)
        #expect(HiveLoopStatus.of(enabled: true, ticking: false) == .resumeRequired)
        // A timer with the loop disarmed is still not a running loop.
        #expect(HiveLoopStatus.of(enabled: false, ticking: true) == .idle)
    }

    /// The badge, the countdown and the Run button all read this. Only one of
    /// the three states may claim the loop is running.
    @Test func onlyTheTickingStateReadsAsRunning() {
        #expect(HiveLoopStatus.ticking.isTicking)
        #expect(!HiveLoopStatus.resumeRequired.isTicking)
        #expect(!HiveLoopStatus.idle.isTicking)
        #expect(HiveLoopStatus.resumeRequired.needsOperator)
        #expect(HiveLoopStatus.resumeRequired.advice != nil)
        #expect(HiveLoopStatus.ticking.advice == nil)
        #expect(HiveLoopStatus.idle.advice == nil)
        // The three labels are distinct, so no state can be mistaken for
        // another on screen.
        #expect(Set([HiveLoopStatus.idle, .ticking, .resumeRequired].map(\.label)).count == 3)
    }
}

@Suite("Hive - the cycle latch has a deadline")
struct HiveCycleLatchTests {

    @Test func aSecondCycleIsDroppedWhileTheFirstRuns() {
        var latch = HiveCycleLatch()
        let start = Date()
        let first = latch.enter(now: start, deadline: 3600)
        #expect(first.token != nil)
        #expect(latch.isInFlight)

        let second = latch.enter(now: start.addingTimeInterval(5), deadline: 3600)
        #expect(second.token == nil)
        #expect(second == .busy(heldFor: 5))
    }

    /// The defect this replaces: a cycle that wedged on a subprocess ignoring
    /// SIGTERM held the loop for ever, and `Cycle now` did nothing at all.
    @Test func aWedgedCycleIsForcedOpen() {
        var latch = HiveCycleLatch()
        let start = Date()
        _ = latch.enter(now: start, deadline: 3600)

        let later = latch.enter(now: start.addingTimeInterval(3601), deadline: 3600)
        guard case .forced(_, let heldFor) = later else {
            Issue.record("a cycle held past its deadline must be forced open")
            return
        }
        #expect(heldFor >= 3600)
        #expect(later.token != nil)
    }

    /// Forcing the latch open creates two claimants. The wedged cycle, if it
    /// ever returns, must not release a latch the new one holds - otherwise a
    /// third cycle runs concurrently with the second.
    @Test func aForcedOutCycleCannotReleaseTheLatchItLost() {
        var latch = HiveCycleLatch()
        let start = Date()
        let wedged = latch.enter(now: start, deadline: 60)
        let rescuer = latch.enter(now: start.addingTimeInterval(120), deadline: 60)

        latch.leave(token: wedged.token!)
        #expect(latch.isInFlight)

        latch.leave(token: rescuer.token!)
        #expect(!latch.isInFlight)
    }

    /// The deadline is derived from the loop's own interval and floored at an
    /// hour, so a slow scan is never mistaken for a wedge.
    @Test func theDeadlineIsAtLeastAnHourAndTwoIntervals() {
        #expect(HiveCycleLatch.wedgeDeadline(cycleIntervalSeconds: 30) == 3600)
        #expect(HiveCycleLatch.wedgeDeadline(cycleIntervalSeconds: 900) == 3600)
        #expect(HiveCycleLatch.wedgeDeadline(cycleIntervalSeconds: 7200) == 14400)
    }
}

@Suite("Hive - one live bee per task")
struct HiveSpawnAdmissionTests {

    @Test func aTaskWithALiveBeeRefusesASecondOne() {
        let refusal = HiveDispatch.admissionRefusal(
            taskID: "hive-apps-queen-testGap",
            liveTaskIDs: ["hive-apps-queen-testGap"],
            reservedTaskIDs: []
        )
        #expect(refusal?.contains("already working") == true)
    }

    /// A reservation outlives its bee's process. Admitting a second bee while
    /// one is outstanding is how an operator dispatched ten bees against a
    /// two-bee limit.
    @Test func anUnsettledReservationAlsoRefuses() {
        let refusal = HiveDispatch.admissionRefusal(
            taskID: "t",
            liveTaskIDs: [],
            reservedTaskIDs: ["t"]
        )
        #expect(refusal?.contains("reservation") == true)
    }

    @Test func anIdleTaskIsAdmitted() {
        #expect(
            HiveDispatch.admissionRefusal(
                taskID: "t",
                liveTaskIDs: ["other"],
                reservedTaskIDs: ["another"]
            ) == nil
        )
    }

    /// The operator's buttons cross the same envelope as the cycle: they
    /// choose which task runs, not whether the ceiling applies.
    @Test func theOperatorPathMeetsTheSameGuardrails() {
        var policy = HivePolicy.default
        policy.enabled = false          // the loop is paused; the human is not
        policy.dailyBudgetUSD = 25

        let refusal = HiveDispatch.guardrails(
            HiveDispatchContext(
                policy: policy,
                tasks: [pendingTask()],
                liveBees: 0,
                spentToday: 25,
                spawnsInLastHour: 0,
                consecutiveFailures: 0,
                auth: .loggedIn(method: "oauth")
            )
        )
        #expect(refusal?.isBlocked == true)
        #expect(refusal?.reason.contains("daily ceiling reached") == true)
    }

    /// A clear envelope returns nothing at all, so the caller can dispatch.
    @Test func aClearEnvelopeRefusesNothing() {
        var policy = HivePolicy.default
        policy.enabled = true
        #expect(
            HiveDispatch.guardrails(
                HiveDispatchContext(
                    policy: policy,
                    tasks: [pendingTask()],
                    liveBees: 0,
                    spentToday: 0,
                    spawnsInLastHour: 0,
                    consecutiveFailures: 0,
                    auth: .loggedIn(method: "oauth")
                )
            ) == nil
        )
    }
}

@Suite("Hive - the ordering key names its own assumption")
struct HiveOrderingKeyTests {

    private func target(
        _ module: String,
        score: Double,
        confidence: Double,
        weightedTotal: Double,
        signals: [HiveSignal] = []
    ) -> HiveTarget {
        HiveTarget(
            module: module, path: module, realm: .core, signals: signals,
            score: score, confidence: confidence, weightedTotal: weightedTotal
        )
    }

    /// One signal, already normalised. `nil` means its probe failed.
    private func signal(_ kind: HiveSignal.Kind, _ value: Double?) -> HiveSignal {
        let state: HiveSignalState = value.map { .measured($0) } ?? .unmeasured("probe failed")
        return HiveSignal(kind: kind, raw: state, normalized: state)
    }

    /// `zeroImputedScore` is the weighted mean with zero substituted for every
    /// unread signal. Stated as an identity so the name cannot drift from the
    /// arithmetic again - and it is the LOWER BOUND, not the key. Ordering on
    /// it was the defect: it reads every failed probe as perfect health.
    @Test func theZeroImputedScoreIsTheLowerBoundNotTheKey() {
        let totalWeight = HiveSignal.Kind.totalWeight
        #expect(abs(totalWeight - 1.0) < 1e-12)

        let t = target("m", score: 0.9, confidence: 0.4, weightedTotal: 0.36)
        #expect(t.zeroImputedScore == 0.36 / totalWeight)
        #expect(t.lowerBound == t.zeroImputedScore)
        // And it is neither of the other two numbers on display.
        #expect(t.zeroImputedScore != t.score)
        #expect(t.zeroImputedScore != t.priorImputedScore)
    }

    /// The sort follows the declared-prior key, and would have produced the
    /// opposite order under the key it replaced.
    @Test func theSortFollowsThePriorImputedKeyAndNotTheZeroImputedOne() {
        // Fully measured, every signal at 0.42.
        let fullSignals = HiveSignal.Kind.allCases.map { signal($0, 0.42) }
        let full = target(
            "a-full", score: 0.42, confidence: 1.0, weightedTotal: 0.42, signals: fullSignals
        )

        // Read on 58% of the weight and genuinely bad there; the rest unread.
        let partialSignals: [HiveSignal] = [
            signal(.todoDensity, 0.5),
            signal(.churn, nil),
            signal(.testGap, 1.0),
            signal(.sizeRisk, nil),
            signal(.declaredIncomplete, nil),
            signal(.openIssues, 0.5),
        ]
        let partial = target(
            "b-partial", score: 0.39 / 0.58, confidence: 0.58,
            weightedTotal: 0.39, signals: partialSignals
        )

        // The old key ranks the fully measured module first, because it counts
        // three failed probes as three readings of zero.
        #expect(partial.zeroImputedScore < full.zeroImputedScore)
        // The key the queue uses ranks the other way, and that is the order
        // that comes out of the sort.
        #expect(partial.priorImputedScore > full.priorImputedScore)
        #expect(HivePriorityEngine.ordered([full, partial]).map(\.module)
            == ["b-partial", "a-full"])
    }

    /// The tie-break the file declares now actually fires.
    ///
    /// These two keys are equal in exact arithmetic. Computed the old way -
    /// score times confidence - the blind target read 0.48400000000000004 and
    /// the sighted one 0.484, so the comparison never reached the confidence
    /// rule and the target with a FAILED probe sorted above the fully measured
    /// one.
    @Test func mathematicallyEqualKeysReachTheConfidenceTieBreak() {
        let blind = target("a-blind", score: 0.88, confidence: 0.55, weightedTotal: 0.484)
        let sighted = target("z-sighted", score: 0.484, confidence: 1.0, weightedTotal: 0.484)

        // The witness: the old key really did differ in the last bit.
        #expect(blind.score * blind.confidence != sighted.score * sighted.confidence)
        #expect(blind.score * blind.confidence > sighted.score * sighted.confidence)

        // Both of the keys that followed it are bitwise equal here, so the
        // declared tie-break decides and the fully measured target goes first.
        #expect(blind.zeroImputedScore == sighted.zeroImputedScore)
        #expect(blind.priorImputedScore == sighted.priorImputedScore)
        #expect(HivePriorityEngine.ordered([blind, sighted]).first?.module == "z-sighted")
        #expect(HivePriorityEngine.ordered([sighted, blind]).first?.module == "z-sighted")
    }

    /// With the key and the confidence both equal, the module name decides, so
    /// two runs over the same facts return the same order.
    @Test func aCompleteTieIsBrokenDeterministicallyByName() {
        let first = target("a", score: 0.5, confidence: 0.5, weightedTotal: 0.25)
        let second = target("b", score: 0.5, confidence: 0.5, weightedTotal: 0.25)
        #expect(HivePriorityEngine.ordered([second, first]).map(\.module) == ["a", "b"])
    }

    /// A target the scan barely read is not ranked at all - it is an
    /// instrument fault, and the remedy is the probe, not a bee. Asserted on
    /// the ORDER rather than on the numbers behind it, which is the gap that
    /// let the old key run untested for as long as it did.
    @Test func aTargetUnderTheFloorIsNotRankedAtAll() {
        let barelyRead = target("weak", score: 1.0, confidence: 0.2, weightedTotal: 0.2)
        let measured = target("strong", score: 0.6, confidence: 1.0, weightedTotal: 0.6)

        #expect(HivePriorityEngine.ordered([barelyRead, measured]).map(\.module) == ["strong"])

        let queue = HivePriorityEngine.queue(of: [barelyRead, measured])
        #expect(queue.ranked.map(\.target.module) == ["strong"])
        #expect(queue.instrumentFaults.map(\.module) == ["weak"])
    }
}

@Suite("Hive - reservations survive the process that made them")
struct HiveReservationRepairTests {

    @Test func aReservationIsWrittenToTheStateFile() throws {
        let root = temporaryRoot()
        defer { try? FileManager.default.removeItem(at: root) }
        let store = HiveStore(stateRoot: root.path)

        let reservation = HiveReservation(
            taskID: "t", sessionID: "s", day: HiveState.dayKey(), amount: 5, pid: 4242
        )
        #expect(
            store.save(HiveState(policy: .default, tasks: [], reservations: ["t": reservation]))
        )
        // Compared field by field: the ISO8601 encoding the store uses drops
        // sub-second precision, so whole-struct equality would fail on the
        // timestamp while every fact that matters round-tripped correctly.
        let reloaded = store.load().reservations["t"]
        #expect(reloaded?.taskID == "t")
        #expect(reloaded?.sessionID == "s")
        #expect(reloaded?.day == HiveState.dayKey())
        #expect(reloaded?.amount == 5)
        #expect(reloaded?.pid == 4242)
    }

    /// A bee that wrote nothing never ran, and that is the one absence which
    /// may honestly be read as a zero.
    @Test func aBeeThatWroteNothingIsRefundedInFull() {
        #expect(HiveDispatch.repair(.absent) == .refundInFull)
        #expect(HiveDispatch.repair(HiveTranscriptSummary(lines: 0, lastCostUSD: nil)) == .refundInFull)
    }

    /// Real output and no cost line: what it spent is unknown, and unknown is
    /// not zero. This is the case the conservative rule was written for.
    @Test func outputWithoutACostLineKeepsTheReservation() {
        #expect(HiveDispatch.repair(HiveTranscriptSummary(lines: 42, lastCostUSD: nil)) == .keep)
    }

    /// The transcript reported a cost, so the guess is replaced by a reading.
    @Test func aReportedCostIsChargedExactly() {
        #expect(HiveDispatch.repair(HiveTranscriptSummary(lines: 9, lastCostUSD: 0.41)) == .charge(0.41))
        // A negative cost is nonsense; it is clamped rather than trusted.
        #expect(HiveDispatch.repair(HiveTranscriptSummary(lines: 9, lastCostUSD: -1)) == .charge(0))
    }

    /// The reader takes the LAST cost line: a bee that reported twice has
    /// spent the later figure, not the earlier one.
    @Test func theTranscriptReaderTakesTheLastReportedCost() throws {
        let root = temporaryRoot()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: root) }
        let url = root.appendingPathComponent("session.jsonl")

        let lines = [
            #"{"type":"assistant","message":{"content":[{"type":"text","text":"working"}]}}"#,
            #"{"type":"result","subtype":"success","total_cost_usd":0.12}"#,
            "",
            #"{"type":"result","subtype":"success","total_cost_usd":0.37}"#,
        ].joined(separator: "\n")
        try Data(lines.utf8).write(to: url)

        let summary = HiveTranscript.summarise(at: url)
        #expect(summary.lines == 3)
        #expect(summary.lastCostUSD == 0.37)
        #expect(HiveDispatch.repair(summary) == .charge(0.37))
    }

    @Test func anAbsentTranscriptIsAbsentNotEmpty() {
        let summary = HiveTranscript.summarise(
            at: temporaryRoot().appendingPathComponent("nothing.jsonl")
        )
        #expect(summary == .absent)
    }

    /// The arithmetic the repair drives: six bees stopped after three seconds
    /// used to hold $30 against a $25 ceiling until local midnight.
    @Test func sixCancelledBeesNoLongerBlockTheDay() {
        var state = HiveState(policy: .default, tasks: [])
        let day = HiveState.dayKey()
        for _ in 0..<6 { state.record(spend: 5) }
        #expect(state.spent() == 30)

        for _ in 0..<6 {
            guard case .refundInFull = HiveDispatch.repair(.absent) else {
                Issue.record("a bee that wrote nothing must be refunded")
                return
            }
            state.refund(5, forDay: day)
        }
        #expect(state.spent() == 0)
    }
}
