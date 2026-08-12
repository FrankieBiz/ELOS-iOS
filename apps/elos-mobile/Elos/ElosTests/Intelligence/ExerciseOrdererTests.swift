import Testing
@testable import Elos

struct ExerciseOrdererTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "fly", name: "Cable Fly", primaryMuscle: "chest", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
        .init(id: "bench", name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "pushdown", name: "Tricep Pushdown", primaryMuscle: "triceps", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
        .init(id: "curl", name: "Bicep Curl", primaryMuscle: "biceps", secondaryMuscles: [], equipment: "dumbbell", movementPattern: "isolation", isCustom: false),
        .init(id: "closegrip", name: "Close-Grip Bench", primaryMuscle: "triceps", secondaryMuscles: ["chest"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "squat", name: "Squat", primaryMuscle: "quads", secondaryMuscles: [], equipment: "barbell", movementPattern: "squat", isCustom: false),
        .init(id: "legext", name: "Leg Extension", primaryMuscle: "quads", secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false),
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

    // MARK: Priority partitioning

    @Test func priorityGroupExercisesPrecedeEverythingElse() {
        let day = [DayExercise(id: "squat", name: "Squat"),
                   DayExercise(id: "curl", name: "Bicep Curl"),
                   DayExercise(id: "closegrip", name: "Close-Grip Bench")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog, priority: .arms)
        let ids = ordered.map(\.id)
        // Arms exercises (curl, closegrip) first, quads (squat) last — regardless of compound-ness.
        #expect(Set(ids.prefix(2)) == Set(["curl", "closegrip"]))
        #expect(ids.last == "squat")
    }

    @Test func compoundBeforeIsolationHoldsWithinThePriorityGroup() {
        let day = [DayExercise(id: "curl", name: "Bicep Curl"),
                   DayExercise(id: "closegrip", name: "Close-Grip Bench"),
                   DayExercise(id: "squat", name: "Squat")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog, priority: .arms)
        // Both arm exercises lead; the compound one (closegrip) leads *within* that group.
        #expect(ordered.map(\.id) == ["closegrip", "curl", "squat"])
    }

    @Test func compoundBeforeIsolationHoldsWithinTheRestGroup() {
        let day = [DayExercise(id: "curl", name: "Bicep Curl"),
                   DayExercise(id: "legext", name: "Leg Extension"),
                   DayExercise(id: "squat", name: "Squat")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog, priority: .arms)
        // curl (arms) leads. Among the rest, squat (compound) leads legext (isolation).
        #expect(ordered.map(\.id) == ["curl", "squat", "legext"])
    }

    @Test func priorityWithNoMatchesBehavesLikeNoPriority() {
        let day = [DayExercise(id: "curl", name: "Bicep Curl"),
                   DayExercise(id: "bench", name: "Bench Press")]
        // Nothing here is a legs exercise — .legs priority should be a no-op vs. nil. DayExercise
        // isn't Equatable, so compare the id sequence rather than the arrays directly.
        let withPriority = ExerciseOrderer.order(day, catalog: catalog, priority: .legs)
        let withoutPriority = ExerciseOrderer.order(day, catalog: catalog, priority: nil)
        #expect(withPriority.map(\.id) == withoutPriority.map(\.id))
    }

    @Test func priorityGroupOrderIsStableAmongEqualRank() {
        let day = [DayExercise(id: "curl", name: "Bicep Curl"),
                   DayExercise(id: "pushdown", name: "Tricep Pushdown"),
                   DayExercise(id: "bench", name: "Bench Press")]
        let ordered = ExerciseOrderer.order(day, catalog: catalog, priority: .arms)
        // curl and pushdown are both arms, both isolation (equal rank) — relative order must survive.
        #expect(ordered.map(\.id) == ["curl", "pushdown", "bench"])
    }
}
