import UserNotifications

enum NotificationManager {

    static let restTimerID   = "elos.rest-timer"
    static let habitReminderID = "elos.habit-daily"   // kept for cancellation of old installs
    private static let dayPrefix = "elos.day."

    // MARK: - Auth

    static func requestAuthorization() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    // MARK: - Split-aware daily notifications

    struct DayInfo {
        let date: Date
        /// Non-empty = training day name (e.g. "Push Day"). Empty = rest / off day.
        let dayName: String
        /// True when user has an active split program (even on rest days).
        let hasSplit: Bool
    }

    /// Schedules one non-repeating 8 pm notification for each of the next `days.count` days,
    /// customised to that day's split. Re-call whenever the active split changes.
    static func scheduleDailyNotifications(_ days: [DayInfo], hour: Int = 20, minute: Int = 0) {
        let center = UNUserNotificationCenter.current()
        let cal    = Calendar.current
        let fmt    = DateFormatter(); fmt.dateFormat = "yyyy-MM-dd"

        // Cancel the legacy repeating reminder + all existing per-day slots (±90 day window).
        var idsToCancel = [habitReminderID]
        for offset in -30..<90 {
            if let d = cal.date(byAdding: .day, value: offset, to: Date()) {
                idsToCancel.append("\(dayPrefix)\(fmt.string(from: d))")
            }
        }
        center.removePendingNotificationRequests(withIdentifiers: idsToCancel)

        for day in days {
            var comps = cal.dateComponents([.year, .month, .day], from: day.date)
            comps.hour   = hour
            comps.minute = minute

            let content = UNMutableNotificationContent()
            (content.title, content.body) = notificationText(for: day)
            content.sound = .default

            let id      = "\(dayPrefix)\(fmt.string(from: day.date))"
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
        }
    }

    private static func notificationText(for day: DayInfo) -> (String, String) {
        // No split configured
        guard day.hasSplit else {
            return (
                "Elos Check-In 📋",
                "Don't break your streak — log your habits today."
            )
        }
        // Rest / off day
        if day.dayName.isEmpty {
            return (
                "Rest Day 🛌",
                "Recovery is part of the program. Log your sleep and habits tonight."
            )
        }
        // Training day
        let name = day.dayName
        return (
            "\(name) 🏋️",
            "Your \(name) session is loaded in Elos. Let's get after it."
        )
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
}
