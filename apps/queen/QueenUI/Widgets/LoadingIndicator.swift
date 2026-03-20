import SwiftUI

// MARK: - ThinkingDots

struct ThinkingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(V4Color.accent)
                    .frame(width: 6, height: 6)
                    .opacity(phase == i ? 1.0 : 0.3)
            }
        }
        .task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(400))
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - StreamingText

struct StreamingText: View {
    let text: String
    @State private var visibleCount = 0

    var body: some View {
        HStack(spacing: 0) {
            Text(String(text.prefix(visibleCount)))
                .font(.body.monospaced())
                .foregroundStyle(V4Color.textPrimary)
            if visibleCount < text.count {
                BlinkingCursor()
            }
        }
        .drawingGroup()
        .task(id: text) {
            let total = text.count
            var pos = 0
            while pos < total && !Task.isCancelled {
                let batch = min(pos < 50 ? 3 : (total - pos), 5)
                pos += batch
                visibleCount = pos
                if pos < 50 {
                    try? await Task.sleep(for: .milliseconds(30))
                }
            }
            visibleCount = total
        }
    }
}

// MARK: - ToolProgress

struct ToolProgress: View {
    let tool: String
    let completed: Bool
    let success: Bool

    @State private var shimmerOffset: CGFloat = -0.3

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            Text(tool)
                .font(.caption.monospaced())
                .foregroundStyle(V4Color.textSecondary)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(V4Color.surface)
                    if completed {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(success ? V4Color.success : V4Color.error)
                            .frame(width: geo.size.width)
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.accent.opacity(V1Theme.opacityTextSecondary))
                            .frame(width: geo.size.width * 0.3)
                            .offset(x: shimmerOffset * geo.size.width)
                    }
                }
            }
            .frame(height: ParietalSpacing.xs)
        }
        .task {
            guard !completed else { return }
            while !Task.isCancelled {
                withAnimation(.linear(duration: 1.0)) { shimmerOffset = 0.7 }
                try? await Task.sleep(for: .seconds(1))
                shimmerOffset = -0.3
            }
        }
    }
}

// MARK: - BlinkingCursor

struct BlinkingCursor: View {
    @State private var visible = true

    var body: some View {
        Rectangle()
            .fill(V4Color.accent)
            .frame(width: 8, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) { visible.toggle() }
            }
    }
}
