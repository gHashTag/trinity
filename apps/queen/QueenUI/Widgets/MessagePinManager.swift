import SwiftUI

// MARK: - Pin Storage

/// Manages persistent storage for pinned message IDs using UserDefaults
/// Maximum 5 pinned messages per design requirement
final class PinStore: ObservableObject {
    /// UserDefaults key for storing pinned message IDs
    private static let pinnedKey = "pinnedMessageIDs"

    /// Maximum number of messages that can be pinned at once
    static let maxPins = 5

    /// Published array of currently pinned message IDs
    @Published var pinnedIDs: Set<UUID> = [] {
        didSet {
            save()
        }
    }

    /// Count of currently pinned messages
    var pinCount: Int { pinnedIDs.count }

    /// Whether another message can be pinned (under the limit)
    var canPin: Bool { pinnedIDs.count < Self.maxPins }

    init() {
        load()
    }

    // MARK: - Persistence

    private func load() {
        guard let data = UserDefaults.standard.data(forKey: Self.pinnedKey),
              let decoded = try? JSONDecoder().decode([UUID].self, from: data) else {
            pinnedIDs = []
            return
        }
        pinnedIDs = Set(decoded)
    }

    private func save() {
        let array = Array(pinnedIDs)
        guard let data = try? JSONEncoder().encode(array) else { return }
        UserDefaults.standard.set(data, forKey: Self.pinnedKey)
    }

    // MARK: - Actions

    /// Check if a message is currently pinned
    func isPinned(_ id: UUID) -> Bool {
        pinnedIDs.contains(id)
    }

    /// Toggle pin state for a message. Returns true if pinned, false if unpinned.
    @discardableResult
    func togglePin(id: UUID) -> Bool {
        if pinnedIDs.contains(id) {
            pinnedIDs.remove(id)
            return false
        } else {
            // Remove oldest pin if at capacity (FIFO eviction)
            if pinnedIDs.count >= Self.maxPins {
                if let oldest = pinnedIDs.first {
                    pinnedIDs.remove(oldest)
                }
            }
            pinnedIDs.insert(id)
            return true
        }
    }

    /// Pin a specific message. Returns true if successful.
    @discardableResult
    func pin(id: UUID) -> Bool {
        guard pinnedIDs.count < Self.maxPins else { return false }
        pinnedIDs.insert(id)
        return true
    }

    /// Unpin a specific message
    func unpin(id: UUID) {
        pinnedIDs.remove(id)
    }

    /// Clear all pins
    func clearAll() {
        pinnedIDs.removeAll()
    }
}

// MARK: - Pin Badge

/// Visual badge showing the number of pinned messages
/// Displays count 1-5, empty state when 0 pinned
struct PinBadge: View {
    let count: Int

    /// Environment check for reduced motion
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(TrinityTheme.bgWindow)
                .frame(minWidth: 16, minHeight: 16)
                .padding(2)
                .background(
                    Circle()
                        .fill(TrinityTheme.golden)
                )
                .accessibilityLabel("Pinned messages")
                .accessibilityValue("\(count) pinned")
        } else {
            Image(systemName: "pin")
                .font(.system(size: 12))
                .foregroundStyle(TrinityTheme.textMuted)
                .frame(width: 20, height: 20)
                .accessibilityLabel("No pinned messages")
        }
    }
}

// MARK: - Pin Indicator

/// Visual indicator shown on pinned messages (small icon overlay)
struct PinIndicator: View {
    @State private var isVisible = false

    var body: some View {
        Image(systemName: "pin.fill")
            .font(.system(size: 9, weight: .semibold))
            .foregroundStyle(TrinityTheme.golden)
            .frame(width: 16, height: 16)
            .background(
                Circle()
                    .fill(TrinityTheme.bgCard)
                    .shadow(color: .black.opacity(0.3), radius: 2)
            )
            .offset(x: -4, y: -4)
            .opacity(isVisible ? 1 : 0)
            .scaleEffect(isVisible ? 1 : 0.5)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isVisible)
            .onAppear {
                isVisible = true
            }
    }
}

