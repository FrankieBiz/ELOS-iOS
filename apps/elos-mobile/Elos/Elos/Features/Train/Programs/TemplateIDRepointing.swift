import Foundation
import SwiftData

/// When a locally-created template's id is rewritten to the server's on first successful push
/// (`TemplatesView.reconcileUnconfirmed`), any split day — or day variant — that still points at
/// the old local id would otherwise silently resolve zero exercises the next time it's used:
/// `AppViewModel.fetchTemplateExercises(templateID:)` returns `[]` for an unknown id, and
/// `prepareExercises(for:)` has no error path for that, just an empty session.
enum TemplateIDRepointing {
    static func repointDays(from oldTemplateID: String, to newTemplateID: String, context: ModelContext) {
        let allLocalDays = (try? context.fetch(FetchDescriptor<UserSplitDayRecord>())) ?? []
        for day in allLocalDays {
            guard var vs = DayVariants.set(for: day) else {
                if day.templateID == oldTemplateID { day.templateID = newTemplateID }
                continue
            }
            var changedAVariant = false
            for i in vs.variants.indices where vs.variants[i].templateID == oldTemplateID {
                vs.variants[i].templateID = newTemplateID
                changedAVariant = true
            }
            // `apply` re-projects the active variant regardless — a harmless no-op if its
            // templateID wasn't one of the ones just corrected.
            if changedAVariant { DayVariants.apply(vs, to: day) }
        }
    }
}
