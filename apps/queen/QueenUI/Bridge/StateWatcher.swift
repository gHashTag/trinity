import Foundation
import Combine

/// Watches .trinity/ JSON files for changes via DispatchSource.
/// Single instance — injected via @EnvironmentObject from App.swift.
/// Uses Combine debounce (250ms) to coalesce burst writes from Queen daemon.
final class StateWatcher: ObservableObject {
    @Published var ouroborosState: OuroborosState?
    @Published var heartbeats: [AgentHeartbeat] = []
    @Published var farmEvents: [FarmEvent] = []
    @Published var queenSenses: QueenSenses?
    @Published var queenState: QueenDaemonState?
    @Published var auditEntries: [AuditEntry] = []
    @Published var eventStream: [AgentEvent] = []
    @Published var todos: [QueenTodo] = []
    @Published var swarmState: SwarmState?
    @Published var selectedEventId: String?    // Time navigation: selected event

    private var sources: [String: DispatchSourceFileSystemObject] = [:]
    private var fileDescriptors: [String: Int32] = [:]
    private let trinityPath: String
    private let queue = DispatchQueue(label: "trinity.state.watcher")
    private var eventLogOffset: UInt64 = 0
    private var pendingEvents: [AgentEvent] = []

    // Combine debounce: coalesce burst file changes into 1 reload
    private let changeSubject = PassthroughSubject<Void, Never>()
    private var debounceCancellable: AnyCancellable?
    // Frame-rate limiter: flush pending events at ~30fps max
    private let eventFlushSubject = PassthroughSubject<Void, Never>()
    private var eventFlushCancellable: AnyCancellable?

    init(trinityPath: String? = nil) {
        self.trinityPath = trinityPath ?? Self.findTrinityPath()

        // 250ms debounce: Queen daemon writes 3-5 files per cycle in ~200ms
        debounceCancellable = changeSubject
            .debounce(for: .milliseconds(250), scheduler: RunLoop.main)
            .sink { [weak self] in self?.reload() }

        // 33ms throttle (~30fps): batch event stream updates to avoid layout thrashing
        eventFlushCancellable = eventFlushSubject
            .throttle(for: .milliseconds(33), scheduler: RunLoop.main, latest: true)
            .sink { [weak self] in self?.flushPendingEvents() }

        reload()
        startWatching()
    }

    deinit {
        debounceCancellable?.cancel()
        eventFlushCancellable?.cancel()
        stopWatching()
    }

    private static func findTrinityPath() -> String {
        let cwd = FileManager.default.currentDirectoryPath
        return "\(cwd)/.trinity"
    }

    func reload() {
        loadOuroboros()
        loadHeartbeats()
        loadFarmEvents()
        loadQueenSenses()
        loadQueenState()
        loadAuditEntries()
        loadEventStream()
        loadTodos()
        loadSwarmState()
    }

    // MARK: - Loaders

