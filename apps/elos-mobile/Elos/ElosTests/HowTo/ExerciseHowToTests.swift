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

    @Test func resolvesUniqueExactMachineName() {
        let g = ExerciseHowToLookup.resolveGenericName(
            machineName: "Leg Extension",
            enrichedNames: ["Leg Extension", "Leg Press"])
        #expect(g == "Leg Extension")
    }

    @Test func resolvesUniqueWordBoundarySuffix() {
        let g = ExerciseHowToLookup.resolveGenericName(
            machineName: "Hammer Strength Chest Press",
            enrichedNames: ["Chest Press", "Leg Press"])
        #expect(g == "Chest Press")
    }

    @Test func returnsNilOnAmbiguousSuffix() {
        // two DISTINCT enriched names both validly match -> never guess
        let g = ExerciseHowToLookup.resolveGenericName(
            machineName: "Super Row",
            enrichedNames: ["Row", "Seated Row"])
        #expect(g == nil)
    }

    @Test func returnsNilOnNoMatch() {
        let g = ExerciseHowToLookup.resolveGenericName(
            machineName: "Iso Lateral Incline",
            enrichedNames: ["Leg Press", "Chest Press"])
        #expect(g == nil)
    }

    @Test func doesNotMatchMidWordSubstring() {
        // "press" must not match inside "compress"; requires whole-string or a space-delimited trailing phrase
        let g = ExerciseHowToLookup.resolveGenericName(
            machineName: "Ab Compress",
            enrichedNames: ["Press"])
        #expect(g == nil)
    }
}
