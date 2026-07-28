import Foundation

/// Top-level coordinator. Resolves the builder's exercises against the catalog, runs the shared
/// muscle/movement analyzers once, feeds them to the dimension scorers, computes the weighted
/// 0–100 composite, and merges/ranks the tips. Pure and synchronous — cheap enough to recompute on
/// every keystroke, provided callers compute it *once* per view body rather than per row.
enum TemplateQualityEngine {

    /// Composite weights, per scope. Each column sums to 1.0.
    ///
    /// The `.singleSession` column is unchanged from before `frequency` existed, so template scores
    /// stay comparable across the change. (Session scores still move a little, because volume is now
    /// counted fractionally — the weights are stable, the inputs are more accurate.)
    static func weight(_ d: QualityDimension, scope: QualityScope) -> Double {
        switch scope {
        case .weeklySplit:
            switch d {
            case .volume:    return 0.28
            case .balance:   return 0.22
            case .selection: return 0.20
            case .repRest:   return 0.15
            case .frequency: return 0.15
            }
        case .singleSession:
            switch d {
            case .volume:    return 0.30
            case .balance:   return 0.25
            case .selection: return 0.25
            case .repRest:   return 0.20
            case .frequency: return 0.0   // not applicable to one workout
            }
        }
    }

    static func score(days: [[ScoredExercise]],
                      dayNames: [String],
                      scope: QualityScope,
                      profile: TrainingProfile,
                      catalog: [ExerciseCandidate],
                      intent: TrainingIntent? = nil) -> QualityReport {
        let resolvedDays = ExerciseResolver.resolve(days, catalog: catalog)
        let totalExercises = resolvedDays.reduce(0) { $0 + $1.count }

        // Shared analyzers — run once, consumed by several scorers and by the UI.
        let volume = MuscleVolumeAnalyzer.analyze(resolvedDays: resolvedDays, scope: scope,
                                                  intent: intent, dayNames: dayNames,
                                                  profile: profile, catalog: catalog)
        let movement = MovementQualityAnalyzer.analyze(resolvedDays: resolvedDays, scope: scope,
                                                       intent: intent, dayNames: dayNames,
                                                       catalog: catalog)

        // Gate: hold *scoring* until there's enough to judge — a half-built plan would flag
        // "low volume" on everything, which reads as nagging rather than coaching. The bars and
        // movement profile are still returned so coverage can fill in as they build.
        let minToScore = scope == .singleSession ? 2 : 3
        guard totalExercises >= minToScore else {
            return QualityReport(overall: 0, tier: .needsWork, dimensions: [], tips: [],
                                 isScored: false, volume: volume, movement: movement)
        }

        let dimensions = [
            VolumeScorer.score(volume: volume, scope: scope, profile: profile),
            BalanceScorer.score(resolvedDays: resolvedDays, scope: scope, dayNames: dayNames,
                                intent: intent, volume: volume, catalog: catalog),
            SelectionScorer.score(resolvedDays: resolvedDays, scope: scope, profile: profile,
                                  movement: movement),
            RepRestScorer.score(resolvedDays: resolvedDays, scope: scope, profile: profile),
            FrequencyScorer.score(volume: volume, scope: scope, profile: profile),
        ]

        var weighted = 0.0
        for dim in dimensions {
            weighted += Double(dim.score) * weight(dim.dimension, scope: scope)
        }
        let overall = Int(weighted.rounded())

        // Only surface tips from dimensions that apply at this scope.
        let applicable = dimensions.filter { $0.dimension.applies(to: scope) }
        return QualityReport(overall: overall, tier: QualityTier(score: overall),
                             dimensions: dimensions, tips: mergeTips(from: applicable),
                             isScored: true, volume: volume, movement: movement)
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
