import Testing
@testable import Elos

struct VolumeScorerTests {
    private let intermediate = TrainingProfile(goal: .hypertrophy, experience: .intermediate)

    @Test func weeklyVolumeInTargetScoresFull() {
        let days = QualityFixtures.resolve([[QualityFixtures.sx("bench", sets: 15)]])
        let d = VolumeScorer.score(resolvedDays: days, scope: .weeklySplit, profile: intermediate)
        #expect(d.score == 100)
        #expect(d.tips.isEmpty)
    }

    @Test func weeklyLowVolumeFlaggedWarn() {
        let days = QualityFixtures.resolve([[QualityFixtures.sx("bench", sets: 4)]])
        let d = VolumeScorer.score(resolvedDays: days, scope: .weeklySplit, profile: intermediate)
        #expect(d.score < 60)
        #expect(d.tips.contains { $0.id == "vol-low-chest" && $0.severity == .warn })
    }

    @Test func weeklyExcessVolumeFlaggedWarn() {
        let days = QualityFixtures.resolve([[QualityFixtures.sx("bench", sets: 26)]])
        let d = VolumeScorer.score(resolvedDays: days, scope: .weeklySplit, profile: intermediate)
        #expect(d.tips.contains { $0.id == "vol-high-chest" && $0.severity == .warn })
    }

    @Test func sessionJunkVolumeFlagged() {
        let days = QualityFixtures.resolve([[QualityFixtures.sx("bench", sets: 15)]])
        let d = VolumeScorer.score(resolvedDays: days, scope: .singleSession, profile: intermediate)
        #expect(d.tips.contains { $0.id == "sess-junk-chest" })
    }

    @Test func sessionShortFlagged() {
        let days = QualityFixtures.resolve([[QualityFixtures.sx("bench", sets: 6)]])
        let d = VolumeScorer.score(resolvedDays: days, scope: .singleSession, profile: intermediate)
        #expect(d.tips.contains { $0.id == "sess-short" })
    }

    @Test func experienceShiftsWeeklyTargets() {
        // 10 weekly sets: in-target for a beginner (10–14), light for advanced (16–20).
        let days = QualityFixtures.resolve([[QualityFixtures.sx("bench", sets: 10)]])
        let beginner = VolumeScorer.score(resolvedDays: days, scope: .weeklySplit,
                                          profile: .init(goal: .hypertrophy, experience: .beginner))
        let advanced = VolumeScorer.score(resolvedDays: days, scope: .weeklySplit,
                                          profile: .init(goal: .hypertrophy, experience: .advanced))
        #expect(beginner.score > advanced.score)
    }

    @Test func unknownExercisesFallBackNeutral() {
        let days = QualityFixtures.resolve([[ScoredExercise(id: "", name: "Mystery Move", sets: 4, repsText: "10")]])
        let d = VolumeScorer.score(resolvedDays: days, scope: .singleSession, profile: intermediate)
        #expect(d.score == 70)
        #expect(d.tips.isEmpty)
    }
}
