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
        HStack(alignment: .top, spacing: ParietalSpacing.md) {
            // Avatar with pulse effect
            avatarView

            // Content column
            VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
                // Label text
                Text("Trinity is typing...")
                    .font(.system(size: WernickeTypography.captionSize(dynamicTypeSize), weight: .medium))
                    .foregroundStyle(V4Color.textSecondary)

                // Bouncing dots
                bouncingDotsView

                // Optional skeleton preview
                if showSkeletonPreview {
                    skeletonPreview
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
            .padding(.vertical, ParietalSpacing.xs)
        }
        .padding(.horizontal, ParietalSpacing.lg)
        .padding(.vertical, ParietalSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.border, lineWidth: 1)
        )
        .scaleEffect(scale)
        .opacity(opacity)
        .onAppear {
            withAnimation(MTMotion.standardSpring) {
                scale = 1
                opacity = 1
            }
        }
        .onChange(of: isVisible) { _, newValue in
            if newValue {
                withAnimation(MTMotion.standardSpring) {
                    scale = 1
                    opacity = 1
                }
            } else {
                withAnimation(V1Theme.fadeAnimation) {
                    scale = MTMotion.exitScale
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
                .fill(V4Color.accent.opacity(V2Depth.bgSidebarHover))
                .frame(width: ParietalSpacing.smallIconFrame, height: ParietalSpacing.smallButtonHeight)

            // Simple triangle path
            Path { path in
                let size: CGFloat = 14
                path.move(to: CGPoint(x: size / 2, y: 2))
                path.addLine(to: CGPoint(x: size - 2, y: size - 2))
                path.addLine(to: CGPoint(x: 2, y: size - 2))
                path.closeSubpath()
            }
            .fill(V4Color.accent)
            .frame(width: ParietalSpacing.xSmallFrame, height: ParietalSpacing.subtitleHeight)

            if !reduceMotion {
                Circle()
                    .stroke(V4Color.accent.opacity(V2Depth.stateHover), lineWidth: 1.5)
                    .frame(width: ParietalSpacing.avatarSmall, height: ParietalSpacing.avatarSmall)
                    .scaleEffect(pulseScale)
                    .opacity(2 - pulseScale)
            }
        }
        .accessibilityHidden(true)
    }

    @State private var pulseScale: CGFloat = 1.0

    // MARK: - Bouncing Dots View

    private var bouncingDotsView: some View {
        HStack(spacing: ParietalSpacing.sm - 2) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(V4Color.accent)
                    .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)
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
        VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
            ForEach(0..<2) { _ in
                RoundedRectangle(cornerRadius: 4)
                    .fill(V4Color.textSecondary.opacity(V2Depth.bgSidebarHover))
                    .frame(height: 10)
                    .frame(maxWidth: CGFloat.random(in: 120...180))
            }
            RoundedRectangle(cornerRadius: 4)
                .fill(V4Color.textSecondary.opacity(V2Depth.bgSidebarHover))
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
                                V4Color.accent.opacity(V2Depth.bgSubtle),
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
        HStack(spacing: ParietalSpacing.xs) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(V4Color.accent)
                    .frame(width: ParietalSpacing.dotSize, height: 6)
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
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
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
                    .foregroundStyle(V4Color.textSecondary)
                CompactTypingIndicator()
            }
            .padding()
            .background(V4Color.surface)
            .cornerRadius(V1Theme.cornerMedium)
        }
        .padding()
        .frame(maxWidth: 400)
        .background(V4Color.background)
    }
}
