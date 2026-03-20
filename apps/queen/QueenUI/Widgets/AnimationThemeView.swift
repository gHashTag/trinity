import SwiftUI

// MARK: - Animation Theme Manager

struct AnimationThemeManager: View {
    @Binding var selectedTheme: AnimationTheme
    let onThemeChanged: (AnimationTheme) -> Void

    private let themes: [AnimationTheme] = [
        .default, .minimal, .playful, .elegant, .technical
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: ParietalSpacing.md) {
            Text("Animation Style")
                .font(.caption2)
                .foregroundStyle(V4Color.textSecondary)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: ParietalSpacing.sm + 2) {
                ForEach(themes, id: \.self) { theme in
                    themeCard(theme)
                }
            }
        }
        .padding()
    }

    private func themeCard(_ theme: AnimationTheme) -> some View {
        Button {
            selectedTheme = theme
            onThemeChanged(theme)
        } label: {
            VStack(spacing: ParietalSpacing.sm) {
                themePreview(theme)

                Text(theme.name)
                    .font(.caption)
                    .foregroundStyle(selectedTheme == theme ? V4Color.accent : V4Color.textPrimary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .fill(selectedTheme == theme ? V4Color.accent.opacity(V2Depth.bgSidebarHover) : V4Color.surface)
            )
            .overlay(
                RoundedRectangle(cornerRadius: V1Theme.cornerSmall)
                    .stroke(selectedTheme == theme ? V4Color.accent : V4Color.border, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func themePreview(_ theme: AnimationTheme) -> some View {
        HStack(spacing: ParietalSpacing.xs) {
            ForEach(0..<3) { index in
                Circle()
                    .fill(theme.previewColor)
                    .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)
                    .scaleEffect(theme == .playful ? 1.0 : Double(index) * 0.3 + 0.7)
            }
        }
        .padding(.vertical, ParietalSpacing.sm)
    }
}

// MARK: - Animation Theme

enum AnimationTheme: String, CaseIterable {
    case `default`
    case minimal
    case playful
    case elegant
    case technical

    var name: String {
        switch self {
        case .default: return "Default"
        case .minimal: return "Minimal"
        case .playful: return "Playful"
        case .elegant: return "Elegant"
        case .technical: return "Technical"
        }
    }

    var previewColor: Color {
        switch self {
        case .default: return V4Color.accent
        case .minimal: return .gray
        case .playful: return .purple
        case .elegant: return .blue
        case .technical: return .green
        }
    }

    var spring: Animation {
        switch self {
        case .default: return .spring(response: 0.4, dampingFraction: 0.8)
        case .minimal: return .linear(duration: 0.2)
        case .playful: return .spring(response: 0.6, dampingFraction: 0.5)
        case .elegant: return .easeInOut(duration: 0.4)
        case .technical: return .timingCurve(0.4, 0, 0.2, 1)
        }
    }

    var fadeIn: Animation {
        switch self {
        case .default: return .easeOut(duration: 0.2)
        case .minimal: return .linear(duration: 0.1)
        case .playful: return .spring(response: 0.5, dampingFraction: 0.7)
        case .elegant: return .easeIn(duration: 0.3)
        case .technical: return .timingCurve(0.25, 0.1, 0.25, 1)
        }
    }

    var scale: Animation {
        switch self {
        case .default: return .spring(response: 0.3, dampingFraction: 0.7)
        case .minimal: return .linear
        case .playful: return .bouncy
        case .elegant: return .easeOut(duration: 0.3)
        case .technical: return .timingCurve(0.34, 1.56, 0.64, 1)
        }
    }

    var bouncy: Animation {
        .spring(response: 0.45, dampingFraction: 0.5)
    }
}

// MARK: - Animation Preview

struct AnimationPreview: View {
    let theme: AnimationTheme
    @State private var isAnimating = false

    var body: some View {
        VStack(spacing: ParietalSpacing.lg) {
            // Scale animation
            Button {
                withAnimation(theme.scale) {
                    isAnimating.toggle()
                }
            } label: {
                Text("Scale")
                    .font(.caption)
                    .padding()
                    .background(V4Color.accent)
                    .foregroundStyle(.white)
                    .cornerRadius(V1Theme.cornerBase)
            }
            .scaleEffect(isAnimating ? 1.2 : 1.0)

            // Fade animation
            HStack(spacing: ParietalSpacing.sm + 2) {
                Text("Fade")
                    .font(.caption)
                    .opacity(isAnimating ? 1 : 0.3)
            }
        }
        .onAppear {
            withAnimation(theme.spring) {
                isAnimating = true
            }
        }
    }
}

// MARK: - Micro Interaction Library

struct MicroInteractionLibrary {
    // Button press animation
    static func buttonPress(_ state: Bool) -> Animation {
        state ? .spring(response: 0.3, dampingFraction: 0.6) : .spring(response: 0.4, dampingFraction: 0.8)
    }

    // Hover animation
    static func hover(_ theme: AnimationTheme) -> Animation {
        theme.spring
    }

    // Appearance animation
    static func appearance(_ theme: AnimationTheme) -> Animation {
        .spring(response: 0.4, dampingFraction: 0.8)
    }

    // Disappearance animation
    static func disappearance(_ theme: AnimationTheme) -> Animation {
        .easeOut(duration: 0.2)
    }
}

// MARK: - Interactive Button with Animation

struct AnimatedButton: View {
    let title: String
    let icon: String?
    let action: () -> Void
    var theme: AnimationTheme = .default

    @State private var isPressed = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: ParietalSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(title)
            }
            .font(WernickeTypography.body14Medium)
            .foregroundStyle(.white)
            .padding(.horizontal, ParietalSpacing.lg)
            .padding(.vertical, ParietalSpacing.sm + 2)
            .background(
                SwiftUI.Capsule()
                    .fill(isPressed ? V4Color.accent.opacity(0.8) : V4Color.accent)
            )
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.95 : 1.0)
        .onTapGesture {
            withAnimation(MicroInteractionLibrary.buttonPress(true)) {
                isPressed = true
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(MicroInteractionLibrary.buttonPress(false)) {
                    isPressed = false
                }
            }
        }
    }
}

