import Testing
@testable import Elos

struct SelectionScorerTests {
    private let intermediate = TrainingProfile(goal: .hypertrophy, experience: .intermediate)

    /// Score days, building the shared movement profile the scorer now reads.
    private func score(_ days: [[ScoredExercise]],
                       scope: QualityScope = .singleSession,
                       profile: TrainingProfile? = nil,
                       dayNames: [String]? = nil) -> DimensionScore {
        let p = profile ?? intermediate
        let resolved = QualityFixtures.resolve(days)
        let movement = QualityFixtures.movement(resolved, scope: scope, dayNames: dayNames)
        return SelectionScorer.score(resolvedDays: resolved, scope: scope,
                                     profile: p, movement: movement)
    }

    @Test func lowCompoundFractionFlagged() {
        let d = score([[
            QualityFixtures.sx("curl", sets: 3),
            QualityFixtures.sx("pushdown", sets: 3),
            QualityFixtures.sx("lateral", sets: 3),
        ]])
        #expect(d.tips.contains { $0.id == "sel-compound" })
    }

    @Test func squatWithoutHingeFlagged() {
        let d = score([[
            QualityFixtures.sx("squat", sets: 4),
            QualityFixtures.sx("legext", sets: 3),
        ]])
        #expect(d.tips.contains { $0.id == "sel-hinge" })
    }

    @Test func isolationBeforeCompoundFlagged() {
        let d = score([[
            QualityFixtures.sx("curl", sets: 3),
            QualityFixtures.sx("row", sets: 4),
        ]])
        #expect(d.tips.contains { $0.id == "sel-order" && $0.action == .reorder(dayIndex: 0) })
    }

    /// The reorder action must name the offending day — at weekly scope there is no implicit "the day".
    @Test func reorderActionCarriesTheOffendingDayIndex() {
        let d = score([
            [QualityFixtures.sx("bench", sets: 4), QualityFixtures.sx("pushdown", sets: 3)],
            [QualityFixtures.sx("curl", sets: 3), QualityFixtures.sx("row", sets: 4)],
        ], scope: .weeklySplit, dayNames: ["Push", "Pull"])
        #expect(d.tips.contains { $0.action == .reorder(dayIndex: 1) })
    }

    @Test func wellSelectedScoresFull() {
        let d = score([[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("row", sets: 4),
            QualityFixtures.sx("lateral", sets: 3),
        ]])
        #expect(d.score == 100)
        #expect(d.tips.isEmpty)
    }

    @Test func compoundFractionThresholdShiftsWithExperience() {
        // 1 compound of 3 = 0.33: passes for advanced, fails the beginner 0.5 bar.
        let days = [[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("lateral", sets: 3),
            QualityFixtures.sx("pushdown", sets: 3),
        ]]
        let beginner = score(days, profile: .init(goal: .hypertrophy, experience: .beginner))
        let advanced = score(days, profile: .init(goal: .hypertrophy, experience: .advanced))
        #expect(beginner.tips.contains { $0.id == "sel-compound" })
        #expect(!advanced.tips.contains { $0.id == "sel-compound" })
    }

    /// Selection scoring reads the by-*count* fraction (what its thresholds were tuned against),
    /// while the UI renders the by-*sets* fraction. Both must be available and distinct.
    @Test func movementProfileReportsBothCompoundFractions() {
        // 1 compound of 2 exercises = 0.5 by count; 8 of 11 sets = ~0.73 by sets.
        let resolved = QualityFixtures.resolve([[
            QualityFixtures.sx("bench", sets: 8),
            QualityFixtures.sx("pushdown", sets: 3),
        ]])
        let m = QualityFixtures.movement(resolved, scope: .singleSession)
        #expect(m.compoundFractionByCount == 0.5)
        #expect(m.compoundFractionBySets > 0.7)
        #expect(m.compoundSets == 8)
        #expect(m.isolationSets == 3)
    }

    /// Patterns outside the production vocabulary (the fixtures use `curl`, `raise`, `pushdown`,
    /// `extension`) must bucket as isolation rather than vanish from the breakdown.
    @Test func offVocabularyPatternsBucketAsIsolation() {
        let resolved = QualityFixtures.resolve([[
            QualityFixtures.sx("curl", sets: 3),      // pattern "curl"
            QualityFixtures.sx("lateral", sets: 2),   // pattern "raise"
        ]])
        let m = QualityFixtures.movement(resolved, scope: .singleSession)
        #expect(m.setsByPattern["isolation"] == 5)
        #expect(m.setsByPattern["curl"] == nil)
    }

    @Test func missingHingeReportedForALegDay() {
        let resolved = QualityFixtures.resolve([[
            QualityFixtures.sx("squat", sets: 4),
            QualityFixtures.sx("legext", sets: 3),
        ]])
        let m = QualityFixtures.movement(resolved, scope: .singleSession,
                                         intent: TrainingIntent(goal: .hypertrophy, focus: .legs))
        #expect(m.missingPatterns.contains("hinge"))
        #expect(!m.missingPatterns.contains("squat"))
    }
}
