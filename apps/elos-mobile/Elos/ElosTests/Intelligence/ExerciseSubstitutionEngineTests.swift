import Testing
@testable import Elos

struct ExerciseSubstitutionEngineTests {
    private static let squat = ExerciseCandidate(
        id: "1", name: "Barbell Back Squat", primaryMuscle: "quads",
        secondaryMuscles: ["glutes", "hamstrings"], equipment: "barbell",
        movementPattern: "squat", isCustom: false)
    private static let goblet = ExerciseCandidate(
        id: "2", name: "Goblet Squat", primaryMuscle: "quads",
        secondaryMuscles: ["glutes"], equipment: "dumbbell",
        movementPattern: "squat", isCustom: false)

    @Test func resolveSourceMatchesByNormalizedName() {
        let resolved = ExerciseSubstitutionEngine.resolveSource(
            name: "barbell   back squat", candidates: [Self.squat, Self.goblet])
        #expect(resolved?.id == Self.squat.id)
    }

    @Test func resolveSourceReturnsNilForUnresolvableName() {
        let resolved = ExerciseSubstitutionEngine.resolveSource(
            name: "Some Totally Custom Thing", candidates: [Self.squat, Self.goblet])
        #expect(resolved == nil)
    }
}
