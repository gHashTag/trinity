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
