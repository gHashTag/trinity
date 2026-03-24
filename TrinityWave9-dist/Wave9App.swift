import SwiftUI
import Foundation

// MARK: - Docker Manager (direct docker compose)
class DockerManager: ObservableObject {
    @Published var isDockerAvailable: Bool = false
    @Published var isDockerRunning: Bool = false
    @Published var logs: [LogEntry] = []
    @Published var devices: [DeviceState] = []
    @Published var isOperating: Bool = false

    let composeFile: String

    init(composeFile: String) {
        self.composeFile = composeFile
        // Initialize 20 devices to match tri's compose file
        self.devices = (1...20).map { id in
            DeviceState(id: id, name: "Worker \(id)", workers: 8, isRunning: false)
        }
        checkDocker()
        refreshStatus()
    }

    struct LogEntry: Identifiable {
        let id = UUID()
        let timestamp: Date
        let message: String
        let type: LogType

        enum LogType {
            case info, success, error, warning
        }
    }

    struct DeviceState: Identifiable {
        let id: Int
        let name: String
        let workers: Int
        var isRunning: Bool
        var uptime: String?
        var lastError: String?

        var idHash: Int { id }
    }

    func checkDocker() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["info"]

        do {
            try task.run()
            task.waitUntilExit()
            isDockerAvailable = (task.terminationStatus == 0)
            isDockerRunning = isDockerAvailable
        } catch {
            isDockerAvailable = false
            isDockerRunning = false
            addLog("Docker недоступен: \(error.localizedDescription)", type: .error)
        }
    }

    func refreshStatus() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["compose", "-f", composeFile, "ps", "--format", "json"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        task.terminationHandler = { _ in
            guard let data = try? pipe.fileHandleForReading.readToEnd(),
                  let output = String(data: data, encoding: .utf8) else {
                DispatchQueue.main.async {
                    self.addLog("Не удалось получить статус", type: .error)
                }
                return
            }

            DispatchQueue.main.async {
                self.parseStatus(output)
            }
        }

        do {
            try task.run()
        } catch {
            addLog("Ошибка проверки статуса: \(error)", type: .error)
        }
    }

    private func parseStatus(_ output: String) {
        // Reset running state
        for i in devices.indices {
            devices[i].isRunning = false
        }

        let lines = output.split(separator: "\n")
        for line in lines {
            guard let data = line.data(using: .utf8),
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let name = json["Name"] as? String,
                  let state = json["State"] as? String else { continue }

            // Extract worker ID from name like "wave9-w1" to "wave9-w20"
            for i in 1...20 {
                if name == "wave9-w\(i)" {
                    if let index = devices.firstIndex(where: { $0.id == i }) {
                        devices[index].isRunning = (state == "running")
                    }
                    break
                }
            }
        }

        addLog("Статус обновлен", type: .info)
    }

    func startWorker(id: Int) {
        isOperating = true
        addLog("Запуск Worker \(id)...", type: .info)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["compose", "-f", composeFile, "up", "-d", "wave9-w\(id)"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                let success = (task.terminationStatus == 0)
                if success {
                    if let index = self.devices.firstIndex(where: { $0.id == id }) {
                        self.devices[index].isRunning = true
                        self.devices[index].lastError = nil
                    }
                    self.addLog("Worker \(id) запущен ✓", type: .success)
                } else {
                    if let index = self.devices.firstIndex(where: { $0.id == id }) {
                        self.devices[index].lastError = "Ошибка запуска"
                    }
                    self.addLog("Worker \(id) не запустился ✗", type: .error)
                }
                self.isOperating = false
                self.refreshStatus()
            }
        }

        do {
            try task.run()
        } catch {
            addLog("Ошибка запуска Worker \(id): \(error)", type: .error)
            isOperating = false
        }
    }

    func stopWorker(id: Int) {
        isOperating = true
        addLog("Остановка Worker \(id)...", type: .info)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["compose", "-f", composeFile, "stop", "wave9-w\(id)"]

        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                let success = (task.terminationStatus == 0)
                if success {
                    if let index = self.devices.firstIndex(where: { $0.id == id }) {
                        self.devices[index].isRunning = false
                    }
                    self.addLog("Worker \(id) остановлен ✓", type: .success)
                } else {
                    self.addLog("Worker \(id) не остановился", type: .error)
                }
                self.isOperating = false
                self.refreshStatus()
            }
        }

        do {
            try task.run()
        } catch {
            addLog("Ошибка остановки Worker \(id): \(error)", type: .error)
            isOperating = false
        }
    }

    func startAll() {
        isOperating = true
        addLog("Запуск всех воркеров...", type: .info)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["compose", "-f", composeFile, "up", "-d"]

        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                let success = (task.terminationStatus == 0)
                if success {
                    for i in self.devices.indices {
                        self.devices[i].isRunning = true
                        self.devices[i].lastError = nil
                    }
                    self.addLog("Все воркеры запущены ✓", type: .success)
                } else {
                    self.addLog("Ошибка запуска всех воркеров", type: .error)
                }
                self.isOperating = false
                self.refreshStatus()
            }
        }

        do {
            try task.run()
        } catch {
            addLog("Ошибка: \(error)", type: .error)
            isOperating = false
        }
    }

    func stopAll() {
        isOperating = true
        addLog("Остановка всех воркеров...", type: .info)

        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["compose", "-f", composeFile, "down"]

        task.terminationHandler = { _ in
            DispatchQueue.main.async {
                let success = (task.terminationStatus == 0)
                if success {
                    for i in self.devices.indices {
                        self.devices[i].isRunning = false
                    }
                    self.addLog("Все воркеры остановлены ✓", type: .success)
                } else {
                    self.addLog("Ошибка остановки", type: .error)
                }
                self.isOperating = false
                self.refreshStatus()
            }
        }

        do {
            try task.run()
        } catch {
            addLog("Ошибка: \(error)", type: .error)
            isOperating = false
        }
    }

    func streamLogs() {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/docker")
        task.arguments = ["compose", "-f", composeFile, "logs", "-f", "--tail", "20"]

        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = pipe

        let handle = pipe.fileHandleForReading
        handle.readabilityHandler = { [weak self] _ in
            guard let data = try? handle.readToEnd(),
                  let output = String(data: data, encoding: .utf8) else { return }

            for line in output.components(separatedBy: .newlines) where !line.isEmpty {
                DispatchQueue.main.async {
                    self?.addLog(line, type: .info)
                }
            }
        }

        do {
            try task.run()
            addLog("Поток логов запущен", type: .info)
        } catch {
            addLog("Ошибка запуска логов: \(error)", type: .error)
        }
    }

    private func addLog(_ message: String, type: LogEntry.LogType) {
        let entry = LogEntry(timestamp: Date(), message: message, type: type)
        logs.append(entry)
        if logs.count > 100 {
            logs.removeFirst(logs.count - 100)
        }
    }

    var totalWorkers: Int {
        devices.reduce(0) { $0 + $1.workers }
    }

    var runningCount: Int {
        devices.filter { $0.isRunning }.count
    }
}