// MARK: - Animated Toggle

struct AnimatedToggle: View {
    @Binding var isOn: Bool
    let theme: AnimationTheme

    var body: some View {
        HStack(spacing: ParietalSpacing.sm) {
            Text(isOn ? "On" : "Off")
                .font(.caption)
                .foregroundStyle(isOn ? V4Color.textPrimary : V4Color.textSecondary)
                .frame(width: ParietalSpacing.touchFrame)

            ZStack(alignment: isOn ? .trailing : .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(isOn ? V4Color.accent : V4Color.border)
                    .frame(width: ParietalSpacing.buttonFrame, height: ParietalSpacing.chipHeight)

                Circle()
                    .fill(.white)
                    .frame(width: ParietalSpacing.icon + 4, height: ParietalSpacing.icon + 4)
                    .shadow(color: .black.opacity(0.2), radius: 2)
            }
            .onTapGesture {
                withAnimation(theme.spring) {
                    isOn.toggle()
                }
            }
        }
    }
}

// MARK: - Loading Spinner

struct LoadingSpinner: View {
    @State private var isSpinning = false
    let size: CGFloat
    let color: Color

    init(size: CGFloat = 20, color: Color = V4Color.accent) {
        self.size = size
        self.color = color
    }

    var body: some View {
        Circle()
            .trim(from: 0.2, to: 1)
            .stroke(
                AngularGradient(
                    gradient: .init(colors: [color.opacity(V2Depth.stateHover), color, color.opacity(V2Depth.stateHover)]),
                    center: .center
                ),
                lineWidth: 3
            )
            .frame(width: size, height: size)
            .rotationEffect(.degrees(isSpinning ? 360 : 0))
            .onAppear {
                withAnimation(.linear(duration: 1).repeatForever(autoreverses: false)) {
                    isSpinning = true
                }
            }
    }
}

// MARK: - Progress Ring

struct ProgressRing: View {
    let progress: Double
    let size: CGFloat
    let color: Color

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
                .frame(width: size, height: size)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, lineWidth: 3)
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.3), value: progress)
        }
    }
}

// MARK: - Morphing Shape

struct MorphingShape: View {
    @State private var isExpanded = false

    var body: some View {
        RoundedRectangle(cornerRadius: isExpanded ? 20 : 10)
            .fill(V4Color.accent)
            .frame(width: ParietalSpacing.standardFrame, height: ParietalSpacing.itemHeight)
            .animation(.spring(response: 0.5, dampingFraction: 0.6), value: isExpanded)
            .onTapGesture {
                isExpanded.toggle()
            }
    }
}

// MARK: - Preview

struct AnimationThemeView_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            AnimationThemeManager(
                selectedTheme: .constant(.default),
                onThemeChanged: { _ in }
            )
            .frame(width: ParietalSpacing.xl * 12)

            HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                AnimatedButton(title: "Click Me", icon: "hand.tap") {}
                AnimatedToggle(isOn: .constant(true), theme: .default)
            }

            HStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                LoadingSpinner(size: 24)
                ProgressRing(progress: 0.75, size: 40, color: V4Color.accent)
                MorphingShape()
            }
        }
        .padding()
        .background(V4Color.background)
    }
}
