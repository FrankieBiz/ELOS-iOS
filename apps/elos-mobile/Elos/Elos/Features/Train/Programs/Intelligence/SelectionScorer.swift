import Foundation

/// Scores exercise selection & ordering: enough big compounds, a hinge when legs are trained,
/// and compounds sequenced before isolations (per day) while the lifter is fresh.
enum SelectionScorer {
    static func score(resolvedDays: [[ResolvedExercise]],
                      scope: QualityScope,
                      profile: TrainingProfile,
                      movement: MovementProfile) -> DimensionScore {
        let known = resolvedDays.flatMap { $0 }.filter { $0.candidate != nil }
        guard !known.isEmpty else {
            return DimensionScore(dimension: .selection, score: 70, tips: [])
        }

        var tips: [QualityTip] = []
        var penalties = 0.0

        // Compound fraction, read from the shared analyzer rather than recomputed here.
        // Deliberately the *by-count* fraction: `minCompoundFraction` was tuned against exercise
        // counts, and switching to the by-sets fraction would silently retune a shipped score.
        // (The by-sets figure is what the stacked bar renders — see `MovementProfile`.)
        let fraction = movement.compoundFractionByCount
        let minFraction = TrainingScience.minCompoundFraction(for: profile.experience)
        if fraction < minFraction {
            penalties += 0.25
            tips.append(QualityTip(
                id: "sel-compound", dimension: .selection, severity: .info,
                message: "Only \(Int((fraction * 100).rounded()))% of these are big compounds. Anchor each day with a squat, hinge, press, or row — they build the most muscle per set.",
                action: .noAction))
        }

        // Hinge presence when legs/glutes are trained
        let patterns = Set(known.compactMap { $0.movementPattern })
        let trainsLowerBody = known.contains { $0.muscleGroup == .legs || $0.muscleGroup == .glutes }
        if trainsLowerBody && patterns.contains("squat") && !patterns.contains("hinge") {
            penalties += 0.12
            tips.append(QualityTip(
                id: "sel-hinge", dimension: .selection, severity: .info,
                message: "You squat but there's no hinge — add a deadlift, RDL, or hip thrust to train the hamstrings and glutes squats miss.",
                action: .addPattern("hinge")))
        }

        // Order: a heavy isolation before a compound, per day. The tip carries the day index so the
        // split builder knows which day to reorder — at weekly scope there's no implicit "the day".
        for (dayIndex, day) in resolvedDays.enumerated() where day.count > 1 {
            if let isoIndex = isolationBeforeCompound(day) {
                penalties += 0.10
                let isoName = day[isoIndex].exercise.name
                tips.append(QualityTip(
                    id: "sel-order", dimension: .selection, severity: .info,
                    message: "Lead with compounds — \(isoName) comes before a bigger lift. Save isolations for after the heavy work.",
                    action: .reorder(dayIndex: dayIndex)))
                break
            }
        }

        let score = max(0, min(100, Int(((1.0 - penalties) * 100).rounded())))
        return DimensionScore(dimension: .selection, score: score, tips: tips)
    }

    /// Index of the first isolation that appears before a later compound, or nil if ordered well.
    private static func isolationBeforeCompound(_ day: [ResolvedExercise]) -> Int? {
        var firstIsolation: Int? = nil
        for (i, r) in day.enumerated() {
            guard r.candidate != nil else { continue }
            if !r.isCompound, firstIsolation == nil { firstIsolation = i }
            if r.isCompound, let iso = firstIsolation { return iso }
        }
        return nil
    }
}
