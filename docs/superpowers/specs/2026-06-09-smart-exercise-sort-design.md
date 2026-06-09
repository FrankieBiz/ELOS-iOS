# Smart Exercise Sort & Intelligent Split Builder — Design

**Date:** 2026-06-09
**Status:** Approved (design); pending implementation plan
**Scope tier:** C — Full intelligent builder
**Default audience posture:** Both, adaptive (guide beginners, full override for power users)

## 1. Problem

When a user builds a workout split in Elos, exercise selection is weak in several ways:

- **Findability.** The exercise picker (`ExercisePickerView`) sorts the catalog alphabetically by name (`@Query(sort: \ExerciseDefinitionRecord.name)`). Related lifts scatter (Bench under "B", Incline Press under "I"); a user's go-to movements are not surfaced; Recent/Favorites live in separate tabs.
- **Context-blindness.** The picker treats every split day identically. It does not know that the day being built is a "Push" day, so it cannot float relevant movements up, does not order compounds before isolations, and does not discourage adding the same lift twice or piling up near-duplicate movements for one muscle.
- **Balance / quality.** A user can finish a "Pull" day with no rear-delt or hamstring work and receive no signal. There is no push/pull balance or weekly volume feedback.
- **Equipment reality.** Home-gym users wade through 1,697 commercial machines with no "what I actually own" filter.
- **Decision fatigue.** 378 built-in exercises plus 1,697 machines, no opinionated default ordering, and no starter scaffold for a chosen split archetype.
- **Ordering.** Exercises persist in add-order; there is no drag-to-reorder and no "order like a real program." Set/rep defaults are constant regardless of movement type.

The metadata required to fix all of this already exists and is unused for ordering: each `ExerciseDefinitionRecord` carries `primaryMuscle`, `secondaryMusclesJSON`, `equipment`, and `movementPattern`; the server already syncs recent and favorite exercises; and local `ExerciseSetRecord` history can supply usage frequency.

## 2. Goals

1. Replace alphabetical default ordering with a context-aware **Smart Sort** that knows which split day is being built.
2. Steer users toward balanced, well-ordered days with in-flow coverage feedback, best-practice ordering, and (for known archetypes) starter scaffolds.
3. Respect the user's available equipment.
4. Keep beginners guided and experienced lifters unblocked — every guidance element dismissible, every default overridable.
5. Introduce no backend contract changes for the core feature; work offline.

## 3. Non-goals

- No backend schema or API contract changes. (Equipment preference persists locally on `UserProfileRecord`; server sync of the preference is a possible later follow-up, explicitly out of scope here.)
- No change to how sets are logged or how progressive overload / PR detection works.
- No change to the machine/equipment database or the `MachineSelectionSheet` flow itself (Smart Sort *orders* machine results but does not redesign machine selection).
- No new exercise content; we rank the existing catalog.

## 4. Architecture

Today the picker's scoring is inline in `ExercisePickerView` (the `exerciseScore` / `machineScore` functions, ~lines 405–430). Per the repo rule "no business logic in views," all ranking and guidance logic moves into small, pure, unit-testable engines under a new folder:

```
apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/
  MuscleTaxonomy.swift          // single source of muscle grouping + classification
  DayContext.swift              // DayContext value type + DayContextInferrer
  ExerciseRankingEngine.swift   // Smart Sort scoring
  MuscleCoverage.swift          // coverage chips for the live strip
  PersonalizationProvider.swift // favorite + recency + local frequency
  EquipmentPreference.swift     // persisted equipment posture + matching
  SetRepDefaults.swift          // movementPattern -> default sets/reps
  ExerciseOrderer.swift         // order a day compounds -> accessories -> isolation
  SplitScaffolds.swift          // archetype -> recommended exercises
  WeeklyBalanceAnalyzer.swift   // push/pull balance + weekly volume landmarks
```

Each unit has one responsibility, communicates through value types, and is testable without SwiftUI. `ExercisePickerView` and `CreateSplitView` become thin consumers.

### 4.1 MuscleTaxonomy (foundation)

Single source of truth, replacing the keyword maps currently duplicated inline in `BodyPartFilter`:

