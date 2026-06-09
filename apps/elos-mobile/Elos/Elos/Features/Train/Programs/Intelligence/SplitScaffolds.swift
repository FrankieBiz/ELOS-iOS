import Foundation

enum SplitScaffolds {
    static func recommend(archetype: SplitArchetype, catalog: [ExerciseCandidate],
                          personalization: PersonalizationProvider,
                          isEquipmentAvailable: @escaping (String) -> Bool,
                          count: Int = 5) -> [DayExercise] {
        let targets = MuscleTaxonomy.targetMuscles(forArchetype: archetype)
        let pool = catalog.filter { targets.contains(MuscleTaxonomy.normalize($0.primaryMuscle)) }
        let ctx = DayContext(dayName: archetype.rawValue, archetype: archetype, targetMuscles: targets,
                             addedPrimaryMuscles: [], addedExerciseIDs: [], addedExerciseNames: [])
        let ranked = ExerciseRankingEngine.rank(pool,
            inputs: RankingInputs(context: ctx, personalization: personalization,
                                  isEquipmentAvailable: isEquipmentAvailable, query: ""))

        var picks: [ExerciseCandidate] = []
        var coveredPrimaries = Set<String>()
        for c in ranked where picks.count < count {
            let p = MuscleTaxonomy.normalize(c.primaryMuscle)
            if !coveredPrimaries.contains(p) { picks.append(c); coveredPrimaries.insert(p) }
        }
        for c in ranked where picks.count < count {
            if !picks.contains(c) { picks.append(c) }
        }
        return picks.map { c in
            let def = SetRepDefaults.defaults(forMovementPattern: c.movementPattern)
            return DayExercise(id: c.id, name: c.name, sets: def.sets, reps: def.reps)
        }
    }
}
