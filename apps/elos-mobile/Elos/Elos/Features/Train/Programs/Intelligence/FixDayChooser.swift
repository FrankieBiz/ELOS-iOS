import Foundation

/// Which day should receive an auto-fix insert. Replaces `firstOpenDayIndex()`'s "fewest
/// exercises" heuristic for automated fixes only — the manual exercise picker keeps its current
/// behavior. Today's heuristic has no awareness of day focus or day-scoped skips, so it can route
/// a hamstring fix to an arm day, or to a day the lifter explicitly excluded that muscle on.
enum FixDayChooser {
    /// - Parameters:
    ///   - muscles: catalog-vocabulary strings (the output of
    ///     `MuscleTaxonomy.targetMuscles(forPayload:)`), not raw tip payloads.
    ///   - intent: the split-wide intent; only `.focus` is read, since day focus at weekly scope
    ///     comes from `dayNames` when `.focus` is nil (matching `MuscleVolumeAnalyzer.expectedMuscles`'s
    ///     own resolution, so the chooser and the scorer never disagree about what a day is for).
    /// - Returns: the chosen day index and a one-line reason, or `nil` when no day is eligible.
    static func choose(forMuscles muscles: [String],
                       dayNames: [String],
                       dayIsRest: [Bool],
                       dayExercises: [[ScoredExercise]],
                       dayExcludedMuscles: [Set<FineMuscle>],
                       catalog: [ExerciseCandidate],
                       intent: TrainingIntent) -> (dayIndex: Int, reason: String)? {
        let targets = Set(muscles.compactMap { MuscleTaxonomy.fine(forMuscle: $0) })
        guard !targets.isEmpty else { return nil }

        // Hard vetoes: a rest day, or a day where every target muscle is explicitly skipped —
        // auto-adding a muscle the lifter told this day to skip is exactly the bug the day-scoped
        // skip feature exists to prevent.
        let eligible = dayExercises.indices.filter { i in
            // Bounds-safe like `dayExcludedMuscles` below: a caller passing a shorter `dayIsRest`
            // shouldn't crash, and reading it as "not rest" is the same safe default `isTrainingDay`
            // uses in TemplateQualityEngine.
            guard !(i < dayIsRest.count && dayIsRest[i]) else { return false }
            let excluded = i < dayExcludedMuscles.count ? dayExcludedMuscles[i] : []
            return !targets.allSatisfy { excluded.contains($0) }
        }
        guard !eligible.isEmpty else { return nil }

        func archetype(for i: Int) -> SplitArchetype? {
            intent.focus ?? MuscleTaxonomy.archetype(forDayName: dayNames[i])
        }
        func focusMatches(_ i: Int) -> Bool {
            guard let arch = archetype(for: i) else { return false }
            let archMuscles = Set(MuscleTaxonomy.targetMuscles(forArchetype: arch)
                .compactMap { MuscleTaxonomy.fine(forMuscle: $0) })
            return !archMuscles.isDisjoint(with: targets)
        }
        func directSets(for i: Int) -> Double {
            let resolved = ExerciseResolver.resolve([dayExercises[i]], catalog: catalog).first ?? []
            return resolved.reduce(0.0) { total, r in
                let hits = targets.contains { r.targets.primary.contains($0) }
                return total + (hits ? Double(r.exercise.sets) : 0)
            }
        }
        // +3.0 for a focus match dwarfs the volume/count terms (each bounded well under 3 for any
        // realistic day), so a focus match always wins over a merely-emptier non-matching day —
        // the exact regression ("hamstring fix lands on the arm day") this chooser exists to fix.
        func score(_ i: Int) -> Double {
            var s = 0.0
            if focusMatches(i) { s += 3.0 }
            s -= 0.5 * directSets(for: i)
            s -= 0.2 * Double(dayExercises[i].count)
            return s
        }

        // Iterate in ascending index order and only replace on a STRICTLY greater score, so the
        // lowest-index day wins any tie — a deterministic tiebreak Swift's own `sorted`/`max(by:)`
        // wouldn't guarantee, and this repo has already shipped one reproducibility bug from that
        // exact gap (the equipment bodyParts tie-break).
        var bestIndex = eligible[0]
        var bestScore = score(bestIndex)
        for i in eligible.dropFirst() {
            let s = score(i)
            if s > bestScore { bestIndex = i; bestScore = s }
        }

        let reason = focusMatches(bestIndex)
            ? "already trains this, and has the least volume there among your built days"
            : "has room for another exercise"
        return (dayIndex: bestIndex, reason: reason)
    }
}
