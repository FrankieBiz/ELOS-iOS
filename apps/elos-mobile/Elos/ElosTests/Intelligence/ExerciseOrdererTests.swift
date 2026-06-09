import Testing
@testable import Elos

struct ExerciseOrdererTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "fly", name: "Cable Fly", primaryMuscle: "chest", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
        .init(id: "bench", name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "pushdown", name: "Tricep Pushdown", primaryMuscle: "triceps", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
    ]
    @Test func compoundsComeFirst() {
        let day = [DayExercise(id: "fly", name: "Cable Fly"),
                   DayExercise(id: "pushdown", name: "Tricep Pushdown"),
                   DayExercise(id: "bench", name: "Bench Press")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog)
        #expect(ordered.first?.id == "bench")
        #expect(ordered.map { $0.id }.firstIndex(of: "bench")! < ordered.map { $0.id }.firstIndex(of: "fly")!)
    }
    @Test func unknownExercisesSinkButArePreserved() {
        let day = [DayExercise(id: "ghost", name: "Mystery Move"), DayExercise(id: "bench", name: "Bench Press")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog)
        #expect(ordered.first?.id == "bench")
        #expect(ordered.count == 2)
    }
}
