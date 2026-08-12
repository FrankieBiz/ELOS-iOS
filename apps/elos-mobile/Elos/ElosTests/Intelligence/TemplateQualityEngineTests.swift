import Testing
@testable import Elos

struct TemplateQualityEngineTests {
    private let profile = TrainingProfile(goal: .hypertrophy, experience: .intermediate)

    @Test func tooFewExercisesNotScored() {
        let r = TemplateQualityEngine.score(days: [[QualityFixtures.sx("bench", sets: 3)]],
                                            dayNames: [""], scope: .singleSession,
                                            profile: profile, catalog: QualityFixtures.catalog)
        #expect(!r.isScored)
        #expect(r.overall == 0)
        #expect(r.dimensions.isEmpty)
        // The coverage bars are still produced while unscored, so they can fill in as you build.
        #expect(r.volume.bars.count == MuscleGroup.allCases.count)
    }

    @Test func splitNeedsThreeExercises() {
        let r = TemplateQualityEngine.score(
            days: [[QualityFixtures.sx("bench", sets: 3)], [QualityFixtures.sx("row", sets: 3)]],
            dayNames: ["Push", "Pull"], scope: .weeklySplit,
            profile: profile, catalog: QualityFixtures.catalog)
        #expect(!r.isScored)
    }

    @Test func wellBuiltSessionScoresHigh() {
        let day = [
            QualityFixtures.sx("bench", sets: 4, reps: "8-10", rest: 120),
            QualityFixtures.sx("ohp", sets: 3, reps: "8-10", rest: 120),
            QualityFixtures.sx("lateral", sets: 3, reps: "12-15", rest: 75),
            QualityFixtures.sx("pushdown", sets: 3, reps: "10-12", rest: 75),
        ]
        let r = TemplateQualityEngine.score(days: [day], dayNames: ["Push Day"],
                                            scope: .singleSession, profile: profile,
                                            catalog: QualityFixtures.catalog)
        #expect(r.isScored)
        #expect(r.overall >= 75)
        #expect(r.tier == .dialedIn || r.tier == .optimized)
        // Five dimensions are computed; frequency doesn't apply to one session, so it's excluded
        // from the scope-filtered view the UI renders and carries zero weight.
        #expect(r.dimensions.count == 5)
        #expect(r.dimensions(for: .singleSession).count == 4)
        #expect(TemplateQualityEngine.weight(.frequency, scope: .singleSession) == 0)
    }

    @Test func poorTemplateScoresLowWithTips() {
        let day = [
            QualityFixtures.sx("curl", sets: 6, reps: "20"),
            QualityFixtures.sx("hammer", sets: 6, reps: "20"),
            QualityFixtures.sx("pushdown", sets: 6, reps: "20"),
        ]
        let r = TemplateQualityEngine.score(days: [day], dayNames: [""],
                                            scope: .singleSession, profile: profile,
                                            catalog: QualityFixtures.catalog)
        #expect(r.isScored)
        #expect(r.overall < 70)
        #expect(!r.tips.isEmpty)
    }

    @Test func sameExercisesScoreDifferentlyByScope() {
        // 3 sets/muscle reads as low *weekly* but acceptable within one *session*.
        let day = [QualityFixtures.sx("bench", sets: 3),
                   QualityFixtures.sx("row", sets: 3),
                   QualityFixtures.sx("squat", sets: 3)]
        let session = TemplateQualityEngine.score(days: [day], dayNames: ["Full Body"],
                                                  scope: .singleSession, profile: profile,
                                                  catalog: QualityFixtures.catalog)
        let week = TemplateQualityEngine.score(days: [day], dayNames: ["Full Body"],
                                               scope: .weeklySplit, profile: profile,
                                               catalog: QualityFixtures.catalog)
        #expect(session.isScored && week.isScored)
        let sessionVol = session.dimensions.first { $0.dimension == .volume }?.score ?? 0
        let weekVol = week.dimensions.first { $0.dimension == .volume }?.score ?? 0
        #expect(sessionVol > weekVol)
    }

    @Test func tipsRankedSeverityFirst() {
        let day = [
            QualityFixtures.sx("curl", sets: 6, reps: "20"),
            QualityFixtures.sx("hammer", sets: 6, reps: "20"),
            QualityFixtures.sx("pushdown", sets: 6, reps: "20"),
        ]
        let r = TemplateQualityEngine.score(days: [day], dayNames: [""],
                                            scope: .singleSession, profile: profile,
                                            catalog: QualityFixtures.catalog)
        // Once an info-level tip appears, no higher-severity warn should follow it.
        if let firstInfo = r.tips.firstIndex(where: { $0.severity == .info }) {
            #expect(!r.tips[firstInfo...].contains { $0.severity == .warn })
        }
    }

