# Quality Coach: Auto-Fix Suggestions + Honest Per-Day Skips — Design

**Date:** 2026-08-14
**Branch:** `feat/muscle-coverage-coach`
**Status:** Approved (build directly)

## Goal

Two complaints, one root cause — the quality coach tells you what's wrong and then leaves you to
fix it by hand, and one of its controls does nothing visible at all.

1. **Phase 1 — the skip is a lie.** Marking a muscle as skipped on a day changes nothing you can
   see. Fix it so the skip is honored where it logically applies and visible where it was set.
2. **Phase 2 — auto-fix.** Every suggestion the coach can mechanically resolve gets a one-tap fix
   that shows a *preview* of the resulting plan and score, which you confirm or deny. No blind
   mutation, no hunting through the exercise picker.

## Background: what the code actually does today

Established by reading the engine, not inferred. Line references are to
`apps/elos-mobile/Elos/Elos/`.

### The skip bug

`CreateSplitView.dayExcludedMuscles` (`Features/Train/Programs/CreateSplitView.swift:39`) is read in
exactly four places: loading an edited split (`:147`), the chip's own label (`:422`), the
`SkipMusclesSheet` binding (`:222`), and persistence (`:583`). For *scoring*, it reaches only
`daySummaries` (`:288-307`), which computes a full per-day `.singleSession` `QualityReport` and
then throws away everything except `.overall` — that unlabeled integer in the report's *BY DAY*
list is the entire observable effect of the control.

The coverage bars the user was actually looking at (`SplitQualityReportView.coverageCard:101-108`)
render the **weekly** report. `TemplateQualityEngine.score:50` forces day-scoped exclusions empty
unless `scope == .singleSession`, by explicit design. So a per-day skip can never reach the weekly
bars or the weekly score.

The design comment is defensible as far as it goes — skipping lower back on Upper day should not
hide a genuine weekly gap if some other day ought to be training it. What was missing is the case
where **every** day skips it, at which point the week has no remaining day that disagrees.

### The suggestion system

23 distinct tip emission sites across six scorers. Full inventory was taken; the load-bearing
findings for this design:

- **`TipAction` carries no day index for `.addMuscle`/`.addPattern`** (`QualityReport.swift:52-61`).
  Only `.reorder` does. At weekly scope this is not lost information — a `bal-gap-back` tip is
  genuinely about the whole week, no single day generated it. Choosing a day is therefore a
  *policy decision made at fix time*, not something to plumb through the engine. **We do not
  extend `TipAction` with a day index.**
- **Today's day choice is unsound for automation.** `firstOpenDayIndex()`
  (`CreateSplitView.swift:330-333`) returns the non-rest day with the fewest exercises, full stop.
  It ignores day focus (a hamstring fix can land on your arm day), ignores `dayExcludedMuscles`
  (it will target a day where you explicitly skipped that muscle), and ignores where the volume
  actually is. Acceptable when a human then sees the picker open; not acceptable when the app
  picks for you.
- **`sel-order` uses a constant tip id** (`SelectionScorer.swift:49`, loop `break`s at `:53`), so
  only one ever exists, pointing at the first offending day. Fixing day 2 makes day 5's inversion
  emit *the same id*. A naive "is this id gone?" check reports false success. Resolution must be
  matched on **`(id, action)`**.
- **Reordering can lower a dimension.** `FatigueModel.effectiveSets` (`FatigueModel.swift:39-54`)
  walks sets in order accumulating systemic load, so the *order* changes which sets land fatigued
  even though total load is order-independent. Moving compounds first can push `efficiency` across
  the `minVolumeEfficiency` threshold in either direction — `fatigue-long-*` can appear as a side
  effect of fixing `fatigue-order-*`. The preview must be able to show a negative delta.
- **Reordering *is* guaranteed to clear the tip it targets.** `ExerciseOrderer.order` performs a
  full partition (all catalog-matched compounds, then isolations, then unresolved), and both
  `SelectionScorer.isolationBeforeCompound` and `FatigueModel.orderQuality` classify compounds via
  the same catalog lookup. No isolation can precede a compound afterward.
- **`.addMuscle` payloads are polymorphic.** Volume tips pass a `FineMuscle.rawValue`
  (`VolumeScorer.swift:76`); balance gap tips pass a `MuscleGroup.rawValue`
  (`BalanceScorer.swift:81-98`). `MuscleTaxonomy.targetMuscles(forPayload:)` (`:181-191`) resolves
  both via a two-stage fallback. Any consumer that assumes one shape misresolves half of them.

### The ranking machinery already exists

`ExerciseRankingEngine.rank(_:inputs:mode:)`
(`Features/Train/Programs/Intelligence/ExerciseRankingEngine.swift:17`) is a pure value-type
function with no SwiftUI coupling, and `SplitScaffolds.recommend` (`SplitScaffolds.swift:3-30`) is
an existing precedent for calling it headlessly. **No new ranking math is required.**

