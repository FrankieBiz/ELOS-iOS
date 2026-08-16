import Foundation
import Testing
@testable import Elos

struct MuscleTargetsTests {

    // MARK: Invariants

    @Test func aMuscleCannotBeBothDirectAndIndirect() {
        let t = MuscleTargets(primary: [.chest], secondary: [.chest, .triceps])
        #expect(t.primary == [.chest])
        #expect(t.secondary == [.triceps])
    }

    @Test func duplicatesCollapseButOrderSurvives() {
        let t = MuscleTargets(primary: [.glutes, .lowerBack, .glutes], secondary: [.abs, .abs])
        #expect(t.primary == [.glutes, .lowerBack])
        #expect(t.secondary == [.abs])
    }

    @Test func groupsAreReportedInTaxonomyOrder() {
        let t = MuscleTargets(primary: [.rearDelts], secondary: [.chest])
        #expect(t.groups == [.chest, .back])   // MuscleGroup.allCases order, not insertion order
    }

    // MARK: Toggling — what the check-off sheet does

    @Test func togglingPrimaryMovesItOutOfSecondary() {
        let t = MuscleTargets(primary: [.chest], secondary: [.rearDelts])
        let after = t.togglingPrimary(.rearDelts)
        #expect(after.primary == [.chest, .rearDelts])
        #expect(after.secondary.isEmpty)
    }

    @Test func togglingSecondaryMovesItOutOfPrimary() {
        let t = MuscleTargets(primary: [.chest, .rearDelts])
        let after = t.togglingSecondary(.rearDelts)
        #expect(after.primary == [.chest])
        #expect(after.secondary == [.rearDelts])
    }

    @Test func togglingTwiceReturnsToTheStart() {
        let t = MuscleTargets(primary: [.lowerBack])
        #expect(t.togglingPrimary(.glutes).togglingPrimary(.glutes) == t)
    }

    @Test func everythingCanBeUnticked() {
        #expect(MuscleTargets(primary: [.chest]).togglingPrimary(.chest).isEmpty)
    }

    // MARK: Persistence

    @Test func jsonRoundTrips() {
        let t = MuscleTargets(primary: [.lowerBack], secondary: [.glutes, .hamstrings])
        #expect(MuscleTargets(jsonString: t.jsonString) == t)
    }

    @Test func emptyTargetsEncodeToNothingAndDecodeToNil() {
        #expect(MuscleTargets().jsonString.isEmpty)
        #expect(MuscleTargets(jsonString: "") == nil)
        #expect(MuscleTargets(jsonString: "not json") == nil)
    }

    /// Older split JSON has no `muscleTargets` key at all — decoding must not throw the exercise away.
    @Test func dayExerciseDecodesWithoutTheNewKey() throws {
        let legacy = #"{"id":"1","name":"Barbell Row","sets":3,"reps":"10"}"#
        let ex = try JSONDecoder().decode(DayExercise.self, from: Data(legacy.utf8))
        #expect(ex.name == "Barbell Row")
        #expect(ex.muscleTargets == nil)
    }

    @Test func dayExerciseRoundTripsTheOverride() throws {
        let ex = DayExercise(id: "1", name: "Pec/Rear Delt", sets: 3, reps: "12",
                             muscleTargets: MuscleTargets(primary: [.rearDelts]))
        let data = try JSONEncoder().encode(ex)
        let back = try JSONDecoder().decode(DayExercise.self, from: data)
        #expect(back.muscleTargets?.primary == [.rearDelts])
    }

    // MARK: Building from catalog strings

    @Test func builtFromCatalogVocabulary() {
        let t = MuscleTargets(primaryMuscle: "lower_back", secondaryMuscles: ["glutes", "hamstrings"])
        #expect(t.primary == [.lowerBack])
        #expect(t.secondary == [.glutes, .hamstrings])
    }

    @Test func unknownMuscleStringsAreDroppedNotGuessed() {
        let t = MuscleTargets(primaryMuscle: "vibes", secondaryMuscles: ["also vibes"])
        #expect(t.isEmpty)
    }

    // MARK: Display

    @Test func summaryPrefersDirectMusclesAndFallsBackToIndirect() {
        #expect(MuscleTargets(primary: [.lowerBack], secondary: [.glutes]).summary == "Lower back")
        #expect(MuscleTargets(secondary: [.glutes, .abs]).summary == "Glutes, Abs")
        #expect(MuscleTargets().summary.isEmpty)
    }
}
