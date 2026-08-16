# Smart Exercise Substitution Engine + Evidence Hierarchy Foundation — Design

**Date:** 2026-08-14
**Branch:** `feat/muscle-coverage-coach`
**Status:** Approved (build directly)

## Goal

When a user swaps an exercise mid-workout (machine's busy, exercise doesn't fit, etc.), stop
handing them the entire 405-exercise catalog to search unaided. Rank the catalog by how well
each candidate matches what the swapped-out exercise was training, and surface the top 5 with a
plain-language reason. Pair it with a small, reusable "evidence hierarchy" component so the app
can honestly label how solid the science behind a claim is — this is the first feature to use it,
not the only one; every dimension weight below only earns "Medium-Low" certainty per this
session's research, and the badge is what keeps that claim visible instead of buried in code
comments.

## Background: why the scoring weights are what they are

Dedicated research this session (see conversation) into the "biomechanically-similar substitution
preserves training stimulus" premise found: no direct RCT tests substitution-outcome parity;
the closest analog (hip thrust vs. back squat) found similar hypertrophy and similar deadlift
transfer *despite* very different EMG activation — a direct counter-example to "closer muscle
activation match → better transfer." The mechanical-tension camp (Schoenfeld, Vigotsky) argues
total effective volume matters more than movement-signature matching. So this engine is framed
throughout as "matches primary muscle, movement pattern, and available equipment" — a defensible,
practical claim — never as "biomechanically optimal" or "proven to preserve results," which the
evidence doesn't support.

## Decisions (locked)

- **Scope:** In-session swap only (`ExerciseSwapSheet`). Split/template-builder integration and
  the equipment-constrained full-session generator ("one kettlebell, 20 minutes") are explicit
  fast-follows once this engine is proven, not part of this build.
- **Output:** Ranked list of up to 5 suggestions, each with a one-line reason, shown above the
  existing manual picker (which stays, unchanged, as "Or choose manually").
- **Evidence surfacing:** One evidence badge for the whole suggested section (not per-row) — the
  same caveat applies to all 5 results, repeating it per-row would just be noise.
- **No injury-awareness in this phase** (see below) — corrected after design approval, before
  writing code.

## Scope correction found during implementation prep

The original verbal design assumed the engine would defer to `InjurySubstitutionEngine`'s
hand-tuned map when an injury is flagged. Verifying the codebase turned up a blocking fact:
`InjuryEntry` / `InjurySeverity` / `InjuredPart` (`SplitFinderModels.swift`) only exist as
**transient input to the SplitFinder wizard** (`SplitFinderInput.injuries`, consumed by
`SplitRecommender` and `InjurySubstitutionEngine.apply(to:input:)`). There is no persisted
per-user injury profile anywhere in `ElosSchema.swift` — so `ExerciseSwapSheet`, reached mid-workout
outside that wizard, has no injury data available to check against. Building an injury-defer
branch that can never fire at its only call site would be dead code. **Dropped from this phase.**
Noted under Out of scope as the natural extension once injury persistence exists.

## Architecture

Fully client-side. No SwiftData schema change, no backend/`elos-shared` contract change — this
computes over data already loaded for the picker. New pure-logic engine + one new shared UI
component pair + one static data file + an addition to an existing sheet.

### New files

