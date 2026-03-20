// Success State View — Success Confirmation
import SwiftUI

// MARK: - Success State View

struct DetailedSuccessState: View {
    let icon: String?
    let title: String
    let message: String
    let actionTitle: String?
    let action: () -> Void
    let autoDismiss: Bool
    let onDismiss: () -> Void

    init(
        icon: String? = nil,
        title: String,
        message: String,
        actionTitle: String? = nil,
        action: @escaping () -> Void = {},
        autoDismiss: Bool = false,
        onDismiss: @escaping () -> Void = {}
    ) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
        self.autoDismiss = autoDismiss
        self.onDismiss = onDismiss
    }

    var body: some View {
        VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
            Spacer()

            // Success icon
            successIcon

            // Title and message
            VStack(spacing: ParietalSpacing.sm) {
                Text(title)
                    .font(WernickeTypography.h4Semibold)
                    .foregroundStyle(V4Color.textPrimary)

                Text(message)
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textSecondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            // Action button
            if let actionTitle = actionTitle {
                Button {
                    action()
                } label: {
                    Text(actionTitle)
                        .font(WernickeTypography.body14Medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, ParietalSpacing.md + ParietalSpacing.md)
                        .padding(.vertical, ParietalSpacing.sm + 2)
                        .background(V4Color.success)
                        .cornerRadius(V1Theme.cornerSmall)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .onAppear {
            if autoDismiss {
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    onDismiss()
                }
            }
        }
    }

    private var successIcon: some View {
        ZStack {
            Circle()
                .fill(V4Color.success.opacity(V2Depth.bgSidebarHover))
                .frame(width: ParietalSpacing.badgeFrame, height: ParietalSpacing.badgeFrame)

            Image(systemName: icon ?? "checkmark.circle.fill")
                .font(WernickeTypography.size32)
                .foregroundStyle(V4Color.success)
        }
    }
}

// MARK: - Checkmark Animation

struct CheckmarkAnimation: View {
    @State private var showCheckmark = false
    @State private var scale: CGFloat = 0
    @State private var rotate = false

    var body: some View {
        ZStack {
            Circle()
                .fill(V4Color.success)
                .frame(width: ParietalSpacing.largeFrame, height: ParietalSpacing.largeFrame)

            Image(systemName: "checkmark")
                .font(WernickeTypography.h3Bold)
                .foregroundStyle(.white)
                .scaleEffect(scale)
                .rotationEffect(.degrees(rotate ? 45 : 0))
                .opacity(showCheckmark ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.6)) {
                showCheckmark = true
                scale = 1
                rotate = true
            }
        }
    }
}

// MARK: - Success Banner

struct SuccessBanner: View {
    let message: String
    let onDismiss: () -> Void

    @State private var isVisible = false

    var body: some View {
        HStack(spacing: ParietalSpacing.sm + 2) {
            Image(systemName: "checkmark.circle.fill")
                .font(WernickeTypography.size16)
                .foregroundStyle(V4Color.success)

            Text(message)
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textPrimary)

            Spacer()

            Button {
                withAnimation {
                    isVisible = false
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onDismiss()
                }
            } label: {
                Image(systemName: "xmark")
                    .font(WernickeTypography.size12)
                    .foregroundStyle(V4Color.textSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm + 2)
        .background(
            V4Color.success.opacity(V2Depth.bgSubtle)
        )
        .overlay(
            Rectangle()
                .fill(V4Color.success)
                .frame(height: 2),
            alignment: .top
        )
        .offset(y: isVisible ? 0 : -60)
        .animation(MTMotion.modal, value: isVisible)
        .onAppear {
            withAnimation {
                isVisible = true
            }
        }
    }
}

// MARK: - Confetti Success

struct ConfettiSuccessView: View {
    let title: String
    let message: String
    let onDismiss: () -> Void

    @State private var showConfetti = false
    @State private var confettiPieces: [ConfettiPiece] = []

    var body: some View {
        ZStack {
            // Background
            Color.black.opacity(V2Depth.stateHover)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Content
            VStack(spacing: ParietalSpacing.md + ParietalSpacing.md) {
                CheckmarkAnimation()

                Text(title)
                    .font(WernickeTypography.size20.weight(.bold))
                    .foregroundStyle(V4Color.textPrimary)

                Text(message)
                    .font(WernickeTypography.size14)
                    .foregroundStyle(V4Color.textSecondary)
                    .multilineTextAlignment(.center)

                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(WernickeTypography.body14Medium)
                        .foregroundStyle(.white)
                        .padding(.horizontal, ParietalSpacing.xl)
                        .padding(.vertical, ParietalSpacing.sm + 2)
                        .background(V4Color.accent)
                        .cornerRadius(V1Theme.cornerSmall)
                }
                .buttonStyle(.plain)
            }
            .padding(ParietalSpacing.xxl)
            .background(V4Color.surface)
            .cornerRadius(V1Theme.cornerLarge)
            .shadow(color: .black.opacity(0.2), radius: 20)
            .overlay(
                // Confetti
                ZStack {
                    ForEach(confettiPieces) { piece in
                        ConfettiPieceView(piece: piece)
                    }
                }
                .allowsHitTesting(false)
            )
        }
        .onAppear {
            showConfetti = true
            generateConfetti()
        }
    }

