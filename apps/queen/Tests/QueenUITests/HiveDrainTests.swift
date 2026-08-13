import Testing
import Foundation
@testable import QueenUILib

/// The second unbounded wait on the subprocess path.
///
/// An adversarial review found that escalating SIGTERM to SIGKILL unblocks
/// `waitUntilExit()` and nothing else: one line later `group.wait()` waits on
/// pipe readers, and `readDataToEndOfFile()` returns only when the WRITE end
/// closes. A grandchild that inherited the descriptor keeps it open after its
/// parent is killed, and `claude -p` spawns tool subprocesses routinely.
@Suite("Hive - subprocess drain")
struct HiveDrainTests {

    @Test func aGrandchildHoldingThePipeDoesNotWedgeTheCaller() {
        // The child exits immediately; the grandchild it leaves behind holds
        // the inherited stdout far longer than any grace period. Without a
        // bounded drain this call never returns.
        let started = Date()
        let result = HiveProcess.run(
            executable: "/bin/sh",
            arguments: ["-c", "sleep 60 & exit 0"],
            timeout: 3
        )
        let elapsed = Date().timeIntervalSince(started)

        #expect(
            elapsed < HiveProcess.terminationGraceSeconds + HiveProcess.readerDrainGraceSeconds + 5
        )
        #expect(result.exitCode == 0)
    }

    @Test func anOrdinaryProcessStillReturnsItsWholeOutput() {
        // The drain bound must not truncate a well-behaved child.
        let result = HiveProcess.run(
            executable: "/bin/echo",
            arguments: ["measured, not assumed"],
            timeout: 10
        )
        #expect(result.exitCode == 0)
        #expect(result.standardOutput.contains("measured, not assumed"))
        #expect(result.timedOut == false)
        #expect(result.outputTruncated == false)
    }

    /// The bounded drain must hand back what arrived, and say that it is a
    /// prefix.
    ///
    /// This is the theorem the last wave's comment asserted and the code did
    /// not do: the bytes were published by the reader RETURNING, and on this
    /// path the reader has not returned. The payload was written, read by the
    /// kernel, and discarded - exit 0, timedOut false, stdout zero bytes. Every
    /// caller then saw a successful command that produced no output, and the
    /// scanner scored that as a measured churn of zero for the whole tree.
    @Test func aBoundedDrainReturnsWhatArrivedAndSaysItIsAPrefix() {
        let result = HiveProcess.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo '{\"loggedIn\":true}'; sleep 45 & exit 0"],
            timeout: 3
        )

        #expect(result.exitCode == 0)
        // The child exited on its own, well inside the timeout...
        #expect(result.timedOut == false)
        // ...the grandchild held the pipe past the drain grace...
        #expect(result.outputTruncated)
        // ...and the line the child did write is still here.
        #expect(result.standardOutput.contains("loggedIn"))
    }

    /// The two flags are not the same claim, and callers act on the difference.
    @Test func truncationIsNotTheSameFlagAsTheChildsWallClock() {
        let complete = HiveProcess.run(
            executable: "/bin/echo", arguments: ["done"], timeout: 10
        )
        #expect(complete.timedOut == false)
        #expect(complete.outputTruncated == false)

        // Timed out on the child's wall clock, and its output is still here:
        // the two flags answer different questions.
        let killed = HiveProcess.run(
            executable: "/bin/sh",
            arguments: ["-c", "echo first; sleep 45"],
            timeout: 2
        )
        #expect(killed.timedOut)
        #expect(killed.standardOutput.contains("first"))
    }

    /// The scanner's side of the same defect.
    ///
    /// `git log` exiting 0 with a truncated read parses into a table missing
    /// most of the repository, and every module the table does not name is
    /// written out as a MEASURED churn of zero - weight still in the
    /// denominator, confidence reported as if the probe had worked. The rule
    /// the whole file exists to enforce, breached from underneath.
    @Test func aTruncatedGitLogIsAFailedReadingNotAChurnOfZero() {
        let truncated = HiveProcess.Result(
            exitCode: 0,
            standardOutput: "abc\nsrc/vsa/vsa.zig\n",
            standardError: "",
            timedOut: false,
            outputTruncated: true
        )
        switch HiveRepoScanner.churnReading(from: truncated, prefixes: ["src"]) {
        case .success(let table):
            Issue.record("a partial log was accepted as a reading: \(table)")
        case .failure(let why):
            #expect(why.contains("not read to the end"))
        }
    }

    @Test func acompleteGitLogIsStillARealReading() {
        let complete = HiveProcess.Result(
            exitCode: 0,
            standardOutput: String(repeating: "a", count: 40) + "\nsrc/vsa/vsa.zig\n",
            standardError: "",
            timedOut: false,
            outputTruncated: false
        )
        switch HiveRepoScanner.churnReading(from: complete, prefixes: ["src"]) {
        case .success(let table):
            #expect(table["src/vsa"] == 1)
        case .failure(let why):
            Issue.record("a complete log must be a reading: \(why)")
        }
    }

    @Test func aChildThatIgnoresSigtermIsStillReaped() {
        let started = Date()
        let result = HiveProcess.run(
            executable: "/bin/sh",
            arguments: ["-c", "trap '' TERM; sleep 60"],
            timeout: 2
        )
        let elapsed = Date().timeIntervalSince(started)

        #expect(result.timedOut)
        #expect(elapsed < 2 + HiveProcess.terminationGraceSeconds + HiveProcess.readerDrainGraceSeconds + 5)
    }
}
