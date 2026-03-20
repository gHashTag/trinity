// Animation View — Reusable Animations
import SwiftUI

// MARK: - Fade In Animation

struct FadeIn<Content: View>: View {
    let duration: Double
    let delay: Double
    let content: Content
    @State private var isVisible = false

    init(
        duration: Double = 0.4,
        delay: Double = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.duration = duration
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Slide In Animation

struct SlideIn<Content: View>: View {
    let edge: Edge
    let duration: Double
    let content: Content
    @State private var offset: CGFloat

    enum Edge {
        case top, bottom, leading, trailing

        var offsetValue: CGFloat {
            switch self {
            case .top: return -50
            case .bottom: return 50
            case .leading: return -50
            case .trailing: return 50
            }
        }
    }

    init(
        edge: Edge = .trailing,
        duration: Double = 0.4,
        @ViewBuilder content: () -> Content
    ) {
        self.edge = edge
        self.duration = duration
        self._offset = State(initialValue: edge.offsetValue)
        self.content = content()
    }

    var body: some View {
        content
            .offset(x: xOffset, y: yOffset)
            .onAppear {
                withAnimation(.spring(response: duration, dampingFraction: 0.8)) {
                    offset = 0
                }
            }
    }

    private var xOffset: CGFloat {
        (edge == .leading || edge == .trailing) ? offset : 0
    }

    private var yOffset: CGFloat {
        (edge == .top || edge == .bottom) ? offset : 0
    }
}

// MARK: - Scale Animation

struct ScaleIn<Content: View>: View {
    let duration: Double
    let delay: Double
    let content: Content
    @State private var scale: CGFloat = 0

    init(
        duration: Double = 0.4,
        delay: Double = 0,
        @ViewBuilder content: () -> Content
    ) {
        self.duration = duration
        self.delay = delay
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: duration, dampingFraction: 0.7).delay(delay)) {
                    scale = 1
                }
            }
    }
}

// MARK: - Bounce Animation

struct AnimatedBounce<Content: View>: View {
    let duration: Double
    let content: Content
    @State private var isAnimating = false

    init(
        duration: Double = 1.0,
        @ViewBuilder content: () -> Content
    ) {
        self.duration = duration
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(isAnimating ? 1.05 : 1.0)
            .animation(
                .easeInOut(duration: duration / 2)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Rotation Animation

struct AnimatedRotate<Content: View>: View {
    let duration: Double
    let content: Content
    @State private var isAnimating = false

    init(
        duration: Double = 2.0,
        @ViewBuilder content: () -> Content
    ) {
        self.duration = duration
        self.content = content()
    }

    var body: some View {
        content
            .rotationEffect(.degrees(isAnimating ? 360 : 0))
            .animation(
                .linear(duration: duration)
                    .repeatForever(autoreverses: false),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Pulse Animation

struct AnimatedPulse<Content: View>: View {
    let duration: Double
    let minScale: CGFloat
    let maxScale: CGFloat
    let content: Content
    @State private var isAnimating = false

    init(
        duration: Double = 1.0,
        minScale: CGFloat = 1.0,
        maxScale: CGFloat = 1.1,
        @ViewBuilder content: () -> Content
    ) {
        self.duration = duration
        self.minScale = minScale
        self.maxScale = maxScale
        self.content = content()
    }

    var body: some View {
        content
            .scaleEffect(isAnimating ? maxScale : minScale)
            .opacity(isAnimating ? 0.6 : 1.0)
            .animation(
                .easeInOut(duration: duration)
                    .repeatForever(autoreverses: true),
                value: isAnimating
            )
            .onAppear {
                isAnimating = true
            }
    }
}

// MARK: - Shimmer Animation

struct Shimmer<Content: View>: View {
    let duration: Double
    let content: Content
    @State private var phase: CGFloat = 0

    init(
        duration: Double = 1.5,
        @ViewBuilder content: () -> Content
    ) {
        self.duration = duration
        self.content = content()
    }

    var body: some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        colors: [.clear, .white.opacity(V2Depth.stateHover), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .offset(x: phase - geometry.size.width)
                }
                .onAppear {
                    let width: CGFloat = 300 // Approximate width
                    withAnimation(.linear(duration: duration).repeatForever(autoreverses: false)) {
                        phase = width * 2
                    }
                }
            )
    }
}

// MARK: - Typewriter Animation

struct Typewriter: View {
    let text: String
    let speed: Double
    @State private var currentText = ""
    @State private var index = 0

    init(text: String, speed: Double = 0.05) {
        self.text = text
        self.speed = speed
    }

    var body: some View {
        Text(currentText)
            .font(WernickeTypography.size14.weight(.regular))
            .foregroundStyle(V4Color.textPrimary)
            .onAppear {
                startTyping()
            }
    }

    private func startTyping() {
        if index < text.count {
            let idx = self.index
            DispatchQueue.main.asyncAfter(deadline: .now() + speed) {
                withAnimation(.easeInOut(duration: 0.05)) {
                    currentText += String(text[text.index(text.startIndex, offsetBy: idx)])
                }
                self.index += 1
                startTyping()
            }
        }
    }
}

// MARK: - Transition Wrapper

struct TransitionWrapper<Content: View>: View {
    let transition: AnyTransition
    let show: Bool
    let content: Content

    init(
        transition: AnyTransition,
        show: Bool,
        @ViewBuilder content: () -> Content
    ) {
        self.transition = transition
        self.show = show
        self.content = content()
    }

    var body: some View {
        content
            .transition(transition)
            .animation(.spring(response: 0.35, dampingFraction: 0.8), value: show)
    }
}

// MARK: - Lottie Style Animation

struct LottieStyleAnimation: View {
    let isPlaying: Bool
    let progress: Double
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 4)
                .frame(width: ParietalSpacing.largeFrame, height: ParietalSpacing.largeFrame)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .frame(width: ParietalSpacing.largeFrame, height: ParietalSpacing.largeFrame)
                .rotationEffect(.degrees(-90))
                .animation(isPlaying ? .linear(duration: 1) : nil, value: progress)
        }
    }
}

// MARK: - Slide Edge (public for extension)

enum SlideEdge {
    case top, bottom, leading, trailing
}

// MARK: - View Modifier Extensions

extension View {
    func fadeIn(duration: Double = 0.4, delay: Double = 0) -> some View {
        modifier(FadeInModifier(duration: duration, delay: delay))
    }

