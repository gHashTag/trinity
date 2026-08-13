import Foundation

/// Minimal process helpers for the hive. Kept separate from `BeeRunner` so the
/// scanner can shell out to git without dragging in the streaming machinery.
enum HiveProcess {

    /// How long a process gets to honour SIGTERM before it is killed outright.
    ///
    /// `Process.terminate()` sends SIGTERM, which is a request. A git
    /// subprocess that ignores it holds the calling thread in
    /// `waitUntilExit()` for ever, and because the scan runs inside the cycle
    /// that wedges the whole loop: the Hive keeps showing 24/7 ARMED, `Cycle
    /// now` does nothing, and only killing the app recovers it.
    static let terminationGraceSeconds: TimeInterval = 5

    /// How long the pipe readers get to finish after the child is gone.
    ///
    /// Bounded for the same reason the child's own wait is bounded: a reader
    /// blocked on a descriptor a grandchild still holds open would otherwise
    /// wedge the caller for ever, with the process already dead.
    static let readerDrainGraceSeconds: Double = 5

    struct Result {
        let exitCode: Int32
        let standardOutput: String
        let standardError: String
        /// True when the process was killed because it outlived its timeout.
        let timedOut: Bool
        /// True when at least one of the two streams was NOT read to EOF, so
        /// what came back may be a prefix of what the child wrote.
        ///
        /// Separate from `timedOut`, which is about the child's wall clock
        /// only. A child can exit 0, well inside its timeout, and still leave
        /// this true: a grandchild holding the inherited descriptor keeps the
        /// pipe open past the drain grace, and then a complete-looking result
        /// is a partial read. Without this flag the caller cannot tell the two
        /// apart, and `HiveRepoScanner.readChurn` scored a truncated git log as
        /// a measured churn of zero for the whole repository.
        let outputTruncated: Bool

        init(
            exitCode: Int32,
            standardOutput: String,
            standardError: String,
            timedOut: Bool,
            outputTruncated: Bool = false
        ) {
            self.exitCode = exitCode
            self.standardOutput = standardOutput
            self.standardError = standardError
            self.timedOut = timedOut
            self.outputTruncated = outputTruncated
        }
    }

    /// Runs a command to completion. Both pipes are drained concurrently so a
    /// chatty process cannot deadlock on a full pipe buffer.
    static func run(
        executable: String,
        arguments: [String],
        currentDirectory: String? = nil,
        environment: [String: String]? = nil,
        timeout: TimeInterval = 60
    ) -> Result {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        if let currentDirectory {
            process.currentDirectoryURL = URL(fileURLWithPath: currentDirectory)
        }
        if let environment {
            process.environment = environment
        }

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        do {
            try process.run()
        } catch {
            return Result(
                exitCode: -1,
                standardOutput: "",
                standardError: "failed to launch \(executable): \(error.localizedDescription)",
                timedOut: false
            )
        }

        let outData = UnsafeDataBox()
        let errData = UnsafeDataBox()
        let group = DispatchGroup()

        // Read INCREMENTALLY into the box, not with `readDataToEndOfFile()`.
        //
        // That call publishes its bytes by returning, and on the bounded path
        // it has not returned - that is what the bound is for. The box was
        // therefore still the empty `Data()` when the caller read it, and every
        // byte the child had already written was thrown away: measured, exit 0,
        // `timedOut` false, stdout zero bytes, with the full JSON line sitting
        // unread in the pipe. Appending under the box's own lock puts the bytes
        // where the caller can find them the moment they arrive.
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            Self.drain(outPipe.fileHandleForReading, into: outData)
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            Self.drain(errPipe.fileHandleForReading, into: errData)
            group.leave()
        }

