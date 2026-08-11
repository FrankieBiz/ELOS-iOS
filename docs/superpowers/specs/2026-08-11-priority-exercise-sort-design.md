# Priority-Aware Exercise Sort — Design

**Date:** 2026-08-11
**Status:** Approved (design); pending implementation plan
**Scope tier:** B — Extend an existing engine + two UI entry points
**Default audience posture:** Both, no gating (existing sort affordances already unguarded)

## 1. Problem

The quality report (`TemplateQualityPanel`, `SplitQualityReportView`) sometimes flags a day's exercise
order as poor — a "fatigue-order" tip from `FatigueScorer.swift` ("X comes before Y, which pre-fatigues
the muscle the compound needs most"). The only fix today is `ExerciseOrderer.order(_:catalog:)`
(`Elos/Features/Train/Programs/Intelligence/ExerciseOrderer.swift`), a single fixed rule: compounds
before isolation, otherwise stable. It has no concept of "I want to prioritize training my arms today" —
a lifter who deliberately wants a muscle trained first, while freshest (a standard hypertrophy practice
for a lagging or emphasized muscle group), has no way to express that, and the app can't help order
their day around it.

Separately, the scoring math has a latent inconsistency worth fixing regardless of this feature:
`FatigueModel.orderQuality` (`Elos/Features/Train/Programs/Intelligence/FatigueModel.swift:83-110`) counts
*every* isolation-before-compound pair as an inversion when computing the numeric `quality` score, but
the tip text generated from that report (`FatigueScorer.swift:50-55`) only surfaces for inversions where
`sharesPrimaryMuscle == true`. The score and its own explanation already disagree about what "bad order"
means.

## 2. Goals

1. Let the user pick a training priority — one of the seven `MuscleGroup` cases (chest, back, shoulders,
   arms, legs, glutes, core) or "Overall Best Growth" (today's default behavior) — and re-sort a day's
   exercises so the priority muscle's work leads.
2. Available primarily per-workout in the template builder (`CreateTemplateView`), where a specific
   day's exercises are authored.
3. Also available as a bulk action in the split builder (`CreateSplitView`): one priority choice applied
   to every non-rest day in the split at once, as a separate action from the existing per-day Sort
   button (which is left unchanged).
4. Using the feature as intended must not lower the day's own quality score, for the normal case where
   every exercise resolves to a single primary muscle group (true for every catalog-derived exercise
   today; see §6 for the narrow multi-primary exception). Fix the scoring inconsistency (§1) so the
   order-quality check only penalizes same-muscle inversions — which makes it inherently compatible with
   prioritized ordering without storing or looking up any new state.

## 3. Non-goals

- No persisted "this template/day has priority X" field. The priority is a one-time sort action (like
  today's Sort button), not a saved setting — nothing new on `WorkoutTemplateRecord` or
  `UserSplitDayRecord`.
- No change to `ExerciseOrderer`'s existing no-priority behavior — "Overall Best Growth" is exactly
  today's compound-before-isolation, stable-otherwise sort.
- No change to the per-day "Sort" button already in `CreateSplitView` — the new bulk action is additive,
  not a replacement.
- No change to how the "poor order" tip's fix action behaves — it keeps calling the sort with no
  priority (nil), since it has no context on which muscle the user cares about.
- No new hypertrophy-order heuristics beyond compound-before-isolation for the no-priority case (e.g. no
  "order compounds by muscle size" or similar) — out of scope, not requested.

## 4. Architecture

### 4.1 `ExerciseOrderer` (extended)

```swift
enum ExerciseOrderer {
    static func order(_ exercises: [DayExercise], catalog: [ExerciseCandidate],
                       priority: MuscleGroup? = nil) -> [DayExercise]
}
```

Backward compatible: existing call sites (`CreateSplitView`'s per-day Sort button, the template
builder's `reorderCompoundsFirst()` used by the "poor order" tip's fix action — see §4.4, this is *not*
a standalone button) omit `priority` and get identical behavior to today.

When `priority` is non-nil:
1. Convert `[DayExercise]` to `[ScoredExercise]` via the existing `ScoredExercise(day:)` adapter
   (`ScoredExercise.swift:37`), wrap as a single-day `[[ScoredExercise]]`, and resolve via
   `ExerciseResolver.resolve(_:catalog:)` (`ScoredExercise.swift:92`, which takes nested arrays — one day
   in, one day of `[ResolvedExercise]` out) — needed only to read `.muscleGroup`
   (`targets.primary.first?.group`, `ScoredExercise.swift:79`) for the partitioning in step 2.
   `ResolvedExercise.isCompound` (line 84) is not used by the orderer at all; compound-ness for the
   within-partition sort in step 3 comes from `rank(_:)` below, not from this resolution. This is the
   same resolution path `FatigueModel`/`TemplateQualityEngine` already use to answer "what muscle does
   this train" — reuse it rather than re-deriving muscle group a third way.
2. Partition into `priorityGroup` (resolved `muscleGroup == priority`) and `rest` (everything else),
   preserving each exercise's original relative position within its partition.
3. Sort each partition independently using the existing compound-before-isolation rule (extract the
   current `rank(_:)` closure from `order` into a shared private helper so both partitions and the
   no-priority path use identical logic — no duplicated sort rule). Note: within the orderer, `rank(_:)`
   (a catalog-only id/name lookup on the raw `DayExercise`, `ExerciseOrderer.swift:7-11`) is the *only*
   compound-ness check — it decides sort order within a partition, `muscleGroup` (step 1) decides
   partition membership, and the two are orthogonal reads answering different questions. Separately,
   `FatigueModel`'s own `ResolvedExercise.isCompound` (line 84) is a *different* compound-ness check used
   by the scorer, with a different unresolvable-exercise fallback (`false`, vs. `rank(_:)`'s deliberate
   "sort last" value of `2`) — intentionally not unified with `rank(_:)`, and not used anywhere in this
   feature.
4. Concatenate `priorityGroup + rest`.

If no exercise in the day matches the chosen priority, `priorityGroup` is empty and the result is
identical to the no-priority sort — no special-casing needed, falls out of the algorithm naturally.

Only primary-target matches qualify for the priority partition (not secondary). This matches how the
rest of the Intelligence layer already treats primary vs. secondary targets as different-strength
signals, and keeps the rule simple: one exercise is unambiguously "for" at most one priority group.

### 4.2 `FatigueModel.orderQuality` (scoring fix)

Current (`FatigueModel.swift:83-110`): every isolation-index-before-compound-index pair appends an
`OrderInversion`, and `quality = 1 - inversions.count / totalPairs` counts all of them, regardless of
`sharesPrimaryMuscle`.

Change: only inversions where `sharesPrimaryMuscle == true` count toward `quality`. Inversions that
don't share a primary muscle are no longer computed at all — the pair-count denominator changes from "all
compound×isolation pairs" to "compound×isolation pairs that share a primary muscle" (ordered or not).
Explicitly: `quality = 1 − (same-muscle pairs that are inverted) / (same-muscle compound×isolation pairs)`,
guarding the zero-denominator case (no same-muscle pairs at all) to `1.0`, same as today's guard for "all
one type, or fewer than two exercises." This is the same criterion the tip text already applies to
decide *what to say*; the fix makes the *number* agree with it.

`OrderReport.inversions` keeps only same-muscle inversions (the ones ever worth surfacing) — the
`sharesPrimaryMuscle` field on `OrderInversion` becomes redundant with this filtering and can be dropped,
simplifying `FatigueScorer.swift:50` (`f.order.inversions.first(where: ...)` → `f.order.inversions.first`).
The same-muscle-first `.sorted` on the inversions list (`FatigueModel.swift:108`, ranking
`sharesPrimaryMuscle` inversions ahead of others) also becomes a no-op once every remaining inversion is
already same-muscle — remove it alongside the field rather than leaving dead sort logic behind.

Net effect: a day sorted with an active priority (arm isolation before an unrelated leg compound) scores
identically to one sorted with no priority, on this dimension — because the two exercises don't share a
muscle, the pairing was never counted as an inversion in the first place, priority feature or not.

### 4.3 UI — `MuscleGroup` picker (shared)

A small SwiftUI `Menu` (matches existing patterns like `TemplatePickerSheet`'s selection UI) listing:
"Overall Best Growth", then `MuscleGroup.allCases` by `displayName`. Selecting an option returns the
chosen `MuscleGroup?` (nil for "Overall Best Growth") via a completion closure — a plain reusable view,
not tied to either builder, so both call sites share one implementation instead of two menus.

### 4.4 `CreateTemplateView` (primary entry point)

Correction from an earlier draft of this spec: `CreateTemplateView` has **no existing standalone sort
button** to convert. `reorderCompoundsFirst()` (`CreateTemplateView.swift:327-344`) exists, but its
*only* caller is the `.reorder` tip action (line 308) — the exact call site §3/§4.6 say must stay
unchanged. So this is a **new** control, added to the view, not a repurposed one.

Placement: a small header row directly above the exercise-cards `ForEach`
(`CreateTemplateView.swift:416-426`, right after the Quality Coach section and before the exercise
list), styled like other section-label-plus-trailing-control rows elsewhere in the app (e.g. `PlanView`'s
"This Week" header): a label ("Sort") and the priority menu from §4.3 as the trailing control. Shown only
when `exercises.count > 1` (nothing to usefully sort with 0 or 1 exercise — same guard the underlying
`ExerciseOrderer` logic already no-ops on).

Selecting a menu option builds `asDays` the same way `reorderCompoundsFirst()` already does (lines
328-331), calls `ExerciseOrderer.order(asDays, catalog:, priority:)` with the chosen value, and re-maps
back into `[TemplateExerciseEntry]` using the same "match ordered names back to real entries, unmatched
at the end" logic already in `reorderCompoundsFirst()` (lines 333-343). Rather than duplicating that
re-mapping, extract it into a shared private helper parameterized by `priority`, and have both the new
menu's action and the now-unchanged `reorderCompoundsFirst()` (still called by the `.reorder` tip, with
no priority) call it.

### 4.5 `CreateSplitView` (bulk action)

A new button, separate from the existing per-day "Sort" button
(`CreateSplitView.swift` — the `withAnimation { dayExercises[i] = ExerciseOrderer.order(...) }` call
inside `dayRow`, line 333+), labeled "Auto-order all days."

Placement: as a trailing control in the "Weekly Schedule" section's header (`CreateSplitView.swift:99`,
`Section("Weekly Schedule") { ForEach(0..<7) { dayRow(index: $0) } }`) — replace the plain string header
with a custom `header:` view (`HStack { Text("Weekly Schedule"); Spacer(); <menu> }`), the same
section that contains every day this action touches.

Opens the same priority menu from §4.3; on selection, applies `ExerciseOrderer.order(dayExercises[i],
catalog:, priority:)` to every `i` where `!dayIsRest[i] && !dayExercises[i].isEmpty`, in one pass, wrapped
in one `withAnimation`.

### 4.6 "Poor order" tip (unchanged behavior, confirmed)

`CreateSplitView.swift:289-294`'s `.reorder(dayIndex:)` handler keeps calling
`ExerciseOrderer.order(dayExercises[dayIndex], catalog:)` with no `priority` argument — the new parameter
defaults to `nil`, so this call site needs no code change at all.

## 5. Data flow

1. User taps the priority-sort control (template builder) or "Auto-order all days" (split builder).
2. Menu presents "Overall Best Growth" + 7 muscle groups.
3. Selection calls `ExerciseOrderer.order(...)` with the chosen `MuscleGroup?` for the relevant day(s).
4. The view's `dayExercises`/template exercise array is replaced with the sorted result, same assignment
   pattern the existing Sort button already uses (`withAnimation { ... }`).
5. `TemplateQualityEngine`/`SplitQualityReportView` re-score on next read (they already recompute from
   the current exercise array, no caching to invalidate) — reflecting the §4.2 scoring fix automatically.

No new persisted state, no new SwiftData fields, no new network calls.

## 6. Error handling & edge cases

- Priority chosen with zero matching exercises in the day → behaves identically to "Overall Best
  Growth" (empty priority partition, see §4.1).
- Day with fewer than 2 exercises → sort is a no-op either way (nothing to reorder).
- Exercise with no resolvable catalog/machine/muscle data (`ResolvedExercise.hasKnownTargets == false`)
  → falls into `rest`, never crashes; same graceful-unknown handling the rest of the Intelligence layer
  already relies on.
- **Multi-primary-muscle exception to Goal 4.** `MuscleTargets.primary` is `[FineMuscle]` and *can* span
  more than one `MuscleGroup` for an exercise the lifter hand-corrected via the muscle check-off sheet
  (`togglingPrimary` places no group constraint on the list). Partitioning in §4.1 uses only
  `targets.primary.first?.group`, while `FatigueModel`'s inversion check compares the *full* primary sets
  for overlap. A hand-edited exercise with primaries spanning two groups (e.g. `[chest, triceps]`,
  `.first.group == chest`) could end up in `rest` while sharing a muscle with something in
  `priorityGroup` — producing a same-muscle inversion that a pure single-primary case would never create,
  narrowly contradicting Goal 4's "does not lower the score" claim. This requires a user-hand-corrected,
  cross-group multi-primary exercise, which is uncommon (catalog/equipment/lexicon-derived targets are
  always single-primary). Accepted as a known, narrow gap — not fixed by this design (fixing it would
  mean partitioning by "any primary group matches," which raises its own tie-breaking question for
  exercises matching multiple different priorities and isn't worth the added complexity for this edge
  case).
- Split-level bulk action on a split with zero non-rest days with exercises → no-op, button still safe
  to tap (iterates an empty set).
- `FatigueModel.orderQuality` scoring change must not regress `FatigueModel`/`FatigueScorer`/
  `MuscleCoverageTests` existing test expectations for days with *no* priority involved — same-muscle
  inversions are unaffected by the fix; only cross-muscle inversions (previously counted, now not) change
  behavior, and no existing test should have been asserting on that specific case (verify during
  implementation).

## 7. Testing

Pure-engine unit tests, per project convention (`ElosTests/Intelligence/`):

- `ExerciseOrderer` (extend existing test file or add one):
  - No priority: unchanged from current behavior (regression-guard the existing tests still pass).
  - Priority with matches: priority-group exercises precede all others; compound-before-isolation holds
    *within* the priority group and *within* the rest group independently.
  - Priority with zero matches in the day: output identical to no-priority sort.
  - Priority group internal order and rest group internal order are each stable (ties preserve original
    relative order), matching today's stability guarantee.
- `FatigueModel.orderQualityTests` (extend `FatigueModel` test coverage):
  - Same-muscle isolation-before-compound: still counted as an inversion, still lowers `quality` (no
    regression).
  - Cross-muscle isolation-before-compound: no longer counted; `quality` for a day whose only inversions
    are cross-muscle is now `1.0`.
  - Mixed day (some same-muscle, some cross-muscle inversions): `quality` reflects only the same-muscle
    ones.
- Existing `MuscleCoverageTests`/`FatigueModelTests`/`VolumeTargetTests` suites re-run as a regression
  check on the scoring change (§6).

Views get no new logic beyond wiring a menu selection to an existing call — no view-level tests needed
beyond a smoke check that the buttons exist, consistent with how the current Sort button is (not)
tested.

## 8. Phasing

Single phase — this is additive to one existing pure engine and one existing scoring function, with two
UI wiring points. No reason to split further:

1. Extend `ExerciseOrderer` with the `priority` parameter (§4.1) + tests.
2. Fix `FatigueModel.orderQuality` (§4.2) + tests; update `FatigueScorer.swift:50` for the simplified
   `OrderInversion`.
3. Build the shared priority menu (§4.3).
4. Wire `CreateTemplateView` (§4.4).
5. Wire `CreateSplitView`'s new bulk action (§4.5).
6. Full build + `build-for-testing` + run the test suite; manual smoke check of both entry points.

## 9. Open questions (to resolve during planning, non-blocking)

- Exact button/menu label text and icon for the two entry points (implementation detail, not a design
  fork).
- Whether `OrderInversion.sharesPrimaryMuscle` should be deleted outright or kept-but-unused for now,
  given it becomes redundant once only same-muscle inversions are ever constructed (lean toward deleting
  — no reason to keep dead state on a value type).
