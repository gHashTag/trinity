// Loading State View — Various Loading States
import SwiftUI

// MARK: - Loading State View

struct DetailedLoadingState: View {
    let message: String
    let style: LoadingStyle

    enum LoadingStyle {
        case spinner
        case dots
        case bars
        case pulsing
    }

    init(
        message: String = "Loading...",
        style: LoadingStyle = .spinner
    ) {
        self.message = message
        self.style = style
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            Spacer()

            loadingIndicator

            Text(message)
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textSecondary)

            Spacer()
        }
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        switch style {
        case .spinner:
            ProgressView()
                .scaleEffect(1.2)
                .tint(V4Color.accent)

        case .dots:
            LoadingDots()

        case .bars:
            LoadingBars()

        case .pulsing:
            PulsingCircle()
        }
    }
}

// MARK: - Loading Dots

struct LoadingDots: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(V4Color.accent)
                    .frame(width: 10, height: 10)
                    .scaleEffect(isAnimating ? pulseScale(for: index) : 1)
                    .animation(
                        .easeInOut(duration: 0.6)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.2),
                        value: isAnimating
                    )
            }
        }
        .onAppear {
            isAnimating = true
        }
    }

    private func pulseScale(for index: Int) -> CGFloat {
        index == 1 ? 1.3 : 1.0
    }
}

// MARK: - Loading Bars

struct LoadingBars: View {
    @State private var isAnimating = false

    var body: some View {
        HStack(spacing: ParietalSpacing.xs) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(V4Color.accent)
                    .frame(width: 4, height: 20)
                    .scaleEffect(y: isAnimating ? barScale(for: index) : 0.3)
                    .animation(
                        .easeInOut(duration: 0.8)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.1),
                        value: isAnimating
                    )
            }
        }
        .frame(height: 20)
        .onAppear {
            isAnimating = true
        }
    }

    private func barScale(for index: Int) -> CGFloat {
        let base: CGFloat = 0.3
        let multiplier = 1.0 - CGFloat(index) * 0.2
        return base + multiplier * 0.7
    }
}

// MARK: - Pulsing Circle

struct PulsingCircle: View {
    @State private var isAnimating = false
    @State private var scale: CGFloat = 1.0

    var body: some View {
        ZStack {
            Circle()
                .fill(V4Color.accent.opacity(V2Depth.stateHover))
                .frame(width: 60, height: 60)
                .scaleEffect(scale)
                .opacity(2 - scale)

            Circle()
                .fill(V4Color.accent)
                .frame(width: 40, height: 40)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: false)) {
                scale = 1.5
            }
        }
    }
}

// MARK: - Inline Loading Indicator

struct InlineLoadingIndicator: View {
    let message: String
    @State private var isAnimating = false

    init(message: String = "Loading...") {
        self.message = message
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.sm + 2) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(V4Color.accent)

            Text(message)
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
                .opacity(isAnimating ? 1 : 0)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.2).delay(0.1)) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Shimmer Modifier

struct ShimmerModifier: ViewModifier {
    @State private var phase: CGFloat = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { geometry in
                    LinearGradient(
                        gradient: Gradient(colors: [
                            .clear,
                            .white.opacity(V2Depth.stateHover),
                            .clear
                        ]),
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(width: geometry.size.width)
                    .offset(x: phase * geometry.size.width * 2 - geometry.size.width)
                }
            )
            .onAppear {
                withAnimation(
                    Animation.linear(duration: 1.5)
                        .repeatForever(autoreverses: false)
                ) {
                    phase = 1
                }
            }
    }
}

extension View {
    func shimmer() -> some View {
        modifier(ShimmerModifier())
    }
}

// MARK: - Skeleton Loading

struct SkeletonLoading: View {
    let show: Bool

    var body: some View {
        if show {
            VStack(spacing: ParietalSpacing.md) {
                HStack(spacing: ParietalSpacing.md) {
                    SkeletonAvatar()
                        .frame(width: ParietalSpacing.avatarMedium, height: ParietalSpacing.avatarMedium)

                    VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                        SkeletonTextLine(widthPercent: 0.4, height: 12)
                        SkeletonTextLine(widthPercent: 0.7, height: 10)
                    }
                }

                SkeletonTextBlock()

                SkeletonTextBlock()
            }
            .padding()
        }
    }
}

// MARK: - Skeleton Components

struct SkeletonTextLine: View {
    let widthPercent: CGFloat
    let height: CGFloat

    var body: some View {
        GeometryReader { geometry in
            RoundedRectangle(cornerRadius: 4)
                .fill(V4Color.border)
                .frame(width: geometry.size.width * widthPercent, height: height)
                .shimmer()
        }
        .frame(height: height)
    }
}

struct SkeletonTextBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            SkeletonTextLine(widthPercent: 0.9, height: 10)
            SkeletonTextLine(widthPercent: 0.7, height: 10)
            SkeletonTextLine(widthPercent: 0.5, height: 10)
        }
        .padding(.vertical, ParietalSpacing.xs)
    }
}

struct SkeletonImagePlaceholder: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .fill(V4Color.border)
                .frame(width: size, height: size)
                .shimmer()

            Image(systemName: "photo")
                .font(.system(size: size * 0.3))
                .foregroundStyle(V4Color.textSecondary.opacity(V1Theme.opacityTextTertiary))
        }
    }
}

