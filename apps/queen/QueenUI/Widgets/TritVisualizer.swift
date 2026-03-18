import SwiftUI

struct TritVisualizer: View {
    let values: [Int8]
    var cellSize: CGFloat = 3

    var body: some View {
        let cols = Int(sqrt(Double(values.count)))
        let rows = values.count / max(cols, 1)

        Canvas { context, size in
            for row in 0..<rows {
                for col in 0..<cols {
                    let idx = row * cols + col
                    guard idx < values.count else { continue }

                    let rect = CGRect(
                        x: CGFloat(col) * cellSize,
                        y: CGFloat(row) * cellSize,
                        width: cellSize - 0.5,
                        height: cellSize - 0.5
                    )

                    let color: Color
                    switch values[idx] {
                    case 1: color = TrinityTheme.accent
                    case -1: color = TrinityTheme.purple
                    default: color = TrinityTheme.bgCard
                    }

                    context.fill(Path(rect), with: .color(color))
                }
            }
        }
        .frame(
            width: CGFloat(cols) * cellSize,
            height: CGFloat(rows) * cellSize
        )
    }
}