import Foundation
@testable import Elos

/// Shared exercise catalog + builders for the quality-engine tests.
enum QualityFixtures {
    static let catalog: [ExerciseCandidate] = [
        .init(id: "bench",    name: "Barbell Bench Press",    primaryMuscle: "chest",      secondaryMuscles: ["triceps", "front delts"], equipment: "barbell",    movementPattern: "push",       isCustom: false),
        .init(id: "incline",  name: "Incline Dumbbell Press", primaryMuscle: "chest",      secondaryMuscles: ["front delts"],            equipment: "dumbbell",   movementPattern: "push",       isCustom: false),
        .init(id: "dip",      name: "Dips",                   primaryMuscle: "chest",      secondaryMuscles: ["triceps"],                equipment: "bodyweight", movementPattern: "push",       isCustom: false),
        .init(id: "ohp",      name: "Overhead Press",         primaryMuscle: "front delts",secondaryMuscles: ["triceps"],                equipment: "barbell",    movementPattern: "push",       isCustom: false),
        .init(id: "lateral",  name: "Lateral Raise",          primaryMuscle: "side delts", secondaryMuscles: [],                         equipment: "dumbbell",   movementPattern: "raise",      isCustom: false),
        .init(id: "pushdown", name: "Triceps Pushdown",       primaryMuscle: "triceps",    secondaryMuscles: [],                         equipment: "cable",      movementPattern: "pushdown",   isCustom: false),
        .init(id: "pulldown", name: "Lat Pulldown",           primaryMuscle: "lats",       secondaryMuscles: ["biceps"],                 equipment: "cable",      movementPattern: "pull",       isCustom: false),
        .init(id: "row",      name: "Barbell Row",            primaryMuscle: "back",       secondaryMuscles: ["biceps"],                 equipment: "barbell",    movementPattern: "pull",       isCustom: false),
        .init(id: "facepull", name: "Face Pull",              primaryMuscle: "rear delts", secondaryMuscles: [],                         equipment: "cable",      movementPattern: "pull",       isCustom: false),
        .init(id: "curl",     name: "Barbell Curl",           primaryMuscle: "biceps",     secondaryMuscles: [],                         equipment: "barbell",    movementPattern: "curl",       isCustom: false),
        .init(id: "hammer",   name: "Hammer Curl",            primaryMuscle: "biceps",     secondaryMuscles: ["forearms"],               equipment: "dumbbell",   movementPattern: "curl",       isCustom: false),
        .init(id: "squat",    name: "Back Squat",             primaryMuscle: "quads",      secondaryMuscles: ["glutes"],                 equipment: "barbell",    movementPattern: "squat",      isCustom: false),
        .init(id: "legpress", name: "Leg Press",              primaryMuscle: "quads",      secondaryMuscles: ["glutes"],                 equipment: "machine",    movementPattern: "squat",      isCustom: false),
        .init(id: "legext",   name: "Leg Extension",          primaryMuscle: "quads",      secondaryMuscles: [],                         equipment: "machine",    movementPattern: "extension",  isCustom: false),
        .init(id: "rdl",      name: "Romanian Deadlift",      primaryMuscle: "hamstrings", secondaryMuscles: ["glutes"],                 equipment: "barbell",    movementPattern: "hinge",      isCustom: false),
        .init(id: "legcurl",  name: "Leg Curl",               primaryMuscle: "hamstrings", secondaryMuscles: [],                         equipment: "machine",    movementPattern: "curl",       isCustom: false),
        .init(id: "hipthrust",name: "Hip Thrust",             primaryMuscle: "glutes",     secondaryMuscles: ["hamstrings"],             equipment: "barbell",    movementPattern: "hinge",      isCustom: false),
        .init(id: "calf",     name: "Standing Calf Raise",    primaryMuscle: "calves",     secondaryMuscles: [],                         equipment: "machine",    movementPattern: "raise",      isCustom: false),
        .init(id: "plank",    name: "Plank",                  primaryMuscle: "core",       secondaryMuscles: [],                         equipment: "bodyweight", movementPattern: "core",       isCustom: false),
    ]

    /// Build a `ScoredExercise` for a catalog id.
    static func sx(_ id: String, sets: Int, reps: String = "8-10", rest: Int? = nil) -> ScoredExercise {
        let name = catalog.first { $0.id == id }?.name ?? id
        return ScoredExercise(id: id, name: name, sets: sets, repsText: reps, restSeconds: rest)
    }

    static func resolve(_ days: [[ScoredExercise]]) -> [[ResolvedExercise]] {
        ExerciseResolver.resolve(days, catalog: catalog)
    }
}
