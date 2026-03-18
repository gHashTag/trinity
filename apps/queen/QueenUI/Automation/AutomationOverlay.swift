import SwiftUI
import AppKit

/// Visual feedback overlay for autonomous AI-controlled testing
/// Shows red cursor, click highlights, and action log in real-time
public struct AutomationOverlay: View {
    @StateObject private var server = ControlServer.shared
    @StateObject private var automation = UIAutomation.shared
    @State private var cursorPosition: CGPoint = .zero
    @State private var highlightPosition: CGPoint?
    @State private var highlightOpacity: Double = 0
    @State private var mouseMonitor: Any?
    @State private var clickAnimationPhase: CGFloat = 0

    public init() {}

    public var body: some View {
        ZStack {
            // Semi-transparent dark overlay
            Color.black.opacity(0.05)
                .allowsHitTesting(false)

            // Red cursor indicator - more prominent
            ZStack {
                // Outer glow
                Circle()
                    .fill(Color.red.opacity(0.3))
                    .frame(width: 24, height: 24)
                    .blur(radius: 4)

                // Main cursor
                Circle()
                    .fill(Color.red)
                    .frame(width: 12, height: 12)
                    .shadow(color: .red, radius: 6)

                // White center dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 4, height: 4)
            }
            .position(x: cursorPosition.x, y: cursorPosition.y)
            .allowsHitTesting(false)

            // Click highlight animation
            if let pos = highlightPosition {
                ZStack {
                    // Expanding rings
                    ForEach(0..<3) { i in
                        Circle()
                            .stroke(Color.white, lineWidth: 2)
                            .frame(width: 60 + CGFloat(i) * 20, height: 60 + CGFloat(i) * 20)
                            .opacity(Double(3 - i) * highlightOpacity * 0.5)
                    }

                    // Central crosshair
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

            // Status panel (top-left) - more visible
            VStack(alignment: .leading, spacing: 6) {
                // Puppet Mode badge - larger and more prominent
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
                            .opacity(0.8 + 0.2 * sin(Date().timeIntervalSince1970 * 5)) // Pulsing
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

                // Server info
                if server.isRunning {
                    HStack(spacing: 12) {
                        Label("localhost:\(server.port)", systemImage: "server.rack")
                        Label("\(server.connectedClients) client(s)", systemImage: "person.2")
                    }
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(4)
                }

                // Last activity
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

            // Action log (bottom-right) - more visible
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
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            .padding(16)
            .allowsHitTesting(false)

            // Coordinates display (bottom-left)
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
        .onAppear {
            startMouseTracking()
        }
        .onDisappear {
            stopMouseTracking()
        }
    }

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