- **`Features/Train/Programs/Intelligence/ExerciseSubstitutionEngine.swift`** (corrected location —
  this is where `ExerciseCandidate.swift`, `MuscleTaxonomy.swift`, and `EquipmentPreference.swift`
  actually live; there is no top-level `Intelligence/`) — pure, Swift-Testing-covered. Operates on
  `ExerciseCandidate` (the existing shared unit "both `ExerciseDefinitionRecord` and the picker's
  server responses map into... so engines never touch SwiftData or the network" —
  `ExerciseCandidate.swift:3-4`), exactly like `TemplateQualityEngine` and the ranking engines
  already do. Signature:

  ```swift
  static func suggest(
      for source: ExerciseCandidate,
      candidates: [ExerciseCandidate],
      equipment: EquipmentPreference,
      limit: Int = 5
  ) -> [SubstitutionSuggestion]
  ```

  **Resolving `source`:** the exercise being swapped out is a session `Exercise`, not a catalog
  `ExerciseDefinitionRecord` — it carries no `movementPattern`, no catalog id, only an
  `equipmentId` (machine identity). The caller must resolve it to an `ExerciseCandidate` by
  matching `Exercise.name` against `candidates` via `MuscleTaxonomy.normalize` (so "Dumbbell
  Turkish  Get-Up" still matches its catalog twin — see the interior-double-space fix already
  in `MuscleTaxonomy.normalize`). **If no candidate matches** (custom exercise, renamed lift, name
  drift), `suggest` returns `[]` — there is no reliable signal to score against, so this is the
  same empty state as "nothing cleared the threshold," not a special case the caller needs to
  branch on separately.

  Scoring per candidate (excludes `source` itself, hard-filters out anything
  `equipment.isAvailable(equipment:)` rejects). The muscle tiers are mutually exclusive — a
  candidate earns exactly one of the three:
  - +3 exact `primaryMuscle` string match
  - +2 same `FineMuscle` bucket via `MuscleTaxonomy.fine(forMuscle:)` but different raw string
  - +1 same `MuscleGroup` only (via `MuscleTaxonomy.group(forMuscle:)`), and none of the above

  Plus, independently:
  - +1 same `movementPattern` — **but only when that shared pattern is one of the specific,
    informative values** (`squat`, `hinge`, `push`, `pull`, `carry`, `rotation`). The generic
    `isolation` bucket covers unrelated muscles indiscriminately (a leg extension and a bicep curl
    are both "isolation") — matching on it carries no signal, so it never earns this point.
  - +1 any shared secondary-muscle string
  - +1 same compound/isolation class (`MuscleTaxonomy.isCompound(movementPattern:)`) **only when
    `movementPattern` differs between source and candidate** — this rewards cross-pattern compound
    similarity (e.g. squat vs. hinge, both compound leg-dominant movements). When patterns are
    identical, the point above already captured that; awarding both double-counts one signal as two.

  These two corrections together close a real degenerate case: leg extension (quads, isolation)
  vs. leg curl (hamstrings, isolation) previously scored `MuscleGroup(+1) + movementPattern(+1)` =
  2 — clearing the threshold despite being antagonists with nothing else in common. With
  `isolation` excluded from the pattern-match bonus, this pair now scores 1 (group only) and
  correctly stays below threshold.

  - **Threshold:** score must be ≥ 2 to appear at all — a same-muscle-group-only match with
    nothing else in common is too weak to present as a "suggestion" rather than a browse result.
  - Sort descending by score, tie-break by name (determinism for tests), take `limit`.
  - Build a reason string from which components fired, e.g. "Same primary muscle (hamstrings) ·
    same hinge pattern." (Equipment is not part of the reason text — it's a hard filter, so it's
    true of every surfaced row and would distinguish nothing.)

  `SubstitutionSuggestion` (new small struct alongside the engine): `id`/`name` (from the matched
  `ExerciseCandidate`), `score`, `reason: String`.

- **`Features/Train/Programs/Intelligence/EvidenceLibrary.swift`** — static data, no persistence,
  one entry so far:

  ```swift
  enum EvidenceTopic: String { case exerciseSubstitution }
  struct EvidenceEntry {
      let claim: String
      let certainty: EvidenceCertainty   // .high / .medium / .low
      let explanation: String
  }
  enum EvidenceLibrary {
      static func entry(for topic: EvidenceTopic) -> EvidenceEntry { ... }
  }
  ```

  The `.exerciseSubstitution` entry's `explanation` states plainly that matching muscle/pattern/
  equipment is a reasonable, practical heuristic — not a proven-equivalent substitution — citing
  the hip-thrust-vs-squat finding as the honest counter-example. Written once now, while the
  research is fresh, so later features (training-load awareness, strength standards, etc.) add
  their own entries to the same enum rather than each feature inventing its own citation string.

- **`Components/EvidenceBadge.swift`** — small ⓘ affordance taking an `EvidenceTopic`, opens
  `EvidenceSheet` on tap: claim, a certainty pill (High/Medium/Low), the explanation. Lives beside
  other shared components per the existing "one shared component, not copies" pattern — every
  future science-backed feature reuses this same pair.

### Changed files

