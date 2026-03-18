import SwiftUI

/// Canvas-based DAG visualization for Golden Chain pipeline steps.
/// Each step is a capsule node connected by bezier curves.
struct WorkflowDAG: View {
    let steps: [DAGStep]
    var onTapStep: ((DAGStep) -> Void)?

    @State private var hoveredStep: String?

    struct DAGStep: Identifiable {
        let id: String
        let label: String
        let phase: String
        let status: StepStatus
        let duration: String?
        let error: String?

        enum StepStatus {
            case pending, running, done, failed

            var color: Color {
                switch self {
                case .pending: return TrinityTheme.textMuted
                case .running: return TrinityTheme.golden
                case .done: return TrinityTheme.statusOK
                case .failed: return TrinityTheme.statusError
                }
            }
        }
    }

    // Layout constants
    private let nodeWidth: CGFloat = 100
    private let nodeHeight: CGFloat = 36
    private let rowSpacing: CGFloat = 16
    private let colSpacing: CGFloat = 24

    var body: some View {
        GeometryReader { geo in
            let cols = max(1, Int(geo.size.width / (nodeWidth + colSpacing)))
            let rows = (steps.count + cols - 1) / cols

            Canvas { ctx, size in
                // Draw edges first (behind nodes)
                for i in 0..<steps.count - 1 {
                    let from = nodeCenter(index: i, cols: cols)
                    let to = nodeCenter(index: i + 1, cols: cols)
                    drawEdge(ctx: ctx, from: from, to: to, color: steps[i].status.color)
                }

                // Draw nodes
                for (i, step) in steps.enumerated() {
                    let center = nodeCenter(index: i, cols: cols)
                    let isHovered = hoveredStep == step.id
                    drawNode(ctx: ctx, center: center, step: step, isHovered: isHovered)
                }
            }
            .frame(height: CGFloat(rows) * (nodeHeight + rowSpacing) + 20)
            .onContinuousHover { phase in
                switch phase {
                case .active(let loc):
                    hoveredStep = hitTestNode(location: loc, cols: cols)
                case .ended:
                    hoveredStep = nil
                @unknown default:
                    hoveredStep = nil
                }
            }
            .onTapGesture { loc in
                if let id = hitTestNode(location: loc, cols: max(1, Int(geo.size.width / (nodeWidth + colSpacing)))),
                   let step = steps.first(where: { $0.id == id }) {
                    onTapStep?(step)
                }
            }
        }
    }

    private func nodeCenter(index: Int, cols: Int) -> CGPoint {
        let col = index % cols
        let row = index / cols
        let x = CGFloat(col) * (nodeWidth + colSpacing) + nodeWidth / 2 + 10
        let y = CGFloat(row) * (nodeHeight + rowSpacing) + nodeHeight / 2 + 10
        return CGPoint(x: x, y: y)
    }

    private func drawNode(ctx: GraphicsContext, center: CGPoint, step: DAGStep, isHovered: Bool) {
        let rect = CGRect(
            x: center.x - nodeWidth / 2,
            y: center.y - nodeHeight / 2,
            width: nodeWidth,
            height: nodeHeight
        )
        let capsule = Path(roundedRect: rect, cornerRadius: nodeHeight / 2)

        // Fill
        let fillColor = isHovered ? step.status.color.opacity(0.3) : step.status.color.opacity(0.12)
        ctx.fill(capsule, with: .color(fillColor))

        // Stroke
        ctx.stroke(capsule, with: .color(step.status.color), lineWidth: isHovered ? 2 : 1)

        // Pulse ring for running
        if step.status == .running {
            let outerRect = rect.insetBy(dx: -3, dy: -3)
            let outerCapsule = Path(roundedRect: outerRect, cornerRadius: (nodeHeight + 6) / 2)
            ctx.stroke(outerCapsule, with: .color(step.status.color.opacity(0.4)), lineWidth: 1)
        }

        // Label text
        ctx.draw(
            Text(step.label)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundStyle(step.status.color),
            at: center
        )
    }

    private func drawEdge(ctx: GraphicsContext, from: CGPoint, to: CGPoint, color: Color) {
        var path = Path()

        if abs(from.y - to.y) < 1 {
            // Same row: simple horizontal line
            path.move(to: CGPoint(x: from.x + nodeWidth / 2, y: from.y))
            path.addLine(to: CGPoint(x: to.x - nodeWidth / 2, y: to.y))
        } else {
            // Different row: bezier curve
            let startX = from.x + nodeWidth / 2
            let endX = to.x - nodeWidth / 2
            let midY = (from.y + to.y) / 2

            path.move(to: CGPoint(x: startX, y: from.y))
            path.addCurve(
                to: CGPoint(x: endX, y: to.y),
                control1: CGPoint(x: startX + 30, y: midY),
                control2: CGPoint(x: endX - 30, y: midY)
            )
        }

        ctx.stroke(
            path,
            with: .color(color.opacity(0.5)),
            style: StrokeStyle(lineWidth: 1.5, lineCap: .round)
        )
    }

    private func hitTestNode(location: CGPoint, cols: Int) -> String? {
        for (i, step) in steps.enumerated() {
            let center = nodeCenter(index: i, cols: cols)
            let rect = CGRect(
                x: center.x - nodeWidth / 2,
                y: center.y - nodeHeight / 2,
                width: nodeWidth,
                height: nodeHeight
            )
            if rect.contains(location) {
                return step.id
            }
        }
        return nil
    }
}
