import SwiftUI

// MARK: - Linear Progress Bar

/// A horizontal progress bar with customizable styling and animations.
/// Supports striped patterns, percentage display, and smooth transitions.
struct LinearProgressBar: View {
    /// Progress value from 0.0 to 1.0
    var value: Double = 0.0

    /// Custom color, defaults to V4Color.accent
    var color: Color = V4Color.accent

    /// Height of the progress bar
    var height: CGFloat = 6

    /// Show percentage text above the bar
    var showsPercentage: Bool = false

    /// Animation duration for value changes
    var animationDuration: Double = 0.3

    /// Enable animated striped pattern
    var striped: Bool = false

    @State private var stripeOffset: CGFloat = 0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm - 2) {
            if showsPercentage {
                HStack {
                    Text("\(Int(value * 100))%")
                        .font(WernickeTypography.caption2MediumMono)
                        .foregroundStyle(V4Color.textSecondary)
                    Spacer()
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(V4Color.border)

                    // Progress fill
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(progressFill)
                        .frame(width: geometry.size.width * clampedValue)
                        .overlay(
                            Group {
                                if striped {
                                    stripeOverlay(geometry: geometry)
                                        .clipShape(RoundedRectangle(cornerRadius: height / 2))
                                }
                            }
                        )
                }
            }
            .frame(height: height)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Progress")
            .accessibilityValue("\(Int(value * 100)) percent")
        }
        .task(id: striped && value > 0 && value < 1) {
            guard striped && !reduceMotion else { return }
            withAnimation(.linear(duration: 1.5).repeatForever(autoreverses: false)) {
                stripeOffset = 200
            }
        }
    }

    private var clampedValue: Double {
        max(0, min(1, value))
    }

    private var progressFill: some ShapeStyle {
        LinearGradient(
            colors: [color, color.opacity(0.85)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    private func stripeOverlay(geometry: GeometryProxy) -> some View {
        GeometryReader { geo in
            ZStack {
                ForEach(0..<20) { i in
                    Rectangle()
                        .fill(color.opacity(V2Depth.stateHover))
                        .frame(width: ParietalSpacing.tinyIndicator, height: height * 2)
                        .offset(x: CGFloat(i) * 20 - stripeOffset)
                }
            }
        }
    }
}

// MARK: - Circular Progress

/// A ring/circle progress indicator with customizable styling.
/// Perfect for showing progress in a compact circular format.
struct CircularProgressIndicator: View {
    /// Progress value from 0.0 to 1.0
    var value: Double = 0.0

    /// Custom color, defaults to V4Color.accent
    var color: Color = V4Color.accent

    /// Size of the progress ring
    var size: CGFloat = 44

    /// Line width of the ring stroke
    var lineWidth: CGFloat = 4

    /// Show percentage text in the center
    var showsPercentage: Bool = false

    /// Animation duration for value changes
    var animationDuration: Double = 0.3

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(color.opacity(V2Depth.bgSidebarHover), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: clampedValue)
                .stroke(
                    AngularGradient(
                        gradient: .init(colors: [color.opacity(V1Theme.opacityTextSecondary), color, color]),
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(reduceMotion ? .none : .easeOut(duration: animationDuration), value: value)

            // Center content
            if showsPercentage {
                Text("\(Int(value * 100))%")
                    .font(.system(size: size * 0.22, weight: .semibold, design: .rounded))
                    .foregroundStyle(V4Color.textPrimary)
                    .contentTransition(.numericText(value: Double(Int(value * 100))))
            }
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Circular progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }

    private var clampedValue: Double {
        max(0, min(1, value))
    }
}

// MARK: - Segmented Progress

/// Step-by-step progress indicator with dots.
/// Shows current step out of total steps with animated transitions.
struct SegmentedProgress: View {
    /// Current step index (0-based)
    var currentStep: Int = 0

    /// Total number of steps
    var totalSteps: Int = 5

    /// Custom color for completed steps
    var color: Color = V4Color.accent

    /// Size of each step dot
    var dotSize: CGFloat = 8

    /// Show step labels (e.g., "Step 2 of 5")
    var showsLabel: Bool = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: ParietalSpacing.sm) {
            HStack(spacing: ParietalSpacing.md) {
                ForEach(0..<totalSteps, id: \.self) { index in
                    stepView(for: index)
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(stepAccessibilityLabel(for: index))
                        .accessibilityValue(stepAccessibilityValue(for: index))
                }
            }

            if showsLabel {
                Text("Step \(currentStep + 1) of \(totalSteps)")
                    .font(WernickeTypography.miniMedium)
                    .foregroundStyle(V4Color.textSecondary)
                    .contentTransition(.numericText())
            }
        }
    }

    @ViewBuilder
    private func stepView(for index: Int) -> some View {
        if index < currentStep {
            // Completed step
            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
                .overlay(
                    Image(systemName: "checkmark")
                        .font(.system(size: dotSize * 0.6, weight: .bold))
                        .foregroundStyle(.white)
                )
        } else if index == currentStep {
            // Current step
            Circle()
                .fill(color)
                .frame(width: dotSize * 1.3, height: dotSize * 1.3)
                .overlay(
                    Circle()
                        .stroke(color.opacity(V2Depth.stateHover), lineWidth: 4)
                )
                .shadow(color: color.opacity(V1Theme.opacityTextTertiary), radius: 4)
        } else {
            // Future step
            Circle()
                .fill(V4Color.border)
                .frame(width: dotSize, height: dotSize)
        }
    }

    private func stepAccessibilityLabel(for index: Int) -> String {
        if index < currentStep { return "Completed step" }
        if index == currentStep { return "Current step" }
        return "Upcoming step"
    }

    private func stepAccessibilityValue(for index: Int) -> Text {
        Text("\(index + 1) of \(totalSteps)")
    }
}

// MARK: - Determinate Progress

/// A determinate progress indicator showing exact value from 0-100%.
/// Provides precise feedback with large percentage display.
struct DeterminateProgress: View {
    /// Progress value from 0.0 to 1.0
    var value: Double = 0.0

    /// Custom color, defaults to V4Color.accent
    var color: Color = V4Color.accent

    /// Display label above the progress
    var label: String?

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.sm) {
            if let label = label {
                HStack {
                    Text(label)
                        .font(WernickeTypography.captionMedium)
                        .foregroundStyle(V4Color.textSecondary)
                    Spacer()
                    Text("\(Int(value * 100))%")
                        .font(WernickeTypography.captionSemiboldMono)
                        .foregroundStyle(color)
                }
            }

            ZStack(alignment: .leading) {
                // Track
                RoundedRectangle(cornerRadius: 10)
                    .fill(V4Color.border)
                    .frame(height: 12)

                // Fill with glow effect
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [color, color.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(0, geo.size.width * max(0, min(1, value))), height: ParietalSpacing.badgeHeight)
                        .shadow(color: color.opacity(V2Depth.stateDisabled), radius: 3)
                        .animation(.easeOut(duration: 0.3), value: value)
                }
            }
            .frame(height: 12)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(label ?? "Progress")
        .accessibilityValue("\(Int(value * 100)) percent")
    }
}

