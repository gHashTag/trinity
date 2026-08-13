import Foundation

/// Durable hive state: one JSON document for tasks and policy, one append-only
/// JSONL for the audit trail. Both live under `.trinity/queen/` so the Zig
/// runtime and the Queen app read the same ground truth.
struct HiveStore {

    let stateRoot: String

    init(stateRoot: String = TrinityRuntimePaths.stateRoot) {
        self.stateRoot = stateRoot
    }

    var stateURL: URL {
        URL(fileURLWithPath: stateRoot).appendingPathComponent("queen/hive.json")
    }

    var eventsURL: URL {
        URL(fileURLWithPath: stateRoot).appendingPathComponent("queen/hive_events.jsonl")
    }

    private func ensureDirectory() {
        let directory = stateURL.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    }

    // MARK: - State

    func load() -> HiveState {
        guard let data = try? Data(contentsOf: stateURL) else { return HiveState() }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard var state = try? decoder.decode(HiveState.self, from: data) else {
            return HiveState()
        }
        state.policy = state.policy.sanitized()
        // The rate window is cut to the last hour here, at the one place every
        // load passes through. A window carried whole out of a file written
        // three days ago is not a measurement of this hour, and replaying it
        // would block the loop for an hour after every launch.
        state.spawnWindow = HiveState.prunedSpawnWindow(state.spawnWindow)
        // A bee cannot survive an app restart - anything left `running` in the
        // file is a crash artefact, and is returned to the queue rather than
        // silently counted as either a success or a failure.
        //
        // Unless the crash ate the task's last attempt. Requeued as `pending`
        // with attempts already at the budget, such a task is schedulable but
        // permanently excluded by the attempt filter, never reaches review, and
        // offers the operator no button at all: it is non-terminal and
        // invisible for the rest of the loop's life. Sending it to `toxic`
        // makes it terminal and says why.
        for index in state.tasks.indices where state.tasks[index].state == .running {
            if state.tasks[index].attempts >= state.policy.maxAttemptsPerTask {
                state.tasks[index].state = .toxic
                state.tasks[index].lastError =
                    "interrupted - the Queen restarted while this bee was working, and that was its "
                    + "last attempt. Rehabilitate the task to give it the budget back."
            } else {
                state.tasks[index].state = .pending
                state.tasks[index].lastError = "interrupted - Queen restarted while this bee was working"
            }
        }
        return state
    }

    @discardableResult
    func save(_ state: HiveState) -> Bool {
        ensureDirectory()
        var snapshot = state
        snapshot.updatedAt = Date()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(snapshot) else { return false }
        return (try? data.write(to: stateURL, options: .atomic)) != nil
    }

    // MARK: - Events

    /// Above this the audit log is rotated down to `retainedEventLines`.
    ///
    /// Transcripts are pruned on a policy; the audit log was not, and it is the
    /// file that grows fastest and forever. A loop stuck on one blocked
    /// decision writes an event every cycle - a few hundred kilobytes a month,
    /// monotone, and every launch of the Hive tab read the entire accumulated
    /// file into one Swift String on the main actor in order to show 60 rows.
    static let maxEventsFileBytes = 2 * 1024 * 1024
    static let retainedEventLines = 5_000
    /// Rotation cuts to half the ceiling rather than to the ceiling itself, so
    /// the next append does not immediately rewrite the file again.
    static var rotationTargetBytes: Int { maxEventsFileBytes / 2 }

    func append(_ event: HiveEvent) {
        ensureDirectory()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        guard let data = try? encoder.encode(event),
              var line = String(data: data, encoding: .utf8) else { return }
        line += "\n"
        guard let payload = line.data(using: .utf8) else { return }

        if let handle = try? FileHandle(forWritingTo: eventsURL) {
            defer { try? handle.close() }
            _ = try? handle.seekToEnd()
            try? handle.write(contentsOf: payload)
        } else {
            try? payload.write(to: eventsURL, options: .atomic)
        }
        rotateEventsIfNeeded()
    }

