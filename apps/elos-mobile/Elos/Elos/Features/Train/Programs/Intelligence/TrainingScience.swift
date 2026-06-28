import Foundation

/// Evidence-based training targets, all in one place so they can be reviewed and tuned.
/// Numbers reflect commonly-cited hypertrophy/strength literature (volume landmarks à la
/// Israetel/RP; rep & rest ranges by goal). These are deliberately conservative defaults.
enum TrainingScience {

    // MARK: Rep ranges (reps per working set), by goal

    struct IntRange: Equatable {
        let low: Int
        let high: Int
        func overlaps(_ other: ClosedRange<Int>) -> Bool {
            low <= other.upperBound && other.lowerBound <= high
        }
    }

    static func repRange(for goal: LiftingGoal) -> IntRange {
        switch goal {
        case .strength:    return IntRange(low: 3,  high: 6)
        case .hypertrophy: return IntRange(low: 6,  high: 12)
        case .endurance:   return IntRange(low: 15, high: 25)
        case .weightLoss:  return IntRange(low: 8,  high: 15)
        }
    }

    // MARK: Rest between sets (seconds), by goal — sized for compound lifts

    static func restRange(for goal: LiftingGoal) -> IntRange {
        switch goal {
        case .strength:    return IntRange(low: 180, high: 300)
        case .hypertrophy: return IntRange(low: 90,  high: 180)
        case .endurance:   return IntRange(low: 30,  high: 60)
        case .weightLoss:  return IntRange(low: 45,  high: 90)
        }
    }

    // MARK: Weekly volume landmarks (sets per muscle group per week), by experience
    // MEV = minimum effective volume; target band = productive range; MRV = maximum recoverable.

    struct VolumeLandmarks: Equatable {
        let mev: Int
        let targetLow: Int
        let targetHigh: Int
        let mrv: Int
    }

    static func weeklyVolume(for experience: TrainingExperienceLevel) -> VolumeLandmarks {
        switch experience {
        case .beginner:     return VolumeLandmarks(mev: 6,  targetLow: 10, targetHigh: 14, mrv: 18)
        case .intermediate: return VolumeLandmarks(mev: 8,  targetLow: 12, targetHigh: 18, mrv: 20)
        case .advanced:     return VolumeLandmarks(mev: 10, targetLow: 16, targetHigh: 20, mrv: 22)
        }
    }

    // MARK: Per-session dosing (sets per muscle within a single workout)

    static let sessionTargetLow  = 4    // a muscle worked as a real focus
    static let sessionTargetHigh = 10   // top of the per-session productive range
    static let sessionJunkThreshold = 12 // beyond this in one session, returns drop off
    static let sessionTotalLow   = 9    // total working sets — very short below this
    static let sessionTotalHigh  = 30   // total working sets — too long above this

    // MARK: Balance

    static let pushPullRatioLimit  = 1.5
    static let antagonistRatioLimit = 2.0

    // MARK: Selection

    static func minCompoundFraction(for experience: TrainingExperienceLevel) -> Double {
        switch experience {
        case .beginner:     return 0.5
        case .intermediate: return 0.4
        case .advanced:     return 0.33
        }
    }
}
