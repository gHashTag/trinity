import SwiftUI

// MARK: - ThinkingDots

struct ThinkingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .fill(TrinityTheme.accent)
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
                .foregroundStyle(TrinityTheme.textPrimary)
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
        HStack(spacing: 8) {
            Text(tool)
                .font(.caption.monospaced())
                .foregroundStyle(TrinityTheme.textMuted)
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(TrinityTheme.bgCard)
                    if completed {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(success ? TrinityTheme.statusOK : TrinityTheme.statusError)
                            .frame(width: geo.size.width)
                    } else {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(TrinityTheme.accent.opacity(0.6))
                            .frame(width: geo.size.width * 0.3)
                            .offset(x: shimmerOffset * geo.size.width)
                    }
                }
            }
            .frame(height: 4)
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
            .fill(TrinityTheme.accent)
            .frame(width: 8, height: 16)
            .opacity(visible ? 1 : 0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.5).repeatForever()) { visible.toggle() }
            }
    }
}
