import Testing
@testable import Elos

struct QualityFixEngineTests {

    private func makeTip(id: String) -> QualityTip {
        QualityTip(id: id, dimension: .balance, severity: .info, message: "", action: .noAction)
    }

    private func context(days: [[ScoredExercise]], dayNames: [String],
                         dayIsRest: [Bool]? = nil,
                         dayExcludedMuscles: [Set<FineMuscle>]? = nil,
                         scope: QualityScope = .weeklySplit,
                         catalog: [ExerciseCandidate] = QualityFixtures.catalog,
                         profile: TrainingProfile = QualityFixtures.intermediate,
                         intent: TrainingIntent = .default) -> QualityFixEngine.Context {
        QualityFixEngine.Context(
            days: days, dayNames: dayNames,
            dayIsRest: dayIsRest ?? Array(repeating: false, count: days.count),
            dayExcludedMuscles: dayExcludedMuscles ?? Array(repeating: [], count: days.count),
            scope: scope, profile: profile, intent: intent, catalog: catalog,
            personalization: PersonalizationProvider(signals: .init()),
            equipmentPreference: .fullGym)
    }

    private func currentReport(_ ctx: QualityFixEngine.Context) -> QualityReport {
        TemplateQualityEngine.score(days: ctx.days, dayNames: ctx.dayNames, scope: ctx.scope,
                                    profile: ctx.profile, catalog: ctx.catalog, intent: ctx.intent,
                                    dayExclusions: ctx.dayExcludedMuscles, dayIsRest: ctx.dayIsRest)
    }

    // MARK: canFix whitelist

    @Test func canFixMatchesTheSpecWhitelist() {
        let fixable = ["bal-gap-back", "bal-focusgap-back", "bal-noham",
                       "vol-low-chest", "vol-light-chest", "sel-hinge", "sel-order",
                       "fatigue-order-0", "rr-reps", "rr-rest"]
        let notFixable = ["vol-high-chest", "vol-more", "sess-junk-chest", "sess-short",
                          "sess-long", "bal-pushpull", "bal-quadham", "bal-single-group",
                          "sel-compound", "fatigue-long-0", "freq-once-chest"]
        for id in fixable {
            #expect(QualityFixEngine.canFix(makeTip(id: id)), "\(id) should be fixable")
        }
        for id in notFixable {
            #expect(!QualityFixEngine.canFix(makeTip(id: id)), "\(id) should not be fixable")
        }
    }

    // MARK: Insert fixes

