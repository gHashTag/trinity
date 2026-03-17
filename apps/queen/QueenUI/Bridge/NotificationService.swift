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

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    func notify(title: String, body: String, sound: String = "Glass") {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        if soundMode != .silent {
            content.sound = UNNotificationSound(named: UNNotificationSoundName(rawValue: sound))
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
}
