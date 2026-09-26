import Foundation

/// Turns "how many sets" into "how many sets that actually did something".
///
/// Raw set counts treat set 1 and set 25 of a session as equal contributors. They aren't. Two things
/// the volume bars alone can't express:
///
/// 1. **Accumulated fatigue.** Stimulus per set falls as systemic fatigue builds within a session, so
///    the same 20 sets are worth more spread over two days than crammed into one.
/// 2. **Order.** A compound performed after the isolation work for the same muscle is done under a
///    pre-fatigued prime mover — you lift less for the same effort, and the compound is the movement
///    that most rewards being fresh.
///
/// Pure value types, no UI and no IO, so this is directly unit-testable — and it is the only place
/// that knows how fatigue is modelled.
enum FatigueModel {

    // MARK: Per-set quality

    /// Stimulus multiplier for a single set performed after `systemicLoadBefore` units of load,
    /// clamped to `fatigueQualityFloor`. Flat at 1.0 until `fatigueOnsetLoad`, then decays linearly.
    static func setQuality(systemicLoadBefore load: Double) -> Double {
        let excess = max(0, load - TrainingScience.fatigueOnsetLoad)
        let q = 1.0 - excess * TrainingScience.fatigueDecayPerLoad
        return min(1.0, max(TrainingScience.fatigueQualityFloor, q))
    }

    /// Systemic cost of one working set of this exercise.
    static func systemicCost(of r: ResolvedExercise) -> Double {
        r.isCompound ? TrainingScience.compoundSystemicCost : TrainingScience.isolationSystemicCost
    }

    // MARK: Effective volume

    /// One entry per exercise, in the order given: how many of its sets survive as effective volume.
    ///
    /// Walks set by set rather than exercise by exercise — an 8-set exercise straddling the fatigue
    /// onset should have its early sets counted at full value and only its later ones discounted.
    static func effectiveSets(day: [ResolvedExercise]) -> [Double] {
        var load = 0.0
        var out: [Double] = []
        out.reserveCapacity(day.count)

        for r in day {
            let cost = systemicCost(of: r)
            var effective = 0.0
            for _ in 0..<max(0, r.exercise.sets) {
                effective += setQuality(systemicLoadBefore: load)
                load += cost
            }
            out.append(effective)
        }
        return out
    }

    /// Total systemic load of a session — the "how taxing is this" number.
    static func systemicLoad(day: [ResolvedExercise]) -> Double {
        day.reduce(0) { $0 + systemicCost(of: $1) * Double(max(0, $1.exercise.sets)) }
    }

    // MARK: Order

    /// An isolation exercise placed before a compound: the compound pays for it.
    struct OrderInversion: Equatable {
        let isolationName: String
        let compoundName: String
    }

    struct OrderReport: Equatable {
        /// 0…1. 1.0 = every compound precedes every isolation.
        let quality: Double
        let inversions: [OrderInversion]

        static let perfect = OrderReport(quality: 1.0, inversions: [])
    }

    /// Compounds first, isolation after, among exercises that train the same muscle — an isolation
    /// exercise for a *different* muscle costs the compound nothing, so it was never really a same-day
    /// ordering problem. Scored as the fraction of same-muscle compound/isolation pairs that are in the
    /// right order, so one stray curl at the top of a long day is a small ding rather than a cliff, and
    /// a fully inverted same-muscle day scores 0.
    static func orderQuality(day: [ResolvedExercise]) -> OrderReport {
        let compoundIdx = day.indices.filter { day[$0].isCompound }
        let isolationIdx = day.indices.filter { !day[$0].isCompound }
        // Nothing to order: all one type, or fewer than two exercises.
        guard !compoundIdx.isEmpty, !isolationIdx.isEmpty else { return .perfect }

        var samePairs = 0
        var inversions: [OrderInversion] = []
        for c in compoundIdx {
            for i in isolationIdx {
                let iso = day[i], comp = day[c]
                let shared = !iso.targets.primary.isEmpty
                    && !comp.targets.primary.isEmpty
                    && !Set(iso.targets.primary).isDisjoint(with: Set(comp.targets.primary))
                guard shared else { continue }
                samePairs += 1
                if i < c {
                    inversions.append(OrderInversion(isolationName: iso.exercise.name,
                                                     compoundName: comp.exercise.name))
                }
            }
        }

        let quality = samePairs > 0
            ? 1.0 - Double(inversions.count) / Double(samePairs)
            : 1.0

        return OrderReport(quality: min(1, max(0, quality)), inversions: inversions)
    }

    // MARK: Whole-day summary

    struct DayFatigue: Equatable {
        let rawSets: Double
        let effectiveSets: Double
        let systemicLoad: Double
        let order: OrderReport

        /// What fraction of the volume on paper is real. 1.0 = nothing lost to fatigue.
        var efficiency: Double { rawSets > 0 ? effectiveSets / rawSets : 1.0 }
        /// Sets that exist in the plan but contribute little — the cost of the session's length.
        var setsLostToFatigue: Double { max(0, rawSets - effectiveSets) }
    }

    static func analyze(day: [ResolvedExercise]) -> DayFatigue {
        let raw = day.reduce(0.0) { $0 + Double(max(0, $1.exercise.sets)) }
        let effective = effectiveSets(day: day).reduce(0, +)
        return DayFatigue(rawSets: raw,
                          effectiveSets: effective,
                          systemicLoad: systemicLoad(day: day),
                          order: orderQuality(day: day))
    }
}
