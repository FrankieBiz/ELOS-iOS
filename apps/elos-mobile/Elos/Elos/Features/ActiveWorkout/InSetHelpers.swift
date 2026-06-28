import Foundation

/// Pure, view-agnostic helpers for the in-set logging experience. Kept free of SwiftUI/SwiftData
/// so they're unit-testable (matches the Intelligence-engine convention).

/// Rest-timer adjustment math.
enum RestMath {
    /// Adjust the remaining rest by `delta` seconds, clamped at zero.
    static func adjust(_ current: Int, by delta: Int) -> Int { max(0, current + delta) }

    /// Step used by the −/+ controls.
    static let step = 15
}

/// The RPE effort ladder shown in place of a typed RPE field.
enum RPEScale {
    /// Half-point steps across the realistic working-set range.
    static let values: [Double] = [6, 7, 7.5, 8, 8.5, 9, 9.5, 10]

    /// A reps-in-reserve anchor for a given RPE, used as a one-line hint.
    static func hint(for rpe: Double) -> String {
        switch rpe {
        case ..<6.5:  return "~4 reps left"
        case ..<7.25: return "~3 reps left"
        case ..<7.75: return "2–3 reps left"
        case ..<8.25: return "~2 reps left"
        case ..<8.75: return "1–2 reps left"
        case ..<9.25: return "~1 rep left"
        case ..<9.75: return "0–1 reps left"
        default:      return "max effort"
        }
    }

    /// Display a ladder value without a trailing ".0" (8 not 8.0, but 7.5 stays 7.5).
    static func label(_ rpe: Double) -> String {
        rpe.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", rpe)
            : String(format: "%.1f", rpe)
    }

    /// Parse a stored RPE string ("8", "7.5", "") into a value, or nil.
    static func parse(_ raw: String) -> Double? {
        let t = raw.trimmingCharacters(in: .whitespaces)
        guard !t.isEmpty, let v = Double(t), v > 0 else { return nil }
        return v
    }
}
