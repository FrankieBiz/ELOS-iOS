import Foundation

/// Pure volume math, kept free of SwiftData so it's unit-testable. `WorkoutSessionRecord.totalVolume`
/// is maintained by incremental deltas during a session (fine for live display), but at finish time
/// it's recomputed from the actual logged sets via this helper so a dropped set-sync can't ship a
/// wrong total to the server.
enum SyncMath {
    /// Volume contribution of one set (kg·reps). Negative reps clamp to zero.
    static func setVolume(weightKg: Double, reps: Int) -> Double {
        weightKg * Double(max(reps, 0))
    }

    /// Authoritative session volume = sum over the done sets.
    static func totalVolume(_ sets: [(weightKg: Double, reps: Int)]) -> Double {
        sets.reduce(0) { $0 + setVolume(weightKg: $1.weightKg, reps: $1.reps) }
    }
}
