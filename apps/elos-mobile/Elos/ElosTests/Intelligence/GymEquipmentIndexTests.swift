import Foundation
import Testing
@testable import Elos

struct GymEquipmentIndexTests {

    private func set(sessionID: String, dedupeKey: String?) -> ExerciseSetRecord {
        ExerciseSetRecord(ownerID: "u", sessionID: sessionID, exerciseName: "Row", setIndex: 0,
                         equipmentDedupeKey: dedupeKey)
    }

    @Test func inventoryContainsOnlyDedupeKeysLoggedAtThatGym() {
        let sets = [set(sessionID: "s1", dedupeKey: "hammer-strength|row"),
                   set(sessionID: "s2", dedupeKey: "cybex|row")]
        let sessionGymByID = ["s1": "gym-a", "s2": "gym-b"]

        let inventory = GymEquipmentIndex.loggedDedupeKeys(gymID: "gym-a", sets: sets, sessionGymByID: sessionGymByID)

        #expect(inventory == ["hammer-strength|row"])
    }

    @Test func aSetWithNoEquipmentKeyContributesNothing() {
        let sets = [set(sessionID: "s1", dedupeKey: nil)]
        let inventory = GymEquipmentIndex.loggedDedupeKeys(gymID: "gym-a", sets: sets,
                                                           sessionGymByID: ["s1": "gym-a"])
        #expect(inventory.isEmpty)
    }

    @Test func anUntaggedSessionContributesNothing() {
        let sets = [set(sessionID: "s1", dedupeKey: "hammer-strength|row")]
        // s1 maps to "" (untagged) in the session lookup — never "gym-a".
        let inventory = GymEquipmentIndex.loggedDedupeKeys(gymID: "gym-a", sets: sets,
                                                           sessionGymByID: ["s1": ""])
        #expect(inventory.isEmpty)
    }

    @Test func emptyGymIDIsUnknownNotEmptyGym() {
        let sets = [set(sessionID: "s1", dedupeKey: "hammer-strength|row")]
        let inventory = GymEquipmentIndex.loggedDedupeKeys(gymID: "", sets: sets, sessionGymByID: ["s1": ""])
        #expect(inventory.isEmpty)
    }

    @Test func equipmentTypesAreDerivedFromTheDedupeKeysViaTheDatabase() {
        let db = [EquipmentRecord(equipmentId: "eq1", brandName: "Hammer Strength", machineName: "Row",
                                  modelSeries: "", bodyParts: ["Back"], equipmentType: "Machine",
                                  primaryCategory: "Back", dedupeKey: "hammer-strength|row")]
        let sets = [set(sessionID: "s1", dedupeKey: "hammer-strength|row")]
        let types = GymEquipmentIndex.loggedEquipmentTypes(gymID: "gym-a", sets: sets,
                                                           sessionGymByID: ["s1": "gym-a"], database: db)
        #expect(types.contains("machine"))
    }

    @Test func noLoggedKeysMeansNoEquipmentTypesEitherNotAnEmptyGymClaim() {
        let types = GymEquipmentIndex.loggedEquipmentTypes(gymID: "gym-a", sets: [], sessionGymByID: [:])
        #expect(types.isEmpty)
    }

    @Test func gymEquipmentTypeBiasReordersOtherwiseTiedCandidates() {
        // Both isolation exercises (no compound bonus), no day focus, no personalization — the
        // only thing that can separate them is the gym-equipment nudge. Named so alphabetical
        // tiebreak favors B without the bias, proving the bias is what flips the order.
        let a = ExerciseCandidate(id: "a", name: "Zebra Press", primaryMuscle: "chest",
                                  secondaryMuscles: [], equipment: "machine", movementPattern: "isolation", isCustom: false)
        let b = ExerciseCandidate(id: "b", name: "Apple Fly", primaryMuscle: "chest",
                                  secondaryMuscles: [], equipment: "cable", movementPattern: "isolation", isCustom: false)
        let base = RankingInputs(context: .empty, personalization: PersonalizationProvider(signals: .init()))

        let withoutBias = ExerciseRankingEngine.rank([a, b], inputs: base)
        #expect(withoutBias.map(\.id) == ["b", "a"], "alphabetical tiebreak with no bias")

        var withBias = base
        withBias.gymEquipmentTypes = ["machine"]
        let ranked = ExerciseRankingEngine.rank([a, b], inputs: withBias)
        #expect(ranked.map(\.id) == ["a", "b"], "machine-equipped candidate should now outrank the tie")
    }
}
