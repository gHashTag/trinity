import Testing
import Foundation
@testable import QueenUILib

// Everything here is about a reading outliving the thing it measured: a verdict
// that survives into the next attempt, a spend ledger that only ever hears from
// bees that lived, a score computed against a set that has since changed, an
// audit log that grows for ever.

@Suite("Hive - evidence currency")
struct HiveEvidenceCurrencyTests {

    @Test func aMatchingCommitIsCurrent() {
        #expect(HiveVerifier.evidenceState(verifiedAt: "abc123", currentHead: "abc123") == .current)
    }

    @Test func aDifferentCommitIsStaleAndSaysWhatItMeasured() {
        let state = HiveVerifier.evidenceState(verifiedAt: "abc123", currentHead: "def456")
        #expect(state == .stale(measuredAt: "abc123"))
        #expect(state.label == "STALE")
        #expect(!state.isCurrent)
    }

    @Test func noRecordedCommitIsItsOwnState() {
        #expect(HiveVerifier.evidenceState(verifiedAt: nil, currentHead: "abc123") == .unrecorded)
        #expect(HiveVerifier.evidenceState(verifiedAt: "", currentHead: "abc123") == .unrecorded)
    }

    @Test func anUnreadableHeadIsUnknownNeverCurrent() {
        let state = HiveVerifier.evidenceState(verifiedAt: "abc123", currentHead: nil)
        #expect(!state.isCurrent)
        if case .unknown = state {} else { Issue.record("expected .unknown, got \(state)") }
    }

    // MARK: - A verdict may not outlive its attempt

    @Test func clearingAVerdictErasesEveryTraceOfIt() {
        var task = HiveTask(
            id: "t", title: "t", module: "m", path: "m", realm: "Core",
            signalKind: "testGap", reason: "r", score: 1, confidence: 1, prompt: "p"
        )
        task.verification = "VERIFIED: Test run with 242 tests passed"
        task.verified = true
        task.verifiedAtCommit = "abc123"
        task.verifiedAt = Date()

        task.clearVerdict()

        #expect(task.verification == nil)
        #expect(task.verified == nil)
        #expect(task.verifiedAtCommit == nil)
        #expect(task.verifiedAt == nil)
    }

