import Foundation
import SwiftData

/// A freshly-created local template (`serverConfirmed == false`) previously relied entirely on
/// `TemplatesViewModel.reconcileUnconfirmed` to ever reach the server — which only runs when the
/// user opens the Templates tab. A template created elsewhere (e.g. Discover's "Add to Plan") could
/// sit unconfirmed indefinitely. `pushIfNeeded` is the same single-template push, extracted so any
/// creation flow can push immediately instead of waiting on that sweep.
enum TemplateSync {
    /// Ids currently mid-push. Without this, opening the Templates tab (which re-sweeps every
    /// unconfirmed template via `reconcileUnconfirmed`) while another flow's `pushIfNeeded` for the
    /// same record is still in flight would double-POST it, creating an orphaned server duplicate.
    /// Process-local only — a relaunch always starts clean, which is fine since nothing can be
    /// in flight across a relaunch.
    @MainActor private static var inFlight: Set<String> = []

    /// Every not-yet-confirmed template a split's days reference — the set a split-push flow should
    /// send first, so the split itself carries corrected server template ids rather than dangling
    /// local ones.
    static func pendingTemplates(forSplit split: UserSplitRecord, context: ModelContext) -> [WorkoutTemplateRecord] {
        let splitID = split.id
        let dayDesc = FetchDescriptor<UserSplitDayRecord>(predicate: #Predicate { $0.splitID == splitID })
        let templateIDs = Set(((try? context.fetch(dayDesc)) ?? []).map(\.templateID).filter { !$0.isEmpty })
        guard !templateIDs.isEmpty else { return [] }

        let ownerID = split.ownerID
        let pendingDesc = FetchDescriptor<WorkoutTemplateRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.serverConfirmed == false }
        )
        return ((try? context.fetch(pendingDesc)) ?? []).filter { templateIDs.contains($0.id) }
    }

    /// Pushes every not-yet-confirmed template this split's days reference. Call before pushing the
    /// split itself so it picks up corrected server ids instead of local ones nobody has pushed yet.
    static func pushPendingTemplates(forSplit split: UserSplitRecord, context: ModelContext) async {
        for template in pendingTemplates(forSplit: split, context: context) {
            await pushIfNeeded(template, context: context)
        }
    }

    static func pushIfNeeded(_ record: WorkoutTemplateRecord, context: ModelContext) async {
        guard !record.serverConfirmed else { return }
        let originalID = record.id
        guard !inFlight.contains(originalID) else { return }
        inFlight.insert(originalID)
        defer { inFlight.remove(originalID) }

        let templateID = record.id
        let exDesc = FetchDescriptor<TemplateExerciseRecord>(
            predicate: #Predicate { $0.templateID == templateID },
            sortBy: [SortDescriptor(\.orderIndex)]
        )
        let exs = (try? context.fetch(exDesc)) ?? []

        let body = CreateTemplateRequest(
            name: record.name,
            exercises: exs.enumerated().map { idx, ex in
                TemplateExerciseRequest(
                    exercise_id: ex.exerciseID,
                    exercise_name: ex.exerciseName,
                    order_index: idx,
                    target_sets: ex.targetSets,
                    target_reps: ex.targetReps,
                    target_rpe: ex.targetRPE > 0 ? ex.targetRPE : nil,
                    rest_seconds: ex.restSeconds,
                    notes: ex.notes.isEmpty ? nil : ex.notes,
                    equipment_id: ex.equipmentId,
                    equipment_dedupe_key: ex.equipmentDedupeKey,
                    equipment_brand_name: ex.equipmentBrandName
                )
            }
        )

        do {
            let response = try await ApiClient.shared.post("/templates", body: body) as TemplateDetailResponse
            let oldID = record.id
            record.serverConfirmed = true
            if oldID != response.id {
                record.id = response.id
                for (idx, ex) in exs.enumerated() {
                    ex.templateID = response.id
                    if idx < response.exercises.count { ex.id = response.exercises[idx].id }
                }
                TemplateIDRepointing.repointDays(from: oldID, to: response.id, context: context)
            }
            try? context.save()
        } catch {
            // Still safe locally; retried the next time the Templates tab loads.
        }
    }
}
