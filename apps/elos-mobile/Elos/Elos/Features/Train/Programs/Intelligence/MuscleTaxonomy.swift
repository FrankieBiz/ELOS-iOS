import Foundation

enum MuscleGroup: String, CaseIterable {
    case chest, back, shoulders, arms, legs, glutes, core

    var displayName: String { rawValue.capitalized }

    /// The fine muscles that roll up into this group, in display order. Derived from
    /// `FineMuscle.group` rather than restated, so the two directions can't drift apart —
    /// `FineMuscle`'s cases are declared grouped in the order they should render.
    var children: [FineMuscle] {
        FineMuscle.allCases.filter { $0.group == self }
    }
}

/// The display-level muscle slot — one level finer than `MuscleGroup`, coarser than the raw
/// `primaryMuscle` strings in the catalog. Volume landmarks live at this level because that's where
/// the training literature defines them, and because "Legs 24 sets" hides "hamstrings: 0".
enum FineMuscle: String, CaseIterable {
    case chest
    case lats, upperBack, lowerBack, rearDelts
    case frontDelts, sideDelts, rotatorCuff
    case biceps, triceps, forearms
    case quads, hamstrings, calves
    case glutes
    case abs

    var displayName: String {
        switch self {
        case .chest:       return "Chest"
        case .lats:        return "Lats"
        case .upperBack:   return "Upper back"
        case .lowerBack:   return "Lower back"
        case .rearDelts:   return "Rear delts"
        case .frontDelts:  return "Front delts"
        case .sideDelts:   return "Side delts"
        case .rotatorCuff: return "Rotator cuff"
        case .biceps:      return "Biceps"
        case .triceps:     return "Triceps"
        case .forearms:    return "Forearms"
        case .quads:       return "Quads"
        case .hamstrings:  return "Hamstrings"
        case .calves:      return "Calves"
        case .glutes:      return "Glutes"
        case .abs:         return "Abs"
        }
    }

    /// The broad group this rolls up into. Canonical definition of the fine→broad edge;
    /// `MuscleTaxonomy.group(forFine:)` delegates here so there is exactly one switch.
    var group: MuscleGroup {
        switch self {
        case .chest:                                    return .chest
        case .lats, .upperBack, .lowerBack, .rearDelts: return .back
        case .frontDelts, .sideDelts, .rotatorCuff:     return .shoulders
        case .biceps, .triceps, .forearms:              return .arms
        case .quads, .hamstrings, .calves:              return .legs
        case .glutes:                                   return .glutes
        case .abs:                                      return .core
        }
    }
}

enum SplitArchetype: String, CaseIterable {
    case push, pull, legs, upper, lower, fullBody, arms, core
}

enum MuscleTaxonomy {
    static func normalize(_ s: String) -> String {
        s.lowercased()
            .replacingOccurrences(of: "_", with: " ")
            .replacingOccurrences(of: "-", with: " ")
            .trimmingCharacters(in: .whitespaces)
    }

    private static let compoundPatterns: Set<String> = ["push", "pull", "squat", "hinge", "carry"]
    static func isCompound(movementPattern p: String) -> Bool {
        compoundPatterns.contains(p.lowercased().trimmingCharacters(in: .whitespaces))
    }

    /// Every `primaryMuscle` / `secondaryMuscles` string used by the seed catalog
    /// (`ExerciseSeedData.swift`). Exposed so tests can walk the real vocabulary rather than a
    /// hand-picked sample — if a new muscle string is seeded, add it here and the tests will police it.
    static let knownMuscleVocabulary: [String] = [
        "chest", "upper_chest", "lower_chest",
        "back", "lower_back", "lats", "traps", "lower_traps", "rhomboids", "rear_delts",
        "front_delts", "side_delts", "external_rotators", "internal_rotators",
        "biceps", "brachialis", "triceps", "forearms",
        "quads", "hamstrings", "calves",
        "glutes", "adductors", "hip_abductors",
        "core", "obliques", "hip_flexors",
    ]

