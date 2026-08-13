import Foundation

// ===========================================================================
// BEE - one Claude Code session, one task, one chat.
//
// The Queen spawns `claude -p` with a fixed session id, so the work she starts
// is a real, resumable conversation the user can open, read and continue.
// ===========================================================================

enum BeeStatus: String, Equatable {
    case starting
    case working
    case succeeded
    case failed
    case cancelled
    case timedOut

    var label: String {
        switch self {
        case .starting: return "STARTING"
        case .working: return "WORKING"
        case .succeeded: return "DONE"
        case .failed: return "FAILED"
        case .cancelled: return "CANCELLED"
        case .timedOut: return "TIMED OUT"
        }
    }

    var isTerminal: Bool {
        self != .starting && self != .working
    }
}

/// One decoded line of a bee's stream.
struct BeeEvent: Identifiable, Equatable {
    let id = UUID()
    let timestamp: Date
    let kind: Kind
    let text: String

    enum Kind: Equatable {
        case system
        case assistant
        case tool(String)
        case toolResult
        case result(success: Bool)
        case raw
    }
}

/// Outcome handed back to the orchestrator when the process exits.
struct BeeOutcome: Equatable {
    var status: BeeStatus
    var summary: String
    var costUSD: Double?
    var durationMs: Int?
    var sessionID: String?
}

/// Live, observable state of one bee.
@MainActor
final class Bee: ObservableObject, Identifiable {
    let taskID: String
    let title: String
    let module: String
    let sessionID: String
    let startedAt: Date
    let branch: String?

    @Published private(set) var status: BeeStatus = .starting
    @Published private(set) var lastLine: String = "spawning..."
    @Published private(set) var toolCalls: Int = 0
    @Published private(set) var events: [BeeEvent] = []
    @Published private(set) var outcome: BeeOutcome?

    nonisolated var id: String { taskID }

    /// Capped so a long-running bee cannot grow the UI's memory without bound.
    private let maxRetainedEvents = 200

    private let runner: BeeRunner

    init(task: HiveTask, sessionID: String, branch: String?, runner: BeeRunner) {
        self.taskID = task.id
        self.title = task.title
        self.module = task.module
        self.sessionID = sessionID
        self.branch = branch
        self.startedAt = Date()
        self.runner = runner
    }

    var elapsed: TimeInterval { Date().timeIntervalSince(startedAt) }

    func append(_ event: BeeEvent) {
        events.append(event)
        if events.count > maxRetainedEvents {
            events.removeFirst(events.count - maxRetainedEvents)
        }
        if case .tool = event.kind { toolCalls += 1 }
        if !event.text.isEmpty {
            lastLine = String(event.text.prefix(240))
        }
        if status == .starting { status = .working }
    }

    func finish(_ outcome: BeeOutcome) {
        self.outcome = outcome
        self.status = outcome.status
        if !outcome.summary.isEmpty {
            lastLine = String(outcome.summary.prefix(240))
        }
    }

    func cancel() {
        runner.terminate()
        if !status.isTerminal { status = .cancelled }
    }
}

// MARK: - Runner

/// Spawns and drains one `claude -p` process.
///
/// Not an actor: `Process` and its pipe handlers are callback-driven, so the
/// runner keeps its own serial queue and hops results to the main actor.
final class BeeRunner: @unchecked Sendable {

    struct Configuration {
        var executable: String
        var workingDirectory: String
        var prompt: String
        var sessionID: String
        var model: String
        var permissionMode: String
        var maxBudgetUSD: Double
        var timeoutSeconds: Int
        var worktreeName: String?
        var displayName: String
    }

    private let configuration: Configuration
    private let queue = DispatchQueue(label: "com.trinity.queen.bee", qos: .utility)
    private var process: Process?
    private var pendingLine = ""
    private let lock = NSLock()

    init(configuration: Configuration) {
        self.configuration = configuration
    }

    /// Command line handed to Claude Code. Pure, so tests can assert on it
    /// without spawning anything.
    static func arguments(for configuration: Configuration) -> [String] {
        var args: [String] = [
            "-p", configuration.prompt,
            "--output-format", "stream-json",
            "--verbose",
            "--session-id", configuration.sessionID,
            "--permission-mode", configuration.permissionMode,
            "--model", configuration.model,
            "--max-budget-usd", String(format: "%.2f", configuration.maxBudgetUSD),
            "-n", configuration.displayName,
        ]
        if let worktree = configuration.worktreeName {
            args.append(contentsOf: ["--worktree", worktree])
        }
        return args
    }

