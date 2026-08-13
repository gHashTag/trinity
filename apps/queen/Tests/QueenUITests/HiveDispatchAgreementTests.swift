import Testing
import Foundation
@testable import QueenUILib

/// The screen and the dispatcher must agree on which task is first.
///
/// They did not. The ranked queue was ordered on the prior-imputed key while
/// `HiveDispatch.nextTask` still sorted on `score` - the self-imputing key the
/// ordering work had just replaced - so the bee that actually went out was
/// chosen by the old rule. An adversarial probe over 2000 random scans found
/// the two disagreeing on 26.2% of them, and `nextTask` had no test at all.
///
/// This is the second time the same shape of defect landed here: a fix applied
/// to the quantity that is displayed rather than to the quantity that decides.
@Suite("Hive - the queue and the dispatcher agree")
struct HiveDispatchAgreementTests {

    private func task(
        id: String,
        score: Double,
        dispatchKey: Double?,
        created: TimeInterval = 1_000_000
    ) -> HiveTask {
        var t = HiveTask(
            id: id, title: id, module: id, path: id, realm: "Cockpit",
            signalKind: "testGap", reason: "r", score: score, confidence: 1, prompt: "p"
        )
        t.dispatchKey = dispatchKey
        t.createdAt = Date(timeIntervalSince1970: created)
        return t
    }

    private func context(_ tasks: [HiveTask]) -> HiveDispatchContext {
        var p = HivePolicy.default
        p.enabled = true
        return HiveDispatchContext(
            policy: p, tasks: tasks, liveBees: 0, spentToday: 0,
            spawnsInLastHour: 0, consecutiveFailures: 0,
            auth: .loggedIn(method: "oauth")
        )
    }

    @Test func theDispatcherPicksByTheKeyNotByScore() {
        // The exact shape the probe found: a half-read module whose `score` is
        // higher because it divides by the measured weight only, against a
        // fully-read module that the ranked queue puts first.
        let wellRead = task(id: "well-read", score: 0.55, dispatchKey: 0.55)
        let halfRead = task(id: "half-read", score: 0.60, dispatchKey: 0.39)
        let picked = HiveDispatch.nextTask(in: context([wellRead, halfRead]))
        #expect(picked?.id == "well-read")
    }

    @Test func theTopOfTheRankedQueueIsTheTaskTheDispatcherPicks() {
        let tasks = [
            task(id: "a", score: 0.90, dispatchKey: 0.20),
            task(id: "b", score: 0.10, dispatchKey: 0.80),
            task(id: "c", score: 0.50, dispatchKey: 0.50),
        ]
        let byKey = tasks.sorted { ($0.dispatchKey ?? $0.score) > ($1.dispatchKey ?? $1.score) }
        let picked = HiveDispatch.nextTask(in: context(tasks))
        #expect(picked?.id == byKey.first?.id)
        #expect(picked?.id == "b")
    }

    @Test func aTaskFromAnOlderStateFileFallsBackToScoreForOneCycle() {
        // A task written before dispatchKey existed carries nil. It must still
        // order rather than sort as zero; materialiseTasks refreshes it on the
        // first cycle after launch.
        let legacy = task(id: "legacy", score: 0.70, dispatchKey: nil)
        let fresh = task(id: "fresh", score: 0.10, dispatchKey: 0.30)
        #expect(HiveDispatch.nextTask(in: context([fresh, legacy]))?.id == "legacy")
    }

    @Test func equalKeysStillFallBackToTheOlderTask() {
        let older = task(id: "older", score: 0.1, dispatchKey: 0.5, created: 1)
        let newer = task(id: "newer", score: 0.9, dispatchKey: 0.5, created: 99)
        #expect(HiveDispatch.nextTask(in: context([newer, older]))?.id == "older")
    }