    private func generateConfetti() {
        confettiPieces = (0..<50).map { _ in
            ConfettiPiece(
                color: [.red, .blue, .green, .yellow, .purple, .orange].randomElement() ?? .blue,
                x: CGFloat.random(in: -150...150),
                y: CGFloat.random(in: -100...100),
                rotation: CGFloat.random(in: 0...360)
            )
        }
    }
}

struct ConfettiPiece: Identifiable {
    let id = UUID()
    let color: Color
    let x: CGFloat
    let y: CGFloat
    let rotation: CGFloat
}

struct ConfettiPieceView: View {
    let piece: ConfettiPiece
    @State private var offset: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        Rectangle()
            .fill(piece.color)
            .frame(width: ParietalSpacing.xs, height: ParietalSpacing.xs)
            .rotationEffect(.degrees(piece.rotation))
            .offset(x: piece.x, y: piece.y + offset)
            .opacity(opacity)
            .onAppear {
                withAnimation(.easeOut(duration: 1.5)) {
                    offset = -300
                    opacity = 0
                }
            }
    }
}

// MARK: - Progress Success

struct ProgressSuccessView: View {
    let steps: [String]
    let currentStep: Int

    var body: some View {
        VStack(spacing: ParietalSpacing.xl) {
            // Success icon
            CheckmarkAnimation()

            Text("All Done!")
                .font(WernickeTypography.size20.weight(.bold))
                .foregroundStyle(V4Color.textPrimary)

            Text("You've completed all steps successfully.")
                .font(WernickeTypography.size14)
                .foregroundStyle(V4Color.textSecondary)

            // Progress steps
            VStack(spacing: ParietalSpacing.md) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: ParietalSpacing.md) {
                        Image(systemName: index < steps.count ? "checkmark.circle.fill" : "circle")
                            .font(WernickeTypography.size16)
                            .foregroundStyle(V4Color.success)

                        Text(step)
                            .font(WernickeTypography.size13)
                            .foregroundStyle(V4Color.textPrimary)
                    }
                }
            }
        }
        .padding(ParietalSpacing.xl)
    }
}

// MARK: - Compact Success

struct CompactSuccess: View {
    let message: String

    var body: some View {
        HStack(spacing: ParietalSpacing.sm + 2) {
            Image(systemName: "checkmark.circle.fill")
                .font(WernickeTypography.size16)
                .foregroundStyle(V4Color.success)

            Text(message)
                .font(WernickeTypography.size13)
                .foregroundStyle(V4Color.textPrimary)

            Spacer()
        }
        .padding(.horizontal, ParietalSpacing.md)
        .padding(.vertical, ParietalSpacing.sm + 2)
        .background(V4Color.success.opacity(V2Depth.bgSubtle))
        .cornerRadius(V1Theme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: V1Theme.cornerMedium)
                .stroke(V4Color.success.opacity(V2Depth.stateHover), lineWidth: 1)
        )
    }
}

// MARK: - Preview

struct DetailedSuccessStates_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            DetailedSuccessState(
                title: "Success!",
                message: "Your changes have been saved successfully.",
                actionTitle: "Continue"
            )
            .frame(width: ParietalSpacing.sheetWidth, height: ParietalSpacing.mediumModalFrame)
            .padding()
            .background(V4Color.background)

            CheckmarkAnimation()
                .frame(width: ParietalSpacing.xxLargeFrame, height: ParietalSpacing.xxLargeFrame)
                .padding()
                .background(V4Color.background)

            ProgressSuccessView(
                steps: ["Step 1: Setup", "Step 2: Configure", "Step 3: Complete"],
                currentStep: 3
            )
            .frame(width: ParietalSpacing.extraWidePanel)
            .padding()
            .background(V4Color.background)

            CompactSuccess(message: "File uploaded successfully")
                .frame(width: ParietalSpacing.xl * 12)
                .padding()
                .background(V4Color.background)
        }
    }
}
