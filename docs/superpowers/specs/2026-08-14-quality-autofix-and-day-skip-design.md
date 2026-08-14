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
- **Tier 1 + Tier 2 in scope** (see table below); volume-reduction and structural tips stay
  read-only.
- **Weekly skip rule:** a muscle excluded on **every active (non-empty) day** is excluded for the
  week. Excluded on some days only → unchanged behavior.
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
                  dayExclusions: [Set<FineMuscle>] = []) -> QualityReport
```

Defaulted so every existing call site compiles unchanged.

```swift
// A muscle the lifter has skipped on *every* day they actually train is skipped for the week —
// there is no remaining day that disagrees. Skipped on only some days, the week still expects it
// on the others, which is what keeps a single day's skip from hiding a real gap.
//
// Only non-empty days vote. A rest day carries no exclusions, and an unbuilt day has no opinion
// yet; letting either into the intersection would zero it out permanently.
let weeklyExclusions: Set<FineMuscle> = {
    guard scope == .weeklySplit, !dayExclusions.isEmpty else { return [] }
    let active = days.indices.filter { !days[$0].isEmpty && $0 < dayExclusions.count }
    guard let first = active.first else { return [] }
    return active.dropFirst().reduce(dayExclusions[first]) { $0.intersection(dayExclusions[$1]) }
}()
```

Unioned with the existing global and day-scoped sets at `TemplateQualityEngine.swift:51`. The rest
of the function is untouched — `effectiveOverrides.excludedMuscles` already flows to every scorer
and to `MuscleVolumeAnalyzer`, so the coverage bars mute correctly with no further change.

**Call site:** `CreateSplitView.qualityReport` (`:250-257`) passes `dayExclusions:
dayExcludedMuscles`. No other call site changes.

## 1.2 Making the skip visible where it was set

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

## 1.3 Test change to declare, not bury

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
    case reorderDay(dayIndex: Int, orderedIDs: [String])
    case setReps(dayIndex: Int, exerciseIndex: Int, reps: String)
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
size from the actual shortfall — `ceil(target − current direct credit)`, where target is
`band.mev` for `vol-low` and `band.targetLow` for `vol-light` — clamped to
`max(default.sets, …)` and capped at a new `TrainingScience.maxAutoFixSetsPerExercise` (5). House
rule: every tunable number lives in `TrainingScience.swift`.

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

`propose` builds operations per tip action, simulates them, re-scores with the **same** parameters
the builder uses, and verifies:

```swift
let after = TemplateQualityEngine.score(days: simulated, …, dayExclusions: context.dayExcludedMuscles)
let resolvesTip = !after.tips.contains { $0.id == tip.id && $0.action == tip.action }
```

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
reorder. Indices are re-validated at apply time; an out-of-range operation aborts with no change.

### One adjacent bug fixed deliberately

`CreateTemplateView`'s manual add path (`:525-536`) never calls `SetRepDefaults`, so a squat added
in the template builder gets a generic `3 × 8-10` while the same squat added in the split builder
gets `4 × 5-8` (`CreateSplitView.swift:187-188`). Auto-fix must produce identical results in both
builders, so this is corrected as part of the work rather than worked around. **Called out
explicitly because it changes existing manual-add behavior**, which no one asked for and everyone
should know about.

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

**`TemplateQualityEngineTests`** — the two replacement tests from §1.3.

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
- **The weekly-skip rule changes a green test's premise.** Declared in §1.3 rather than quietly
  edited.
- **Fix quality is only as good as `movementPattern` data.** Verified 404/404 seeded exercises
  carry a pattern; server-synced and user-custom exercises may not, and
  `MovementQualityAnalyzer.analyze` already guards for empty. The picker's pattern filter will
  simply not select them, which degrades to "no auto-fix offered" rather than a wrong fix.
