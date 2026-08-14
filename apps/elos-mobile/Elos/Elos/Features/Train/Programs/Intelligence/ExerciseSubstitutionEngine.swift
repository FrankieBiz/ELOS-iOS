import Foundation

struct SubstitutionSuggestion: Identifiable, Equatable {
    let id: String
    let name: String
    let score: Int
    let reason: String
}

enum ExerciseSubstitutionEngine {
    /// Resolves the session `Exercise` being swapped (known only by name) to its catalog
    /// candidate. Returns nil for custom exercises, renamed lifts, or any name that doesn't
    /// resolve — callers treat that the same as "nothing to suggest," not a special case.
    static func resolveSource(name: String, candidates: [ExerciseCandidate]) -> ExerciseCandidate? {
        let key = MuscleTaxonomy.normalize(name)
        return candidates.first { MuscleTaxonomy.normalize($0.name) == key }
    }
}
