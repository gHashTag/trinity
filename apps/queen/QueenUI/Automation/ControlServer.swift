import Foundation
import Network
import Combine
import AppKit

/// HTTP Control Server for autonomous AI-driven UI testing
/// Listens on port 8080, provides endpoints for click, type, navigate, screenshot
public final class ControlServer: ObservableObject {
    public static let shared = ControlServer()

    private var listener: NWListener?
    private var connections: [NWConnection] = []
    private let queue = DispatchQueue(label: "com.trinity.automation.server")
    @Published public var isRunning = false
    @Published public var port: UInt16 = 8080
    @Published public var lastActivity: String = ""
    @Published public var connectedClients: Int = 0

    // Nonisolated state for callback access
    private var internalIsRunning: Bool = false
    private var internalConnectedClients: Int = 0
    private let stateLock = NSLock()

    private init() {
        // Don't check environment in init - causes crash
        // Server will be started manually via startIfPuppetMode()
    }

    /// Call this from appdidFinishLaunching or similar
    public func startIfPuppetMode() {
        let isPuppet = ProcessInfo.processInfo.environment["PUPPET_MODE"] != nil ||
                      ProcessInfo.processInfo.arguments.contains("--puppet")

        NSLog("[ControlServer] startIfPuppetMode: isPuppet=\(isPuppet)")

        if isPuppet {
            DispatchQueue.main.async { [weak self] in
                self?.start()
                Task { @MainActor in
                    UIAutomation.shared.isPuppetMode = true
                    NSLog("[ControlServer] 🤖 PUPPET MODE active")
                }
            }
        }
    }

    // MARK: - Start/Stop

