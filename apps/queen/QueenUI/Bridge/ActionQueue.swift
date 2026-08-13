import Foundation
import SwiftUI

enum QueenActionRisk: Equatable {
    case safe
    case requiresConfirmation
}

enum QueenActionHandling: Equatable {
    case refresh
    case clearQueue
    case queenRuntime
    /// Executed in-process by the Queen's own hive, not by the Zig runtime.
    case hive
}

struct QueenActionDefinition: Equatable {
    let id: String
    let title: String
    let risk: QueenActionRisk
    let handling: QueenActionHandling
}

enum QueenActionCatalog {
    static let all: [QueenActionDefinition] = [
        action("build", "Rebuild", .safe),
        action("cell_create", "Create cell", .requiresConfirmation),
        action("farm_evolve", "Evolve farm", .requiresConfirmation),
        action("farm_kill_idle", "Kill idle services", .requiresConfirmation),
        action("git_commit", "Commit state", .requiresConfirmation),
        hive("hive_start", "Run the hive 24/7", .requiresConfirmation),
        hive("hive_pause", "Pause the hive", .safe),
        hive("hive_stop_all", "Stop every bee", .requiresConfirmation),
        hive("hive_cycle", "Run one hive cycle", .safe),
        hive("hive_rescan", "Re-measure the system", .safe),
        action("git_push", "Push changes", .requiresConfirmation),
        refresh("issues_refresh", "Refresh issues"),
        refresh("keys_test", "Test keys"),
        action("pipeline_run", "Run pipeline", .requiresConfirmation),
        action("queen_approve", "Approve action", .requiresConfirmation),
        action("queen_deny", "Deny action", .requiresConfirmation),
        QueenActionDefinition(
            id: "queue_clear",
            title: "Clear action queue",
            risk: .requiresConfirmation,
            handling: .clearQueue
        ),
        action("redeploy", "Redeploy", .requiresConfirmation),
        action("scholar_research", "Start research", .safe),
        action("swarm_decompose", "Decompose task", .requiresConfirmation),
        refresh("telegram_check", "Check Telegram"),
        action("telegram_test", "Send Telegram test", .requiresConfirmation),
    ]

    static func definition(for id: String) -> QueenActionDefinition? {
        all.first { $0.id == id }
    }

    private static func action(
        _ id: String,
        _ title: String,
        _ risk: QueenActionRisk
    ) -> QueenActionDefinition {
        QueenActionDefinition(
            id: id,
            title: title,
            risk: risk,
            handling: .queenRuntime
        )
    }

    private static func refresh(
        _ id: String,
        _ title: String
    ) -> QueenActionDefinition {
        QueenActionDefinition(
            id: id,
            title: title,
            risk: .safe,
            handling: .refresh
        )
    }

    private static func hive(
        _ id: String,
        _ title: String,
        _ risk: QueenActionRisk
    ) -> QueenActionDefinition {
        QueenActionDefinition(
            id: id,
            title: title,
            risk: risk,
            handling: .hive
        )
    }
}

struct QueenActionEnvelope: Codable, Equatable {
    let timestamp: Int
    let action: String
    let params: [String: String]

    enum CodingKeys: String, CodingKey {
        case timestamp = "ts"
        case action
        case params
    }
}

enum QueenActionCodec {
    static func encode(_ actions: [QueenActionEnvelope]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(actions)
    }

    static func decode(_ data: Data) throws -> [QueenActionEnvelope] {
        try JSONDecoder().decode([QueenActionEnvelope].self, from: data)
    }
}

enum QueenActionPhase: Equatable {
    case queued
    case running
    case succeeded
    case failed
}

struct QueenActionFeedback: Identifiable, Equatable {
    let id = UUID()
    let actionID: String
    let title: String
    let detail: String
    let phase: QueenActionPhase
}

extension Notification.Name {
    static let queenWorkspaceRefresh = Notification.Name(
        "com.trinity.queen.workspace-refresh"
    )
    /// Object is a `Screen`. Routes to screens that have no petal on the
    /// 27-block triangle.
    static let queenOpenScreen = Notification.Name(
        "com.trinity.queen.open-screen"
    )
}

/// Central action dispatcher. Runtime actions are written to a durable compact
/// JSON queue; local refresh and clear operations complete immediately.
@MainActor
class ActionQueue: ObservableObject {
    static let shared = ActionQueue()

    @Published var lastEnqueued: String?
    @Published var isProcessing = false
    @Published var feedback: QueenActionFeedback?

    private var queuePath: String {
        let cwd = TrinityRuntimePaths.projectRoot
        return "\(cwd)/.trinity/queen/actions_queue.json"
    }

    func enqueue(_ action: String, params: [String: String] = [:]) {
        guard let definition = QueenActionCatalog.definition(for: action) else {
            showFeedback(
                actionID: action,
                title: "Unknown action",
                detail: "\(action) is not declared in the Queen action catalog.",
                phase: .failed
            )
            return
        }

        switch definition.handling {
        case .refresh:
            lastEnqueued = action
            NotificationCenter.default.post(
                name: .queenWorkspaceRefresh,
                object: action
            )
            showFeedback(
                actionID: action,
                title: definition.title,
                detail: "Live workspace data refreshed.",
                phase: .succeeded
            )
        case .clearQueue:
            clearDurableQueue(definition: definition)
        case .queenRuntime:
            enqueueForRuntime(definition: definition, params: params)
        case .hive:
            dispatchToHive(definition: definition)
        }
    }

