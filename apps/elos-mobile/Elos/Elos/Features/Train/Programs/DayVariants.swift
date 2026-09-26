import Foundation
import SwiftData

/// A day's own version for a specific gym — "Leg Day @ Fairless" vs "@ Warminster". `gymID == nil`
/// means "not tied to a particular gym" (the day's original/default version, before any gym-specific
/// copy existed).
struct DayVariant: Codable, Identifiable, Equatable {
    let id: String
    var name: String
    var gymID: String?
    var exercises: [DayExercise]
    var templateID: String

    init(id: String = UUID().uuidString, name: String, gymID: String? = nil,
        exercises: [DayExercise], templateID: String = "") {
        self.id = id
        self.name = name
        self.gymID = gymID
        self.exercises = exercises
        self.templateID = templateID
    }
}

struct DayVariantSet: Codable, Equatable {
    var activeID: String
    var variants: [DayVariant]
}

/// Reads/writes `UserSplitDayRecord.variantsJSON`, and enforces the one invariant everything else
/// in this feature depends on: **the active variant is always mirrored into the day's own
/// `exercisesJSON`/`templateID`.** Those two fields stay the single source of truth for
/// `prepareExercises(for:)`, sync, scoring, and the builder — none of them need to know variants
/// exist. Every mutation in this type goes through `apply(_:to:)`, which is the only place that
/// writes `variantsJSON` *and* re-projects in the same step — a day whose wire fields disagree
/// with its active variant is the one state that breaks everything downstream at once.
enum DayVariants {

    /// `nil` when the day has no variants — byte-identical to before this feature existed.
    static func set(for day: UserSplitDayRecord) -> DayVariantSet? {
        guard !day.variantsJSON.isEmpty,
              let data = day.variantsJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(DayVariantSet.self, from: data)
        else { return nil }
        return decoded
    }

    /// Persists `set` and re-projects its active variant into the day's wire fields. If `activeID`
    /// doesn't match any variant (shouldn't happen through this type's own functions), the wire
    /// fields are left untouched rather than guessed at.
    static func apply(_ set: DayVariantSet, to day: UserSplitDayRecord) {
        if let active = set.variants.first(where: { $0.id == set.activeID }) {
            day.templateID = active.templateID
            if let data = try? JSONEncoder().encode(active.exercises),
               let json = String(data: data, encoding: .utf8) {
                day.exercisesJSON = json
            }
        }
        persist(set, to: day)
    }

    /// Switches which variant is active. Writes the *outgoing* variant's current state — the
    /// day's current wire fields, which may have been edited since this variant was last projected
    /// — back into its slot first, or those edits are silently discarded the moment another
    /// variant's content overwrites `exercisesJSON`.
    static func switchTo(variantID: String, day: UserSplitDayRecord) {
        guard var vs = set(for: day), vs.variants.contains(where: { $0.id == variantID }) else { return }
        if let outgoing = vs.variants.firstIndex(where: { $0.id == vs.activeID }) {
            vs.variants[outgoing].exercises = currentExercises(of: day)
            vs.variants[outgoing].templateID = day.templateID
        }
        vs.activeID = variantID
        apply(vs, to: day)
    }

    /// A new variant seeded from the day's *current* state — a Warminster leg day starts as a copy
    /// of the Fairless one with a few machines swapped, not a blank slate. Does not touch
    /// `variantsJSON`; the caller decides whether/how to add it (typically via `seeded(for:)` then
    /// appending, or via `addVariant`).
    static func createVariant(named name: String, gymID: String?, from day: UserSplitDayRecord) -> DayVariant {
        DayVariant(name: name, gymID: gymID, exercises: currentExercises(of: day), templateID: day.templateID)
    }