// MARK: - Indeterminate Progress

/// An animated loading state with no specific progress value.
/// Uses continuous animation to indicate ongoing activity.
struct IndeterminateProgressIndicator: View {
    /// Custom color, defaults to V4Color.accent
    var color: Color = V4Color.accent

    /// Display a loading message
    var message: String?

    /// Size of the indicator
    var size: CGFloat = 24

    @State private var rotation: Double = 0
    @State private var pulseScale: CGFloat = 1.0

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: ParietalSpacing.md) {
            ZStack {
                // Outer ring
                Circle()
                    .stroke(color.opacity(V2Depth.bgSidebarHover), lineWidth: 2)
                    .frame(width: size, height: size)

                // Rotating segment
                Circle()
                    .trim(from: 0, to: 0.7)
                    .stroke(
                        AngularGradient(
                            gradient: .init(colors: [color.opacity(V2Depth.stateHover), color]),
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )
                    .frame(width: size, height: size)
                    .rotationEffect(.degrees(rotation))
            }
            .scaleEffect(pulseScale)

            if let message = message {
                Text(message)
                    .font(WernickeTypography.size13)
                    .foregroundStyle(V4Color.textSecondary)
            }
        }
        .task {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                rotation = 360
            }
            withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                pulseScale = 1.1
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Loading")
        .accessibilityHint(message ?? "Please wait")
    }
}

