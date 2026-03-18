import Foundation
import AppKit

/// Goal-oriented scenario execution for UX testing
@MainActor
public final class ScenarioEngine {
    public static let shared = ScenarioEngine()

    private var activeScenario: AutomationScenario?
    private var scenarioHistory: [AutomationScenarioResult] = []
    private let clickHistory: AutomationClickHistoryTracker

    private init() {
        self.clickHistory = AutomationClickHistoryTracker()
    }

    // MARK: - Scenario Execution

    /// Execute a scenario based on user goal
    public func executeScenario(_ scenario: AutomationScenario) async -> AutomationScenarioResult {
        activeScenario = scenario
        let startTime = Date()

        NSLog("[ScenarioEngine] Starting scenario: \(scenario.goal)")

        var steps: [AutomationScenarioStep] = []
        var success = false
        var errorMessage: String?

        do {
            switch scenario.goal {
            case .navigate(let screen):
                steps = try await executeNavigation(to: screen, context: scenario.context)

            case .input(let element, let text):
                steps = try await executeInput(element: element, text: text, context: scenario.context)

            case .findAndClick(let desc):
                steps = try await executeFindAndClick(desc, context: scenario.context)

            case .custom(let goalText):
                steps = try await executeCustomGoal(goalText, context: scenario.context)
            }

            success = true

        } catch {
            errorMessage = error.localizedDescription
            NSLog("[ScenarioEngine] Scenario failed: \(error)")
        }

        let duration = Date().timeIntervalSince(startTime)
        let result = AutomationScenarioResult(
            scenario: scenario,
            steps: steps,
            duration: duration,
            success: success,
            errorMessage: errorMessage,
            violatedConstraints: checkConstraints(scenario.constraints, duration: duration, steps: steps)
        )

        scenarioHistory.append(result)
        activeScenario = nil

        NSLog("[ScenarioEngine] Scenario completed: \(success ? "SUCCESS" : "FAILED") in \(String(format: "%.2f", duration))s")

        return result
    }

    // MARK: - Persona Application

