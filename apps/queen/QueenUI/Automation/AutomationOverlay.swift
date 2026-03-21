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
                .fill(Color.red.opacity(V2Depth.stateHover))
                .frame(width: ParietalSpacing.iconButtonFrame, height: ParietalSpacing.chipHeight)
                .blur(radius: 4)
            Circle()
                .fill(Color.red)
                .frame(width: ParietalSpacing.mediumBadge, height: ParietalSpacing.badgeHeight)
                .shadow(color: .red, radius: 6)
            Circle()
                .fill(Color.white)
                .frame(width: ParietalSpacing.smallIndicator, height: ParietalSpacing.microHeight)
        }
        .position(x: cursorPosition.x, y: cursorPosition.y)
        .allowsHitTesting(false)
    }

    private var clickHighlightView: some View {
        Group {
            if let pos = highlightPosition {
                ZStack {
                    // Expanding circles
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 60 + CGFloat(i) * 20, height: 60 + CGFloat(i) * 20)
                            .opacity(Double(3 - i) * highlightOpacity * 0.5)
                    }

                    // Crosshair lines
                    VStack(spacing: 0) {
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: ParietalSpacing.chipWidth, height: 2)
                        Rectangle()
                            .fill(Color.white)
                            .frame(width: ParietalSpacing.dividerThickness, height: ParietalSpacing.iconHeight)
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
                        .fill(Color.cyan.opacity(V2Depth.bgSidebarHover))
                        .frame(width: ParietalSpacing.xxxLargeFrame, height: ParietalSpacing.xxxLargeFrame)
                        .blur(radius: 20)
                    Circle()
                        .stroke(Color.cyan.opacity(V1Theme.opacityTextSecondary), lineWidth: 1.5)
                        .frame(width: ParietalSpacing.xLargeFrame, height: ParietalSpacing.xLargeFrame)
                    Image(systemName: "eye.fill")
                        .font(WernickeTypography.size14)
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
                VStack(spacing: ParietalSpacing.xs) {
                    ZStack {
                        Circle()
                            .stroke(Color.orange, lineWidth: 2)
                            .frame(width: ParietalSpacing.standardFrame, height: ParietalSpacing.itemHeight)
                            .opacity(0.3 + 0.3 * sin(thinkingPhase * 4))
                            .scaleEffect(1.0 + 0.2 * sin(thinkingPhase * 3))
                        Circle()
                            .fill(Color.orange.opacity(0.8))
                            .frame(width: ParietalSpacing.iconButtonFrame, height: ParietalSpacing.chipHeight)
                        Image(systemName: "brain.head.profile")
                            .font(WernickeTypography.caption)
                            .foregroundStyle(.white)
                    }
                    Text("THINKING")
                        .font(WernickeTypography.size7.weight(.bold).monospaced())
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
                HStack(spacing: ParietalSpacing.xxs) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.black.opacity(V1Theme.opacityTextSecondary))
                            .frame(width: ParietalSpacing.xLargeFrame, height: ParietalSpacing.microHeight)
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.green)
                            .frame(width: 80 * actionProgress, height: ParietalSpacing.microHeight)
                    }
                    Text(currentAction)
                        .font(WernickeTypography.microSemibold.monospaced())
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
                HStack(spacing: ParietalSpacing.xxs) {
                    Image(systemName: "arrow.uturn.backward")
                        .font(WernickeTypography.mini)
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("CORRECTING")
                            .font(WernickeTypography.size7.weight(.bold))
                            .foregroundStyle(.orange)
                        Text("\"\(error.wrongText.prefix(15))\" → \"\(error.correctedText.prefix(15))\"")
                            .font(WernickeTypography.size8)
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.2))
                        .overlay(
                            RoundedRectangle(cornerRadius: 4)
                                .stroke(Color.orange.opacity(V1Theme.opacityTextSecondary), lineWidth: 1)
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
                    .frame(width: ParietalSpacing.tinyIndicator, height: 8)
                    .overlay(
                        Circle()
                            .stroke(Color.white, lineWidth: 1)
                    )
                Text(point.label)
                    .font(WernickeTypography.microMedium)
                    .foregroundStyle(.purple.opacity(0.9))
            }
            .position(point.position)
            .allowsHitTesting(false)
            .opacity(point.opacity)
        }
    }

    private var statusPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: ParietalSpacing.sm) {
                Circle()
                    .fill(server.isRunning ? Color.green : Color.red)
                    .frame(width: ParietalSpacing.smallBadge, height: ParietalSpacing.captionHeight)
                    .shadow(color: server.isRunning ? .green : .red, radius: 4)
                Text("🤖 PUPPET MODE")
                    .font(WernickeTypography.captionBold.monospaced())
                    .foregroundStyle(.white)
                if server.isRunning {
                    Circle()
                        .fill(Color.green)
                        .frame(width: ParietalSpacing.dotSize, height: 6)
                        .opacity(0.8 + 0.2 * sin(Date().timeIntervalSince1970 * 5))
                }
            }
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.black.opacity(0.8))
                    .shadow(color: .black.opacity(V2Depth.stateDisabled), radius: 8)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.red, lineWidth: 2)
            )

            if server.isRunning {
                HStack(spacing: ParietalSpacing.md) {
                    Text("localhost:\(server.port)")
                        .font(WernickeTypography.miniMono)
                    Text("\(server.connectedClients) client(s)")
                        .font(WernickeTypography.miniMono)
                }
                .foregroundStyle(.white.opacity(0.9))
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(V2Depth.black70)
                .cornerRadius(V1Theme.cornerTiny)
            }

            if !server.lastActivity.isEmpty {
                Text(server.lastActivity.uppercased())
                    .font(WernickeTypography.microBold.monospaced())
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, ParietalSpacing.xs)
                    .padding(.vertical, 2)
                    .background(V2Depth.black70)
                    .cornerRadius(V1Theme.cornerTiny)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .padding(ParietalSpacing.md)
        .allowsHitTesting(false)
    }

    private var actionLogView: some View {
        VStack(alignment: .trailing, spacing: ParietalSpacing.xs) {
            Text("ACTION LOG")
                .font(WernickeTypography.size8.weight(.bold).monospaced())
                .foregroundStyle(.white.opacity(V1Theme.opacityTextSecondary))
            ForEach(Array(automation.actionLog.enumerated().reversed()), id: \.offset) { _, action in
                HStack(spacing: ParietalSpacing.xs) {
                    Circle()
                        .fill(Color.red)
                        .frame(width: ParietalSpacing.smallIndicator, height: ParietalSpacing.microHeight)
                    Text(action)
                        .font(WernickeTypography.caption2.monospaced())
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.75))
                )
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        .padding(ParietalSpacing.md)
        .allowsHitTesting(false)
    }

    private var coordinatesView: some View {
        Group {
            if server.isRunning {
                HStack(spacing: ParietalSpacing.sm) {
                    Text("X: \(Int(cursorPosition.x))")
                    Text("Y: \(Int(cursorPosition.y))")
                }
                .font(WernickeTypography.miniMono)
                .foregroundStyle(.white.opacity(0.8))
                .padding(.horizontal, ParietalSpacing.xs)
                .padding(.vertical, ParietalSpacing.xxs)
                .background(V2Depth.black70)
                .cornerRadius(V1Theme.cornerTiny)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(ParietalSpacing.md)
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