Two properties of that engine matter and are easy to get wrong:

- Equipment availability is a **−2.0 score penalty, not a filter** (`:68`). A candidate needing a
  machine you don't have can still win.
- Duplicate avoidance is likewise a **−4.0 penalty, not a filter** (`:88-92`). Both builders apply
  their own hard guard at commit time (`CreateSplitView.swift:186`,
  `CreateTemplateView.swift:526`).

A headless picker must therefore hard-filter for both before ranking.

### State and persistence

Neither builder writes to SwiftData until Save (`CreateTemplateView`'s `onSave` at `:509`,
`CreateSplitView.saveSplit()` at `:550`). Everything before that is local `@State`. **"Deny"
therefore needs no rollback of any kind** — it discards a local value, exactly as the existing
discard confirmations do.

## Decisions (locked)

- **Per-tip fixes only.** No bulk "fix everything" in v1.
- **Tier 1 + Tier 2 in scope** (enumerated in §2.7); volume-reduction and structural tips stay
  read-only.
- **Weekly skip rule:** a muscle excluded on **every training day** is excluded for the week
  (§1.1 fixes one definition of "training day" for both phases). Excluded on some days only → unchanged
  behavior. A weekly exclusion always renders as an explicit "Skipped" row rather than
  disappearing (§1.2) — it is allowed to stop the nagging, never to hide information.
- **The engine returns a typed operation list, not a mutated plan.**
- **Alternate picks:** an insert fix offers the #2 and #3 ranked candidates.
- **One spec, two phases.** Phase 1 lands first; Phase 2 depends on its per-day exclusion data.

### Why operations rather than a mutated copy

The two builders hold different state: `CreateTemplateView` has `[TemplateExerciseEntry]`
(`:242`), `CreateSplitView` has `[[DayExercise]]` (`:38`). Returning a mutated plan would force one
of them into a lossy round-trip through a foreign type — and `TemplateExerciseEntry` carries
`targetRPE`/`restSeconds` that `DayExercise` has no field for. The repo already has a documented
recurring bug class from exactly this shape (an integration seam that carries an exercise's *name*
but drops the rest of its identity; it has bitten the swap sheet, the weekly muscle strip and the
PR label). `CreateTemplateView.reorder(priority:)` (`:329-346`) currently round-trips through
`DayExercise` and maps back **by name matching** — the very pattern to avoid extending.

Operations addressed by `(dayIndex, exerciseIndex)` avoid this entirely: each builder applies them
to its own array in its own types, and the mapping is positional and 1:1.

## Architecture

Fully client-side. No SwiftData schema change, no backend or `packages/elos-shared` contract
change, no migration. All new logic is pure value types under
`Features/Train/Programs/Intelligence/`, unit-tested with Swift Testing — the established pattern
for this layer.

The common representation is **`[[ScoredExercise]]`**: it is already what
`TemplateQualityEngine.score` consumes, both builders already produce it (`.scored` at
`CreateTemplateView.swift:6-46`, `ScoredExercise.init(day:)` at `ScoredExercise.swift:37-40`), and
unlike `DayExercise` it carries `restSeconds`, which Tier 2 needs.

---

# Phase 1 — Honest per-day skips

## 1.1 Engine: the weekly intersection rule

`TemplateQualityEngine.score` gains one defaulted parameter:

```swift
static func score(days: [[ScoredExercise]],
                  dayNames: [String],
                  scope: QualityScope,
                  profile: TrainingProfile,
                  catalog: [ExerciseCandidate],
                  intent: TrainingIntent? = nil,
                  dayExclusions: [Set<FineMuscle>] = [],
                  dayIsRest: [Bool] = []) -> QualityReport
```

Both new parameters are defaulted, so every existing call site compiles unchanged.
`dayIsRest` is required, not incidental: the engine cannot derive "is this a training day" from
`days` alone (see below).

```swift
// A muscle the lifter has skipped on *every* day they actually train is skipped for the week —
// there is no remaining day that disagrees. Skipped on only some days, the week still expects it
// on the others, which is what keeps one day's skip from hiding a real gap.
//
// Only training days vote. Including non-training days would fold in their empty exclusion sets
// and intersect the result to nothing, disabling the rule entirely. Note this cuts the other way
// too — see §1.2 for why a wrong weekly exclusion must stay *visible* rather than silent.
//
// A day index with no corresponding entry in `dayExclusions` votes as an empty set (killing the
// intersection) rather than being skipped: a caller that passes a short array must not be able to
// widen the exclusion by omission.
func isTrainingDay(_ i: Int) -> Bool {
    !(i < dayIsRest.count && dayIsRest[i]) && !days[i].isEmpty
}
func exclusions(_ i: Int) -> Set<FineMuscle> {
    i < dayExclusions.count ? dayExclusions[i] : []
}

let weeklyExclusions: Set<FineMuscle> = {
    guard scope == .weeklySplit else { return [] }
    let voting = days.indices.filter(isTrainingDay)
    guard let first = voting.first else { return [] }
    return voting.dropFirst().reduce(exclusions(first)) { $0.intersection(exclusions($1)) }
}()
```

