import Testing
@testable import Elos

struct SplitScaffoldsTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "bench", name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "fly", name: "Cable Fly", primaryMuscle: "chest", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
        .init(id: "ohp", name: "Overhead Press", primaryMuscle: "front_delts", secondaryMuscles: ["triceps"], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "lateral", name: "Lateral Raise", primaryMuscle: "side_delts", secondaryMuscles: [], equipment: "dumbbell", movementPattern: "isolation", isCustom: false),
        .init(id: "pushdown", name: "Tricep Pushdown", primaryMuscle: "triceps", secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false),
        .init(id: "curl", name: "Leg Curl", primaryMuscle: "hamstrings", secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false),
    ]
    private let pers = PersonalizationProvider(signals: .init())

    @Test func coversTargetMusclesCompoundFirstNoDupes() {
        let picks = SplitScaffolds.recommend(archetype: .push, catalog: catalog,
            personalization: pers, isEquipmentAvailable: { _ in true }, count: 4)
        #expect(picks.count == 4)
        #expect(Set(picks.map { $0.id }).count == 4)
        #expect(picks.first?.id == "bench" || picks.first?.id == "ohp")
        #expect(!picks.contains { $0.id == "curl" })
    }
    @Test func respectsEquipmentAvailability() {
        let picks = SplitScaffolds.recommend(archetype: .push, catalog: catalog,
            personalization: pers, isEquipmentAvailable: { $0.lowercased() != "machine" }, count: 5)
        #expect(!picks.contains { $0.id == "curl" })
    }
    @Test func deterministic() {
        let a = SplitScaffolds.recommend(archetype: .push, catalog: catalog, personalization: pers, isEquipmentAvailable: { _ in true }, count: 4)
        let b = SplitScaffolds.recommend(archetype: .push, catalog: catalog, personalization: pers, isEquipmentAvailable: { _ in true }, count: 4)
        #expect(a.map { $0.id } == b.map { $0.id })
    }
}