// MARK: - Upload Progress Indicator

struct UploadProgressIndicator: View {
    let progress: Double
    let filename: String

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            ZStack {
                Circle()
                    .stroke(V4Color.border, lineWidth: 2)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        V4Color.accent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                Text("\(Int(progress * 100))%")
                    .font(WernickeTypography.miniMedium)
                    .foregroundStyle(V4Color.textPrimary)
            }
            .frame(width: ParietalSpacing.avatarMedium - 4, height: ParietalSpacing.avatarMedium - 4)

            VStack(alignment: .leading, spacing: ParietalSpacing.xs) {
                Text(filename)
                    .font(WernickeTypography.captionMedium)
                    .foregroundStyle(V4Color.textPrimary)
                    .lineLimit(1)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.border)
                            .frame(height: ParietalSpacing.xs)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(V4Color.accent)
                            .frame(width: geometry.size.width * progress, height: 4)
                            .shimmer()
                    }
                }
                .frame(height: ParietalSpacing.xs)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                .fill(V4Color.surface)
        )
    }
}

// MARK: - Card Skeleton

struct CardSkeleton: View {
    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            SkeletonImagePlaceholder(size: 60)

            VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
                SkeletonTextLine(widthPercent: 0.5, height: 12)
                SkeletonTextLine(widthPercent: 0.9, height: 10)
                SkeletonTextLine(widthPercent: 0.7, height: 10)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                .fill(V4Color.surface)
        )
    }
}

// MARK: - List Skeleton

struct ListSkeleton: View {
    let itemCount: Int

    init(itemCount: Int = 3) {
        self.itemCount = itemCount
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.sm) {
            ForEach(0..<itemCount, id: \.self) { _ in
                CardSkeleton()
            }
        }
    }
}

// MARK: - Full Screen Loading

struct FullScreenLoading: View {
    let message: String
    let showProgress: Bool
    let progress: Double

    init(
        message: String = "Loading...",
        showProgress: Bool = false,
        progress: Double = 0.5
    ) {
        self.message = message
        self.showProgress = showProgress
        self.progress = progress
    }

    var body: some View {
        ZStack {
            Color.black.opacity(V2Depth.stateHover)
                .ignoresSafeArea()

            VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(message)
                    .font(WernickeTypography.size14)
                    .foregroundStyle(.white)

                if showProgress {
                    Text("\(Int(progress * 100))%")
                        .font(WernickeTypography.h3Bold)
                        .foregroundStyle(.white)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: V1Theme.cornerLarge)
                    .fill(.black.opacity(0.8))
            )
        }
    }
}

// MARK: - Loading Button

struct LoadingButton: View {
    let isLoading: Bool
    let title: String
    let action: () -> Void

    init(
        isLoading: Bool,
        title: String,
        action: @escaping () -> Void
    ) {
        self.isLoading = isLoading
        self.title = title
        self.action = action
    }

    var body: some View {
        Button {
            if !isLoading {
                action()
            }
        } label: {
            HStack(spacing: ParietalSpacing.sm) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Text(title)
                        .font(WernickeTypography.body14Medium)
                }
            }
            .frame(minWidth: 100)
            .padding(.horizontal, ParietalSpacing.md + ParietalSpacing.md)
            .padding(.vertical, ParietalSpacing.sm + 2)
            .background(isLoading ? V4Color.accent.opacity(V1Theme.opacityTextSecondary) : V4Color.accent)
            .cornerRadius(V1Theme.cornerSmall)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Page Loading Indicator

struct PageLoadingIndicator: View {
    let isLoading: Bool

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            ProgressView()
                .scaleEffect(0.6)
                .tint(V4Color.accent)
                .opacity(isLoading ? 1 : 0)

            Text("Loading...")
                .font(.caption)
                .foregroundStyle(V4Color.textSecondary)
                .opacity(isLoading ? 1 : 0)
        }
        .frame(height: 20)
    }
}

// MARK: - Preview

struct DetailedLoadingStates_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            DetailedLoadingState(style: .dots)
                .frame(width: 300, height: 200)
                .padding()
                .background(V4Color.background)

            DetailedLoadingState(message: "Fetching data...", style: .bars)
                .frame(width: 300, height: 200)
                .padding()
                .background(V4Color.background)

            InlineLoadingIndicator(message: "Loading messages...")
                .frame(width: ParietalSpacing.xl * 8)
                .padding()
                .background(V4Color.background)

            LoadingButton(isLoading: true, title: "Load More") {}
                .frame(width: ParietalSpacing.xl * 8)
                .padding()
                .background(V4Color.background)

            // Skeleton previews
            SkeletonLoading(show: true)
                .frame(width: ParietalSpacing.xl * 12)
                .padding()
                .background(V4Color.background)

            ListSkeleton(itemCount: 3)
                .frame(width: 350)
                .padding()
                .background(V4Color.background)

            UploadProgressIndicator(progress: 0.65, filename: "upload.jpg")
                .frame(width: ParietalSpacing.xl * 12)
                .padding()
                .background(V4Color.background)

            HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                CircularProgressIndicator(value: 0.25)
                CircularProgressIndicator(value: 0.5)
                CircularProgressIndicator(value: 0.75)
                CircularProgressIndicator(value: 1.0)
            }
            .padding()
            .background(V4Color.background)
        }
    }
}
