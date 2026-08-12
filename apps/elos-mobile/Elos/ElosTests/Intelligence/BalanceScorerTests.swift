import Testing
@testable import Elos

struct BalanceScorerTests {

    /// Score days at a scope, building the shared muscle report the scorer now reads.
    private func score(_ days: [[ScoredExercise]],
                       scope: QualityScope,
                       dayNames: [String],
                       intent: TrainingIntent? = nil,
                       excludedMuscles: Set<FineMuscle> = []) -> DimensionScore {
        let resolved = QualityFixtures.resolve(days)
        let volume = QualityFixtures.volume(resolved, scope: scope,
                                            intent: intent, dayNames: dayNames)
        return BalanceScorer.score(resolvedDays: resolved, scope: scope, dayNames: dayNames,
                                   intent: intent, volume: volume,
                                   catalog: QualityFixtures.catalog,
                                   excludedMuscles: excludedMuscles)
    }

    @Test func weeklyGapsFlaggedForMissingMajors() {
        let d = score([[QualityFixtures.sx("bench", sets: 12)]],
                      scope: .weeklySplit, dayNames: [""])
        #expect(d.tips.contains { $0.id == "bal-gap-back" })
        #expect(d.tips.contains { $0.id == "bal-gap-legs" })
        #expect(d.score < 70)
    }

    /// A group reached only by secondary work is a softer problem than a true blind spot — it should
    /// be reported as "indirect only", not "no work at all".
    @Test func indirectOnlyGroupFlaggedAsInfoNotWarn() {
        // Bench gives the triceps indirect volume but no direct arm work.
        let d = score([[QualityFixtures.sx("bench", sets: 12)]],
                      scope: .weeklySplit, dayNames: [""])
        let armsTip = d.tips.first { $0.id == "bal-gap-arms" }
        #expect(armsTip?.severity == .info)
        #expect(armsTip?.message.contains("indirect") == true)
        // Legs get nothing at all, so they stay a hard warning.
        #expect(d.tips.first { $0.id == "bal-gap-legs" }?.severity == .warn)
    }

    @Test func pushPullImbalanceFlagged() {
        let d = score([[
            QualityFixtures.sx("bench", sets: 12),
            QualityFixtures.sx("ohp", sets: 8),
            QualityFixtures.sx("row", sets: 3),
        ]], scope: .weeklySplit, dayNames: [""])
        #expect(d.tips.contains { $0.id == "bal-pushpull" && $0.severity == .warn })
    }

    @Test func quadWithoutHamstringFlagged() {
        let d = score([[QualityFixtures.sx("squat", sets: 12)]],
                      scope: .weeklySplit, dayNames: [""])
        #expect(d.tips.contains { $0.id == "bal-noham" })
    }

    /// Hip thrusts train the hamstrings only secondarily, so "no *direct* hamstring work" is still
    /// the right call — and the wording must say so, to match what the bar shows.
    @Test func hipThrustAloneStillCountsAsNoDirectHamstringWork() {
        let d = score([[
            QualityFixtures.sx("squat", sets: 6),
            QualityFixtures.sx("hipthrust", sets: 6),
        ]], scope: .weeklySplit, dayNames: [""])
        let tip = d.tips.first { $0.id == "bal-noham" }
        #expect(tip != nil)
        #expect(tip?.message.contains("direct") == true)
    }

    @Test func focusedSessionGapFlaggedAsInfo() {
        // A "Push Day" with only chest leaves shoulders & arms uncovered.
        let d = score([[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("incline", sets: 4),
        ]], scope: .singleSession, dayNames: ["Push Day"])
        #expect(d.tips.contains { $0.id.hasPrefix("bal-focusgap-") && $0.severity == .info })
    }

    /// Explicit intent should drive focus even when the day name says nothing.
    @Test func explicitIntentSuppliesFocusWithoutDayName() {
        let d = score([[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("incline", sets: 4),
        ]], scope: .singleSession, dayNames: [""],
            intent: TrainingIntent(goal: .hypertrophy, focus: .push))
        #expect(d.tips.contains { $0.id.hasPrefix("bal-focusgap-") })
    }

    @Test func unfocusedSingleGroupSessionFlagged() {
        let d = score([[
            QualityFixtures.sx("bench", sets: 3),
            QualityFixtures.sx("incline", sets: 3),
            QualityFixtures.sx("dip", sets: 3),
        ]], scope: .singleSession, dayNames: [""])
        #expect(d.tips.contains { $0.id == "bal-single-group" })
    }

    @Test func balancedWeekScoresHigh() {
        let d = score([
            [QualityFixtures.sx("bench", sets: 6), QualityFixtures.sx("ohp", sets: 6)],
            [QualityFixtures.sx("row", sets: 6), QualityFixtures.sx("pulldown", sets: 6)],
            [QualityFixtures.sx("squat", sets: 6), QualityFixtures.sx("rdl", sets: 6),
             QualityFixtures.sx("curl", sets: 4), QualityFixtures.sx("pushdown", sets: 4),
             QualityFixtures.sx("plank", sets: 3)],
        ], scope: .weeklySplit, dayNames: ["Push", "Pull", "Legs"])
        #expect(d.score >= 80)
        #expect(!d.tips.contains { $0.severity == .warn })
    }

    @Test func excludingEveryChildOfAMissingGroupSuppressesTheGapTip() {
        let d = score([[QualityFixtures.sx("bench", sets: 12)]],
                      scope: .weeklySplit, dayNames: [""],
                      excludedMuscles: Set(MuscleGroup.legs.children))
        #expect(!d.tips.contains { $0.id == "bal-gap-legs" })
        // Back is untouched — still missing, still flagged.
        #expect(d.tips.contains { $0.id == "bal-gap-back" })
    }

    @Test func excludingOnlySomeChildrenOfAGroupDoesNotSuppressTheGapTip() {
        // Excluding calves alone doesn't excuse "no legs work at all" — quads/hamstrings are still
        // expected.
        let d = score([[QualityFixtures.sx("bench", sets: 12)]],
                      scope: .weeklySplit, dayNames: [""],
                      excludedMuscles: [.calves])
        #expect(d.tips.contains { $0.id == "bal-gap-legs" })
    }

    @Test func excludingAFocusedSessionsMissingGroupSuppressesTheInfoTip() {
        let d = score([[
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("incline", sets: 4),
        ]], scope: .singleSession, dayNames: ["Push Day"],
            excludedMuscles: [.sideDelts, .frontDelts, .rotatorCuff])
        #expect(!d.tips.contains { $0.id.hasPrefix("bal-focusgap-shoulders") })
    }
}
