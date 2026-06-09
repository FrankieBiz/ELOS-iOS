import Testing
@testable import Elos

struct ExerciseSearchTests {
    private func cand(_ name: String, muscle: String = "chest", equip: String = "barbell", pattern: String = "push") -> ExerciseCandidate {
        ExerciseCandidate(id: name, name: name, primaryMuscle: muscle, secondaryMuscles: [],
                          equipment: equip, movementPattern: pattern, isCustom: false)
    }
    @Test func exactNameScoresHighest() {
        let s = ExerciseSearch.tokens(from: "bench press")
        #expect(ExerciseSearch.score(cand("Bench Press"), tokens: s, query: "bench press") == 100)
    }
    @Test func prefixBeatsContains() {
        let s = ExerciseSearch.tokens(from: "bench")
        #expect(ExerciseSearch.score(cand("Bench Press"), tokens: s, query: "bench") == 90)
        let s2 = ExerciseSearch.tokens(from: "press")
        #expect(ExerciseSearch.score(cand("Bench Press"), tokens: s2, query: "press") == 80)
    }
    @Test func aliasExpands() {
        let s = ExerciseSearch.tokens(from: "rdl")
        #expect(s.contains("romanian"))
    }
    @Test func nonMatchReturnsNil() {
        let s = ExerciseSearch.tokens(from: "squat")
        #expect(ExerciseSearch.score(cand("Bench Press"), tokens: s, query: "squat") == nil)
    }
    @Test func matchesViaMuscleField() {
        let s = ExerciseSearch.tokens(from: "chest")
        #expect(ExerciseSearch.score(cand("Weird Lift", muscle: "chest"), tokens: s, query: "chest") == 50)
    }
}
