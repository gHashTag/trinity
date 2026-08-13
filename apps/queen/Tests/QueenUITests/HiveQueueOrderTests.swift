import Testing
import Foundation
@testable import QueenUILib

/// The key the queue is ACTUALLY ordered on.
///
/// This suite exists because the no-imputation invariant was asserted on
/// `score` - the honest number, which nothing sorted by - while the queue was
/// ordered on `zeroImputedScore`, which substitutes zero for every probe that
/// failed. The rule and the sort had no test in common, and the contradiction
/// survived six cycles. Every assertion here is written against
/// `HivePriorityEngine.ordered` or the key it reads, never against a number
/// that merely sits beside it on the screen.
@Suite("Hive - the key the queue is ordered on")
struct HiveQueueOrderTests {

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

    // MARK: - The test that was missing

    @Test func aFailedProbeIsNotScoredAsZeroOnTheKeyTheSortUses() {
        // Two modules, identical on every signal either of them measured. One
        // had its churn probe fail; the other measured churn and it really was
        // zero. The instrument's first rule says these two are not the same
        // reading, so the key the sort uses must not give them the same number.
        var blind = facts("src/blind", todos: 10, churn: nil, tests: 0, issues: 2)
        blind.unmeasuredReasons[.churn] = "git log exited 128"
        let zeroed = facts("src/zeroed", todos: 10, churn: 0, tests: 0, issues: 2)

        let ranked = HivePriorityEngine.rank([blind, zeroed])
        let blindTarget = try! #require(ranked.first { $0.module == "src/blind" })
        let zeroedTarget = try! #require(ranked.first { $0.module == "src/zeroed" })

        // The old key: a failed probe and a measured zero are indistinguishable.
        // Kept as a live assertion so the defect cannot come back unnoticed
        // under a different name.
        #expect(blindTarget.zeroImputedScore == zeroedTarget.zeroImputedScore)

        // The key the sort uses: they are not the same reading.
        #expect(blindTarget.priorImputedScore > zeroedTarget.priorImputedScore)

        // And the order that comes out of the sort, not merely the property.
        let order = HivePriorityEngine.ordered([zeroedTarget, blindTarget]).map(\.module)
        #expect(order == ["src/blind", "src/zeroed"])
    }

    @Test func everySignalDeclaresAPriorStrictlyAboveZero() {
        // A prior of zero is zero-imputation wearing the new key's name. This
        // is the single line that stops the whole design decaying back into
        // the defect it replaced.
        for kind in HiveSignal.Kind.allCases {
            #expect(kind.priorWhenUnread > 0, "\(kind.rawValue) declares a zero prior")
            #expect(kind.priorWhenUnread <= 1, "\(kind.rawValue) declares a prior above full scale")
        }
        #expect(abs(HiveSignal.Kind.totalWeight - 1.0) < 1e-12)
    }

    @Test func theQueueIsOrderedDescendingOnThePriorImputedScore() {
        let ranked = HivePriorityEngine.rank([
            facts("src/a", todos: 30, churn: 12, tests: 0, issues: 5),
            facts("src/b", todos: 2, churn: 1, tests: 20, issues: 0),
            facts("src/c", todos: 14, churn: 4, tests: 3, issues: 2),
            facts("src/d", todos: 0, churn: 0, tests: 40, issues: 0),
        ])
        let keys = ranked.map(\.priorImputedScore)
        #expect(keys == keys.sorted(by: >))
    }