- `bodyPart(forMuscle:)` — maps a normalized `primaryMuscle` (e.g. `rear_delts`) to a broad body part (Back/Shoulders/etc.). Reuses the existing keyword maps, centralized.
- `isCompound(movementPattern:)` — `push`/`pull`/`squat`/`hinge`/`carry` are compound; `isolation`/`rotation` are not. (Classification can be refined per-exercise later; pattern-based is the v1 rule.)
- `antagonist(of:)` — push↔pull, quads↔hamstrings, chest↔back, biceps↔triceps, etc.
- `targetMuscles(forArchetype:)` — e.g. Push → {chest, front_delts, side_delts, triceps}; Pull → {lats, back, rear_delts, biceps, traps}; Legs → {quads, hamstrings, glutes, calves}; Upper/Lower/Full Body likewise.
- `archetype(forDayName:)` — alias match from a free-text day name to an archetype (see 4.2).

### 4.2 DayContext + DayContextInferrer

`DayContext` is a value type describing the day being built:

```
struct DayContext {
  let dayName: String
  let inferredArchetype: SplitArchetype?       // .push, .pull, .legs, .upper, .lower, .fullBody, .custom(...)
  let targetMuscles: Set<String>               // union of archetype targets + muscles of added exercises
  let addedExercises: [DayExercise]            // already on this day
}
```

`DayContextInferrer.infer(dayName:added:)`:
1. Normalize the day name and alias-match to an archetype (reusing/extending the existing `gymAliases` map: "push", "pull", "legs", "chest & tri" → push, "back & bi" → pull, "upper", "lower", "full body", etc.).
2. Union the archetype's target muscles with the primary/secondary muscles of any already-added exercises.
3. If neither the name nor the added exercises yield a focus, `inferredArchetype = nil` and `targetMuscles = []` → ranking falls back to personalization + compound-first with **no** day penalties.

### 4.3 ExerciseRankingEngine (Smart Sort)

Pure function:
`rank(candidates:context:personalization:equipmentPref:query:) -> [ScoredExercise]`

Score per candidate:

```
score = W_day      * dayMatch(E, ctx)          // fraction of E's muscles/pattern in ctx.targetMuscles
      + W_compound * compoundPriority(E)         // 1 if compound else 0
      + W_pers     * personalization(E)          // normalized 0..1 (favorite + recency + frequency)
      + W_gap      * coverageGap(E, ctx)          // boost if E covers a target muscle not yet covered
      - W_dup      * duplicatePenalty(E, ctx)     // penalize same primaryMuscle+pattern already added
      - W_equip    * equipmentUnavailable(E, pref)// demote (never hide) unavailable equipment
      + W_query    * searchMatch(E, query)        // existing token/alias score, normalized
```

**Weight regimes** (exact constants to be finalized in implementation; relative ordering is the contract):

- **Searching** (`query.count >= 2`): `W_query` dominates all other terms combined, so typed search behaves as today. The existing `exerciseScore`/`machineScore` ladder (exact 100 / prefix 90 / contains 80 / all-tokens 70 / field 50) is preserved verbatim as the `searchMatch` term and normalized into the composite.
- **Browsing a known day** (`query` empty, `inferredArchetype != nil`): `W_day` and `W_compound` dominate, `W_pers` breaks ties, `W_gap` nudges toward uncovered muscles, `W_dup` pushes redundant picks down.
- **Browsing with no day context**: `W_day = W_gap = W_dup = 0`; personalization + compound-first order the list.

Properties: total and deterministic. Missing fields default to neutral (0 contribution). Empty candidate set returns empty. No randomness.

This ranking is applied to **both** generic exercise rows and machine (`EquipmentRecord`) results, so machine ordering also respects body-part match and equipment preference instead of plain brand/name alpha.

### 4.4 MuscleCoverage (live coverage strip)

`MuscleCoverage.compute(context:) -> [CoverageChip]` where each chip is a target muscle with a fill level:

- `none` (✗) — no added exercise targets it
- `some` (—/✓) — one exercise targets it as primary or secondary
- `good` (✓✓) — two or more

