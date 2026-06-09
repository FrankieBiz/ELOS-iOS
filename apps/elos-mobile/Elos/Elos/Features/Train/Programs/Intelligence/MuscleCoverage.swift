import Foundation

enum CoverageLevel { case none, some, good }

struct CoverageChip: Identifiable, Equatable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let level: CoverageLevel
}

enum MuscleCoverage {
    static func chips(context: DayContext, addedCandidates: [ExerciseCandidate]) -> [CoverageChip] {
        var groups: [MuscleGroup] = []
        for m in context.targetMuscles.sorted() {
            if let g = MuscleTaxonomy.group(forMuscle: m), !groups.contains(g) { groups.append(g) }
        }
        return groups.map { group in
            var primaryHits = 0, secondaryHits = 0
            for c in addedCandidates {
                if MuscleTaxonomy.group(forMuscle: c.primaryMuscle) == group { primaryHits += 1 }
                else if c.secondaryMuscles.contains(where: { MuscleTaxonomy.group(forMuscle: $0) == group }) { secondaryHits += 1 }
            }
            let level: CoverageLevel = primaryHits >= 2 ? .good
                : (primaryHits == 1 || secondaryHits >= 1) ? .some : .none
            return CoverageChip(muscleGroup: group.rawValue.capitalized, level: level)
        }
    }
}