    /// Starts the bee. `onEvent` fires per decoded stream line, `onFinish`
    /// exactly once. Both are delivered on the main actor.
    func start(
        onEvent: @escaping @MainActor (BeeEvent) -> Void,
        onFinish: @escaping @MainActor (BeeOutcome) -> Void
    ) {
        let configuration = self.configuration
        let transcriptURL = Self.transcriptURL(for: configuration.sessionID)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: configuration.executable)
        process.arguments = Self.arguments(for: configuration)
        process.currentDirectoryURL = URL(fileURLWithPath: configuration.workingDirectory)

        var environment = ProcessInfo.processInfo.environment
        // Marks the session as hive-spawned for anything downstream that cares.
        environment["TRINITY_HIVE_TASK"] = configuration.displayName
        process.environment = environment

        let outPipe = Pipe()
        let errPipe = Pipe()
        process.standardOutput = outPipe
        process.standardError = errPipe

        let errorBox = UnsafeDataBox()
        let resultBox = ResultBox()

        outPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            guard let self else { return }
            for line in self.split(chunk) {
                Self.appendTranscript(line, to: transcriptURL)
                guard let event = Self.decode(line) else { continue }
                if case .result(let success) = event.kind {
                    resultBox.record(line: line, success: success)
                }
                Task { @MainActor in onEvent(event) }
            }
        }

        errPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            guard !data.isEmpty else { return }
            errorBox.value.append(data)
        }

        process.terminationHandler = { finished in
            outPipe.fileHandleForReading.readabilityHandler = nil
            errPipe.fileHandleForReading.readabilityHandler = nil

            let stderrText = String(data: errorBox.value, encoding: .utf8) ?? ""
            let outcome = Self.outcome(
                exitCode: finished.terminationStatus,
                resultBox: resultBox,
                stderr: stderrText,
                fallbackSessionID: configuration.sessionID
            )
            Task { @MainActor in onFinish(outcome) }
        }

        do {
            try process.run()
        } catch {
            Task { @MainActor in
                onFinish(
                    BeeOutcome(
                        status: .failed,
                        summary: "could not launch claude: \(error.localizedDescription)",
                        costUSD: nil,
                        durationMs: nil,
                        sessionID: configuration.sessionID
                    )
                )
            }
            return
        }

        lock.lock()
        self.process = process
        lock.unlock()

        // Wall-clock guard, independent of anything Claude Code reports.
        queue.asyncAfter(deadline: .now() + .seconds(configuration.timeoutSeconds)) { [weak self] in
            guard let self else { return }
            self.lock.lock()
            let running = self.process?.isRunning ?? false
            self.lock.unlock()
            if running {
                resultBox.markTimedOut()
                self.terminate()
            }
        }
    }

    /// The live child's pid, persisted at dispatch so a reservation found in
    /// the state file after a restart can be told apart from one whose bee is
    /// still running.
    var processIdentifier: Int32? {
        lock.lock(); defer { lock.unlock() }
        guard let process, process.isRunning else { return nil }
        return process.processIdentifier
    }

    func terminate() {
        lock.lock()
        let process = self.process
        lock.unlock()
        guard let process, process.isRunning else { return }
        process.terminate()
        // SIGTERM is a request; SIGKILL is not. The escalation runs on the
        // runner's own queue so the caller - the main actor, when an operator
        // presses Stop all bees - is never held waiting for a child that has
        // decided to ignore SIGTERM.
        let grace = Int(HiveProcess.terminationGraceSeconds * 1000)
        queue.asyncAfter(deadline: .now() + .milliseconds(grace)) {
            guard process.isRunning else { return }
            kill(process.processIdentifier, SIGKILL)
        }
    }

    // MARK: - Line assembly

    /// Claude Code emits one JSON object per line, but a pipe read can split
    /// mid-line - so partial lines are carried to the next chunk.
    private func split(_ chunk: String) -> [String] {
        lock.lock()
        pendingLine += chunk
        var parts = pendingLine.components(separatedBy: "\n")
        pendingLine = parts.removeLast()
        lock.unlock()
        return parts.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    // MARK: - Decoding

    static func decode(_ line: String) -> BeeEvent? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let type = object["type"] as? String else {
            return BeeEvent(timestamp: Date(), kind: .raw, text: String(line.prefix(240)))
        }

        switch type {
        case "system":
            let subtype = object["subtype"] as? String ?? "system"
            return BeeEvent(timestamp: Date(), kind: .system, text: subtype)

        case "assistant":
            guard let message = object["message"] as? [String: Any],
                  let content = message["content"] as? [[String: Any]] else {
                return BeeEvent(timestamp: Date(), kind: .assistant, text: "")
            }
            for block in content {
                let blockType = block["type"] as? String
                if blockType == "tool_use", let name = block["name"] as? String {
                    return BeeEvent(timestamp: Date(), kind: .tool(name), text: name)
                }
            }
            let text = content
                .filter { ($0["type"] as? String) == "text" }
                .compactMap { $0["text"] as? String }
                .joined(separator: " ")
            return BeeEvent(timestamp: Date(), kind: .assistant, text: text)

        case "user":
            return BeeEvent(timestamp: Date(), kind: .toolResult, text: "")

        case "result":
            let isError = object["is_error"] as? Bool ?? false
            let subtype = object["subtype"] as? String ?? ""
            let text = object["result"] as? String ?? subtype
            return BeeEvent(
                timestamp: Date(),
                kind: .result(success: !isError && subtype == "success"),
                text: text
            )

        default:
            return nil
        }
    }

    /// Decides the bee's fate from the exit code and the terminal `result`
    /// line. A missing result line is a failure, never an assumed success.
    static func outcome(
        exitCode: Int32,
        resultBox: ResultBox,
        stderr: String,
        fallbackSessionID: String
    ) -> BeeOutcome {
        if resultBox.timedOut {
            return BeeOutcome(
                status: .timedOut,
                summary: "killed after exceeding its wall-clock budget",
                costUSD: resultBox.costUSD,
                durationMs: resultBox.durationMs,
                sessionID: fallbackSessionID
            )
        }

        guard let line = resultBox.line,
              let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return BeeOutcome(
                status: .failed,
                summary: detail.isEmpty
                    ? "exited \(exitCode) without reporting a result"
                    : String(detail.suffix(400)),
                costUSD: nil,
                durationMs: nil,
                sessionID: fallbackSessionID
            )
        }

        let isError = object["is_error"] as? Bool ?? false
        let subtype = object["subtype"] as? String ?? ""
        let summary = object["result"] as? String ?? subtype
        let cost = object["total_cost_usd"] as? Double
        let duration = object["duration_ms"] as? Int
        let sessionID = object["session_id"] as? String ?? fallbackSessionID

        let succeeded = !isError && subtype == "success" && exitCode == 0
        return BeeOutcome(
            status: succeeded ? .succeeded : .failed,
            summary: summary,
            costUSD: cost,
            durationMs: duration,
            sessionID: sessionID
        )
    }

    // MARK: - Transcript

    /// Durable, plain-text record of every bee, outside the app bundle, so the
    /// work survives a crash and is readable by the Zig side.
    static func transcriptURL(for sessionID: String) -> URL {
        let directory = URL(fileURLWithPath: TrinityRuntimePaths.stateRoot)
            .appendingPathComponent("queen/hive", isDirectory: true)
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory.appendingPathComponent("\(sessionID).jsonl")
    }

    static func appendTranscript(_ line: String, to url: URL) {
        guard let data = (line + "\n").data(using: .utf8) else { return }
        if let handle = try? FileHandle(forWritingTo: url) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: data)
        } else {
            try? data.write(to: url, options: .atomic)
        }
    }
}

/// Carries the terminal `result` line across threads.
final class ResultBox: @unchecked Sendable {
    private let lock = NSLock()
    private var _line: String?
    private var _timedOut = false

    var line: String? {
        lock.lock(); defer { lock.unlock() }
        return _line
    }

    var timedOut: Bool {
        lock.lock(); defer { lock.unlock() }
        return _timedOut
    }

    var costUSD: Double? { field("total_cost_usd") as? Double }
    var durationMs: Int? { field("duration_ms") as? Int }

    func record(line: String, success: Bool) {
        lock.lock(); defer { lock.unlock() }
        _line = line
    }

    func markTimedOut() {
        lock.lock(); defer { lock.unlock() }
        _timedOut = true
    }

    private func field(_ key: String) -> Any? {
        guard let line,
              let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object[key]
    }
}
