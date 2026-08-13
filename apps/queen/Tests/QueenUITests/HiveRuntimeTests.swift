import Testing
import Foundation
@testable import QueenUILib

@Suite("Hive - guardrails")
struct HiveGuardrailTests {

    @Test func policySanitizationClampsHostileValues() {
        var policy = HivePolicy.default
        policy.maxConcurrentBees = 500
        policy.cycleIntervalSeconds = 0
        policy.maxBeesPerHour = -3
        policy.maxBudgetUSDPerBee = 10_000
        // Raised so this case exercises the absolute per-bee cap rather than
        // the daily ceiling, which is asserted separately in HiveBudgetTests.
        policy.dailyBudgetUSD = 500

        let clean = policy.sanitized()
        #expect(clean.maxConcurrentBees == 8)
        #expect(clean.cycleIntervalSeconds == 30)
        #expect(clean.maxBeesPerHour == 1)
        #expect(clean.maxBudgetUSDPerBee == 100)
    }

    @Test func rateLimiterCountsOnlyTheLastHour() {
        var limiter = HiveRateLimiter()
        let now = Date()
        limiter.record(now.addingTimeInterval(-7200))
        limiter.record(now.addingTimeInterval(-1800))
        limiter.record(now.addingTimeInterval(-60))

        #expect(limiter.spawnsInLastHour(now) == 2)
        #expect(limiter.allows(limit: 3, now: now))
        #expect(!limiter.allows(limit: 2, now: now))
    }

    @Test func taskIsSchedulableOnlyBeforeItSucceedsOrGoesToxic() {
        var task = HiveTask(
            id: "t", title: "t", module: "m", path: "m", realm: "Core",
            signalKind: "testGap", reason: "r", score: 1, confidence: 1, prompt: "p"
        )
        #expect(task.isSchedulable)

        task.state = .failed
        #expect(task.isSchedulable)

        task.state = .running
        #expect(!task.isSchedulable)

        task.state = .review
        #expect(!task.isSchedulable)

        task.state = .toxic
        #expect(!task.isSchedulable)
        #expect(task.isTerminal)
    }
}

@Suite("Hive - preflight")
struct HiveAuthProbeTests {

