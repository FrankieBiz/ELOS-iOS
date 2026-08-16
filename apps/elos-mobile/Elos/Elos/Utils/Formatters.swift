import Foundation

/// Shared, cached date formatters. `DateFormatter` is expensive to construct, and
/// the same formats ("yyyy-MM-dd", "MMM d") were being rebuilt inline in many places.
enum Formatters {
    /// Canonical log/exam date format, matching the backend's date strings.
    /// **Always use this for day keys.** A bare `DateFormatter` with `"yyyy-MM-dd"` inherits the
    /// user's calendar, so on a Buddhist or Japanese-imperial calendar today becomes "2569-08-01" —
    /// and that key is what matches habits and readiness to today, schedules notifications and goes to
    /// the server. Locale and calendar are both pinned here so the key is the same for every user.
    static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    /// Short display date, e.g. "Jun 7".
    static let monthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "MMM d"
        return f
    }()

    /// Weekday + short date, e.g. "Sat, Aug 1" — the Today header.
    static let weekdayMonthDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    /// Full weekday, e.g. "Thursday" — used when a date is close enough that the name reads better
    /// than the number.
    static let weekdayLong: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "EEEE"
        return f
    }()

    /// Clock time, e.g. "6:30 AM" — sleep bed/wake times.
    static let clockTime: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "h:mm a"
        return f
    }()

    /// Whole days from today (start of day) to the given "yyyy-MM-dd" string.
    /// Returns 0 if the string can't be parsed. Computing this on read keeps
    /// "days away" fresh instead of relying on a value snapshotted at sync time.
    static func daysFromToday(toISODay s: String) -> Int {
        guard let d = isoDay.date(from: s) else { return 0 }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? 0
    }
}
