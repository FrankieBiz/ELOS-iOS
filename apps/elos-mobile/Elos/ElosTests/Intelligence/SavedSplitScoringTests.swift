import Foundation
import Testing
@testable import Elos

struct SavedSplitScoringTests {

    private func day(_ i: Int, name: String, exercisesJSON: String = "[]",
                     templateID: String = "", isRest: Bool = false) -> UserSplitDayRecord {
        UserSplitDayRecord(splitID: "split-1", orderIndex: i, dayLabel: name,
                          dayName: name, templateID: templateID, isRest: isRest,
                          exercisesJSON: exercisesJSON)
    }

    private func encoded(_ exercises: [DayExercise]) -> String {
        let data = try? JSONEncoder().encode(exercises)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    @Test func resolvesAdHocExercisesOverTemplate() {
        let adHoc = [DayExercise(id: "bench", name: "Barbell Bench Press", sets: 4, reps: "6-10")]
        let d = day(0, name: "Push", exercisesJSON: encoded(adHoc), templateID: "some-template")
        let resolved = SavedSplitScoring.dayExercises(for: d) { _ in
            [TemplateExerciseRecord(ownerID: "u", templateID: "some-template",
                                    exerciseID: "squat", exerciseName: "Back Squat", orderIndex: 0)]
        }
        #expect(resolved.map(\.id) == ["bench"])
        #expect(!SavedSplitScoring.isTemplateBacked(d))
    }

    @Test func fallsBackToTemplateWhenExercisesJSONIsAnEmptyArray() {
        let d = day(0, name: "Push", exercisesJSON: "[]", templateID: "tmpl-1")
        let resolved = SavedSplitScoring.dayExercises(for: d) { _ in
            [TemplateExerciseRecord(ownerID: "u", templateID: "tmpl-1",
                                    exerciseID: "squat", exerciseName: "Back Squat", orderIndex: 0)]
        }
        #expect(resolved.map(\.id) == ["squat"])
        #expect(SavedSplitScoring.isTemplateBacked(d))
    }

    @Test func fallsBackToTemplateWhenExercisesJSONIsAnEmptyString() {
        let d = day(0, name: "Push", exercisesJSON: "", templateID: "tmpl-1")
        let resolved = SavedSplitScoring.dayExercises(for: d) { _ in
            [TemplateExerciseRecord(ownerID: "u", templateID: "tmpl-1",
                                    exerciseID: "squat", exerciseName: "Back Squat", orderIndex: 0)]
        }
        #expect(resolved.map(\.id) == ["squat"])
        #expect(SavedSplitScoring.isTemplateBacked(d))
    }

    @Test func fallsBackToTemplateWhenExercisesJSONIsMalformed() {
        let d = day(0, name: "Push", exercisesJSON: "{not json", templateID: "tmpl-1")
        let resolved = SavedSplitScoring.dayExercises(for: d) { _ in
            [TemplateExerciseRecord(ownerID: "u", templateID: "tmpl-1",
                                    exerciseID: "squat", exerciseName: "Back Squat", orderIndex: 0)]
        }
        #expect(resolved.map(\.id) == ["squat"])
        #expect(SavedSplitScoring.isTemplateBacked(d))
    }

    @Test func restDaysContributeNoExercises() {
        let adHoc = [DayExercise(id: "bench", name: "Barbell Bench Press", sets: 4, reps: "6-10")]
        let days = [day(0, name: "Push", exercisesJSON: encoded(adHoc)),
                   day(1, name: "Rest", isRest: true)]
        let report = SavedSplitScoring.report(days: days, templateExercises: { _ in [] },
                                              catalog: QualityFixtures.catalog,
                                              profile: QualityFixtures.intermediate,
                                              intent: .default)
        // A rest day must contribute zero credit even if its exercisesJSON somehow held data.
        #expect(report.volume.sets(for: .chest) == 4)
    }

    @Test func producesTheSameReportAsTheBuilderForEquivalentInput() {
        let pushExercises = [DayExercise(id: "bench", name: "Barbell Bench Press", sets: 4, reps: "6-10"),
                             DayExercise(id: "ohp", name: "Overhead Press", sets: 3, reps: "6-10")]
        let pullExercises = [DayExercise(id: "row", name: "Barbell Row", sets: 4, reps: "6-10"),
                             DayExercise(id: "pulldown", name: "Lat Pulldown", sets: 3, reps: "6-10")]
        let legExercises = [DayExercise(id: "squat", name: "Back Squat", sets: 4, reps: "5-8"),
                            DayExercise(id: "rdl", name: "Romanian Deadlift", sets: 3, reps: "6-10")]

        // Builder side — @State-shaped, real day names as CreateSplitView would hold them
        // (weekday-default days go in as "").
        let builderDays: [[ScoredExercise]] = [pushExercises, pullExercises, legExercises]
            .map { $0.map(ScoredExercise.init(day:)) }
        let builderReport = TemplateQualityEngine.score(
            days: builderDays, dayNames: ["", "", ""], scope: .weeklySplit,
            profile: QualityFixtures.intermediate, catalog: QualityFixtures.catalog,
            intent: .default, dayExclusions: [[], [], []], dayIsRest: [false, false, false])

        // Record side — the REAL stored dayName values (never "" — see UserSplitDayRecord's
        // resolved-at-save-time dayName), which is the case this test exists to prove is equivalent.
        let recordDays = [day(0, name: "Monday", exercisesJSON: encoded(pushExercises)),
                          day(1, name: "Tuesday", exercisesJSON: encoded(pullExercises)),
                          day(2, name: "Wednesday", exercisesJSON: encoded(legExercises))]
        let recordReport = SavedSplitScoring.report(days: recordDays, templateExercises: { _ in [] },
                                                    catalog: QualityFixtures.catalog,
                                                    profile: QualityFixtures.intermediate,
                                                    intent: .default)

        #expect(builderReport.overall == recordReport.overall)
    }
}
