import Foundation

/// One sighting of a machine at a gym, before it's been merged into the inventory.
struct GymEquipmentObservation: Hashable {
    let gymID: String
    let dedupeKey: String
    var equipmentId: String = ""
    var source: GymEquipmentSource = .logged
    var at: Date = Date()
}

/// The pure rules for turning sightings into an inventory: what a sighting is worth, how it merges
/// with what's already known, and how to reconstruct history when the lifter first opts in.
///
/// Everything here is a pure function over value types — no SwiftData, no catalog lookups beyond an
/// injected database — so the whole learning policy is testable without a simulator.
/// `GymEquipmentStore` is the only thing that touches persistence.
enum GymEquipmentLearning {

    // MARK: - Describing a sighting

    /// Fill in the display fields for a sighting from the equipment catalog.
    ///
    /// Returns `nil` when the machine isn't training equipment (storage, cardio) or isn't in the
    /// catalog at all — a sighting we can't describe is one we shouldn't record, because it would
    /// show up in the lifter's gym list as a blank row.
    static func describe(observation o: GymEquipmentObservation,
                         database: [EquipmentRecord] = EquipmentDatabase.all) -> GymEquipmentEntry? {
        guard !o.gymID.isEmpty, !o.dedupeKey.isEmpty else { return nil }
        var match: EquipmentRecord? = database.first { $0.dedupeKey == o.dedupeKey }
        if match == nil, !o.equipmentId.isEmpty {
            match = database.first { $0.equipmentId == o.equipmentId }
        }
        guard let r = match else { return nil }
        guard GymEquipmentTaxonomy.isTrainingRelevant(catalogType: r.equipmentType) else { return nil }

        return GymEquipmentEntry(
            dedupeKey: o.dedupeKey,
            equipmentId: r.equipmentId,
            displayName: r.displayName,
            brandName: r.brandName,
            equipmentType: r.equipmentType,
            source: o.source,
            timesSeen: 1,
            firstSeenAt: o.at,
            lastSeenAt: o.at,
            isExcluded: false
        )
    }

    // MARK: - Merging

    /// Fold a fresh sighting into what's already stored.
    ///
    /// Three rules, each load-bearing:
    /// 1. **Exclusion is sticky.** A machine the lifter said isn't here stays excluded no matter how
    ///    many sightings arrive — otherwise correcting the app would last only until the next
    ///    re-import of a plan, and the correction would feel ignored. `unexclude` is the only way back.
    /// 2. **Source only ever climbs.** A `logged` sighting can promote a `planned` entry, but a
    ///    later `planned` sighting can't demote a `manual` one.
    /// 3. **`firstSeenAt` is the earliest, `lastSeenAt` the latest** — backfill replays history out
    ///    of order, so neither can be assigned blindly from the incoming sighting.
    static func merged(existing: GymEquipmentEntry?, incoming: GymEquipmentEntry) -> GymEquipmentEntry {
        guard var e = existing else { return incoming }
        if e.isExcluded { return e }

        e.timesSeen += 1
        e.firstSeenAt = min(e.firstSeenAt, incoming.firstSeenAt)
        e.lastSeenAt = max(e.lastSeenAt, incoming.lastSeenAt)
        if incoming.source.rank > e.source.rank { e.source = incoming.source }
        // Refresh denormalized display fields when the stored copy is blank (an entry recorded
        // before its catalog row was resolvable) but never overwrite good data with blanks.
        if e.displayName.isEmpty { e.displayName = incoming.displayName }
        if e.brandName.isEmpty { e.brandName = incoming.brandName }
        if e.equipmentType.isEmpty { e.equipmentType = incoming.equipmentType }
        if e.equipmentId.isEmpty { e.equipmentId = incoming.equipmentId }
        return e
    }

    // MARK: - Backfill

    /// Every machine sighting recoverable from logged history, for the one-time catch-up when the
    /// lifter turns the feature on. Without this, opting in would start from zero and the feature
    /// would look broken for weeks despite months of history sitting right there.
    ///
    /// `sessionGymByID` maps `WorkoutSessionRecord.id -> gymID`; sets from an untagged session are
    /// skipped, since we genuinely don't know where they happened.
    static func observationsFromHistory(sets: [ExerciseSetRecord],
                                        sessionGymByID: [String: String]) -> [GymEquipmentObservation] {
        var out: [GymEquipmentObservation] = []
        for s in sets {
            // Only a *completed* set is evidence the machine exists and was used. An unfinished
            // row is a placeholder the lifter may never touch, and it carries no timestamp to
            // date the sighting with.
            guard let completedAt = s.completedAt,
                  let key = s.equipmentDedupeKey, !key.isEmpty,
                  let gymID = sessionGymByID[s.sessionID], !gymID.isEmpty else { continue }
            out.append(GymEquipmentObservation(gymID: gymID, dedupeKey: key,
                                               equipmentId: s.equipmentId ?? "",
                                               source: .logged, at: completedAt))
        }
        return out
    }

    /// Sightings recoverable from planned work — the exercises sitting in a split day's per-gym
    /// variant. A variant is explicitly tagged with the gym it's for, which makes it the one place a
    /// *plan* says something trustworthy about a location.
    static func observationsFromPlans(variantsByGym: [(gymID: String, exercises: [DayExercise])],
                                      at: Date = Date()) -> [GymEquipmentObservation] {
        var out: [GymEquipmentObservation] = []
        for entry in variantsByGym where !entry.gymID.isEmpty {
            for ex in entry.exercises {
                guard let key = ex.equipmentDedupeKey, !key.isEmpty else { continue }
                out.append(GymEquipmentObservation(gymID: entry.gymID, dedupeKey: key,
                                                   equipmentId: ex.equipmentId ?? "",
                                                   source: .planned, at: at))
            }
        }
        return out
    }

    /// Reduce a stream of sightings into one entry per `(gym, machine)`. Pure — this is what both
    /// the backfill and the tests run through, so the merge rules can't diverge between them.
    static func fold(_ observations: [GymEquipmentObservation],
                     into existing: [String: [String: GymEquipmentEntry]] = [:],
                     database: [EquipmentRecord] = EquipmentDatabase.all) -> [String: [String: GymEquipmentEntry]] {
        var byGym = existing
        for o in observations {
            guard let described = describe(observation: o, database: database) else { continue }
            var forGym = byGym[o.gymID] ?? [:]
            forGym[o.dedupeKey] = merged(existing: forGym[o.dedupeKey], incoming: described)
            byGym[o.gymID] = forGym
        }
        return byGym
    }
}
