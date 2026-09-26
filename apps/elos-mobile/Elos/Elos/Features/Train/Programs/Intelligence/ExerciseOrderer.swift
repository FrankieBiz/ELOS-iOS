import Foundation

enum ExerciseOrderer {
    static func order(_ exercises: [DayExercise], catalog: [ExerciseCandidate],
                       priority: MuscleGroup? = nil) -> [DayExercise] {
        orderedIndices(exercises, catalog: catalog, priority: priority).map { exercises[$0] }
    }

    /// Same partition-then-sort as `order`, but returns the permutation of **original indices**
    /// rather than rearranged values. This is what an auto-fix reorder operation needs: a template
    /// exercise with no catalog match resolves to `ScoredExercise(id: "")`, so two such rows on one
    /// day are indistinguishable by id, and an id-keyed reorder can't reproduce the intended
    /// ordering — the same name/identity trap this codebase keeps re-discovering. A permutation of
    /// indices has no such ambiguity.
    static func orderedIndices(_ exercises: [DayExercise], catalog: [ExerciseCandidate],
                               priority: MuscleGroup? = nil) -> [Int] {
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byName = Dictionary(catalog.map { (MuscleTaxonomy.normalize($0.name), $0) }, uniquingKeysWith: { a, _ in a })
        func rank(_ ex: DayExercise) -> Int {
            let c = byID[ex.id] ?? byName[MuscleTaxonomy.normalize(ex.name)]
            guard let c else { return 2 }
            return MuscleTaxonomy.isCompound(movementPattern: c.movementPattern) ? 0 : 1
        }
        // Sorts a set of ORIGINAL indices by rank, tie-breaking on the index itself rather than a
        // re-enumerated local offset — so ties keep their original relative order regardless of
        // whether the whole array or one partition subset is being sorted here.
        func sortedIndices(_ indices: [Int]) -> [Int] {
            indices.sorted { a, b in
                let ra = rank(exercises[a]), rb = rank(exercises[b])
                return ra == rb ? a < b : ra < rb
            }
        }
        guard let priority else { return sortedIndices(Array(exercises.indices)) }

        // Resolve each exercise's targets through the same chain FatigueModel/TemplateQualityEngine use,
        // so partition membership never disagrees with the rest of the Intelligence layer. Membership
        // matches FatigueModel's own "shares a primary muscle" test — ANY primary, not just the first —
        // so a priority-sorted day can't introduce a new same-muscle inversion in the fixed FatigueModel
        // score. `ResolvedExercise.muscleGroup` (single, `.first`-only) is deliberately not used here:
        // a manually-overridden exercise can carry primaries spanning two different groups.
        let scored = exercises.map { ScoredExercise(day: $0) }
        let resolved = ExerciseResolver.resolve([scored], catalog: catalog).first ?? []

        var priorityIndices: [Int] = []
        var restIndices: [Int] = []
        for i in exercises.indices {
            let resolvedExercise = resolved[i]
            if resolvedExercise.targets.primary.contains(where: { $0.group == priority }) {
                priorityIndices.append(i)
            } else {
                restIndices.append(i)
            }
        }
        return sortedIndices(priorityIndices) + sortedIndices(restIndices)
    }
}