    @Test func anOlderStateFileWithoutTheEvidenceFieldsStillLoads() {
        // The whole point of decoding these optionally: a hive.json written
        // before the fields existed must keep loading rather than throwing and
        // handing back an empty task list.
        let json = """
        {"id":"t","title":"t","module":"m","state":"review","attempts":1,"verified":true}
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let task = try! decoder.decode(HiveTask.self, from: Data(json.utf8))

        #expect(task.id == "t")
        #expect(task.verified == true)
        #expect(task.verifiedAtCommit == nil)
        #expect(task.lastDispatchAt == nil)
    }

    @Test func anOlderPolicyMissingKeysKeepsTheSettingsItDoesCarry() {
        // The synthesised decoder rejects a file that predates any one key and
        // the store falls back to a default policy, which reads exactly like
        // the operator never configured anything.
        let json = #"{"enabled":true,"maxConcurrentBees":5}"#
        let policy = try! JSONDecoder().decode(HivePolicy.self, from: Data(json.utf8))

        #expect(policy.enabled)
        #expect(policy.maxConcurrentBees == 5)
        #expect(policy.dailyBudgetUSD == HivePolicy.default.dailyBudgetUSD)
        #expect(policy.verifyBeforeReview == HivePolicy.default.verifyBeforeReview)
    }
}

@Suite("Hive - spend is charged for what was started")
struct HiveSpendReservationTests {

    @Test func aRefundNeverDrivesADayBelowZero() {
        var state = HiveState()
        state.record(spend: 5)
        state.refund(9, forDay: HiveState.dayKey())
        #expect(state.spent() == 0)
    }

    @Test func aRefundLandsOnTheDayItWasChargedTo() {
        var state = HiveState()
        let yesterday = Date().addingTimeInterval(-86_400)
        state.record(spend: 5, on: yesterday)
        state.record(spend: 5)

        state.refund(4, forDay: HiveState.dayKey(yesterday))

        #expect(abs(state.spent(on: yesterday) - 1.0) < 0.0001)
        #expect(abs(state.spent() - 5.0) < 0.0001)
    }

    @Test func reserveThenReconcileLeavesOnlyWhatWasReported() {
        // The whole ledger shape: charge the per-bee budget at dispatch, then
        // settle downward when the bee says what it cost.
        var state = HiveState()
        state.record(spend: 5.0)
        #expect(abs(state.spent() - 5.0) < 0.0001)

        state.refund(5.0 - 0.42, forDay: HiveState.dayKey())
        #expect(abs(state.spent() - 0.42) < 0.0001)
    }

    @Test func twoHungBeesAreChargedTheFullBudgetEach() {
        // The failing execution this exists for: two bees hang, the wall-clock
        // guard kills both, neither reports a cost. Debiting only what a bee
        // reports leaves the ledger at zero while the provider bills $10.
        var state = HiveState()
        state.record(spend: 5.0)
        state.record(spend: 5.0)
        // Neither bee reported anything, so nothing is refunded.
        #expect(abs(state.spent() - 10.0) < 0.0001)
        #expect(state.spent() > HivePolicy.default.dailyBudgetUSD / 5)
    }

    @Test func fortyEightHungBeesTripTheCeilingTheyUsedToWalkPast() {
        var state = HiveState()
        for _ in 0..<48 { state.record(spend: 5.0) }
        #expect(state.spent() == 240)

        var policy = HivePolicy.default
        policy.enabled = true
        let decision = HiveDispatch.decide(
            HiveDispatchContext(
                policy: policy, tasks: [], liveBees: 0, spentToday: state.spent(),
                spawnsInLastHour: 0, consecutiveFailures: 0, auth: .loggedIn(method: "oauth")
            )
        )
        #expect(decision.isBlocked)
    }
}

@Suite("Hive - a crash may not consume a task's last attempt silently")
struct HiveInterruptedTaskTests {

    private func temporaryStore() -> HiveStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-\(UUID().uuidString)")
        return HiveStore(stateRoot: root.path)
    }

    private func runningTask(attempts: Int) -> HiveTask {
        var task = HiveTask(
            id: "t", title: "t", module: "m", path: "m", realm: "Core",
            signalKind: "testGap", reason: "r", score: 1, confidence: 1, prompt: "p"
        )
        task.state = .running
        task.attempts = attempts
        return task
    }

    @Test func aCrashWithAttemptsLeftRequeuesTheTask() {
        let store = temporaryStore()
        store.save(HiveState(policy: .default, tasks: [runningTask(attempts: 1)]))
        let loaded = store.load()
        #expect(loaded.tasks.first?.state == .pending)
    }

    @Test func aCrashOnTheLastAttemptGoesToxicRatherThanVanishing() {
        // Requeued as pending with attempts already at the budget, the task is
        // schedulable, excluded for ever by the attempt filter, never reaches
        // review, and offers the operator no button at all. It is non-terminal
        // and invisible - so it is made terminal, with the reason recorded.
        let store = temporaryStore()
        var policy = HivePolicy.default
        policy.maxAttemptsPerTask = 3
        store.save(HiveState(policy: policy, tasks: [runningTask(attempts: 3)]))

        let loaded = store.load()
        #expect(loaded.tasks.first?.state == .toxic)
        #expect(loaded.tasks.first?.isTerminal == true)
        #expect(loaded.tasks.first?.lastError?.contains("last attempt") == true)
    }
}

@Suite("Hive - the audit log is bounded")
struct HiveEventLogRetentionTests {

    private func temporaryStore() -> HiveStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-\(UUID().uuidString)")
        return HiveStore(stateRoot: root.path)
    }

    @Test func aSmallLogIsLeftAlone() {
        let store = temporaryStore()
        store.append(HiveEvent(kind: "hive_blocked", detail: "one"))
        #expect(store.rotateEventsIfNeeded() == false)
        #expect(store.recentEvents(limit: 10).count == 1)
    }

    @Test func anOversizedLogIsTruncatedFromTheFrontAndKeepsTheNewest() throws {
        let store = temporaryStore()
        store.append(HiveEvent(kind: "seed", detail: "seed"))

        // One padded line per record, over the ceiling, written directly so the
        // test does not depend on how large one real event happens to be.
        let padding = String(repeating: "x", count: 4_000)
        var text = ""
        for index in 0..<800 {
            text += #"{"id":"\#(UUID().uuidString)","timestamp":"2026-08-13T00:00:00Z","kind":"pad\#(index)","detail":"\#(padding)"}"# + "\n"
        }
        try text.write(to: store.eventsURL, atomically: true, encoding: .utf8)
        #expect((try Data(contentsOf: store.eventsURL)).count > HiveStore.maxEventsFileBytes)

        store.append(HiveEvent(kind: "newest", detail: "newest"))

        let size = (try Data(contentsOf: store.eventsURL)).count
        #expect(size <= HiveStore.maxEventsFileBytes)
        #expect(store.recentEvents(limit: 1).first?.kind == "newest")
    }

    @Test func recentEventsReadsTheTailNotTheWholeFile() throws {
        let store = temporaryStore()
        for index in 0..<200 {
            store.append(HiveEvent(kind: "e\(index)", detail: String(repeating: "y", count: 200)))
        }
        let events = store.recentEvents(limit: 5)
        #expect(events.count == 5)
        #expect(events.first?.kind == "e199")
        #expect(events.last?.kind == "e195")
    }

    @Test func tailTextOfAnAbsentFileIsNilNotEmpty() {
        let missing = FileManager.default.temporaryDirectory
            .appendingPathComponent("nope-\(UUID().uuidString).jsonl")
        #expect(HiveStore.tailText(of: missing, lines: 10) == nil)
    }

    @Test func tailTextSpansChunkBoundaries() throws {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("tail-\(UUID().uuidString).jsonl")
        defer { try? FileManager.default.removeItem(at: url) }
        let lines = (0..<50).map { "line-\($0)" }.joined(separator: "\n") + "\n"
        try lines.write(to: url, atomically: true, encoding: .utf8)

        // A chunk far smaller than one line forces the backwards read to make
        // several passes, which is where an off-by-one loses records.
        let tail = try #require(HiveStore.tailText(of: url, lines: 3, chunkSize: 8))
        #expect(tail.contains("line-49"))
        #expect(tail.contains("line-47"))
    }
}

@Suite("Hive - scanning excludes what nobody wrote")
struct HiveScannerExclusionTests {

    @Test func generatedAndVendoredTreesAreNotThisProjectsSource() {
        let base = "/repo/src/tri/"
        #expect(HiveRepoScanner.isExcluded(URL(fileURLWithPath: "/repo/src/tri/generated/x.zig"), relativeTo: base))
        #expect(HiveRepoScanner.isExcluded(URL(fileURLWithPath: "/repo/src/tri/vendor/dep/y.rs"), relativeTo: base))
        #expect(!HiveRepoScanner.isExcluded(URL(fileURLWithPath: "/repo/src/tri/real.zig"), relativeTo: base))
    }

    @Test func aPathOutsideTheBaseIsNotJudgedAtAll() {
        #expect(!HiveRepoScanner.isExcluded(URL(fileURLWithPath: "/elsewhere/generated/x.zig"), relativeTo: "/repo/"))
    }

    @Test func measuringAModuleSkipsItsGeneratedSubtree() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("hive-excl-\(UUID().uuidString)")
        try fm.createDirectory(at: root.appendingPathComponent("generated"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try "// TODO: real\nlet a = 1\n".write(
            to: root.appendingPathComponent("real.swift"), atomically: true, encoding: .utf8
        )
        try (0..<50).map { "// TODO: machine \($0)" }.joined(separator: "\n").write(
            to: root.appendingPathComponent("generated/machine.swift"), atomically: true, encoding: .utf8
        )

        let counts = HiveRepoScanner(projectRoot: root.path).measureContent(at: root.path)
        #expect(counts.lines == 2)
        #expect(counts.todos == 1)
    }

    // MARK: - Tokenised attribution

    @Test func identifiersAreWholeTokensNotSubstrings() {
        let tokens = HiveRepoScanner.identifiers(in: "let x = ChatMessageStore(id: some_name)")
        #expect(tokens.contains("ChatMessageStore"))
        #expect(tokens.contains("some_name"))
        #expect(!tokens.contains("ChatMessage"))
    }

    @Test func identifiersHandleAFileWithNoTrailingSeparator() {
        #expect(HiveRepoScanner.identifiers(in: "HiveOrchestrator").contains("HiveOrchestrator"))
        #expect(HiveRepoScanner.identifiers(in: "").isEmpty)
    }

    @Test func aTestFileNamingALongerTypeDoesNotCreditTheShorterOne() throws {
        // Substring matching credited `HiveStore` to any file that mentioned
        // `HiveStoreTests`, and `ChatMessage` to any file naming
        // `ChatMessageStore`. Whole-token matching is the correct rule and is
        // also what made the scan fast enough to run every cycle.
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("hive-tok-\(UUID().uuidString)")
        let moduleRoot = root.appendingPathComponent("QueenUI")
        let testsRoot = root.appendingPathComponent("Tests")
        try fm.createDirectory(at: moduleRoot.appendingPathComponent("Hive"), withIntermediateDirectories: true)
        try fm.createDirectory(at: moduleRoot.appendingPathComponent("Chat"), withIntermediateDirectories: true)
        try fm.createDirectory(at: testsRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try "struct HiveStore {}".write(
            to: moduleRoot.appendingPathComponent("Hive/HiveStore.swift"), atomically: true, encoding: .utf8
        )
        try "struct HiveStoreTests {}".write(
            to: moduleRoot.appendingPathComponent("Chat/HiveStoreTests.swift"), atomically: true, encoding: .utf8
        )
        try """
        @Test func a() { _ = HiveStoreTests.self }
        @Test func b() { _ = HiveStoreTests.self }
        """.write(to: testsRoot.appendingPathComponent("T.swift"), atomically: true, encoding: .utf8)

        let counts = HiveRepoScanner(projectRoot: root.path).attributeExternalTests(
            testsRoot: testsRoot.path, moduleRoot: moduleRoot.path, modulePrefix: "QueenUI"
        )
        #expect(counts["QueenUI/Chat"] == 2)
        #expect(counts["QueenUI/Hive"] == nil)
    }
}

@Suite("Hive - a score is a property of the module")
struct HiveScoreStabilityTests {

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

    @Test func removingAThirdModuleDoesNotReorderTheOtherTwo() {
        // Independence of irrelevant alternatives. Under set-relative
        // normalisation, deleting the module that happened to hold a column's
        // maximum rewrote every other module's score in that column: one
        // removal moved a module from fifth to second without a line changing
        // anywhere in it.
        let a = facts("src/a", todos: 4, churn: 3, tests: 2, issues: 1)
        let b = facts("src/b", todos: 2, churn: 1, tests: 5, issues: 0)
        let peak = facts("src/peak", todos: 60, churn: 90, tests: 0, issues: 40)

        let withPeak = HivePriorityEngine.rank([a, b, peak])
        let without = HivePriorityEngine.rank([a, b])

        for module in ["src/a", "src/b"] {
            let before = try! #require(withPeak.first { $0.module == module })
            let after = try! #require(without.first { $0.module == module })
            #expect(abs(before.score - after.score) < 1e-12)
        }
        #expect(withPeak.map(\.module).filter { $0 != "src/peak" } == without.map(\.module))
    }

    @Test func aFailedProbeOnOneModuleDoesNotRewriteAnothersScore() {
        let holder = facts("src/holder", churn: 100)
        let other = facts("src/other", churn: 10)

        let before = try! #require(HivePriorityEngine.rank([holder, other]).first { $0.module == "src/other" })

        var blinded = holder
        blinded.churn30d = nil
        blinded.unmeasuredReasons[.churn] = "git log exited 128"
        let after = try! #require(HivePriorityEngine.rank([blinded, other]).first { $0.module == "src/other" })

        #expect(abs(before.score - after.score) < 1e-12)
        #expect(abs(before.confidence - after.confidence) < 1e-12)
    }

    @Test func aScoreComputedInOneCycleIsComparableWithOneComputedInAnother() {
        // Same module, same facts, scanned beside a quiet set and then beside a
        // busy one. A stored score is only meaningful if these agree.
        let subject = facts("src/subject", todos: 10, churn: 5, tests: 1, issues: 2)
        let quiet = [subject, facts("src/quiet", churn: 1)]
        let busy = [subject, facts("src/busy", todos: 300, churn: 400, issues: 90)]

        let inQuiet = try! #require(HivePriorityEngine.rank(quiet).first { $0.module == "src/subject" })
        let inBusy = try! #require(HivePriorityEngine.rank(busy).first { $0.module == "src/subject" })
        #expect(abs(inQuiet.score - inBusy.score) < 1e-12)
    }

    @Test func testGapKeepsItsAbsoluteCalibration() {
        // testGap is the one signal that already answers "is this bad in
        // itself". Dividing it by the set maximum meant its 6-blocks-per-kLOC
        // anchor survived only when some module in the scan had zero tests: one
        // `func test` line in a 53-line module moved two other modules' scores.
        let tested = facts("src/tested", tests: 3)     // density 3/kLOC -> gap 0.5
        let untested = facts("src/untested", tests: 0) // gap 1.0

        let alone = try! #require(HivePriorityEngine.rank([tested]).first)
        let beside = try! #require(HivePriorityEngine.rank([tested, untested]).first { $0.module == "src/tested" })

        let gapAlone = try! #require(alone.signals.first { $0.kind == .testGap }?.normalized.value)
        let gapBeside = try! #require(beside.signals.first { $0.kind == .testGap }?.normalized.value)
        #expect(abs(gapAlone - 0.5) < 1e-12)
        #expect(abs(gapAlone - gapBeside) < 1e-12)
    }

    @Test func thinEvidenceCannotBuyAPlaceAtTheTopOfTheQueue() {
        // A fully scanned module with one signal at full scale, against a
        // barely scanned one whose two readings are also at full scale. Ranked
        // on the raw score the second wins outright, because dividing by a
        // measured weight of 0.38 counts each surviving signal 2.3x.
        var thin = HiveModuleFacts(module: "src/thin", path: "src/thin", realm: .core)
        thin.churn30d = 40
        thin.openIssues = 20
        for kind in [HiveSignal.Kind.todoDensity, .testGap, .sizeRisk, .declaredIncomplete] {
            thin.unmeasuredReasons[kind] = "not read"
        }
        let full = facts("src/full", todos: 0, churn: 40, tests: 6, status: "active", issues: 20)

        let ranked = HivePriorityEngine.rank([thin, full])
        let thinTarget = try! #require(ranked.first { $0.module == "src/thin" })
        let fullTarget = try! #require(ranked.first { $0.module == "src/full" })

        #expect(thinTarget.score > fullTarget.score)
        #expect(thinTarget.zeroImputedScore < fullTarget.zeroImputedScore)
        #expect(ranked.first?.module == "src/full")
    }

    @Test func aThinlyMeasuredTargetIsDeclinedWithAReasonNotSilentlyDropped() {
        var thin = HiveModuleFacts(module: "src/thin", path: "src/thin", realm: .core)
        thin.lines = 1000
        thin.todos = 40
        for kind in [HiveSignal.Kind.churn, .testGap, .declaredIncomplete, .openIssues] {
            thin.unmeasuredReasons[kind] = "not read"
        }
        let target = try! #require(HivePriorityEngine.rank([thin]).first)

        #expect(target.confidence < HiveInvariants.minimumDispatchConfidence)
        let why = try! #require(HiveTaskFactory.rejection(for: target))
        #expect(why.contains("below the 50% floor"))
        #expect(HiveTaskFactory.makeTask(from: target, policy: .default) == nil)
    }

    @Test func aWellMeasuredTargetIsNotDeclined() {
        var full = HiveModuleFacts(module: "src/full", path: "src/full", realm: .core)
        full.lines = 1000
        full.todos = 40
        full.churn30d = 12
        full.testBlocks = 0
        full.declaredStatus = "active"
        full.openIssues = 3

        let target = try! #require(HivePriorityEngine.rank([full]).first)
        #expect(HiveTaskFactory.rejection(for: target) == nil)
        #expect(HiveTaskFactory.makeTask(from: target, policy: .default) != nil)
    }

    @Test func theBriefTellsTheBeeNotToOptimiseTheSignalThatSelectedIt() {
        var full = HiveModuleFacts(module: "src/full", path: "src/full", realm: .core)
        full.lines = 1000
        full.todos = 40
        full.churn30d = 12
        full.testBlocks = 0
        full.declaredStatus = "active"
        full.openIssues = 3

        let target = try! #require(HivePriorityEngine.rank([full]).first)
        let task = try! #require(HiveTaskFactory.makeTask(from: target, policy: .default))
        #expect(task.prompt.contains("Do NOT optimise the signal that selected this task"))
        #expect(task.prompt.contains("Fix the underlying weakness or report that there is none"))
    }
}
