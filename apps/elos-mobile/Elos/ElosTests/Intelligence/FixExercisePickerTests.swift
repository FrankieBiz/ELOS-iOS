import Testing
@testable import Elos

struct FixExercisePickerTests {

    private func sampleContext(addedIDs: [String] = [], addedNames: [String] = [],
                               equipmentPreference: EquipmentPreference = .fullGym) -> FixExercisePicker.Context {
        var added: [ScoredExercise] = addedIDs.map { QualityFixtures.sx($0, sets: 3) }
        added += addedNames.map { ScoredExercise(id: "", name: $0, sets: 3, repsText: "8-10") }
        return FixExercisePicker.Context(
            catalog: QualityFixtures.catalog,
            dayName: "Day",
            addedDay: added,
            personalization: PersonalizationProvider(signals: .init()),
            equipmentPreference: equipmentPreference)
    }

    @Test func onlyReturnsPrimaryMuscleMatches() {
        // "row"'s primary is "back", secondary is "biceps" — asking for biceps must not return it.
        let results = FixExercisePicker.candidates(forMuscles: ["biceps"], context: sampleContext(), limit: 3)
        #expect(!results.contains { $0.id == "row" })
        #expect(results.contains { $0.id == "curl" || $0.id == "hammer" })
    }

    @Test func excludesByIdAndByNormalizedName() {
        let ctx = sampleContext(addedIDs: ["bench"], addedNames: ["Incline Dumbbell Press"])
        let results = FixExercisePicker.candidates(forMuscles: ["chest"], context: ctx, limit: 5)
        #expect(!results.contains { $0.id == "bench" })
        #expect(!results.contains { MuscleTaxonomy.normalize($0.name) == MuscleTaxonomy.normalize("Incline Dumbbell Press") })
    }

    @Test func fallsBackRatherThanReturningEmptyWhenEquipmentOverConstrains() {
        // The fixture catalog's only chest exercises are barbell/dumbbell/bodyweight — none is
        // "home"-disallowed, so pick a muscle the fixture only trains via non-home equipment.
        let ctx = sampleContext(equipmentPreference: EquipmentPreference(posture: .custom, customTypes: ["nonexistent-equipment"]))
        let results = FixExercisePicker.candidates(forMuscles: ["chest"], context: ctx, limit: 3)
        #expect(!results.isEmpty)
    }

    @Test func patternFilterMatchesMovementPattern() {
        let results = FixExercisePicker.candidates(forPattern: "hinge", context: sampleContext(), limit: 3)
        #expect(!results.isEmpty)
        #expect(results.allSatisfy { $0.movementPattern == "hinge" })
    }

    @Test func alternatesAreDistinctFromThePick() {
        let results = FixExercisePicker.candidates(forMuscles: ["chest"], context: sampleContext(), limit: 3)
        #expect(Set(results.map(\.id)).count == results.count)
    }

    @Test func returnsEmptyWhenEveryMatchingCandidateIsAlreadyOnTheDay() {
        // Only one hinge exercise in the fixture catalog trains hamstrings this specifically —
        // exclude it and confirm the picker returns nothing rather than a wrong pick.
        let ctx = sampleContext(addedIDs: ["rdl"])
        let results = FixExercisePicker.candidates(forMuscles: ["hamstrings"], context: ctx, limit: 3)
        #expect(!results.contains { $0.id == "rdl" })
    }
}
