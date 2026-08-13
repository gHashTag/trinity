import Testing
import Foundation
@testable import QueenUILib

@Suite("Hive - priority ranking")
struct HivePriorityTests {

    private func facts(
        _ module: String,
        lines: Int? = 1000,
        todos: Int? = 0,
        churn: Int? = 0,
        tests: Int? = 6,
        status: String? = "active",
        issues: Int? = 0
    ) -> HiveModuleFacts {
        var f = HiveModuleFacts(module: module, path: module, realm: .core)
        f.lines = lines
        f.todos = todos
        f.churn30d = churn
        f.testBlocks = tests
        f.declaredStatus = status
        f.openIssues = issues
        return f
    }

    @Test func ranksTheModuleWithMoreProblemsHigher() {
        let ranked = HivePriorityEngine.rank([
            facts("src/clean", todos: 0, churn: 0, tests: 12, issues: 0),
            facts("src/rotten", todos: 40, churn: 30, tests: 0, issues: 9),
        ])

        #expect(ranked.first?.module == "src/rotten")
        #expect(ranked.last?.module == "src/clean")
        #expect((ranked.first?.score ?? 0) > (ranked.last?.score ?? 1))
    }

    @Test func rankingIsDeterministicForEqualInputs() {
        let input = [facts("src/b"), facts("src/a"), facts("src/c")]
        let first = HivePriorityEngine.rank(input).map(\.module)
        let second = HivePriorityEngine.rank(input).map(\.module)

        #expect(first == second)
        // Equal score and equal confidence must fall back to module name, not
        // to whatever order the filesystem happened to hand over.
        #expect(first == ["src/a", "src/b", "src/c"])
    }

    // MARK: - Absent is not zero

    @Test func unmeasuredSignalIsExcludedFromTheScoreNotCountedAsZero() {
        // Two modules with identical measured evidence. One of them simply
        // could not have its churn read. Their scores must match; only the
        // confidence differs.
        var blind = facts("src/blind", todos: 20, churn: nil, tests: 0, issues: 4)
        blind.unmeasuredReasons[.churn] = "git history unavailable"
        let sighted = facts("src/sighted", todos: 20, churn: 0, tests: 0, issues: 4)

        let ranked = HivePriorityEngine.rank([blind, sighted])
        let blindTarget = try! #require(ranked.first { $0.module == "src/blind" })
        let sightedTarget = try! #require(ranked.first { $0.module == "src/sighted" })

        // The sighted module measured churn as a real zero, which drags its
        // score down. The blind one is not punished for a probe that failed.
        #expect(blindTarget.score > sightedTarget.score)
        #expect(blindTarget.confidence < sightedTarget.confidence)
    }

    @Test func unmeasuredSignalCarriesItsReasonThrough() {
        var f = facts("src/opaque", churn: nil)
        f.unmeasuredReasons[.churn] = "git log exited 128"

        let target = try! #require(HivePriorityEngine.rank([f]).first)
        let churn = try! #require(target.signals.first { $0.kind == .churn })

        #expect(churn.raw.isMeasured == false)
        #expect(churn.normalized.isMeasured == false)
        if case .unmeasured(let why) = churn.raw {
            #expect(why == "git log exited 128")
        } else {
            Issue.record("churn should be unmeasured")
        }
    }

    @Test func confidenceIsTheMeasuredShareOfTotalWeight() {
        let full = facts("src/full")
        let target = try! #require(HivePriorityEngine.rank([full]).first)
        #expect(abs(target.confidence - 1.0) < 0.0001)

        var half = HiveModuleFacts(module: "src/half", path: "src/half", realm: .core)
        half.lines = 500
        half.todos = 5
        // No churn, no tests, no status, no issues.
        let partial = try! #require(HivePriorityEngine.rank([half]).first)
        #expect(partial.confidence < 1.0)
        #expect(partial.confidence > 0.0)
    }

    @Test func aModuleWithNothingMeasuredScoresZeroWithZeroConfidence() {
        let blank = HiveModuleFacts(module: "src/unknown", path: "src/unknown", realm: .core)
        let target = try! #require(HivePriorityEngine.rank([blank]).first)

        #expect(target.score == 0)
        #expect(target.confidence == 0)
        #expect(target.measuredCount == 0)
        // And it must say so rather than presenting a confident zero.
        #expect(target.reason.contains("no positive signal measured"))
    }

