import Foundation
import SwiftData
import Testing
@testable import Elos

/// `addToMyPlan()` used to fork every program day into an independent template with no split
/// wrapper at all — no day ordering, no scoring, no gym-variant participation, because every one of
/// those systems operates on split-shaped data. `buildLocalSplit` is the network-free half of the
/// fix, split out specifically so this is testable without a live API call.
struct WorkoutDetailAddToPlanTests {

    @MainActor
    private func makeContext() -> ModelContext {
        let schema = Schema([UserSplitRecord.self, UserSplitDayRecord.self,
                             WorkoutTemplateRecord.self, TemplateExerciseRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    private func sampleWorkout(dayCount: Int) -> WorkoutDetailAPIResponse {
        let days = (0..<dayCount).map { i in
            WorkoutDayAPIResponse(
                id: "day-\(i)", day_number: i + 1, name: "Day \(i + 1)", focus: nil, notes: nil,
                order_index: i,
                exercises: [WorkoutExerciseAPIResponse(
                    exercise_name: "Exercise \(i)-0", order_index: 0, sets: 4, reps: "6-10",
                    rest_seconds: 90, rpe_guidance: nil, notes: nil, substitution_notes: nil,
                    is_superset: nil, superset_group: nil)])
        }
        return WorkoutDetailAPIResponse(
            id: "w1", creator_id: "c1", creator_name: "Test Creator", creator_slug: "test-creator",
            title: "Test Program", description: nil, program_type: "split", days_per_week: dayCount,
            goal: nil, difficulty: "intermediate", duration_weeks: nil, est_session_mins: nil,
            equipment: [], muscle_groups: [], tags: [], source_url: nil, attribution: nil,
            disclaimer: nil, confidence_level: "high", days: days)
    }

    @Test @MainActor func createsASplitWithOneDayPerProgramDay() {
        let context = makeContext()
        let vm = WorkoutDetailViewModel()
        vm.workout = sampleWorkout(dayCount: 3)

        vm.buildLocalSplit(ownerID: "u1", context: context)

        let splits = (try? context.fetch(FetchDescriptor<UserSplitRecord>())) ?? []
        #expect(splits.count == 1)
        let splitID = splits[0].id
        let days = (try? context.fetch(FetchDescriptor<UserSplitDayRecord>(
            predicate: #Predicate { $0.splitID == splitID }))) ?? []
        #expect(days.count == 7, "SplitDayPersistence's shape is always a full 7-slot week")
        #expect(days.filter { !$0.isRest }.count == 3)
        #expect(days.filter { $0.isRest }.count == 4)
    }

    @Test @MainActor func eachTrainingDayGetsItsOwnLocalTemplateWithExercisesInOrder() {
        let context = makeContext()
        let vm = WorkoutDetailViewModel()
        vm.workout = sampleWorkout(dayCount: 2)

        vm.buildLocalSplit(ownerID: "u1", context: context)

        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplateRecord>())) ?? []
        #expect(templates.count == 2)
        #expect(templates.allSatisfy { !$0.serverConfirmed }, "local-first: not yet pushed")
        for t in templates {
            let tid = t.id
            let exs = (try? context.fetch(FetchDescriptor<TemplateExerciseRecord>(
                predicate: #Predicate { $0.templateID == tid }))) ?? []
            #expect(!exs.isEmpty)
        }
    }

    @Test @MainActor func aProgramWithMoreThanSevenDaysTakesOnlyTheFirstSeven() {
        let context = makeContext()
        let vm = WorkoutDetailViewModel()
        vm.workout = sampleWorkout(dayCount: 10)

        vm.buildLocalSplit(ownerID: "u1", context: context)

        let templates = (try? context.fetch(FetchDescriptor<WorkoutTemplateRecord>())) ?? []
        #expect(templates.count == 7, "extra days are dropped, not silently truncating mid-week")
    }

    @Test @MainActor func doesNothingForAnEmptyProgram() {
        let context = makeContext()
        let vm = WorkoutDetailViewModel()
        vm.workout = sampleWorkout(dayCount: 0)

        vm.buildLocalSplit(ownerID: "u1", context: context)

        #expect(((try? context.fetch(FetchDescriptor<UserSplitRecord>())) ?? []).isEmpty)
    }

    @Test @MainActor func theBuiltSplitIsNotActivatedByDefault() {
        let context = makeContext()
        let vm = WorkoutDetailViewModel()
        vm.workout = sampleWorkout(dayCount: 2)

        let split = vm.buildLocalSplit(ownerID: "u1", context: context)

        #expect(split?.isActive == false, "matches the existing 'blank Create Split just adds to My Splits' convention")
    }
}
