# Muscle Coverage Coach — design spec

**Date:** 2026-07-28
**Branch:** `feat/muscle-coverage-coach`
**Status:** approved, in implementation

## Goal

Turn the existing `TemplateQualityEngine` from "a score plus some text tips" into a **visual coverage
coach**: fillable per-muscle-group bars in the template builder, a full-screen split report that shows
whether the week hits every muscle group with good movement selection, and a suggestions area on both
that actually does something when tapped.

## What already exists (do not rebuild)

Shipped 2026-06-28 (`docs/superpowers/specs/2026-06-28-template-quality-rating-design.md`):

- `TemplateQualityEngine.score(days:dayNames:scope:profile:catalog:)` → `QualityReport`
  (overall 0–100, tier, 4 `DimensionScore`s, merged/ranked `[QualityTip]`).
- Scorers: `VolumeScorer`, `BalanceScorer`, `SelectionScorer`, `RepRestScorer` — all pure, scope-aware.
- `TrainingScience` — every tunable constant in one file.
- `TrainingProfile` (`LiftingGoal` + `TrainingExperienceLevel`), read from `UserProfileRecord`.
- `ScoredExercise` / `ResolvedExercise` / `ExerciseResolver` — builder-agnostic scoring input.
- `TemplateQualityPanel` — the shared score-ring + dimension-bars + tips card.
- `MuscleTaxonomy` — `MuscleGroup` (7 broad), `isCompound`, archetype inference.

## Gaps this spec closes

1. `VolumeScorer` computes sets-per-muscle then **discards it** — the UI never sees per-muscle data.
   Template builder shows flat chips (`Chest 9×`) with no target and no fill.