    @Test func theKeyTravelsFromTheTargetOntoTheTask() {
        var facts = HiveModuleFacts(module: "src/tri", path: "src/tri", realm: .core)
        facts.lines = 1000
        facts.todos = 30
        facts.churn30d = 5
        facts.testBlocks = 0
        facts.declaredStatus = "active"
        facts.openIssues = 2
        let target = try! #require(HivePriorityEngine.rank([facts]).first)
        let made = try! #require(HiveTaskFactory.makeTask(from: target, policy: .default))
        // Not recomputed from score and confidence - those cannot reconstruct
        // it, which is why it is carried.
        #expect(made.dispatchKey == target.priorImputedScore)
    }
}

/// The rank is NOT neutral to a probe failure, and that is worth a test of its
/// own rather than a footnote.
///
/// The key is unchanged only when the failed probe's true reading equals the
/// declared prior exactly. Measured end to end by an adversarial review: break
/// one probe on one module of six, change nothing else, and the queue order
/// moves in 46.7% of trials. Anyone reading only the key-neutrality test would
/// conclude the opposite.
@Suite("Hive - a probe failure does move the rank")
struct HiveProbeFailureRankTests {

    private func facts(
        _ module: String,
        todos: Int?, churn: Int?, tests: Int?, issues: Int?
    ) -> HiveModuleFacts {
        var f = HiveModuleFacts(module: module, path: module, realm: .core)
        f.lines = 1000
        f.todos = todos
        f.churn30d = churn
        f.testBlocks = tests
        f.declaredStatus = "active"
        f.openIssues = issues
        return f
    }

    @Test func breakingOneProbeCanReorderTheQueue() {
        // The claim is existential - a probe failure is CAPABLE of moving the
        // rank - so it is tested by search rather than by one guessed pair.
        // My first attempt asserted it on a fixture I had not computed, and the
        // fixture happened not to reorder: the test failed and the code was
        // right, which is the same mistake this suite exists to catch.
        var reorderings = 0
        var trials = 0

        for aTodos in [2, 6, 12] {
            for aTests in [0, 2, 6] {
                for bTodos in [3, 8] {
                    for bChurn in [1, 6] {
                        let alpha = facts("src/alpha", todos: aTodos, churn: 4, tests: aTests, issues: 2)
                        let beta = facts("src/beta", todos: bTodos, churn: bChurn, tests: 2, issues: 2)

                        let before = HivePriorityEngine
                            .ordered(HivePriorityEngine.rank([alpha, beta])).map(\.module)

                        var blind = alpha
                        blind.testBlocks = nil
                        blind.unmeasuredReasons[.testGap] = "test blocks not counted"
                        let after = HivePriorityEngine
                            .ordered(HivePriorityEngine.rank([blind, beta])).map(\.module)

                        trials += 1
                        if before != after { reorderings += 1 }
                    }
                }
            }
        }

        #expect(trials == 36)
        #expect(
            reorderings > 0,
            "breaking one probe must be able to move the rank; found none in \(trials) pairs"
        )
    }

    @Test func theRankMovesEvenWhenTheKeyDoesNot() {
        // The exact case the key-neutrality test covers: the declared prior
        // matches the reading, so the two keys are bit-equal - and the
        // confidence tie-break still demotes the module whose probe failed.
        let read = facts("src/read", todos: 10, churn: 3, tests: 0, issues: 2)
        var unread = facts("src/unread", todos: 10, churn: nil, tests: 0, issues: 2)
        unread.unmeasuredReasons[.churn] = "git history not read"

        let ranked = HivePriorityEngine.rank([read, unread])
        let readTarget = try! #require(ranked.first { $0.module == "src/read" })
        let unreadTarget = try! #require(ranked.first { $0.module == "src/unread" })

        #expect(readTarget.priorImputedScore == unreadTarget.priorImputedScore)
        // Equal keys, and yet an order: the failed probe loses the tie.
        #expect(readTarget.confidence > unreadTarget.confidence)
        #expect(
            HivePriorityEngine.ordered([unreadTarget, readTarget]).first?.module == "src/read"
        )
    }
}
