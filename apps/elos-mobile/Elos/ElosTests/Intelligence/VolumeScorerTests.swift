import Testing
@testable import Elos

struct VolumeScorerTests {
    private let intermediate = TrainingProfile(goal: .hypertrophy, experience: .intermediate)

    /// Score a set of days at a scope, building the shared muscle report the scorer now reads.
    private func score(_ days: [[ScoredExercise]],
                       scope: QualityScope,
                       profile: TrainingProfile? = nil) -> DimensionScore {
        let p = profile ?? intermediate
        let resolved = QualityFixtures.resolve(days)
        let volume = QualityFixtures.volume(resolved, scope: scope, profile: p)
        return VolumeScorer.score(volume: volume, scope: scope, profile: p)
    }

    @Test func weeklyVolumeInTargetScoresFull() {
        // Chest's weekly productive band at intermediate is 14–20 fractional sets.
        let d = score([[QualityFixtures.sx("bench", sets: 15)]], scope: .weeklySplit)
        #expect(d.score == 100)
        #expect(d.tips.isEmpty)
    }

    @Test func weeklyLowVolumeFlaggedWarn() {
        let d = score([[QualityFixtures.sx("bench", sets: 4)]], scope: .weeklySplit)
        #expect(d.score < 60)
        #expect(d.tips.contains { $0.id == "vol-low-chest" && $0.severity == .warn })
    }

    @Test func weeklyExcessVolumeFlaggedWarn() {
        // Chest MRV at intermediate is 26, so 30 sets is genuinely excessive.
        let d = score([[QualityFixtures.sx("bench", sets: 30)]], scope: .weeklySplit)
        #expect(d.tips.contains { $0.id == "vol-high-chest" && $0.severity == .warn })
    }

    @Test func sessionJunkVolumeFlagged() {
        let d = score([[QualityFixtures.sx("bench", sets: 15)]], scope: .singleSession)
        #expect(d.tips.contains { $0.id == "sess-junk-chest" })
    }

    @Test func sessionShortFlagged() {
        let d = score([[QualityFixtures.sx("bench", sets: 6)]], scope: .singleSession)
        #expect(d.tips.contains { $0.id == "sess-short" })
    }

    @Test func experienceShiftsWeeklyTargets() {
        // 14 weekly chest sets: productive for a beginner (11–15), light for advanced (16–23).
        let days = [[QualityFixtures.sx("bench", sets: 14)]]
        let beginner = score(days, scope: .weeklySplit,
                             profile: .init(goal: .hypertrophy, experience: .beginner))
        let advanced = score(days, scope: .weeklySplit,
                             profile: .init(goal: .hypertrophy, experience: .advanced))
        #expect(beginner.score > advanced.score)
    }

    @Test func unknownExercisesFallBackNeutral() {
        let d = score([[ScoredExercise(id: "", name: "Mystery Move", sets: 4, repsText: "10")]],
                      scope: .singleSession)
        #expect(d.score == 70)
        #expect(d.tips.isEmpty)
    }

    // MARK: Fractional volume

    @Test func secondaryMusclesEarnHalfCredit() {
        // Bench = chest primary, triceps + front delts secondary.
        let resolved = QualityFixtures.resolve([[QualityFixtures.sx("bench", sets: 10)]])
        let v = QualityFixtures.volume(resolved, scope: .weeklySplit)
        #expect(v.sets(for: .chest) == 10)
        #expect(v.sets(for: .triceps) == 5)
        #expect(v.directSets(for: .triceps) == 0)
    }

    /// A muscle trained only indirectly is a *coverage* problem (BalanceScorer's tip), so the volume
    /// scorer must stay quiet about it rather than double-reporting the same mistake.
    @Test func indirectOnlyMusclesAreNotGradedForDosing() {
        let d = score([[QualityFixtures.sx("bench", sets: 15)]], scope: .weeklySplit)
        #expect(!d.tips.contains { $0.id.contains("triceps") })
        #expect(!d.tips.contains { $0.id.contains("frontDelts") })
    }

    /// Direct work is judged on total volume, so indirect help counts toward the band.
    @Test func directMuscleJudgedOnTotalIncludingIndirect() {
        // Pushdown gives triceps 8 direct; bench adds 8 × 0.5 = 4 indirect → 12 total, which is
        // exactly the bottom of the triceps productive band (12–18).
        let resolved = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 8),
            QualityFixtures.sx("pushdown", sets: 8),
        ]])
        let v = QualityFixtures.volume(resolved, scope: .weeklySplit)
        #expect(v.directSets(for: .triceps) == 8)
        #expect(v.sets(for: .triceps) == 12)

        let d = VolumeScorer.score(volume: v, scope: .weeklySplit, profile: intermediate)
        #expect(!d.tips.contains { $0.id == "vol-low-triceps" })
    }

    /// One exercise naming the same slot twice (primary + secondary, or two secondaries that fold
    /// together) must not inflate that muscle.
    @Test func sameSlotNamedTwiceDoesNotDoubleCount() {
        let ex = ExerciseCandidate(id: "x", name: "Odd Press", primaryMuscle: "chest",
                                   secondaryMuscles: ["upper_chest", "lower_chest"],
                                   equipment: "barbell", movementPattern: "push", isCustom: false)
        let resolved = [[ResolvedExercise(
            exercise: ScoredExercise(id: "x", name: "Odd Press", sets: 6, repsText: "8"),
            candidate: ex)]]
        let v = MuscleVolumeAnalyzer.analyze(resolvedDays: resolved, scope: .weeklySplit,
                                             intent: nil, dayNames: [""],
                                             profile: intermediate, catalog: [ex])
        #expect(v.sets(for: .chest) == 6)
    }
}
