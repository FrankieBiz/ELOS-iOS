import Foundation

/// One atomic change to a plan. Declarative on purpose: the two builders hold different state
/// types (`TemplateExerciseEntry` vs `DayExercise`), so the engine describes *what* to change and
/// each builder applies it in its own terms rather than handing back a value in a foreign type.
/// Addressed positionally — `dayIndex`/`exerciseIndex` map 1:1 onto each builder's own array —
/// which avoids the name-matching identity trap this repo has hit repeatedly.
enum FixOperation: Equatable {
    case insertExercise(InsertSpec)
    /// `permutation[newIndex] = oldIndex`. Positional, **not** id-keyed: a template exercise with
    /// no catalog match becomes `ScoredExercise(id: "")`, so two such rows on one day are
    /// indistinguishable by id and an id-keyed reorder cannot reproduce the intended ordering —
    /// the same name-as-identity trap this design exists to avoid.
    case reorderDay(dayIndex: Int, permutation: [Int])
    case setReps(dayIndex: Int, exerciseIndex: Int, reps: String)
    /// Single-session scope only. `DayExercise` has no rest field and `ScoredExercise.init(day:)`
    /// hard-codes `restSeconds: nil`, so the split builder's `apply` implements this case as an
    /// intentional no-op.
    case setRest(dayIndex: Int, exerciseIndex: Int, seconds: Int)
}

struct InsertSpec: Equatable {
    let dayIndex: Int
    let insertAt: Int
    let candidate: ExerciseCandidate
    let sets: Int
    let reps: String
}

extension FixOperation {
    /// Every case carries a day index; each stores it differently (buried in `InsertSpec` for
    /// insert, a direct associated value for the rest), so this is the one place that unifies
    /// access rather than every caller re-deriving it per case.
    var dayIndex: Int {
        switch self {
        case .insertExercise(let spec): return spec.dayIndex
        case .reorderDay(let dayIndex, _): return dayIndex
        case .setReps(let dayIndex, _, _): return dayIndex
        case .setRest(let dayIndex, _, _): return dayIndex
        }
    }
}

extension FixOperation {
    /// Pure `[[ScoredExercise]] -> [[ScoredExercise]]`. Out-of-range indices or a non-bijective
    /// permutation return the input unchanged rather than crashing or corrupting state — a stale
    /// preview re-applied after the plan changed underneath it must fail safe.
    func apply(to days: [[ScoredExercise]]) -> [[ScoredExercise]] {
        var result = days
        switch self {
        case .insertExercise(let spec):
            guard result.indices.contains(spec.dayIndex) else { return days }
            let insertAt = min(max(0, spec.insertAt), result[spec.dayIndex].count)
            let new = ScoredExercise(id: spec.candidate.id, name: spec.candidate.name,
                                     sets: spec.sets, repsText: spec.reps,
                                     equipmentId: nil, muscleTargets: nil)
            result[spec.dayIndex].insert(new, at: insertAt)
        case .reorderDay(let dayIndex, let permutation):
            guard result.indices.contains(dayIndex) else { return days }
            let day = result[dayIndex]
            guard permutation.count == day.count,
                  Set(permutation) == Set(0..<day.count) else { return days }
            result[dayIndex] = permutation.map { day[$0] }
        case .setReps(let dayIndex, let exerciseIndex, let reps):
            guard result.indices.contains(dayIndex),
                  result[dayIndex].indices.contains(exerciseIndex) else { return days }
            result[dayIndex][exerciseIndex].repsText = reps
        case .setRest(let dayIndex, let exerciseIndex, let seconds):
            guard result.indices.contains(dayIndex),
                  result[dayIndex].indices.contains(exerciseIndex) else { return days }
            result[dayIndex][exerciseIndex].restSeconds = seconds
        }
        return result
    }
}

/// What the preview renders and what Confirm applies. Built by `QualityFixEngine.propose`, which
/// has already simulated `operations` and re-scored — this struct is the frozen result of that
/// work, never recomputed by the UI.
struct FixProposal: Equatable, Identifiable {
    let tip: QualityTip
    let operations: [FixOperation]
    let summary: FixSummary
    let before: QualityReport
    let after: QualityReport
    /// Whether simulating `operations` actually cleared the targeted tip. Matched on
    /// `(id, action)` by the engine — `sel-order` reuses one id across days, so an id-only check
    /// would report false success.
    let resolvesTip: Bool
    /// Ranked #2/#3 candidates for an insert fix, for "use a different exercise". Empty otherwise.
    let alternates: [ExerciseCandidate]

    /// For `.sheet(item:)` — exactly one proposal is ever shown at a time, scoped to one tip.
    var id: String { tip.id }

    var scoreDelta: Int { after.overall - before.overall }

    /// Non-zero dimension moves, largest magnitude first — including regressions. Reordering can
    /// provably worsen `fatigue` while fixing `selection`/`fatigue`'s order component, so this
    /// must be able to show a negative number, not just describe wins.
    var dimensionDeltas: [(dimension: QualityDimension, delta: Int)] {
        let beforeByDim = Dictionary(uniqueKeysWithValues: before.dimensions.map { ($0.dimension, $0.score) })
        let afterByDim = Dictionary(uniqueKeysWithValues: after.dimensions.map { ($0.dimension, $0.score) })
        return afterByDim.compactMap { dim, afterScore -> (dimension: QualityDimension, delta: Int)? in
            guard let beforeScore = beforeByDim[dim] else { return nil }
            let delta = afterScore - beforeScore
            return delta != 0 ? (dimension: dim, delta: delta) : nil
        }.sorted { abs($0.delta) > abs($1.delta) }
    }
}

struct FixSummary: Equatable {
    let headline: String    // "Adds Barbell Row"
    let detail: String      // "4 × 6-10 · barbell"
    let placement: String?  // "Pull Day — already trains back, and has the least back volume"
    /// Set when `resolvesTip` is false but the fix still helps.
    let caveat: String?     // "Improves coverage but won't fully close the gap"
}