// MARK: - Single View App
struct Wave9SingleView: View {
    @StateObject private var docker: DockerManager
    @State private var autoScroll = false

    init() {
        // Use tri's compose file directly
        let appDir = Bundle.main.bundlePath as NSString
        let projectDir = (appDir.deletingLastPathComponent as NSString).deletingLastPathComponent
        let composeFile = "\(projectDir)/deploy/docker/docker-compose.wave9.yml"

        _docker = StateObject(wrappedValue: DockerManager(composeFile: composeFile))
    }

    var body: some View {
        HSplitView {
            // Left panel - Workers grid
            VStack(spacing: 0) {
                // Header with stats
                HStack(spacing: 20) {
                    StatCard(title: "Всего", value: "\(docker.totalWorkers)", icon: "cpu", color: .blue)
                    StatCard(title: "Работает", value: "\(docker.runningCount)", icon: "checkmark.circle.fill", color: .green)
                    StatCard(title: "Docker", value: docker.isDockerRunning ? "OK" : "OFF", icon: docker.isDockerRunning ? "power.circle.fill" : "power.circle", color: docker.isDockerRunning ? .green : .red)

                    Spacer()

                    Button(action: { docker.startAll() }) {
                        Label("Запустить все", systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(docker.isOperating || !docker.isDockerRunning)

                    Button(action: { docker.stopAll() }) {
                        Label("Остановить все", systemImage: "stop.fill")
                    }
                    .buttonStyle(.bordered)
                    .disabled(docker.isOperating)

                    Button(action: { docker.refreshStatus() }) {
                        Label("", systemImage: "arrow.clockwise")
                    }
                    .buttonStyle(.bordered)
                    .disabled(docker.isOperating)
                }
                .padding(16)
                .background(Color(.controlBackgroundColor))

                Divider()

                // Workers grid
                ScrollView {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 180))], spacing: 16) {
                        ForEach(docker.devices) { device in
                            WorkerCard(
                                device: device,
                                isOperating: docker.isOperating,
                                onStart: { docker.startWorker(id: device.id) },
                                onStop: { docker.stopWorker(id: device.id) }
                            )
                        }
                    }
                    .padding(16)
                }
            }
            .frame(minWidth: 400)

