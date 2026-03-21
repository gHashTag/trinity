import Foundation
import AppKit
import CoreGraphics

/// Record and replay UI automation sessions for regression testing
@MainActor
public final class SessionRecorder {
    public static let shared = SessionRecorder()

    private var isRecording = false
    private var isPlaying = false
    private var recordingStart: Date?
    private var recordedActions: [RecordedAction] = []
    private var currentSession: String?

    private init() {}

    // MARK: - Recording

    public func startSession(named name: String) {
        currentSession = name
        recordingStart = Date()
        recordedActions.removeAll()
        isRecording = true
        NSLog("[SessionRecorder] Started recording session: \(name)")
    }

    public func stopSession() -> [RecordedAction] {
        isRecording = false
        let actions = recordedActions
        let duration = recordingStart.map { Date().timeIntervalSince($0) } ?? 0
        NSLog("[SessionRecorder] Stopped recording. \(actions.count) actions in \(String(format: "%.2f", duration))s")
        return actions
    }

    public func saveSession(to url: URL) -> Bool {
        let sessionData = SessionData(
            name: currentSession ?? "unnamed",
            startTime: recordingStart ?? Date(),
            endTime: Date(),
            actions: recordedActions
        )

        guard let data = try? JSONEncoder().encode(sessionData) else {
            NSLog("[SessionRecorder] Failed to encode session")
            return false
        }

        do {
            try data.write(to: url)
            NSLog("[SessionRecorder] Saved session to \(url.path)")
            return true
        } catch {
            NSLog("[SessionRecorder] Failed to save session: \(error)")
            return false
        }
    }

    public func loadSession(from url: URL) -> [RecordedAction]? {
        guard let data = try? Data(contentsOf: url),
              let sessionData = try? JSONDecoder().decode(SessionData.self, from: data) else {
            NSLog("[SessionRecorder] Failed to load session")
            return nil
        }

        currentSession = sessionData.name
        recordedActions = sessionData.actions
        NSLog("[SessionRecorder] Loaded session: \(sessionData.name) with \(sessionData.actions.count) actions")
        return sessionData.actions
    }

    // MARK: - Action Recording

    public func recordClick(at position: CGPoint, element: String? = nil) {
        guard isRecording else { return }

        let timestamp = recordingStart.map { Date().timeIntervalSince($0) } ?? 0
        let action = RecordedAction(
            type: .click,
            timestamp: timestamp,
            element: element,
            position: position,
            text: nil
        )
        recordedActions.append(action)
        NSLog("[SessionRecorder] Recorded click at \(position)")
    }

    public func recordType(element: String?, text: String) {
        guard isRecording else { return }

        let timestamp = recordingStart.map { Date().timeIntervalSince($0) } ?? 0
        let action = RecordedAction(
            type: .type,
            timestamp: timestamp,
            element: element,
            position: nil,
            text: text
        )
        recordedActions.append(action)
        NSLog("[SessionRecorder] Recorded type: '\(text.prefix(20))...'")
    }

    public func recordNavigate(to screen: String) {
        guard isRecording else { return }

        let timestamp = recordingStart.map { Date().timeIntervalSince($0) } ?? 0
        let action = RecordedAction(
            type: .navigate,
            timestamp: timestamp,
            element: screen,
            position: nil,
            text: nil
        )
        recordedActions.append(action)
        NSLog("[SessionRecorder] Recorded navigate to \(screen)")
    }

    // MARK: - Playback

    public func playSession(speed: Double = 1.0) async -> PlaybackResult {
        guard !isPlaying else {
            return PlaybackResult(
                success: false,
                totalActions: 0,
                successfulActions: 0,
                failedActions: 0,
                errors: ["Already playing"]
            )
        }

        isPlaying = true
        var successCount = 0
        var failures: [String] = []

        NSLog("[SessionRecorder] Starting playback of \(recordedActions.count) actions at \(speed)x speed")

        for (index, action) in recordedActions.enumerated() {
            let adjustedDelay = action.timestamp / speed

            // Wait until action time
            try? await Task.sleep(nanoseconds: UInt64(adjustedDelay * 1_000_000_000))

            let result: Bool
            switch action.type {
            case .click:
                if let pos = action.position {
                    let clickResult = await UIAutomation.shared.click(element: action.element, x: pos.x, y: pos.y)
                    result = clickResult["success"] as? Bool ?? false
                } else {
                    result = false
                }

            case .type:
                if let text = action.text {
                    let typeResult = await UIAutomation.shared.type(element: action.element, text: text)
                    result = typeResult["success"] as? Bool ?? false
                } else {
                    result = false
                }

            case .navigate:
                if let screen = action.element {
                    let navResult = await UIAutomation.shared.navigate(to: screen)
                    result = navResult["success"] as? Bool ?? false
                } else {
                    result = false
                }
            }

            if result {
                successCount += 1
            } else {
                failures.append("\(action.type) at \(String(format: "%.2f", action.timestamp))s")
            }

            NSLog("[SessionRecorder] Playback \(index + 1)/\(recordedActions.count): \(action.type) - \(result ? "OK" : "FAIL")")
        }

        isPlaying = false

        let playbackResult = PlaybackResult(
            success: failures.isEmpty,
            totalActions: recordedActions.count,
            successfulActions: successCount,
            failedActions: failures.count,
            errors: failures
        )

        NSLog("[SessionRecorder] Playback complete: \(successCount)/\(recordedActions.count) succeeded")

        return playbackResult
    }

    // MARK: - Export

    public func exportToJSON() -> String? {
        let sessionData = SessionData(
            name: currentSession ?? "unnamed",
            startTime: recordingStart ?? Date(),
            endTime: Date(),
            actions: recordedActions
        )

        guard let data = try? JSONEncoder().encode(sessionData),
              let json = try? JSONSerialization.jsonObject(with: data, options: [.allowFragments]) as? [String: Any] else {
            return nil
        }

        guard let jsonData = try? JSONSerialization.data(withJSONObject: json, options: .prettyPrinted) else {
            return nil
        }

        return String(data: jsonData, encoding: .utf8)
    }

    // MARK: - State

    public var isRecordingNow: Bool { isRecording }
    public var isPlayingNow: Bool { isPlaying }
    public var actionCount: Int { recordedActions.count }
    public var sessionName: String? { currentSession }
}

// MARK: - Supporting Types

public struct SessionData: Codable {
    public let name: String
    public let startTime: Date
    public let endTime: Date
    public let actions: [RecordedAction]
}

public struct RecordedAction: Codable {
    public enum ActionType: String, Codable {
        case click
        case type
        case navigate
    }

    public let type: ActionType
    public let timestamp: TimeInterval
    public let element: String?
    public let position: CGPoint?
    public let text: String?

    public func toJSON() -> [String: Any] {
        var result: [String: Any] = [
            "type": type.rawValue,
            "timestamp": timestamp
        ]
        if let element = element {
            result["element"] = element
        }
        if let position = position {
            result["position"] = ["x": position.x, "y": position.y]
        }
        if let text = text {
            result["text"] = text
        }
        return result
    }
}

public struct PlaybackResult {
    public let success: Bool
    public let totalActions: Int
    public let successfulActions: Int
    public let failedActions: Int
    public let errors: [String]

    public func toJSON() -> [String: Any] {
        [
            "success": success,
            "totalActions": totalActions,
            "successfulActions": successfulActions,
            "failedActions": failedActions,
            "errors": errors
        ]
    }
}

// CGPoint already has Codable support in CoreGraphics (iOS 7+, macOS 10.9+)
// No custom extension needed
