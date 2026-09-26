import Foundation

/// How a machine came to be associated with a gym, ordered by how much it should be trusted.
///
/// `manual` beats `logged` beats `planned`: the lifter saying "this gym has a Hammer Strength row"
/// outranks having done a set on one, which outranks merely having put one in a plan — a plan is a
/// statement of intent, and intent is the weakest evidence that the thing is physically there.
enum GymEquipmentSource: String, CaseIterable, Codable {
    case planned, logged, manual

    var rank: Int {
        switch self {
        case .planned: return 1
        case .logged:  return 2
        case .manual:  return 3
        }
    }

    var label: String {
        switch self {
        case .planned: return "In a plan"
        case .logged:  return "Logged here"
        case .manual:  return "Added by you"
        }
    }

    static func from(_ raw: String) -> GymEquipmentSource {
        GymEquipmentSource(rawValue: raw) ?? .logged
    }
}

/// One machine believed to be at one gym — the pure mirror of `GymEquipmentRecord`, so every merge
/// and inventory rule can be written and tested without SwiftData in the way.
struct GymEquipmentEntry: Hashable, Identifiable {
    var id: String { dedupeKey }

    let dedupeKey: String
    var equipmentId: String = ""
    var displayName: String = ""
    var brandName: String = ""
    /// The catalog's own type string ("Selectorized", "Cable / Multi-Station"), kept verbatim.
    /// Coarsen it through `GymEquipmentTaxonomy` before comparing it to anything else.
    var equipmentType: String = ""
    var source: GymEquipmentSource = .logged
    var timesSeen: Int = 1
    var firstSeenAt: Date = Date()
    var lastSeenAt: Date = Date()
    var isExcluded: Bool = false
}

/// Translates the equipment catalog's `equipmentType` vocabulary into the one the exercise catalog
/// and every ranking engine actually speak.
///
/// This is the join that was missing. `EquipmentRecord.equipmentType` is manufacturer vocabulary —
/// "Selectorized", "Plate-Loaded", "Bench/Rack" — while `ExerciseCandidate.equipment` only ever
/// holds one of six tokens seeded by `ExerciseCatalog`: barbell, dumbbell, cable, machine,
/// bodyweight, kettlebell. Comparing the two directly (lowercase-and-hope) matches *nothing*: not
/// one of the 857 "Selectorized" records equals "machine". Any gym-equipment signal that skips this
/// step is silently dead, which is exactly what the earlier, unwired version did.
enum GymEquipmentTaxonomy {

    /// Every exercise-catalog equipment token, so callers can reason about the closed vocabulary.
    static let exerciseVocabulary: Set<String> = [
        "barbell", "dumbbell", "cable", "machine", "bodyweight", "kettlebell",
    ]

    /// The coarse token(s) a catalog machine makes available. One machine can back more than one:
    /// a bench/rack is where both barbell and dumbbell work happens.
    ///
    /// Returns empty for equipment that trains nothing — storage, cardio, accessories — so racks of
    /// dumbbells don't get mistaken for evidence of a lifting station.
    static func coarseTypes(forCatalogType raw: String) -> Set<String> {
        let t = raw.lowercased()
        var out: Set<String> = []

        // Order matters only in that every clause is additive; a "Bench/Rack / Plate-Loaded"
        // legitimately contributes both free-weight and machine tokens.
        if t.contains("cable") { out.insert("cable") }
        if t.contains("selectorized") || t.contains("plate-loaded") || t.contains("plate loaded")
            || t.contains("machine") || t.contains("smart strength")
            || t.contains("multi-station") || t.contains("multi station") {
            // Every clause here is a real string in the shipping catalog. "multi-station" is NOT
            // covered by "machine" — the catalog spells it without that word, and dropping the
            // clause silently orphaned all 53 "Multi-Station"/"Cable / Multi-Station" records.
            // `GymEquipmentTaxonomyTests` sweeps the real catalog to keep that from recurring.
            out.insert("machine")
        }
        if t.contains("bench") || t.contains("rack") {
            // A bench or rack is a free-weight station, not a machine — it enables barbell and
            // dumbbell work. Storage racks are filtered out below, before this can fire on them.
            out.insert("barbell")
            out.insert("dumbbell")
        }
        if t.contains("bodyweight") { out.insert("bodyweight") }
        return out
    }

