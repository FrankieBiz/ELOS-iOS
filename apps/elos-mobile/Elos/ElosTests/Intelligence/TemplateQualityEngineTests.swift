import Testing
@testable import Elos

struct TemplateQualityEngineTests {
    private let profile = TrainingProfile(goal: .hypertrophy, experience: .intermediate)

    @Test func tooFewExercisesNotScored() {
        let r = TemplateQualityEngine.score(days: [[QualityFixtures.sx("bench", sets: 3)]],
                                            dayNames: [""], scope: .singleSession,
                                            profile: profile, catalog: QualityFixtures.catalog)
        #expect(!r.isScored)
        #expect(r == .empty)
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
        #expect(r.dimensions.count == 4)
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
}
