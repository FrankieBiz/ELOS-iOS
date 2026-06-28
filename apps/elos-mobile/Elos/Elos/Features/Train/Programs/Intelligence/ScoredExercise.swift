import Foundation

/// Scope changes which landmark tables and balance rules the engine applies.
enum QualityScope {
    case singleSession   // one workout / template
    case weeklySplit     // a full week
}

/// The unified scoring input. Both `TemplateExerciseEntry` and `DayExercise` map into this so
/// the engine never depends on a specific builder's view model. `restSeconds` is nil when the
/// source doesn't capture rest (split days only store sets/reps).
struct ScoredExercise: Equatable {
    let id: String           // exercise-definition id ("" if unknown/custom)
    let name: String
    let sets: Int
    let repsText: String
    let restSeconds: Int?

    init(id: String, name: String, sets: Int, repsText: String, restSeconds: Int? = nil) {
        self.id = id
        self.name = name
        self.sets = sets
        self.repsText = repsText
        self.restSeconds = restSeconds
    }

    /// Adapter for split days (no rest captured).
    init(day d: DayExercise) {
        self.init(id: d.id, name: d.name, sets: d.sets, repsText: d.reps, restSeconds: nil)
    }
}

/// A `ScoredExercise` joined to its catalog metadata (muscle, movement pattern, compound-ness).
struct ResolvedExercise: Equatable {
    let exercise: ScoredExercise
    let candidate: ExerciseCandidate?

    var muscleGroup: MuscleGroup? {
        candidate.flatMap { MuscleTaxonomy.group(forMuscle: $0.primaryMuscle) }
    }
    var normalizedPrimary: String? {
        candidate.map { MuscleTaxonomy.normalize($0.primaryMuscle) }
    }
    var movementPattern: String? {
        candidate.map { $0.movementPattern.lowercased().trimmingCharacters(in: .whitespaces) }
    }
    var isCompound: Bool {
        candidate.map { MuscleTaxonomy.isCompound(movementPattern: $0.movementPattern) } ?? false
    }
}

/// Resolves the builder's exercises against the catalog by id first, then normalized name —
/// the same fallback the other Intelligence engines use.
enum ExerciseResolver {
    static func resolve(_ days: [[ScoredExercise]], catalog: [ExerciseCandidate]) -> [[ResolvedExercise]] {
        let byID = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        let byName = Dictionary(catalog.map { (MuscleTaxonomy.normalize($0.name), $0) },
                                uniquingKeysWith: { a, _ in a })
        return days.map { day in
            day.map { ex in
                let match = (ex.id.isEmpty ? nil : byID[ex.id]) ?? byName[MuscleTaxonomy.normalize(ex.name)]
                return ResolvedExercise(exercise: ex, candidate: match)
            }
        }
    }
}
