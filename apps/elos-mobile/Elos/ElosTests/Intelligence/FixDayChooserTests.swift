import Testing
@testable import Elos

struct FixDayChooserTests {

    @Test func vetoesRestDays() {
        let result = FixDayChooser.choose(
            forMuscles: ["hamstrings"],
            dayNames: ["Push", "Rest"], dayIsRest: [false, true],
            dayExercises: [[QualityFixtures.sx("bench", sets: 4)], []],
            dayExcludedMuscles: [[], []], catalog: QualityFixtures.catalog,
            intent: .default)
        #expect(result?.dayIndex == 0)
    }

    @Test func vetoesADayThatExcludesEveryTargetMuscle() {
        let result = FixDayChooser.choose(
            forMuscles: ["hamstrings"],
            dayNames: ["Legs", "Upper"], dayIsRest: [false, false],
            dayExercises: [[QualityFixtures.sx("squat", sets: 4)], [QualityFixtures.sx("bench", sets: 4)]],
            dayExcludedMuscles: [[.hamstrings], []], catalog: QualityFixtures.catalog,
            intent: .default)
        #expect(result?.dayIndex == 1)
    }

    @Test func prefersAFocusMatchingDayOverAnEmptierNonMatchingDay() {
        // Regression: today's firstOpenDayIndex() would route to the emptier arm day.
        let result = FixDayChooser.choose(
            forMuscles: ["hamstrings"],
            dayNames: ["Legs", "Arms"], dayIsRest: [false, false],
            dayExercises: [
                [QualityFixtures.sx("squat", sets: 4), QualityFixtures.sx("legpress", sets: 4)],
                [QualityFixtures.sx("curl", sets: 3)],
            ],
            dayExcludedMuscles: [[], []], catalog: QualityFixtures.catalog,
            intent: .default)
        #expect(result?.dayIndex == 0)
    }

    @Test func prefersTheLowerVolumeDayAmongFocusMatches() {
        // Both are "Legs" days by name; day 1 already has more hamstring volume, so day 0 (less
        // volume there) should win.
        let result = FixDayChooser.choose(
            forMuscles: ["hamstrings"],
            dayNames: ["Legs A", "Legs B"], dayIsRest: [false, false],
            dayExercises: [
                [QualityFixtures.sx("squat", sets: 4)],
                [QualityFixtures.sx("rdl", sets: 6)],
            ],
            dayExcludedMuscles: [[], []], catalog: QualityFixtures.catalog,
            intent: .default)
        #expect(result?.dayIndex == 0)
    }

    @Test func returnsNilWhenNoDayIsEligible() {
        let result = FixDayChooser.choose(
            forMuscles: ["hamstrings"],
            dayNames: ["Rest"], dayIsRest: [true],
            dayExercises: [[]], dayExcludedMuscles: [[]], catalog: QualityFixtures.catalog,
            intent: .default)
        #expect(result == nil)
    }

    @Test func returnsNilWhenEveryEligibleDayExcludesTheMuscle() {
        let result = FixDayChooser.choose(
            forMuscles: ["hamstrings"],
            dayNames: ["Legs", "Upper"], dayIsRest: [false, false],
            dayExercises: [[QualityFixtures.sx("squat", sets: 4)], [QualityFixtures.sx("bench", sets: 4)]],
            dayExcludedMuscles: [[.hamstrings], [.hamstrings]], catalog: QualityFixtures.catalog,
            intent: .default)
        #expect(result == nil)
    }

    @Test func deterministicUnderTies() {
        let a = FixDayChooser.choose(
            forMuscles: ["chest"],
            dayNames: ["A", "B"], dayIsRest: [false, false],
            dayExercises: [[], []], dayExcludedMuscles: [[], []], catalog: QualityFixtures.catalog,
            intent: .default)
        let b = FixDayChooser.choose(
            forMuscles: ["chest"],
            dayNames: ["A", "B"], dayIsRest: [false, false],
            dayExercises: [[], []], dayExcludedMuscles: [[], []], catalog: QualityFixtures.catalog,
            intent: .default)
        #expect(a?.dayIndex == b?.dayIndex)
        // Both days are identical/empty, so the tie must break to the lower index.
        #expect(a?.dayIndex == 0)
    }
}
