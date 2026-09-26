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

    // MARK: Auto-fix

    /// Cap on how many sets a single auto-added exercise can carry, even when the shortfall to a
    /// muscle's weekly minimum is larger. An honest partial fix with a caveat beats silently
    /// inflating one exercise to an unrealistic set count.
    static let maxAutoFixSetsPerExercise = 5

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

        /// Same numbers, forced optional — used when a muscle is explicitly excluded. Deliberately
        /// does not zero the targets: `isOptional` is what every consumer (`VolumeScorer`,
        /// `FrequencyScorer`, the coverage bars) actually branches on to skip grading/nagging, and
        /// keeping real numbers avoids a divide-by-zero in the bars' fill-percentage math if the
        /// muscle still receives incidental indirect credit from another exercise.
        var asOptional: VolumeBand {
            VolumeBand(mev: mev, targetLow: targetLow, targetHigh: targetHigh, mrv: mrv, isOptional: true)
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

    // MARK: - Bands, override-aware
    //
    // `profile` carries the lifter's overrides, so these stay pure functions of their inputs and
    // remain unit-testable — nothing here reads UserDefaults.

    static func weeklyBand(for m: FineMuscle, profile: TrainingProfile) -> VolumeBand {
        let band = derivedWeeklyBand(for: m, profile: profile)
        // An explicit exclusion always wins, even over a numeric group target left over from before
        // the muscle was excluded — the UI (`VolumeTargetsView`) keeps the two mutually exclusive,
        // but the engine doesn't rely on that alone.
        return profile.volumeOverrides.excludedMuscles.contains(m) ? band.asOptional : band
    }

    private static func derivedWeeklyBand(for m: FineMuscle, profile: TrainingProfile) -> VolumeBand {
        let o = profile.volumeOverrides

        // An explicit per-group weekly target is the lifter's own number and replaces the derived
        // one outright — experience and preference already had their say when they chose it.
        // The group's requested total is distributed across its children in the same proportion the
        // science table uses, so "18 sets for Back" doesn't hand lats and lower back equal shares.
        if let requested = o.groupWeeklyTarget[m.group.rawValue], requested > 0 {
            let baseGroupLow = m.group.children.reduce(0.0) { $0 + baseWeeklyBand($1).targetLow }
            if baseGroupLow > 0 {
                return baseWeeklyBand(m).scaled(Double(requested) / baseGroupLow)
            }
        }
        return baseWeeklyBand(m).scaled(experienceScale(profile.experience) * o.preference.scale)
    }

    /// For call sites that only know an experience level and have no overrides to hand (the logged-
    /// volume analyzer, the Train tab's target chips). Prefer the `profile:` form wherever a profile
    /// exists, so the lifter's overrides actually apply.
    static func weeklyBand(for m: FineMuscle, experience: TrainingExperienceLevel) -> VolumeBand {
        weeklyBand(for: m, profile: TrainingProfile(goal: .hypertrophy, experience: experience))
    }

    /// Within a *single* session the question isn't weekly adequacy but per-session dosing: enough to
    /// be a real stimulus, not so much that the last sets are junk.
    ///
    /// Derived from the weekly band rather than a flat constant. It used to be uniform — 4–10 sets for
    /// every muscle — which said a chest day and a calf day want the same dose. They don't: chest is a
    /// 14–20 sets/week muscle and lower back is 8–14, so spreading each over `targetWeeklyFrequency`
    /// sessions gives 7–10 and 4–7 respectively. One table, one place to tune, and the per-session
    /// number can never drift from the weekly one it's supposed to add up to.
    static func sessionBand(for m: FineMuscle, profile: TrainingProfile) -> VolumeBand {
        let weekly = weeklyBand(for: m, profile: profile)
        let freq = Double(max(1, targetWeeklyFrequency))

        let low  = max(Double(sessionPerMuscleFloor), (weekly.targetLow / freq).rounded())
        let high = max(low + 1, (weekly.targetHigh / freq).rounded())
        // Past this, extra sets in one sitting stop paying for themselves regardless of the muscle.
        let junk = min(Double(sessionJunkThreshold), max(high + 1, (weekly.mrv / freq).rounded() + 2))

        // `mev` stays 0: no single workout is obliged to train any particular muscle.
        // `isOptional` is propagated so prehab muscles (rotator cuff, forearms) aren't graded as a
        // per-session volume gap either — previously every session band was non-optional, so a
        // template with two rotator-cuff sets was marked "below minimum".
        return VolumeBand(mev: 0, targetLow: low, targetHigh: high, mrv: junk,
                          isOptional: weekly.isOptional)
    }

    /// Smallest per-session dose worth calling a real stimulus for a muscle.
    static let sessionPerMuscleFloor = 2

    // MARK: - Frequency

    /// Training a muscle twice a week beats once at matched weekly volume — the best-supported
    /// frequency finding, and the main thing a sets-per-week number can't tell you.
    static let targetWeeklyFrequency = 2

    // MARK: - Fatigue & exercise order
    //
    // Raw set counts treat set 1 and set 25 of a session as equal. They aren't: stimulus per set
    // falls as systemic fatigue accumulates, and a compound taxes the whole system more than a curl.
    // These turn "how many sets" into "how many sets that actually did something", and let the engine
    // say *why* a long session scores worse than a short one with the same volume.

    /// Systemic cost of one working set. A compound recruits far more musculature, so it fatigues the
    /// lifter — not just the target muscle — considerably more.
    static let compoundSystemicCost: Double  = 1.6
    static let isolationSystemicCost: Double = 1.0

    /// Accumulated systemic load a lifter absorbs before stimulus per set starts falling off.
    /// Roughly the first 7–8 compound sets, or 12 isolation sets, of a session.
    static let fatigueOnsetLoad: Double = 12

    /// Quality lost per unit of systemic load past onset.
    static let fatigueDecayPerLoad: Double = 0.02

    /// Floor on per-set quality. Even deep in a long session a set is not worthless.
    static let fatigueQualityFloor: Double = 0.6

    /// Below this fraction of raw volume surviving as effective volume, the session is long enough
    /// that trimming or splitting it is the highest-value change available.
    static let minVolumeEfficiency: Double = 0.85

    // MARK: - Citations
    //
    // Real, named sources — the point of showing "cited studies" to a lifter is that the citation is
    // checkable. Kept to 2–3 shared references rather than one per muscle group, because the
    // literature reports these findings per *muscle group*, not per fine muscle — inventing 16
    // fine-muscle-specific studies would be dishonest, not more rigorous.
    static let citations: [ResearchCitation] = [
        .init(authors: "Schoenfeld, Grgic & Krieger", year: 2017,
              title: "Dose-response relationship between weekly resistance training volume and increases in muscle mass",
              finding: "More weekly sets per muscle (up to roughly 20) reliably produced more muscle growth across the studies reviewed."),
        .init(authors: "Schoenfeld, Grgic & Krieger", year: 2019,
              title: "How many times per week should a muscle be trained to maximize muscle hypertrophy?",
              finding: "Spreading the same weekly volume across two or more sessions tended to build more muscle than cramming it into one."),
        .init(authors: "Israetel & Renaissance Periodization", year: 2019,
              title: "The Renaissance Periodization volume-landmarks framework (MEV / MAV / MRV)",
              finding: "Frames a productive training range between a minimum that's worth doing and a maximum you can still recover from."),
    ]
}

/// One cited source behind the volume recommendations, shown in `VolumeTargetsView`.
struct ResearchCitation: Equatable {
    let authors: String
    let year: Int
    let title: String
    /// One plain-English sentence — what the source actually found, not academic phrasing.
    let finding: String
}
