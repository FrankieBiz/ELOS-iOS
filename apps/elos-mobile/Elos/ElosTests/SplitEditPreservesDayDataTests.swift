import Foundation
import SwiftData
import Testing
@testable import Elos

/// `SplitDayPersistence.upsertDays` replaced a delete-and-rebuild that regenerated every day
/// row's `id` on every save and would have silently dropped any local-only column the split
/// builder's own `@State` doesn't carry (day variants, added in a later commit — see
/// `DayVariantsTests` for the test that specifically proves `variantsJSON` survives an edit-save,
/// since that column doesn't exist yet at this point in the build). What's provable right now:
/// row identity survives, and an edit still actually takes effect.
struct SplitEditPreservesDayDataTests {

    @MainActor
    private func makeContext() -> ModelContext {
        let schema = Schema([UserSplitDayRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    @Test @MainActor func editingASplitKeepsDayRowIdentityStable() {
        let context = makeContext()
        let day = UserSplitDayRecord(splitID: "split-1", orderIndex: 0, dayLabel: "Monday")
        let originalID = day.id
        context.insert(day)
        try? context.save()

        SplitDayPersistence.upsertDays(
            splitID: "split-1", dayLabels: ["Monday"], dayNames: ["Push"],
            dayTemplateIDs: [""], dayIsRest: [false],
            dayExercises: [[DayExercise(id: "bench", name: "Bench Press")]],
            dayExcludedMuscles: [[]], existing: [day], modelContext: context)

        let rows = (try? context.fetch(FetchDescriptor<UserSplitDayRecord>())) ?? []
        #expect(rows.count == 1)
        #expect(rows.first?.id == originalID)
    }

    @Test @MainActor func editingASplitActuallyUpdatesTheExistingRow() {
        let context = makeContext()
        let day = UserSplitDayRecord(splitID: "split-1", orderIndex: 0, dayLabel: "Monday",
                                     dayName: "Old Name", exercisesJSON: "[]")
        context.insert(day)
        try? context.save()

        SplitDayPersistence.upsertDays(
            splitID: "split-1", dayLabels: ["Monday"], dayNames: ["New Name"],
            dayTemplateIDs: [""], dayIsRest: [false],
            dayExercises: [[DayExercise(id: "row", name: "Barbell Row", sets: 4, reps: "6-10")]],
            dayExcludedMuscles: [[.lowerBack]], existing: [day], modelContext: context)

        #expect(day.dayName == "New Name")
        #expect(day.exercisesJSON.contains("Barbell Row"))
        #expect(day.excludedMuscles == [.lowerBack])
    }

    @Test @MainActor func aDayToggledToRestClearsItsExercisesAndTemplateButKeepsTheRow() {
        let context = makeContext()
        let day = UserSplitDayRecord(splitID: "split-1", orderIndex: 0, dayLabel: "Monday",
                                     dayName: "Push", templateID: "tmpl-1",
                                     exercisesJSON: "[{\"id\":\"bench\",\"name\":\"Bench Press\"}]")
        context.insert(day)
        try? context.save()

        SplitDayPersistence.upsertDays(
            splitID: "split-1", dayLabels: ["Monday"], dayNames: ["Push"],
            dayTemplateIDs: ["tmpl-1"], dayIsRest: [true],
            dayExercises: [[DayExercise(id: "bench", name: "Bench Press")]],
            dayExcludedMuscles: [[]], existing: [day], modelContext: context)

        #expect(day.isRest)
        #expect(day.dayName == "Rest")
        #expect(day.templateID.isEmpty)
        #expect(day.exercisesJSON == "[]")
    }

    @Test @MainActor func createModeInsertsFreshRowsWhenNoExistingRowsArePassed() {
        let context = makeContext()

        SplitDayPersistence.upsertDays(
            splitID: "split-2", dayLabels: ["Monday", "Tuesday"], dayNames: ["Push", ""],
            dayTemplateIDs: ["", ""], dayIsRest: [false, true],
            dayExercises: [[DayExercise(id: "bench", name: "Bench Press")], []],
            dayExcludedMuscles: [[], []], existing: [], modelContext: context)

        let rows = (try? context.fetch(FetchDescriptor<UserSplitDayRecord>())) ?? []
        #expect(rows.count == 2)
        #expect(rows.contains { $0.orderIndex == 0 && $0.dayName == "Push" })
        #expect(rows.contains { $0.orderIndex == 1 && $0.isRest })
    }

    @Test @MainActor func editingADayWithAnActiveVariantKeepsTheVariantCacheInSync() {
        let context = makeContext()
        let day = UserSplitDayRecord(splitID: "split-1", orderIndex: 0, dayLabel: "Monday",
                                     dayName: "Push", exercisesJSON: "[]")
        let original = DayVariant(name: "Fairless",
                                  exercises: [DayExercise(id: "bench", name: "Bench Press", sets: 3)])
        DayVariants.apply(DayVariantSet(activeID: original.id, variants: [original]), to: day)
        context.insert(day)
        try? context.save()

        // The builder edits the day's exercises directly (adds a set) and saves — exactly what
        // saveSplit does today, now routed through upsertDays.
        SplitDayPersistence.upsertDays(
            splitID: "split-1", dayLabels: ["Monday"], dayNames: ["Push"],
            dayTemplateIDs: [""], dayIsRest: [false],
            dayExercises: [[DayExercise(id: "bench", name: "Bench Press", sets: 5)]],
            dayExcludedMuscles: [[]], existing: [day], modelContext: context)

        // If the variant cache went stale here, switching away and back to "Fairless" would
        // silently revert this edit back to 3 sets.
        let vs = DayVariants.set(for: day)
        #expect(vs?.variants.first { $0.id == original.id }?.exercises.first?.sets == 5)
    }

    @Test @MainActor func strayRowsBeyondTheDayCountAreRemoved() {
        let context = makeContext()
        let stray = UserSplitDayRecord(splitID: "split-1", orderIndex: 9, dayLabel: "Stray")
        context.insert(stray)
        try? context.save()

        SplitDayPersistence.upsertDays(
            splitID: "split-1", dayLabels: ["Monday"], dayNames: [""],
            dayTemplateIDs: [""], dayIsRest: [true],
            dayExercises: [[]], dayExcludedMuscles: [[]], existing: [stray], modelContext: context)

        let rows = (try? context.fetch(FetchDescriptor<UserSplitDayRecord>())) ?? []
        #expect(!rows.contains { $0.orderIndex == 9 })
    }
}
