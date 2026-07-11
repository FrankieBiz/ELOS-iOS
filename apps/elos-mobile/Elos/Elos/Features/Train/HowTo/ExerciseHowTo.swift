import Foundation
import SwiftData

/// Reference how-to content for a generic exercise. Keyed on the generic exercise,
/// so every brand-machine variant inherits it. Pure value type.
struct ExerciseHowTo: Identifiable, Equatable {
    let name: String
    let steps: [String]
    let imageKey: String?   // nil -> no bundled photo

    var id: String { name }

    /// Returns nil when the record has no instructions (ⓘ then falls back to the muscle caption).
    static func from(record: ExerciseDefinitionRecord) -> ExerciseHowTo? {
        let steps = record.instructions
        guard !steps.isEmpty else { return nil }
        let key = record.imageKey.isEmpty ? nil : record.imageKey
        return ExerciseHowTo(name: record.name, steps: steps, imageKey: key)
    }
}

/// Looks up how-to content for an exercise by its (catalog) name.
enum ExerciseHowToLookup {
    static func find(name: String, in context: ModelContext) -> ExerciseHowTo? {
        var descriptor = FetchDescriptor<ExerciseDefinitionRecord>(
            predicate: #Predicate { $0.name == name }
        )
        descriptor.fetchLimit = 5
        let matches = (try? context.fetch(descriptor)) ?? []
        // Prefer a global catalog row (empty ownerID) over a custom one.
        let record = matches.first(where: { $0.ownerID.isEmpty }) ?? matches.first
        return record.flatMap { ExerciseHowTo.from(record: $0) }
    }

    /// Resolve the generic exercise a machine corresponds to, by name — conservatively.
    /// Matches only when the machine name equals an enriched exercise name, or ends with it
    /// on a word boundary (" <name>"). Returns a name ONLY if the match is unambiguous:
    /// - exactly one distinct enriched name matches, AND
    /// - that matched name is not itself a word-boundary suffix of any other enriched name
    ///   (which would mean the match is a sub-term of a longer exercise name — too ambiguous).
    /// Otherwise nil. Never guesses.
    static func resolveGenericName(machineName: String, enrichedNames: [String]) -> String? {
        let mn = machineName.lowercased()
        let matches = enrichedNames.filter { name in
            let n = name.lowercased()
            return mn == n || mn.hasSuffix(" " + n)
        }
        let distinct = Set(matches.map { $0.lowercased() })
        guard distinct.count == 1, let matched = matches.first else { return nil }   // 0 = no match, >1 = ambiguous
        // Secondary check: if the matched name is a suffix-word of any OTHER enriched name,
        // we can't distinguish between them — bail out.
        let matchedLower = matched.lowercased()
        let isSubterm = enrichedNames.contains { other in
            let o = other.lowercased()
            guard o != matchedLower else { return false }
            return o == matchedLower || o.hasSuffix(" " + matchedLower)
        }
        guard !isSubterm else { return nil }
        return matched
    }

    /// Full resolution for an in-session exercise: exact name first, then a conservative
    /// machine fallback (only for an un-swapped brand-machine pick).
    static func find(for exercise: Exercise, in context: ModelContext) -> ExerciseHowTo? {
        if let ht = find(name: exercise.name, in: context) { return ht }
        // Machine fallback: only when this is still the original branded machine pick
        // (name starts with the brand). After a name-only swap the machine identity is stale, so skip.
        guard !exercise.isGenericExercise,
              let brand = exercise.equipmentBrandName, !brand.isEmpty,
              exercise.name.hasPrefix(brand),
              let key = exercise.equipmentDedupeKey, !key.isEmpty,
              let machine = EquipmentDatabase.find(dedupeKey: key) else { return nil }
        let all = (try? context.fetch(FetchDescriptor<ExerciseDefinitionRecord>())) ?? []
        let enrichedNames = all.filter { $0.ownerID.isEmpty && !$0.instructions.isEmpty }.map { $0.name }
        guard let generic = resolveGenericName(machineName: machine.machineName, enrichedNames: enrichedNames) else { return nil }
        return find(name: generic, in: context)
    }
}
