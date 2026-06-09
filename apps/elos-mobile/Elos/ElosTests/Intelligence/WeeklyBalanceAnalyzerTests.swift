import Testing
@testable import Elos

struct WeeklyBalanceAnalyzerTests {
    private let catalog: [ExerciseCandidate] = [
        .init(id: "bench", name: "Bench Press", primaryMuscle: "chest", secondaryMuscles: [], equipment: "barbell", movementPattern: "push", isCustom: false),
        .init(id: "row", name: "Barbell Row", primaryMuscle: "back", secondaryMuscles: [], equipment: "barbell", movementPattern: "pull", isCustom: false),
    ]
    @Test func flagsLowVolumeMuscle() {
        let days = [[DayExercise(id: "bench", name: "Bench Press", sets: 2, reps: "8")]]
        let warnings = WeeklyBalanceAnalyzer.analyze(days: days, catalog: catalog)
        #expect(warnings.contains { $0.message.lowercased().contains("chest") })
    }
    @Test func balancedWeekHasNoPushPullWarning() {
        let days = [
            [DayExercise(id: "bench", name: "Bench Press", sets: 4, reps: "8")],
            [DayExercise(id: "row", name: "Barbell Row", sets: 4, reps: "8")],
        ]
        let warnings = WeeklyBalanceAnalyzer.analyze(days: days, catalog: catalog)
        #expect(!warnings.contains { $0.message.lowercased().contains("push") && $0.message.lowercased().contains("pull") })
    }
}
