# In-Set Interface — Core Package Redesign

**Date:** 2026-06-28
**Branch:** `feat/core-functionality-hardening`
**Status:** Approved (build directly)
**Target:** `Views/ActiveSessionView.swift` (the live workout / "in your set" screen) + `Features/Train/TrainViewModel.swift`

## Goal

Make the screen a lifter looks at *while performing and logging a set* as good as possible.
Scoped (by the user) to the **core friction-killer package** — the six changes with the highest
impact-per-effort. Remaining ideas (live e1RM/PR, machine-variant chip, per-muscle volume rail,
set-type tags, Live Activity, XP surfacing, etc.) are a documented roadmap, not in this build.

Grounded in an audit (workflow `in-set-ux-audit`, 7-lens ideation) of the current screen, whose
biggest frictions are: ~4–5 taps per set with no rapid-log; destructive edit path; RPE is a
skipped ghost field (which starves the overload engine); the rest timer scrolls away and dies
silently; the current set isn't the visual focus; the keyboard never dismisses.

## The six changes

1. **Rapid logging** — the previous-set numbers and the (currently display-only) overload
   suggestion become **tap-to-fill chips** that populate weight/reps. "+ Add set" inherits the
   previous set's values. After the first working set, one-tap **"apply to remaining"** copies down.
2. **Non-destructive inline edit + undo** — logged rows edit in place via a new
   `TrainViewModel.updateLoggedSet(...)` (updates the record instead of delete-and-retype).
   Completing a set shows a brief **"Set logged · Undo"** snackbar (~4s) to revert an accidental tap.
3. **RPE effort ladder** — replace the cramped typed RPE field with a glanceable tap ladder
   (6 · 7 · 7.5 · 8 · 8.5 · 9 · 9.5 · 10) with anchor hints. Feeds the `overloadSuggestion` engine.
4. **Smart sticky rest timer** — move the banner to a pinned `safeAreaInset(.bottom)` so it never
   scrolls away; **completion chime + haptic** at 0 (today it silently vanishes); **[−15]/[+15]**
   tap-to-adjust; a **"next: Set N"** preview.
5. **Single active-set focus + locked rows** — the current set is the visual anchor (a focus block
   with larger controls); completed sets collapse to compact **locked** summaries; muscle/secondary
   chrome demotes behind an ⓘ.
6. **Keyboard "Done" bar** — `@FocusState` + a numeric-pad toolbar (**Next →** weight→reps, **Done**).

## Architecture

- **Refactor `Views/ActiveSessionView.swift`** (647 lines, growing): extract `SessionExerciseCard`,
  the active-set focus block, the RPE ladder, the sticky rest bar, and the undo snackbar into focused
  files — filling the abandoned `Features/ActiveWorkout/` stubs (`SetRowView`, `RestTimerView`) so the
  structure matches its intended layout.
- **`TrainViewModel`** gains: `overloadTarget(...) -> (weightKg: Double, reps: Int)?` (structured form
  of the existing suggestion, for tap-to-fill) and `updateLoggedSet(...)` (non-destructive edit:
  update the `ExerciseSetRecord` + adjust `session.totalVolume`, re-sync via `WorkoutSyncService`).
- **No SwiftData model change** — RPE stays a `String` on `WorkSet`; the rest is view state + the two
  VM methods.
- **Pure, unit-tested helpers** (Swift Testing, matching the Intelligence culture): tap-to-fill target
  resolver, rest-adjust clamp, RPE ladder values.

## Decisions (tunable)

- RPE ladder: half-point steps 6→10.
- Undo window: ~4s.
- Rest adjust: ±15s, clamped ≥ 0.

## Out of scope (roadmap)

Live e1RM/PR-distance surfacing, in-card machine-variant chip + change warning, per-muscle volume
rail (would reuse the new quality engine), set-type tags (warm-up/working/AMRAP/drop), inline
history peek, plate math, warmup-ramp generator, keep-awake/crash-recovery/sync-status, Live Activity
+ Dynamic Island, XP fly-up / streak surfacing, swipe-to-complete, superset grouping, tempo capture.

## Testing

`xcodebuild test -scheme Elos -destination 'id=<iPhone17 udid>' -parallel-testing-enabled NO`
(parallel disabled — clones intermittently fail to launch the host app). New Swift Testing cases for
the pure helpers; build + manual verification for the view layer.