- **`Features/Train/ExerciseSwapSheet.swift`** — today this is a thin wrapper that hands control
  straight to `ExercisePickerView` (`ExerciseSwapSheet.swift:17-24`) and queries nothing itself —
  `dbExercises` and `profiles` currently live only in the child `ExercisePickerView`
  (`ExercisePickerView.swift:31-33`). This file adds its own
  `@Query(sort: \ExerciseDefinitionRecord.name) private var dbExercises: [ExerciseDefinitionRecord]`
  and `@Query private var profiles: [UserProfileRecord]`, mirroring the picker's own queries, so it
  can compute suggestions independently of the child view.

  It gains a "Suggested for you" section rendered above the picker: maps `dbExercises` through
  `ExerciseCandidate.init(record:)` (the existing conversion), resolves the bound `exercise` to its
  source candidate by normalized-name lookup (see "Resolving `source`" above), and calls
  `ExerciseSubstitutionEngine.suggest(...)` with `profiles.first?.equipmentPreference ?? .fullGym`
  (same default `ExercisePickerView` uses at line 33). Each row shows name + reason; tapping adopts
  via `exercise.adopt(PickedExercise(id: suggestion.id, name: suggestion.name), in: modelContext)`
  — `suggestion.id` is the catalog id (`ExerciseCandidate.init(record:)` sets it from `r.id`), and
  `adopt` re-resolves muscles/equipment/weight semantics from that id on its own
  (`Enums.swift:203`), so no richer `PickedExercise` payload is needed. This intentionally skips
  the machine-brand picker and muscle check-off that manual generic picks can trigger
  (`ExercisePickerView.swift:633,676`) — the same trade-off the picker's own direct-add path
  already makes (`ExercisePickerView.swift:783`). The existing duplicate-name check
  (`ExerciseSwapSheet.swift:19-22`) applies identically to suggestion taps. The existing
  `ExercisePickerView(onPickSingle:)` call is unchanged below the new section.

## Edge cases

- **No candidate scores ≥ 2** (e.g. an unusual custom exercise with an unmapped muscle string) →
  suggested section shows "No close matches found — browse manually below" rather than forcing
  weak results onto the list.
- **Custom exercises** with free-text muscle strings `MuscleTaxonomy.fine(forMuscle:)` can't
  classify → still eligible as *candidates* (scored on `movementPattern`/equipment only, since the
  muscle-match bonuses can't apply), still gated by the same ≥2 threshold.
- **Duplicate already in session** → suggestions run through the exact same `existingNames`
  collision check `ExerciseSwapSheet` already does for manual picks (`ExerciseSwapSheet.swift:19-22`)
  — no separate logic needed.

## Testing

`ExerciseSubstitutionEngine.suggest` is pure input → output — Swift Testing fixtures (not the live
405-row seed catalog, so tests don't break when seed data changes) covering:
- Barbell Back Squat unavailable (no barbell in equipment) → Goblet Squat/Leg Press rank above
  unrelated isolation exercises.
- Romanian Deadlift → hamstring-hinge alternatives rank above quad-dominant ones.
- Equipment hard-filter excludes anything `EquipmentPreference.isAvailable` rejects, regardless of
  score.
- Below-threshold candidates never appear (empty-state case).
- **Degenerate case from the spec review:** Leg Extension (quads, isolation) vs. Leg Curl
  (hamstrings, isolation) never surfaces for each other — same-`MuscleGroup`-only plus a generic
  `isolation` pattern match must NOT clear the ≥2 threshold.
- Compound-class point only fires on differing patterns (e.g. squat vs. hinge scores it; squat vs.
  squat does not get it twice on top of the pattern-match point).
- Source with no matching catalog candidate (name doesn't resolve, e.g. a custom exercise) →
  `suggest` returns `[]`, not a crash or a special-cased result.
- Tie-break is deterministic (alphabetical by name).

## Out of scope (YAGNI / fast-follows)

- Split/template-builder integration (same engine, different call site — natural next step).
- Equipment-constrained full-session generator ("one kettlebell, 20 minutes").
- Per-suggestion (vs. per-section) evidence badges.
- PubMed-link-level citations — `EvidenceEntry.explanation` is a written summary, not a citation
  database, for this phase.
- **Injury-aware in-session substitution** — blocked on persisting a per-user injury profile
  outside the SplitFinder wizard first (see Scope correction above). Once that exists, this engine
  can accept the same `[InjuryEntry]` `SplitRecommender`/`InjurySubstitutionEngine` already consume
  and defer to the hand-tuned map the same way `SplitRecommender` does today.
