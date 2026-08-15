import Foundation
import Testing
@testable import Elos

/// The projection invariant is what the rest of the gym/variants feature rests on: the active
/// variant is always mirrored into the day's own `exercisesJSON`/`templateID`, so
/// `prepareExercises(for:)`, sync, scoring, and the builder never need to know variants exist.
struct DayVariantsTests {

    private func day(exercisesJSON: String = "[]", templateID: String = "") -> UserSplitDayRecord {
        UserSplitDayRecord(splitID: "split-1", orderIndex: 0, dayLabel: "Monday",
                          templateID: templateID, exercisesJSON: exercisesJSON)
    }

    private func encoded(_ exercises: [DayExercise]) -> String {
        let data = try? JSONEncoder().encode(exercises)
        return data.flatMap { String(data: $0, encoding: .utf8) } ?? "[]"
    }

    @Test func activeVariantIsMirroredIntoTheDaysWireFields() {
        let d = day()
        let a = DayVariant(name: "Fairless", exercises: [DayExercise(id: "bench", name: "Bench Press")])
        let b = DayVariant(name: "Warminster", exercises: [DayExercise(id: "row", name: "Barbell Row")],
                          templateID: "tmpl-warminster")
        DayVariants.apply(DayVariantSet(activeID: b.id, variants: [a, b]), to: d)

        #expect(d.templateID == "tmpl-warminster")
        let decoded = (try? JSONDecoder().decode([DayExercise].self, from: Data(d.exercisesJSON.utf8))) ?? []
        #expect(decoded.map(\.id) == ["row"])
    }

    @Test func aDayWithNoVariantsIsUnchanged() {
        let d = day(exercisesJSON: encoded([DayExercise(id: "bench", name: "Bench Press")]))
        #expect(DayVariants.set(for: d) == nil)
    }

    @Test func switchingVariantsPreservesTheOutgoingVariantsEdits() {
        let d = day()
        let a = DayVariant(name: "Fairless", exercises: [DayExercise(id: "bench", name: "Bench Press", sets: 3)])
        let b = DayVariant(name: "Warminster", exercises: [DayExercise(id: "row", name: "Barbell Row")])
        DayVariants.apply(DayVariantSet(activeID: a.id, variants: [a, b]), to: d)

        // Edit A's content directly on the day's wire fields, as the builder would, WITHOUT
        // switching away yet.
        d.exercisesJSON = encoded([DayExercise(id: "bench", name: "Bench Press", sets: 5)])

        DayVariants.switchTo(variantID: b.id, day: d)
        DayVariants.switchTo(variantID: a.id, day: d)

        let decoded = (try? JSONDecoder().decode([DayExercise].self, from: Data(d.exercisesJSON.utf8))) ?? []
        #expect(decoded.first?.sets == 5, "the edit made to A before switching away must survive the round trip")
    }

    @Test func remoteEditWinsOverTheLocalVariantCache() {
        let d = day()
        let a = DayVariant(name: "Fairless", exercises: [DayExercise(id: "bench", name: "Bench Press", sets: 3)])
        DayVariants.apply(DayVariantSet(activeID: a.id, variants: [a]), to: d)

        // Simulate syncSplitsFromServer overwriting the wire fields with a real remote edit.
        d.exercisesJSON = encoded([DayExercise(id: "bench", name: "Bench Press", sets: 8)])
        DayVariants.reconcileAfterRemoteUpdate(day: d)

        // The variant's cached copy must now agree with the server, not the pre-sync value —
        // otherwise switching away and back would silently revert the remote edit.
        DayVariants.switchTo(variantID: a.id, day: d)  // no-op switch, same variant already active
        let vs = DayVariants.set(for: d)
        #expect(vs?.variants.first?.exercises.first?.sets == 8)
        #expect(d.exercisesJSON.contains("8") || (try? JSONDecoder().decode([DayExercise].self, from: Data(d.exercisesJSON.utf8)))?.first?.sets == 8)
    }

    @Test func deletingTheActiveVariantPromotesAnotherAndReprojects() {
        let d = day()
        let a = DayVariant(name: "Fairless", exercises: [DayExercise(id: "bench", name: "Bench Press")])
        let b = DayVariant(name: "Warminster", exercises: [DayExercise(id: "row", name: "Barbell Row")])
        DayVariants.apply(DayVariantSet(activeID: b.id, variants: [a, b]), to: d)

        DayVariants.deleteVariant(id: b.id, day: d)

        let vs = DayVariants.set(for: d)
        #expect(vs?.variants.map(\.id) == [a.id])
        #expect(vs?.activeID == a.id)
        let decoded = (try? JSONDecoder().decode([DayExercise].self, from: Data(d.exercisesJSON.utf8))) ?? []
        #expect(decoded.map(\.id) == ["bench"], "deleting the active variant must re-project the promoted one")
    }

    @Test func deletingTheLastVariantClearsBackToNoVariants() {
        let d = day()
        let a = DayVariant(name: "Fairless", exercises: [DayExercise(id: "bench", name: "Bench Press")])
        DayVariants.apply(DayVariantSet(activeID: a.id, variants: [a]), to: d)

        DayVariants.deleteVariant(id: a.id, day: d)

        #expect(DayVariants.set(for: d) == nil)
    }

    @Test func aVariantWhoseGymWasDeletedStillRendersByStoredName() {
        // DayVariant.name is stored independently of any live GymRecord — there is deliberately
        // no lookup back to one. Deleting a gym (Task 5) can never make a variant unreadable.
        let orphaned = DayVariant(name: "Fairless", gymID: "gym-deleted-later", exercises: [])
        #expect(orphaned.name == "Fairless")
    }

    @Test func seededCreatesOneVariantFromTheDaysCurrentState() {
        let d = day(exercisesJSON: encoded([DayExercise(id: "bench", name: "Bench Press")]),
                   templateID: "tmpl-1")
        #expect(DayVariants.set(for: d) == nil)

        let vs = DayVariants.seeded(for: d, defaultName: "Original")
        #expect(vs.variants.count == 1)
        #expect(vs.variants[0].name == "Original")
        #expect(vs.variants[0].templateID == "tmpl-1")
        #expect(vs.activeID == vs.variants[0].id)
    }

    @Test func addVariantSeedsFirstThenAppendsWithoutSwitchingUnlessAsked() {
        let d = day(exercisesJSON: encoded([DayExercise(id: "bench", name: "Bench Press")]))
        let newVariant = DayVariant(name: "Warminster", exercises: [DayExercise(id: "row", name: "Barbell Row")])

        DayVariants.addVariant(newVariant, to: d, defaultNameForSeed: "Fairless", makeActive: false)

        let vs = DayVariants.set(for: d)
        #expect(vs?.variants.count == 2)
        // Not made active — the day's wire fields must still reflect the ORIGINAL content.
        let decoded = (try? JSONDecoder().decode([DayExercise].self, from: Data(d.exercisesJSON.utf8))) ?? []
        #expect(decoded.map(\.id) == ["bench"])
    }
}