    @Test func signedInCLIIsAllowedToSpawn() {
        let state = HiveAuthProbe.parse(#"{"loggedIn":true,"authMethod":"oauth","apiProvider":"firstParty"}"#)
        #expect(state == .loggedIn(method: "oauth"))
        #expect(state.canSpawn)
        #expect(state.blockerText == nil)
    }

    @Test func signedOutCLIBlocksTheHiveWithTheExactFix() {
        let state = HiveAuthProbe.parse(#"{"loggedIn":false,"authMethod":"none","apiProvider":"firstParty"}"#)
        #expect(state == .loggedOut)
        #expect(!state.canSpawn)
        #expect(state.blockerText?.contains("claude auth login") == true)
    }

    @Test func anUnreadableProbeIsUnknownNotSignedOut() {
        // The distinction matters: "we could not tell" and "it is signed out"
        // call for different messages and neither may be silently assumed.
        let state = HiveAuthProbe.parse("<html>proxy error</html>")
        #expect(!state.canSpawn)
        if case .unknown = state {} else { Issue.record("expected .unknown, got \(state)") }
        #expect(state.blockerText?.contains("Could not determine") == true)
    }

    @Test func emptyProbeOutputIsUnknown() {
        let state = HiveAuthProbe.parse("")
        #expect(state == .unknown("empty response"))
    }

    @Test func aSignedOutReportIsReadFromStdoutNotFromTheExitCode() {
        // `claude auth status` exits 1 when signed out and still prints a
        // well-formed report. Reading the code instead of the report turned a
        // clear "signed out" into a vague "could not determine".
        let signedOut = #"{"loggedIn":false,"authMethod":"none","apiProvider":"firstParty"}"#
        #expect(HiveAuthProbe.parse(signedOut) == .loggedOut)
        #expect(HiveAuthProbe.parse(signedOut).blockerText?.contains("not signed in") == true)
    }
}

@Suite("Hive - bee process contract")
struct BeeRunnerTests {

    private func configuration(worktree: String? = "hive-x") -> BeeRunner.Configuration {
        BeeRunner.Configuration(
            executable: "/usr/bin/true",
            workingDirectory: "/tmp",
            prompt: "do the thing",
            sessionID: "11111111-2222-3333-4444-555555555555",
            model: "sonnet",
            permissionMode: "acceptEdits",
            maxBudgetUSD: 5,
            timeoutSeconds: 60,
            worktreeName: worktree,
            displayName: "bee/hive-x"
        )
    }

    @Test func argumentsPinTheSessionSoTheChatIsResumable() {
        let args = BeeRunner.arguments(for: configuration())
        let sessionIndex = try! #require(args.firstIndex(of: "--session-id"))
        #expect(args[sessionIndex + 1] == "11111111-2222-3333-4444-555555555555")
        #expect(args.contains("--output-format"))
        #expect(args.contains("stream-json"))
        #expect(args.contains("--verbose"))
    }

    @Test func argumentsCarryTheBudgetAndTheWorktree() {
        let args = BeeRunner.arguments(for: configuration())
        let budgetIndex = try! #require(args.firstIndex(of: "--max-budget-usd"))
        #expect(args[budgetIndex + 1] == "5.00")

        let worktreeIndex = try! #require(args.firstIndex(of: "--worktree"))
        #expect(args[worktreeIndex + 1] == "hive-x")
    }

    @Test func noWorktreeFlagWhenIsolationIsOff() {
        let args = BeeRunner.arguments(for: configuration(worktree: nil))
        #expect(!args.contains("--worktree"))
    }

    // MARK: - Stream decoding

    @Test func decodesAToolUseAsAToolEvent() {
        let line = #"{"type":"assistant","message":{"content":[{"type":"tool_use","name":"Edit"}]}}"#
        let event = try! #require(BeeRunner.decode(line))
        #expect(event.kind == .tool("Edit"))
    }

    @Test func decodesAssistantText() {
        let line = #"{"type":"assistant","message":{"content":[{"type":"text","text":"measured 14 TODOs"}]}}"#
        let event = try! #require(BeeRunner.decode(line))
        #expect(event.kind == .assistant)
        #expect(event.text == "measured 14 TODOs")
    }

    @Test func malformedLineBecomesRawRatherThanBeingDropped() {
        let event = try! #require(BeeRunner.decode("not json at all"))
        #expect(event.kind == .raw)
    }

    // MARK: - Outcome

    @Test func successRequiresBothACleanExitAndASuccessResult() {
        let box = ResultBox()
        box.record(
            line: #"{"type":"result","subtype":"success","is_error":false,"result":"done","total_cost_usd":0.42,"duration_ms":120000,"session_id":"s1"}"#,
            success: true
        )
        let outcome = BeeRunner.outcome(exitCode: 0, resultBox: box, stderr: "", fallbackSessionID: "fallback")

        #expect(outcome.status == .succeeded)
        #expect(outcome.costUSD == 0.42)
        #expect(outcome.durationMs == 120000)
        #expect(outcome.sessionID == "s1")
    }

    @Test func nonZeroExitIsNeverASuccessEvenWithASuccessResultLine() {
        let box = ResultBox()
        box.record(
            line: #"{"type":"result","subtype":"success","is_error":false,"result":"done"}"#,
            success: true
        )
        let outcome = BeeRunner.outcome(exitCode: 2, resultBox: box, stderr: "", fallbackSessionID: "f")
        #expect(outcome.status == .failed)
    }

    @Test func aMissingResultLineIsAFailureNotAnAssumedSuccess() {
        let box = ResultBox()
        let outcome = BeeRunner.outcome(
            exitCode: 0,
            resultBox: box,
            stderr: "",
            fallbackSessionID: "f"
        )
        #expect(outcome.status == .failed)
        #expect(outcome.summary.contains("without reporting a result"))
    }

    @Test func timeoutOutranksWhateverTheStreamSaid() {
        let box = ResultBox()
        box.record(line: #"{"type":"result","subtype":"success","is_error":false}"#, success: true)
        box.markTimedOut()
        let outcome = BeeRunner.outcome(exitCode: 0, resultBox: box, stderr: "", fallbackSessionID: "f")
        #expect(outcome.status == .timedOut)
    }

    @Test func stderrIsSurfacedWhenTheProcessDiesWithoutAResult() {
        let box = ResultBox()
        let outcome = BeeRunner.outcome(
            exitCode: 1,
            resultBox: box,
            stderr: "error: not a git repository",
            fallbackSessionID: "f"
        )
        #expect(outcome.status == .failed)
        #expect(outcome.summary.contains("not a git repository"))
    }
}

@Suite("Hive - repository scanning")
struct HiveRepoScannerTests {

    @Test func countsLinesTodosAndTestBlocks() {
        let source = """
        const std = @import("std");
        // TODO: handle the empty case
        pub fn add(a: i32, b: i32) i32 { return a + b; }
        // FIXME: overflow
        test "add works" {
            try std.testing.expectEqual(3, add(1, 2));
        }
        """
        let counts = HiveRepoScanner.count(in: source)
        #expect(counts.lines == 7)
        #expect(counts.todos == 2)
        #expect(counts.testBlocks == 1)
    }

    @Test func countsSwiftTestFunctionsToo() {
        let source = """
        import Testing
        @Test func somethingWorks() {}
        func testLegacyStyle() {}
        """
        let counts = HiveRepoScanner.count(in: source)
        #expect(counts.testBlocks == 2)
    }

    @Test func churnCountsEachCommitOncePerModule() {
        let log = """
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        src/tri/queen.zig
        src/tri/hive.zig
        src/vsa/core.zig
        bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb
        src/tri/queen.zig
        """
        let counts = HiveRepoScanner.parseChurn(log, prefixes: ["src"])

        // Two files in src/tri in the first commit still count as one commit.
        #expect(counts["src/tri"] == 2)
        #expect(counts["src/vsa"] == 1)
    }

    @Test func churnIgnoresPathsOutsideTheScannedRoots() {
        let log = """
        aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa
        docs/readme.md
        src/tri/x.zig
        """
        let counts = HiveRepoScanner.parseChurn(log, prefixes: ["src"])
        #expect(counts.count == 1)
        #expect(counts["src/tri"] == 1)
    }

    @Test func testsLivingOutsideTheModuleTreeAreAttributedBackToIt() throws {
        // Swift keeps its tests in a sibling tree. Counting only in-tree
        // blocks would report a fully tested module as wholly untested.
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("hive-attr-\(UUID().uuidString)")
        let moduleRoot = root.appendingPathComponent("QueenUI")
        let testsRoot = root.appendingPathComponent("Tests")
        try fm.createDirectory(at: moduleRoot.appendingPathComponent("Hive"), withIntermediateDirectories: true)
        try fm.createDirectory(at: moduleRoot.appendingPathComponent("Widgets"), withIntermediateDirectories: true)
        try fm.createDirectory(at: testsRoot, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try "struct HiveOrchestrator {}".write(
            to: moduleRoot.appendingPathComponent("Hive/HiveOrchestrator.swift"),
            atomically: true, encoding: .utf8
        )
        try "struct StatCard {}".write(
            to: moduleRoot.appendingPathComponent("Widgets/StatCard.swift"),
            atomically: true, encoding: .utf8
        )
        try """
        @Test func a() { _ = HiveOrchestrator.self }
        @Test func b() { _ = HiveOrchestrator.self }
        """.write(to: testsRoot.appendingPathComponent("HiveTests.swift"), atomically: true, encoding: .utf8)

        let scanner = HiveRepoScanner(projectRoot: root.path)
        let counts = scanner.attributeExternalTests(
            testsRoot: testsRoot.path,
            moduleRoot: moduleRoot.path,
            modulePrefix: "QueenUI"
        )

        #expect(counts["QueenUI/Hive"] == 2)
        // A module the test file never names gets no credit at all.
        #expect(counts["QueenUI/Widgets"] == nil)
    }

    @Test func externalTestsRootThatDoesNotExistYieldsNoAttribution() {
        let scanner = HiveRepoScanner(projectRoot: "/tmp")
        let counts = scanner.attributeExternalTests(
            testsRoot: "/tmp/definitely-not-here-\(UUID().uuidString)",
            moduleRoot: "/tmp",
            modulePrefix: "x"
        )
        #expect(counts.isEmpty)
    }

    @Test func issueMentionsAreCountedPerModulePath() {
        let snapshot = #"{"issues":[{"title":"src/tri leaks","body":"see src/tri and src/vsa"}]}"#
        let counts = HiveRepoScanner.parseIssueMentions(snapshot, prefixes: ["src"])
        #expect(counts["src/tri"] == 2)
        #expect(counts["src/vsa"] == 1)
    }
}

@Suite("Hive - persistence")
struct HiveStoreTests {

    private func temporaryStore() -> HiveStore {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-test-\(UUID().uuidString)")
        return HiveStore(stateRoot: root.path)
    }

    @Test func stateSurvivesARoundTrip() {
        let store = temporaryStore()
        var policy = HivePolicy.default
        policy.maxConcurrentBees = 3
        let task = HiveTask(
            id: "hive-src-tri-testGap", title: "t", module: "src/tri", path: "src/tri",
            realm: "Core", signalKind: "testGap", reason: "r", score: 0.9, confidence: 1, prompt: "p"
        )

        #expect(store.save(HiveState(policy: policy, tasks: [task])))

        let loaded = store.load()
        #expect(loaded.policy.maxConcurrentBees == 3)
        #expect(loaded.tasks.count == 1)
        #expect(loaded.tasks.first?.id == "hive-src-tri-testGap")
    }

    @Test func aTaskLeftRunningByACrashGoesBackToTheQueue() {
        let store = temporaryStore()
        var task = HiveTask(
            id: "t", title: "t", module: "m", path: "m", realm: "Core",
            signalKind: "testGap", reason: "r", score: 1, confidence: 1, prompt: "p"
        )
        task.state = .running
        store.save(HiveState(policy: .default, tasks: [task]))

        let loaded = store.load()
        // Neither counted as a success nor burned as a failure - requeued, and
        // the reason is recorded.
        #expect(loaded.tasks.first?.state == .pending)
        #expect(loaded.tasks.first?.lastError?.contains("interrupted") == true)
    }

    @Test func missingStateFileYieldsDefaultsRatherThanCrashing() {
        let loaded = temporaryStore().load()
        #expect(loaded.tasks.isEmpty)
        #expect(loaded.policy.enabled == false)
    }

    @Test func eventsAppendInOrderAndReadBackNewestFirst() {
        let store = temporaryStore()
        store.append(HiveEvent(kind: "bee_spawned", taskID: "t1", detail: "first"))
        store.append(HiveEvent(kind: "bee_succeeded", taskID: "t1", detail: "second"))

        let events = store.recentEvents(limit: 10)
        #expect(events.count == 2)
        #expect(events.first?.detail == "second")
    }

    @Test func theLoopStartsDisarmed() {
        // A fresh install must never begin spawning bees on its own.
        #expect(HivePolicy.default.enabled == false)
        #expect(HivePolicy.default.allowPush == false)
    }
}