    /// Truncates the audit log from the front once it outgrows its ceiling.
    /// The rewrite is O(file), but it happens once per two megabytes rather
    /// than once per event.
    @discardableResult
    func rotateEventsIfNeeded() -> Bool {
        let size = (try? FileManager.default.attributesOfItem(atPath: eventsURL.path)[.size]) as? Int
        guard let size, size > Self.maxEventsFileBytes else { return false }
        guard let text = try? String(contentsOf: eventsURL, encoding: .utf8) else { return false }
        // Bounded by both counts: a line ceiling for an ordinary log of small
        // events, and a byte ceiling so a handful of very large records cannot
        // keep the file over its limit while still satisfying the line rule.
        var kept: [String] = []
        var bytes = 0
        for line in text.components(separatedBy: "\n").filter({ !$0.isEmpty }).reversed() {
            let size = line.utf8.count + 1
            if kept.count >= Self.retainedEventLines || bytes + size > Self.rotationTargetBytes { break }
            kept.append(line)
            bytes += size
        }
        let rewritten = kept.reversed().joined(separator: "\n") + "\n"
        guard let data = rewritten.data(using: .utf8) else { return false }
        return (try? data.write(to: eventsURL, options: .atomic)) != nil
    }

    /// Reads the newest events from the end of the file.
    ///
    /// Only the tail is read into memory. Asking for 60 rows must not cost a
    /// string the size of the whole audit trail.
    func recentEvents(limit: Int = 50) -> [HiveEvent] {
        guard let text = Self.tailText(of: eventsURL, lines: limit) else { return [] }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return text
            .components(separatedBy: "\n")
            // The file ends in a newline, so the last component is empty. Left
            // in, it takes one of the slots the caller asked for and the list
            // comes back one row short.
            .filter { !$0.isEmpty }
            .suffix(limit)
            .compactMap { line -> HiveEvent? in
                guard let data = line.data(using: .utf8) else { return nil }
                return try? decoder.decode(HiveEvent.self, from: data)
            }
            .reversed()
    }

    /// The last `lines` newline-separated records of a file, read backwards in
    /// chunks. Returns nil when the file cannot be opened at all.
    ///
    /// A partial record can be produced at the front of the window when the
    /// chunk boundary lands mid-line; it fails to decode and is dropped, which
    /// is why the caller reads one chunk more than it strictly needs.
    static func tailText(of url: URL, lines: Int, chunkSize: Int = 64 * 1024) -> String? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        guard let end = try? handle.seekToEnd() else { return nil }

        var offset = end
        var collected = Data()
        var newlines = 0
        // One extra line, so a record clipped by the chunk boundary cannot eat
        // one of the records the caller asked for.
        while offset > 0 && newlines <= lines + 1 {
            let step = UInt64(min(chunkSize, Int(offset)))
            offset -= step
            guard (try? handle.seek(toOffset: offset)) != nil,
                  let chunk = try? handle.read(upToCount: Int(step)) else { break }
            newlines += chunk.filter { $0 == UInt8(ascii: "\n") }.count
            collected = chunk + collected
        }
        return String(data: collected, encoding: .utf8)
    }
}

// MARK: - Retention

/// Prunes what the hive leaves behind. A loop that runs for weeks writes a
/// transcript per bee and a chat thread per task; without this the state
/// directory and the user's chat sidebar grow without bound.
struct HiveRetention {

    let stateRoot: String
    let threadsDirectory: URL?

    init(stateRoot: String = TrinityRuntimePaths.stateRoot, threadsDirectory: URL? = nil) {
        self.stateRoot = stateRoot
        self.threadsDirectory = threadsDirectory
    }

    struct Result: Equatable {
        var transcriptsRemoved = 0
        var threadsRemoved = 0
        var isEmpty: Bool { transcriptsRemoved == 0 && threadsRemoved == 0 }
    }

