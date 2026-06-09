import Testing
@testable import Elos

struct SetRepDefaultsTests {
    @Test func heavyCompoundsLowerReps() {
        let squat = SetRepDefaults.defaults(forMovementPattern: "squat")
        #expect(squat.sets == 4)
        #expect(squat.reps == "5-8")
    }
    @Test func isolationHigherReps() {
        let iso = SetRepDefaults.defaults(forMovementPattern: "isolation")
        #expect(iso.sets == 3)
        #expect(iso.reps == "10-15")
    }
    @Test func unknownPatternFallsBackToIsolationDefault() {
        #expect(SetRepDefaults.defaults(forMovementPattern: "").reps == "10-15")
    }
}