    public func start(port: UInt16 = 8080) {
        stateLock.lock()
        let alreadyRunning = internalIsRunning
        stateLock.unlock()

        guard !alreadyRunning else { return }
        self.port = port

        NSLog("[ControlServer] Starting on port \(port)")

        do {
            listener = try NWListener(using: .tcp, on: NWEndpoint.Port(rawValue: port)!)
        } catch {
            NSLog("[ControlServer] Failed to create listener: \(error)")
            return
        }

        listener?.newConnectionHandler = { [weak self] connection in
            self?.handleConnection(connection)
        }

        listener?.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                stateLock.lock()
                let clients = self.internalConnectedClients
                stateLock.unlock()
                self.setState(running: true, clients: clients)
                NSLog("[ControlServer] Listening on port \(port)")
            case .failed(let error):
                NSLog("[ControlServer] Failed: \(error)")
                self.setState(running: false, clients: 0)
            default:
                break
            }
        }

        listener?.start(queue: queue)
    }

    public func stop() {
        listener?.cancel()
        stateLock.lock()
        connections.forEach { $0.cancel() }
        connections.removeAll()
        stateLock.unlock()
        setState(running: false, clients: 0)
    }

    // MARK: - State Management (thread-safe)

    private func setState(running: Bool, clients: Int) {
        stateLock.lock()
        internalIsRunning = running
        internalConnectedClients = clients
        stateLock.unlock()

        Task { @MainActor in
            self.isRunning = running
            self.connectedClients = clients
        }
    }

    // MARK: - Connection Handling

    private func handleConnection(_ connection: NWConnection) {
        stateLock.lock()
        connections.append(connection)
        let count = connections.count
        internalConnectedClients = count
        stateLock.unlock()

        Task { @MainActor in
            self.connectedClients = count
        }

        connection.stateUpdateHandler = { [weak self] state in
            if case .failed = state, let self = self {
                self.stateLock.lock()
                self.connections.removeAll { $0 === connection }
                let count = self.connections.count
                self.internalConnectedClients = count
                self.stateLock.unlock()

                Task { @MainActor in
                    self.connectedClients = count
                }
            }
        }

        connection.start(queue: queue)
        receiveNext(on: connection)
    }

    private func receiveNext(on connection: NWConnection) {
        connection.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] data, _, isComplete, error in
            if let data = data, !data.isEmpty {
                self?.handleRequest(data, on: connection)
            }
            if !isComplete && error == nil {
                self?.receiveNext(on: connection)
            }
        }
    }

    // MARK: - Request Handler

    private func handleRequest(_ data: Data, on connection: NWConnection) {
        guard let requestString = String(data: data, encoding: .utf8) else { return }

        let lines = requestString.components(separatedBy: "\r\n")
        guard let firstLine = lines.first else { return }

        let parts = firstLine.components(separatedBy: " ")
        guard parts.count >= 2 else { return }

        let method = parts[0]
        let pathWithQuery = parts[1]
        let path = pathWithQuery.components(separatedBy: "?").first ?? pathWithQuery

        var body: Data?
        if method == "POST" {
            if let bodyStart = requestString.range(of: "\r\n\r\n") {
                let bodyData = requestString[bodyStart.upperBound...].data(using: .utf8)
                body = bodyData
            }
        }

        Task { @MainActor in
            let response = await self.routeRequest(method: method, path: path, body: body)
            connection.send(content: response, completion: .contentProcessed { _ in })
        }
    }

    // MARK: - Routing

    private func routeRequest(method: String, path: String, body: Data?) async -> Data {
        lastActivity = "\(method) \(path)"
        NSLog("[ControlServer] \(method) \(path)")

        switch path {
        case "/health":
            return httpResponse(json: [
                "status": "ok",
                "puppetMode": true,
                "version": "1.0.0",
                "timestamp": ISO8601DateFormatter().string(from: Date())
            ])

        case "/ui-state":
            let state = await UIAutomation.shared.getCurrentState()
            return httpResponse(json: state)

        case "/screenshot":
            let screenshot = await UIAutomation.shared.takeScreenshot()
            return httpResponse(json: screenshot)

        case "/click":
            if let body = body,
               let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                let result = await UIAutomation.shared.click(
                    element: params["element"] as? String,
                    x: (params["x"] as? NSNumber)?.CGFloatValue,
                    y: (params["y"] as? NSNumber)?.CGFloatValue
                )
                return httpResponse(json: result)
            }
            return httpResponse(status: 400, json: ["error": "Invalid request"])

        case "/type":
            if let body = body,
               let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                let result = await UIAutomation.shared.type(
                    element: params["element"] as? String,
                    text: params["text"] as? String
                )
                return httpResponse(json: result)
            }
            return httpResponse(status: 400, json: ["error": "Invalid request"])

        case "/navigate":
            if let body = body,
               let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                let result = await UIAutomation.shared.navigate(to: params["screen"] as? String)
                return httpResponse(json: result)
            }
            return httpResponse(status: 400, json: ["error": "Invalid request"])

        case "/elements":
            let elements = await UIAutomation.shared.getElements()
            return httpResponse(json: elements)

        // NEW: Scenario-based testing endpoints
        case "/scenario":
            if let body = body,
               let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any] {
                let result = await executeScenario(params)
                return httpResponse(json: result)
            }
            return httpResponse(status: 400, json: ["error": "Invalid scenario request"])

        case "/rage-clicks":
            let rageClicks = ScenarioEngine.shared.detectRageClicks()
            return httpResponse(json: [
                "success": true,
                "rageClicks": rageClicks.map { [
                    "location": $0.location,
                    "clickCount": $0.clickCount,
                    "timeSpan": $0.timeSpan,
                    "avgX": $0.avgX,
                    "avgY": $0.avgY
                ]}
            ])

        case "/heatmap":
            let timeWindow = body.flatMap {
                (try? JSONSerialization.jsonObject(with: $0) as? [String: Any])?["timeWindow"] as? Double
            } ?? 60.0
            let heatmap = ScenarioEngine.shared.getBehavioralHeatmap(timeWindow: timeWindow)
            return httpResponse(json: [
                "success": true,
                "timeWindow": timeWindow,
                "heatmap": heatmap.map { [
                    "x": $0.x,
                    "y": $0.y,
                    "intensity": $0.intensity
                ]}
            ])

        case "/scenario-history":
            let history = ScenarioEngine.shared.getScenarioHistory()
            return httpResponse(json: [
                "success": true,
                "history": history.map { $0.toJSON() }
            ])

        default:
            return httpResponse(status: 404, json: ["error": "Not found"])
        }
    }

    // MARK: - HTTP Response Builder

    private func httpResponse(status: Int = 200, json: [String: Any]) -> Data {
        let jsonBody: String
        do {
            let data = try JSONSerialization.data(withJSONObject: json)
            jsonBody = String(data: data, encoding: .utf8) ?? "{}"
        } catch {
            jsonBody = "{\"error\": \"JSON encoding failed\"}"
        }

        let response = """
        HTTP/1.1 \(status) \(status == 200 ? "OK" : "Error")
        Content-Type: application/json
        Access-Control-Allow-Origin: *
        Content-Length: \(jsonBody.utf8.count)

        \(jsonBody)
        """

        return response.data(using: .utf8) ?? Data()
    }

    // MARK: - Scenario Execution Helper

    private func executeScenario(_ params: [String: Any]) async -> [String: Any] {
        // Parse scenario from request
        guard let goalDict = params["goal"] as? [String: Any],
              let goalType = goalDict["type"] as? String else {
            return ["success": false, "error": "Invalid goal format"]
        }

        let goal: AutomationScenarioGoal
        switch goalType {
        case "navigate":
            let screen = goalDict["screen"] as? String ?? ""
            goal = .navigate(screen)
        case "input":
            let element = goalDict["element"] as? String ?? ""
            let text = goalDict["text"] as? String ?? ""
            goal = .input(element: element, text: text)
        case "findAndClick":
            let description = goalDict["description"] as? String ?? ""
            goal = .findAndClick(description)
        case "custom":
            let goalText = goalDict["text"] as? String ?? ""
            goal = .custom(goalText)
        default:
            return ["success": false, "error": "Unknown goal type"]
        }

        // Parse context
        var context = AutomationScenarioContext()
        if let contextDict = params["context"] as? [String: Any],
           let personaName = contextDict["persona"] as? String {
            context.persona = personaName == "novice" ? .novice :
                            personaName == "expert" ? .expert :
                            personaName == "elderly" ? .elderly : nil
        }

        // Parse constraints
        var constraints: AutomationScenarioConstraints?
        if let constraintsDict = params["constraints"] as? [String: Any] {
            let maxTime = constraintsDict["maxTime"] as? Double
            let maxSteps = constraintsDict["maxSteps"] as? Int
            if maxTime != nil || maxSteps != nil {
                constraints = AutomationScenarioConstraints(maxTime: maxTime, maxSteps: maxSteps)
            }
        }

        let scenario = AutomationScenario(goal: goal, context: context, constraints: constraints)
        let result = await ScenarioEngine.shared.executeScenario(scenario)

        return [
            "success": result.success,
            "result": result.toJSON()
        ]
    }
}

// MARK: - Helper Extensions

extension NSNumber {
    var CGFloatValue: CGFloat {
        #if arch(arm64)
        return CGFloat(truncating: self)
        #else
        return CGFloat(doubleValue)
        #endif
    }
}
