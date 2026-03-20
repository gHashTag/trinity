import Foundation
import SwiftUI

/// Central action dispatcher — writes actions to .trinity/queen/actions_queue.json
/// Queen Zig daemon reads and executes them on next cycle
@MainActor
class ActionQueue: ObservableObject {
    static let shared = ActionQueue()

    @Published var lastEnqueued: String?
    @Published var isProcessing = false

    private var queuePath: String {
        let cwd = FileManager.default.currentDirectoryPath
        return "\(cwd)/.trinity/queen/actions_queue.json"
    }

    func enqueue(_ action: String, params: [String: String] = [:]) {
        let entry: [String: Any] = [
            "ts": Int(Date().timeIntervalSince1970),
            "action": action,
            "params": params,
        ]

        // Read existing queue or create new
        var queue: [[String: Any]] = []
        if let data = try? Data(contentsOf: URL(fileURLWithPath: queuePath)),
           let existing = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            queue = existing
        }

        queue.append(entry)

        // Ensure directory exists
        let dir = (queuePath as NSString).deletingLastPathComponent
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)

        // Write
        if let data = try? JSONSerialization.data(withJSONObject: queue, options: [.prettyPrinted]) {
            try? data.write(to: URL(fileURLWithPath: queuePath))
        }

        lastEnqueued = action
        isProcessing = true

        // Reset processing indicator after 3s
        Task {
            try? await Task.sleep(for: .seconds(3))
            await MainActor.run {
                isProcessing = false
            }
        }
    }
}

/// Reusable action button style for dashboard screens
struct ActionButton: View {
    let icon: String
    let label: String
    let color: Color
    var action: String
    var params: [String: String] = [:]

    @StateObject private var queue = ActionQueue.shared

    var body: some View {
        Button {
            ActionQueue.shared.enqueue(action, params: params)
        } label: {
            HStack(spacing: ParietalSpacing.xxs) {
                Text(icon)
                    .font(WernickeTypography.caption)
                Text(label)
                    .font(WernickeTypography.captionBold)
            }
            .foregroundStyle(.black)
            .padding(.horizontal, ParietalSpacing.sm)
            .padding(.vertical, ParietalSpacing.xxs)
            .background(color)
            .clipShape(SwiftUI.Capsule())
        }
        .buttonStyle(.plain)
    }
}
