import Foundation
import SwiftUI

struct QueenGlassProfile: Equatable, Sendable {
    let rootBlackOpacity: Double
    let surfaceBlackOpacity: Double
    let elevatedBlackOpacity: Double
    let sidebarBlackOpacity: Double
    let contentBlackOpacity: Double
    let borderWhiteOpacity: Double
    let mutedTextWhiteOpacity: Double
    let dimTextWhiteOpacity: Double
    let usesOpaqueContentFill: Bool
}

enum QueenGlassTheme {
    static let shared = QueenGlassProfile(
        rootBlackOpacity: 0.60,
        surfaceBlackOpacity: 0.46,
        elevatedBlackOpacity: 0.58,
        sidebarBlackOpacity: 0.22,
        contentBlackOpacity: 0.14,
        borderWhiteOpacity: 0.14,
        mutedTextWhiteOpacity: 0.62,
        dimTextWhiteOpacity: 0.43,
        usesOpaqueContentFill: false
    )
}

struct QueenWorkspaceDescriptor: Equatable {
    let screen: Screen
    let subtitle: String
    let dataSource: String
}

enum QueenWorkspaceCatalog {
    static let operationalScreens = (0..<27).map(Screen.screenForBlock)

    static func descriptor(for screen: Screen) -> QueenWorkspaceDescriptor? {
        let details: (String, String)

        switch screen {
        case .chat:
            details = ("Agent conversation and tool timeline", "Trios runtime")
        case .sevoFarm:
            details = ("Evolution state, population, and farm actions", ".trinity")
        case .arenaLLM:
            details = ("Model battles and ELO leaderboard", "data/arena")
        case .arenaCode:
            details = ("Code-solving benchmark results", ".trinity")
        case .faculty:
            details = ("Agent roster, health, and capabilities", "heartbeats")
        case .oracle:
            details = ("Watchdog signals and operational alerts", ".trinity")
        case .muMemory:
            details = ("Persistent experience and memory index", ".trinity/experience")
        case .scholar:
            details = ("Research agent status and focus", "heartbeats")
        case .swarm:
            details = ("Cell registry and task decomposition", "src/*/cell.tri")
        case .hive:
            details = ("Ranked self-improvement targets and live bees", ".trinity/queen/hive.json")
        case .brainHealth:
            details = ("Runtime diagnostics and neural health", ".trinity")
        case .build:
            details = ("Build status and verification output", ".trinity/logs")
        case .triTools:
            details = ("TRI command and specification tools", "TRI runtime")
        case .issues:
            details = ("Repository issue snapshot", ".trinity")
        case .git:
            details = ("Repository status and recent changes", "Git")
        case .deploy:
            details = ("Deployment state and recovery controls", ".trinity")
        case .bridge:
            details = ("Browser, Telegram, and GitHub bridges", "integrations")
        case .telegram:
            details = ("Telegram transport and event history", ".trinity")
        case .keys:
            details = ("Credential presence and validation", "environment")
        case .state:
            details = ("Queen runtime state and senses", ".trinity")
        case .files:
            details = ("Project structure and source roots", "filesystem")
        case .todo:
            details = ("To-Do list with task tracking and details", ".trinity/queen/todos.json")
        case .rainbowBridge:
            details = ("Cross-runtime bridge status", "integrations")
        case .sacredMath:
            details = ("Canonical constants and identities", "specs")
        case .techTree:
            details = ("Capability dependencies and maturity", "architecture")
        case .fpga:
            details = ("Hardware synthesis and artifact status", "fpga")
        case .vsa:
            details = ("Vector-symbolic architecture metrics", "specs")
        case .pipeline:
            details = ("Specification pipeline and stages", ".trinity")
        case .benchmarks:
            details = ("Performance history and comparisons", "bench")
        case .experience:
            details = ("Saved episodes and learned patterns", ".trinity/experience")
        case .settings:
            details = ("Queen preferences and runtime controls", "UserDefaults")
        }

        return QueenWorkspaceDescriptor(
            screen: screen,
            subtitle: details.0,
            dataSource: details.1
        )
    }
}

struct QueenOperationalWorkspace<Content: View>: View {
    let screen: Screen
    @ViewBuilder let content: () -> Content

    var body: some View {
        ZStack(alignment: .bottom) {
            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            QueenActionFeedbackBar()
                .padding(.horizontal, ParietalSpacing.sm)
                .padding(.bottom, ParietalSpacing.xs)
        }
        .background(
            Color.black.opacity(QueenGlassTheme.shared.contentBlackOpacity)
        )
        .accessibilityElement(children: .contain)
        .accessibilityLabel(accessibilityLabel)
    }

    private var accessibilityLabel: String {
        guard let descriptor = QueenWorkspaceCatalog.descriptor(for: screen) else {
            return "\(screen.rawValue) workspace"
        }
        return "\(screen.rawValue). \(descriptor.subtitle)"
    }
}

struct QueenActionFeedbackBar: View {
    @ObservedObject private var queue = ActionQueue.shared

    @ViewBuilder
    var body: some View {
        if let feedback = queue.feedback {
            feedbackCard(feedback)
                .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }

    private func feedbackCard(_ feedback: QueenActionFeedback) -> some View {
        HStack(spacing: ParietalSpacing.xs) {
            feedbackIcon(feedback.phase)
            feedbackText(feedback)
            Spacer(minLength: ParietalSpacing.xs)
            dismissButton
        }
        .padding(.horizontal, ParietalSpacing.sm)
        .padding(.vertical, ParietalSpacing.xs)
        .frame(maxWidth: 620)
        .background(V4Color.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .overlay(feedbackBorder)
        .shadow(color: Color.black.opacity(0.32), radius: 12, y: 6)
        .animation(.easeInOut(duration: 0.18), value: feedback.id)
    }

    private func feedbackText(
        _ feedback: QueenActionFeedback
    ) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(feedback.title)
                .font(WernickeTypography.captionBold.monospaced())
                .foregroundStyle(V4Color.textPrimary)
            Text(feedback.detail)
                .font(WernickeTypography.tiny)
                .foregroundStyle(V4Color.textSecondary)
                .lineLimit(2)
        }
    }

    private var dismissButton: some View {
        Button {
            queue.dismissFeedback()
        } label: {
            Image(systemName: "xmark")
                .font(WernickeTypography.tiny)
                .foregroundStyle(V4Color.textSecondary)
        }
        .buttonStyle(.plain)
    }

    private var feedbackBorder: some View {
        RoundedRectangle(cornerRadius: 12, style: .continuous)
            .stroke(V4Color.border, lineWidth: 1)
    }

    @ViewBuilder
    private func feedbackIcon(_ phase: QueenActionPhase) -> some View {
        switch phase {
        case .queued:
            Image(systemName: "tray.and.arrow.down.fill")
                .foregroundStyle(V4Color.warning)
        case .running:
            ProgressView()
                .controlSize(.small)
        case .succeeded:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(V4Color.success)
        case .failed:
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(V4Color.error)
        }
    }
}