Unioned with the existing global and day-scoped sets at `TemplateQualityEngine.swift:51`. The rest
of the function is untouched — `effectiveOverrides.excludedMuscles` already flows to every scorer
and to `MuscleVolumeAnalyzer`.

**Call site:** `CreateSplitView.qualityReport` (`:250-257`) passes both `dayExclusions:
dayExcludedMuscles` and `dayIsRest: dayIsRest` (the view already holds it at `:37`). No other call
site changes; `CreateTemplateView`'s single-session call (`:274`) takes the defaults and is fenced
out of the whole block by `guard scope == .weeklySplit`.

### One definition of "training day", shared by both phases

Phase 1's intersection and Phase 2's `FixDayChooser` veto must not disagree about which days
count. They would if written independently: `dayIsRest` and `days[i].isEmpty` are **not** the same
predicate. Toggling Rest on (`CreateSplitView.swift:381-386`) clears `dayTemplateIDs` and
`dayNames` but deliberately leaves `dayExercises[i]` intact, so a day marked Rest can still hold
exercises — and those exercises are still scored, because `qualityReport` (`:251`) passes all
seven days unfiltered.

The predicate is `!dayIsRest[i] && !days[i].isEmpty` — mirroring the semantics `saveSplit`'s
`isEffectivelyRest` (`:563-566`) already persists — and is written twice against the same
semantics rather than shared as one literal function: the engine's array is `days`, the view's is
`dayExercises`, and `daySummaries` (`:291`) already inlines exactly this test today. Phase 2's
`FixDayChooser` uses the view-side form. Any change to the rule must change both; the tests in
§1.4 pin the engine side.

## 1.2 A weekly exclusion must be visible, never silent

The intersection rule has a failure mode worth designing against rather than arguing away.
Mid-build, a user with two Push days built and Pull days still to come may skip back on both to
quiet the coach. The intersection then concludes back is skipped for the week and mutes it —
hiding a gap they fully intend to fill. The rule self-corrects the moment a Pull day appears, but
the wrong state is live in between, and *silent* wrongness during the exact minutes someone is
making decisions is the worst kind.

The asymmetry decides the design: failing to mute is merely annoying and visible, while muting
wrongly hides information. So the mute is never allowed to be invisible.

`MuscleVolumeBar` gains `let isExcluded: Bool`, set when a muscle is muted by the lifter's own
choice rather than by science. The distinction is real and computable: an excluded muscle is in
`profile.volumeOverrides.excludedMuscles` (already the merged global ∪ day-scoped ∪ weekly set by
the time `MuscleVolumeAnalyzer` sees it, per `TemplateQualityEngine.swift:50-63`), whereas a
science-optional muscle like rotator cuff carries `isOptional` on its *base* band
(`TrainingScience.swift:144,147`) and is absent from that set. Both `fineRow` and `groupRow`
already receive `profile` (`MuscleVolumeAnalyzer.swift:211,278`), so no new plumbing is needed.

**A group row is excluded when every child is** — `childBars.allSatisfy(\.isExcluded)`, applied
uniformly to all three of `groupRow`'s return paths (the single-child mirror at `:224`, the
no-expected-children branch at `:234`, and the normal path at `:268`); for the single-child case
`childBars` holds exactly that one child, so the same expression is correct there. This must be
stated explicitly because the existing `expectedChildren.isEmpty` branch (`:231`) does **not**
catch it: weekly `expectedMuscles` is computed from the experience-only band overload (`:181-184`),
which builds a fresh profile with empty overrides (`TrainingScience.swift:197-199`) and so cannot
see exclusions at all. Without the explicit group rule, an all-excluded group falls through to the
normal path, `worst` resolves to `.untrained`, and the row renders red with a set count — which is
exactly the "Back — Skipped" example above failing to render. `expectedMuscles` itself is left
alone: `isExcluded` now carries the meaning explicitly, and changing what "expected" means would
ripple into `isExpected` and the group's in-range counts for no gain.

`MuscleCoverageBars` renders an excluded row with an explicit **"Skipped"** value in place of the
set count, reusing the existing `isMuted` styling path (`MuscleCoverageBars.swift:96`) for colour —
which already fires, since an excluded muscle's band is forced `asOptional`
(`TrainingScience.swift:175`).

The row stays on screen and says what happened. A half-built split reads "Back — Skipped", which
is immediately recognisable as wrong and one tap from being undone, instead of a bar that quietly
vanished. This also answers the original complaint more directly than muting ever could: the user
gets confirmation the app heard them, not just an absence of nagging.

`VolumeScorer` and `BalanceScorer` continue to skip excluded muscles for scoring and tips — the
nagging genuinely stops. Only the *rendering* changes.

