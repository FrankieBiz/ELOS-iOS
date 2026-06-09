import Testing
import Foundation
@testable import Elos

struct ExerciseCandidateTests {
    @Test func mapsFromDefinitionRecord() {
        let rec = ExerciseDefinitionRecord(
            id: "x1", name: "Barbell Bench Press", primaryMuscle: "chest",
            secondaryMusclesJSON: "[\"triceps\",\"front_delts\"]",
            equipment: "barbell", movementPattern: "push", isCustom: false)
        let c = ExerciseCandidate(record: rec)
        #expect(c.id == "x1")
        #expect(c.name == "Barbell Bench Press")
        #expect(c.primaryMuscle == "chest")
        #expect(c.secondaryMuscles == ["triceps", "front_delts"])
        #expect(c.equipment == "barbell")
        #expect(c.movementPattern == "push")
    }
}
