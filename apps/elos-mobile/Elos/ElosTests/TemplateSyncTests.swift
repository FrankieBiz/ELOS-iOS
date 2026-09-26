import Foundation
import SwiftData
import Testing
@testable import Elos

/// Reproduces, then proves fixed, the exact silent breakage: a template's local id gets rewritten
/// to the server's on first push, and a split day that referenced the old id used to be left
/// pointing at nothing.
struct TemplateSyncTests {

    @MainActor
    private func makeContext() -> ModelContext {
        let schema = Schema([UserSplitDayRecord.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try! ModelContainer(for: schema, configurations: config)
        return container.mainContext
    }

    @Test @MainActor func repointsADayWithNoVariantsThatReferencedTheOldTemplateID() {
        let context = makeContext()
        let day = UserSplitDayRecord(splitID: "split-1", orderIndex: 0, dayLabel: "Monday",
                                     templateID: "local-id", exercisesJSON: "[]")
        context.insert(day)
        try? context.save()

        TemplateIDRepointing.repointDays(from: "local-id", to: "server-id", context: context)

        #expect(day.templateID == "server-id")
    }

    @Test @MainActor func repointsTheActiveVariantsTemplateIDAndReprojects() {
        let context = makeContext()
        let day = UserSplitDayRecord(splitID: "split-1", orderIndex: 0, dayLabel: "Monday")
        let variant = DayVariant(name: "Fairless", exercises: [], templateID: "local-id")
        DayVariants.apply(DayVariantSet(activeID: variant.id, variants: [variant]), to: day)
        context.insert(day)
        try? context.save()

        TemplateIDRepointing.repointDays(from: "local-id", to: "server-id", context: context)

        #expect(day.templateID == "server-id", "the day's wire field must be re-projected, not just the variant")
        #expect(DayVariants.set(for: day)?.variants.first?.templateID == "server-id")
    }

    @Test @MainActor func repointsAnInactiveVariantsTemplateIDWithoutDisturbingTheActiveOne() {
        let context = makeContext()
        let day = UserSplitDayRecord(splitID: "split-1", orderIndex: 0, dayLabel: "Monday")
        let active = DayVariant(name: "Fairless", exercises: [], templateID: "tmpl-active")
        let inactive = DayVariant(name: "Warminster", exercises: [], templateID: "local-id")
        DayVariants.apply(DayVariantSet(activeID: active.id, variants: [active, inactive]), to: day)
        context.insert(day)
        try? context.save()

        TemplateIDRepointing.repointDays(from: "local-id", to: "server-id", context: context)

        #expect(day.templateID == "tmpl-active", "the day's live content must stay on the active variant")
        let vs = DayVariants.set(for: day)
        #expect(vs?.variants.first { $0.id == inactive.id }?.templateID == "server-id")
    }

    @Test @MainActor func leavesUnrelatedDaysAlone() {
        let context = makeContext()
        let day = UserSplitDayRecord(splitID: "split-1", orderIndex: 0, dayLabel: "Monday",
                                     templateID: "some-other-template")
        context.insert(day)
        try? context.save()

        TemplateIDRepointing.repointDays(from: "local-id", to: "server-id", context: context)

        #expect(day.templateID == "some-other-template")
    }
}
