import Foundation

/// Top-level coordinator. Resolves the builder's exercises against the catalog, runs the shared
/// muscle/movement analyzers once, feeds them to the dimension scorers, computes the weighted
/// 0–100 composite, and merges/ranks the tips. Pure and synchronous — cheap enough to recompute on
/// every keystroke, provided callers compute it *once* per view body rather than per row.
enum TemplateQualityEngine {

    /// Composite weights, per scope. Each column sums to 1.0.
    ///
    /// `fatigue` earns real weight rather than a token slice: whether the sets land while the lifter
    /// can still do them justice is on the same footing as whether the dose is right, and it's the
    /// dimension that explains why two plans with identical set counts aren't equally good. Adding it
    /// necessarily rescales every other dimension, so scores from before this change sit a few points
    /// away from scores after it — the ranking between two plans is what's meaningful, not the
    /// absolute number's continuity across engine versions.
    static func weight(_ d: QualityDimension, scope: QualityScope) -> Double {
        switch scope {
        case .weeklySplit:
            switch d {
            case .volume:    return 0.24
            case .balance:   return 0.19
            case .selection: return 0.17
            case .repRest:   return 0.13
            case .frequency: return 0.13
            case .fatigue:   return 0.14
            }
        case .singleSession:
            switch d {
            case .volume:    return 0.26
            case .balance:   return 0.21
            case .selection: return 0.21
            case .repRest:   return 0.16
            case .frequency: return 0.0   // not applicable to one workout
            case .fatigue:   return 0.16
            }
        }
    }

    static func score(days: [[ScoredExercise]],
                      dayNames: [String],
                      scope: QualityScope,
                      profile: TrainingProfile,
                      catalog: [ExerciseCandidate],
                      intent: TrainingIntent? = nil,
                      dayExclusions: [Set<FineMuscle>] = [],
                      dayIsRest: [Bool] = []) -> QualityReport {
        // A day that actually contributes training. Not `!dayIsRest[i]` alone — a day toggled to
        // Rest in the split builder keeps its exercises in state (and keeps being scored), so
        // `!isEmpty` matters too. Out-of-range `i` reads as non-rest, matching `dayIsRest`'s own
        // "shorter array means no opinion" default elsewhere.
        func isTrainingDay(_ i: Int) -> Bool {
            !(i < dayIsRest.count && dayIsRest[i]) && !days[i].isEmpty
        }
        // A day index with no corresponding `dayExclusions` entry votes as an empty exclusion set
        // (killing the intersection) rather than being skipped — a caller passing a short array
        // must not be able to widen the weekly exclusion by omission.
        func exclusions(_ i: Int) -> Set<FineMuscle> {
            i < dayExclusions.count ? dayExclusions[i] : []
        }
        // A muscle the lifter has skipped on *every* day they actually train is skipped for the
        // week — there is no remaining day that disagrees. Only training days vote: folding a
        // rest/empty day's implicit empty exclusion set into the intersection would zero it out
        // and disable the rule entirely.
        let weeklyExclusions: Set<FineMuscle> = {
            guard scope == .weeklySplit else { return [] }
            let voting = days.indices.filter(isTrainingDay)
            guard let first = voting.first else { return [] }
            return voting.dropFirst().reduce(exclusions(first)) { $0.intersection(exclusions($1)) }
        }()

        // Day-scoped exclusions only apply at the scope a single day actually has — this makes D1
        // (a day-level "skip this muscle" never affects a split's weekly score, UNLESS every
        // active day agrees, see `weeklyExclusions` above) an engine-level guarantee rather than
        // something every call site has to remember to withhold. The *global* exclusion set
        // (`profile.volumeOverrides.excludedMuscles`) is not scope-gated.
        let dayScopedExclusions: Set<FineMuscle> = scope == .singleSession ? (intent?.excludedMuscles ?? []) : []
        let excludedMuscles = profile.volumeOverrides.excludedMuscles
            .union(dayScopedExclusions)
            .union(weeklyExclusions)
        var effectiveOverrides = profile.volumeOverrides
        effectiveOverrides.excludedMuscles = excludedMuscles
        let profile = TrainingProfile(goal: profile.goal, experience: profile.experience,
                                      volumeOverrides: effectiveOverrides)

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
                                intent: intent, volume: volume, catalog: catalog,
                                excludedMuscles: excludedMuscles),
            SelectionScorer.score(resolvedDays: resolvedDays, scope: scope, profile: profile,
                                  movement: movement),
            RepRestScorer.score(resolvedDays: resolvedDays, scope: scope, profile: profile),
            FrequencyScorer.score(volume: volume, scope: scope, profile: profile),
            FatigueScorer.score(resolvedDays: resolvedDays, dayNames: dayNames, scope: scope),
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