    @Test func tipsAreDeduped() {
        let day = [
            QualityFixtures.sx("curl", sets: 6, reps: "20"),
            QualityFixtures.sx("hammer", sets: 6, reps: "20"),
            QualityFixtures.sx("pushdown", sets: 6, reps: "20"),
        ]
        let r = TemplateQualityEngine.score(days: [day], dayNames: [""],
                                            scope: .singleSession, profile: profile,
                                            catalog: QualityFixtures.catalog)
        let ids = r.tips.map { $0.id }
        #expect(Set(ids).count == ids.count)
    }

    @Test func daySpecificExclusionAffectsSingleSessionScore() {
        // Excluding a muscle that's genuinely missing removes the coverage-gap penalty for it.
        let day = [
            QualityFixtures.sx("bench", sets: 4),
            QualityFixtures.sx("incline", sets: 4),
        ]
        let withoutExclusion = TemplateQualityEngine.score(
            days: [day], dayNames: ["Push Day"], scope: .singleSession,
            profile: profile, catalog: QualityFixtures.catalog,
            intent: TrainingIntent(goal: .hypertrophy, focus: .push))
        let withExclusion = TemplateQualityEngine.score(
            days: [day], dayNames: ["Push Day"], scope: .singleSession,
            profile: profile, catalog: QualityFixtures.catalog,
            intent: TrainingIntent(goal: .hypertrophy, focus: .push, excludedMuscles: [.sideDelts, .frontDelts, .rotatorCuff, .biceps, .triceps, .forearms]))
        let gapTips = { (r: QualityReport) in r.tips.filter { $0.id.hasPrefix("bal-focusgap-") } }
        #expect(!gapTips(withoutExclusion).isEmpty)
        #expect(gapTips(withExclusion).isEmpty)
    }

    @Test func dayScopedExclusionDoesNotAffectWeeklySplitScore() {
        // D1: a per-day exclusion must be provably inert at `.weeklySplit` scope, regardless of what
        // the intent passed in carries. This is the direct regression test for that guarantee.
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("bench", sets: 6), QualityFixtures.sx("ohp", sets: 6)],
            [QualityFixtures.sx("row", sets: 6), QualityFixtures.sx("pulldown", sets: 6)],
            [QualityFixtures.sx("squat", sets: 6), QualityFixtures.sx("rdl", sets: 6)],
        ]
        let dayNames = ["Push", "Pull", "Legs"]
        let withoutExclusion = TemplateQualityEngine.score(
            days: days, dayNames: dayNames, scope: .weeklySplit,
            profile: profile, catalog: QualityFixtures.catalog,
            intent: TrainingIntent(goal: .hypertrophy))
        let withExclusion = TemplateQualityEngine.score(
            days: days, dayNames: dayNames, scope: .weeklySplit,
            profile: profile, catalog: QualityFixtures.catalog,
            intent: TrainingIntent(goal: .hypertrophy, excludedMuscles: [.quads, .hamstrings, .chest, .lats]))
        #expect(withoutExclusion.overall == withExclusion.overall)
    }

    @Test func globalExclusionDoesAffectWeeklySplitScore() {
        // Contrast with the test above: the *global* exclusion lever (VolumeOverrides) is not
        // scope-gated — only the day-scoped one (TrainingIntent) is.
        let days: [[ScoredExercise]] = [
            [QualityFixtures.sx("squat", sets: 3)],
        ]
        let dayNames = ["Legs"]
        let withoutExclusion = TemplateQualityEngine.score(
            days: days, dayNames: dayNames, scope: .weeklySplit,
            profile: profile, catalog: QualityFixtures.catalog)
        let excludedProfile = TrainingProfile(
            goal: .hypertrophy, experience: .intermediate,
            volumeOverrides: VolumeOverrides(excludedMuscles: [.quads, .glutes]))
        let withExclusion = TemplateQualityEngine.score(
            days: days, dayNames: dayNames, scope: .weeklySplit,
            profile: excludedProfile, catalog: QualityFixtures.catalog)
        #expect(withoutExclusion.overall != withExclusion.overall)
    }
}
