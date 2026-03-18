import SwiftUI
import AppKit
import Combine

/// Visual feedback overlay for autonomous AI-controlled testing
/// Shows gaze tracking, hesitation markers, decision indicators, and action log
public struct AutomationOverlay: View {
    @StateObject private var server = ControlServer.shared
    @StateObject private var automation = UIAutomation.shared
    @State private var cursorPosition: CGPoint = .zero
    @State private var highlightPosition: CGPoint?
    @State private var highlightOpacity: Double = 0
    @State private var mouseMonitor: Any?
    @State private var clickAnimationPhase: CGFloat = 0

    // Enhanced visual feedback state
    @State private var gazePosition: CGPoint = .zero
    @State private var gazeActive: Bool = false
    @State private var isThinking: Bool = false
    @State private var thinkingPhase: Double = 0
    @State private var currentAction: String = ""
    @State private var actionProgress: Double = 0
    @State private var errorCorrection: ErrorCorrectionEvent?
    @State private var decisionPoints: [DecisionPoint] = []

    public init() {}

    // Helper view builder to break up complex body
    private var cursorIndicator: some View {
        ZStack {
            Circle()
                .fill(Color.red.opacity(0.3))
                .frame(width: 24, height: 24)
                .blur(radius: 4)
            Circle()
                .fill(Color.red)
                .frame(width: 12, height: 12)
                .shadow(color: .red, radius: 6)
            Circle()
                .fill(Color.white)
                .frame(width: 4, height: 4)
        }
        .position(x: cursorPosition.x, y: cursorPosition.y)
        .allowsHitTesting(false)
    }

