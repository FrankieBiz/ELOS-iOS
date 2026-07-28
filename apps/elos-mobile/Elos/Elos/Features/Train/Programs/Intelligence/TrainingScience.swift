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

    // MARK: - Fractional volume

    /// A set that trains a muscle *secondarily* counts as half a set toward that muscle
    /// (the standard fractional-volume convention). Bench press = 1.0 chest + 0.5 triceps per set.
    /// This is why volume is `Double` throughout the bar layer.
    static let secondaryCredit: Double = 0.5

    // MARK: - Per-fine-muscle volume bands
    //
    // Weekly sets per muscle. Defined at the `FineMuscle` level because that's the level the
    // literature defines them at, and because a `Legs` aggregate hides "hamstrings: 0".
    //
    // IMPORTANT: these are calibrated for FRACTIONAL counting (primary 1.0 + secondary 0.5), so they
    // sit above the direct-sets-only numbers usually quoted. Don't compare them to a table that
    // counts primary sets only.
    //
    struct VolumeBand: Equatable {
        let mev: Double        // minimum effective volume
        let targetLow: Double  // bottom of the productive band
        let targetHigh: Double // top of the productive band
        let mrv: Double        // maximum recoverable volume

        /// Optional muscles are excluded from "every muscle covered" checks and never emit a
        /// low-volume warning — they're prehab/indirect work (rotator cuff, forearms), not a gap.
        ///
        /// Explicit rather than inferred from `mev == 0`: *every* per-session band has an MEV of 0,
        /// because no single workout is obliged to train any given muscle. Deriving the flag made
        /// all session bands look optional and silently emptied session volume scoring.
        let isOptional: Bool

        init(mev: Double, targetLow: Double, targetHigh: Double, mrv: Double,
             isOptional: Bool = false) {
            self.mev = mev
            self.targetLow = targetLow
            self.targetHigh = targetHigh
            self.mrv = mrv
            self.isOptional = isOptional
        }

        func scaled(_ f: Double) -> VolumeBand {
            VolumeBand(mev: (mev * f).rounded(), targetLow: (targetLow * f).rounded(),
                       targetHigh: (targetHigh * f).rounded(), mrv: (mrv * f).rounded(),
                       isOptional: isOptional)
        }
    }

    /// Base weekly band at `.intermediate`.
    private static func baseWeeklyBand(_ m: FineMuscle) -> VolumeBand {
        switch m {
        case .chest:       return VolumeBand(mev: 8, targetLow: 14, targetHigh: 20, mrv: 26)
        case .lats:        return VolumeBand(mev: 8, targetLow: 14, targetHigh: 20, mrv: 26)
        case .upperBack:   return VolumeBand(mev: 8, targetLow: 14, targetHigh: 20, mrv: 28)
        case .lowerBack:   return VolumeBand(mev: 4, targetLow: 8,  targetHigh: 14, mrv: 20)
        case .rearDelts:   return VolumeBand(mev: 4, targetLow: 8,  targetHigh: 14, mrv: 20)
        case .frontDelts:  return VolumeBand(mev: 6, targetLow: 10, targetHigh: 16, mrv: 24)
        case .sideDelts:   return VolumeBand(mev: 6, targetLow: 10, targetHigh: 16, mrv: 24)
        case .rotatorCuff: return VolumeBand(mev: 0, targetLow: 2,  targetHigh: 6,  mrv: 12, isOptional: true)
        case .biceps:      return VolumeBand(mev: 8, targetLow: 12, targetHigh: 18, mrv: 24)
        case .triceps:     return VolumeBand(mev: 8, targetLow: 12, targetHigh: 18, mrv: 24)
        case .forearms:    return VolumeBand(mev: 0, targetLow: 2,  targetHigh: 8,  mrv: 14, isOptional: true)
        case .quads:       return VolumeBand(mev: 8, targetLow: 12, targetHigh: 18, mrv: 24)
        case .hamstrings:  return VolumeBand(mev: 6, targetLow: 10, targetHigh: 16, mrv: 22)
        case .calves:      return VolumeBand(mev: 6, targetLow: 10, targetHigh: 16, mrv: 22)
        case .glutes:      return VolumeBand(mev: 6, targetLow: 10, targetHigh: 16, mrv: 22)
        case .abs:         return VolumeBand(mev: 4, targetLow: 8,  targetHigh: 14, mrv: 20)
        }
    }

    /// Beginners grow on less and recover from less; advanced lifters need more to progress.
    static func experienceScale(_ e: TrainingExperienceLevel) -> Double {
        switch e {
        case .beginner:     return 0.75
        case .intermediate: return 1.0
        case .advanced:     return 1.15
        }
    }

    static func weeklyBand(for m: FineMuscle, experience: TrainingExperienceLevel) -> VolumeBand {
        baseWeeklyBand(m).scaled(experienceScale(experience))
    }

    /// Within a *single* session, the question isn't weekly adequacy but per-session dosing: enough
    /// to be a real stimulus, not so much that the last sets are junk. Uniform across muscles —
    /// `mev` is 0 because no single workout is obliged to train any particular muscle.
    static func sessionBand(for m: FineMuscle) -> VolumeBand {
        VolumeBand(mev: 0,
                   targetLow: Double(sessionTargetLow),
                   targetHigh: Double(sessionTargetHigh),
                   mrv: Double(sessionJunkThreshold))
    }

    // MARK: - Frequency

    /// Training a muscle twice a week beats once at matched weekly volume — the best-supported
    /// frequency finding, and the main thing a sets-per-week number can't tell you.
    static let targetWeeklyFrequency = 2
}
