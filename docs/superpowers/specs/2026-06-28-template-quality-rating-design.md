# Science-Based Template & Split Quality Rating — Design

**Date:** 2026-06-28
**Branch:** `feat/core-functionality-hardening`
**Status:** Approved (build directly)

## Goal

Make the template maker and split maker actively *coach* the user. As they build, show a
live **0–100 quality score** (with a tier label and per-dimension sub-bars) plus prioritized,
**science-based, goal-aware tips** for what's lacking and how to fix it.

## Decisions (locked)

- **Scope:** Both builders — `CreateTemplateView` (template maker, today has zero guidance)
  and `CreateSplitView` (split maker, today has a basic `WeeklyBalanceAnalyzer` banner).
  One shared scoring engine powers both.
- **Presentation:** 0–100 score + tier (`Needs work` / `Solid` / `Dialed in` / `Optimized`)
  with four sub-bars.
- **Surfacing:** Live, inline, recomputed on every edit.
- **Personalization:** Fully adapts to the saved profile — `trainingGoal`
  (strength / hypertrophy / endurance / weight_loss) and `trainingExperience`
  (beginner / intermediate / advanced).
- **Dimensions:** Volume · Balance · Selection & order · Rep ranges & rest.

## The scope problem (why one engine, two modes)

A template is *one workout*; a split is *a week*. Volume landmarks (MEV/MRV) are **weekly**.
Scoring a single Push-day template against weekly landmarks would flag every muscle as
under-trained. So the engine takes a `scope` (`.singleSession` / `.weeklySplit`) and swaps
its target tables and balance logic accordingly. A template is fed as a 1-day "week".

## Architecture

All logic is pure value-type engines under
`apps/elos-mobile/Elos/Elos/Features/Train/Programs/Intelligence/` — no SwiftUI/SwiftData/
network coupling, unit-tested with Swift Testing (the established pattern). **No backend or
`elos-shared` changes** — the science is entirely client-side. One shared SwiftUI component
(`TemplateQualityPanel`) renders the report in both builders.

### New engine files (`Intelligence/`)
- `TrainingProfile.swift` — `TrainingGoal`, `TrainingExperienceLevel`, `TrainingProfile`
  (+ `init(record:)`, `.default`).
- `TrainingScience.swift` — all tunable constants/tables (rep ranges, rest ranges, weekly
  volume landmarks, per-session dosing, balance ratios, compound-fraction minimums).
- `ScoredExercise.swift` — unified scoring input (`ScoredExercise`), `QualityScope`,
  `ResolvedExercise`, `ExerciseResolver` (maps to `ExerciseCandidate` by id then name).
- `QualityReport.swift` — output types: `QualityDimension`, `QualityTier`, `TipSeverity`,
  `TipAction`, `QualityTip`, `DimensionScore`, `QualityReport`.
- `VolumeScorer.swift`, `BalanceScorer.swift`, `SelectionScorer.swift`, `RepRestScorer.swift`
  — one dimension each, scope-aware, return a `DimensionScore` (0–100 + tips).
- `TemplateQualityEngine.swift` — orchestrator: resolves exercises, runs the four scorers,
  computes the weighted composite, merges/dedupes/ranks tips.

### UI
- `Programs/TemplateQualityPanel.swift` — shared component: score ring + tier + 4 sub-bars +
  ranked tips (gated/expandable by `GuidanceLevel`: beginners see it expanded, intermediate/
  advanced collapsed to the score). Optional `onTapTip` lets a tip open the Add-Exercise sheet.
- `CreateTemplateView` — adds `@Query` for defs + profile, computes the report
  (`scope: .singleSession`), renders the panel under the muscle panel (gate: ≥2 exercises).
- `CreateSplitView` — replaces the `balanceBanner` with the panel (`scope: .weeklySplit`,
  gate: ≥2 populated days). `WeeklyBalanceAnalyzer` stays (its tests remain) but is no longer
  used by the view.

## The science model (tunable defaults in `TrainingScience`)

**Rep range / set (goal):** strength 3–6 · hypertrophy 6–12 · endurance 15–25 · weight_loss 8–15.
**Rest / set (goal, compound):** strength 180–300s · hypertrophy 90–180s · endurance 30–60s ·
weight_loss 45–90s. (Isolation accepted a bit shorter.)

**Weekly volume (sets·muscle⁻¹·wk⁻¹) — MEV / target band / MRV, by experience:**
beginner 6 / 10–14 / 18 · intermediate 8 / 12–18 / 20 · advanced 10 / 16–20 / 22.

**Per-session dosing (`.singleSession`):** effective 4–10 sets/muscle; junk-volume warning above 12
on one muscle; total working sets sane at 9–30 (warn outside).

**Balance:** push/pull ratio limit 1.5×; antagonist (quad/hamstring) ratio limit 2×; coverage
gaps — weekly: any untrained major group (chest/back/legs/shoulders/arms) is a gap; single-session:
gaps judged only against the day's inferred focus (`DayContextInferrer`), and an unfocused session
training a single muscle group is flagged.

**Selection & order:** minimum compound fraction (beginner 0.5 / intermediate 0.4 / advanced 0.33);
hinge-presence check when legs are trained; compounds-sequenced-first per day.

## Scoring

Each scorer returns 0–100. Composite weights: **Volume 0.30 · Balance 0.25 · Selection 0.25 ·
Rep & rest 0.20**. Tiers: `<55 Needs work · 55–74 Solid · 75–89 Dialed in · 90+ Optimized`.

Tips carry `dimension`, `severity` (good/info/warn), a message (goal-aware, actionable), and an
optional `TipAction` (`addMuscle` / `addPattern` / `reorder`). The engine merges all dimension
tips, dedupes by id, ranks (severity desc, then weakest dimension first), and the panel caps the
inline list with a "+N more" expander.

## Edge cases

- Too few exercises (≤1 template / <2 populated split days, or <3 total for a split) → no panel
  (`isScored == false`) to avoid nagging mid-build.
- Unrecognized custom exercises (no `ExerciseCandidate`) → excluded from muscle math; scorers
  fall back to neutral scores rather than crashing.
- Unparseable reps (e.g. "AMRAP") / zero rest → skipped from that sub-score.
- Empty/missing profile → defaults to hypertrophy + intermediate.

## Testing

Swift Testing unit tests in `ElosTests/Intelligence/`: `TrainingProfileTests`, `VolumeScorerTests`,
`BalanceScorerTests`, `SelectionScorerTests`, `RepRestScorerTests`, `TemplateQualityEngineTests`.
Cover scope differences (same exercises score differently as session vs week), goal sensitivity
(rep dimension shifts strength vs hypertrophy), experience sensitivity (volume targets shift),
tip generation/ranking/dedupe, and the edge cases above.

## Out of scope (YAGNI)

Persisting/syncing the score, showing a quality badge on shared/imported templates, secondary-muscle
fractional volume, periodization across weeks.
