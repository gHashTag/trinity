import Testing
import Foundation
@testable import QueenUILib

@Suite("Hive - verification gate")
struct HiveVerifierTests {

    private func task(realm: String, branch: String? = nil) -> HiveTask {
        var t = HiveTask(
            id: "t", title: "t", module: "m", path: "m", realm: realm,
            signalKind: "testGap", reason: "r", score: 1, confidence: 1, prompt: "p"
        )
        t.branch = branch
        return t
    }

    // MARK: - Three outcomes, never two

    @Test func unavailableIsNotAPass() {
        let verdict = HiveVerdict.unavailable("no checker")
        #expect(!verdict.isPass)
        #expect(!verdict.isFail)
        #expect(verdict.label == "UNVERIFIED")
    }

    @Test func onlyAFailingCheckCostsTheBeeAnAttempt() {
        #expect(HiveVerdict.failed("build broke").isFail)
        #expect(!HiveVerdict.passed("ok").isFail)
        // A missing checker is the Queen's gap, not the bee's fault.
        #expect(!HiveVerdict.unavailable("no checker").isFail)
    }

    @Test func theZigCoreReportsItselfUnverifiableRatherThanVerified() {
        // `zig build` fails at build.zig.zon in this checkout. Reporting a Zig
        // change as verified would be a lie with a green tick on it.
        let verdict = HiveVerifier(projectRoot: "/tmp").verify(task: task(realm: "Core"))
        #expect(!verdict.isPass)
        #expect(verdict.detail.contains("build.zig.zon"))
    }

    @Test func anUnknownRealmIsUnverifiedNotVerified() {
        let verdict = HiveVerifier(projectRoot: "/tmp").verify(task: task(realm: "Operator"))
        #expect(!verdict.isPass)
        #expect(verdict.label == "UNVERIFIED")
    }

    // MARK: - Worktree targeting

    @Test func aTaskWithNoWorktreeVerifiesTheMainCheckout() {
        let verifier = HiveVerifier(projectRoot: "/tmp/repo")
        #expect(verifier.workingRoot(for: task(realm: "Cockpit")) == "/tmp/repo")
    }

    @Test func aMissingWorktreeRefusesRatherThanGradingTheWrongTree() {
        // The dangerous version of this returned projectRoot, ran the checks
        // against a tree the bee never touched, and reported a green pass.
        let verifier = HiveVerifier(projectRoot: "/tmp/repo")
        let resolved = verifier.workingRoot(for: task(realm: "Cockpit", branch: "hive-nope"))
        #expect(resolved == nil)

        let verdict = verifier.verify(task: task(realm: "Cockpit", branch: "hive-nope"))
        #expect(!verdict.isPass)
        #expect(verdict.detail.contains("grade the wrong tree"))
    }

    @Test func worktreePathIsFoundByBranchRef() {
        let porcelain = """
        worktree /Users/x/trinity
        HEAD abc
        branch refs/heads/main

        worktree /Users/x/trinity-worktrees/hive-src-tri
        HEAD def
        branch refs/heads/hive-src-tri
        """
        #expect(
            HiveVerifier.worktreePath(named: "hive-src-tri", in: porcelain)
                == "/Users/x/trinity-worktrees/hive-src-tri"
        )
        #expect(HiveVerifier.worktreePath(named: "hive-absent", in: porcelain) == nil)
    }

    @Test func worktreePathIsFoundByDirectoryNameWhenDetached() {
        let porcelain = """
        worktree /Users/x/wt/hive-a
        HEAD abc
        detached
        """
        #expect(HiveVerifier.worktreePath(named: "hive-a", in: porcelain) == "/Users/x/wt/hive-a")
    }

    // MARK: - Output shaping

    @Test func summaryQuotesTheToolsOwnTally() {
        let output = """
        ◇ Test run started.
        ✔ Test run with 110 tests in 17 suites passed after 0.05 seconds.
        """
        #expect(HiveVerifier.testSummary(output)?.hasPrefix("Test run with 110 tests") == true)
        #expect(HiveVerifier.testSummary("nothing here") == nil)
    }

    @Test func failureOutputIsTailedNotTruncatedFromTheFront() {
        // The compiler's last lines are the ones that name the error.
        let text = (1...100).map { "line \($0)" }.joined(separator: "\n")
        let tail = HiveVerifier.tail(text, lines: 3)
        #expect(tail == "line 98\nline 99\nline 100")
    }

    @Test func missingPackageIsUnavailableNotFailed() {
        let verdict = HiveVerifier(projectRoot: "/tmp")
            .verifySwiftPackage(at: "/tmp/definitely-not-a-package-\(UUID().uuidString)")
        #expect(!verdict.isPass)
        #expect(!verdict.isFail)
    }
}