// MARK: - Progress with Label

/// Progress indicator with integrated text description.
/// Combines visual progress with contextual information.
struct ProgressWithLabel: View {
    /// Progress value from 0.0 to 1.0 (nil for indeterminate)
    var value: Double?

    /// Primary label text
    var label: String

    /// Secondary description text
    var description: String?

    /// Custom color, defaults to V4Color.accent
    var color: Color = V4Color.accent

    /// Style variant
    var style: ProgressStyle = .linear

    @State private var animateGlow = false

    enum ProgressStyle {
        case linear
        case circular
        case compact
    }

    var body: some View {
        HStack(spacing: ParietalSpacing.md + 2) {
            // Progress indicator
            Group {
                if let value = value {
                    switch style {
                    case .linear:
                        LinearProgressBar(value: value, color: color, height: ParietalSpacing.microHeight)
                    case .circular:
                        CircularProgressIndicator(value: value, color: color, size: 32)
                    case .compact:
                        compactProgress(value)
                    }
                } else {
                    IndeterminateProgressIndicator(color: color, size: 28)
                }
            }
            .frame(width: style == .circular ? 32 : (style == .compact ? 60 : 100))

            // Labels
            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(WernickeTypography.smallMedium)
                    .foregroundStyle(V4Color.textPrimary)

                if let description = description {
                    Text(description)
                        .font(WernickeTypography.size11)
                        .foregroundStyle(V4Color.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Percentage badge for determinate progress
            if let value = value, style != .compact {
                Text("\(Int(value * 100))%")
                    .font(WernickeTypography.caption2Semibold)
                    .foregroundStyle(color)
                    .padding(.horizontal, ParietalSpacing.sm)
                    .padding(.vertical, ParietalSpacing.xs)
                    .background(color.opacity(V2Depth.bgSidebarHover))
                    .clipShape(SwiftUI.Capsule())
            }
        }
        .padding(.horizontal, ParietalSpacing.md + 2)
        .padding(.vertical, ParietalSpacing.sm + 2)
        .background(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .fill(V4Color.surface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(value != nil && value! > 0 ? color.opacity(V2Depth.stateHover) : Color.clear, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label). \(description ?? "")")
        .accessibilityValue(value.map { "\(Int($0 * 100)) percent complete" } ?? "In progress")
    }

    @ViewBuilder
    private func compactProgress(_ value: Double) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(V4Color.border)

                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: geo.size.width * max(0, min(1, value)))
            }
        }
        .frame(height: ParietalSpacing.xs)
    }
}

// MARK: - Convenience View Extensions

extension View {
    /// Returns a linear progress bar with the specified value.
    /// - Parameter value: Progress value from 0.0 to 1.0
    func progressBarOverlay(_ value: Double, color: Color = V4Color.accent) -> some View {
        self.overlay(
            LinearProgressBar(value: value, color: color)
                .offset(y: 2)
        )
    }

    /// Returns a circular progress ring with the specified value.
    /// - Parameter value: Progress value from 0.0 to 1.0
    func progressRingOverlay(_ value: Double, color: Color = V4Color.accent) -> some View {
        self.overlay(
            CircularProgressIndicator(value: value, color: color)
        )
    }

    /// Returns a segmented step progress indicator.
    /// - Parameters:
    ///   - currentStep: Current step index (0-based)
    ///   - totalSteps: Total number of steps
    func stepProgressOverlay(currentStep: Int, totalSteps: Int) -> some View {
        self.overlay(
            SegmentedProgress(currentStep: currentStep, totalSteps: totalSteps)
        )
    }
}