        var timedOut = false
        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        if process.isRunning {
            timedOut = true
            terminateHard(process)
        }
        process.waitUntilExit()
        // Killing the child is not enough to unblock the readers.
        //
        // `readDataToEndOfFile()` returns when the WRITE end of the pipe closes,
        // and a grandchild that inherited the descriptor keeps it open after its
        // parent dies. `claude -p` spawns tool subprocesses, so this is ordinary,
        // not exotic. An unbounded `group.wait()` here would hold the caller for
        // ever - the second unbounded block on this path, one line after the one
        // the SIGKILL escalation was added to fix.
        let drained = group.wait(timeout: .now() + Self.readerDrainGraceSeconds) != .timedOut
        if !drained {
            // Whatever arrived so far is what there is - and it really is in
            // the boxes now, because the readers append as they go. The handles
            // are closed so the detached readers stop.
            try? outPipe.fileHandleForReading.close()
            try? errPipe.fileHandleForReading.close()
        }

        // Complete means "read to EOF", which is the only state in which the
        // absence of a line is evidence that the child never wrote it.
        //
        // The bound is consulted FIRST, and it is decisive. Closing a
        // descriptor underneath a blocked `read` does not reliably surface as
        // an error - on this platform the call can return 0, which is
        // indistinguishable from a genuine end of file, and the reader would
        // then claim it read everything a moment after being cut off. What is
        // known for certain is that the drain did not finish inside its bound.
        let truncated = !drained || !(outData.reachedEnd && errData.reachedEnd)

        return Result(
            exitCode: process.terminationStatus,
            standardOutput: String(data: outData.value, encoding: .utf8) ?? "",
            standardError: String(data: errData.value, encoding: .utf8) ?? "",
            timedOut: timedOut,
            outputTruncated: truncated
        )
    }

    /// Copies a pipe into a box until EOF, appending as it goes.
    ///
    /// Uses `read(2)` on the descriptor rather than `FileHandle.availableData`.
    /// The bounded path closes this handle underneath a blocked reader to
    /// unblock it, and the FileHandle accessors answer that by raising an
    /// Objective-C exception, which Swift cannot catch: the crash would land in
    /// the drain the bound exists to survive. `read` returns -1 and the loop
    /// leaves quietly, with everything that arrived already in the box.
    static func drain(_ handle: FileHandle, into box: UnsafeDataBox) {
        let descriptor = handle.fileDescriptor
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)
        while true {
            let count = buffer.withUnsafeMutableBytes { raw -> Int in
                read(descriptor, raw.baseAddress, raw.count)
            }
            if count > 0 {
                box.append(Data(buffer[0..<count]))
                continue
            }
            if count == 0 {
                box.markReachedEnd()
                return
            }
            // Interrupted by a signal: the read never happened, so retry.
            if errno == EINTR { continue }
            // Anything else - EBADF from the close above, most likely - ends
            // the drain without claiming the stream was read to its end.
            return
        }
    }

    /// Asks a process to stop, then makes it stop.
    ///
    /// SIGTERM first, because a well-behaved child flushes and exits; SIGKILL
    /// after the grace period, because a child that ignores SIGTERM is exactly
    /// the case the caller cannot survive. Signals only this process's own
    /// child, whose pid is known to be current, never a pid read from a file.
    static func terminateHard(
        _ process: Process,
        graceSeconds: TimeInterval = terminationGraceSeconds
    ) {
        guard process.isRunning else { return }
        process.terminate()
        let deadline = Date().addingTimeInterval(graceSeconds)
        while process.isRunning && Date() < deadline {
            Thread.sleep(forTimeInterval: 0.05)
        }
        guard process.isRunning else { return }
        kill(process.processIdentifier, SIGKILL)
    }

    /// Resolves an executable by name across the places the user's tools live,
    /// honouring an explicit override first.
    ///
    /// Note: `tri` on this machine's PATH is a Railway SSH shim, not the
    /// Trinity CLI - so the hive resolves binaries by absolute path and never
    /// relies on PATH lookup.
    static func resolve(_ name: String, overrideEnvKey: String? = nil) -> String? {
        let fm = FileManager.default
        if let key = overrideEnvKey,
           let configured = ProcessInfo.processInfo.environment[key],
           fm.isExecutableFile(atPath: configured) {
            return configured
        }
        let home = fm.homeDirectoryForCurrentUser.path
        let candidates = [
            "\(home)/.local/bin/\(name)",
            "/opt/homebrew/bin/\(name)",
            "/usr/local/bin/\(name)",
            "\(home)/.claude/local/\(name)",
        ]
        return candidates.first(where: fm.isExecutableFile(atPath:))
    }
}

