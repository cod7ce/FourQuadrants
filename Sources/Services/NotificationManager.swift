import Foundation
import UserNotifications

/// 管理截止提醒的本地通知。
@MainActor
final class NotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()

    func configure() {
        center.delegate = self
    }

    func requestAuthorizationIfNeeded() async {
        let settings = await center.notificationSettings()
        guard settings.authorizationStatus == .notDetermined else { return }
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
    }

    /// 根据任务的 remindAt 重新安排（或取消）通知。
    func reschedule(for task: TaskItem) async {
        let id = task.notificationID
        center.removePendingNotificationRequests(withIdentifiers: [id])

        guard let remindAt = task.remindAt, !task.isCompleted, remindAt > .now else { return }
        await requestAuthorizationIfNeeded()

        let content = UNMutableNotificationContent()
        content.title = task.title.isEmpty ? "任务提醒" : task.title
        if let key = task.issueKey { content.subtitle = key }
        if !task.notes.isEmpty { content.body = task.notes }
        content.sound = .default

        let comps = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute], from: remindAt)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        try? await center.add(request)
    }

    func cancel(for task: TaskItem) {
        center.removePendingNotificationRequests(withIdentifiers: [task.notificationID])
    }

    // 让通知在应用前台时也展示。
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
