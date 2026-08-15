import Foundation

/// What's actually been logged at a gym, derived purely from history — no catalog to maintain,
/// no setup screen, matching the user's own choice to "learn it from what I log" rather than
/// build a per-gym equipment catalog up front.
///
/// An empty result means **unknown** — nothing logged there yet, or no active gym at all — never
/// "this gym has nothing." Nothing may use it as a hard filter; both consumers (the picker's
/// ranking nudge, `DayVariantSheet`'s quiet note) are explicitly soft for exactly this reason.
enum GymEquipmentIndex {

    /// Every `equipmentDedupeKey` logged at `gymID` — the precise, machine-model-level inventory.
    /// `sessionGymByID` maps a session's id to the gym it was tagged with
    /// (`WorkoutSessionRecord.id -> gymID`); sets from an untagged or differently-tagged session
    /// don't count.
    static func loggedDedupeKeys(gymID: String, sets: [ExerciseSetRecord],
                                 sessionGymByID: [String: String]) -> Set<String> {
        guard !gymID.isEmpty else { return [] }
        var keys: Set<String> = []
        for s in sets {
            guard let key = s.equipmentDedupeKey, !key.isEmpty,
                  sessionGymByID[s.sessionID] == gymID else { continue }
            keys.insert(key)
        }
        return keys
    }

    /// The coarse equipment TYPES (e.g. "cable", "machine", "barbell") available at `gymID`,
    /// derived from its logged dedupe keys via the equipment database. This is the level the
    /// exercise-ranking engine can actually act on — `ExerciseCandidate.equipment` only ever
    /// carries a coarse type, never a specific model, so a dedupe-key-precise inventory has to be
    /// coarsened before it's useful for ranking.
    static func loggedEquipmentTypes(gymID: String, sets: [ExerciseSetRecord],
                                     sessionGymByID: [String: String],
                                     database: [EquipmentRecord] = EquipmentDatabase.all) -> Set<String> {
        let keys = loggedDedupeKeys(gymID: gymID, sets: sets, sessionGymByID: sessionGymByID)
        guard !keys.isEmpty else { return [] }
        var types: Set<String> = []
        for record in database where keys.contains(record.dedupeKey) {
            types.insert(MuscleTaxonomy.normalize(record.equipmentType))
        }
        return types
    }
}
