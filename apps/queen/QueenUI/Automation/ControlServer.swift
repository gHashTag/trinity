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
            let rageClicks = await ScenarioEngine.shared.detectRageClicks()
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
            let heatmap = await ScenarioEngine.shared.getBehavioralHeatmap(timeWindow: timeWindow)
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
            let history = await ScenarioEngine.shared.getScenarioHistory()
            return httpResponse(json: [
                "success": true,
                "history": history.map { $0.toJSON() }
            ])

        // NEW: Behavioral analytics report
        case "/analytics":
            let report = await BehaviorAnalytics.shared.generateReport()
            return httpResponse(json: [
                "success": true,
                "report": report.toJSON()
            ])

        case "/analytics-reset":
            await BehaviorAnalytics.shared.resetSession()
            return httpResponse(json: [
                "success": true,
                "message": "Session reset"
            ])

        // NEW: Screenshot analysis endpoint
        case "/analyze-screen":
            let analysis = await ScreenAnalyzer.shared.analyzeCurrentScreen()
            return httpResponse(json: [
                "success": true,
                "analysis": analysis.toJSON()
            ])

        // NEW: Session recording endpoints
        case "/record/start":
            if let body = body,
               let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let name = params["name"] as? String {
                await SessionRecorder.shared.startSession(named: name)
                return httpResponse(json: [
                    "success": true,
                    "message": "Recording started",
                    "session": name
                ])
            }
            return httpResponse(status: 400, json: ["error": "Missing session name"])

        case "/record/stop":
            let actions = await SessionRecorder.shared.stopSession()
            return httpResponse(json: [
                "success": true,
                "message": "Recording stopped",
                "actions": actions.count,
                "export": actions.map { $0.toJSON() }
            ])

        case "/record/save":
            if let body = body,
               let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let path = params["path"] as? String {
                let saved = await SessionRecorder.shared.saveSession(to: URL(fileURLWithPath: path))
                return httpResponse(json: [
                    "success": saved,
                    "message": saved ? "Session saved" : "Failed to save"
                ])
            }
            return httpResponse(status: 400, json: ["error": "Missing path"])

        case "/record/play":
            if let body = body,
               let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let speed = params["speed"] as? Double {
                let result = await SessionRecorder.shared.playSession(speed: speed)
                return httpResponse(json: [
                    "success": result.success,
                    "result": result.toJSON()
                ])
            }
            // Default speed 1.0
            let result = await SessionRecorder.shared.playSession(speed: 1.0)
            return httpResponse(json: [
                "success": result.success,
                "result": result.toJSON()
            ])

        case "/record/export":
            let json = await SessionRecorder.shared.exportToJSON()
            if let json = json {
                return httpResponse(json: [
                    "success": true,
                    "session": json
                ])
            }
            return httpResponse(status: 400, json: ["error": "No session to export"])

        case "/record/status":
            return httpResponse(json: [
                "success": true,
                "isRecording": await SessionRecorder.shared.isRecordingNow,
                "isPlaying": await SessionRecorder.shared.isPlayingNow,
                "actionCount": await SessionRecorder.shared.actionCount,
                "sessionName": await SessionRecorder.shared.sessionName ?? ""
            ])

        // NEW: Adaptive action suggestion
        case "/suggest-action":
            let analysis = await ScreenAnalyzer.shared.analyzeCurrentScreen()
            return httpResponse(json: [
                "success": true,
                "analysis": analysis.toJSON()
            ])

        // NEW: Adaptive action suggestion
        case "/suggest-action":
            if let body = body,
               let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let goal = params["goal"] as? String {
                if let suggestion = await ScreenAnalyzer.shared.suggestNextAction(goal: goal) {
                    return httpResponse(json: [
                        "success": true,
                        "suggestion": [
                            "action": String(describing: suggestion.action),
                            "x": suggestion.target?.x ?? 0,
                            "y": suggestion.target?.y ?? 0,
                            "reason": suggestion.reason,
                            "confidence": suggestion.confidence
                        ]
                    ])
                }
            }
            return httpResponse(status: 400, json: ["error": "Could not generate suggestion"])

        // NEW: Natural language user flow endpoint
        case "/user-flow":
            if let body = body,
               let params = try? JSONSerialization.jsonObject(with: body) as? [String: Any],
               let goal = params["goal"] as? String {
                let result = await executeUserFlow(goal, context: params["context"] as? [String: Any])
                return httpResponse(json: result)
            }
            return httpResponse(status: 400, json: ["error": "Invalid user flow request"])

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
            let persona: TestPersona? = personaName == "novice" ? .novice :
                                       personaName == "expert" ? .expert :
                                       personaName == "elderly" ? .elderly : nil
            context = AutomationScenarioContext(persona: persona, startingScreen: context.startingScreen, userState: context.userState)
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

    // MARK: - Natural Language User Flow Execution

    private func executeUserFlow(_ goalText: String, context: [String: Any]?) async -> [String: Any] {
        NSLog("[ControlServer] Processing user flow: \"\(goalText)\"")

        // Parse natural language into structured actions
        let actions = parseUserGoal(goalText)
        var results: [[String: Any]] = []
        var overallSuccess = true

        for (index, action) in actions.enumerated() {
            NSLog("[ControlServer] Step \(index + 1)/\(actions.count): \(action.type)")

            let stepResult: [String: Any]
            switch action.type {
            case "navigate":
                let result = await UIAutomation.shared.navigate(to: action.param)
                stepResult = ["step": index + 1, "action": "navigate", "target": action.param, "result": result]

            case "click":
                let result = await UIAutomation.shared.click(element: action.element, x: action.x, y: action.y)
                stepResult = ["step": index + 1, "action": "click", "result": result]

            case "type":
                let result = await UIAutomation.shared.type(element: action.element, text: action.param)
                stepResult = ["step": index + 1, "action": "type", "text": action.param, "result": result]

            case "wait":
                let delay = Double(action.param) ?? 1.0
                try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                stepResult = ["step": index + 1, "action": "wait", "duration": delay]

            case "screenshot":
                let result = await UIAutomation.shared.takeScreenshot()
                stepResult = ["step": index + 1, "action": "screenshot", "result": result]

            default:
                stepResult = ["step": index + 1, "action": "unknown", "result": ["success": false, "error": "Unknown action"]]
            }

            results.append(stepResult)

            // Check if step failed
            if let stepActionResult = stepResult["result"] as? [String: Any],
               let success = stepActionResult["success"] as? Bool, !success {
                overallSuccess = false
                NSLog("[ControlServer] Step \(index + 1) failed, stopping flow")
                break
            }

            // Small delay between steps for realism
            try? await Task.sleep(nanoseconds: 200_000_000) // 200ms
        }

        return [
            "success": overallSuccess,
            "goal": goalText,
            "stepsCompleted": results.count,
            "totalSteps": actions.count,
            "steps": results
        ]
    }

    // MARK: - Natural Language Parser

    private func parseUserGoal(_ text: String) -> [ParsedAction] {
        let lowercased = text.lowercased()
        var actions: [ParsedAction] = []

        // Extract intent patterns
        if lowercased.contains("go to") || lowercased.contains("navigate to") || lowercased.contains("open") {
            if let range = lowercased.range(of: "go to ") ?? lowercased.range(of: "navigate to ") ?? lowercased.range(of: "open ") {
                let target = String(text[range.upperBound...]).trimmingCharacters(in: .whitespaces)
                    .components(separatedBy: " ")[0]
                actions.append(ParsedAction(type: "navigate", param: target))
            }
        }

        if lowercased.contains("click") || lowercased.contains("tap") {
            // Extract coordinates or element
            if lowercased.contains("at ") {
                let coordPart = lowercased.components(separatedBy: "at ").last ?? ""
                let parts = coordPart.components(separatedBy: ",")
                if parts.count == 2,
                   let x = Double(parts[0].trimmingCharacters(in: .whitespaces)),
                   let y = Double(parts[1].trimmingCharacters(in: .whitespaces)) {
                    actions.append(ParsedAction(type: "click", x: CGFloat(x), y: CGFloat(y)))
                }
            } else if lowercased.contains("button") || lowercased.contains("send") {
                actions.append(ParsedAction(type: "click", element: "chat.send"))
            }
        }

        if lowercased.contains("type") || lowercased.contains("enter") || lowercased.contains("input") {
            if let range = lowercased.range(of: "\"") {
                let quoteEnd = text[text.index(after: range.upperBound)...].range(of: "\"")
                if let end = quoteEnd {
                    let textToType = String(text[text.index(after: range.upperBound)..<end.lowerBound])
                    actions.append(ParsedAction(type: "type", param: textToType))
                }
            }
        }

        if lowercased.contains("wait") || lowercased.contains("pause") {
            let duration = extractNumber(from: lowercased) ?? 1.0
            actions.append(ParsedAction(type: "wait", param: String(format: "%.1f", duration)))
        }

        if lowercased.contains("screenshot") || lowercased.contains("capture") {
            actions.append(ParsedAction(type: "screenshot", param: ""))
        }

        // Default: if no actions parsed, treat as navigation
        if actions.isEmpty {
            // Try to find screen name
            let screens = ["sevo", "oracle", "settings", "chat", "arena", "faculty"]
            for screen in screens {
                if lowercased.contains(screen) {
                    actions.append(ParsedAction(type: "navigate", param: screen))
                    break
                }
            }
        }

        return actions
    }

    private func extractNumber(from text: String) -> Double? {
        let numbers = text.components(separatedBy: CharacterSet.decimalDigits.inverted)
            .filter { !$0.isEmpty }
        if let first = numbers.first, let value = Double(first) {
            return value
        }
        return nil
    }
}

// MARK: - Parsed Action Model

private struct ParsedAction {
    let type: String
    var param: String = ""
    var element: String? = nil
    var x: CGFloat? = nil
    var y: CGFloat? = nil
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
