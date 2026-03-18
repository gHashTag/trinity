import Foundation
import UserNotifications
import AppKit

/// macOS notifications + sound feedback for Queen events
class NotificationService {
    static let shared = NotificationService()

    enum SoundMode: String {
        case full = "full"
        case notificationsOnly = "notifications"
        case silent = "silent"
    }

    var soundMode: SoundMode {
        let raw = UserDefaults.standard.string(forKey: "soundMode") ?? "full"
        return SoundMode(rawValue: raw) ?? .full
    }

    // MARK: - Notification Grouping

    /// Tracks recent notifications per category for grouping within 5 minutes
    private struct GroupEntry {
        let firstFired: Date
        var count: Int
    }
    private var groupTracker: [String: GroupEntry] = [:]
    private let groupWindowSeconds: TimeInterval = 300 // 5 minutes

    /// Returns true if this notification should be suppressed (grouped into existing one).
    /// Updates the tracker and posts a summary notification when count > 1.
    private func shouldGroup(category: String) -> Bool {
        let now = Date()
        if let entry = groupTracker[category],
           now.timeIntervalSince(entry.firstFired) < groupWindowSeconds {
            groupTracker[category] = GroupEntry(firstFired: entry.firstFired, count: entry.count + 1)
            return true
        }
        groupTracker[category] = GroupEntry(firstFired: now, count: 1)
        return false
    }

    /// Returns the current group count for a category (for summary text)
    private func groupCount(for category: String) -> Int {
        groupTracker[category]?.count ?? 1
    }

    // MARK: - Setup

    func requestPermission() {
        // Guard: only request from real app bundle
        guard Bundle.main.bundleIdentifier != nil else {
            NSLog("[NotificationService] Skipping notification request: no app bundle (CLI build)")
            return
        }
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
        registerCategories()
    }

    private func registerCategories() {
        let responseCategory = UNNotificationCategory(
            identifier: "RESPONSE_READY",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        let budgetCategory = UNNotificationCategory(
            identifier: "BUDGET_ALERT",
            actions: [],
            intentIdentifiers: [],
            options: .customDismissAction
        )
        UNUserNotificationCenter.current().setNotificationCategories([responseCategory, budgetCategory])
    }

    // MARK: - Core Notify

    func notify(title: String, body: String, sound: String = "Glass", threadIdentifier: String? = nil, categoryIdentifier: String? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if soundMode != .silent {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))
        }
        if let threadID = threadIdentifier {
            content.threadIdentifier = threadID
        }
        if let category = categoryIdentifier {
            content.categoryIdentifier = category
        }

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    func playSound(_ name: String) {
        guard soundMode == .full else { return }
        NSSound(named: NSSound.Name(name))?.play()
    }

    // Event-specific notifications
    func buildBroke() {
        notify(title: "Build Failed", body: "zig build broke — check errors", sound: "Sosumi")
    }

    func buildFixed() {
        playSound("Glass")
    }

    func pplRecord(ppl: Double, service: String) {
        notify(title: "PPL Record!", body: "\(service) reached PPL \(String(format: "%.2f", ppl))", sound: "Hero")
        playSound("Hero")
    }

    func approvalNeeded(action: String) {
        notify(title: "Approval Needed", body: "Queen wants to execute: \(action)", sound: "Morse")
    }

    func streamCompleted(tokens: Int, duration: TimeInterval, model: String) {
        // Only notify for long streams (>30s) when app is not frontmost
        guard duration > 30 else { return }
        guard !NSApp.isActive else { return }
        let durationStr = duration < 60 ? "\(Int(duration))s" : String(format: "%.1fm", duration / 60)
        notify(
            title: "Response Ready",
            body: "\(model): \(tokens) tokens in \(durationStr)",
            sound: "Glass"
        )
    }

    /// Rich notification when streaming response completes while app is in background.
    /// Groups by thread; shows first 100 chars of response as preview.
    func streamCompleted(threadTitle: String, preview: String, threadID: UUID) {
        guard !NSApp.isActive else { return }

        let trimmed = String(preview.prefix(100))
        let body = trimmed.count < preview.count ? trimmed + "..." : trimmed

        // Group repeated completions for same thread within 5 minutes
        let groupKey = "response-\(threadID.uuidString)"
        if shouldGroup(category: groupKey) {
            let count = groupCount(for: groupKey)
            // Replace with summary notification
            let summaryContent = UNMutableNotificationContent()
            summaryContent.title = "Queen \u{2014} \(count) responses ready"
            summaryContent.body = "Latest: \(threadTitle)"
            summaryContent.threadIdentifier = threadID.uuidString
            summaryContent.categoryIdentifier = "RESPONSE_READY"
            if soundMode != .silent {
                summaryContent.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: "Glass"))
            }
            let req = UNNotificationRequest(
                identifier: "response-group-\(threadID.uuidString)",
                content: summaryContent,
                trigger: nil
            )
            UNUserNotificationCenter.current().add(req)
            return
        }

        notify(
            title: "Queen \u{2014} Response ready",
            body: body,
            sound: "Glass",
            threadIdentifier: threadID.uuidString,
            categoryIdentifier: "RESPONSE_READY"
        )
    }

    /// Notification when daily budget is exceeded. Fires at most once per calendar day.
    func budgetAlert(spent: Double, budget: Double) {
        guard spent >= budget else { return }

        // Only fire once per day
        let today = Calendar.current.startOfDay(for: Date())
        let lastAlertDate = UserDefaults.standard.object(forKey: "lastBudgetAlertDate") as? Date
        if let lastDate = lastAlertDate, Calendar.current.isDate(lastDate, inSameDayAs: today) {
            return
        }
        UserDefaults.standard.set(today, forKey: "lastBudgetAlertDate")

        let spentStr = String(format: "$%.2f", spent)
        let budgetStr = String(format: "$%.2f", budget)
        notify(
            title: "Queen \u{2014} Budget exceeded",
            body: "\(spentStr)/\(budgetStr)",
            sound: "Sosumi",
            categoryIdentifier: "BUDGET_ALERT"
        )
    }

    func apiError(provider: String, error: String) {
        guard !NSApp.isActive else { return }
        notify(title: "API Error", body: "\(provider): \(error)", sound: "Basso")
    }
}
