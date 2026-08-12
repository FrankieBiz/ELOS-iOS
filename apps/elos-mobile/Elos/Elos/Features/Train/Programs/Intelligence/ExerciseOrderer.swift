import Foundation

enum ExerciseOrderer {
    static func order(_ exercises: [DayExercise], catalog: [ExerciseCandidate],
                       priority: MuscleGroup? = nil) -> [DayExercise] {
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byName = Dictionary(catalog.map { (MuscleTaxonomy.normalize($0.name), $0) }, uniquingKeysWith: { a, _ in a })
        func rank(_ ex: DayExercise) -> Int {
            let c = byID[ex.id] ?? byName[MuscleTaxonomy.normalize(ex.name)]
            guard let c else { return 2 }
            return MuscleTaxonomy.isCompound(movementPattern: c.movementPattern) ? 0 : 1
        }
        func sorted(_ items: [DayExercise]) -> [DayExercise] {
            items.enumerated()
                .sorted { a, b in
                    let ra = rank(a.element), rb = rank(b.element)
                    return ra == rb ? a.offset < b.offset : ra < rb
                }
                .map { $0.element }
        }
        guard let priority else { return sorted(exercises) }

        // Resolve each exercise's muscle group through the same chain FatigueModel/TemplateQualityEngine
        // use, so "which group is this for" never disagrees with the rest of the Intelligence layer.
        let scored = exercises.map { ScoredExercise(day: $0) }
        let resolved = ExerciseResolver.resolve([scored], catalog: catalog).first ?? []

        var priorityGroup: [DayExercise] = []
        var rest: [DayExercise] = []
        for (exercise, resolvedExercise) in zip(exercises, resolved) {
            if resolvedExercise.muscleGroup == priority {
                priorityGroup.append(exercise)
            } else {
                rest.append(exercise)
            }
        }
        return sorted(priorityGroup) + sorted(rest)
    }
}
