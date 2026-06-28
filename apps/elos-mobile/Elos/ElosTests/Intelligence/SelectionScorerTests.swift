import Testing
@testable import Elos

struct SelectionScorerTests {
    private let intermediate = TrainingProfile(goal: .hypertrophy, experience: .intermediate)

    @Test func lowCompoundFractionFlagged() {
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("curl", sets: 3),
            QualityFixtures.sx("pushdown", sets: 3),
            QualityFixtures.sx("lateral", sets: 3),
        ]])
        let d = SelectionScorer.score(resolvedDays: days, scope: .singleSession, profile: intermediate)
        #expect(d.tips.contains { $0.id == "sel-compound" })
    }

    @Test func squatWithoutHingeFlagged() {
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("squat", sets: 4),
            QualityFixtures.sx("legext", sets: 3),
        ]])
        let d = SelectionScorer.score(resolvedDays: days, scope: .singleSession, profile: intermediate)
        #expect(d.tips.contains { $0.id == "sel-hinge" })
    }

    @Test func isolationBeforeCompoundFlagged() {
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("curl", sets: 3),
            QualityFixtures.sx("row", sets: 4),
        ]])
        let d = SelectionScorer.score(resolvedDays: days, scope: .singleSession, profile: intermediate)
        #expect(d.tips.contains { $0.id == "sel-order" && $0.action == .reorder })
    }

    @Test func wellSelectedScoresFull() {
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("row", sets: 4),
            QualityFixtures.sx("lateral", sets: 3),
        ]])
        let d = SelectionScorer.score(resolvedDays: days, scope: .singleSession, profile: intermediate)
        #expect(d.score == 100)
        #expect(d.tips.isEmpty)
    }

    @Test func compoundFractionThresholdShiftsWithExperience() {
        // 1 compound of 3 = 0.33: passes for advanced, fails the beginner 0.5 bar.
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("lateral", sets: 3),
            QualityFixtures.sx("pushdown", sets: 3),
        ]])
        let beginner = SelectionScorer.score(resolvedDays: days, scope: .singleSession,
                                             profile: .init(goal: .hypertrophy, experience: .beginner))
        let advanced = SelectionScorer.score(resolvedDays: days, scope: .singleSession,
                                             profile: .init(goal: .hypertrophy, experience: .advanced))
        #expect(beginner.tips.contains { $0.id == "sel-compound" })
        #expect(!advanced.tips.contains { $0.id == "sel-compound" })
    }
}