    /// Deletes bee transcripts and hive-authored chat threads older than
    /// `days`. Only files the hive itself wrote are considered: a thread is
    /// removed only if it decodes and carries the `hive` tag, so a hand-written
    /// conversation can never be caught by this.
    @discardableResult
    func prune(olderThanDays days: Int, now: Date = Date()) -> Result {
        var result = Result()
        let cutoff = now.addingTimeInterval(-Double(days) * 86_400)
        let fm = FileManager.default

        let transcripts = URL(fileURLWithPath: stateRoot)
            .appendingPathComponent("queen/hive", isDirectory: true)
        if let files = try? fm.contentsOfDirectory(
            at: transcripts,
            includingPropertiesForKeys: [.contentModificationDateKey]
        ) {
            for url in files where url.pathExtension == "jsonl" {
                let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                    .contentModificationDate
                guard let modified, modified < cutoff else { continue }
                if (try? fm.removeItem(at: url)) != nil { result.transcriptsRemoved += 1 }
            }
        }

        if let threadsDirectory,
           let files = try? fm.contentsOfDirectory(at: threadsDirectory, includingPropertiesForKeys: nil) {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            for url in files where url.pathExtension == "json" {
                guard let data = try? Data(contentsOf: url),
                      let thread = try? decoder.decode(ChatThread.self, from: data) else { continue }
                guard thread.tags.contains("hive"), !thread.isPinned else { continue }
                guard thread.updatedAt < cutoff else { continue }
                if (try? fm.removeItem(at: url)) != nil { result.threadsRemoved += 1 }
            }
        }

        return result
    }
}

// MARK: - Transcripts

/// Reads back what a bee wrote before the Queen lost sight of it.
///
/// `BeeRunner` streams every line to `.trinity/queen/hive/<sessionID>.jsonl`
/// as it arrives, so a bee interrupted by a crash, a rebuild or a Stop-all
/// leaves its own evidence on disk. That file is the only thing that can tell
/// a reservation apart from a real cost once the process is gone.
enum HiveTranscript {

    static func summarise(at url: URL) -> HiveTranscriptSummary {
        guard let text = try? String(contentsOf: url, encoding: .utf8) else { return .absent }
        var lines = 0
        var lastCost: Double?
        for line in text.components(separatedBy: "\n") where !line.trimmingCharacters(in: .whitespaces).isEmpty {
            lines += 1
            guard line.contains("total_cost_usd"),
                  let data = line.data(using: .utf8),
                  let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let cost = object["total_cost_usd"] as? Double else { continue }
            lastCost = cost
        }
        return HiveTranscriptSummary(lines: lines, lastCostUSD: lastCost)
    }
}

/// Whether a process id still names a running process.
///
/// `kill(pid, 0)` sends nothing; it only asks whether the process exists and
/// could be signalled. The hive deliberately stops there and never signals a
/// pid it read out of a file: pids are reused, and the process wearing this one
/// after a reboot is somebody else's. An orphan is therefore reported and
/// worked around - its worktree name is unique to its session, so no later bee
/// can be dispatched into the directory it is still writing to - rather than
/// killed on a guess.
enum HiveProcessLiveness {
    static func isAlive(_ pid: Int32) -> Bool {
        guard pid > 0 else { return false }
        return kill(pid, 0) == 0 || errno == EPERM
    }
}

// MARK: - Rate limiting

/// Rolling-window rate limiter for bee spawns.
///
/// Seeded from the persisted window and written back on every spawn, so the
/// bound it enforces - at most `maxBeesPerHour` spawns in any rolling hour -
/// is a statement about the machine rather than about one launch of the app.
///
/// It used to be in-memory only, justified as "a restart is a human-initiated
/// event that should not inherit an old window's debt". That justification
/// depends on a fact about the environment, and the environment stopped
/// supplying it: a watchdog relaunches this app within 60s of it dying, so a
/// crash-loop resets the window as fast as it can crash. The bound is now
/// correct by construction instead of correct by assumption, which is what
/// makes auto-resume on launch safe to add.
struct HiveRateLimiter {
    private(set) var spawnTimes: [Date] = []

    init(spawnTimes: [Date] = [], now: Date = Date()) {
        self.spawnTimes = spawnTimes
        prune(now)
    }

    mutating func record(_ now: Date = Date()) {
        spawnTimes.append(now)
        prune(now)
    }

    mutating func prune(_ now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-3600)
        spawnTimes.removeAll { $0 < cutoff }
    }

    func spawnsInLastHour(_ now: Date = Date()) -> Int {
        let cutoff = now.addingTimeInterval(-3600)
        return spawnTimes.filter { $0 >= cutoff }.count
    }

    func allows(limit: Int, now: Date = Date()) -> Bool {
        spawnsInLastHour(now) < limit
    }
}