    /// Hive actions run inside this process — the bees are child processes of
    /// the Queen, so there is nothing to hand to the Zig runtime.
    private func dispatchToHive(definition: QueenActionDefinition) {
        let hive = HiveOrchestrator.shared
        let detail: String

        switch definition.id {
        case "hive_start":
            hive.start()
            detail = "24/7 loop armed."
        case "hive_pause":
            hive.pause()
            detail = "Loop paused. Running bees were left to finish."
        case "hive_stop_all":
            hive.stopAll()
            detail = "Loop paused and every live bee terminated."
        case "hive_cycle":
            hive.runCycleNow()
            detail = "One supervision cycle started."
        case "hive_rescan":
            Task { await hive.rescan() }
            detail = "Re-measuring the system."
        default:
            showFeedback(
                actionID: definition.id,
                title: "Unhandled hive action",
                detail: "\(definition.id) is declared as a hive action but has no handler.",
                phase: .failed
            )
            return
        }

        lastEnqueued = definition.id
        showFeedback(
            actionID: definition.id,
            title: definition.title,
            detail: detail,
            phase: .succeeded
        )
    }

    func dismissFeedback() {
        feedback = nil
    }

    private func enqueueForRuntime(
        definition: QueenActionDefinition,
        params: [String: String]
    ) {
        let url = URL(fileURLWithPath: queuePath)
        var queue: [QueenActionEnvelope] = []

        if let data = try? Data(contentsOf: url) {
            queue = (try? QueenActionCodec.decode(data)) ?? []
        }

        queue.append(
            QueenActionEnvelope(
                timestamp: Int(Date().timeIntervalSince1970),
                action: definition.id,
                params: params
            )
        )

        do {
            let directory = url.deletingLastPathComponent()
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            let data = try QueenActionCodec.encode(queue)
            try data.write(to: url, options: .atomic)

            lastEnqueued = definition.id
            isProcessing = false
            showFeedback(
                actionID: definition.id,
                title: definition.title,
                detail: "Queued durably for the Queen runtime.",
                phase: .queued
            )
        } catch {
            isProcessing = false
            showFeedback(
                actionID: definition.id,
                title: "\(definition.title) failed",
                detail: error.localizedDescription,
                phase: .failed
            )
        }
    }

    private func clearDurableQueue(definition: QueenActionDefinition) {
        let url = URL(fileURLWithPath: queuePath)
        do {
            if FileManager.default.fileExists(atPath: url.path) {
                try FileManager.default.removeItem(at: url)
            }
            lastEnqueued = definition.id
            showFeedback(
                actionID: definition.id,
                title: definition.title,
                detail: "The durable Queen action queue is empty.",
                phase: .succeeded
            )
        } catch {
            showFeedback(
                actionID: definition.id,
                title: "\(definition.title) failed",
                detail: error.localizedDescription,
                phase: .failed
            )
        }
    }

    private func showFeedback(
        actionID: String,
        title: String,
        detail: String,
        phase: QueenActionPhase
    ) {
        feedback = QueenActionFeedback(
            actionID: actionID,
            title: title,
            detail: detail,
            phase: phase
        )
    }
}

/// Reusable action button style for dashboard screens
struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var action: String
    var params: [String: String] = [:]

    @ObservedObject private var queue = ActionQueue.shared
    @State private var showsConfirmation = false

    var body: some View {
        Button {
            if definition?.risk == .requiresConfirmation {
                showsConfirmation = true
            } else {
                submit()
            }
        } label: {
            HStack(spacing: ParietalSpacing.xxs) {
                if queue.isProcessing && queue.lastEnqueued == action {
                    ProgressView()
                        .controlSize(.mini)
                } else {
                    Text(icon)
                        .font(WernickeTypography.caption)
                }
                Text(label)
                    .font(WernickeTypography.captionBold)
            }
            .foregroundStyle(V4Color.textPrimary)
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xxs)
            .background(V4Color.surface)
            .clipShape(SwiftUI.Capsule())
            .overlay {
                SwiftUI.Capsule()
                    .stroke(color.opacity(0.64), lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .confirmationDialog(
            definition?.title ?? label,
            isPresented: $showsConfirmation,
            titleVisibility: .visible
        ) {
            Button("Confirm", role: confirmationRole) {
                submit()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This action can change project or external state.")
        }
        .help(definition?.title ?? label)
    }

    private var definition: QueenActionDefinition? {
        QueenActionCatalog.definition(for: action)
    }

    private var confirmationRole: ButtonRole? {
        action == "farm_kill_idle" || action == "queue_clear"
            ? .destructive
            : nil
    }

    private func submit() {
        queue.enqueue(action, params: params)
    }
}
