import UserNotifications

enum NotificationManager {

    static let restTimerID = "elos.rest-timer"
    static let habitReminderID = "elos.habit-daily"

    // MARK: - Auth

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Rest Timer

    static func scheduleRestTimer(seconds: Int) {
        cancelRestTimer()
        guard seconds > 0 else { return }

        let content = UNMutableNotificationContent()
        content.title = "Rest Complete"
        content.body  = "Time to hit the next set 💪"
        content.sound = .default

        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: TimeInterval(seconds), repeats: false)
        let request  = UNNotificationRequest(identifier: restTimerID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelRestTimer() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [restTimerID])
    }

    // MARK: - Daily Habit Reminder

    /// Schedules (or replaces) a daily notification at the given hour/minute.
    /// Call with hour = nil to cancel.
    static func scheduleHabitReminder(hour: Int = 20, minute: Int = 0) {
        cancelHabitReminder()

        let content = UNMutableNotificationContent()
        content.title = "Habit Check-In"
        content.body  = "Don't break your streak — check off today's habits."
        content.sound = .default

        var comps = DateComponents()
        comps.hour   = hour
        comps.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
        let request  = UNNotificationRequest(identifier: habitReminderID, content: content, trigger: trigger)
        UNUserNotificationCenter.current().add(request)
    }

    static func cancelHabitReminder() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [habitReminderID])
    }
}
