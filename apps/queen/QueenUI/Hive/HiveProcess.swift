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

    struct Result {
        let exitCode: Int32
        let standardOutput: String
        let standardError: String
        /// True when the process was killed because it outlived its timeout.
        let timedOut: Bool
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

        group.enter()
        DispatchQueue.global(qos: .utility).async {
            outData.value = outPipe.fileHandleForReading.readDataToEndOfFile()
            group.leave()
        }
        group.enter()
        DispatchQueue.global(qos: .utility).async {
            errData.value = errPipe.fileHandleForReading.readDataToEndOfFile()
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
        group.wait()

        return Result(
            exitCode: process.terminationStatus,
            standardOutput: String(data: outData.value, encoding: .utf8) ?? "",
            standardError: String(data: errData.value, encoding: .utf8) ?? "",
            timedOut: timedOut
        )
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

/// Small reference box so concurrent readers can hand data back out of a
/// dispatch group without capturing an inout.
final class UnsafeDataBox: @unchecked Sendable {
    var value = Data()
}
