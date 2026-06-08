import Foundation

/// Shared, cached date formatters. `DateFormatter` is expensive to construct, and
/// the same formats ("yyyy-MM-dd", "MMM d") were being rebuilt inline in many places.
enum Formatters {
    /// Canonical log/exam date format, matching the backend's date strings.
    static let isoDay: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
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

    /// Whole days from today (start of day) to the given "yyyy-MM-dd" string.
    /// Returns 0 if the string can't be parsed. Computing this on read keeps
    /// "days away" fresh instead of relying on a value snapshotted at sync time.
    static func daysFromToday(toISODay s: String) -> Int {
        guard let d = isoDay.date(from: s) else { return 0 }
        let cal = Calendar.current
        return cal.dateComponents([.day], from: cal.startOfDay(for: Date()), to: cal.startOfDay(for: d)).day ?? 0
    }
}