    func slideIn(edge: SlideEdge = .trailing, duration: Double = 0.4) -> some View {
        modifier(SlideInModifier(edge: edge, duration: duration))
    }

    func scaleIn(duration: Double = 0.4, delay: Double = 0) -> some View {
        modifier(ScaleInModifier(duration: duration, delay: delay))
    }
}

// MARK: - Fade In Modifier

private struct FadeInModifier: ViewModifier {
    let duration: Double
    let delay: Double
    @State private var isVisible = false

    func body(content: Content) -> some View {
        content
            .opacity(isVisible ? 1 : 0)
            .onAppear {
                withAnimation(.easeIn(duration: duration).delay(delay)) {
                    isVisible = true
                }
            }
    }
}

// MARK: - Slide In Modifier

private struct SlideInModifier: ViewModifier {
    let edge: SlideEdge
    let duration: Double
    @State private var offset: CGFloat

    init(edge: SlideEdge = .trailing, duration: Double = 0.4) {
        self.edge = edge
        self.duration = duration
        switch edge {
        case .top: self._offset = State(initialValue: -50)
        case .bottom: self._offset = State(initialValue: 50)
        case .leading: self._offset = State(initialValue: -50)
        case .trailing: self._offset = State(initialValue: 50)
        }
    }

    func body(content: Content) -> some View {
        let xOffset: CGFloat = (edge == .leading || edge == .trailing) ? offset : 0
        let yOffset: CGFloat = (edge == .top || edge == .bottom) ? offset : 0

        return content
            .offset(x: xOffset, y: yOffset)
            .onAppear {
                withAnimation(.spring(response: duration, dampingFraction: 0.8)) {
                    offset = 0
                }
            }
    }
}

// MARK: - Scale In Modifier

private struct ScaleInModifier: ViewModifier {
    let duration: Double
    let delay: Double
    @State private var scale: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .scaleEffect(scale)
            .onAppear {
                withAnimation(.spring(response: duration, dampingFraction: 0.7).delay(delay)) {
                    scale = 1
                }
            }
    }
}

// MARK: - Preview

struct AnimationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                FadeIn(duration: 0.5) {
                    Text("Fade In")
                        .font(.title)
                }

                AnimatedBounce(duration: 1.0) {
                    Text("Bounce")
                        .font(.title3)
                }

                AnimatedPulse(duration: 1.5, maxScale: 1.2) {
                    Circle()
                        .fill(V4Color.accent)
                        .frame(width: ParietalSpacing.standardFrame, height: ParietalSpacing.itemHeight)
                }
            }
            .padding()
        }
        .padding()
        .background(V4Color.background)
    }
}
