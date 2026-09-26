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

    /// Movement patterns specific enough that sharing one is a real signal. `isolation` is a
    /// generic bucket covering unrelated muscles (a leg extension and a bicep curl are both
    /// "isolation") — matching on it tells you nothing, so it's deliberately excluded.
    private static let specificPatterns: Set<String> = ["squat", "hinge", "push", "pull", "carry", "rotation"]

    /// Scores one candidate against the source being swapped out. Returns the total score and the
    /// plain-language reason fragments that fired, in priority order. Internal (not private) so
    /// tests can verify scoring in isolation rather than reverse-engineering it from ranked output.
    static func scoreCandidate(source: ExerciseCandidate, candidate: ExerciseCandidate) -> (score: Int, reasons: [String]) {
        var score = 0
        var reasons: [String] = []

        // Muscle tiers are mutually exclusive — a candidate earns exactly one.
        if MuscleTaxonomy.normalize(source.primaryMuscle) == MuscleTaxonomy.normalize(candidate.primaryMuscle) {
            score += 3
            reasons.append("Same primary muscle (\(candidate.primaryMuscle))")
        } else if let sFine = MuscleTaxonomy.fine(forMuscle: source.primaryMuscle),
                  let cFine = MuscleTaxonomy.fine(forMuscle: candidate.primaryMuscle),
                  sFine == cFine {
            score += 2
            reasons.append("Trains the same muscle (\(cFine.displayName.lowercased()))")
        } else if let sGroup = MuscleTaxonomy.group(forMuscle: source.primaryMuscle),
                  let cGroup = MuscleTaxonomy.group(forMuscle: candidate.primaryMuscle),
                  sGroup == cGroup {
            score += 1
            reasons.append("Same muscle group (\(cGroup.displayName))")
        }

        // Nothing in the data model guarantees canonical casing/whitespace on `movementPattern`
        // (same reason `MuscleTaxonomy.isCompound`, `ScoredExercise.swift`'s `ResolvedExercise`,
        // and `ExercisePickerView.swift:491` all normalize it defensively before comparing) — so
        // normalize both sides here too, or two candidates identical except for pattern casing
        // silently score differently.
        let sourcePattern = source.movementPattern.lowercased().trimmingCharacters(in: .whitespaces)
        let candidatePattern = candidate.movementPattern.lowercased().trimmingCharacters(in: .whitespaces)
        let patternsMatch = sourcePattern == candidatePattern
        if patternsMatch && specificPatterns.contains(candidatePattern) {
            score += 1
            reasons.append("Same \(candidatePattern) pattern")
        }

        let sourceSecondary = Set(source.secondaryMuscles.map(MuscleTaxonomy.normalize))
        let candidateSecondary = Set(candidate.secondaryMuscles.map(MuscleTaxonomy.normalize))
        if !sourceSecondary.isDisjoint(with: candidateSecondary) {
            score += 1
            reasons.append("Overlapping secondary muscles")
        }

        // Only rewards CROSS-pattern compound similarity (e.g. squat vs. hinge). When patterns
        // are identical, the point above already captured that — awarding both double-counts
        // one signal as two.
        if !patternsMatch,
           MuscleTaxonomy.isCompound(movementPattern: source.movementPattern),
           MuscleTaxonomy.isCompound(movementPattern: candidate.movementPattern) {
            score += 1
            reasons.append("Similar compound movement")
        }

        return (score, reasons)
    }

    static func suggest(
        for source: ExerciseCandidate,
        candidates: [ExerciseCandidate],
        equipment: EquipmentPreference,
        limit: Int = 5
    ) -> [SubstitutionSuggestion] {
        let scored: [(candidate: ExerciseCandidate, score: Int, reason: String)] = candidates
            .filter { $0.id != source.id }
            .filter { equipment.isAvailable(equipment: $0.equipment) }
            .compactMap { candidate in
                let (score, reasons) = scoreCandidate(source: source, candidate: candidate)
                guard score >= 2 else { return nil }
                return (candidate, score, reasons.joined(separator: " · "))
            }
            .sorted { lhs, rhs in
                lhs.score != rhs.score ? lhs.score > rhs.score : lhs.candidate.name < rhs.candidate.name
            }

        return scored.prefix(limit).map {
            SubstitutionSuggestion(id: $0.candidate.id, name: $0.candidate.name, score: $0.score, reason: $0.reason)
        }
    }
}
