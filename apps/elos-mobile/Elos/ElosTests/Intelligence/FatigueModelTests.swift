import Foundation
import Testing
@testable import Elos

/// The fatigue/order layer: turning "how many sets" into "how many sets that actually did something".
///
/// Raw set counts treat set 1 and set 25 of a session as equal contributors, and they treat a curl
/// placed before a squat as costing nothing. Both are wrong, and both are things the volume bars alone
/// can't express — so this is the dimension that explains why two plans with identical set counts
/// aren't equally good.
struct FatigueModelTests {

    private func ex(_ name: String, sets: Int, compound: Bool,
                    primary: [FineMuscle] = [.chest]) -> ResolvedExercise {
        ResolvedExercise(
            exercise: ScoredExercise(id: "", name: name, sets: sets, repsText: "8-10"),
            candidate: ExerciseCandidate(
                id: "", name: name, primaryMuscle: primary.first?.rawValue ?? "chest",
                secondaryMuscles: [], equipment: "barbell",
                // `isCompound` is derived from the movement pattern, so drive it through the pattern
                // rather than faking the flag — that keeps the test honest about the real mapping.
                movementPattern: compound ? "push" : "isolation", isCustom: false)
        )
    }

    // MARK: Per-set quality

    @Test func aFreshSetIsWorthFullValue() {
        #expect(FatigueModel.setQuality(systemicLoadBefore: 0) == 1.0)
    }

    @Test func qualityIsFlatUntilOnsetThenDecays() {
        let onset = TrainingScience.fatigueOnsetLoad
        #expect(FatigueModel.setQuality(systemicLoadBefore: onset) == 1.0)
        #expect(FatigueModel.setQuality(systemicLoadBefore: onset + 10) < 1.0)
    }

    @Test func qualityNeverFallsBelowTheFloor() {
        #expect(FatigueModel.setQuality(systemicLoadBefore: 10_000) == TrainingScience.fatigueQualityFloor)
    }

    @Test func qualityNeverIncreasesWithLoad() {
        var previous = 1.1
        for load in stride(from: 0.0, through: 80.0, by: 1.0) {
            let q = FatigueModel.setQuality(systemicLoadBefore: load)
            #expect(q <= previous)
            previous = q
        }
    }

    // MARK: Effective volume

    @Test func aShortSessionLosesNothing() {
        let day = [ex("Bench", sets: 3, compound: true), ex("Fly", sets: 3, compound: false)]
        let f = FatigueModel.analyze(day: day)
        #expect(f.efficiency == 1.0)
        #expect(f.setsLostToFatigue == 0)
    }

    @Test func aLongSessionLosesRealVolume() {
        let long = (0..<8).map { ex("Big \($0)", sets: 4, compound: true) }
        let f = FatigueModel.analyze(day: long)
        #expect(f.efficiency < 1.0)
        #expect(f.setsLostToFatigue > 1)
        // The whole point: 32 sets on paper are not 32 sets of stimulus.
        #expect(f.effectiveSets < f.rawSets)
    }

    @Test func effectiveVolumeIsNeverMoreThanRawOrNegative() {
        let cases: [[ResolvedExercise]] = [
            [],
            [ex("Zero", sets: 0, compound: true)],
            [ex("A", sets: 3, compound: false)],
            (0..<12).map { ex("X\($0)", sets: 5, compound: true) },
        ]
        for day in cases {
            let f = FatigueModel.analyze(day: day)
            #expect(f.effectiveSets >= 0)
            #expect(f.effectiveSets <= f.rawSets)
            #expect(f.efficiency <= 1.0)
        }
    }

    @Test func compoundsCostMoreSystemicLoadThanIsolation() {
        let compound = [ex("Squat", sets: 10, compound: true)]
        let isolation = [ex("Curl", sets: 10, compound: false)]
        #expect(FatigueModel.systemicLoad(day: compound) > FatigueModel.systemicLoad(day: isolation))
        #expect(FatigueModel.analyze(day: compound).efficiency
                  < FatigueModel.analyze(day: isolation).efficiency)
    }

    // MARK: Order

    @Test func compoundFirstIsPerfectlyOrdered() {
        let day = [ex("Squat", sets: 3, compound: true, primary: [.quads]),
                   ex("Leg Extension", sets: 3, compound: false, primary: [.quads])]
        #expect(FatigueModel.orderQuality(day: day).quality == 1.0)
        #expect(FatigueModel.orderQuality(day: day).inversions.isEmpty)
    }

    @Test func isolationBeforeACompoundIsPenalised() {
        let day = [ex("Leg Extension", sets: 3, compound: false, primary: [.quads]),
                   ex("Squat", sets: 3, compound: true, primary: [.quads])]
        let report = FatigueModel.orderQuality(day: day)
        #expect(report.quality < 1.0)
        #expect(report.inversions.count == 1)
    }

    @Test func anUnrelatedIsolationIsNotCountedAsAnInversion() {
        let day = [ex("Curl", sets: 3, compound: false, primary: [.biceps]),
                   ex("Squat", sets: 3, compound: true, primary: [.quads])]
        let report = FatigueModel.orderQuality(day: day)
        #expect(report.inversions.isEmpty)
        #expect(report.quality == 1.0)
    }

    @Test func qualityCountsOnlySameMuscleInversions() {
        // Curl-before-Squat: different muscles, doesn't count. Leg-Extension-before-Squat: same
        // muscle (quads), counts. Quality should reflect only the second pair.
        let day = [ex("Curl", sets: 3, compound: false, primary: [.biceps]),
                   ex("Leg Extension", sets: 3, compound: false, primary: [.quads]),
                   ex("Squat", sets: 3, compound: true, primary: [.quads])]
        let report = FatigueModel.orderQuality(day: day)
        #expect(report.inversions.count == 1)
        #expect(report.inversions.first?.isolationName == "Leg Extension")
        #expect(report.quality == 0.0)  // the one same-muscle pair, and it's inverted
    }

    @Test func aDayOfOneTypeHasNothingToOrder() {
        let compoundOnly = (0..<3).map { ex("C\($0)", sets: 3, compound: true) }
        let isolationOnly = (0..<3).map { ex("I\($0)", sets: 3, compound: false) }
        #expect(FatigueModel.orderQuality(day: compoundOnly).quality == 1.0)
        #expect(FatigueModel.orderQuality(day: isolationOnly).quality == 1.0)
        #expect(FatigueModel.orderQuality(day: []).quality == 1.0)
    }

    @Test func aFullyInvertedDayScoresZero() {
        let day = [ex("I1", sets: 2, compound: false), ex("I2", sets: 2, compound: false),
                   ex("C1", sets: 2, compound: true), ex("C2", sets: 2, compound: true)]
        #expect(FatigueModel.orderQuality(day: day).quality == 0.0)
    }
}
