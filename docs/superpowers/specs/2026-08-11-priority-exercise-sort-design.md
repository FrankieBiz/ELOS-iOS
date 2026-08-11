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
4. Using the feature as intended must not lower the day's own quality score. Fix the scoring
   inconsistency (§1) so the order-quality check only penalizes same-muscle inversions — which makes it
   inherently compatible with prioritized ordering without storing or looking up any new state.

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

Backward compatible: existing call sites (`CreateSplitView`'s per-day Sort button, `CreateTemplateView`'s
apply-order action, the "poor order" tip's fix action) omit `priority` and get identical behavior to
today.

When `priority` is non-nil:
1. Resolve each `DayExercise` to a `ResolvedExercise` via `ExerciseResolver.resolve` (already the
   standard resolution path — same one `FatigueModel`/`TemplateQualityEngine` use), to read
   `.isCompound` and `.muscleGroup` (`targets.primary.first?.group`).
2. Partition into `priorityGroup` (resolved `muscleGroup == priority`) and `rest` (everything else),
   preserving each exercise's original relative position within its partition.
3. Sort each partition independently using the existing compound-before-isolation rule (extract the
   current `rank(_:)` closure from `order` into a shared private helper so both partitions and the
   no-priority path use identical logic — no duplicated sort rule).
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
don't share a primary muscle are no longer computed at all — the pair-count denominator changes to only
same-muscle compound/isolation pairs (analogous to today's `totalPairs`, but restricted to pairs that
matter). This is the same criterion the tip text already applies to decide *what to say*; the fix makes
the *number* agree with it.

`OrderReport.inversions` keeps only same-muscle inversions (the ones ever worth surfacing) — the
`sharesPrimaryMuscle` field on `OrderInversion` becomes redundant with this filtering and can be dropped,
simplifying `FatigueScorer.swift:50` (`f.order.inversions.first(where: ...)` → `f.order.inversions.first`).

Net effect: a day sorted with an active priority (arm isolation before an unrelated leg compound) scores
identically to one sorted with no priority, on this dimension — because the two exercises don't share a
muscle, the pairing was never counted as an inversion in the first place, priority feature or not.

### 4.3 UI — `MuscleGroup` picker (shared)

A small SwiftUI `Menu` (matches existing patterns like `TemplatePickerSheet`'s selection UI) listing:
"Overall Best Growth", then `MuscleGroup.allCases` by `displayName`. Selecting an option returns the
chosen `MuscleGroup?` (nil for "Overall Best Growth") via a completion closure — a plain reusable view,
not tied to either builder, so both call sites share one implementation instead of two menus.

### 4.4 `CreateTemplateView` (primary entry point)

The existing "Apply ExerciseOrderer (compound-first)" button (`CreateTemplateView.swift:326-332`) becomes
the priority menu from §4.3. Selecting an option calls `ExerciseOrderer.order(asDays, catalog:,
priority:)` with the chosen value and applies the result exactly as today's button already does
(preserving each entry's settings, per the existing comment at line 326).

### 4.5 `CreateSplitView` (bulk action)

A new button, separate from the existing per-day "Sort" button
(`CreateSplitView.swift` — the `withAnimation { dayExercises[i] = ExerciseOrderer.order(...) }` call in
`dayRow`), labeled "Auto-order all days." Opens the same priority menu from §4.3; on selection, applies
`ExerciseOrderer.order(dayExercises[i], catalog:, priority:)` to every `i` where `!dayIsRest[i] &&
!dayExercises[i].isEmpty`, in one pass, wrapped in one `withAnimation`.

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
