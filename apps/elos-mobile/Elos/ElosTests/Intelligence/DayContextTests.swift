import Testing
@testable import Elos

struct DayContextTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "1", name: "Barbell Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "2", name: "Lat Pulldown", primaryMuscle: "lats", secondaryMuscles: ["biceps"], equipment: "cable", movementPattern: "pull", isCustom: false),
    ]
    @Test func infersArchetypeFromName() {
        let ctx = DayContextInferrer.infer(dayName: "Push Day", added: [], catalog: catalog)
        #expect(ctx.archetype == .push)
        #expect(ctx.targetMuscles.contains("chest"))
        #expect(ctx.hasFocus)
    }
    @Test func emptyNameNoAddedHasNoFocus() {
        let ctx = DayContextInferrer.infer(dayName: "", added: [], catalog: catalog)
        #expect(ctx.archetype == nil)
        #expect(!ctx.hasFocus)
        #expect(ctx.targetMuscles.isEmpty)
    }
    @Test func infersFocusFromAddedWhenNameBlank() {
        let added = [DayExercise(id: "2", name: "Lat Pulldown")]
        let ctx = DayContextInferrer.infer(dayName: "", added: added, catalog: catalog)
        #expect(ctx.hasFocus)
        #expect(ctx.targetMuscles.contains("lats"))
        #expect(ctx.addedPrimaryMuscles.contains("lats"))
        #expect(ctx.addedExerciseIDs.contains("2"))
    }
}
