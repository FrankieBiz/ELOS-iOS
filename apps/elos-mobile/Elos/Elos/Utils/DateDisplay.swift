import Foundation

/// Small display helpers for the `yyyy-MM-dd` date strings stored on
/// AssignmentRecord/ExamRecord (produced by CanvasService.dayString).
///
/// `friendly` parses a stored `yyyy-MM-dd` string and returns a human label
/// like "May 20". If the input isn't in that format (e.g. a manually entered
/// value), it is returned unchanged so nothing ever shows worse than before.
enum DateDisplay {
    private static let storedParser: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let shortDisplay: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// "2026-05-20" -> "May 20". Unparseable input is returned unchanged.
    static func friendly(_ stored: String) -> String {
        guard let date = storedParser.date(from: stored) else { return stored }
        return shortDisplay.string(from: date)
    }
}
