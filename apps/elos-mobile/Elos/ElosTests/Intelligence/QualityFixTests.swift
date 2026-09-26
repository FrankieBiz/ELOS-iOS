import Testing
@testable import Elos

struct QualityFixTests {

    @Test func insertOperationAppendsAtTheGivenIndex() {
        let day: [ScoredExercise] = [QualityFixtures.sx("bench", sets: 4)]
        let candidate = QualityFixtures.catalog.first { $0.id == "row" }!
        let op = FixOperation.insertExercise(InsertSpec(dayIndex: 0, insertAt: 1,
                                                        candidate: candidate, sets: 4, reps: "6-10"))
        let result = op.apply(to: [day])
        #expect(result[0].count == 2)
        #expect(result[0][1].name == candidate.name)
        #expect(result[0][1].sets == 4)
    }

    @Test func outOfRangeDayIndexReturnsInputUnchanged() {
        let days: [[ScoredExercise]] = [[QualityFixtures.sx("bench", sets: 4)]]
        let op = FixOperation.setReps(dayIndex: 9, exerciseIndex: 0, reps: "6-10")
        #expect(op.apply(to: days) == days)
    }

    @Test func reorderDayAppliesAPermutation() {
        let day: [ScoredExercise] = [QualityFixtures.sx("bench", sets: 4),
                                    QualityFixtures.sx("pushdown", sets: 3)]
        let op = FixOperation.reorderDay(dayIndex: 0, permutation: [1, 0])
        let result = op.apply(to: [day])
        #expect(result[0].map(\.id) == ["pushdown", "bench"])
    }

    @Test func nonBijectivePermutationIsRejected() {
        let day: [ScoredExercise] = [QualityFixtures.sx("bench", sets: 4),
                                    QualityFixtures.sx("pushdown", sets: 3)]
        let op = FixOperation.reorderDay(dayIndex: 0, permutation: [0, 0])  // not a bijection
        let result = op.apply(to: [day])
        #expect(result[0].map(\.id) == ["bench", "pushdown"])  // unchanged, not a crash
    }

    @Test func setRepsMutatesOnlyTheTargetedExercise() {
        let day: [ScoredExercise] = [QualityFixtures.sx("bench", sets: 4, reps: "8-10"),
                                    QualityFixtures.sx("pushdown", sets: 3, reps: "8-10")]
        let op = FixOperation.setReps(dayIndex: 0, exerciseIndex: 0, reps: "6-8")
        let result = op.apply(to: [day])
        #expect(result[0][0].repsText == "6-8")
        #expect(result[0][1].repsText == "8-10")
    }

    @Test func setRestMutatesOnlyTheTargetedExercise() {
        let day: [ScoredExercise] = [QualityFixtures.sx("bench", sets: 4, rest: 90)]
        let op = FixOperation.setRest(dayIndex: 0, exerciseIndex: 0, seconds: 150)
        let result = op.apply(to: [day])
        #expect(result[0][0].restSeconds == 150)
    }
}