    /// Apply persona to action execution
    public func executeAsPersona(_ persona: TestPersona, action: @escaping () async throws -> Void) async throws {
        // Apply persona-specific delays
        let delay = HumanBehaviorModel.decisionTime(complexity: persona.complexityPreference)
        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))

        try await action()

        // Post-action reflection time for certain personas
        if persona.reflective {
            try await Task.sleep(nanoseconds: UInt64(HumanBehaviorModel.randomDelay(mean: 300, stdDev: 100) * 1_000_000_000))
        }
    }

    // MARK: - Goal Implementations

    private func executeNavigation(to screen: String, context: AutomationScenarioContext) async throws -> [AutomationScenarioStep] {
        var steps: [AutomationScenarioStep] = []

        // Step 1: "Decide" to navigate
        let decisionTime = HumanBehaviorModel.decisionTime(complexity: .simple)
        steps.append(AutomationScenarioStep(
            action: "decision",
            desc: "Deciding to navigate to \(screen)",
            duration: decisionTime
        ))
        try await Task.sleep(nanoseconds: UInt64(decisionTime * 1_000_000_000))

        // Step 2: Perform navigation
        let start = Date()
        let result = await UIAutomation.shared.navigate(to: screen)
        let navTime = Date().timeIntervalSince(start)

        guard result["success"] as? Bool == true else {
            throw AutomationScenarioError.navigationFailed(screen)
        }

        steps.append(AutomationScenarioStep(
            action: "navigate",
            desc: "Navigated to \(screen)",
            duration: navTime
        ))

        // Step 3: Post-navigation scan time
        let scanTime = HumanBehaviorModel.gazeFixation(contentType: .navigation)
        try await Task.sleep(nanoseconds: UInt64(scanTime * 1_000_000_000))

        return steps
    }

    private func executeInput(element: String, text: String, context: AutomationScenarioContext) async throws -> [AutomationScenarioStep] {
        var steps: [AutomationScenarioStep] = []

        // Step 1: Find and focus element
        let findTime = HumanBehaviorModel.decisionTime(complexity: .medium)
        steps.append(AutomationScenarioStep(
            action: "locate",
            desc: "Locating input field: \(element)",
            duration: findTime
        ))
        try await Task.sleep(nanoseconds: UInt64(findTime * 1_000_000_000))

        // Step 2: Click to focus
        let clickStart = Date()
        let clickResult = await UIAutomation.shared.click(element: element, x: nil, y: nil)
        let clickDuration = Date().timeIntervalSince(clickStart)

        if clickResult["success"] as? Bool != true {
            // Try fallback: click center screen
            _ = await UIAutomation.shared.click(element: nil, x: 400, y: 300)
        }

        steps.append(AutomationScenarioStep(
            action: "focus",
            desc: "Focused input field",
            duration: clickDuration
        ))

        // Step 3: Read existing content (if any)
        let readTime = HumanBehaviorModel.readingTime(for: "")
        try await Task.sleep(nanoseconds: UInt64(readTime * 1_000_000_000))

        // Step 4: Type text with realistic timing
        let typeStart = Date()
        let typeResult = await UIAutomation.shared.type(element: element, text: text)
        let typeDuration = Date().timeIntervalSince(typeStart)

        guard typeResult["success"] as? Bool == true else {
            throw AutomationScenarioError.inputFailed(element)
        }

        steps.append(AutomationScenarioStep(
            action: "type",
            desc: "Entered text: \(text.prefix(50))\(text.count > 50 ? "..." : "")",
            duration: typeDuration
        ))

        // Step 5: Verify input
        let verifyTime = HumanBehaviorModel.randomDelay(mean: 300, stdDev: 100)
        try await Task.sleep(nanoseconds: UInt64(verifyTime * 1_000_000_000))

        return steps
    }

    private func executeFindAndClick(_ description: String, context: AutomationScenarioContext) async throws -> [AutomationScenarioStep] {
        var steps: [AutomationScenarioStep] = []

        // Step 1: Visual search
        let searchTime = HumanBehaviorModel.gazeFixation(contentType: .button) * 2 // Search takes longer
        steps.append(AutomationScenarioStep(
            action: "search",
            desc: "Scanning for: \(description)",
            duration: searchTime
        ))
        try await Task.sleep(nanoseconds: UInt64(searchTime * 1_000_000_000))

        // Step 2: Decision and click
        let decisionTime = HumanBehaviorModel.decisionTime(complexity: .simple)
        try await Task.sleep(nanoseconds: UInt64(decisionTime * 1_000_000_000))

        // Map description to known elements
        let targetElement = mapDescriptionToElement(description)

        if let element = targetElement {
            let result = await UIAutomation.shared.click(element: element, x: nil, y: nil)
            guard result["success"] as? Bool == true else {
                throw AutomationScenarioError.elementNotFound(description)
            }

            steps.append(AutomationScenarioStep(
                action: "click",
                desc: "Clicked: \(element)",
                duration: 0.1
            ))
        } else {
            // Try coordinate-based click
            let coords = inferCoordinates(description)
            _ = await UIAutomation.shared.click(element: nil, x: coords.x, y: coords.y)

            steps.append(AutomationScenarioStep(
                action: "click",
                desc: "Clicked at coords: (\(coords.x), \(coords.y))",
                duration: 0.1
            ))
        }

        return steps
    }

    private func executeCustomGoal(_ goalText: String, context: AutomationScenarioContext) async throws -> [AutomationScenarioStep] {
        var steps: [AutomationScenarioStep] = []

        // Parse natural language goal
        let lowercased = goalText.lowercased()

        if lowercased.contains("settings") || lowercased.contains("preference") {
            return try await executeNavigation(to: "settings", context: context)
        } else if lowercased.contains("sevo") || lowercased.contains("farm") {
            return try await executeNavigation(to: "sevo", context: context)
        } else if lowercased.contains("oracle") {
            return try await executeNavigation(to: "oracle", context: context)
        } else if lowercased.contains("chat") || lowercased.contains("message") {
            return try await executeNavigation(to: "chat", context: context)
        } else {
            // Generic exploration
            for screen in ["sevo", "oracle", "settings"] {
                let navSteps = try await executeNavigation(to: screen, context: context)
                steps.append(contentsOf: navSteps)

                let pause = HumanBehaviorModel.gazeFixation(contentType: .navigation)
                try await Task.sleep(nanoseconds: UInt64(pause * 1_000_000_000))
            }
            return steps
        }
    }

    // MARK: - Helper Methods

    private func mapDescriptionToElement(_ description: String) -> String? {
        let lower = description.lowercased()

        if lower.contains("send") || lower.contains("submit") { return "chat.send" }
        if lower.contains("input") || lower.contains("field") { return "chat.input" }
        if lower.contains("new thread") { return "sidebar.newThread" }
        if lower.contains("settings") { return "nav.settings" }

        return nil
    }

    private func inferCoordinates(_ description: String) -> CGPoint {
        let lower = description.lowercased()

        if lower.contains("top") {
            return CGPoint(x: 400, y: 100)
        } else if lower.contains("bottom") {
            return CGPoint(x: 400, y: 700)
        } else if lower.contains("left") {
            return CGPoint(x: 100, y: 400)
        } else if lower.contains("right") {
            return CGPoint(x: 700, y: 400)
        } else {
            return CGPoint(x: 400, y: 400)
        }
    }

    private func checkConstraints(_ constraints: AutomationScenarioConstraints?, duration: TimeInterval, steps: [AutomationScenarioStep]) -> [String] {
        guard let constraints = constraints else { return [] }

        var violations: [String] = []

        if let maxTime = constraints.maxTime, duration > maxTime {
            violations.append("Exceeded max time: \(String(format: "%.2f", duration))s > \(maxTime)s")
        }

        if let maxSteps = constraints.maxSteps, steps.count > maxSteps {
            violations.append("Exceeded max steps: \(steps.count) > \(maxSteps)")
        }

        return violations
    }

    // MARK: - Rage Click Detection

    public func detectRageClicks() -> [RageClickEvent] {
        let events = clickHistory.getRecentEvents(timeWindow: 5.0)
        var rageClicks: [RageClickEvent] = []

        let grouped = Dictionary(grouping: events) { event in
            let gridX = Int(event.x / 50) * 50
            let gridY = Int(event.y / 50) * 50
            return "\(gridX)x\(gridY)"
        }

        for (location, clicks) in grouped {
            if clicks.count >= 3 {
                let timeSpan = clicks.map { $0.timestamp }.max()!.timeIntervalSince(clicks.map { $0.timestamp }.min()!)
                if timeSpan < 2.0 {
                    rageClicks.append(RageClickEvent(
                        location: location,
                        clickCount: clicks.count,
                        timeSpan: timeSpan,
                        avgX: clicks.map { $0.x }.reduce(0, +) / CGFloat(clicks.count),
                        avgY: clicks.map { $0.y }.reduce(0, +) / CGFloat(clicks.count)
                    ))
                }
            }
        }

        return rageClicks
    }

    // MARK: - History & Analytics

    public func getScenarioHistory() -> [AutomationScenarioResult] {
        return scenarioHistory
    }

    public func getBehavioralHeatmap(timeWindow: TimeInterval = 60.0) -> [HeatmapPoint] {
        let events = clickHistory.getRecentEvents(timeWindow: timeWindow)

        let binSize: CGFloat = 50
        var bins: [String: Int] = [:]

        for event in events {
            let binX = Int(event.x / binSize)
            let binY = Int(event.y / binSize)
            let key = "\(binX)x\(binY)"
            bins[key, default: 0] += 1
        }

        return bins.map { key, count in
            let parts = key.split(separator: "x").compactMap { Int($0) }
            let xVal = parts.count > 0 ? parts[0] : 0
            let yVal = parts.count > 1 ? parts[1] : 0
            return HeatmapPoint(
                x: CGFloat(xVal) * binSize,
                y: CGFloat(yVal) * binSize,
                intensity: count
            )
        }
    }
}

