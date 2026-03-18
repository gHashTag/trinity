import Foundation
import AppKit
import CoreGraphics

/// UI Automation executor - performs actions via CGEvent, clipboard, and NotificationCenter
/// Handles clicks, text input, navigation, screenshots, and state inspection
@MainActor
public final class UIAutomation: ObservableObject {
    public static let shared = UIAutomation()

    @Published public var isPuppetMode: Bool = false
    @Published public var lastAction: String = ""
    @Published public var actionLog: [String] = []
    @Published public var gazePosition: CGPoint = .zero
    @Published public var currentDecision: String = ""

    private let maxLogEntries = 5
    private var lastClickTime: Date?
    private var clickDebounce: TimeInterval = 0.1
    private var lastGazePosition: CGPoint = .zero

    private init() {
        // Don't auto-detect in init - causes crash with environment variables
        // Puppet mode will be set by ControlServer
    }

    // MARK: - Action Logging

    private func logAction(_ action: String) {
        lastAction = action
        actionLog.append(action)
        if actionLog.count > maxLogEntries {
            actionLog.removeFirst()
        }
        NSLog("[UIAutomation] \(action)")
    }

    // MARK: - Visual Feedback Helpers

    private func notifyGaze(at point: CGPoint) {
        gazePosition = point
        lastGazePosition = point
        NotificationCenter.default.post(
            name: NSNotification.Name("AutomationGazeUpdate"),
            object: nil,
            userInfo: ["x": point.x, "y": point.y]
        )
    }

    private func notifyThinkingStart() {
        NotificationCenter.default.post(name: NSNotification.Name("AutomationThinkingStart"), object: nil)
    }

    private func notifyThinkingEnd() {
        NotificationCenter.default.post(name: NSNotification.Name("AutomationThinkingEnd"), object: nil)
    }

