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

        // Resolve each exercise's targets through the same chain FatigueModel/TemplateQualityEngine use,
        // so partition membership never disagrees with the rest of the Intelligence layer. Membership
        // matches FatigueModel's own "shares a primary muscle" test — ANY primary, not just the first —
        // so a priority-sorted day can't introduce a new same-muscle inversion in the fixed FatigueModel
        // score. `ResolvedExercise.muscleGroup` (single, `.first`-only) is deliberately not used here:
        // a manually-overridden exercise can carry primaries spanning two different groups.
        let scored = exercises.map { ScoredExercise(day: $0) }
        let resolved = ExerciseResolver.resolve([scored], catalog: catalog).first ?? []

        var priorityGroup: [DayExercise] = []
        var rest: [DayExercise] = []
        for (exercise, resolvedExercise) in zip(exercises, resolved) {
            if resolvedExercise.targets.primary.contains(where: { $0.group == priority }) {
                priorityGroup.append(exercise)
            } else {
                rest.append(exercise)
            }
        }
        return sorted(priorityGroup) + sorted(rest)
    }
}