// MARK: - Pin Context Menu Action

/// Context menu action for pinning/unpinning messages
struct PinContextMenuAction: View {
    let messageID: UUID
    let isPinned: Bool
    let onToggle: (UUID) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            onToggle(messageID)
            playFeedback()
        } label: {
            Label(
                isPinned ? "Unpin Message" : "Pin Message",
                systemImage: isPinned ? "pin.slash" : "pin"
            )
        }
    }

    private func playFeedback() {
        if !reduceMotion {
            NSHapticFeedbackManager.defaultPerformer.perform(
                .alignment,
                performanceTime: .default
            )
        }
    }
}

// MARK: - Pinned Messages Header

/// Header section shown above pinned messages
struct PinnedMessagesHeader: View {
    let count: Int

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "pin.fill")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(TrinityTheme.golden)

            Text("Pinned")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(TrinityTheme.textMuted)

            if count > 0 {
                Text("(\(count))")
                    .font(.system(size: 11))
                    .foregroundStyle(TrinityTheme.textMuted.opacity(0.6))
            }

            Spacer()

            if count > 0 {
                Text("max \(PinStore.maxPins)")
                    .font(.system(size: 10))
                    .foregroundStyle(TrinityTheme.textMuted.opacity(0.4))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: TrinityTheme.cornerSmall)
                .fill(TrinityTheme.bgCard.opacity(0.5))
        )
    }
}

// MARK: - Pin Animation Modifier

/// View modifier that applies pin/unpin animations
struct PinAnimationModifier: ViewModifier {
    let isPinned: Bool
    let isAnimating: Bool

    @State private var scale: CGFloat = 1.0
    @State private var rotation: Double = 0

    func body(content: Content) -> some View {
        content
            .overlay(
                RoundedRectangle(cornerRadius: TrinityTheme.cornerMedium)
                    .stroke(
                        LinearGradient(
                            colors: isPinned ? [TrinityTheme.golden, TrinityTheme.golden.opacity(0.3)] : [],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: isPinned ? 2 : 0
                    )
                    .opacity(isAnimating ? 1 : 0)
            )
            .scaleEffect(scale)
            .rotationEffect(.degrees(rotation))
            .onChange(of: isPinned) { _, newValue in
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    if newValue {
                        scale = 1.02
                        rotation = 0.5
                        Task { @MainActor in
                            try? await Task.sleep(for: .milliseconds(100))
                            scale = 1.0
                            rotation = 0
                        }
                    }
                }
            }
    }
}

// MARK: - View Extensions

extension View {
    /// Applies pin animation when the pin state changes
    func pinAnimation(isPinned: Bool, isAnimating: Bool = true) -> some View {
        self.modifier(PinAnimationModifier(isPinned: isPinned, isAnimating: isAnimating))
    }
}

// MARK: - Preview Provider

struct MessagePinManager_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            // Pin badges with different counts
            HStack(spacing: 16) {
                PinBadge(count: 0)
                PinBadge(count: 1)
                PinBadge(count: 3)
                PinBadge(count: 5)
            }
            .padding()
            .background(TrinityTheme.bgSidebar)

            // Pinned messages header
            VStack(spacing: 8) {
                PinnedMessagesHeader(count: 0)
                PinnedMessagesHeader(count: 2)
                PinnedMessagesHeader(count: 5)
            }
            .padding()
            .background(TrinityTheme.bgSidebar)

            // Context menu action preview
            List {
                Text("Sample Message 1")
                    .contextMenu {
                        PinContextMenuAction(
                            messageID: UUID(),
                            isPinned: false,
                            onToggle: { _ in }
                        )
                    }

                Text("Sample Message 2")
                    .contextMenu {
                        PinContextMenuAction(
                            messageID: UUID(),
                            isPinned: true,
                            onToggle: { _ in }
                        )
                    }
            }
        }
        .frame(width: 300)
        .padding()
        .background(TrinityTheme.bgWindow)
        .preferredColorScheme(.dark)
    }
}