**One exception to fix while here:** `BalanceScorer`'s `bal-noham` (`:52-57`) is the sole gap tip
that never consults `excludedMuscles` — every sibling gap check does (`:75`, `:93`, `:109`). So
excluding hamstrings today still produces "add a hinge to balance the knee." Gate it the same way
its siblings are gated.

## 1.3 Opening a day's own report

`SplitDaySummary` (`SplitQualityReportView.swift:5-11`) gains `let report: QualityReport`.
`daySummaries` (`CreateSplitView.swift:288-307`) already computes it and discards it — it now
stores it. **Zero additional computation.**

`perDayCard` (`:271-303`) rows become `Button`s (matching the `MuscleCoverageBars.groupRow`
precedent at `MuscleCoverageBars.swift:206`, which chose a real `Button` over `.onTapGesture`
specifically because these rows contain a `GeometryReader`). A new `onSelectDay:
((SplitDaySummary) -> Void)?` is threaded out to `CreateSplitView`, which presents:

**New file — `Features/Train/Programs/DayQualityReportView.swift`.** A single-day report sheet:
score ring + tier, `QualityDimensionBars` for `.singleSession`, `MuscleCoverageBars(report:
report.volume, hidesUnexpected: true)`, and that day's own tips. It composes the same shared
subviews as `SplitQualityReportView` rather than duplicating them. `hidesUnexpected: true` is
correct here and `false` at weekly scope — for one focused day an untargeted group is not a
finding, which is the existing convention documented at `MuscleCoverageBars.swift:168-170`.

This is where a skipped Lower Back renders **muted**, via the `isMuted` path already implemented
at `MuscleCoverageBars.swift:96`.

## 1.4 Test change to declare, not bury

`ElosTests/Intelligence/TemplateQualityEngineTests.swift:124-142`,
`dayScopedExclusionDoesNotAffectWeeklySplitScore`, asserts a per-day skip *never* moves the weekly
score. Its premise changes. It is replaced by two tests:

- `dayScopedExclusionOnSomeDaysDoesNotAffectWeeklySplitScore` — the original assertion, with a
  second active day that does *not* exclude the muscle. Preserves the real safety property.
- `muscleExcludedOnEveryActiveDayIsExcludedWeekly` — the new rule.

---

# Phase 2 — Auto-fix

## 2.1 New types — `Intelligence/QualityFix.swift`

```swift
/// One atomic change to a plan. Declarative on purpose: the two builders hold different state
/// types, so the engine describes *what* to change and each builder applies it in its own terms.
/// Addressed positionally — `exerciseIndex` maps 1:1 onto each builder's own array — which avoids
/// the name-matching identity trap this repo has hit repeatedly.
enum FixOperation: Equatable {
    case insertExercise(InsertSpec)
    /// `permutation[newIndex] = oldIndex`. Positional, **not** id-keyed: a template exercise with
    /// no catalog match becomes `ScoredExercise(id: "")` (`CreateTemplateView.swift:6-46`,
    /// `exerciseID ?? ""`), so two such rows on one day are indistinguishable by id and an
    /// id-keyed reorder cannot reproduce the intended ordering — the same name-as-identity trap
    /// this design exists to avoid.
    case reorderDay(dayIndex: Int, permutation: [Int])
    case setReps(dayIndex: Int, exerciseIndex: Int, reps: String)
    /// Single-session scope only. `DayExercise` has no rest field and `ScoredExercise.init(day:)`
    /// hard-codes `restSeconds: nil`, so the split builder's `apply` implements this as an
    /// intentional no-op — see §2.6.
    case setRest(dayIndex: Int, exerciseIndex: Int, seconds: Int)
}

struct InsertSpec: Equatable {
    let dayIndex: Int
    let insertAt: Int
    let candidate: ExerciseCandidate
    let sets: Int
    let reps: String
}

/// What the preview renders and what Confirm applies.
struct FixProposal: Equatable {
    let tip: QualityTip
    let operations: [FixOperation]
    let summary: FixSummary
    let before: QualityReport
    let after: QualityReport
    /// Whether simulating `operations` actually cleared the targeted tip. Matched on
    /// `(id, action)` — `sel-order` reuses one id across days, so an id-only check lies.
    let resolvesTip: Bool
    /// Ranked #2/#3 candidates for an insert fix. Empty otherwise.
    let alternates: [ExerciseCandidate]

    var scoreDelta: Int { after.overall - before.overall }
    /// Non-zero dimension moves, largest magnitude first — including regressions.
    var dimensionDeltas: [(dimension: QualityDimension, delta: Int)] { … }
}

struct FixSummary: Equatable {
    let headline: String    // "Adds Barbell Row"
    let detail: String      // "4 × 6-10 · barbell"
    let placement: String?  // "Pull Day — already trains back, and has the least back volume"
    /// Set when `resolvesTip` is false but the fix still helps.
    let caveat: String?     // "Improves coverage but won't fully close the gap"
}
```

