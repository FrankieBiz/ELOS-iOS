import Foundation

/// Single source of truth for weight units across the app.
///
/// Storage invariant: weight is ALWAYS persisted and synced in kilograms
/// (`ExerciseSetRecord.weightKg`, `WorkoutSessionRecord.totalVolume`, backend
/// `weight_kg` / `total_volume`). This type is the ONLY place that converts
/// between kilograms and the user's chosen display unit, and the only place
/// that builds "kg"/"lb" display strings. Do not scatter `0.453592` literals
/// or hardcoded unit labels anywhere else.
enum WeightUnit: String, CaseIterable, Codable {
    case kg
    case lb

    /// The one canonical conversion constant (NIST: 1 lb = 0.45359237 kg).
    static let kgPerLb = 0.45359237

    /// Sensible default derived from the device locale.
    /// Only the US (and a couple of others) default to imperial.
    static var localeDefault: WeightUnit {
        Locale.current.measurementSystem == .us ? .lb : .kg
    }

    // MARK: - Bridging to the persisted `useImperial` flag

    /// Maps the existing `UserProfileRecord.useImperial` flag onto the enum so
    /// we reuse one preference end-to-end (imperial == pounds).
    init(useImperial: Bool) { self = useImperial ? .lb : .kg }
    var useImperial: Bool { self == .lb }

    // MARK: - Display

    var label: String { self == .kg ? "kg" : "lb" }

    // MARK: - Conversion

    /// Convert a kilogram value into this unit for display.
    func fromKg(_ kg: Double) -> Double { self == .kg ? kg : kg / Self.kgPerLb }

    /// Convert a value the user typed (in this unit) back into kilograms for storage.
    func toKg(_ display: Double) -> Double { self == .kg ? display : display * Self.kgPerLb }

    // MARK: - Increments / rounding

    /// Natural load step for +/- controls and overload suggestions
    /// (2.5 kg vs 5 lb plates).
    var increment: Double { self == .kg ? 2.5 : 5 }

    /// Round a display-unit value to the unit's natural granularity.
    func round(_ display: Double) -> Double {
        let step = self == .kg ? 0.5 : 5.0
        return (display / step).rounded() * step
    }

    private func defaultDecimals() -> Int { self == .kg ? 1 : 0 }

    // MARK: - Formatting (the ONLY place unit strings are built)

    /// A single weight with its unit, e.g. "62.5 kg" / "135 lb".
    func formatWeight(kg: Double, decimals: Int? = nil) -> String {
        "\(formatValue(kg: kg, decimals: decimals)) \(label)"
    }

    /// Just the numeric value in the display unit (no unit suffix) — for
    /// text-field placeholders and editable fields.
    func formatValue(kg: Double, decimals: Int? = nil) -> String {
        let d = decimals ?? defaultDecimals()
        return String(format: "%.\(d)f", fromKg(kg))
    }

    /// Volume (kg·reps) rendered in the display unit with a "k" abbreviation
    /// for large numbers, e.g. "12.3k kg" / "27.1k lb".
    func formatVolume(kg: Double) -> String {
        let v = fromKg(kg)
        if v >= 1000 { return String(format: "%.1fk %@", v / 1000, label) }
        return String(format: "%.0f %@", v, label)
    }
}
