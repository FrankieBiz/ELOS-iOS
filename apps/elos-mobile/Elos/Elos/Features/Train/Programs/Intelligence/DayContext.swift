import Foundation

struct DayContext: Equatable {
    let dayName: String
    let archetype: SplitArchetype?
    let targetMuscles: Set<String>     // normalized muscle strings
    let addedPrimaryMuscles: [String]  // normalized, includes duplicates for coverage counting
    let addedExerciseIDs: Set<String>
    let addedExerciseNames: Set<String> // normalized
    /// What each added exercise actually trains, fully resolved (lifter override → catalog → machine →
    /// name). Coverage counts these rather than re-deriving from the catalog, so machine-backed
    /// exercises — which have no catalog entry at all — still register.
    let addedTargets: [MuscleTargets]

    var hasFocus: Bool { !targetMuscles.isEmpty }

    static let empty = DayContext(dayName: "", archetype: nil, targetMuscles: [],
                                  addedPrimaryMuscles: [], addedExerciseIDs: [],
                                  addedExerciseNames: [], addedTargets: [])

    init(dayName: String, archetype: SplitArchetype?, targetMuscles: Set<String>,
         addedPrimaryMuscles: [String], addedExerciseIDs: Set<String>,
         addedExerciseNames: Set<String>, addedTargets: [MuscleTargets] = []) {
        self.dayName = dayName
        self.archetype = archetype
        self.targetMuscles = targetMuscles
        self.addedPrimaryMuscles = addedPrimaryMuscles
        self.addedExerciseIDs = addedExerciseIDs
        self.addedExerciseNames = addedExerciseNames
        self.addedTargets = addedTargets
    }
}

enum DayContextInferrer {
    static func infer(dayName: String, added: [DayExercise], catalog: [ExerciseCandidate]) -> DayContext {
        let archetype = MuscleTaxonomy.archetype(forDayName: dayName)
        var targets = archetype.map { MuscleTaxonomy.targetMuscles(forArchetype: $0) } ?? []

        // Resolve through the shared resolver so the equipment and name fallbacks apply here too.
        let resolved = ExerciseResolver.resolve([added.map(ScoredExercise.init(day:))],
                                               catalog: catalog).first ?? []

        var addedPrimaries: [String] = []
        var addedTargets: [MuscleTargets] = []
        for r in resolved {
            let t = r.targets
            addedTargets.append(t)
            guard !t.isEmpty else { continue }

            // When the catalog answered, use its own muscle strings verbatim. The ranking engine
            // compares these against `normalize(candidate.primaryMuscle)`, and round-tripping through
            // `FineMuscle` would rewrite them ("core" → "abs") and stop them matching.
            if r.exercise.muscleTargets == nil, let c = r.candidate {
                addedPrimaries.append(MuscleTaxonomy.normalize(c.primaryMuscle))
                targets.insert(MuscleTaxonomy.normalize(c.primaryMuscle))
                for s in c.secondaryMuscles { targets.insert(MuscleTaxonomy.normalize(s)) }
                continue
            }

            // Machine- or lifter-resolved: there is no catalog string, so translate the fine muscles
            // back into the vocabulary the ranking engine speaks.
            if let primary = t.primary.first,
               let vocab = MuscleTaxonomy.knownMuscles(forFine: primary).first {
                addedPrimaries.append(vocab)
            }
            for m in t.all {
                targets.formUnion(MuscleTaxonomy.knownMuscles(forFine: m))
            }
        }

        return DayContext(
            dayName: dayName,
            archetype: archetype,
            targetMuscles: targets,
            addedPrimaryMuscles: addedPrimaries,
            addedExerciseIDs: Set(added.map { $0.id }),
            addedExerciseNames: Set(added.map { MuscleTaxonomy.normalize($0.name) }),
            addedTargets: addedTargets
        )
    }
}