@Suite("Hive - spend ceiling and skip list")
struct HiveBudgetTests {

    @Test func spendAccumulatesPerLocalDay() {
        var state = HiveState()
        let today = Date()
        state.record(spend: 1.25, on: today)
        state.record(spend: 0.75, on: today)
        #expect(abs(state.spent(on: today) - 2.0) < 0.0001)
    }

    @Test func yesterdaysSpendDoesNotCountAgainstToday() {
        var state = HiveState()
        let today = Date()
        let yesterday = today.addingTimeInterval(-86_400)
        state.record(spend: 10, on: yesterday)
        #expect(state.spent(on: today) == 0)
        #expect(state.spent(on: yesterday) == 10)
    }

    @Test func spendHistoryIsTrimmedButTodaySurvives() {
        var state = HiveState()
        let today = Date()
        state.record(spend: 1, on: today.addingTimeInterval(-40 * 86_400))
        state.record(spend: 2, on: today)
        #expect(state.spent(on: today) == 2)
        #expect(state.spendByDay.count == 1)
    }

    @Test func zeroSpendIsNotRecorded() {
        var state = HiveState()
        state.record(spend: 0)
        #expect(state.spendByDay.isEmpty)
    }

    @Test func aPerBeeBudgetCannotExceedTheDailyCeiling() {
        // Otherwise one bee spends the whole day before the ceiling is read.
        var policy = HivePolicy.default
        policy.dailyBudgetUSD = 4
        policy.maxBudgetUSDPerBee = 50
        #expect(policy.sanitized().maxBudgetUSDPerBee == 4)
    }

    @Test func breakerAndRetentionAreClamped() {
        var policy = HivePolicy.default
        policy.maxConsecutiveFailures = 0
        policy.retainTranscriptDays = 9999
        let clean = policy.sanitized()
        #expect(clean.maxConsecutiveFailures == 1)
        #expect(clean.retainTranscriptDays == 365)
    }

    @Test func spendSurvivesAStoreRoundTrip() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-spend-\(UUID().uuidString)")
        let store = HiveStore(stateRoot: root.path)
        var state = HiveState()
        state.record(spend: 3.5)
        store.save(state)

        // A crash-loop must not be able to reset the day's ceiling by restarting.
        #expect(abs(store.load().spent() - 3.5) < 0.0001)
    }

    @Test func olderStateFilesWithoutASpendLedgerStillLoad() {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("hive-legacy-\(UUID().uuidString)")
        try? FileManager.default.createDirectory(
            at: root.appendingPathComponent("queen"), withIntermediateDirectories: true
        )
        let legacy = #"{"policy":{"enabled":false,"maxConcurrentBees":2,"cycleIntervalSeconds":900,"maxAttemptsPerTask":3,"maxBeesPerHour":6,"targetsPerCycle":3,"beeTimeoutSeconds":3600,"maxBudgetUSDPerBee":5,"model":"sonnet","permissionMode":"acceptEdits","useWorktree":true,"allowPush":false,"openChatPerTask":true},"tasks":[],"updatedAt":"2026-08-13T00:00:00Z"}"#
        try? legacy.write(
            to: root.appendingPathComponent("queen/hive.json"), atomically: true, encoding: .utf8
        )

        let loaded = HiveStore(stateRoot: root.path).load()
        #expect(loaded.spendByDay.isEmpty)
        #expect(loaded.policy.maxConcurrentBees == 2)
        // Fields added after the file was written take their defaults.
        #expect(loaded.policy.verifyBeforeReview)
        #expect(loaded.policy.skippedModules.isEmpty)
    }
}

@Suite("Hive - retention")
struct HiveRetentionTests {

