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
        VStack(spacing: 20) {
            Spacer()

            loadingIndicator

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textMuted)

            Spacer()
        }
    }

    @ViewBuilder
    private var loadingIndicator: some View {
        switch style {
        case .spinner:
            ProgressView()
                .scaleEffect(1.2)
                .tint(TrinityTheme.accent)

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
        HStack(spacing: 8) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(TrinityTheme.accent)
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
        HStack(spacing: 4) {
            ForEach(0..<4) { index in
                RoundedRectangle(cornerRadius: 2)
                    .fill(TrinityTheme.accent)
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
                .fill(TrinityTheme.accent.opacity(0.3))
                .frame(width: 60, height: 60)
                .scaleEffect(scale)
                .opacity(2 - scale)

            Circle()
                .fill(TrinityTheme.accent)
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
        HStack(spacing: 10) {
            ProgressView()
                .scaleEffect(0.8)
                .tint(TrinityTheme.accent)

            Text(message)
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
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
                            .white.opacity(0.3),
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
            VStack(spacing: 12) {
                HStack(spacing: 12) {
                    SkeletonAvatar()
                        .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 8) {
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
                .fill(TrinityTheme.bgCardBorder)
                .frame(width: geometry.size.width * widthPercent, height: height)
                .shimmer()
        }
        .frame(height: height)
    }
}

struct SkeletonTextBlock: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SkeletonTextLine(widthPercent: 0.9, height: 10)
            SkeletonTextLine(widthPercent: 0.7, height: 10)
            SkeletonTextLine(widthPercent: 0.5, height: 10)
        }
        .padding(.vertical, 4)
    }
}

struct SkeletonImagePlaceholder: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(TrinityTheme.bgCardBorder)
                .frame(width: size, height: size)
                .shimmer()

            Image(systemName: "photo")
                .font(.system(size: size * 0.3))
                .foregroundStyle(TrinityTheme.textMuted.opacity(0.4))
        }
    }
}

// MARK: - Upload Progress Indicator

struct UploadProgressIndicator: View {
    let progress: Double
    let filename: String

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(TrinityTheme.bgCardBorder, lineWidth: 2)

                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        TrinityTheme.accent,
                        style: StrokeStyle(lineWidth: 2, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.3), value: progress)

                Text("\(Int(progress * 100))%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)
            }
            .frame(width: 44, height: 44)

            VStack(alignment: .leading, spacing: 4) {
                Text(filename)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(TrinityTheme.textPrimary)
                    .lineLimit(1)

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(TrinityTheme.bgCardBorder)
                            .frame(height: 4)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(TrinityTheme.accent)
                            .frame(width: geometry.size.width * progress, height: 4)
                            .shimmer()
                    }
                }
                .frame(height: 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(TrinityTheme.bgCard)
        )
    }
}

// MARK: - Card Skeleton

struct CardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            SkeletonImagePlaceholder(size: 60)

            VStack(alignment: .leading, spacing: 8) {
                SkeletonTextLine(widthPercent: 0.5, height: 12)
                SkeletonTextLine(widthPercent: 0.9, height: 10)
                SkeletonTextLine(widthPercent: 0.7, height: 10)
            }

            Spacer()
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(TrinityTheme.bgCard)
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
        VStack(spacing: 8) {
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
            Color.black.opacity(0.3)
                .ignoresSafeArea()

            VStack(spacing: 20) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(.white)

                if showProgress {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
            .padding(32)
            .background(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerLarge)
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
            HStack(spacing: 8) {
                if isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                        .tint(.white)
                } else {
                    Text(title)
                        .font(.system(size: 14, weight: .medium))
                }
            }
            .frame(minWidth: 100)
            .padding(.horizontal, 20)
            .padding(.vertical, 10)
            .background(isLoading ? TrinityTheme.accent.opacity(0.6) : TrinityTheme.accent)
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
        .disabled(isLoading)
    }
}

// MARK: - Page Loading Indicator

struct PageLoadingIndicator: View {
    let isLoading: Bool

    var body: some View {
        HStack(spacing: 12) {
            ProgressView()
                .scaleEffect(0.6)
                .tint(TrinityTheme.accent)
                .opacity(isLoading ? 1 : 0)

            Text("Loading...")
                .font(.caption)
                .foregroundStyle(TrinityTheme.textMuted)
                .opacity(isLoading ? 1 : 0)
        }
        .frame(height: 20)
    }
}

// MARK: - Preview

struct DetailedLoadingStates_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DetailedLoadingState(style: .dots)
                .frame(width: 300, height: 200)
                .padding()
                .background(TrinityTheme.bgWindow)

            DetailedLoadingState(message: "Fetching data...", style: .bars)
                .frame(width: 300, height: 200)
                .padding()
                .background(TrinityTheme.bgWindow)

            InlineLoadingIndicator(message: "Loading messages...")
                .frame(width: 200)
                .padding()
                .background(TrinityTheme.bgWindow)

            LoadingButton(isLoading: true, title: "Load More") {}
                .frame(width: 200)
                .padding()
                .background(TrinityTheme.bgWindow)

            // Skeleton previews
            SkeletonLoading(show: true)
                .frame(width: 300)
                .padding()
                .background(TrinityTheme.bgWindow)

            ListSkeleton(itemCount: 3)
                .frame(width: 350)
                .padding()
                .background(TrinityTheme.bgWindow)

            UploadProgressIndicator(progress: 0.65, filename: "upload.jpg")
                .frame(width: 300)
                .padding()
                .background(TrinityTheme.bgWindow)

            HStack(spacing: 20) {
                CircularProgressIndicator(progress: 0.25)
                CircularProgressIndicator(progress: 0.5)
                CircularProgressIndicator(progress: 0.75)
                CircularProgressIndicator(progress: 1.0)
            }
            .padding()
            .background(TrinityTheme.bgWindow)
        }
    }
}
