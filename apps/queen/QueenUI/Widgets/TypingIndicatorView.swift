import SwiftUI

// MARK: - Typing Indicator View

/// An animated typing indicator showing "Trinity is typing..." with bouncing dots.
/// Supports smooth entrance/exit animations, configurable animation speed, and accessibility.
struct TypingIndicatorView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let isVisible: Bool
    let animationSpeed: AnimationSpeed
    let showSkeletonPreview: Bool

    @State private var scale: CGFloat = 0
    @State private var opacity: Double = 0

    enum AnimationSpeed: String, CaseIterable {
        case slow = "Slow"
        case normal = "Normal"
        case fast = "Fast"

        var dotDuration: Double {
            switch self {
            case .slow: return 0.6
            case .normal: return 0.4
            case .fast: return 0.25
            }
        }

        var waveDelay: Double {
            switch self {
            case .slow: return 0.2
            case .normal: return 0.12
            case .fast: return 0.08
            }
        }
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            // Avatar with pulse effect
            avatarView

            // Content column
            VStack(alignment: .leading, spacing: 6) {
                // Label text
                Text("Trinity is typing...")
                    .font(.system(size: TrinityTheme.captionSize(dynamicTypeSize), weight: .medium))
                    .foregroundStyle(TrinityTheme.textMuted)

                // Bouncing dots
                bouncingDotsView

                // Optional skeleton preview
                if showSkeletonPreview {
                    skeletonPreview
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, 4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .fill(TrinityTheme.bgCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(TrinityTheme.bgCardBorder, lineWidth: 1)
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(TrinityTheme.springAnimation()) {
                scale = 1
                opacity = 1
            }
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                withAnimation(TrinityTheme.springAnimation()) {
                    scale = 1
                    opacity = 1
                }
            } else {
                withAnimation(TrinityTheme.fadeAnimation) {
                    scale = TrinityTheme.messageExitScale
                    opacity = 0
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trinity is typing")
        .accessibilityHint("Waiting for response")
    }

    // MARK: - Avatar View

    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(TrinityTheme.accent.opacity(0.15))
                .frame(width: 28, height: 28)

            // Simple triangle path
            Path { path in
                let size: CGFloat = 14
                path.move(to: CGPoint(x: size / 2, y: 2))
                path.addLine(to: CGPoint(x: size - 2, y: size - 2))
                path.addLine(to: CGPoint(x: 2, y: size - 2))
                path.closeSubpath()
            }
            .fill(TrinityTheme.accent)
            .frame(width: 14, height: 14)

            if !reduceMotion {
                Circle()
                    .stroke(TrinityTheme.accent.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 32, height: 32)
                    .scaleEffect(pulseScale)
                    .opacity(2 - pulseScale)
            }
        }
        .accessibilityHidden(true)
    }

    @State private var pulseScale: CGFloat = 1.0

    // MARK: - Bouncing Dots View

    private var bouncingDotsView: some View {
        HStack(spacing: 6) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(TrinityTheme.accent)
                    .frame(width: 8, height: 8)
                    .scaleEffect(reduceMotion ? 1 : dotScales[index])
                    .opacity(reduceMotion ? 0.6 : dotOpacities[index])
            }
        }
        .padding(.top, 2)
        .accessibilityHidden(true)
        .onAppear {
            guard !reduceMotion else { return }
            startDotAnimation()
        }
    }

    @State private var dotScales: [CGFloat] = [1, 1, 1]
    @State private var dotOpacities: [Double] = [0.3, 1.0, 0.3]

    private func startDotAnimation() {
        Task {
            while !Task.isCancelled {
                let duration = animationSpeed.dotDuration
                let delay = animationSpeed.waveDelay

                // Animate each dot with staggered delay
                for i in 0..<3 {
                    let delay = delay * Double(i)
                    try? await Task.sleep(for: .seconds(delay))

                    await MainActor.run {
                        withAnimation(.easeInOut(duration: duration)) {
                            dotScales[i] = 1.4
                            dotOpacities[i] = 1.0
                        }
                    }

                    try? await Task.sleep(for: .seconds(duration))

                    await MainActor.run {
                        withAnimation(.easeInOut(duration: duration)) {
                            dotScales[i] = 1.0
                            dotOpacities[i] = 0.3
                        }
                    }
                }

                // Pause before next cycle
                try? await Task.sleep(for: .seconds(duration))
            }
        }
    }

    // MARK: - Skeleton Preview

    private var skeletonPreview: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(0..<2) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .fill(TrinityTheme.textMuted.opacity(0.15))
                    .frame(height: 10)
                    .frame(maxWidth: CGFloat.random(in: 120...180))
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(TrinityTheme.textMuted.opacity(0.15))
                .frame(height: 10)
                .frame(maxWidth: 80)
        }
        .padding(.top, 4)
        .overlay(
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [
                                .clear,
                                TrinityTheme.accent.opacity(0.1),
                                .clear
                            ],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .offset(x: shimmerOffset)
                    .onAppear {
                        guard !reduceMotion else { return }
                        withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                            shimmerOffset = geo.size.width * 2
                        }
                    }
            }
        )
        .clipped()
        .accessibilityHidden(true)
    }

    @State private var shimmerOffset: CGFloat = -200
}

// MARK: - Compact Typing Indicator

/// A minimal inline version of the typing indicator for use in tight spaces.
struct CompactTypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(TrinityTheme.accent)
                    .frame(width: 6, height: 6)
                    .scaleEffect(reduceMotion ? 1 : scales[index])
                    .opacity(reduceMotion ? 0.6 : opacities[index])
            }
        }
        .accessibilityLabel("Typing")
        .onAppear {
            guard !reduceMotion else { return }
            animate()
        }
    }

    @State private var scales: [CGFloat] = [0.6, 1, 0.6]
    @State private var opacities: [Double] = [0.3, 1, 0.3]
    @State private var phase = 0

    private func animate() {
        Task {
            while !Task.isCancelled {
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.3)) {
                        phase = (phase + 1) % 3
                        for i in 0..<3 {
                            let offset = (i - phase + 3) % 3
                            scales[i] = offset == 1 ? 1.2 : 0.8
                            opacities[i] = offset == 1 ? 1.0 : 0.4
                        }
                    }
                }
                try? await Task.sleep(for: .milliseconds(350))
            }
        }
    }
}

// MARK: - Preview Provider

struct TypingIndicatorView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Full indicator with skeleton
            TypingIndicatorView(
                isVisible: true,
                animationSpeed: .normal,
                showSkeletonPreview: true
            )

            // Full indicator without skeleton
            TypingIndicatorView(
                isVisible: true,
                animationSpeed: .fast,
                showSkeletonPreview: false
            )

            // Compact version
            HStack {
                Text("Response incoming")
                    .foregroundStyle(TrinityTheme.textMuted)
                CompactTypingIndicator()
            }
            .padding()
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerMedium)
        }
        .padding()
        .frame(maxWidth: 400)
        .background(TrinityTheme.bgWindow)
    }
}