// MARK: - Supporting Types

public struct AutomationScenario {
    public let goal: AutomationScenarioGoal
    public let context: AutomationScenarioContext
    public let constraints: AutomationScenarioConstraints?

    public init(goal: AutomationScenarioGoal, context: AutomationScenarioContext = AutomationScenarioContext(), constraints: AutomationScenarioConstraints? = nil) {
        self.goal = goal
        self.context = context
        self.constraints = constraints
    }
}

public enum AutomationScenarioGoal {
    case navigate(String)
    case input(element: String, text: String)
    case findAndClick(String)
    case custom(String)
}

public struct AutomationScenarioContext {
    public let persona: TestPersona?
    public let startingScreen: String?
    public let userState: AutomationUserState

    public init(persona: TestPersona? = nil, startingScreen: String? = nil, userState: AutomationUserState = .normal) {
        self.persona = persona
        self.startingScreen = startingScreen
        self.userState = userState
    }
}

public enum AutomationUserState {
    case normal
    case rushed
    case confused
    case frustrated
}

public struct AutomationScenarioConstraints {
    public let maxTime: TimeInterval?
    public let maxSteps: Int?

    public init(maxTime: TimeInterval? = nil, maxSteps: Int? = nil) {
        self.maxTime = maxTime
        self.maxSteps = maxSteps
    }
}