    /// Equipment types that say nothing about what a gym can train — a dumbbell rack, a treadmill,
    /// a stretching mat. Excluded from the inventory entirely so they neither inflate the count the
    /// lifter sees nor leak a bogus "barbell" token out of the word "rack".
    static func isTrainingRelevant(catalogType raw: String) -> Bool {
        let t = raw.lowercased()
        if t.contains("storage") || t.contains("accessory") { return false }
        if t.contains("cardio") || t.contains("flexibility") { return false }
        return true
    }

    /// A human-facing grouping for the "My Gym" list — coarse enough that a lifter recognizes it.
    static func displayCategory(forCatalogType raw: String) -> String {
        let t = raw.lowercased()
        if t.contains("cable") { return "Cable" }
        if t.contains("bench") || t.contains("rack") { return "Benches & racks" }
        if t.contains("plate") { return "Plate-loaded" }
        if t.contains("selectorized") || t.contains("strength machine") || t.contains("smart strength") {
            return "Selectorized"
        }
        if t.contains("multi") { return "Multi-station" }
        if t.contains("bodyweight") { return "Bodyweight" }
        return "Other"
    }
}

/// What the app believes one gym has.
///
/// **An empty inventory means UNKNOWN, never "this gym has nothing."** Nothing may use it as a hard
/// filter, and every consumer must no-op when `isKnown` is false — the lifter's first session at a
/// new gym must not be met with an app that thinks the place is empty. Every read path in this
/// feature honors that, and any new one has to as well.
struct GymInventory {
    let gymID: String
    let gymName: String
    /// Machine-model identities present at this gym (`EquipmentRecord.dedupeKey`).
    let dedupeKeys: Set<String>
    /// Identities the lifter explicitly said this gym does *not* have.
    let excludedKeys: Set<String>
    /// Coarse equipment tokens, already translated into the exercise catalog's vocabulary.
    let equipmentTypes: Set<String>
    let brands: Set<String>
    let entries: [GymEquipmentEntry]

    static let unknown = GymInventory(gymID: "", gymName: "", dedupeKeys: [], excludedKeys: [],
                                      equipmentTypes: [], brands: [], entries: [])

    /// False when there's nothing learned yet — treat as "we don't know," not "it has nothing."
    var isKnown: Bool { !dedupeKeys.isEmpty }
    var machineCount: Int { dedupeKeys.count }

    func has(dedupeKey: String) -> Bool { dedupeKeys.contains(dedupeKey) }
    func isExcluded(dedupeKey: String) -> Bool { excludedKeys.contains(dedupeKey) }
    /// True only when we know the gym *and* know it lacks this — never true on an unknown gym.
    func knownMissing(dedupeKey: String) -> Bool {
        isKnown && (excludedKeys.contains(dedupeKey) || !dedupeKeys.contains(dedupeKey))
    }

    /// Build from entries, coarsening types through `GymEquipmentTaxonomy` exactly once.
    init(gymID: String, gymName: String, entries: [GymEquipmentEntry]) {
        self.gymID = gymID
        self.gymName = gymName
        self.entries = entries.filter { !$0.isExcluded }
        var keys: Set<String> = [], excluded: Set<String> = [], types: Set<String> = [], brands: Set<String> = []
        for e in entries {
            guard !e.dedupeKey.isEmpty else { continue }
            if e.isExcluded { excluded.insert(e.dedupeKey); continue }
            keys.insert(e.dedupeKey)
            types.formUnion(GymEquipmentTaxonomy.coarseTypes(forCatalogType: e.equipmentType))
            if !e.brandName.isEmpty { brands.insert(e.brandName) }
        }
        self.dedupeKeys = keys
        self.excludedKeys = excluded
        self.equipmentTypes = types
        self.brands = brands
    }

    private init(gymID: String, gymName: String, dedupeKeys: Set<String>, excludedKeys: Set<String>,
                 equipmentTypes: Set<String>, brands: Set<String>, entries: [GymEquipmentEntry]) {
        self.gymID = gymID; self.gymName = gymName; self.dedupeKeys = dedupeKeys
        self.excludedKeys = excludedKeys; self.equipmentTypes = equipmentTypes
        self.brands = brands; self.entries = entries
    }
}
