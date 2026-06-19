import Foundation
import UserNotifications

/// Schedules a single daily local notification reminding the user to log
/// today's spend. Driven by `AppSettings.dailyReminderEnabled` and the
/// configured hour/minute. Idempotent, call `sync(with:)` whenever the
/// settings change.
enum ReminderScheduler {
    private static let identifier = "cashie.daily.reminder"

    /// Brings the system schedule into agreement with the supplied settings.
    static func sync(with settings: AppSettings) async {
        let center = UNUserNotificationCenter.current()
        guard settings.dailyReminderEnabled else {
            center.removePendingNotificationRequests(withIdentifiers: [identifier])
            return
        }

        let granted = (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        guard granted else { return }

        let content = UNMutableNotificationContent()
        content.title = "How did today land?"
        content.body = "Tap to log what you spent."
        content.sound = .default

        var date = DateComponents()
        date.hour = settings.dailyReminderHour
        date.minute = settings.dailyReminderMinute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)

        let request = UNNotificationRequest(identifier: identifier,
                                            content: content,
                                            trigger: trigger)
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        try? await center.add(request)
    }
}