Rendered as a compact, collapsible strip at the top of the picker while building a split day (e.g. `Chest ✓✓ · Shoulders ✓ · Triceps — · Rear Delts ✗`). Tapping a chip applies that muscle as a filter/sort focus. The existing passive `MuscleGroupPanelWeekly` is retained for the whole-split weekly roll-up.

### 4.5 PersonalizationProvider

`score(forExerciseName:) -> Double` in 0..1, combining:

- **Favorite** — boolean from the server-synced favorites already loaded by `ExercisePickerViewModel`.
- **Recency** — rank within the server-synced recent list.
- **Frequency** — count of `ExerciseSetRecord` rows for that exercise (by name, and by `equipmentDedupeKey` where present) over a recent window (e.g. last 8 weeks), read locally from SwiftData.

If server signals are unavailable (offline), frequency from local history still works; if there is no history at all, the provider returns a neutral 0 for every exercise (ranking degrades gracefully to day-context + compound order).

### 4.6 EquipmentPreference

Persisted posture stored as a new local field on `UserProfileRecord` (e.g. `equipmentPreferenceJSON`), with values:

- `.fullGym` (default; no demotion)
- `.home` (a curated allowed set: barbell, dumbbell, kettlebell, bodyweight, optionally cable)
- `.custom(Set<EquipmentType>)`

Note: there is no `EquipmentType` type today — equipment is handled as raw strings (`EquipmentFilter` raw values, `EquipmentRecord.equipmentType: String`). Implementation introduces a small `EquipmentType` enum (or types the set as `Set<EquipmentFilter>`); it is net-new, not an existing type to reuse.

`equipmentUnavailable(E, pref)` returns 1 when E's equipment type is not in the allowed set, else 0. Unavailable items are **demoted, never hidden** (the user can still pick anything). If the preference is unset, treat as `.fullGym`.

### 4.7 SetRepDefaults

`defaults(forMovementPattern:) -> (sets: Int, reps: String)`. Compounds default to lower-rep/higher-set (e.g. 4 × 5–8); isolation to higher-rep (e.g. 3 × 10–15). Applied when an exercise is added to a day; fully editable afterward (the existing 2–5 set dropdown remains and is pre-seeded).

### 4.8 ExerciseOrderer

`order(_ exercises:) -> [DayExercise]` sorts a day compounds → accessories → isolation, secondarily by muscle size (large → small). Exposed as a per-day "Sort exercises" action; manual **drag-to-reorder** is also added to the day's exercise list in `CreateSplitView` (currently no reorder UI exists).

### 4.9 SplitScaffolds

`recommend(forArchetype:context:personalization:equipmentPref:) -> [DayExercise]` produces 4–6 exercises for a known archetype, built **through** `ExerciseRankingEngine` so picks are compound-first, balanced across the archetype's target muscles (one per target before doubling up), equipment-respecting, and de-duplicated. Surfaced as an "Auto-fill recommended" affordance shown only when `inferredArchetype != nil` and the day is empty. Deterministic. Never auto-applied — the user taps to accept, then edits.

### 4.10 WeeklyBalanceAnalyzer

`analyze(days:) -> [BalanceWarning]` across all 7 days:

- **Push/pull balance** — flags lopsided weekly counts (e.g. heavy pressing, little pulling).
- **Per-muscle weekly volume landmarks** — total weekly sets per muscle against simple landmarks (e.g. below ~10 sets = "low", above ~22 = "very high"); thresholds defined as named constants for easy tuning.

Surfaced as a banner/section in `CreateSplitView` (inline for beginners, subtle badge for experienced — see 4.11). Advisory only; never blocks saving.

### 4.11 Adaptive behavior

`UserProfileRecord.trainingExperience` (existing field; values `beginner` / `intermediate` / `advanced`) sets *initial* guidance verbosity only; it never restricts capability. The three values map to two postures: `beginner` → **Beginner**; `intermediate` and `advanced` → **Experienced**.

- **Beginner** → coverage strip expanded; "Auto-fill recommended" prompted on empty archetype days; balance warnings shown inline.
- **Experienced** → coverage strip collapsed; warnings shown as a subtle badge; sort control, filters, and reorder are front-and-center.