    /// Map a raw muscle string to its display-level slot. Returns nil only for strings outside the
    /// known vocabulary (e.g. a user's custom exercise with a free-text muscle).
    static func fine(forMuscle muscle: String) -> FineMuscle? {
        let m = normalize(muscle)

        // Order matters: the more specific test must precede the substring it contains.
        if m.contains("pec") || m.contains("chest") { return .chest }
        if m.contains("rear delt") { return .rearDelts }
        if m.contains("lat") && !m.contains("lateral") { return .lats }
        if m.contains("lower back") || m.contains("erector") || m.contains("spinal") { return .lowerBack }
        if m.contains("trap") || m.contains("rhomboid") { return .upperBack }
        if m.contains("back") { return .upperBack }
        if m.contains("front delt") { return .frontDelts }
        if m.contains("side delt") || m.contains("lateral delt") { return .sideDelts }
        if m.contains("rotator") || m.contains("infraspinatus") || m.contains("supraspinatus") { return .rotatorCuff }
        if m.contains("delt") || m.contains("shoulder") { return .sideDelts }  // generic "shoulders"
        if m.contains("bicep") || m.contains("brachialis") { return .biceps }
        if m.contains("tricep") { return .triceps }
        if m.contains("forearm") || m.contains("grip") { return .forearms }
        if m.contains("quad") { return .quads }
        if m.contains("hamstring") { return .hamstrings }
        if m.contains("calf") || m.contains("calves") || m.contains("tibialis") { return .calves }
        // Hip flexors are anterior-core (leg raises, knee tucks), NOT glutes — this must precede the
        // generic "hip" test below, which would otherwise swallow it.
        if m.contains("hip flexor") { return .abs }
        if m.contains("glute") || m.contains("hip") || m.contains("adductor") || m.contains("abductor") { return .glutes }
        if m.contains("ab") || m.contains("oblique") || m.contains("core") { return .abs }
        if m.contains("leg") { return .quads }   // generic "legs"
        return nil
    }

    static func group(forFine fine: FineMuscle) -> MuscleGroup { fine.group }

    /// Map a primaryMuscle string to a broad group. Derived from `fine(forMuscle:)` so the two levels
    /// can never disagree — a single source of truth rather than two parallel keyword ladders.
    ///
    /// Two deliberate behavior changes vs. the pre-`FineMuscle` implementation, both bug fixes:
    /// - `external_rotators` / `internal_rotators` used to fall through to `nil` (7 seeded exercises
    ///   were invisible to every scorer); they now classify as `.shoulders`.
    /// - `hip_flexors` used to hit the generic `contains("hip")` test and land in `.glutes`; it is
    ///   core work (leg raises) and now classifies as `.core`, matching the old chips UI.
    static func group(forMuscle muscle: String) -> MuscleGroup? {
        fine(forMuscle: muscle)?.group
    }

    static func targetMuscles(forArchetype a: SplitArchetype) -> Set<String> {
        switch a {
        case .push:     return ["chest", "front delts", "side delts", "triceps"]
        case .pull:     return ["lats", "back", "traps", "rear delts", "biceps", "forearms"]
        case .legs, .lower: return ["quads", "hamstrings", "glutes", "calves", "adductors"]
        case .upper:    return ["chest", "back", "lats", "front delts", "side delts", "rear delts", "biceps", "triceps", "traps"]
        case .fullBody: return ["chest", "back", "lats", "quads", "hamstrings", "glutes", "front delts", "biceps", "triceps", "core"]
        case .arms:     return ["biceps", "triceps", "forearms", "brachialis"]
        case .core:     return ["abs", "core", "obliques", "hip flexors"]
        }
    }

    /// Free-text day name → archetype. Returns nil when nothing matches.
    static func archetype(forDayName name: String) -> SplitArchetype? {
        let n = normalize(name)
        guard !n.isEmpty else { return nil }
        if n.contains("full body") || n.contains("full-body") { return .fullBody }
        if n.contains("upper") { return .upper }
        if n.contains("lower") { return .lower }
        if n.contains("push") || (n.contains("chest") && n.contains("tri")) { return .push }
        if n.contains("pull") || (n.contains("back") && n.contains("bi")) { return .pull }
        if n.contains("leg") || n.contains("quad") || n.contains("hamstring") { return .legs }
        if n.contains("arm") && !n.contains("warm") { return .arms }
        if n.contains("core") || n.contains("abs") { return .core }
        if n.contains("chest") { return .push }
        if n.contains("back") { return .pull }
        if n.contains("shoulder") || n.contains("delt") { return .push }
        return nil
    }

    static func antagonist(of group: MuscleGroup) -> MuscleGroup? {
        switch group {
        case .chest: return .back
        case .back: return .chest
        case .legs: return .glutes
        case .glutes: return .legs
        default: return nil
        }
    }
}