    /// The day's variant set, creating one from its current state if it doesn't have one yet —
    /// so a day with zero variants can go straight to two (its existing content, now named, plus
    /// whatever's being added) without a separate "first-time" code path.
    static func seeded(for day: UserSplitDayRecord, defaultName: String) -> DayVariantSet {
        if let existing = set(for: day) { return existing }
        let original = DayVariant(name: defaultName, gymID: nil,
                                  exercises: currentExercises(of: day), templateID: day.templateID)
        return DayVariantSet(activeID: original.id, variants: [original])
    }

    /// Adds `variant` to the day's set (seeding one from the current state first if needed) and
    /// re-projects only if `makeActive` is true — adding a variant for the OTHER gym shouldn't
    /// silently switch you to it.
    static func addVariant(_ variant: DayVariant, to day: UserSplitDayRecord,
                          defaultNameForSeed: String, makeActive: Bool) {
        var vs = seeded(for: day, defaultName: defaultNameForSeed)
        vs.variants.append(variant)
        if makeActive { vs.activeID = variant.id }
        apply(vs, to: day)
    }

    static func renameVariant(id: String, to name: String, day: UserSplitDayRecord) {
        guard var vs = set(for: day), let i = vs.variants.firstIndex(where: { $0.id == id }) else { return }
        vs.variants[i].name = name
        // Renaming changes no content and doesn't move `activeID` — persist without re-deriving
        // the wire fields from whichever variant happens to be active.
        persist(vs, to: day)
    }

    /// Deleting the active variant promotes the first remaining one and re-projects it. Deleting
    /// the last variant clears back to "no variants" — a single remaining version is just the
    /// day's content again, not a one-item list.
    static func deleteVariant(id: String, day: UserSplitDayRecord) {
        guard var vs = set(for: day) else { return }
        vs.variants.removeAll { $0.id == id }
        guard !vs.variants.isEmpty else {
            day.variantsJSON = ""
            return
        }
        if vs.activeID == id {
            vs.activeID = vs.variants[0].id
        }
        apply(vs, to: day)
    }

    /// Called whenever something OTHER than this type just changed a day's wire fields directly —
    /// `syncSplitsFromServer` overwriting them from the server, or the split builder saving edited
    /// exercises straight into `exercisesJSON`. Either way, **the wire fields win**: they just
    /// changed for a real reason and must never be clobbered by a stale variant cache on the next
    /// switch-away. This only updates the active variant's stored copy to match what's now on the
    /// day; it never re-projects, since the wire fields are already correct.
    static func syncActiveVariantToWireFields(day: UserSplitDayRecord) {
        guard var vs = set(for: day), let i = vs.variants.firstIndex(where: { $0.id == vs.activeID }) else { return }
        vs.variants[i].exercises = currentExercises(of: day)
        vs.variants[i].templateID = day.templateID
        persist(vs, to: day)
    }

    /// The active variant's name, only when the day genuinely has more than one — a day with zero
    /// or one variant returns nil, so the common case (no gym-splitting) shows nothing extra
    /// anywhere this is used (the split detail view's day-row chip, Today/Plan's schedule copy).
    static func activeVariantName(for day: UserSplitDayRecord) -> String? {
        guard let vs = set(for: day), vs.variants.count > 1 else { return nil }
        return vs.variants.first { $0.id == vs.activeID }?.name
    }

    /// Read-only: which variant this day would switch to for `gymID`, without mutating anything —
    /// the gym switcher's preview needs to show what's about to change before committing to it.
    /// `nil` means the day has no version for that gym and would be left exactly as it is.
    static func previewVariant(forGym gymID: String, day: UserSplitDayRecord) -> DayVariant? {
        set(for: day)?.variants.first { $0.gymID == gymID }
    }

    // MARK: - Private

    private static func currentExercises(of day: UserSplitDayRecord) -> [DayExercise] {
        (try? JSONDecoder().decode([DayExercise].self, from: Data(day.exercisesJSON.utf8))) ?? []
    }

    private static func persist(_ set: DayVariantSet, to day: UserSplitDayRecord) {
        guard let data = try? JSONEncoder().encode(set),
              let json = String(data: data, encoding: .utf8) else { return }
        day.variantsJSON = json
    }
}
