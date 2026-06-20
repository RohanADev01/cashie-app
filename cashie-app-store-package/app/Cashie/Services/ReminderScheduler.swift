import Foundation
import UserNotifications

/// Schedules a single daily local notification reminding the user to log
/// today's spend. Driven by `AppSettings.dailyReminderEnabled` and the
/// configured hour/minute. Idempotent, call `sync(with:)` whenever the
/// settings change.
enum ReminderScheduler {
    private static let identifier = "cashie.daily.reminder"
    private static let rateIdentifier = "cashie.rate.reminder"
    private static let rateScheduledKey = "rateReminderScheduled"

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

    /// Schedules a one-time "rate Cashie" nudge ~3 days out, exactly once. Only
    /// fires if the user has already granted notifications, it never prompts for
    /// permission on its own. Tapping it opens the app (the rate card lives on
    /// the You tab).
    static func scheduleRateReminderIfNeeded() async {
        let defaults = UserDefaults.standard
        guard !defaults.bool(forKey: rateScheduledKey) else { return }

        let center = UNUserNotificationCenter.current()
        let status = await center.notificationSettings().authorizationStatus
        guard status == .authorized || status == .provisional else { return }

        let content = UNMutableNotificationContent()
        content.title = "Enjoying Cashie?"
        content.body = "If Cashie's helping, a quick 5-star rating goes a long way. Tap to rate."
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3 * 24 * 60 * 60, repeats: false)
        let request = UNNotificationRequest(identifier: rateIdentifier, content: content, trigger: trigger)
        try? await center.add(request)
        defaults.set(true, forKey: rateScheduledKey)
    }
}
