import Foundation

struct DayContext: Equatable {
    let dayName: String
    let archetype: SplitArchetype?
    let targetMuscles: Set<String>     // normalized muscle strings
    let addedPrimaryMuscles: [String]  // normalized, includes duplicates for coverage counting
    let addedExerciseIDs: Set<String>
    let addedExerciseNames: Set<String> // normalized

    var hasFocus: Bool { !targetMuscles.isEmpty }

    static let empty = DayContext(dayName: "", archetype: nil, targetMuscles: [],
                                  addedPrimaryMuscles: [], addedExerciseIDs: [], addedExerciseNames: [])
}

enum DayContextInferrer {
    static func infer(dayName: String, added: [DayExercise], catalog: [ExerciseCandidate]) -> DayContext {
        let archetype = MuscleTaxonomy.archetype(forDayName: dayName)
        var targets = archetype.map { MuscleTaxonomy.targetMuscles(forArchetype: $0) } ?? []

        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byName = Dictionary(catalog.map { (MuscleTaxonomy.normalize($0.name), $0) }, uniquingKeysWith: { a, _ in a })
        var addedPrimaries: [String] = []
        for ex in added {
            let match = byID[ex.id] ?? byName[MuscleTaxonomy.normalize(ex.name)]
            guard let c = match else { continue }
            let primary = MuscleTaxonomy.normalize(c.primaryMuscle)
            addedPrimaries.append(primary)
            targets.insert(primary)
            for s in c.secondaryMuscles { targets.insert(MuscleTaxonomy.normalize(s)) }
        }

        return DayContext(
            dayName: dayName,
            archetype: archetype,
            targetMuscles: targets,
            addedPrimaryMuscles: addedPrimaries,
            addedExerciseIDs: Set(added.map { $0.id }),
            addedExerciseNames: Set(added.map { MuscleTaxonomy.normalize($0.name) })
        )
    }
}