            // Right panel - Logs
            VStack(spacing: 0) {
                HStack {
                    Text("Логи")
                        .font(.headline)
                    Spacer()
                    Button("Очистить") { docker.logs.removeAll() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    Toggle("Авто-скролл", isOn: $autoScroll)
                        .controlSize(.small)
                }
                .padding(12)
                .background(Color(.controlBackgroundColor))

                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 4) {
                            ForEach(docker.logs) { log in
                                LogRow(log: log)
                                    .id(log.id)
                            }
                        }
                        .padding(8)
                    }
                    .frame(minWidth: 300)
                    .onChange(of: docker.logs.count) { oldValue, newValue in
                        if autoScroll, let lastLog = docker.logs.last {
                            withAnimation {
                                proxy.scrollTo(lastLog.id, anchor: .bottom)
                            }
                        }
                    }
                }
            }
            .frame(minWidth: 300)
        }
        .frame(minWidth: 800, minHeight: 500)
        .onAppear {
            docker.refreshStatus()
        }
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(color)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.caption2).foregroundColor(.secondary)
                Text(value).font(.headline).bold()
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 8)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

struct WorkerCard: View {
    let device: DockerManager.DeviceState
    let isOperating: Bool
    let onStart: () -> Void
    let onStop: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: device.isRunning ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundColor(device.isRunning ? .green : .gray)
                Text(device.name)
                    .font(.headline)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("\(device.workers) воркеров")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }

                if device.isRunning {
                    if let uptime = device.uptime {
                        Text(uptime)
                            .font(.caption2)
                            .foregroundColor(.green)
                    }
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }

            Button(action: device.isRunning ? onStop : onStart) {
                HStack {
                    Image(systemName: device.isRunning ? "stop.fill" : "play.fill")
                    Text(device.isRunning ? "Остановить" : "Запустить")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(device.isRunning ? .red : .green)
            .controlSize(.small)
            .disabled(isOperating)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(12)
        .shadow(radius: 1)
    }
}

struct LogRow: View {
    let log: DockerManager.LogEntry

    var body: some View {
        HStack(alignment: .top, spacing: 6) {
            Text(formatTime(log.timestamp))
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
                .frame(width: 50, alignment: .leading)

            Image(systemName: iconForType(log.type))
                .font(.caption2)
                .foregroundColor(colorForType(log.type))
                .frame(width: 12)

            Text(log.message)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(colorForType(log.type))
                .textSelection(.enabled)
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm:ss"
        return formatter.string(from: date)
    }

    private func iconForType(_ type: DockerManager.LogEntry.LogType) -> String {
        switch type {
        case .info: return "info.circle.fill"
        case .success: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        }
    }

    private func colorForType(_ type: DockerManager.LogEntry.LogType) -> Color {
        switch type {
        case .info: return .primary
        case .success: return .green
        case .error: return .red
        case .warning: return .orange
        }
    }
}

// MARK: - App
@main
struct Wave9App: App {
    var body: some Scene {
        WindowGroup("Trinity Wave 9") {
            Wave9SingleView()
        }
        .defaultSize(width: 1000, height: 600)
    }
}