// MARK: - Previews

struct ProgressIndicators_Previews: PreviewProvider {
    static var previews: some View {
        ScrollView {
            VStack(spacing: 32) {
                // Linear Progress Bar
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("Linear Progress Bar")
                        .font(.headline)
                        .foregroundStyle(V4Color.textPrimary)

                    LinearProgressBar(value: 0.65)
                    LinearProgressBar(value: 0.3, color: .blue, showsPercentage: true)
                    LinearProgressBar(value: 0.85, color: .blue, striped: true)
                    LinearProgressBar(value: 0.45, color: .purple, height: ParietalSpacing.captionHeight)
                }
                .padding()
                .background(V4Color.surface)
                .cornerRadius(V1Theme.cornerLarge)

                // Circular Progress
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("Circular Progress")
                        .font(.headline)
                        .foregroundStyle(V4Color.textPrimary)

                    HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                        CircularProgressIndicator(value: 0.3)
                        CircularProgressIndicator(value: 0.65, showsPercentage: true)
                        CircularProgressIndicator(value: 0.85, color: .purple, size: 60, lineWidth: 6)
                        CircularProgressIndicator(value: 1.0, color: .green, showsPercentage: true)
                    }
                }
                .padding()
                .background(V4Color.surface)
                .cornerRadius(V1Theme.cornerLarge)

                // Segmented Progress
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("Segmented Progress")
                        .font(.headline)
                        .foregroundStyle(V4Color.textPrimary)

                    SegmentedProgress(currentStep: 2, totalSteps: 5)
                    SegmentedProgress(currentStep: 1, totalSteps: 5, color: .blue, showsLabel: true)
                    SegmentedProgress(currentStep: 4, totalSteps: 5, color: .purple, dotSize: 12)
                }
                .padding()
                .background(V4Color.surface)
                .cornerRadius(V1Theme.cornerLarge)

                // Determinate Progress
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("Determinate Progress")
                        .font(.headline)
                        .foregroundStyle(V4Color.textPrimary)

                    DeterminateProgress(value: 0.72, label: "Uploading files...")
                    DeterminateProgress(value: 0.25, color: .orange, label: "Processing")
                    DeterminateProgress(value: 0.95, color: .green, label: "Almost done")
                }
                .padding()
                .background(V4Color.surface)
                .cornerRadius(V1Theme.cornerLarge)

                // Indeterminate Progress
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("Indeterminate Progress")
                        .font(.headline)
                        .foregroundStyle(V4Color.textPrimary)

                    HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                        IndeterminateProgressIndicator()
                        IndeterminateProgressIndicator(message: "Loading...")
                        IndeterminateProgressIndicator(color: .blue, size: 32)
                    }
                }
                .padding()
                .background(V4Color.surface)
                .cornerRadius(V1Theme.cornerLarge)

                // Progress with Label
                VStack(alignment: .leading, spacing: ParietalSpacing.md) {
                    Text("Progress with Label")
                        .font(.headline)
                        .foregroundStyle(V4Color.textPrimary)

                    ProgressWithLabel(
                        value: 0.65,
                        label: "Downloading",
                        description: "42 MB of 65 MB",
                        style: .linear
                    )

                    ProgressWithLabel(
                        value: 0.3,
                        label: "Syncing",
                        description: "Please wait...",
                        color: .blue,
                        style: .circular
                    )

                    ProgressWithLabel(
                        value: 0.85,
                        label: "Encoding",
                        description: "Finalizing",
                        color: .purple,
                        style: .compact
                    )

                    ProgressWithLabel(
                        value: nil,
                        label: "Connecting",
                        description: "Establishing secure connection...",
                        style: .linear
                    )
                }
                .padding()
                .background(V4Color.surface)
                .cornerRadius(V1Theme.cornerLarge)
            }
            .padding()
        }
        .background(V4Color.background)
        .frame(height: 900)
    }
}