public struct AutomationScenarioResult {
    public let scenario: AutomationScenario
    public let steps: [AutomationScenarioStep]
    public let duration: TimeInterval
    public let success: Bool
    public let errorMessage: String?
    public let violatedConstraints: [String]

    public func toJSON() -> [String: Any] {
        [
            "goal": String(describing: scenario.goal),
            "success": success,
            "duration": duration,
            "stepCount": steps.count,
            "steps": steps.map { $0.toJSON() },
            "violatedConstraints": violatedConstraints,
            "errorMessage": errorMessage ?? ""
        ]
    }
}

public struct AutomationScenarioStep {
    public let action: String
    public let desc: String
    public let duration: TimeInterval

    public func toJSON() -> [String: Any] {
        [
            "action": action,
            "description": desc,
            "duration": duration
        ]
    }
}

public enum AutomationScenarioError: Error {
    case navigationFailed(String)
    case inputFailed(String)
    case elementNotFound(String)
    case timeout(TimeInterval)
}

public struct TestPersona {
    public let name: String
    public let proficiency: TypingProficiency
    public let complexityPreference: ActionComplexity
    public let reflective: Bool
    public let patience: TimeInterval

    public static let novice = TestPersona(name: "Novice", proficiency: .novice, complexityPreference: .simple, reflective: true, patience: 30)
    public static let expert = TestPersona(name: "Expert", proficiency: .expert, complexityPreference: .medium, reflective: false, patience: 10)
    public static let elderly = TestPersona(name: "Elderly", proficiency: .novice, complexityPreference: .simple, reflective: true, patience: 60)
}

public struct RageClickEvent {
    public let location: String
    public let clickCount: Int
    public let timeSpan: TimeInterval
    public let avgX: CGFloat
    public let avgY: CGFloat
}

public struct HeatmapPoint {
    public let x: CGFloat
    public let y: CGFloat
    public let intensity: Int
}

// MARK: - Click History Tracker

private class AutomationClickHistoryTracker {
    private var events: [AutomationClickEvent] = []
    private let lock = NSLock()

    func addEvent(_ event: AutomationClickEvent) {
        lock.lock()
        events.append(event)
        if events.count > 100 {
            events.removeFirst(events.count - 100)
        }
        lock.unlock()
    }

    func getRecentEvents(timeWindow: TimeInterval) -> [AutomationClickEvent] {
        lock.lock()
        let now = Date()
        let recent = events.filter { now.timeIntervalSince($0.timestamp) <= timeWindow }
        lock.unlock()
        return recent
    }
}

// MARK: - Click Event Type

public struct AutomationClickEvent {
    public let timestamp: Date
    public let x: CGFloat
    public let y: CGFloat

    public init(timestamp: Date, x: CGFloat, y: CGFloat) {
        self.timestamp = timestamp
        self.x = x
        self.y = y
    }
}