    private func notifyActionStart(_ action: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("AutomationActionStart"),
            object: nil,
            userInfo: ["action": action]
        )
    }

    private func notifyActionProgress(_ progress: Double) {
        NotificationCenter.default.post(
            name: NSNotification.Name("AutomationActionProgress"),
            object: nil,
            userInfo: ["progress": progress]
        )
    }

    private func notifyActionEnd() {
        NotificationCenter.default.post(name: NSNotification.Name("AutomationActionEnd"), object: nil)
    }

    private func notifyErrorCorrection(wrong: String, correct: String, at: CGPoint) {
        NotificationCenter.default.post(
            name: NSNotification.Name("AutomationErrorCorrection"),
            object: nil,
            userInfo: ["wrong": wrong, "correct": correct, "x": at.x, "y": at.y]
        )
    }

    private func notifyDecisionPoint(at: CGPoint, label: String) {
        NotificationCenter.default.post(
            name: NSNotification.Name("AutomationDecisionPoint"),
            object: nil,
            userInfo: ["x": at.x, "y": at.y, "label": label]
        )
    }

    // MARK: - Click

    /// Click at specified coordinates or on named element
    public func click(element: String?, x: CGFloat?, y: CGFloat?) async -> [String: Any] {
        notifyActionStart("CLICK")
        notifyThinkingStart()

        // Simulate gaze scan before clicking (human behavior)
        try? await Task.sleep(nanoseconds: 150_000_000) // 150ms gaze
        notifyThinkingEnd()

        // Determine click position
        var targetX: CGFloat?
        var targetY: CGFloat?

        if let element = element {
            // Look up element position by name
            if let pos = findElementPosition(element) {
                (targetX, targetY) = pos
            }
        } else if let x = x, let y = y {
            targetX = x
            targetY = y
        }

        guard let clickX = targetX, let clickY = targetY else {
            let error = element != nil
                ? "Element '\(element!)' not found"
                : "No coordinates provided"
            logAction("❌ Click failed: \(error)")
            notifyActionEnd()
            return ["success": false, "error": error]
        }

        // Show gaze at target before click
        notifyGaze(at: CGPoint(x: clickX, y: clickY))

        // Debounce rapid clicks
        if let last = lastClickTime,
           Date().timeIntervalSince(last) < clickDebounce {
            try? await Task.sleep(nanoseconds: UInt64(clickDebounce * 1_000_000_000))
        }

        notifyActionProgress(0.5)

        // Perform click via CGEvent
        let mainScreen = NSScreen.main ?? NSScreen.screens.first
        let screenFrame = mainScreen?.visibleFrame ?? .zero
        let flippedY = screenFrame.height - clickY // Flip Y for CGEvent

        guard let eventDown = CGEvent(mouseEventSource: nil, mouseType: .leftMouseDown, mouseCursorPosition: CGPoint(x: clickX, y: flippedY), mouseButton: .left),
              let eventUp = CGEvent(mouseEventSource: nil, mouseType: .leftMouseUp, mouseCursorPosition: CGPoint(x: clickX, y: flippedY), mouseButton: .left) else {
            logAction("❌ Click failed: CGEvent creation failed")
            notifyActionEnd()
            return ["success": false, "error": "CGEvent creation failed"]
        }

        eventDown.flags = .maskCommand
        eventUp.flags = .maskCommand
        eventDown.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01s
        eventUp.post(tap: .cghidEventTap)

        notifyActionProgress(1.0)

        lastClickTime = Date()
        let msg = element != nil ? "Clicked '\(element!)'" : "Clicked at (\(clickX), \(clickY))"
        logAction("🖱️ \(msg)")
        notifyActionEnd()
        return [
            "success": true,
            "x": clickX,
            "y": clickY,
            "element": element ?? ""
        ]
    }

    // MARK: - Type

    /// Type text via clipboard paste (Cmd+V)
    public func type(element: String?, text: String?) async -> [String: Any] {
        guard let text = text, !text.isEmpty else {
            logAction("❌ Type failed: no text provided")
            return ["success": false, "error": "No text provided"]
        }

        notifyActionStart("TYPE")

        // Simulate "finding" the field (gaze behavior)
        notifyThinkingStart()
        try? await Task.sleep(nanoseconds: 200_000_000) // 200ms decision time
        notifyThinkingEnd()

        // If element specified, click it first
        let clickPos: CGPoint
        if let element = element {
            let clickResult = await click(element: element, x: nil, y: nil)
            if !(clickResult["success"] as? Bool ?? false) {
                notifyActionEnd()
                return clickResult
            }
            try? await Task.sleep(nanoseconds: 50_000_000) // 0.05s
            clickPos = CGPoint(x: clickResult["x"] as? CGFloat ?? 0, y: clickResult["y"] as? CGFloat ?? 0)
        } else {
            clickPos = lastGazePosition
        }

        notifyActionProgress(0.3)

        // Copy to clipboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        notifyActionProgress(0.6)

        // Simulate Cmd+V
        guard let cmdDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: true),
              let vDown = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: true),
              let vUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x09, keyDown: false),
              let cmdUp = CGEvent(keyboardEventSource: nil, virtualKey: 0x37, keyDown: false) else {
            logAction("❌ Type failed: CGEvent creation failed")
            notifyActionEnd()
            return ["success": false, "error": "CGEvent creation failed"]
        }

        cmdDown.flags = .maskCommand
        vDown.flags = .maskCommand
        vUp.flags = .maskCommand

        cmdDown.post(tap: .cghidEventTap)
        vDown.post(tap: .cghidEventTap)
        try? await Task.sleep(nanoseconds: 10_000_000) // 0.01s
        vUp.post(tap: .cghidEventTap)
        cmdUp.post(tap: .cghidEventTap)

        notifyActionProgress(1.0)

        let msg = element != nil ? "Typed '\(text)' into '\(element!)'" : "Typed '\(text)'"
        logAction("⌨️ \(msg)")
        notifyActionEnd()
        return [
            "success": true,
            "text": text,
            "element": element ?? ""
        ]
    }

    // MARK: - Navigate

    /// Navigate to a different screen via NotificationCenter
    public func navigate(to screenName: String?) async -> [String: Any] {
        guard let screenName = screenName else {
            logAction("❌ Navigate failed: no screen specified")
            return ["success": false, "error": "No screen specified"]
        }

        notifyActionStart("NAVIGATE")
        notifyThinkingStart()

        // Simulate decision time for navigation choice
        try? await Task.sleep(nanoseconds: 300_000_000) // 300ms decision
        notifyThinkingEnd()

        // Show decision point marker at navigation area
        notifyDecisionPoint(at: CGPoint(x: 100, y: 300), label: "NAV: \(screenName.uppercased())")

        // Map screen names to notifications
        let notification: Notification.Name?
        switch screenName.lowercased() {
        case "chat", "main", "home":
            notification = nil // Already on main
        case "sevo", "farm", "sevofarm":
            notification = .navigateToSEVOFarm
        case "arena", "llm", "arenallm":
            notification = .navigateToArenaLLM
        case "faculty":
            notification = .navigateToFaculty
        case "oracle":
            notification = .navigateToOracle
        case "build":
            notification = .navigateToBuild
        case "deploy":
            notification = .navigateToDeploy
        case "telegram":
            notification = .navigateToTelegram
        case "settings", "prefs":
            notification = .navigateToSettings
        default:
            notification = nil
        }

        notifyActionProgress(0.5)

        if let notification = notification {
            NotificationCenter.default.post(name: notification, object: nil)
            logAction("🧭 Navigated to \(screenName)")
            notifyActionProgress(1.0)
            notifyActionEnd()
            return ["success": true, "screen": screenName]
        } else if screenName.lowercased() == "chat" || screenName.lowercased() == "home" {
            // Go back to main menu
            NotificationCenter.default.post(name: .navigateToMain, object: nil)
            logAction("🧭 Navigated to main menu")
            notifyActionProgress(1.0)
            notifyActionEnd()
            return ["success": true, "screen": "main"]
        }

        logAction("❌ Navigate failed: unknown screen '\(screenName)'")
        notifyActionEnd()
        return ["success": false, "error": "Unknown screen '\(screenName)'"]
    }

    // MARK: - Screenshot

    /// Capture window screenshot as base64 PNG
    public func takeScreenshot() async -> [String: Any] {
        guard NSScreen.main != nil else {
            logAction("❌ Screenshot failed: no main screen")
            return ["success": false, "error": "No main screen"]
        }

        let screenshot = CGDisplayCreateImage(CGMainDisplayID())

        guard let cgImage = screenshot else {
            logAction("❌ Screenshot failed: CGDisplayCreateImage returned nil")
            return ["success": false, "error": "Failed to capture display"]
        }

        let rep = NSBitmapImageRep(cgImage: cgImage)
        guard let pngData = rep.representation(using: .png, properties: [:]) else {
            logAction("❌ Screenshot failed: PNG encoding failed")
            return ["success": false, "error": "PNG encoding failed"]
        }

        let base64 = pngData.base64EncodedString(options: .endLineWithLineFeed)
        logAction("📸 Screenshot captured (\(pngData.count) bytes)")

        return [
            "success": true,
            "image": base64,
            "width": Int(cgImage.width),
            "height": Int(cgImage.height),
            "format": "png"
        ]
    }

    // MARK: - Get Current State

    /// Get snapshot of current UI state
    public func getCurrentState() async -> [String: Any] {
        let activeApp = NSWorkspace.shared.frontmostApplication
        let mainScreen = NSScreen.main

        return [
            "success": true,
            "timestamp": ISO8601DateFormatter().string(from: Date()),
            "puppetMode": isPuppetMode,
            "frontmostApp": activeApp?.localizedName ?? "unknown",
            "bundleIdentifier": activeApp?.bundleIdentifier ?? "",
            "screen": [
                "width": mainScreen?.frame.width ?? 0,
                "height": mainScreen?.frame.height ?? 0
            ],
            "lastAction": lastAction,
            "actionLog": actionLog
        ]
    }

    // MARK: - Get Elements

    /// Get list of known interactive elements
    public func getElements() async -> [String: Any] {
        // This would ideally use Accessibility API to discover real elements
        // For now, return known UI elements based on current screen
        let knownElements: [[String: Any]] = [
            ["id": "chat.input", "type": "textField", "hint": "Chat input field"],
            ["id": "chat.send", "type": "button", "hint": "Send message button"],
            ["id": "sidebar.newThread", "type": "button", "hint": "New thread button"],
            ["id": "sidebar.settings", "type": "button", "hint": "Settings screen"],
            ["id": "nav.sevo", "type": "button", "hint": "SEVO Farm screen"],
            ["id": "nav.arena", "type": "button", "hint": "Arena LLM screen"],
            ["id": "nav.faculty", "type": "button", "hint": "Faculty screen"],
            ["id": "nav.oracle", "type": "button", "hint": "Oracle screen"],
        ]

        return [
            "success": true,
            "elements": knownElements,
            "count": knownElements.count
        ]
    }

    // MARK: - Element Position Lookup

    /// Find screen coordinates for a named element
    private func findElementPosition(_ elementId: String) -> (CGFloat, CGFloat)? {
        // TODO: Use Accessibility API to find real element positions
        // For now, return nil - element-based clicking not implemented
        // Users should provide x, y coordinates directly

        // Known positions (hardcoded for testing - these should be dynamic)
        let knownPositions: [String: (CGFloat, CGFloat)] = [
            "chat.send": (200, 100),
            "chat.input": (200, 80),
        ]

        return knownPositions[elementId]
    }
}

// MARK: - Navigation Notifications

extension Notification.Name {
    static let navigateToSEVOFarm = Notification.Name("navigateToSEVOFarm")
    static let navigateToArenaLLM = Notification.Name("navigateToArenaLLM")
    static let navigateToFaculty = Notification.Name("navigateToFaculty")
    static let navigateToOracle = Notification.Name("navigateToOracle")
    static let navigateToBuild = Notification.Name("navigateToBuild")
    static let navigateToDeploy = Notification.Name("navigateToDeploy")
    static let navigateToTelegram = Notification.Name("navigateToTelegram")
    static let navigateToSettings = Notification.Name("navigateToSettings")
    static let navigateToMain = Notification.Name("navigateToMain")
}
