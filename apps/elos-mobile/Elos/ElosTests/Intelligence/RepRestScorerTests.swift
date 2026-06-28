import Testing
@testable import Elos

struct RepRestScorerTests {
    @Test func parseRepsHandlesRangesAndSingles() {
        #expect(RepRestScorer.parseReps("8-10") == 8...10)
        #expect(RepRestScorer.parseReps("8–10") == 8...10)   // en-dash
        #expect(RepRestScorer.parseReps("10") == 10...10)
        #expect(RepRestScorer.parseReps("8/side") == 8...8)
        #expect(RepRestScorer.parseReps("AMRAP") == nil)
        #expect(RepRestScorer.parseReps("Failure") == nil)
    }

    @Test func hypertrophyRepsInRangeScoreFull() {
        let p = TrainingProfile(goal: .hypertrophy, experience: .intermediate)
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 4, reps: "8-10"),
            QualityFixtures.sx("row", sets: 4, reps: "10-12"),
        ]])
        let d = RepRestScorer.score(resolvedDays: days, scope: .weeklySplit, profile: p)
        #expect(d.score == 100)
        #expect(d.tips.isEmpty)
    }

    @Test func strengthGoalFlagsHighReps() {
        let p = TrainingProfile(goal: .strength, experience: .intermediate)
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 4, reps: "12-15"),
            QualityFixtures.sx("row", sets: 4, reps: "15"),
        ]])
        let d = RepRestScorer.score(resolvedDays: days, scope: .weeklySplit, profile: p)
        #expect(d.tips.contains { $0.id == "rr-reps" })
        #expect(d.score < 60)
    }

    @Test func goalChangesRepScore() {
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 4, reps: "5"),
            QualityFixtures.sx("row", sets: 4, reps: "5"),
        ]])
        let strength = RepRestScorer.score(resolvedDays: days, scope: .weeklySplit,
                                           profile: .init(goal: .strength, experience: .intermediate))
        let endurance = RepRestScorer.score(resolvedDays: days, scope: .weeklySplit,
                                            profile: .init(goal: .endurance, experience: .intermediate))
        #expect(strength.score > endurance.score)
    }

    @Test func restScoredOnlyForSingleSession() {
        let p = TrainingProfile(goal: .hypertrophy, experience: .intermediate)
        // 600s rest is well outside the hypertrophy window.
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 4, reps: "8-10", rest: 600),
            QualityFixtures.sx("row", sets: 4, reps: "8-10", rest: 600),
        ]])
        let session = RepRestScorer.score(resolvedDays: days, scope: .singleSession, profile: p)
        let week = RepRestScorer.score(resolvedDays: days, scope: .weeklySplit, profile: p)
        #expect(session.tips.contains { $0.id == "rr-rest" })
        #expect(!week.tips.contains { $0.id == "rr-rest" })   // splits don't capture rest
        #expect(week.score == 100)
    }
}