    private var clickHighlightView: some View {
        Group {
            if let pos = highlightPosition {
                ZStack {
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 60 + CGFloat(i) * 20, height: 60 + CGFloat(i) * 20)
                            .opacity(Double(3 - i) * highlightOpacity * 0.5)
                    }
                    Group {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 20, height: 2)
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: 2, height: 20)
                    }
                    .opacity(highlightOpacity)
                }
                .position(pos)
                .onAppear {
                    withAnimation(.easeOut(duration: 0.5)) {
                        highlightOpacity = 0
                    }
                }
            }
        }
    }

    private var gazeIndicator: some View {
        Group {
            if gazeActive {
                ZStack {
                    Circle()
                        .fill(Color.cyan.opacity(0.15))
                        .frame(width: 120, height: 120)
                        .blur(radius: 20)
                    Circle()
                        .stroke(Color.cyan.opacity(0.6), lineWidth: 1.5)
                        .frame(width: 80, height: 80)
                    Image(systemName: "eye.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.cyan.opacity(0.8))
                }
                .position(gazePosition)
                .allowsHitTesting(false)
            }
        }
    }

    private var thinkingIndicator: some View {
        Group {
            if isThinking {
                VStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: 40, height: 40)
                            .opacity(0.3 + 0.3 * sin(thinkingPhase * 4))
                            .scaleEffect(1.0 + 0.2 * sin(thinkingPhase * 3))
                        Circle()
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: 24, height: 24)
                        Image(systemName: "brain.head.profile")
                            .font(.system(size: 12))
                            .foregroundStyle(.white)
                    }
                    Text("THINKING")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(Color.orange.opacity(0.9))
                }
                .position(x: cursorPosition.x + 50, y: cursorPosition.y - 50)
                .allowsHitTesting(false)
            }
        }
    }

    private var actionIndicator: some View {
        Group {
            if !currentAction.isEmpty {
                HStack(spacing: 6) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(0.6))
                            .frame(width: 80, height: 4)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: 80 * actionProgress, height: 4)
                    }
                    Text(currentAction)
                        .font(.system(size: 9, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.black.opacity(0.75))
                        )
                }
                .position(x: cursorPosition.x, y: cursorPosition.y + 40)
                .allowsHitTesting(false)
            }
        }
    }

    private var errorCorrectionView: some View {
        Group {
            if let error = errorCorrection {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(.system(size: 10))
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CORRECTING")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.orange)
                        Text("\"\(error.wrongText.prefix(15))\" → \"\(error.correctedText.prefix(15))\"")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.orange.opacity(0.6), lineWidth: 1)
                        )
                )
                .position(error.position)
                .allowsHitTesting(false)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        errorCorrection = nil
                    }
                }
            }
        }
    }

    private var decisionPointsView: some View {
        ForEach(decisionPoints.indices, id: \.self) { index in
            let point = decisionPoints[index]
            VStack(spacing: 2) {
                Circle()
                    .fill(Color.purple)
                    .frame(width: 8, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
                Text(point.label)
                    .font(.system(size: 6, weight: .bold, design: .monospaced))
                    .foregroundStyle(.purple.opacity(0.9))
            }
            .position(point.position)
            .allowsHitTesting(false)
            .opacity(point.opacity)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle()
                    .fill(server.isRunning ? Color.green : Color.red)
                    .frame(width: 10, height: 10)
                    .shadow(color: server.isRunning ? .green : .red, radius: 4)
                Text("🤖 PUPPET MODE")
                    .font(.system(size: 12, weight: .black, design: .monospaced))
                    .foregroundStyle(.white)
                if server.isRunning {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 6, height: 6)
                        .opacity(0.8 + 0.2 * sin(Date().timeIntervalSince1970 * 5))
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.8))
                    .shadow(color: .black.opacity(0.5), radius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.red, lineWidth: 2)
            )

            if server.isRunning {
                HStack(spacing: 12) {
                    Text("localhost:\(server.port)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                    Text("\(server.connectedClients) client(s)")
                        .font(.system(size: 10, weight: .medium, design: .monospaced))
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
            }

            if !server.lastActivity.isEmpty {
                Text(server.lastActivity.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(16)
        .allowsHitTesting(false)
    }

    private var actionLogView: some View {
        VStack(alignment: .trailing, spacing: 4) {
            Text("ACTION LOG")
                .font(.system(size: 8, weight: .bold, design: .monospaced))
                .foregroundStyle(.white.opacity(0.6))
            ForEach(Array(automation.actionLog.enumerated().reversed()), id: \.offset) { _, action in
                HStack(spacing: 4) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 4, height: 4)
                    Text(action)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.75))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(16)
        .allowsHitTesting(false)
    }

    private var coordinatesView: some View {
        Group {
            if server.isRunning {
                HStack(spacing: 8) {
                    Text("X: \(Int(cursorPosition.x))")
                    Text("Y: \(Int(cursorPosition.y))")
                }
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.7))
                .cornerRadius(4)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(16)
                .allowsHitTesting(false)
            }
        }
    }

    public var body: some View {
        ZStack {
            // Semi-transparent dark overlay
            Color.black.opacity(0.05)
                .allowsHitTesting(false)

            // All visual feedback elements
            cursorIndicator
            clickHighlightView
            gazeIndicator
            thinkingIndicator
            actionIndicator
            errorCorrectionView
            decisionPointsView
            statusPanel
            actionLogView
            coordinatesView
        }
        .onAppear {
            startMouseTracking()
            subscribeToAutomationEvents()
        }
        .onDisappear {
            stopMouseTracking()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutomationGazeUpdate"))) { notification in
            if let userInfo = notification.userInfo,
               let x = userInfo["x"] as? CGFloat,
               let y = userInfo["y"] as? CGFloat {
                gazePosition = CGPoint(x: x, y: y)
                gazeActive = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    gazeActive = false
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutomationThinkingStart"))) { _ in
            isThinking = true
            thinkingPhase = 0
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutomationThinkingEnd"))) { _ in
            isThinking = false
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutomationActionStart"))) { notification in
            if let userInfo = notification.userInfo,
               let action = userInfo["action"] as? String {
                currentAction = action
                actionProgress = 0
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutomationActionProgress"))) { notification in
            if let userInfo = notification.userInfo,
               let progress = userInfo["progress"] as? Double {
                actionProgress = progress
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutomationActionEnd"))) { _ in
            currentAction = ""
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutomationErrorCorrection"))) { notification in
            if let userInfo = notification.userInfo,
               let wrong = userInfo["wrong"] as? String,
               let correct = userInfo["correct"] as? String,
               let x = userInfo["x"] as? CGFloat,
               let y = userInfo["y"] as? CGFloat {
                errorCorrection = ErrorCorrectionEvent(
                    wrongText: wrong,
                    correctedText: correct,
                    position: CGPoint(x: x, y: y)
                )
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSNotification.Name("AutomationDecisionPoint"))) { notification in
            if let userInfo = notification.userInfo,
               let x = userInfo["x"] as? CGFloat,
               let y = userInfo["y"] as? CGFloat,
               let label = userInfo["label"] as? String {
                let point = DecisionPoint(position: CGPoint(x: x, y: y), label: label, opacity: 1)
                decisionPoints.append(point)
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    if let index = decisionPoints.firstIndex(where: { $0.label == label }) {
                        decisionPoints.remove(at: index)
                    }
                }
            }
        }
    }

    // MARK: - Event Subscription

    private func subscribeToAutomationEvents() {
        // Timer for thinking animation
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { _ in
                if isThinking {
                    thinkingPhase += 0.1
                }
            }
            .store(in: &cancellables)
    }

    @State private var cancellables: Set<AnyCancellable> = []

    // MARK: - Mouse Tracking

    private func startMouseTracking() {
        mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .mouseMoved) { [self] event in
            cursorPosition = event.locationInWindow
            return event
        }
    }

    private func stopMouseTracking() {
        if let monitor = mouseMonitor {
            NSEvent.removeMonitor(monitor)
            mouseMonitor = nil
        }
    }
}

/// Live highlight animation for click feedback
public struct ClickHighlight: ViewModifier {
    @State private var scale: CGFloat = 0.5
    @State private var opacity: Double = 1

    public func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 0.3)) {
                    scale = 1.5
                    opacity = 0
                }
            }
    }
}

extension View {
    public func clickHighlight() -> some View {
        modifier(ClickHighlight())
    }
}

// MARK: - Supporting Types

/// Error correction event for visualizing typo fixes
public struct ErrorCorrectionEvent {
    public let wrongText: String
    public let correctedText: String
    public let position: CGPoint
}

/// Decision point marker for showing AI choices
public struct DecisionPoint: Identifiable {
    public let id = UUID()
    public let position: CGPoint
    public let label: String
    public var opacity: Double
}
