import Foundation

enum CoverageLevel { case none, some, good }

struct CoverageChip: Identifiable, Equatable {
    var id: String { muscleGroup }
    let muscleGroup: String
    let level: CoverageLevel
}

enum MuscleCoverage {
    /// Coverage per broad group for the picker's chip strip.
    ///
    /// Counts `context.addedTargets` — the resolved answer for each added exercise — rather than
    /// looking exercises back up in the catalog. That's what lets a machine picked straight from the
    /// picker count at all: it has no catalog entry, so the old catalog-matched version silently
    /// skipped it and reported the group as uncovered.
    static func chips(context: DayContext) -> [CoverageChip] {
        var groups: [MuscleGroup] = []
        for m in context.targetMuscles.sorted() {
            if let g = MuscleTaxonomy.group(forMuscle: m), !groups.contains(g) { groups.append(g) }
        }
        return groups.map { group in
            var primaryHits = 0, secondaryHits = 0
            for t in context.addedTargets {
                if t.primary.contains(where: { $0.group == group }) { primaryHits += 1 }
                else if t.secondary.contains(where: { $0.group == group }) { secondaryHits += 1 }
            }
            let level: CoverageLevel = primaryHits >= 2 ? .good
                : (primaryHits == 1 || secondaryHits >= 1) ? .some : .none
            return CoverageChip(muscleGroup: group.rawValue.capitalized, level: level)
        }
    }
}
