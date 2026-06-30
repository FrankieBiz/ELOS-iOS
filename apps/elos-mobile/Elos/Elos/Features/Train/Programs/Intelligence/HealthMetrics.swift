import Foundation

/// Pure, HealthKit-free logic + value types for the Apple Health integration, so the parts worth
/// testing don't depend on `HKHealthStore`. The thin `HealthKitService` consumes these.

/// Estimated active energy for a strength session (HealthKit workouts read better with an energy value).
enum HealthEnergy {
    /// Moderate-to-vigorous resistance training MET. Deliberately conservative.
    static let strengthMET = 5.0
    /// Fallback body weight (kg) when the real value is unknown, so we still produce an estimate.
    static let defaultWeightKg = 75.0

    /// kcal ≈ MET × weight(kg) × hours.
    static func estimateKcal(durationSec: Double, bodyWeightKg: Double) -> Double {
        let weight = bodyWeightKg > 0 ? bodyWeightKg : defaultWeightKg
        let hours = max(0, durationSec) / 3600
        return strengthMET * weight * hours
    }
}

/// Turns a resting-HR reading + the user's recent baseline into an optional, non-alarming recovery
/// nudge. Returns nil unless resting HR is meaningfully above baseline (we never auto-change the
/// readiness score — this is a hint only).
enum RecoveryHint {
    static let elevatedRatio = 1.10   // ~10% above baseline

    static func evaluate(restingHR: Double?, baseline: Double?) -> String? {
        guard let hr = restingHR, let base = baseline, base > 0, hr > base * elevatedRatio else {
            return nil
        }
        return "Resting heart rate is up vs your recent average — recovery may be down. Consider easing off today."
    }
}

/// Snapshot of the Health metrics Elos reads, held by `AppViewModel` and rendered by Today/readiness.
struct HealthSnapshot: Equatable {
    var bodyWeightKg: Double?
    var restingHeartRate: Double?
    var restingHRBaseline: Double?
    var steps: Int?

    /// Derived recovery hint (nil unless resting HR is elevated vs baseline).
    var recoveryHint: String? { RecoveryHint.evaluate(restingHR: restingHeartRate, baseline: restingHRBaseline) }

    /// True when there's at least one metric worth showing.
    var hasAnyMetric: Bool { bodyWeightKg != nil || restingHeartRate != nil || steps != nil }

    static let empty = HealthSnapshot()
}
