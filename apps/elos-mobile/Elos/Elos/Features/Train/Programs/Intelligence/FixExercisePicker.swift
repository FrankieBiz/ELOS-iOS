import Foundation

/// Headless top-N exercise pick for one specific day, for auto-fix inserts. Reuses
/// `ExerciseRankingEngine` (the same engine behind Smart Sort in the picker) rather than inventing
/// new ranking math — the only genuinely new logic here is the hard guarantees the engine alone
/// doesn't provide (duplicate/equipment are soft score penalties there, not filters) and the
/// primary-muscle-only constraint auto-fix needs for correctness.
enum FixExercisePicker {
    /// Everything needed to rank candidates for one specific day. Deliberately narrower than
    /// `QualityFixEngine.Context` — that struct describes the whole plan; this is what one day's
    /// ranking call needs. `QualityFixEngine` slices its own `Context` down to this shape after
    /// `FixDayChooser` has picked a day.
    struct Context {
        let catalog: [ExerciseCandidate]
        let dayName: String
        let addedDay: [ScoredExercise]
        let personalization: PersonalizationProvider
        let equipmentPreference: EquipmentPreference
    }

    /// - Parameter muscles: catalog-vocabulary strings (the output of
    ///   `MuscleTaxonomy.targetMuscles(forPayload:)`), not a raw tip payload.
    static func candidates(forMuscles muscles: [String], context: Context, limit: Int = 3) -> [ExerciseCandidate] {
        let targets = Set(muscles.map(MuscleTaxonomy.normalize))
        // Primary-muscle-only, not primary-or-secondary: bal-gap-*/bal-focusgap-* fire on DIRECT
        // sets being zero, so a secondary-only pick would not clear the tip it claims to fix.
        let pool = context.catalog.filter { targets.contains(MuscleTaxonomy.normalize($0.primaryMuscle)) }
        return rank(pool, targetMuscles: targets, context: context, limit: limit)
    }

    static func candidates(forPattern pattern: String, context: Context, limit: Int = 3) -> [ExerciseCandidate] {
        let normalizedPattern = MuscleTaxonomy.normalize(pattern)
        let pool = context.catalog.filter { MuscleTaxonomy.normalize($0.movementPattern) == normalizedPattern }
        return rank(pool, targetMuscles: [], context: context, limit: limit)
    }

    private static func rank(_ pool: [ExerciseCandidate], targetMuscles: Set<String>,
                             context: Context, limit: Int) -> [ExerciseCandidate] {
        let addedIDs = Set(context.addedDay.map(\.id).filter { !$0.isEmpty })
        let addedNames = Set(context.addedDay.map { MuscleTaxonomy.normalize($0.name) })

        // Hard duplicate filter — `ExerciseRankingEngine`'s own duplicate term is a −4.0 score
        // penalty, not a guarantee it won't win anyway.
        var filteredPool = pool.filter { !addedIDs.contains($0.id) && !addedNames.contains(MuscleTaxonomy.normalize($0.name)) }
        guard !filteredPool.isEmpty else { return [] }

        // Hard equipment filter, with a fallback to the unfiltered pool rather than dead-ending —
        // same reasoning: the engine's equipment term is a −2.0 penalty, not a filter, so without
        // this an unavailable-equipment exercise could still win outright.
        let equipmentFiltered = filteredPool.filter { context.equipmentPreference.isAvailable(equipment: $0.equipment) }
        if !equipmentFiltered.isEmpty { filteredPool = equipmentFiltered }

        // Build the DayContext the ranking engine needs, resolving `addedDay` directly rather than
        // round-tripping through `DayExercise` (which `DayContextInferrer.infer` expects but this
        // picker only has `ScoredExercise` for). Mirrors `DayContextInferrer`'s own resolution so
        // `addedPrimaryMuscles` is populated correctly — the bug `CreateTemplateView.openPicker`
        // has today (always empty), fixed here rather than reproduced.
        let resolvedDay = ExerciseResolver.resolve([context.addedDay], catalog: context.catalog).first ?? []
        var addedPrimaryMuscles: [String] = []
        var addedTargetsList: [MuscleTargets] = []
        for r in resolvedDay {
            let t = r.targets
            addedTargetsList.append(t)
            guard !t.isEmpty else { continue }
            if r.exercise.muscleTargets == nil, let c = r.candidate {
                addedPrimaryMuscles.append(MuscleTaxonomy.normalize(c.primaryMuscle))
            } else if let primary = t.primary.first,
                      let vocab = MuscleTaxonomy.knownMuscles(forFine: primary).first {
                addedPrimaryMuscles.append(vocab)
            }
        }

        let dayContext = DayContext(dayName: context.dayName, archetype: nil, targetMuscles: targetMuscles,
                                    addedPrimaryMuscles: addedPrimaryMuscles,
                                    addedExerciseIDs: addedIDs, addedExerciseNames: addedNames,
                                    addedTargets: addedTargetsList)
        let inputs = RankingInputs(context: dayContext, personalization: context.personalization,
                                   isEquipmentAvailable: { context.equipmentPreference.isAvailable(equipment: $0) })
        return Array(ExerciseRankingEngine.rank(filteredPool, inputs: inputs).prefix(limit))
    }
}