`FixOperation.apply(to:)` — a pure `[[ScoredExercise]] -> [[ScoredExercise]]` used for simulation,
with bounds validation returning the input unchanged on an out-of-range index.

## 2.2 Day selection — `Intelligence/FixDayChooser.swift`

Replaces `firstOpenDayIndex()` for automated fixes (the manual path keeps its current behavior).

**Hard vetoes.** A day is ineligible if it is a rest day, or if **every** muscle in the fix target
set is in that day's `excludedMuscles`. The second is a correctness requirement, not a preference:
auto-adding a muscle the user explicitly skipped on that day is precisely the bug Phase 1 fixes.

**Ranking**, applied to eligible days:

1. `+3.0` if the day's archetype targets any of the fix muscles. Archetype comes from
   `intent.focus` when set, else `MuscleTaxonomy.archetype(forDayName:)` — the same resolution
   `MuscleVolumeAnalyzer.expectedMuscles` uses (`:186-193`), so the chooser and the scorer agree
   on what a day is for.
2. `−0.5 ×` current direct sets for those muscles on that day. Prefers spreading volume across
   days, which also raises weekly frequency — the thing `FrequencyScorer` rewards.
3. `−0.2 ×` exercise count. Today's whole heuristic, demoted to the tiebreak it should always have
   been.
4. **`dayIndex` ascending as a final, total tiebreak.** Swift's `sorted(by:)` is not stable; this
   repo already has a documented reproducibility bug from that exact cause. Attribution must be
   deterministic.

**Fallback:** if no eligible day scores a focus match, rank all eligible days by criteria 2–4, so
the chooser never dead-ends on an unnamed split.

**No eligible day at all** → returns `nil` → the tip offers no auto-fix and falls back to today's
manual behavior.

At `.singleSession` scope there is one day; the chooser trivially returns index 0 unless vetoed.

Returns the index **and the human-readable reason**, which is what makes the preview's placement
line honest rather than decorative.

## 2.3 Exercise selection — `Intelligence/FixExercisePicker.swift`

```swift
static func candidates(forMuscles targets: Set<String>,   // normalized catalog keys
                       dayIndex: Int, context: Context, limit: Int = 3) -> [ExerciseCandidate]
static func candidates(forPattern pattern: String,
                       dayIndex: Int, context: Context, limit: Int = 3) -> [ExerciseCandidate]
```

Pipeline:

1. **Resolve the payload** through `MuscleTaxonomy.targetMuscles(forPayload:)` — handles the
   `FineMuscle` / `MuscleGroup` polymorphism.
2. **Primary-muscle filter only.** A candidate qualifies only if its *primary* muscle is in the
   target set. This is a correctness constraint: `bal-gap-*` and `bal-focusgap-*` fire on
   **direct** sets being zero, so a secondary-only pick would not clear the tip it claims to fix.
   For `forPattern`, filter on `movementPattern` equality instead.
   **Both sides of that membership test must be normalized** — compare
   `MuscleTaxonomy.normalize(candidate.primaryMuscle)` against the normalized target set. The
   catalog stores snake_case (`"lower_back"`) while the target vocabulary is normalized
   (`"lower back"`); comparing raw against normalized silently drops every candidate for that
   muscle. This repo has shipped that exact bug twice.
3. **Hard duplicate filter** — drop anything whose id, or normalized name, is already on that day.
   The engine's own −4.0 penalty is not a guarantee.
4. **Hard equipment filter**, with a fallback: filter by `EquipmentPreference.isAvailable`; if
   that empties the pool, use the unfiltered pool rather than dead-ending, and set a caveat.
5. **Rank** via `ExerciseRankingEngine.rank` with a `DayContext` built from the target day —
   including a correctly populated `addedPrimaryMuscles`, which
   `CreateTemplateView.openPicker` (`:314-324`) currently leaves empty, silently disabling the
   engine's own coverage-gap and duplicate terms.
6. Take `limit`; `[0]` is the pick, the rest are alternates.

**Set sizing.** Presence-test tips (`bal-*`, `sel-hinge`) take
`SetRepDefaults.defaults(forMovementPattern:)` unchanged. Dose tips (`vol-low-*`, `vol-light-*`)
size from the actual shortfall: **`ceil(target − credit.total)`**, capped at a new
`TrainingScience.maxAutoFixSetsPerExercise` (5), where target is `band.mev` for `vol-low` and
`band.targetLow` for `vol-light`. House rule: every tunable number lives in
`TrainingScience.swift`.

The shortfall is measured against **`credit.total`, not `credit.direct`** — `VolumeScorer.weekly`
(`:69`) computes status from `credit.total`, so a muscle already earning indirect credit needs
fewer new sets than its direct count suggests. A chest at `direct 5 / indirect 2` (total 7) against
`mev 8` needs **1** set; the direct-based formula would ask for 3.

One added set closes exactly one set of the shortfall: credit accumulates as a straight sum across
exercises (`MuscleVolumeAnalyzer.swift:123-124`), and the "largest credit, not the sum" rule
(`:163-165`) is intra-exercise only, so N sets of an exercise whose primary is M raise M's total by
exactly N.

