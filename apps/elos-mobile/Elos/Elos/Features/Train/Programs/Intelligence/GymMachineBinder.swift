import Foundation

/// Turns a generic recommendation into one made of the machines the gym actually has.
///
/// This is where knowing a gym's inventory stops being a ranking nudge and starts producing a
/// concretely better plan: "Leg Extension" becomes "Nautilus Leg Extension" — the machine standing
/// on the floor — so the day's exercises carry the right `equipmentDedupeKey` from the moment
/// they're created, and progressive overload has a per-machine history to track from set one.
///
/// Deliberately conservative. A wrong binding is worse than none: it pins the lifter's overload
/// history to a machine they never touched, and that's tedious to unpick later. So a name has to
/// match closely, and an ambiguous name is left generic rather than guessed at.
enum GymMachineBinder {

    /// Attach the gym's own machine to each generic exercise whose name unambiguously names one.
    ///
    /// Leaves alone: exercises that already carry an equipment identity (the lifter chose it),
    /// and anything the inventory can't match confidently. Returns the input unchanged when the
    /// gym is unknown — an unknown gym must never rewrite a plan.
    static func bind(_ exercises: [DayExercise], inventory: GymInventory) -> [DayExercise] {
        bind(exercises, inventory: inventory, resolve: { EquipmentDatabase.find(dedupeKey: $0) })
    }

    /// Test seam: bind against an explicit catalog instead of the shipping one.
    static func bind(_ exercises: [DayExercise], inventory: GymInventory,
                     database: [EquipmentRecord]) -> [DayExercise] {
        let byKey = Dictionary(database.map { ($0.dedupeKey, $0) }, uniquingKeysWith: { a, _ in a })
        return bind(exercises, inventory: inventory, resolve: { byKey[$0] })
    }

    private static func bind(_ exercises: [DayExercise], inventory: GymInventory,
                             resolve: (String) -> EquipmentRecord?) -> [DayExercise] {
        guard inventory.isKnown else { return exercises }
        let owned = inventory.dedupeKeys.compactMap(resolve)
        guard !owned.isEmpty else { return exercises }

        return exercises.map { exercise in
            guard exercise.equipmentDedupeKey == nil else { return exercise }
            guard let machine = match(name: exercise.name, among: owned, inventory: inventory)
            else { return exercise }

            var bound = exercise
            bound.equipmentId = machine.equipmentId
            bound.equipmentDedupeKey = machine.dedupeKey
            bound.equipmentBrandName = machine.brandName
            return bound
        }
    }

    /// The one machine at this gym that this exercise name names, or `nil`.
    ///
    /// Match rules, strictest first — note that none of them is `contains`. The catalog's own
    /// `variants(forExercise:)` uses a substring match, which is right for *offering* a list the
    /// lifter then picks from, and wrong here: "Row" substring-matches Low Row, T-Bar Row, and
    /// Seated Row alike, and silently picking one of those would be a fabricated choice.
    ///
    /// Ties break on how often the machine has been seen at this gym, then on name, so the result
    /// is stable across runs rather than dependent on set iteration order.
    static func match(name: String, among owned: [EquipmentRecord],
                      inventory: GymInventory) -> EquipmentRecord? {
        let target = MuscleTaxonomy.normalize(name)
        guard !target.isEmpty else { return nil }

        let exact = owned.filter { MuscleTaxonomy.normalize($0.machineName) == target }
        if let best = mostSeen(exact, inventory: inventory) { return best }

        // "Leg Extension" should still bind a machine listed as "Plate-Loaded Leg Extension" —
        // a manufacturer prefix describes the same movement. A *suffix* only: "Leg Extension
        // Bench" is a different piece of equipment, and matching it would be the fabrication above.
        let suffix = owned.filter {
            let machine = MuscleTaxonomy.normalize($0.machineName)
            return machine != target && machine.hasSuffix(" " + target)
        }

        // Two DIFFERENT machine names both ending in the query is a genuinely ambiguous request —
        // "Row" suffix-matches Seated Row and Low Row alike, and tie-breaking between them on
        // usage would invent a choice the lifter never made. Bail to generic instead.
        //
        // Several records sharing ONE name (the same machine from two brands) is not ambiguous in
        // that sense: they're all the exercise that was asked for, so usage legitimately decides.
        let distinctNames = Set(suffix.map { MuscleTaxonomy.normalize($0.machineName) })
        guard distinctNames.count == 1 else { return nil }
        return mostSeen(suffix, inventory: inventory)
    }

    private static func mostSeen(_ records: [EquipmentRecord],
                                 inventory: GymInventory) -> EquipmentRecord? {
        guard !records.isEmpty else { return nil }
        let seenByKey = Dictionary(inventory.entries.map { ($0.dedupeKey, $0.timesSeen) },
                                   uniquingKeysWith: { a, _ in a })
        return records.sorted {
            let a = seenByKey[$0.dedupeKey] ?? 0, b = seenByKey[$1.dedupeKey] ?? 0
            return a == b ? $0.displayName < $1.displayName : a > b
        }.first
    }
}