    @Test func theKeyIsUnchangedWhenTheDeclaredPriorMatchesTheReading() {
        // Neutrality OF THE KEY with respect to probe failure. Named narrowly
        // on purpose: an adversarial review measured what the old name implied
        // and found the RANK moves in 46.7% of single-probe failures, because
        // the key is unchanged only when the true reading equals the declared
        // prior exactly - and even then the tie-break reorders the pair. The
        // key is the neutral quantity; the ranking is not, and the test that
        // says so is directly below.
        //
        // Nothing about the module changed here, only whether the scanner
        // managed to read it. churn's
        // declared prior is 0.15 of full scale, and full scale is 20 commits,
        // so a module that really churned 3 times is the module the prior
        // describes. Its key must not move when the probe fails.
        let read = facts("src/read", todos: 10, churn: 3, tests: 0, issues: 2)
        var unread = facts("src/unread", todos: 10, churn: nil, tests: 0, issues: 2)
        unread.unmeasuredReasons[.churn] = "git history not read"

        let ranked = HivePriorityEngine.rank([read, unread])
        let readTarget = try! #require(ranked.first { $0.module == "src/read" })
        let unreadTarget = try! #require(ranked.first { $0.module == "src/unread" })

        // Exact, not approximate. Two mathematically equal keys that differ in
        // the last bit skip the declared tie-breaks, and the target with the
        // FAILED probe lands above the measured one for a reason nobody wrote
        // down - which is how the previous key was found to be wrong.
        #expect(readTarget.priorImputedScore == unreadTarget.priorImputedScore)

        // Equal keys, so the declared tie-break decides: the better-measured
        // module goes first.
        #expect(HivePriorityEngine.ordered([unreadTarget, readTarget]).map(\.module)
            == ["src/read", "src/unread"])
    }

    @Test func theKeyIsNeitherOfTheTwoRejectedCandidates() {
        // A set built so all three candidate keys disagree. `score` divides by
        // the measured weight only and hands the top to the least-known
        // module; `zeroImputedScore` reads every failed probe as health.
        var thin = HiveModuleFacts(module: "src/thin", path: "src/thin", realm: .core)
        thin.lines = 900
        thin.todos = 18
        thin.unmeasuredReasons[.churn] = "git log exited 128"
        thin.unmeasuredReasons[.testGap] = "test blocks not counted"
        thin.unmeasuredReasons[.declaredIncomplete] = "no cell.tri"
        thin.unmeasuredReasons[.openIssues] = "issues snapshot absent"

        let solid = facts("src/solid", todos: 12, churn: 6, tests: 1, issues: 3)
        let ranked = HivePriorityEngine.rank([thin, solid])

        let thinTarget = try! #require(ranked.first { $0.module == "src/thin" })
        let solidTarget = try! #require(ranked.first { $0.module == "src/solid" })

        // score rewards ignorance...
        #expect(thinTarget.score > solidTarget.score)
        // ...zeroImputedScore punishes it...
        #expect(thinTarget.zeroImputedScore < solidTarget.zeroImputedScore)
        // ...and the key the queue uses is neither: it is the declared prior
        // that decides, and here it leaves the fully measured module on top.
        #expect(thinTarget.priorImputedScore < solidTarget.priorImputedScore)
    }

    /// One signal, already normalised. `nil` means its probe failed.
    private func signal(_ kind: HiveSignal.Kind, _ value: Double?) -> HiveSignal {
        let state: HiveSignalState = value.map { .measured($0) } ?? .unmeasured("probe failed")
        return HiveSignal(kind: kind, raw: state, normalized: state)
    }

    /// A target built from normalised readings directly, with `score`,
    /// `confidence` and `weightedTotal` derived the way the engine derives
    /// them. Some readings cannot be produced from facts - `sizeRisk` is
    /// measured whenever the module has a line count, and `todoDensity` needs
    /// that same line count - so the sharpest cases have to be stated here.
    private func handBuilt(_ module: String, _ signals: [HiveSignal]) -> HiveTarget {
        var weighted = 0.0
        var measuredWeight = 0.0
        for signal in signals {
            guard let value = signal.normalized.value else { continue }
            weighted += value * signal.kind.weight
            measuredWeight += signal.kind.weight
        }
        return HiveTarget(
            module: module,
            path: module,
            realm: .core,
            signals: signals,
            score: measuredWeight > 0 ? weighted / measuredWeight : 0,
            confidence: measuredWeight / HiveSignal.Kind.totalWeight,
            weightedTotal: weighted
        )
    }

    private func uniformlyMeasured(_ module: String, at value: Double) -> HiveTarget {
        handBuilt(module, HiveSignal.Kind.allCases.map { signal($0, value) })
    }

    /// Read on 58% of the weight and genuinely bad there. Above the confidence
    /// floor, so it is ranked rather than gated.
    private func partlyRead(_ module: String) -> HiveTarget {
        handBuilt(module, [
            signal(.todoDensity, 0.5),
            signal(.churn, nil),
            signal(.testGap, 1.0),
            signal(.sizeRisk, nil),
            signal(.declaredIncomplete, nil),
            signal(.openIssues, 0.5),
        ])
    }

    /// The three candidate keys produce three different orders on one set, and
    /// the queue follows exactly one of them.
    @Test func theQueueFollowsThePriorImputedKeyAndNeitherOfTheOthers() {
        let high = uniformlyMeasured("a-high", at: 0.55)
        let low = uniformlyMeasured("b-low", at: 0.42)
        let partial = partlyRead("c-partial")
        let all = [low, partial, high]

        // What the queue actually does.
        #expect(HivePriorityEngine.ordered(all).map(\.module)
            == ["a-high", "c-partial", "b-low"])

        // `score` divides by the measured weight only, so the least-known
        // module goes to the top.
        #expect(all.sorted { $0.score > $1.score }.map(\.module)
            == ["c-partial", "a-high", "b-low"])

        // `zeroImputedScore` reads three failed probes as three zeroes, so the
        // same module falls to the bottom.
        #expect(all.sorted { $0.zeroImputedScore > $1.zeroImputedScore }.map(\.module)
            == ["a-high", "b-low", "c-partial"])
    }

    // MARK: - The gate

    @Test func aTargetBelowTheConfidenceFloorLeavesTheRankedQueue() {
        var thin = HiveModuleFacts(module: "src/thin", path: "src/thin", realm: .core)
        thin.churn30d = 5
        let solid = facts("src/solid", todos: 12, churn: 6, tests: 1, issues: 3)

        let queue = HivePriorityEngine.queue([thin, solid])

        #expect(queue.ranked.map(\.target.module) == ["src/solid"])
        #expect(queue.instrumentFaults.map(\.module) == ["src/thin"])
        // It is not dropped: the operator has to see that the instrument, not
        // the module, is what needs work.
        #expect(queue.instrumentFaults.first?.confidence ?? 1
            < HiveInvariants.minimumDispatchConfidence)
    }

    @Test func anInstrumentFaultNamesTheProbesThatFailed() {
        var thin = HiveModuleFacts(module: "src/thin", path: "src/thin", realm: .core)
        thin.churn30d = 5
        thin.unmeasuredReasons[.testGap] = "test blocks not counted"

        let queue = HivePriorityEngine.queue([thin])
        let fault = try! #require(queue.instrumentFaults.first)
        #expect(fault.unreadProbeDetail.contains("test blocks not counted"))
        #expect(fault.unreadProbeDetail.contains("Test gap"))
        #expect(queue.ranked.isEmpty)
    }

    @Test func rankStillReturnsEveryTargetWithTheFaultsLast() {
        var thin = HiveModuleFacts(module: "src/aaa-thin", path: "src/aaa-thin", realm: .core)
        thin.churn30d = 5
        let solid = facts("src/zzz-solid", todos: 12, churn: 6, tests: 1, issues: 3)

        // Alphabetically the fault sorts first; it must still come last,
        // because it is not ranked at all.
        let ranked = HivePriorityEngine.rank([thin, solid]).map(\.module)
        #expect(ranked == ["src/zzz-solid", "src/aaa-thin"])
    }

    // MARK: - What the evidence settles

    @Test func theIntervalBracketsTheKeyAndItsLowerEndIsTheZeroImputedScore() {
        var partial = HiveModuleFacts(module: "src/partial", path: "src/partial", realm: .core)
        partial.lines = 800
        partial.todos = 12
        partial.testBlocks = 0
        partial.churn30d = 4
        partial.unmeasuredReasons[.openIssues] = "issues snapshot absent"
        partial.unmeasuredReasons[.declaredIncomplete] = "no cell.tri"

        let target = try! #require(HivePriorityEngine.rank([partial]).first)
        #expect(target.lowerBound == target.zeroImputedScore)
        #expect(target.lowerBound <= target.priorImputedScore)
        #expect(target.priorImputedScore <= target.upperBound)
        let width: Double = target.upperBound - target.lowerBound
        let unread: Double = 1 - target.confidence
        #expect(abs(width - unread) < 1e-12)
    }

    @Test func aFullyMeasuredTargetHasAPointInterval() {
        let target = try! #require(HivePriorityEngine.rank([facts("src/full", todos: 5)]).first)
        #expect(target.confidence == 1.0)
        #expect(target.lowerBound == target.upperBound)
        #expect(target.priorImputedScore == target.lowerBound)
    }

    /// Measured on four of six signals: churn and open issues went unread, so
    /// 38% of the weight is left open and the interval is that wide.
    private func halfReadFacts() -> HiveModuleFacts {
        var half = HiveModuleFacts(module: "src/half", path: "src/half", realm: .core)
        half.lines = 1000
        half.todos = 8
        half.testBlocks = 3
        half.declaredStatus = "active"
        half.unmeasuredReasons[.churn] = "git log exited 128"
        half.unmeasuredReasons[.openIssues] = "issues snapshot absent"
        return half
    }

    @Test func neighboursWhoseIntervalsOverlapAreMarkedNotSettled() {
        // A fully measured module and a half-read one whose unread weight is
        // wide enough to reach across the gap.
        let half = halfReadFacts()
        let solid = facts("src/solid", todos: 12, churn: 6, tests: 1, issues: 3)

        let queue = HivePriorityEngine.queue([half, solid])
        #expect(queue.ranked.count == 2)
        // The first row has nothing above it, so it is settled by definition.
        #expect(queue.ranked.first?.separation == .settled)

        let second = try! #require(queue.ranked.last)
        guard case .notSettled = second.separation else {
            Issue.record("an overlapping pair must be reported as unsettled, not silently ordered")
            return
        }
        #expect(queue.hasUnsettledPairs)
    }

    @Test func twoFullyMeasuredNeighboursAreSettledByTheEvidence() {
        let worse = facts("src/worse", todos: 40, churn: 18, tests: 0, issues: 8)
        let better = facts("src/better", todos: 0, churn: 0, tests: 30, issues: 0)

        let queue = HivePriorityEngine.queue([better, worse])
        #expect(queue.ranked.map(\.target.module) == ["src/worse", "src/better"])
        // Both intervals are points, and the points differ.
        #expect(queue.ranked.allSatisfy { $0.separation == .settled })
        #expect(queue.hasUnsettledPairs == false)
    }

    @Test func theBreakEvenIsTheReadingThatWouldDrawTheLowerRowLevel() {
        let half = halfReadFacts()
        let solid = facts("src/solid", todos: 12, churn: 6, tests: 1, issues: 3)

        let queue = HivePriorityEngine.queue([half, solid])
        let lower = try! #require(queue.ranked.last)
        guard case .notSettled(let breakEven) = lower.separation,
              let breakEven else {
            Issue.record("this pair overlaps and the lower row has unread weight")
            return
        }

        // Substituting the break-even reading for every unread signal must
        // reproduce the key of the row above, to arithmetic precision.
        let above: HiveTarget = try! #require(queue.ranked.first).target
        let unreadShare: Double = lower.target.unmeasuredShare
        let rebuilt: Double = lower.target.lowerBound + breakEven.normalized * unreadShare
        let drift: Double = abs(rebuilt - above.priorImputedScore)
        #expect(drift < 1e-9)

        // And it is reported in the unread signals' own units, not as a bare
        // fraction: churn's full scale is 20 commits.
        let churn = try! #require(breakEven.readings.first { $0.kind == .churn })
        let expectedCommits: Double = breakEven.normalized * 20
        #expect(abs(churn.inOwnUnits - expectedCommits) < 1e-9)

        let reported: [String] = breakEven.readings.map(\.kind.rawValue).sorted()
        #expect(reported == ["churn", "openIssues"])
        #expect(breakEven.summary.contains("of 20"))
    }

    @Test func anUnsettledPairWhoseLowerRowIsFullyMeasuredReportsNoBreakEven() {
        // The doubt belongs to the row ABOVE: the lower row has nothing left
        // unread, so no reading of its own could flip the pair, and inventing
        // a number for it would be the imputation this whole wave removed.
        let half = halfReadFacts()
        let measured = facts("src/measured", todos: 6, churn: 2, tests: 4, issues: 3)

        let queue = HivePriorityEngine.queue([measured, half])
        #expect(queue.ranked.map(\.target.module) == ["src/half", "src/measured"])

        let lower = try! #require(queue.ranked.last)
        #expect(lower.target.confidence == 1.0)
        guard case .notSettled(let breakEven) = lower.separation else {
            Issue.record("the row above has unread weight reaching below this one")
            return
        }
        #expect(breakEven == nil)
    }

    // MARK: - Determinism

    @Test func identicalFactsGiveAnIdenticalQueue() {
        var thin = HiveModuleFacts(module: "src/thin", path: "src/thin", realm: .core)
        thin.churn30d = 5
        let input = [
            facts("src/b", todos: 12, churn: 6, tests: 1, issues: 3),
            thin,
            facts("src/a", todos: 12, churn: 6, tests: 1, issues: 3),
        ]
        #expect(HivePriorityEngine.queue(input) == HivePriorityEngine.queue(input))
        // Equal keys and equal confidence fall back to the module name.
        #expect(HivePriorityEngine.queue(input).ranked.map(\.target.module) == ["src/a", "src/b"])
    }

    // MARK: - What the operator is told

    @Test func theOrderingSentenceNamesTheAssumptionItMakes() {
        let sentence = HiveQueue.orderingSentence
        #expect(sentence.contains("never zero"))
        #expect(sentence.contains("not settled"))
        #expect(sentence.allSatisfy { $0.isASCII })
    }
}
