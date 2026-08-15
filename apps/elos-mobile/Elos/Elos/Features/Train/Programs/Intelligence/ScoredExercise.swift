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
    // `var` (not `let`): auto-fix operations mutate these in a simulated copy of the plan before
    // re-scoring (`FixOperation.apply(to:)`) — this never touches builder state directly, only a
    // value-type copy, so mutability here doesn't weaken the "nothing persists before Save"
    // invariant the builders rely on.
    var sets: Int
    var repsText: String
    var restSeconds: Int?
    /// Set when the lifter picked a specific gym machine. Lets coverage fall back to the equipment
    /// database when `id` is an equipment id and therefore matches nothing in the exercise catalog.
    let equipmentId: String?
    /// The lifter's own answer to "what does this work", from the muscle check-off sheet. Outranks
    /// every guess.
    let muscleTargets: MuscleTargets?

    init(id: String, name: String, sets: Int, repsText: String, restSeconds: Int? = nil,
         equipmentId: String? = nil, muscleTargets: MuscleTargets? = nil) {
        self.id = id
        self.name = name
        self.sets = sets
        self.repsText = repsText
        self.restSeconds = restSeconds
        self.equipmentId = equipmentId
        self.muscleTargets = muscleTargets
    }

    /// Adapter for split days (no rest captured).
    init(day d: DayExercise) {
        self.init(id: d.id, name: d.name, sets: d.sets, repsText: d.reps, restSeconds: nil,
                  equipmentId: d.equipmentId, muscleTargets: d.muscleTargets)
    }
}

/// A `ScoredExercise` joined to its catalog metadata (muscle, movement pattern, compound-ness).
struct ResolvedExercise: Equatable {
    let exercise: ScoredExercise
    let candidate: ExerciseCandidate?

    /// **The** answer to "what does this exercise train" — resolved once here so the coverage bars, the
    /// quality score, and the picker chips can never disagree.
    ///
    /// Precedence, most to least authoritative:
    /// 1. What the lifter ticked in the muscle check-off sheet.
    /// 2. The exercise catalog, when the exercise is a catalog entry.
    /// 3. The gym machine's name and `bodyParts`, when they picked a machine directly.
    /// 4. The movement lexicon on the bare name, for custom exercises in neither.
    ///
    /// Before step 3 existed, picking a machine straight from the picker stored its *equipment* id as
    /// the exercise id, which matched no catalog entry and no catalog name — so a PRIME Low Back
    /// Extension resolved to nothing and reported zero lower-back volume.
    var targets: MuscleTargets {
        if let explicit = exercise.muscleTargets, !explicit.isEmpty { return explicit }
        if let c = candidate {
            let fromCatalog = MuscleTargets(primaryMuscle: c.primaryMuscle,
                                            secondaryMuscles: c.secondaryMuscles)
            if !fromCatalog.isEmpty { return fromCatalog }
        }
        if let equipmentId = exercise.equipmentId,
           let record = EquipmentDatabase.find(equipmentId: equipmentId),
           let fromEquipment = EquipmentMuscleMap.targets(for: record) {
            return fromEquipment
        }
        return MovementLexicon.targets(forExerciseName: exercise.name) ?? MuscleTargets()
    }

    /// Whether anything at all is known about what this trains. A `false` here is what the builder
    /// surfaces as "tap to set muscles" rather than silently crediting nothing.
    var hasKnownTargets: Bool { !targets.isEmpty }

    var muscleGroup: MuscleGroup? { targets.primary.first?.group }

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
