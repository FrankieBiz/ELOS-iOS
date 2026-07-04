import Testing
@testable import Elos

struct ExerciseHowToTests {
    @Test func returnsNilWhenNoInstructions() {
        let r = ExerciseDefinitionRecord(
            id: "1", ownerID: "", name: "Pec Deck", primaryMuscle: "chest",
            secondaryMusclesJSON: "[]", equipment: "machine", movementPattern: "isolation",
            isCustom: false, instructionsJSON: "[]", imageKey: ""
        )
        #expect(ExerciseHowTo.from(record: r) == nil)
    }

    @Test func buildsFromRecordWithSteps() {
        let r = ExerciseDefinitionRecord(
            id: "1", ownerID: "", name: "Pec Deck", primaryMuscle: "chest",
            secondaryMusclesJSON: "[]", equipment: "machine", movementPattern: "isolation",
            isCustom: false, instructionsJSON: "[\"Sit down.\",\"Squeeze.\"]", imageKey: "Butterfly"
        )
        let howTo = ExerciseHowTo.from(record: r)
        #expect(howTo?.steps == ["Sit down.", "Squeeze."])
        #expect(howTo?.imageKey == "Butterfly")
    }

    @Test func emptyImageKeyBecomesNil() {
        let r = ExerciseDefinitionRecord(
            id: "1", ownerID: "", name: "Pec Deck", primaryMuscle: "chest",
            secondaryMusclesJSON: "[]", equipment: "machine", movementPattern: "isolation",
            isCustom: false, instructionsJSON: "[\"Sit down.\"]", imageKey: ""
        )
        let howTo = ExerciseHowTo.from(record: r)
        #expect(howTo?.imageKey == nil)
    }
}