    @Test func aBalGapProposalGenuinelyClearsTheTargetedTip() {
        // No back work anywhere in the week (bench/squat/curl/pushdown never touch lats/upperBack/
        // lowerBack/rearDelts) -> bal-gap-back should fire, then clear after the fix.
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("bench", sets: 4), QualityFixtures.sx("squat", sets: 4)],
            [QualityFixtures.sx("curl", sets: 4), QualityFixtures.sx("pushdown", sets: 4)],
        ]
        let ctx = context(days: days, dayNames: ["Day1", "Day2"])
        let before = currentReport(ctx)
        let tip = before.tips.first { $0.id == "bal-gap-back" }
        #expect(tip != nil)
        let proposal = QualityFixEngine.propose(for: tip!, context: ctx)
        #expect(proposal?.resolvesTip == true)
        #expect(proposal!.after.tips.contains { $0.id == "bal-gap-back" } == false)
    }

    @Test func aSelOrderProposalOnASecondDayCountsAsResolvedEvenThoughIdRepeats() {
        // Day 0 and Day 2 both have an isolation exercise before a compound one; SelectionScorer's
        // loop surfaces only the FIRST offending day (dayIndex 0) under the constant id "sel-order".
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("pushdown", sets: 4), QualityFixtures.sx("bench", sets: 4)],
            [QualityFixtures.sx("squat", sets: 4), QualityFixtures.sx("legpress", sets: 4)],
            [QualityFixtures.sx("curl", sets: 4), QualityFixtures.sx("row", sets: 4)],
        ]
        let ctx = context(days: days, dayNames: ["Day1", "Day2", "Day3"])
        let before = currentReport(ctx)
        let tip = before.tips.first { $0.id == "sel-order" }
        #expect(tip != nil)
        if case .reorder(let dayIndex) = tip!.action { #expect(dayIndex == 0) }

        let proposal = QualityFixEngine.propose(for: tip!, context: ctx)
        #expect(proposal?.resolvesTip == true)
        // Day 2's inversion re-emits the SAME id with a DIFFERENT action (dayIndex 2) — must not be
        // mistaken for "day 0's problem is still there."
        let after = proposal!.after
        let stillDay0 = after.tips.contains { $0.id == "sel-order" && $0.action == .reorder(dayIndex: 0) }
        #expect(!stillDay0)
    }

    @Test func reorderProposalTouchesOnlyItsOwnDay() {
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("pushdown", sets: 4), QualityFixtures.sx("bench", sets: 4)],
            [QualityFixtures.sx("squat", sets: 4), QualityFixtures.sx("legpress", sets: 4)],
        ]
        let ctx = context(days: days, dayNames: ["Day1", "Day2"])
        let tip = QualityTip(id: "sel-order", dimension: .selection, severity: .info,
                             message: "", action: .reorder(dayIndex: 0))
        let proposal = QualityFixEngine.propose(for: tip, context: ctx)
        #expect(proposal != nil)
        if case .reorderDay(let dayIndex, let permutation) = proposal!.operations.first {
            #expect(dayIndex == 0)
            #expect(Set(permutation) == Set(0..<2))
        } else {
            Issue.record("expected a reorderDay operation for day 0")
        }
    }

    /// `VolumeScorer.weekly` grades each muscle by *status bucket* (under/light/productive/…), not
    /// a continuous fraction — so a capped partial dose that doesn't cross into the next bucket
    /// moves the score by exactly zero. When the shortfall is severe enough that
    /// `maxAutoFixSetsPerExercise` can't cross that boundary, the fix genuinely doesn't help by the
    /// engine's own measure, and `propose` correctly suppresses it rather than offering a fix with
    /// no real benefit. Chest mev is 8 (intermediate); starting at 2 sets (still direct-trained, so
    /// VolumeScorer grades it — untrained muscles are BalanceScorer's job) plus a capped 5-set
    /// insert reaches 7, still short of the 8-set `.under` threshold.
    @Test func doseFixThatCannotHelpAtAllIsSuppressed() {
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("squat", sets: 10), QualityFixtures.sx("rdl", sets: 10)],
            [QualityFixtures.sx("curl", sets: 8), QualityFixtures.sx("pushdown", sets: 8)],
            [QualityFixtures.sx("incline", sets: 2)],
        ]
        let ctx = context(days: days, dayNames: ["Legs", "Arms", "Push"])
        let before = currentReport(ctx)
        let tip = before.tips.first { $0.id == "vol-low-chest" }
        #expect(tip != nil)
        #expect(QualityFixEngine.propose(for: tip!, context: ctx) == nil)
    }

    /// The reachable "dose fix helps" case: enough headroom that the capped insert crosses chest
    /// from `.under` into the `.light` bucket. Because the tip id itself encodes the status bucket
    /// (`vol-low-*` only exists while `.under`), crossing the boundary both raises the score AND
    /// clears the exact `(id, action)` this proposal targeted — a real, verifiable success rather
    /// than a partial one.
    @Test func doseFixThatCrossesAStatusBucketResolvesAndImproves() {
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("squat", sets: 10), QualityFixtures.sx("rdl", sets: 10)],
            [QualityFixtures.sx("curl", sets: 8), QualityFixtures.sx("pushdown", sets: 8)],
            [QualityFixtures.sx("incline", sets: 6)],
        ]
        let ctx = context(days: days, dayNames: ["Legs", "Arms", "Push"])
        let before = currentReport(ctx)
        let tip = before.tips.first { $0.id == "vol-low-chest" }
        #expect(tip != nil)
        let proposal = QualityFixEngine.propose(for: tip!, context: ctx)
        #expect(proposal != nil)
        #expect(proposal?.resolvesTip == true)
        #expect((proposal?.after.overall ?? 0) > (proposal?.before.overall ?? 0))
        if case .insertExercise(let spec) = proposal!.operations.first {
            #expect(spec.sets <= TrainingScience.maxAutoFixSetsPerExercise)
        } else {
            Issue.record("expected an insertExercise operation")
        }
    }

    @Test func proposeReturnsNilWhenNoCandidateTrainsTheMuscle() {
        // A catalog with no core-training exercise at all.
        let noCoreCatalog = QualityFixtures.catalog.filter { $0.id != "plank" }
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("bench", sets: 4), QualityFixtures.sx("row", sets: 4)],
            [QualityFixtures.sx("squat", sets: 4), QualityFixtures.sx("rdl", sets: 4)],
        ]
        let ctx = context(days: days, dayNames: ["Day1", "Day2"], catalog: noCoreCatalog)
        let tip = QualityTip(id: "bal-gap-core", dimension: .balance, severity: .info,
                             message: "", action: .addMuscle("core"))
        #expect(QualityFixEngine.propose(for: tip, context: ctx) == nil)
    }

    @Test func proposeReturnsNilForANonFixableTip() {
        let ctx = context(days: [[QualityFixtures.sx("bench", sets: 4)]], dayNames: ["Day1"])
        let tip = QualityTip(id: "vol-high-chest", dimension: .volume, severity: .warn,
                             message: "", action: .noAction)
        #expect(QualityFixEngine.propose(for: tip, context: ctx) == nil)
    }

    // MARK: Tier 2

    @Test func tier2RetuneMovesRrRepsOutOfTheTipList() {
        let strengthProfile = TrainingProfile(goal: .strength, experience: .intermediate)
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("bench", sets: 4, reps: "20-25"), QualityFixtures.sx("ohp", sets: 4, reps: "20-25")],
        ]
        let ctx = context(days: days, dayNames: ["Push Day"], scope: .singleSession, profile: strengthProfile)
        let before = currentReport(ctx)
        let tip = before.tips.first { $0.id == "rr-reps" }
        #expect(tip != nil)
        let proposal = QualityFixEngine.propose(for: tip!, context: ctx)
        #expect(proposal?.resolvesTip == true)
        #expect(proposal!.after.tips.contains { $0.id == "rr-reps" } == false)
    }

    @Test func tier2RetuneRestMovesRrRestOutOfTheTipList() {
        let strengthProfile = TrainingProfile(goal: .strength, experience: .intermediate)
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("bench", sets: 4, reps: "5", rest: 30), QualityFixtures.sx("ohp", sets: 4, reps: "5", rest: 30)],
        ]
        let ctx = context(days: days, dayNames: ["Push Day"], scope: .singleSession, profile: strengthProfile)
        let before = currentReport(ctx)
        let tip = before.tips.first { $0.id == "rr-rest" }
        #expect(tip != nil)
        let proposal = QualityFixEngine.propose(for: tip!, context: ctx)
        #expect(proposal?.resolvesTip == true)
        #expect(proposal!.after.tips.contains { $0.id == "rr-rest" } == false)
    }
}