// MARK: - Preflight

/// Whether the Claude Code CLI can actually do work right now.
///
/// Checked before arming the loop: an unauthenticated CLI fails every bee in
/// milliseconds, and without this the attempt counter would burn three tries
/// per task and mark real work toxic for a reason that has nothing to do with
/// the code.
enum HiveAuthState: Equatable {
    case loggedIn(method: String)
    case loggedOut
    /// The probe itself failed - not the same as "logged out".
    case unknown(String)

    var canSpawn: Bool {
        if case .loggedIn = self { return true }
        return false
    }

    var blockerText: String? {
        switch self {
        case .loggedIn:
            return nil
        case .loggedOut:
            return "The claude CLI is not signed in, so every bee would fail instantly. "
                + "Run `claude auth login` (or `claude setup-token`) in a terminal, then re-arm the hive."
        case .unknown(let why):
            return "Could not determine whether the claude CLI is signed in: \(why). "
                + "The hive will not spawn bees until this is resolved."
        }
    }
}

enum HiveAuthProbe {
    /// Parses `claude auth status` output. Split out so the parsing rule is
    /// testable without a CLI on the machine.
    static func parse(_ output: String) -> HiveAuthState {
        guard let data = output.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let loggedIn = object["loggedIn"] as? Bool else {
            let trimmed = output.trimmingCharacters(in: .whitespacesAndNewlines)
            return .unknown(trimmed.isEmpty ? "empty response" : String(trimmed.prefix(200)))
        }
        guard loggedIn else { return .loggedOut }
        return .loggedIn(method: object["authMethod"] as? String ?? "unknown")
    }

    static func check(executable: String) -> HiveAuthState {
        let result = HiveProcess.run(
            executable: executable,
            arguments: ["auth", "status"],
            timeout: 20
        )
        if result.timedOut { return .unknown("`claude auth status` timed out") }
        // A truncated read is not an answer. Without this the probe parses an
        // empty string, reports "empty response", and the operator is told the
        // CLI's sign-in state could not be determined when in fact the report
        // arrived and was discarded.
        if result.outputTruncated {
            return .unknown("`claude auth status` replied but its output was not read to the end")
        }

        // The exit code is not the answer: `claude auth status` exits 1 when
        // signed out and still prints a well-formed report on stdout. Reading
        // the code instead of the report turns a clear "signed out" into a
        // vague "could not determine".
        let parsed = parse(result.standardOutput)
        if case .unknown = parsed {} else { return parsed }

        guard result.exitCode != 0 else { return parsed }
        let stderr = result.standardError.trimmingCharacters(in: .whitespacesAndNewlines)
        let stdout = result.standardOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        let detail = !stderr.isEmpty ? stderr : (!stdout.isEmpty ? stdout : "exited \(result.exitCode) with no output")
        return .unknown(String(detail.prefix(200)))
    }
}

/// Small reference box so a concurrent reader can hand data back out of a
/// dispatch group without capturing an inout.
///
/// Every access takes the lock, because the caller reads the box on a bounded
/// schedule while the reader may still be appending to it. The point of the box
/// is that the bytes are IN it as they arrive rather than at the end: a reader
/// that publishes only when it finishes has nothing to publish on the path
/// where it does not finish.
final class UnsafeDataBox: @unchecked Sendable {
    private let lock = NSLock()
    private var storage = Data()
    private var sawEndOfFile = false

    var value: Data {
        lock.lock()
        defer { lock.unlock() }
        return storage
    }

    /// True only when the stream was read all the way to EOF. False means what
    /// is in the box may be a prefix - never that the child wrote nothing.
    var reachedEnd: Bool {
        lock.lock()
        defer { lock.unlock() }
        return sawEndOfFile
    }

    func append(_ chunk: Data) {
        lock.lock()
        storage.append(chunk)
        lock.unlock()
    }

    func markReachedEnd() {
        lock.lock()
        sawEndOfFile = true
        lock.unlock()
    }
}