2. Training intent is **inferred** from free-text day names (`BalanceScorer`: "this looks like a push
   day"). Nothing is user-selectable per template or per split.
3. Split builder renders the same cramped card as a template. Untrained muscle groups surface only as a
   text tip, never as a visibly empty bar.
4. Compound/isolation mix is computed in `SelectionScorer` but only emitted as a tip when it is *below*
   minimum — it can never simply be seen.
5. Frequency (times/week a muscle is trained) is not modelled at all. Sets/week alone cannot judge a split.
6. `QualityTip.action` (`addMuscle`/`addPattern`/`reorder`) is **discarded** by both builders —
   `CreateTemplateView` maps every tip tap to "open blank picker". `ExerciseOrderer` exists and is unused.
7. Duplicate muscle taxonomy: engines use `MuscleGroup` (7 cases) while `CreateTemplateView` carries its
   own `muscleKeyToLabel` / `muscleDisplayOrder` / `resolveMuscleLabelHeuristic`. Two sources of truth.
   `MuscleGroupPanelWeekly` also fetches SwiftData **inside a View** and invents `3` sets for unresolved
   names.

## Decisions (locked with the user)

**D1 — Bar granularity: broad bars, fine on tap.** Seven `MuscleGroup` rows; tapping one expands to its
fine sub-muscles. Keeps the default view scannable while still exposing quad/hamstring and bi/tri
imbalances, which a single `Legs` or `Arms` bar hides.

**D2 — Secondary muscles get half credit.** Primary = `sets × 1.0`, each secondary = `sets × 0.5`
(standard fractional-volume convention). Volume becomes `Double`. This makes bars honest — a push day of
presses correctly shows triceps partially filled instead of empty — and rewards compound selection.
Consequence: existing weekly landmarks were calibrated primary-only, so they must be recalibrated and
`VolumeScorerTests` updated.

## Architecture

Extends the established pure-engine pattern: all logic in value types under
`Features/Train/Programs/Intelligence/`, unit-tested with Swift Testing, views are thin consumers.
**No backend / `elos-shared` change** — entirely client-side, like `EquipmentPreference`.

### 1. Two-level muscle taxonomy (`MuscleTaxonomy`, extended)

New `FineMuscle` enum — the display-level slot between raw DB muscle strings and broad groups:

```
chest, lats, upperBack, frontDelts, sideDelts, rearDelts,
biceps, triceps, forearms, quads, hamstrings, glutes, calves, abs
```

Add `fine(forMuscle: String) -> FineMuscle?` and `group(forFine: FineMuscle) -> MuscleGroup`.

**Invariant:** `group(forFine: fine(forMuscle: m)) == group(forMuscle: m)` for every `m`. The existing
`group(forMuscle:)` is left byte-for-byte unchanged so nothing already tuned regresses; the fine layer
must agree with it. Covered by a test that walks every key in the DB muscle vocabulary.

Group → children:
- chest → chest · back → lats, upperBack, rearDelts · shoulders → frontDelts, sideDelts
- arms → biceps, triceps, forearms · legs → quads, hamstrings, calves · glutes → glutes · core → abs

(rearDelts under `back` and adductors/abductors folded into `glutes` mirror today's `group(forMuscle:)`.)

### 2. `TrainingIntent` — the thing the user selects

```swift
struct TrainingIntent: Equatable, Codable {
    var goal: LiftingGoal          // defaults from UserProfileRecord
    var focus: SessionFocus        // template only: push/pull/legs/upper/lower/fullBody/arms/core/custom
    var daysPerWeek: Int?          // split only
}
```

The highest-leverage piece: **explicit intent replaces name inference.** `focus` determines which fine
muscles are *expected* to be filled, so a Push template is never nagged about hamstrings, and
`BalanceScorer` stops string-matching day names (it falls back to inference only when `focus == .custom`).

Persistence is local-only via defaulted properties (the `equipmentPreferenceJSON` precedent →
lightweight migration, no backend contract change):
- `WorkoutTemplateRecord.intentJSON: String = ""` + computed `intent: TrainingIntent?`
- `WorkoutSplitRecord.intentJSON: String = ""` (same)

### 3. `MuscleVolumeAnalyzer` (new)

Single source of truth for per-muscle dosing. Consumed by both `VolumeScorer` and the UI so the bar and
the score can never disagree.

```swift
enum VolumeStatus { case untrained, under, productive, high, excessive }

struct MuscleVolumeBar: Identifiable {
    let fine: FineMuscle?          // nil for a group-level row
    let group: MuscleGroup
    let sets: Double               // fractional (primary 1.0 + secondary 0.5)
    let band: TrainingScience.VolumeBand   // mev / targetLow / targetHigh / mrv
    let fill: Double               // 0…1, targetLow→1.0; >1 clamps with overflow flag
    let status: VolumeStatus
    let isExpected: Bool           // per the intent
    let children: [MuscleVolumeBar]
}
```

Group-row aggregation: `sets` = sum of children; `fill` = mean of **expected** children's fills;
`status` = worst expected child. Deliberately *not* a summed target band — summing per-muscle targets
invents a number that means nothing (calves and quads don't need equal volume). The group row summarizes;
tapping reveals which child is the problem.

Unexpected + untrained fine muscles are hidden rather than shown failing.

### 4. `MovementQualityAnalyzer` (new)

```swift
struct MovementProfile {
    let compoundSets: Double, isolationSets: Double
    let compoundFraction: Double
    let setsByPattern: [String: Double]   // squat/hinge/push/pull/carry/isolation
    let missingPatterns: [String]         // vs. what the intent implies
}
```

`SelectionScorer` consumes this instead of recomputing the compound fraction itself.

### 5. `FrequencyScorer` (new — 5th dimension, weekly scope only)

Counts distinct days each fine muscle appears. Target ≥2×/week for the major groups (the
well-supported frequency recommendation). Emits tips like "Chest is only trained once this week —
splitting those 15 sets across two days grows more muscle."

`QualityDimension` gains `.frequency`. Weights:
- `.weeklySplit`: volume .28, balance .22, selection .20, repRest .15, frequency .15
- `.singleSession`: volume .30, balance .25, selection .25, repRest .20 (**unchanged** — frequency is not
  applicable, so existing template scores stay stable)

### 6. `QualityReport` (extended)

Gains `bars: [MuscleVolumeBar]` and `movement: MovementProfile?`. Existing fields unchanged, so
`TemplateQualityPanel` keeps working while the new UI is built.

## UI

### Template builder (`CreateTemplateView` / `TemplateBuilderView`)

- **Intent row** at the top: `Focus` menu + `Goal` menu. Focus pre-fills from the day name on first edit
  so it is never a blank chore.
- **`MuscleVolumeBarsView`** replaces `MuscleGroupPanel`'s chips: per group — label, fill bar with the
  target band drawn as a zone, `9 sets · 4–10 target`, colored by `status`, chevron to expand children.
  Tapping a bar opens the picker biased to that muscle group.
- Keeps `TemplateQualityPanel` for the score ring + dimension bars + tips.

### Split builder (`CreateSplitView`) — the "bigger screen"

Panel gains a **"See full report"** row presenting `SplitQualityReportView` (sheet, `NavigationStack`):

1. Score ring + tier + one-line plain-English verdict.
2. **Weekly muscle coverage** — all 7 groups incl. untrained ones as visibly empty bars, on the
   MEV → target → MRV ladder, expandable to fine muscles.
3. **Movement quality** — compound vs isolation stacked bar + pattern pills, missing patterns called out.
4. **Frequency** — ×/week per group, flagging anything trained once.
5. **Suggestions** — the full ranked tip list grouped by dimension, each with a working action button.
6. **Per-day breakdown** — day name, total sets, its own mini score.

### Make suggestions actionable (both builders)

Wire `TipAction` instead of discarding it:
- `.addMuscle(g)` → open `ExercisePickerView` biased to `g`
- `.addPattern(p)` → open picker biased to pattern `p`
- `.reorder` → apply `ExerciseOrderer` (already exists, currently unused) to the day

### Cleanup

Delete `muscleKeyToLabel` / `muscleDisplayOrder` / `resolveMuscleLabelHeuristic` /
`MuscleGroupPanel` / `MuscleGroupPanelWeekly` from `CreateTemplateView.swift`; route everything through
`MuscleTaxonomy` + `MuscleVolumeAnalyzer`. Removes the second taxonomy, the SwiftData-fetch-in-a-View,
and the fabricated `3`-set fallback.

## Phases

1. **Engine** — `FineMuscle` + taxonomy, fine landmarks in `TrainingScience`, `MuscleVolumeAnalyzer`,
   `MovementQualityAnalyzer`, `FrequencyScorer`, `TrainingIntent`, `QualityReport` fields; retune
   `VolumeScorer` for fractional volume. Tests for each; update `VolumeScorerTests`.
2. **Template UI** — intent row, `MuscleVolumeBarsView`, working tip actions.
3. **Split UI** — `SplitQualityReportView`.
4. **Persistence + cleanup** — `intentJSON` fields, delete the duplicate taxonomy, full green suite.

## Corrections made during phase 1

Recorded after a spec review + implementation; these supersede the text above where they conflict.

**C1 — Direct vs indirect sets are tracked separately (`MuscleCredit`).** The spec's half-credit
decision, taken alone, would have made `BalanceScorer` contradict the bars: bench + incline press gives
the triceps real fractional volume but *zero direct work*, so "no direct triceps work" and "the triceps
bar is partly filled" are both true. Rather than pick one number, `MuscleCredit` carries
`direct` + `indirect`. Coverage tips (`bal-gap-*`, `bal-noham`) read **direct** sets — the correct
coaching — while bars render both segments. `VolumeScorer` grades only muscles with direct work, judged
on their *total*; a muscle with indirect volume only is a coverage gap, so grading it there too would
report the same mistake twice. Consequence: `bal-gap-*` now distinguishes "only gets indirect work"
(info) from "no work at all" (warn).

**C2 — `group(forMuscle:)` is now *derived* from `fine(forMuscle:)`,** not kept byte-for-byte as the
spec proposed. This makes the invariant structural rather than something a test has to police across two
parallel keyword ladders. `MuscleTaxonomy.knownMuscleVocabulary` ships the authoritative 27-string
vocabulary so the test walks real data. Two deliberate bug fixes fall out: `external_rotators` /
`internal_rotators` used to resolve to `nil` (7 seeded exercises invisible to every scorer) and now map
to `.shoulders`; `hip_flexors` used to hit the generic `contains("hip")` test and land in `.glutes`, and
now correctly maps to `.core`.

**C3 — `VolumeBand.isOptional` is stored, not derived from `mev == 0`.** Every *per-session* band has an
MEV of 0 (no single workout must train any given muscle), so deriving the flag marked all session bands
optional and silently emptied session volume scoring. Caught by the harness — it was the only real bug
the 242 assertions found.

**C4 — Movement patterns.** The production vocabulary is exactly eight values (`squat, hinge, push,
pull, carry, rotation, core, isolation`), verified against both `ExerciseSeedData.swift` and the API seed
migrations — the spec's list omitted `core`. Patterns outside it (`curl`, `raise`, `pushdown`,
`extension`, which appear in *test fixtures* and in user-created exercises) fold onto `isolation` via
`displayBucket(forPattern:)` rather than vanishing from the breakdown.

**C5 — `SelectionScorer` keeps the by-*count* compound fraction.** `MovementProfile` exposes
`compoundFractionByCount` (scoring input, what `minCompoundFraction` was tuned against) and
`compoundFractionBySets` (what the stacked bar renders). Switching the scorer to by-sets would have
silently retuned a shipped score.

**C6 — `TipAction.reorder` carries a `dayIndex`.** At weekly scope there is no implicit "the day".

**C7 — Scope-keyed weights; `TrainingIntent.daysPerWeek` cut** (no consumer — days/week is already
derivable from the split's rest toggles). `focus` reuses `SplitArchetype` rather than introducing a
near-duplicate `SessionFocus`.

**C8 — Honesty correction on scores.** The claim that single-session scores stay "unchanged" is
withdrawn. The session *weight vector* is unchanged, so scores stay comparable, but they do shift a few
points because volume is now counted fractionally at the fine-muscle level. That's more accurate input,
not a regression.

## Verification reality

`xcodebuild test` **cannot run in this environment** — the iOS test host needs a pty and `openpty` is
blocked by the sandbox (`EXIT=133 / Pseudo Terminal Setup Error`). Builds also need
`OTHER_SWIFT_FLAGS='$(inherited) -disable-sandbox'` or the Swift macro plugin server dies. See the
`sandboxed-xcodebuild` memory.

What was actually verified for phase 1:
- `xcodebuild build-for-testing` clean (app target **and** `ElosTests` compile, zero errors).
- **242/242 assertions green** in a standalone `swiftc` harness compiling the pure Intelligence layer
  natively on macOS, mirroring the Swift Testing cases and covering the taxonomy invariant over the full
  vocabulary, fractional credit, the fill/status ladder, group aggregation incl. the zero-expected-children
  NaN guard, and every preserved scorer behavior.
- **Not** verified: the `ElosTests` suite actually executing on a simulator. That run is still owed.

## Risks

- **Recalibrating volume landmarks for fractional counting is the main regression risk.** Landmarks move
  and `VolumeScorerTests` must be rewritten. Mitigation: fine-grained landmarks are a new table
  calibrated for fractional counting from the start, and the single-session weight vector is unchanged so
  template scores stay comparable.
- Bar rows must not recompute the analyzer per row — compute the report once per builder body and pass
  it down (the engine is pure and cheap, but O(rows × catalog) resolution would not be).
- Dynamic Type: bars need `.fixedSize`/wrapping care; the recent accessibility polish commit
  (`c1f7cf8`) set the bar for this screen.

## Build / test

```
xcodebuild test -scheme Elos -destination 'id=<iPhone17 udid>' -parallel-testing-enabled NO
```

`-parallel-testing-enabled NO` is mandatory — parallel sim clones intermittently report all assigned
tests as `failed (0.000s)`. Baseline before this work: 91 tests / 23 suites green.
