import Testing
@testable import Elos

struct BalanceScorerTests {
    @Test func weeklyGapsFlaggedForMissingMajors() {
        let days = QualityFixtures.resolve([[QualityFixtures.sx("bench", sets: 12)]])
        let d = BalanceScorer.score(resolvedDays: days, scope: .weeklySplit,
                                    dayNames: [""], catalog: QualityFixtures.catalog)
        #expect(d.tips.contains { $0.id == "bal-gap-back" })
        #expect(d.tips.contains { $0.id == "bal-gap-legs" })
        #expect(d.score < 70)
    }

    @Test func pushPullImbalanceFlagged() {
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 12),
            QualityFixtures.sx("ohp", sets: 8),
            QualityFixtures.sx("row", sets: 3),
        ]])
        let d = BalanceScorer.score(resolvedDays: days, scope: .weeklySplit,
                                    dayNames: [""], catalog: QualityFixtures.catalog)
        #expect(d.tips.contains { $0.id == "bal-pushpull" && $0.severity == .warn })
    }

    @Test func quadWithoutHamstringFlagged() {
        let days = QualityFixtures.resolve([[QualityFixtures.sx("squat", sets: 12)]])
        let d = BalanceScorer.score(resolvedDays: days, scope: .weeklySplit,
                                    dayNames: [""], catalog: QualityFixtures.catalog)
        #expect(d.tips.contains { $0.id == "bal-noham" })
    }

    @Test func focusedSessionGapFlaggedAsInfo() {
        // A "Push Day" with only chest leaves shoulders & arms uncovered.
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("incline", sets: 4),
        ]])
        let d = BalanceScorer.score(resolvedDays: days, scope: .singleSession,
                                    dayNames: ["Push Day"], catalog: QualityFixtures.catalog)
        #expect(d.tips.contains { $0.id.hasPrefix("bal-focusgap-") && $0.severity == .info })
    }

    @Test func unfocusedSingleGroupSessionFlagged() {
        let days = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 3),
            QualityFixtures.sx("incline", sets: 3),
            QualityFixtures.sx("dip", sets: 3),
        ]])
        let d = BalanceScorer.score(resolvedDays: days, scope: .singleSession,
                                    dayNames: [""], catalog: QualityFixtures.catalog)
        #expect(d.tips.contains { $0.id == "bal-single-group" })
    }

    @Test func balancedWeekScoresHigh() {
        let days = QualityFixtures.resolve([
            [QualityFixtures.sx("bench", sets: 6), QualityFixtures.sx("ohp", sets: 6)],
            [QualityFixtures.sx("row", sets: 6), QualityFixtures.sx("pulldown", sets: 6)],
            [QualityFixtures.sx("squat", sets: 6), QualityFixtures.sx("rdl", sets: 6),
             QualityFixtures.sx("curl", sets: 4), QualityFixtures.sx("pushdown", sets: 4),
             QualityFixtures.sx("plank", sets: 3)],
        ])
        let d = BalanceScorer.score(resolvedDays: days, scope: .weeklySplit,
                                    dayNames: ["Push", "Pull", "Legs"], catalog: QualityFixtures.catalog)
        #expect(d.score >= 80)
        #expect(!d.tips.contains { $0.severity == .warn })
    }
}