    // MARK: - Reason text

    @Test func reasonNamesOnlySignalsItActuallyRead() {
        var f = facts("src/loud", todos: 50, churn: nil, tests: 0, issues: 0)
        f.unmeasuredReasons[.churn] = "git history unavailable"

        let target = try! #require(HivePriorityEngine.rank([f]).first)
        #expect(target.reason.contains("confidence"))
        #expect(!target.reason.contains("Churn"))
    }

    @Test func testGapFallsAsTestDensityRises() {
        let untested = facts("src/untested", tests: 0)
        let tested = facts("src/tested", tests: 60)

        let untestedReading = HivePriorityEngine.rawReadings(for: untested)[.testGap]
        let testedReading = HivePriorityEngine.rawReadings(for: tested)[.testGap]

        #expect((untestedReading?.value ?? 0) == 1.0)
        #expect((testedReading?.value ?? 1) == 0.0)
    }

    @Test func declaredStubCountsAsIncomplete() {
        let stub = HivePriorityEngine.rawReadings(for: facts("src/x", status: "stub"))[.declaredIncomplete]
        let active = HivePriorityEngine.rawReadings(for: facts("src/y", status: "active"))[.declaredIncomplete]

        #expect(stub?.value == 1)
        #expect(active?.value == 0)
    }
}

@Suite("Hive - task synthesis")
struct HiveTaskFactoryTests {

    @Test func taskIDIsStableForTheSameModuleAndWeakness() {
        let a = HiveTaskFactory.taskID(module: "src/tri", kind: .testGap)
        let b = HiveTaskFactory.taskID(module: "src/tri", kind: .testGap)
        let c = HiveTaskFactory.taskID(module: "src/tri", kind: .churn)

        #expect(a == b)
        #expect(a != c)
        #expect(a == "hive-src-tri-testGap")
    }

    @Test func promptForbidsPushingWhenPolicyForbidsIt() {
        var facts = HiveModuleFacts(module: "src/tri", path: "src/tri", realm: .core)
        facts.lines = 1000
        facts.todos = 30
        facts.churn30d = 5
        facts.testBlocks = 0
        facts.declaredStatus = "active"
        facts.openIssues = 2

        let target = try! #require(HivePriorityEngine.rank([facts]).first)
        var policy = HivePolicy.default
        policy.allowPush = false

        let task = try! #require(HiveTaskFactory.makeTask(from: target, policy: policy))
        #expect(task.prompt.contains("Do NOT push"))
        #expect(task.prompt.contains("Never `git add -A`"))
        #expect(task.prompt.contains("is not a zero"))
        #expect(task.state == .pending)
        #expect(task.attempts == 0)
    }

    @Test func promptListsUnmeasuredSignalsAsUnknownNotZero() {
        // Enough of the module is measured to clear the dispatch-confidence
        // floor; churn and open issues are the two probes that failed, and the
        // brief must say so rather than quietly scoring them zero.
        var facts = HiveModuleFacts(module: "src/tri", path: "src/tri", realm: .core)
        facts.lines = 1000
        facts.todos = 30
        facts.testBlocks = 0
        facts.declaredStatus = "active"
        facts.unmeasuredReasons[.churn] = "git history unavailable"
        facts.unmeasuredReasons[.openIssues] = "issues snapshot absent"

        let target = try! #require(HivePriorityEngine.rank([facts]).first)
        let task = try! #require(HiveTaskFactory.makeTask(from: target, policy: .default))

        #expect(task.prompt.contains("NOT MEASURED"))
        #expect(task.prompt.contains("treat these as unknown, not as zero"))
        #expect(task.prompt.contains("git history unavailable"))
    }

    @Test func makeTaskReturnsNilWhenNoSignalDrivesTheScore() {
        let blank = HiveModuleFacts(module: "src/unknown", path: "src/unknown", realm: .core)
        let target = try! #require(HivePriorityEngine.rank([blank]).first)
        #expect(HiveTaskFactory.makeTask(from: target, policy: .default) == nil)
    }
}
