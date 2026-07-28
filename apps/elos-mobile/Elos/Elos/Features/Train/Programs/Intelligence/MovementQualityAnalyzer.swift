import Foundation

/// The movement-selection picture behind the Selection score, exposed so the builder can *show* the
/// compound/isolation mix instead of only warning when it's bad.
///
/// Two compound fractions are reported on purpose, and they are not interchangeable:
/// - `compoundFractionByCount` — share of *exercises* that are compound. This is what
///   `SelectionScorer` has always judged, and `TrainingScience.minCompoundFraction` is tuned against
///   it, so it stays the scoring input (changing it would silently retune a shipped score).
/// - `compoundFractionBySets` — share of *working sets*. This is what the stacked bar renders, because
///   a bar of set volume is what the lifter is actually looking at.
struct MovementProfile: Equatable {
    let compoundSets: Double
    let isolationSets: Double
    /// Sets whose exercise couldn't be resolved against the catalog (custom/free-text entries).
    let unclassifiedSets: Double
    let compoundFractionByCount: Double
    let compoundFractionBySets: Double
    /// Working sets per movement pattern, e.g. ["squat": 8, "hinge": 6, "isolation": 9].
    let setsByPattern: [String: Double]
    /// Patterns the intent implies but that are absent, in a stable display order.
    let missingPatterns: [String]

    static let empty = MovementProfile(
        compoundSets: 0, isolationSets: 0, unclassifiedSets: 0,
        compoundFractionByCount: 0, compoundFractionBySets: 0,
        setsByPattern: [:], missingPatterns: [])

    var classifiedSets: Double { compoundSets + isolationSets }
}

enum MovementQualityAnalyzer {

    /// The production pattern vocabulary, in the order the UI shows them (compounds first, biggest
    /// movements leading). Verified against both the iOS seed (`ExerciseSeedData.swift`) and the API
    /// seed migrations, which agree on exactly these eight.
    static let displayOrder = ["squat", "hinge", "push", "pull", "carry", "rotation", "core", "isolation"]

    /// Fold a raw pattern onto a display bucket. Anything outside the production vocabulary
    /// (`curl`, `raise`, `pushdown`, `extension` — present in test fixtures, and possible from a
    /// user's custom exercise) is non-compound by `MuscleTaxonomy.isCompound`, so it buckets as
    /// isolation rather than silently vanishing from the breakdown.
    static func displayBucket(forPattern p: String) -> String {
        let n = p.lowercased().trimmingCharacters(in: .whitespaces)
        return displayOrder.contains(n) ? n : "isolation"
    }

    static func analyze(resolvedDays: [[ResolvedExercise]],
                        scope: QualityScope,
                        intent: TrainingIntent?,
                        dayNames: [String],
                        catalog: [ExerciseCandidate]) -> MovementProfile {
        let all = resolvedDays.flatMap { $0 }
        guard !all.isEmpty else { return .empty }

        var compoundSets = 0.0, isolationSets = 0.0, unclassifiedSets = 0.0
        var compoundCount = 0, knownCount = 0
        var setsByPattern: [String: Double] = [:]

        for r in all {
            let sets = Double(r.exercise.sets)
            guard let pattern = r.movementPattern, r.candidate != nil, !pattern.isEmpty else {
                unclassifiedSets += sets
                continue
            }
            knownCount += 1
            setsByPattern[displayBucket(forPattern: pattern), default: 0] += sets
            if r.isCompound {
                compoundSets += sets
                compoundCount += 1
            } else {
                isolationSets += sets
            }
        }

        let classified = compoundSets + isolationSets
        return MovementProfile(
            compoundSets: compoundSets,
            isolationSets: isolationSets,
            unclassifiedSets: unclassifiedSets,
            compoundFractionByCount: knownCount == 0 ? 0 : Double(compoundCount) / Double(knownCount),
            compoundFractionBySets: classified == 0 ? 0 : compoundSets / classified,
            setsByPattern: setsByPattern,
            missingPatterns: missing(present: Set(setsByPattern.keys),
                                    scope: scope, intent: intent,
                                    dayNames: dayNames, catalog: catalog, all: all))
    }

    // MARK: Expected patterns

    /// Which patterns the plan *should* contain. Explicit intent wins; otherwise fall back to the
    /// day-name inference that predates `TrainingIntent`.
    static func expectedPatterns(scope: QualityScope,
                                 intent: TrainingIntent?,
                                 dayNames: [String],
                                 catalog: [ExerciseCandidate],
                                 all: [ResolvedExercise]) -> Set<String> {
        switch scope {
        case .weeklySplit:
            // A complete week should contain both lower-body hips patterns and both upper directions.
            return ["squat", "hinge", "push", "pull"]

        case .singleSession:
            let focus: SplitArchetype? = intent?.focus ?? inferredArchetype(
                dayNames: dayNames, catalog: catalog, all: all)
            guard let focus else { return [] }   // unknown focus → don't invent requirements
            return patterns(for: focus)
        }
    }

    static func patterns(for focus: SplitArchetype) -> Set<String> {
        switch focus {
        case .push:         return ["push"]
        case .pull:         return ["pull"]
        case .legs, .lower: return ["squat", "hinge"]
        case .upper:        return ["push", "pull"]
        case .fullBody:     return ["squat", "push", "pull"]
        case .arms, .core:  return []   // accessory days — no compound requirement
        }
    }

    private static func missing(present: Set<String>,
                                scope: QualityScope,
                                intent: TrainingIntent?,
                                dayNames: [String],
                                catalog: [ExerciseCandidate],
                                all: [ResolvedExercise]) -> [String] {
        let expected = expectedPatterns(scope: scope, intent: intent, dayNames: dayNames,
                                        catalog: catalog, all: all)
        return displayOrder.filter { expected.contains($0) && !present.contains($0) }
    }

    private static func inferredArchetype(dayNames: [String],
                                          catalog: [ExerciseCandidate],
                                          all: [ResolvedExercise]) -> SplitArchetype? {
        let added = all.map {
            DayExercise(id: $0.exercise.id, name: $0.exercise.name,
                        sets: $0.exercise.sets, reps: $0.exercise.repsText)
        }
        return DayContextInferrer.infer(dayName: dayNames.first ?? "",
                                       added: added, catalog: catalog).archetype
    }

    // MARK: Display helpers

    static func label(forPattern p: String) -> String {
        switch p {
        case "squat":     return "Squat"
        case "hinge":     return "Hinge"
        case "push":      return "Push"
        case "pull":      return "Pull"
        case "carry":     return "Carry"
        case "rotation":  return "Rotation"
        case "core":      return "Core"
        case "isolation": return "Isolation"
        default:          return p.capitalized
        }
    }

    /// A concrete example movement, used in "add a hinge (deadlift, RDL)" style copy.
    static func examples(forPattern p: String) -> String {
        switch p {
        case "squat": return "squat, leg press, lunge"
        case "hinge": return "deadlift, RDL, hip thrust"
        case "push":  return "bench press, overhead press"
        case "pull":  return "row, pull-up, lat pulldown"
        case "carry": return "farmer's carry, suitcase carry"
        default:      return ""
        }
    }
}
