import Foundation

enum MuscleGroup: String, CaseIterable {
    case chest, back, shoulders, arms, legs, glutes, core
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

    /// Map a primaryMuscle string to a broad group. Mirrors BodyPartFilter.from but centralised.
    static func group(forMuscle muscle: String) -> MuscleGroup? {
        let m = normalize(muscle)
        if m.contains("pec") || m.contains("chest") { return .chest }
        if m.contains("rear delt") { return .back }      // posterior delts trained on pull days
        if m.contains("lat") || m.contains("back") || m.contains("trap") || m.contains("rhomboid") { return .back }
        if m.contains("delt") || m.contains("shoulder") { return .shoulders }
        if m.contains("bicep") || m.contains("tricep") || m.contains("forearm") || m.contains("brachialis") { return .arms }
        if m.contains("glute") || m.contains("hip") || m.contains("adductor") || m.contains("abductor") { return .glutes }
        if m.contains("quad") || m.contains("hamstring") || m.contains("calf") || m.contains("calves") || m.contains("leg") || m.contains("tibialis") { return .legs }
        if m.contains("ab") || m.contains("oblique") || m.contains("core") { return .core }
        return nil
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
