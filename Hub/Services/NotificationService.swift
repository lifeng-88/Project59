import Foundation
import UserNotifications

@MainActor
enum NotificationService {
    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    static func scheduleReminder(for task: HubTask, language: AppLanguage) {
        guard let fireDate = task.reminderDate,
              fireDate > Date(),
              !task.isCompleted else { return }

        let content = UNMutableNotificationContent()
        content.title = L10n.tr(.notifyTaskReminderTitle, language: language)
        content.body = task.title
        content.sound = .default

        let components = Calendar.current.dateComponents(
            [.year, .month, .day, .hour, .minute],
            from: fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(
            identifier: task.id.uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelReminder(for task: HubTask) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [task.id.uuidString]
        )
    }

    private static let focusPhaseEndID = "hub.focus.phase.end"

    static func notifyFocusComplete(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
        let request = UNNotificationRequest(
            identifier: "hub.focus.complete.\(UUID().uuidString)",
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    /// 在阶段结束时触发（用于 App 在后台时仍能提醒）
    static func scheduleFocusPhaseEnd(at endDate: Date, title: String, body: String) {
        cancelFocusPhaseEnd()
        let interval = endDate.timeIntervalSinceNow
        guard interval > 1 else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: focusPhaseEndID,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelFocusPhaseEnd() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(
            withIdentifiers: [focusPhaseEndID]
        )
    }

    static func syncAll(tasks: [HubTask], enabled: Bool, language: AppLanguage) async {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
        guard enabled else { return }
        let status = await authorizationStatus()
        guard status == .authorized || status == .provisional else { return }
        for task in tasks where !task.isCompleted {
            scheduleReminder(for: task, language: language)
        }
    }
}