Note the tip only exists for muscles with `direct > 0` — `VolumeScorer` skips untargeted muscles
entirely (`:17-18`), which is `BalanceScorer`'s job instead. So the shortfall path never sees a
zero-direct muscle.

If one exercise cannot close the gap, the proposal is still offered with `resolvesTip: false` and
an honest caveat. It is not silently inflated to 14 sets.

## 2.4 Orchestration — `Intelligence/QualityFixEngine.swift`

```swift
struct Context {
    let days: [[ScoredExercise]]
    let dayNames: [String]
    let dayIsRest: [Bool]
    let dayExcludedMuscles: [Set<FineMuscle>]
    let scope: QualityScope
    let profile: TrainingProfile
    let intent: TrainingIntent
    let catalog: [ExerciseCandidate]
    let personalization: PersonalizationProvider
    let equipmentPreference: EquipmentPreference
}

static func canFix(_ tip: QualityTip) -> Bool                        // cheap, for UI affordance
static func propose(for tip: QualityTip, context: Context) -> FixProposal?
static func propose(for tip: QualityTip, context: Context,
                    using alternate: ExerciseCandidate) -> FixProposal?
```

**Deriving the reorder permutation.** `ExerciseOrderer.order` returns reordered *values*, and
`DayExercise` is not `Equatable` (`SplitHelpers.swift:3` declares only `Codable, Identifiable`), so
the permutation must not be recovered by diffing outputs. `ExerciseOrderer` already computes the
answer internally — it sorts `enumerated()` and maps back to `$0.element` (`:19,34-41`). Add a
sibling `orderedIndices(_:catalog:priority:) -> [Int]` and express `order` in terms of it, so the
permutation comes straight from the sort with no equality, no name matching, and no second
implementation to drift.

Note this is slightly more than surfacing an existing value: on the `priority != nil` path
(`:29-41`) the `enumerated().offset` values are local to the `priorityGroup` and `rest`
sub-arrays, so `orderedIndices` must thread the *original* indices through the partition. The
tip-driven fix path always calls it with `priority: nil`, but the function must be correct for
both, since `order` will be composed from it. A characterization test over the existing
`ExerciseOrdererTests` fixtures pins that `order` still returns exactly what it returns today.

`propose` builds operations per tip action, simulates them, re-scores with the **same** parameters
the builder uses, and verifies:

```swift
let after = TemplateQualityEngine.score(days: simulated, …,
                                        dayExclusions: context.dayExcludedMuscles,
                                        dayIsRest: context.dayIsRest)
let resolvesTip = !after.tips.contains { $0.id == tip.id && $0.action == tip.action }
```

**`dayIsRest` must be passed here.** Omitting it lets it default to `[]`, which degrades
`isTrainingDay` to `!days[i].isEmpty` — so a Rest-toggled day still holding exercises would vote in
the *after* intersection but not in the builder's *before* report. The two reports would then be
computed under different weekly exclusion sets, making the delta meaningless and `resolvesTip`
unreliable. The before/after pair must always be scored with identical parameters.

**Suppression rule.** Return `nil` when `!resolvesTip && scoreDelta <= 0` — a change that neither
clears the tip nor improves the score is noise, and offering it is what "sloppy" looks like. A fix
that clears the tip but costs a point or two elsewhere *is* offered, with the regression visible.

## 2.5 Tier 2 — rep and rest retuning

`TipAction` gains two cases:

```swift
case retuneReps    // rewrite out-of-range rep targets to the goal's range
case retuneRest    // rewrite out-of-range rest targets (single session only)
```

`RepRestScorer` attaches them to `rr-reps` (`:30-33`) and `rr-rest` (`:53-56`). The fix rewrites
every out-of-range exercise in scope to `TrainingScience.repRange(for: profile.goal)` /
`restRange(for:)`, leaving in-range exercises alone.

Adding enum cases makes both builders' `handle(tip:)` switches non-exhaustive — a compile error,
not a silent miss. That is the intended safety property.

## 2.6 UI

**New file — `Features/Train/Programs/QualityFixPreviewSheet.swift`.** Presented via `.sheet(item:)`
carrying the proposal — the established pattern for a sheet scoped to one row
(`$muscleEdit`, `$skipMusclesDay`, `$activePicker` in `CreateSplitView`). Contents, top to bottom:
the tip text; before → after score; the non-zero dimension deltas including regressions in red;
the change itself with its placement reason; "Use a different exercise" cycling the alternates and
re-proposing live; "Choose manually instead" falling back to today's picker flow; and
Deny / Confirm. `.presentationDetents([.medium, .large])` — the Plate Calculator precedent for a
compact sheet that shouldn't over-allocate height.

