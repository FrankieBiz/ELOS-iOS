import Foundation
import SwiftData

/// UserDefaults keys shared between `AppViewModel` (which owns the published value) and the views
/// that read it through `@AppStorage` instead of taking an `AppViewModel` dependency they don't
/// otherwise need. One constant so the two can't drift apart into a silently-never-matching pair.
enum GymDefaultsKey {
    static let activeGymID = "elos.activeGymID"
    static let learningEnabled = "elos.gymEquipmentLearning"
}

/// The only place the learned-equipment feature touches persistence. Everything it decides comes
/// from `GymEquipmentLearning`; this type just fetches, upserts, and saves.
///
/// Kept out of `Intelligence/` deliberately — that layer stays pure so it can be exercised without
/// SwiftData, and this is the seam where the pure rules meet the store.
enum GymEquipmentStore {

    // MARK: - Reading

    /// Every stored entry for one gym, including exclusion tombstones (the inventory needs them to
    /// know what the lifter has ruled out).
    static func entries(gymID: String, ownerID: String, context: ModelContext) -> [GymEquipmentEntry] {
        records(gymID: gymID, ownerID: ownerID, context: context).map(entry(from:))
    }

    static func records(gymID: String, ownerID: String, context: ModelContext) -> [GymEquipmentRecord] {
        guard !gymID.isEmpty else { return [] }
        let descriptor = FetchDescriptor<GymEquipmentRecord>(
            predicate: #Predicate { $0.ownerID == ownerID && $0.gymID == gymID },
            sortBy: [SortDescriptor(\.displayName)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    /// The inventory for a gym. Returns `.unknown` for an empty gym id — no active gym means we
    /// know nothing, which every consumer must treat as "don't bias anything."
    static func inventory(gymID: String, gymName: String, ownerID: String,
                          context: ModelContext) -> GymInventory {
        guard !gymID.isEmpty else { return .unknown }
        return GymInventory(gymID: gymID, gymName: gymName,
                            entries: entries(gymID: gymID, ownerID: ownerID, context: context))
    }

    /// Whether the lifter has opted in. Off by default, and every write path outside the
    /// opt-in backfill must check it — this feature changes what the app recommends, so it
    /// stays silent until asked for.
    ///
    /// Lives in UserDefaults, not on `UserProfileRecord`, for the same reason `activeGymID` and
    /// `volumeOverrides` do: it's a local-only preference and has no business riding along in the
    /// record that syncs to the backend. It also keeps this check off the SwiftData path entirely,
    /// which matters because it runs on every logged set.
    static var isLearningEnabled: Bool {
        UserDefaults.standard.bool(forKey: GymDefaultsKey.learningEnabled)
    }

    /// The inventory for whichever gym is currently selected, or `.unknown` when the feature is off,
    /// no gym is active, or nothing's been learned. One helper so every builder asks the question the
    /// same way and can't accidentally skip the opt-in check.
    ///
    /// This hits the store, so call it from on-demand paths (a button tap, a `.task`) — never from a
    /// computed property a view re-evaluates per render.
    static func activeGymInventory(ownerID: String, activeGymID: String,
                                   gyms: [GymRecord] = [], context: ModelContext) -> GymInventory {
        guard isLearningEnabled, !activeGymID.isEmpty, !ownerID.isEmpty else { return .unknown }
        let name = gyms.first { $0.id == activeGymID }?.name ?? ""
        return inventory(gymID: activeGymID, gymName: name, ownerID: ownerID, context: context)
    }

    // MARK: - Writing

    /// Fold sightings into the store. Silently no-ops for an empty owner — an unauthenticated write
    /// would create records no later query can find.
    ///
    /// Not gated on the feature toggle here on purpose: the gate belongs at each call site, so the
    /// one place that *should* write while disabled (the backfill that runs the moment you enable
    /// it) doesn't have to fight its own guard.
    static func record(_ observations: [GymEquipmentObservation], ownerID: String,
                       context: ModelContext, database: [EquipmentRecord] = EquipmentDatabase.all) {
        guard !ownerID.isEmpty, !observations.isEmpty else { return }

        // Group by gym so each gym's existing rows are fetched once, not once per sighting.
        let byGym = Dictionary(grouping: observations, by: \.gymID)
        var didChange = false

        for (gymID, group) in byGym where !gymID.isEmpty {
            let existing = records(gymID: gymID, ownerID: ownerID, context: context)
            var recordByKey = Dictionary(existing.map { ($0.equipmentDedupeKey, $0) },
                                         uniquingKeysWith: { a, _ in a })

            for o in group {
                guard let described = GymEquipmentLearning.describe(observation: o, database: database)
                else { continue }

                if let stored = recordByKey[o.dedupeKey] {
                    // An excluded machine stays excluded — `merged` enforces it, but returning early
                    // also avoids a pointless write.
                    if stored.isExcluded { continue }
                    let updated = GymEquipmentLearning.merged(existing: entry(from: stored),
                                                              incoming: described)
                    apply(updated, to: stored)
                } else {
                    let fresh = GymEquipmentRecord(ownerID: ownerID, gymID: gymID,
                                                   equipmentDedupeKey: described.dedupeKey,
                                                   equipmentId: described.equipmentId,
                                                   displayName: described.displayName,
                                                   brandName: described.brandName,
                                                   equipmentType: described.equipmentType,
                                                   source: described.source.rawValue,
                                                   timesSeen: 1,
                                                   firstSeenAt: described.firstSeenAt,
                                                   lastSeenAt: described.lastSeenAt)
                    context.insert(fresh)
                    recordByKey[described.dedupeKey] = fresh
                }
                didChange = true
            }
        }
        if didChange { try? context.save() }
    }

    /// Record a single machine sighting — the hot path, called as sets are logged.
    static func record(dedupeKey: String?, equipmentId: String?, gymID: String,
                       source: GymEquipmentSource, ownerID: String, context: ModelContext,
                       at: Date = Date()) {
        guard let key = dedupeKey, !key.isEmpty, !gymID.isEmpty else { return }
        record([GymEquipmentObservation(gymID: gymID, dedupeKey: key,
                                        equipmentId: equipmentId ?? "", source: source, at: at)],
               ownerID: ownerID, context: context)
    }

    /// The lifter adding a machine themselves — highest-confidence source, and it clears any
    /// previous exclusion, since adding it back is an explicit reversal of "we don't have this."
    static func addManually(_ machine: EquipmentRecord, gymID: String, ownerID: String,
                            context: ModelContext) {
        guard !gymID.isEmpty, !ownerID.isEmpty else { return }
        let existing = records(gymID: gymID, ownerID: ownerID, context: context)
        if let stored = existing.first(where: { $0.equipmentDedupeKey == machine.dedupeKey }) {
            stored.isExcluded = false
            stored.source = GymEquipmentSource.manual.rawValue
            stored.lastSeenAt = Date()
        } else {
            context.insert(GymEquipmentRecord(ownerID: ownerID, gymID: gymID,
                                              equipmentDedupeKey: machine.dedupeKey,
                                              equipmentId: machine.equipmentId,
                                              displayName: machine.displayName,
                                              brandName: machine.brandName,
                                              equipmentType: machine.equipmentType,
                                              source: GymEquipmentSource.manual.rawValue))
        }
        try? context.save()
    }

    /// "My gym doesn't actually have this." Kept as a tombstone rather than deleted so the next
    /// logged set or imported plan can't quietly put it back.
    static func exclude(_ record: GymEquipmentRecord, context: ModelContext) {
        record.isExcluded = true
        try? context.save()
    }

    static func unexclude(_ record: GymEquipmentRecord, context: ModelContext) {
        record.isExcluded = false
        try? context.save()
    }

    /// Drop every learned row for a gym — used when the gym itself is deleted, and by the "forget
    /// what you learned" control.
    static func forgetAll(gymID: String, ownerID: String, context: ModelContext) {
        for r in records(gymID: gymID, ownerID: ownerID, context: context) { context.delete(r) }
        try? context.save()
    }

    // MARK: - Backfill

    /// Replay existing history into the inventory. Run once when the lifter turns the feature on,
    /// so months of logged sets aren't thrown away and the feature has something to show
    /// immediately instead of looking broken.
    ///
    /// Idempotent in effect but not in counts: re-running bumps `timesSeen`, which only feeds
    /// display ordering, never a correctness decision.
    @discardableResult
    static func backfillFromHistory(ownerID: String, context: ModelContext) -> Int {
        guard !ownerID.isEmpty else { return 0 }

        let sessionDescriptor = FetchDescriptor<WorkoutSessionRecord>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        let sessions = (try? context.fetch(sessionDescriptor)) ?? []
        let sessionGymByID = Dictionary(sessions.map { ($0.id, $0.gymID) },
                                        uniquingKeysWith: { a, _ in a })
        // Nothing was ever tagged with a gym — there is no history to attribute, so don't scan sets.
        guard sessionGymByID.values.contains(where: { !$0.isEmpty }) else { return 0 }

        let setDescriptor = FetchDescriptor<ExerciseSetRecord>(
            predicate: #Predicate { $0.ownerID == ownerID }
        )
        let sets = (try? context.fetch(setDescriptor)) ?? []

        var observations = GymEquipmentLearning.observationsFromHistory(
            sets: sets, sessionGymByID: sessionGymByID)
        observations += planObservations(ownerID: ownerID, context: context)

        record(observations, ownerID: ownerID, context: context)
        return observations.count
    }

    /// Sightings from every split day's per-gym variants. A variant names the gym it's for, which is
    /// what makes a *plan* worth reading as evidence at all.
    static func planObservations(ownerID: String, context: ModelContext) -> [GymEquipmentObservation] {
        let descriptor = FetchDescriptor<UserSplitDayRecord>()
        guard let days = try? context.fetch(descriptor) else { return [] }
        var pairs: [(gymID: String, exercises: [DayExercise])] = []
        for day in days {
            guard let set = DayVariants.set(for: day) else { continue }
            for variant in set.variants {
                guard let gymID = variant.gymID, !gymID.isEmpty else { continue }
                pairs.append((gymID: gymID, exercises: variant.exercises))
            }
        }
        return GymEquipmentLearning.observationsFromPlans(variantsByGym: pairs)
    }

    // MARK: - Record <-> entry

    static func entry(from r: GymEquipmentRecord) -> GymEquipmentEntry {
        GymEquipmentEntry(dedupeKey: r.equipmentDedupeKey, equipmentId: r.equipmentId,
                          displayName: r.displayName, brandName: r.brandName,
                          equipmentType: r.equipmentType, source: GymEquipmentSource.from(r.source),
                          timesSeen: r.timesSeen, firstSeenAt: r.firstSeenAt,
                          lastSeenAt: r.lastSeenAt, isExcluded: r.isExcluded)
    }

    private static func apply(_ e: GymEquipmentEntry, to r: GymEquipmentRecord) {
        r.equipmentId = e.equipmentId
        r.displayName = e.displayName
        r.brandName = e.brandName
        r.equipmentType = e.equipmentType
        r.source = e.source.rawValue
        r.timesSeen = e.timesSeen
        r.firstSeenAt = e.firstSeenAt
        r.lastSeenAt = e.lastSeenAt
        r.isExcluded = e.isExcluded
    }
}