Every guidance element is dismissible and every default (sort mode, set/rep, ordering) is overridable. A user-flippable toggle to expand/collapse guidance is remembered locally.

## 5. Data flow

1. `CreateSplitView` holds per-day state (`dayNames[i]`, `dayExercises[i]`). When opening the picker for day *i*, it builds `DayContext` via `DayContextInferrer.infer(dayName: dayNames[i], added: dayExercises[i])` and reads the persisted `EquipmentPreference`.
2. It passes `DayContext` + `EquipmentPreference` into `ExercisePickerView`.
3. `ExercisePickerView` keeps its `@Query` to fetch the candidate set but applies `ExerciseRankingEngine.rank(...)` in a computed property instead of relying on `sort: \.name`. The sort control (Smart / A–Z / Most used / By muscle) chooses the comparator; Smart is default.
4. The coverage strip reads `MuscleCoverage.compute(context:)`, recomputed as exercises are added.
5. On add, `SetRepDefaults` seeds sets/reps for the new `DayExercise`.
6. "Auto-fill recommended" calls `SplitScaffolds.recommend(...)`; "Sort exercises" calls `ExerciseOrderer.order(...)`.
7. `WeeklyBalanceAnalyzer.analyze(days:)` runs over all days and surfaces a banner in `CreateSplitView`.

When the picker is opened **outside** split creation (e.g. mid-session "+ Add Exercise"), `DayContext` is passed as `nil`/empty and Smart Sort degrades to personalization + compound-first — no regression to that flow.

## 6. Error handling & edge cases

- Ambiguous/empty day name → neutral context, no day penalties, never blocks.
- Offline / missing server signals → personalization uses local history; if none, neutral.
- Equipment preference unset → treated as `.fullGym`.
- Unknown archetype → "Auto-fill recommended" hidden rather than emitting junk.
- Scoring is total and deterministic; missing fields contribute 0; empty candidate set → empty list.
- Coverage/balance never block saving a split; they are advisory.
- Existing search behavior must not regress: when a query is present, results match today's ordering for the matched set.

## 7. Testing

Because logic is extracted from the View, each engine gets focused unit tests:

- `ExerciseRankingEngine`: push-day ranks push/chest/triceps above legs; compound > isolation at equal day-match; already-added exercise demoted; uncovered target muscle boosted; query present → query term dominates and order matches today's ladder.
- `DayContextInferrer`: "Push", "Pull", "Legs", "Chest & Tri", "Upper", "" → expected archetype + target muscles.
- `MuscleCoverage`: added exercises → expected chip fill levels.
- `EquipmentPreference`: `.home` demotes machine-only movements; `.fullGym` demotes nothing.
- `SetRepDefaults`: each pattern → expected defaults.
- `ExerciseOrderer`: mixed list → compounds first, isolation last.
- `SplitScaffolds`: PPL push archetype → balanced, compound-first, equipment-respecting, deterministic set with no duplicates.
- `WeeklyBalanceAnalyzer`: lopsided week → expected warnings; volume below/above landmarks flagged.

Views get light smoke coverage only (the engines carry the logic).

## 8. Phasing

Built in order so each phase is independently valuable and shippable:

1. **Phase 1 — Smart Sort core.** `MuscleTaxonomy`, `DayContext`/`DayContextInferrer`, `PersonalizationProvider`, `ExerciseRankingEngine`, sort control in `ExercisePickerView`, `SetRepDefaults`. (Findability + context ordering + smart defaults.)
2. **Phase 2 — Guidance.** `MuscleCoverage` strip, `EquipmentPreference` + filter, `ExerciseOrderer` + drag-reorder in `CreateSplitView`.
3. **Phase 3 — Intelligence.** `SplitScaffolds` auto-fill, `WeeklyBalanceAnalyzer`, adaptive verbosity wired to `trainingExperience`.

## 9. Open questions (to resolve during planning, non-blocking)

- Exact weight constants and the frequency window (8 weeks is a starting assumption).
- Whether `.home` includes cable by default.
- Precise weekly volume landmark thresholds per muscle (start from a single global pair, refine later).
- Whether the sort control persists per-user or resets to Smart each open (proposed: remember locally).
