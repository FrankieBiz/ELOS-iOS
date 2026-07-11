import Testing
@testable import Elos

struct SplitDescriptorTests {
    private func day(_ name: String = "", rest: Bool = false,
                     _ exercises: [(String, Int)] = []) -> DescriptorDayInput {
        DescriptorDayInput(isRest: rest, dayName: name, exercises: exercises)
    }

    // MARK: Day classification

    @Test func restDayClassified() {
        #expect(SplitDescriptor.classify(day(rest: true)) == .rest)
    }

    @Test func emptyTrainingDayReadsAsRest() {
        #expect(SplitDescriptor.classify(day()) == .rest)
    }

    @Test func dayNameWinsOverExercises() {
        // Named "Pull Day" even though exercises alone would read as legs.
        let d = day("Pull Day", [("squat", 4), ("leg press", 3)])
        #expect(SplitDescriptor.classify(d) == .pull)
    }

    @Test func pushDayFromExercises() {
        let d = day("", [("bench press", 4), ("overhead press", 3), ("tricep pushdown", 3)])
        #expect(SplitDescriptor.classify(d) == .push)
    }

    @Test func pullDayFromExercises() {
        let d = day("", [("barbell row", 4), ("lat pulldown", 3), ("bicep curl", 3)])
        #expect(SplitDescriptor.classify(d) == .pull)
    }

    @Test func legDayFromExercises() {
        let d = day("", [("squat", 4), ("leg press", 3), ("leg curl", 3), ("calf raise", 3)])
        #expect(SplitDescriptor.classify(d) == .legs)
    }

    @Test func upperDayFromExercises() {
        let d = day("", [("bench press", 4), ("barbell row", 4), ("lateral raise", 3), ("bicep curl", 3)])
        #expect(SplitDescriptor.classify(d) == .upper)
    }

    @Test func fullBodyDayFromExercises() {
        let d = day("", [("squat", 4), ("bench press", 4), ("barbell row", 4)])
        #expect(SplitDescriptor.classify(d) == .fullBody)
    }

    @Test func armDayFromExercises() {
        let d = day("", [("bicep curl", 4), ("tricep pushdown", 4), ("hammer curl", 3), ("skullcrusher", 3)])
        #expect(SplitDescriptor.classify(d) == .arms)
    }

    // MARK: Archetypes

    @Test func pplArchetype() {
        let desc = SplitDescriptor.describe(days: [
            day("Push"), day("Pull"), day("Legs"),
            day(rest: true), day("Push"), day("Pull"), day(rest: true),
        ].map { $0.isRest ? $0 : self.nonEmpty($0) })
        #expect(desc.archetype == "Push / Pull / Legs")
        #expect(desc.trainingDaysPerWeek == 5)
    }

    @Test func upperLowerArchetype() {
        let desc = SplitDescriptor.describe(days: [
            nonEmpty(day("Upper")), nonEmpty(day("Lower")),
            day(rest: true),
            nonEmpty(day("Upper")), nonEmpty(day("Lower")),
            day(rest: true), day(rest: true),
        ])
        #expect(desc.archetype == "Upper / Lower")
        #expect(desc.trainingDaysPerWeek == 4)
    }

    @Test func fullBodyArchetype() {
        let desc = SplitDescriptor.describe(days: [
            nonEmpty(day("Full Body")), day(rest: true), nonEmpty(day("Full Body")),
            day(rest: true), nonEmpty(day("Full Body")), day(rest: true), day(rest: true),
        ])
        #expect(desc.archetype == "Full Body")
    }

    @Test func broSplitArchetype() {
        let desc = SplitDescriptor.describe(days: [
            nonEmpty(day("Chest")), nonEmpty(day("Back")), nonEmpty(day("Shoulders")),
            nonEmpty(day("Legs")), nonEmpty(day("Arms")), day(rest: true), day(rest: true),
        ])
        #expect(desc.archetype == "Bro Split")
    }

    @Test func allRestIsRestWeek() {
        let desc = SplitDescriptor.describe(days: Array(repeating: day(rest: true), count: 7))
        #expect(desc.archetype == "Rest Week")
        #expect(desc.trainingDaysPerWeek == 0)
    }

    // MARK: Summary stats

    @Test func summaryLineAndStats() {
        let desc = SplitDescriptor.describe(days: [
            day("Push", [("bench press", 4), ("overhead press", 3), ("tricep pushdown", 3)]),
            day("Pull", [("barbell row", 4), ("lat pulldown", 3), ("bicep curl", 3)]),
            day("Legs", [("squat", 4), ("leg curl", 3), ("calf raise", 3)]),
            day(rest: true), day(rest: true), day(rest: true), day(rest: true),
        ])
        #expect(desc.trainingDaysPerWeek == 3)
        #expect(desc.totalWeeklySets == 30)
        #expect(desc.estimatedMinutesPerSession == 30)
        #expect(desc.summaryLine == "3 Days · Push / Pull / Legs · ~30 min")
    }

    @Test func topMusclesRankedBySets() {
        let desc = SplitDescriptor.describe(days: [
            day("", [("bench press", 10), ("squat", 6), ("bicep curl", 2)]),
        ])
        #expect(desc.topMuscles.first == "Chest")
        #expect(desc.topMuscles.count <= 3)
    }

    // Give a named day one exercise so name-based classification is exercised
    // through the full describe() path.
    private func nonEmpty(_ d: DescriptorDayInput) -> DescriptorDayInput {
        DescriptorDayInput(isRest: d.isRest, dayName: d.dayName, exercises: [("bench press", 3)])
    }
}