    private func loadOuroboros() {
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: "\(trinityPath)/ouroboros_state.json")) else { return }
        let state = try? JSONDecoder().decode(OuroborosState.self, from: data)
        DispatchQueue.main.async { self.ouroborosState = state }
    }

    private func loadHeartbeats() {
        var beats: [AgentHeartbeat] = []

        for agent in ["mu", "scholar"] {
            let path = "\(trinityPath)/\(agent)/heartbeat.json"
            guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { continue }
            if var beat = try? JSONDecoder().decode(AgentHeartbeat.self, from: data) {
                beat.name = agent
                beats.append(beat)
            }
        }

        DispatchQueue.main.async { self.heartbeats = beats }
    }

    private func loadFarmEvents() {
        let path = "\(trinityPath)/farm/events.jsonl"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }

        let lines = content.components(separatedBy: "\n").suffix(20)
        let decoder = JSONDecoder()
        var events: [FarmEvent] = []

        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8),
               let event = try? decoder.decode(FarmEvent.self, from: data) {
                events.append(event)
            }
        }

        DispatchQueue.main.async { self.farmEvents = events }
    }

    private func loadQueenSenses() {
        let path = "\(trinityPath)/queen/senses.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        let senses = try? JSONDecoder().decode(QueenSenses.self, from: data)
        DispatchQueue.main.async { self.queenSenses = senses }
    }

    private func loadQueenState() {
        let path = "\(trinityPath)/queen_state.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        let state = try? JSONDecoder().decode(QueenDaemonState.self, from: data)
        DispatchQueue.main.async { self.queenState = state }
    }

    private func loadAuditEntries() {
        let path = "\(trinityPath)/queen/audit.jsonl"
        guard let content = try? String(contentsOfFile: path, encoding: .utf8) else { return }
        let lines = content.components(separatedBy: "\n").suffix(20)
        let decoder = JSONDecoder()
        var entries: [AuditEntry] = []
        for line in lines where !line.isEmpty {
            if let data = line.data(using: .utf8),
               let entry = try? decoder.decode(AuditEntry.self, from: data) {
                entries.append(entry)
            }
        }
        DispatchQueue.main.async { self.auditEntries = entries }
    }

    private func loadEventStream() {
        let path = "\(trinityPath)/event_log.jsonl"
        guard let fh = FileHandle(forReadingAtPath: path) else { return }
        defer { try? fh.close() }

        try? fh.seek(toOffset: eventLogOffset)
        guard let newData = try? fh.readToEnd(), !newData.isEmpty else { return }

        eventLogOffset += UInt64(newData.count)

        guard let newContent = String(data: newData, encoding: .utf8) else { return }
        let decoder = JSONDecoder()
        var newEvents: [AgentEvent] = []
        for line in newContent.components(separatedBy: "\n") where !line.isEmpty {
            if let data = line.data(using: .utf8),
               let ev = try? decoder.decode(AgentEvent.self, from: data) {
                newEvents.append(ev)
            }
        }

        guard !newEvents.isEmpty else { return }
        // Buffer events and signal throttled flush (~30fps)
        pendingEvents.append(contentsOf: newEvents)
        eventFlushSubject.send()
    }

    /// Flush buffered events to @Published at throttled rate (~30fps)
    private func flushPendingEvents() {
        guard !pendingEvents.isEmpty else { return }
        let batch = pendingEvents
        pendingEvents.removeAll()
        eventStream.append(contentsOf: batch)
        if eventStream.count > 200 {
            eventStream = Array(eventStream.suffix(200))
        }
    }

    private func loadTodos() {
        let path = "\(trinityPath)/queen/todos.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        let file = try? JSONDecoder().decode(QueenTodosFile.self, from: data)
        DispatchQueue.main.async { self.todos = file?.items ?? [] }
    }

    private func loadSwarmState() {
        let path = "\(trinityPath)/swarm_state.json"
        guard let data = try? Data(contentsOf: URL(fileURLWithPath: path)) else { return }
        let state = try? JSONDecoder().decode(SwarmState.self, from: data)
        DispatchQueue.main.async { self.swarmState = state }
    }

    // MARK: - User Actions (write back to .trinity/)

    /// Mid-flight steering: write user message to .trinity/queen/user_input.json
    /// Queen Zig daemon reads this file each cycle and incorporates the message.
    func sendUserInput(_ message: String) {
        let path = "\(trinityPath)/queen/user_input.json"
        let ts = Int(Date().timeIntervalSince1970)
        let json = "{\"ts\":\(ts),\"message\":\"\(message.replacingOccurrences(of: "\"", with: "\\\""))\"}"
        try? json.data(using: .utf8)?.write(to: URL(fileURLWithPath: path))
    }

    /// Editable plan: toggle a todo's status and write back to todos.json
    func toggleTodo(_ todoId: String) {
        guard let idx = todos.firstIndex(where: { $0.id == todoId }) else { return }
        let old = todos[idx]
        let newStatus = old.status == "done" ? "pending" : "done"
        todos[idx] = QueenTodo(text: old.text, source: old.source, status: newStatus, id: old.id)
        writeTodosFile()
    }

    private func writeTodosFile() {
        let path = "\(trinityPath)/queen/todos.json"
        let file = QueenTodosFile(generated_at: Int(Date().timeIntervalSince1970), items: todos)
        guard let data = try? JSONEncoder().encode(file) else { return }
        try? data.write(to: URL(fileURLWithPath: path))
    }

    // MARK: - Time Navigation

    /// Get senses snapshot closest to a given event timestamp
    func sensesAtEvent(_ event: AgentEvent) -> String {
        guard let ts = event.ts else { return "" }
        var parts: [String] = []
        if let s = queenSenses {
            parts.append("Build: \(s.build_ok == true ? "OK" : "FAIL")")
            parts.append("Score: \(String(format: "%.1f", s.ouroboros_score ?? 0))")
            parts.append("Dirty: \(s.dirty_files ?? 0)")
            parts.append("Issues: \(s.open_issues ?? 0)")
        }
        let date = Date(timeIntervalSince1970: TimeInterval(ts))
        let fmt = DateFormatter()
        fmt.dateFormat = "HH:mm:ss"
        parts.insert(fmt.string(from: date), at: 0)
        return parts.joined(separator: " | ")
    }

    // MARK: - File Watching (rename-safe)

    private var watchedPaths: [String] {
        [
            "\(trinityPath)/ouroboros_state.json",
            "\(trinityPath)/mu/heartbeat.json",
            "\(trinityPath)/scholar/heartbeat.json",
            "\(trinityPath)/farm/events.jsonl",
            "\(trinityPath)/queen/senses.json",
            "\(trinityPath)/queen_state.json",
            "\(trinityPath)/queen/audit.jsonl",
            "\(trinityPath)/event_log.jsonl",
            "\(trinityPath)/queen/todos.json",
            "\(trinityPath)/swarm_state.json",
            "\(trinityPath)/queen/user_input.json",
        ]
    }

    private func startWatching() {
        for path in watchedPaths {
            registerSource(for: path)
        }
    }

    /// Register (or re-register) a DispatchSource for a given path.
    /// On `.rename` event, the old fd is stale — we close it and reopen.
    private func registerSource(for path: String) {
        // Clean up any existing source for this path
        if let oldSource = sources[path] {
            oldSource.cancel()
        }
        if let oldFd = fileDescriptors[path] {
            close(oldFd)
        }

        let fd = open(path, O_EVTONLY)
        guard fd >= 0 else {
            sources[path] = nil
            fileDescriptors[path] = nil
            return
        }
        fileDescriptors[path] = fd

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .delete],
            queue: queue
        )

        source.setEventHandler { [weak self] in
            guard let self else { return }
            let events = source.data

            if events.contains(.rename) || events.contains(.delete) {
                // File was replaced (atomic write) or deleted.
                // Old fd now points to deleted inode — cancel triggers close via setCancelHandler.
                source.cancel()
                self.sources[path] = nil
                self.fileDescriptors[path] = nil

                // Small delay: let the new file appear on disk
                self.queue.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                    self?.registerSource(for: path)
                    self?.changeSubject.send()
                }
            } else {
                self.changeSubject.send()
            }
        }

        source.setCancelHandler { [fd] in
            Darwin.close(fd)
        }

        source.resume()
        sources[path] = source
    }

    private func stopWatching() {
        for (_, source) in sources {
            source.cancel()  // setCancelHandler closes the fd
        }
        sources.removeAll()
        fileDescriptors.removeAll()
    }
}
