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
        VStack(spacing: 20) {
            Spacer()

            // Success icon
            successIcon

            // Title and message
            VStack(spacing: 8) {
                Text(title)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 300)
            }

            // Action button
            if let actionTitle = actionTitle {
                Button {
                    action()
                } label: {
                    Text(actionTitle)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 10)
                        .background(TrinityTheme.statusOK)
                        .cornerRadius(8)
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
                .fill(TrinityTheme.statusOK.opacity(0.15))
                .frame(width: 70, height: 70)

            Image(systemName: icon ?? "checkmark.circle.fill")
                .font(.system(size: 32))
                .foregroundStyle(TrinityTheme.statusOK)
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
                .fill(TrinityTheme.statusOK)
                .frame(width: 60, height: 60)

            Image(systemName: "checkmark")
                .font(.system(size: 24, weight: .bold))
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
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(TrinityTheme.statusOK)

            Text(message)
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textPrimary)

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
                    .font(.system(size: 12))
                    .foregroundStyle(TrinityTheme.textMuted)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            TrinityTheme.statusOK.opacity(0.1)
        )
        .overlay(
            Rectangle()
                .fill(TrinityTheme.statusOK)
                .frame(height: 2),
            alignment: .top
        )
        .offset(y: isVisible ? 0 : -60)
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: isVisible)
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
            Color.black.opacity(0.3)
                .ignoresSafeArea()
                .onTapGesture {
                    onDismiss()
                }

            // Content
            VStack(spacing: 20) {
                CheckmarkAnimation()

                Text(title)
                    .font(.system(size: 20, weight: .bold))
                    .foregroundStyle(TrinityTheme.textPrimary)

                Text(message)
                    .font(.system(size: 14))
                    .foregroundStyle(TrinityTheme.textMuted)
                    .multilineTextAlignment(.center)

                Button {
                    onDismiss()
                } label: {
                    Text("Continue")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 10)
                        .background(TrinityTheme.accent)
                        .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(32)
            .background(TrinityTheme.bgCard)
            .cornerRadius(TrinityTheme.cornerLarge)
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
            .frame(width: 8, height: 8)
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
        VStack(spacing: 24) {
            // Success icon
            CheckmarkAnimation()

            Text("All Done!")
                .font(.system(size: 20, weight: .bold))
                .foregroundStyle(TrinityTheme.textPrimary)

            Text("You've completed all steps successfully.")
                .font(.system(size: 14))
                .foregroundStyle(TrinityTheme.textMuted)

            // Progress steps
            VStack(spacing: 12) {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(spacing: 12) {
                        Image(systemName: index < steps.count ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 16))
                            .foregroundStyle(TrinityTheme.statusOK)

                        Text(step)
                            .font(.system(size: 13))
                            .foregroundStyle(TrinityTheme.textPrimary)
                    }
                }
            }
        }
        .padding(24)
    }
}

// MARK: - Compact Success

struct CompactSuccess: View {
    let message: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 16))
                .foregroundStyle(TrinityTheme.statusOK)

            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(TrinityTheme.textPrimary)

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(TrinityTheme.statusOK.opacity(0.1))
        .cornerRadius(TrinityTheme.cornerMedium)
        .overlay(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                .stroke(TrinityTheme.statusOK.opacity(0.3), lineWidth: 1)
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
            .frame(width: 400, height: 300)
            .padding()
            .background(TrinityTheme.bgWindow)

            CheckmarkAnimation()
                .frame(width: 100, height: 100)
                .padding()
                .background(TrinityTheme.bgWindow)

            ProgressSuccessView(
                steps: ["Step 1: Setup", "Step 2: Configure", "Step 3: Complete"],
                currentStep: 3
            )
            .frame(width: 350)
            .padding()
            .background(TrinityTheme.bgWindow)

            CompactSuccess(message: "File uploaded successfully")
                .frame(width: 300)
                .padding()
                .background(TrinityTheme.bgWindow)
        }
    }
}
