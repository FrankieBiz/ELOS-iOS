import Foundation

/// What one exercise-in-a-workout actually trains, at `FineMuscle` resolution.
///
/// This exists because "what does this movement work?" has three possible answers of decreasing
/// authority — the lifter's own choice, the exercise catalog, and the machine's spec sheet — and the
/// coverage display needs exactly one. `MuscleTargets` is that one answer, resolved once by
/// `ResolvedExercise.targets` and read by everything downstream.
///
/// `primary` earns full set credit, `secondary` earns `TrainingScience.secondaryCredit`. A muscle
/// listed in both is primary — direct work supersedes indirect.
struct MuscleTargets: Equatable, Codable, Hashable {
    var primary: [FineMuscle]
    var secondary: [FineMuscle]

    init(primary: [FineMuscle] = [], secondary: [FineMuscle] = []) {
        // Dedupe while preserving order, and never let a muscle sit in both lists.
        let p = MuscleTargets.deduped(primary)
        self.primary = p
        self.secondary = MuscleTargets.deduped(secondary).filter { !p.contains($0) }
    }

    var isEmpty: Bool { primary.isEmpty && secondary.isEmpty }

    /// Every muscle this touches, primaries first.
    var all: [FineMuscle] { primary + secondary }

    /// The broad groups involved, in `MuscleGroup.allCases` order. Used to decide whether a machine
    /// is ambiguous enough to ask the lifter about (chest *and* rear delts = worth asking).
    var groups: [MuscleGroup] {
        let hit = Set(all.map(\.group))
        return MuscleGroup.allCases.filter { hit.contains($0) }
    }

    /// "Lower back, Glutes" — the subtitle shown on an exercise row.
    var summary: String {
        primary.isEmpty
            ? secondary.map(\.displayName).joined(separator: ", ")
            : primary.map(\.displayName).joined(separator: ", ")
    }

    func togglingPrimary(_ m: FineMuscle) -> MuscleTargets {
        primary.contains(m)
            ? MuscleTargets(primary: primary.filter { $0 != m }, secondary: secondary)
            : MuscleTargets(primary: primary + [m], secondary: secondary)
    }

    func togglingSecondary(_ m: FineMuscle) -> MuscleTargets {
        secondary.contains(m)
            ? MuscleTargets(primary: primary, secondary: secondary.filter { $0 != m })
            : MuscleTargets(primary: primary.filter { $0 != m }, secondary: secondary + [m])
    }

    private static func deduped(_ xs: [FineMuscle]) -> [FineMuscle] {
        var seen: Set<FineMuscle> = []
        return xs.filter { seen.insert($0).inserted }
    }

    // MARK: Persistence
    //
    // Stored as a JSON string so this rides along inside existing local-only columns
    // (`TemplateExerciseRecord.muscleTargetsJSON`) and inside the split's opaque `exercisesJSON`,
    // with no backend contract change — the same trick `WorkoutTemplateRecord.intentJSON` uses.

    var jsonString: String {
        guard !isEmpty, let d = try? JSONEncoder().encode(self) else { return "" }
        return String(decoding: d, as: UTF8.self)
    }

    init?(jsonString: String) {
        guard !jsonString.isEmpty,
              let t = try? JSONDecoder().decode(MuscleTargets.self, from: Data(jsonString.utf8)),
              !t.isEmpty
        else { return nil }
        self = t
    }

    /// Build from the raw muscle strings the catalog uses. Strings outside the known vocabulary are
    /// dropped rather than guessed at.
    init(primaryMuscle: String, secondaryMuscles: [String]) {
        self.init(primary: [MuscleTaxonomy.fine(forMuscle: primaryMuscle)].compactMap { $0 },
                  secondary: secondaryMuscles.compactMap { MuscleTaxonomy.fine(forMuscle: $0) })
    }

    // MARK: Back to catalog vocabulary
    //
    // `Exercise`, `ExerciseSetRecord`, and the stats screens all speak the catalog's muscle strings
    // ("lower back"), not `FineMuscle` raw values ("lowerBack"). Translating rather than leaking the
    // raw values keeps `String.muscleDisplayName` and every existing muscle-keyed dictionary working.

    /// The catalog key for the first direct muscle, e.g. `.lowerBack` → `"lower_back"` — the same
    /// snake_case form `ExerciseDefinitionRecord.primaryMuscle` uses, so these are interchangeable.
    var catalogPrimary: String? {
        primary.first.flatMap { MuscleTaxonomy.vocabularyKey(forFine: $0) }
    }

    var catalogSecondaries: [String] {
        (primary.dropFirst() + secondary).compactMap { MuscleTaxonomy.vocabularyKey(forFine: $0) }
    }
}