**`TipRow`** (`SplitQualityReportView.swift:315-347`, shared by the inline panel and the full
report) gets one new optional `onAutoFix`. Behavior, in order: if the tip is auto-fixable, tap
opens the preview; else if the action is actionable, tap does exactly what it does today; else the
row is inert. **One tap target per row** — the manual escape hatch lives inside the preview, not
as a competing second button in a small row.

**Both builders** gain an `apply(_ operations: [FixOperation])` that switches over the operations
and mutates its own native state, wrapped in `withAnimation(.elosEmphasis)` to match the existing
reorder. Indices and permutations are re-validated at apply time; an out-of-range or non-bijective
operation aborts with no change.

`CreateSplitView.apply` implements `setRest` as an **intentional no-op** with a comment saying so —
`DayExercise` has no rest field, `rr-rest` only fires at single-session scope on exercises with
non-nil rest, and a split-sourced day always has `restSeconds: nil`, so the case is unreachable
there. The switch must still cover it, and an implementer should not read that gap as a prompt to
invent rest storage on `DayExercise`.

`CreateTemplateView` needs a one-line `equipmentPreference` computed property to build the
`Context`; it already has the `@Query profiles` (`:240`) that `CreateSplitView:11` derives it from,
but doesn't currently expose it.

## 2.7 The fixable set — `canFix`'s whitelist

`QualityFixEngine.canFix` is load-bearing: it decides which tips get a button. It is a whitelist on
tip id prefix, not on `action.isActionable`, so a tip can carry an action for the manual path
without claiming to be auto-fixable.

| Tip id | Tier | Operation |
|---|---|---|
| `bal-gap-*`, `bal-focusgap-*`, `bal-noham` | 1 | `insertExercise` — one primary-target exercise |
| `vol-low-*`, `vol-light-*` | 1 | `insertExercise` — sets sized from the shortfall (§2.3) |
| `sel-hinge` | 1 | `insertExercise` — one hinge-pattern exercise |
| `sel-order`, `fatigue-order-*` | 1 | `reorderDay` |
| `rr-reps` | 2 | `setReps` on every out-of-range exercise in scope |
| `rr-rest` | 2 | `setRest` — single-session scope only |

Everything else — `vol-high-*`, `vol-more`, `sess-junk-*`, `sess-short`, `sess-long`,
`bal-pushpull`, `bal-quadham`, `bal-single-group`, `sel-compound`, `fatigue-long-*`, `freq-once-*` —
is deliberately **not** fixable and keeps today's behavior. See Out of scope for why.

`canFix` returning true is necessary but not sufficient: `propose` can still return `nil` (no
eligible day, no candidate, or a change that neither clears the tip nor helps), in which case the
UI falls back to the manual path.

### One adjacent bug fixed deliberately

`CreateTemplateView`'s manual add path (`:525-536`) never calls `SetRepDefaults`, so a squat added
in the template builder gets a generic `3 × 8-10` while the same squat added in the split builder
gets `4 × 5-8` (`CreateSplitView.swift:187-188`). Auto-fix inserts carry their own sets/reps from
`InsertSpec` (§2.3), so auto-fix is self-consistent either way — this is an independent drive-by
fix, corrected because leaving the two builders disagreeing while working directly on the seam
between them is how the disagreement survives another year.

**It changes existing manual-add behavior**, which no one asked for. It therefore lands as its own
commit, so the auto-fix change stays behavior-preserving for the manual path and this can be
reverted alone if it surprises anyone.

## Error handling and edge cases

| Case | Behavior |
|---|---|
| No eligible day (all rest, or all veto the muscle) | No auto-fix offered; falls back to manual tap |
| Equipment filter empties the candidate pool | Relax to unfiltered pool, surface a caveat |
| No candidate at all trains that muscle | No auto-fix offered; falls back to manual |
| One exercise can't close a dose gap | Offered with `resolvesTip: false` + honest caveat |
| Fix clears the tip but lowers overall | Offered; delta shown in red; user's call |
| Fix neither clears the tip nor helps | Suppressed entirely (`propose` returns `nil`) |
| Plan changed while the sheet is open | Indices re-validated on Confirm; abort with no change |
| `sel-order` regenerating on another day | Counts as resolved — `(id, action)` differs |
| Sort ties in day/candidate selection | Total tiebreak on index; Swift's sort is not stable |
| Two unmatched exercises on one day (both `id == ""`) | Reorder is positional, so they stay distinguishable |
| Added sets push a *secondary* muscle past its MRV | Surfaces as a new `vol-high-*` tip and a red dimension delta in the preview; cannot corrupt `resolvesTip`, which matches only the targeted tip |
| Weekly skip concluded from a half-built split | Row renders "Skipped" rather than vanishing (§1.2) |
| Muscle excluded on a day that also holds leftover exercises after a Rest toggle | Shared `isTrainingDay` predicate governs both phases (§1.1) |

## Testing

Swift Testing, alongside the existing scorer suites, reusing `QualityFixtures`' 19-exercise catalog
and `sx(_:sets:)`/`resolve(_:)`/`volume(_:scope:)` helpers.

