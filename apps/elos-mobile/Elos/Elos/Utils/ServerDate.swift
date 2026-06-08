import Foundation

/// Parses timestamps as returned by the backend. Postgres `timestamptz::text`
/// produces values like "2026-06-08 18:14:40.123456+00" (space separator,
/// up-to-6 fractional digits, 2-digit zone offset) which `ISO8601DateFormatter`
/// cannot parse directly — so normalize first, then try ISO variants.
enum ServerDate {
    private static let isoFractional: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        return f
    }()

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    static func parse(_ raw: String?) -> Date? {
        guard let raw, !raw.isEmpty else { return nil }
        var s = raw

        // "2026-06-08 18:14:40..." → "2026-06-08T18:14:40..."
        if let space = s.firstIndex(of: " ") {
            s.replaceSubrange(space...space, with: "T")
        }

        // Normalize the timezone suffix to ±HH:MM (Postgres emits "+00" / "-05";
        // ISO wants "+00:00"). Leave a trailing "Z" untouched.
        if let tz = s.range(of: #"[+-]\d{2}$"#, options: .regularExpression) {
            _ = tz
            s.append(":00")
        }

        // ISO8601 fractional parsing only tolerates milliseconds (3 digits);
        // trim Postgres microseconds down so the parse succeeds.
        if let dot = s.firstIndex(of: ".") {
            let after = s.index(after: dot)
            // collect digits following the dot
            var end = after
            while end < s.endIndex, s[end].isNumber { end = s.index(after: end) }
            let digits = s.distance(from: after, to: end)
            if digits > 3 {
                let trimEnd = s.index(after: s.index(dot, offsetBy: 3))
                s.removeSubrange(trimEnd..<end)
            }
        }

        return isoFractional.date(from: s) ?? iso.date(from: s)
    }
}