    @Test func onlyHiveAuthoredThreadsArePruned() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("hive-ret-\(UUID().uuidString)")
        let threads = root.appendingPathComponent("threads")
        try fm.createDirectory(at: threads, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        func write(_ thread: ChatThread) throws {
            try encoder.encode(thread).write(to: threads.appendingPathComponent("\(thread.id).json"))
        }

        let old = Date().addingTimeInterval(-30 * 86_400)

        var hiveThread = ChatThread(title: "🐝 old bee")
        hiveThread.tags = ["hive"]
        hiveThread.updatedAt = old
        try write(hiveThread)

        var humanThread = ChatThread(title: "my own old conversation")
        humanThread.updatedAt = old
        try write(humanThread)

        var pinnedHive = ChatThread(title: "🐝 pinned bee")
        pinnedHive.tags = ["hive"]
        pinnedHive.isPinned = true
        pinnedHive.updatedAt = old
        try write(pinnedHive)

        let result = HiveRetention(stateRoot: root.path, threadsDirectory: threads)
            .prune(olderThanDays: 14)

        #expect(result.threadsRemoved == 1)
        // The user's own old thread and the pinned bee both survive.
        #expect(fm.fileExists(atPath: threads.appendingPathComponent("\(humanThread.id).json").path))
        #expect(fm.fileExists(atPath: threads.appendingPathComponent("\(pinnedHive.id).json").path))
        #expect(!fm.fileExists(atPath: threads.appendingPathComponent("\(hiveThread.id).json").path))
    }

    @Test func recentTranscriptsSurvive() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("hive-ret2-\(UUID().uuidString)")
        let hive = root.appendingPathComponent("queen/hive")
        try fm.createDirectory(at: hive, withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let fresh = hive.appendingPathComponent("fresh.jsonl")
        try "{}".write(to: fresh, atomically: true, encoding: .utf8)

        let stale = hive.appendingPathComponent("stale.jsonl")
        try "{}".write(to: stale, atomically: true, encoding: .utf8)
        try fm.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-40 * 86_400)],
            ofItemAtPath: stale.path
        )

        let result = HiveRetention(stateRoot: root.path).prune(olderThanDays: 14)
        #expect(result.transcriptsRemoved == 1)
        #expect(fm.fileExists(atPath: fresh.path))
        #expect(!fm.fileExists(atPath: stale.path))
    }

    @Test func pruningAnAbsentDirectoryIsHarmless() {
        let result = HiveRetention(stateRoot: "/tmp/nope-\(UUID().uuidString)").prune(olderThanDays: 1)
        #expect(result.isEmpty)
    }
}

@Suite("Hive - stale inputs")
struct HiveStaleInputTests {

    @Test func aStaleIssuesSnapshotIsUnreadableNotZero() throws {
        // The real file on this machine was 116 days old and was being scored
        // as a current reading of open issues.
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("hive-stale-\(UUID().uuidString)")
        try fm.createDirectory(at: root.appendingPathComponent(".trinity"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        let snapshot = root.appendingPathComponent(".trinity/issues_snapshot.json")
        try #"[{"number":1,"title":"src/tri is broken"}]"#.write(to: snapshot, atomically: true, encoding: .utf8)
        try fm.setAttributes(
            [.modificationDate: Date().addingTimeInterval(-116 * 86_400)],
            ofItemAtPath: snapshot.path
        )

        let scanner = HiveRepoScanner(projectRoot: root.path)
        switch scanner.readIssueCounts() {
        case .success:
            Issue.record("a 116-day-old snapshot must not be reported as a measurement")
        case .failure(let why):
            #expect(why.contains("stale"))
            #expect(why.contains("116"))
        }
    }

    @Test func aFreshSnapshotIsRead() throws {
        let fm = FileManager.default
        let root = fm.temporaryDirectory.appendingPathComponent("hive-fresh-\(UUID().uuidString)")
        try fm.createDirectory(at: root.appendingPathComponent(".trinity"), withIntermediateDirectories: true)
        defer { try? fm.removeItem(at: root) }

        try #"[{"number":1,"title":"src/tri is broken"}]"#.write(
            to: root.appendingPathComponent(".trinity/issues_snapshot.json"),
            atomically: true, encoding: .utf8
        )

        switch HiveRepoScanner(projectRoot: root.path).readIssueCounts() {
        case .success(let counts):
            #expect(counts["src/tri"] == 1)
        case .failure(let why):
            Issue.record("a fresh snapshot should be read, got: \(why)")
        }
    }
}
