import Foundation

/// Top-level coordinator. Resolves the builder's exercises against the catalog, runs the four
/// dimension scorers, computes the weighted 0–100 composite, and merges/ranks the tips for
/// inline display. Pure and synchronous — cheap enough to recompute on every keystroke.
enum TemplateQualityEngine {

    /// Composite weights (sum to 1.0).
    private static let weights: [QualityDimension: Double] = [
        .volume:    0.30,
        .balance:   0.25,
        .selection: 0.25,
        .repRest:   0.20,
    ]

    static func score(days: [[ScoredExercise]],
                      dayNames: [String],
                      scope: QualityScope,
                      profile: TrainingProfile,
                      catalog: [ExerciseCandidate]) -> QualityReport {
        let resolvedDays = ExerciseResolver.resolve(days, catalog: catalog)
        let totalExercises = resolvedDays.reduce(0) { $0 + $1.count }

        // Gate: hold scoring until there's enough to judge — a half-built plan would flag
        // "low volume" on everything, which reads as nagging rather than coaching.
        let minToScore = scope == .singleSession ? 2 : 3
        guard totalExercises >= minToScore else { return .empty }

        let dimensions = [
            VolumeScorer.score(resolvedDays: resolvedDays, scope: scope, profile: profile),
            BalanceScorer.score(resolvedDays: resolvedDays, scope: scope, dayNames: dayNames, catalog: catalog),
            SelectionScorer.score(resolvedDays: resolvedDays, scope: scope, profile: profile),
            RepRestScorer.score(resolvedDays: resolvedDays, scope: scope, profile: profile),
        ]

        let overall = Int(dimensions.reduce(0.0) { acc, dim in
            acc + Double(dim.score) * (weights[dim.dimension] ?? 0)
        }.rounded())
        let tier = QualityTier(score: overall)

        let tips = mergeTips(from: dimensions)
        return QualityReport(overall: overall, tier: tier,
                             dimensions: dimensions, tips: tips, isScored: true)
    }

    /// Flatten all dimension tips, dedupe by id, and rank: most urgent first, then weakest
    /// dimension first (so the lowest-scoring area's advice surfaces above incidental notes).
    private static func mergeTips(from dimensions: [DimensionScore]) -> [QualityTip] {
        let scoreByDimension = Dictionary(uniqueKeysWithValues: dimensions.map { ($0.dimension, $0.score) })

        var seen = Set<String>()
        let unique = dimensions.flatMap { $0.tips }.filter { seen.insert($0.id).inserted }

        return unique.sorted { lhs, rhs in
            if lhs.severity != rhs.severity { return lhs.severity > rhs.severity }
            let ls = scoreByDimension[lhs.dimension] ?? 100
            let rs = scoreByDimension[rhs.dimension] ?? 100
            return ls < rs
        }
    }
}
