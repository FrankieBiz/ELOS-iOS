import Testing
@testable import Elos

struct MuscleCoverageTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "1", name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "2", name: "Incline Press", primaryMuscle: "chest", secondaryMuscles: ["front_delts"], equipment: "dumbbell", movementPattern: "push", isCustom: false),
    ]
    @Test func uncoveredTargetReportsNone() {
        let ctx = DayContextInferrer.infer(dayName: "Push", added: [], catalog: catalog)
        let chips = MuscleCoverage.chips(context: ctx, addedCandidates: [])
        #expect(chips.first { $0.muscleGroup == "Chest" }?.level == CoverageLevel.none)
        #expect(chips.first { $0.muscleGroup == "Arms" }?.level == CoverageLevel.none) // triceps → Arms
    }
    @Test func twoExercisesGiveGoodCoverage() {
        let added = [DayExercise(id: "1", name: "Bench Press"), DayExercise(id: "2", name: "Incline Press")]
        let ctx = DayContextInferrer.infer(dayName: "Push", added: added, catalog: catalog)
        let chips = MuscleCoverage.chips(context: ctx, addedCandidates: [catalog[0], catalog[1]])
        #expect(chips.first { $0.muscleGroup == "Chest" }?.level == CoverageLevel.good)
    }
}