**`FixDayChooserTests`** — vetoes rest days; vetoes a day excluding every target muscle; prefers a
focus-matching day over an emptier non-matching one (the hamstring-lands-on-arm-day regression);
prefers the lower-volume day among focus matches; returns `nil` when nothing is eligible;
deterministic under ties.

**`FixExercisePickerTests`** — returns only primary-muscle matches; excludes by id *and* by
normalized name; respects equipment preference; falls back rather than returning empty when the
filter over-constrains; pattern filter for `.addPattern`; alternates are distinct from the pick.

**`QualityFixEngineTests`** — the load-bearing property: **for every fixture tip the engine claims
to fix, applying the proposal genuinely clears that `(id, action)` in the after-report.** Plus:
`sel-order` on a second day still counts as resolved; a reorder proposal touches only its own day;
a dose fix that can't close the gap reports `resolvesTip: false`; `propose` returns `nil` for the
no-help case; Tier 2 retune moves `rr-reps` out of the tip list.

**`TemplateQualityEngineTests`** — the two replacement tests from §1.4, plus: a day toggled to Rest
while still holding exercises does not vote in the intersection; a `dayExclusions` array shorter
than `days` cannot widen the weekly exclusion.

**Coverage-bar rendering** — a muscle excluded by the lifter reports `isExcluded` and renders
"Skipped"; a science-optional muscle (rotator cuff) does not, so the two mute reasons stay
distinguishable. **A group whose every child is excluded reports `isExcluded` at group level** —
the case that would otherwise render red with a set count, and the one §1.2's own worked example
depends on.

**`ExerciseOrderer.orderedIndices`** — returns a valid permutation of the input indices, and
`order` composed from it produces the identical array it produces today (a characterization test
over the existing `ExerciseOrdererTests` fixtures).

### Verification reality

Re-verified live on 2026-08-14, not assumed:

- `xcodebuild build-for-testing -project Elos.xcodeproj -scheme Elos -destination
  'platform=iOS Simulator,name=iPhone 17' OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'`
  **succeeds** (confirmed a real rebuild, not a cache hit, by checking the `.xctest` bundle mtime).
- `xcodebuild test` **fails** in this environment: `Pseudo Terminal Setup Error … Operation not
  permitted`. This is current, not stale.

So: compilation is gated by `build-for-testing`; **actual execution of the new pure-logic tests
goes through the `swiftc` harness** — copy `Intelligence/*.swift` + `Programs/SplitHelpers.swift`
into a temp dir with a shim for the two SwiftData types the `init(record:)` adapters touch
(`UserProfileRecord`, `ExerciseDefinitionRecord`), then `swiftc -o harness *.swift && ./harness`.
The Swift Testing files are still written and committed — they run in CI/on a real machine.

## Out of scope

- **Bulk "fix everything."** Natural v2 once per-tip is proven; the operation list composes.
- **Volume-reduction fixes** (`vol-high-*`, `sess-junk-*`, `sess-long`) — deciding what to *remove*
  from someone's workout is a judgement call, not a mechanical one.
- **Structural tips** (`bal-pushpull`, `sel-compound`, `fatigue-long-*`, `freq-once-*`,
  `bal-single-group`, `vol-more`) — the honest fix is "restructure your week." They stay read-only
  rather than getting a button that pretends.
- **Undo after Confirm.** Both builders already have discard-on-cancel and don't persist until
  Save; a second undo layer is redundant.
- **Any backend, contract, or schema change.**

## Risks

- **`TemplateQualityEngine.score` signature change.** Mitigated by defaulting `dayExclusions`;
  every existing call site compiles untouched.
- **`TipAction` gaining cases** breaks exhaustive switches — by design, caught at compile time.
- **The weekly-skip rule changes a green test's premise.** Declared in §1.4 rather than quietly
  edited.
- **Fix quality is only as good as `movementPattern` data.** Verified 404/404 seeded exercises
  carry a pattern; server-synced and user-custom exercises may not, and
  `MovementQualityAnalyzer.analyze` already guards for empty. The picker's pattern filter will
  simply not select them, which degrades to "no auto-fix offered" rather than a wrong fix.
- **The muscle vocabulary can produce false negatives.** `MuscleTaxonomy.knownMuscleVocabulary`
  (`:113-121`) does not list every string `fine(forMuscle:)` can resolve — `"upper_back"` resolves
  to `.upperBack` but is absent from the vocabulary. A catalog entry with such a primary muscle is
  filtered out of the candidate pool despite legitimately crediting that muscle. The failure is
  "no fix offered," never a wrong fix, so it degrades to the manual path. Worth an audit pass over
  the vocabulary against the real catalog's distinct `primaryMuscle` values, but not a blocker.
- **The weekly skip rule can be wrong mid-build**, as analysed in §1.2. Mitigated by rendering
  rather than hiding, and self-correcting as days are added. Accepted deliberately: the opposite
  failure — refusing to honour a skip — is the complaint that started this work.
