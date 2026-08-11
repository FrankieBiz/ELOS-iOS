# Muscle exclusion, rater on/off, and cited volume recommendations — design spec

**Date:** 2026-08-11
**Branch:** `feat/muscle-coverage-coach`
**Status:** approved by user, pre-implementation

## Goal

Close three gaps in the shipped muscle-coverage-coach system (`docs/superpowers/specs/2026-07-28-muscle-coverage-coach-design.md`, `2026-06-28-template-quality-rating-design.md`):

1. A lifter who deliberately doesn't train a given muscle on a given day/template (e.g. no lower back
   on an Upper day) has no way to say so — the engine can only infer expectations from day-name/archetype,
   with no user override, so intentional omissions can still read as gaps.
2. There is no way to hide the 0–100 score/tips layer for a lifter who doesn't want to be rated.
3. `VolumeTargetsView`'s per-group weekly-set picker has no explanation of *why* the science defaults are
   what they are, and no way to say "I'm not training this muscle" (today the picker's floor is 4 sets).

## What already exists (do not rebuild)

- `TemplateQualityEngine`, `VolumeScorer`, `BalanceScorer`, `FrequencyScorer`, `SelectionScorer`,
  `RepRestScorer` — pure, scope-aware scorers under `Features/Train/Programs/Intelligence/`.
- `TrainingScience.VolumeBand.isOptional` — **already the exact mechanism this spec needs.** Currently
  hardcoded `true` for rotator cuff / forearms only. Already respected everywhere that matters:
  `VolumeScorer` and `FrequencyScorer` skip optional muscles entirely (no grading, no tip), and
  `MuscleBarRow.isMuted` renders an optional muscle greyed-out with an "optional" accessibility label
  instead of a red gap.
- `TrainingIntent` (`goal` + `focus`) — already persisted per-template via
  `WorkoutTemplateRecord.intentJSON`, already rendered by `TrainingIntentRow` as a chip row in
  `CreateTemplateView`. `CreateSplitView` has exactly one split-wide `TrainingIntent` (goal only —
  `focus` is always `nil` at weekly scope), **not** one per day.
- `VolumeOverrides` (`preference` + `groupWeeklyTarget`) — the *global*, profile-level override struct
  behind `VolumeTargetsView`, persisted as `AppViewModel.volumeOverrides` (`elos.volumeOverrides`).
  Deliberately group-level (7 `MuscleGroup`s), not fine-muscle, because a 16-field numeric form is a
  worse product than one multiplier plus a handful of group targets — that reasoning does not apply to a
  yes/no exclusion checklist, which is a different (lower-cognitive-load) control.
- `CreateSplitView.daySummaries` — **already scores each split day individually** at `.singleSession`
  scope, one call per day, feeding the per-day numbers in `SplitQualityReportView`'s full report. This is
  the second place (besides standalone templates) where a day-level exclusion has to take effect.
- `MuscleTargetSheet` — the proven working pattern for "pick several muscles from a grouped list": a
  `.sheet` with `Button` rows + checkmark circles, **not** `Toggle`. Reused verbatim for the new exclusion
  picker (see Risks — `Toggle` inside a similar List/sheet context has previously failed to fire at all).

## Decisions (locked with the user)

**D1 — Exclusion is per-day/per-template, not a global preference**, and explicitly does **not** roll up
into a split's weekly report. Excluding lower back on the Upper day only affects that day's own
`.singleSession` score; the split's `.weeklySplit` aggregate keeps grading lower back from whatever
actually happens across the whole week. If a lifter wants to quiet the *weekly* volume nag for a muscle
they train less by design, that's what the global Volume Targets screen (part 3, D5 below) is for — a
separate, already-existing lever, now extended with its own exclusion state.

**D2 — Fine-muscle granularity**, not `MuscleGroup`. "Lower back" is one of four children of the `back`
group (with lats, upper back, rear delts); excluding the whole group would also stop expecting
lats/rows, which is not the ask.

**D3 — Both standalone templates and individual split days get the picker.** Templates are the smaller
lift (one `TrainingIntent`, already day-scoped). Split days need new per-day storage since none exists
today.

**D4 — Rater toggle hides score + tips only**, not the coverage bars. Lives in `SettingsView`'s existing
"Training" section.

**D5 — Real, named citations**, scoped honestly: the literature reports dose-response findings per
*muscle group*, not per fine muscle, so citations are shared across a group's fine muscles rather than
invented per fine muscle.

## Architecture

All new logic stays in pure value types under `Intelligence/`; no backend / `elos-shared` change (same
local-only-JSON precedent as `intentJSON`/`muscleTargetsJSON`).

### 1. Exclusion plumbing — extend `isOptional`'s inputs, not its consumers

```swift
// VolumeOverrides — the GLOBAL, profile-level struct (VolumeTargetsView)
struct VolumeOverrides: Equatable, Codable {
    var preference: VolumePreference = .standard
    var groupWeeklyTarget: [String: Int] = [:]
    var excludedMuscles: Set<FineMuscle> = []   // NEW — "not training this, anywhere"
    var isCustomized: Bool { preference != .standard || !groupWeeklyTarget.isEmpty || !excludedMuscles.isEmpty }
}

// TrainingIntent — the PER-DAY/PER-TEMPLATE struct
struct TrainingIntent: Equatable, Codable {
    var goal: LiftingGoal
    var focus: SplitArchetype?
    var excludedMuscles: Set<FineMuscle> = []   // NEW — "not training this, today"
}
```

**Both** `TrainingIntent` **and** `VolumeOverrides` need a custom `init(from:)`
(`decodeIfPresent(...) ?? []`) so records saved before this ships still decode — synthesized `Decodable`
would otherwise throw `keyNotFound` on the missing key, not just for templates but for `VolumeOverrides`
too: it's decoded at `AppViewModel.swift:129` via `try? JSONDecoder().decode(VolumeOverrides.self, ...)`,
and on a thrown decode the `try?` silently yields `nil`, resetting every existing user's saved
`preference` *and* `groupWeeklyTarget` entries back to defaults on upgrade — the exact same failure mode
as `TrainingIntent`, just on the global Volume Targets screen instead of a per-template blob. `isCustomized`
also gains the `excludedMuscles` clause above so a lifter who has *only* set a global exclusion (no
numeric override) still shows the "Custom" badge in Settings and gets the reset affordance.

**The merge point is `TemplateQualityEngine.score(days:dayNames:scope:profile:catalog:intent:)` itself —
this file does change, as its very first step, before anything else runs:**

```swift
static func score(days: [[ScoredExercise]], dayNames: [String], scope: QualityScope,
                  profile: TrainingProfile, catalog: [ExerciseCandidate],
                  intent: TrainingIntent? = nil) -> QualityReport {
    // Day-scoped exclusions only apply at the scope a single day actually has — D1 is enforced
    // here, not by trusting every call site to withhold them. `.weeklySplit` never unions `intent`'s
    // set in, so a `TrainingIntent.excludedMuscles` handed to a weekly call is provably inert,
    // regardless of what any UI does or does not write to it.
    let dayScoped: Set<FineMuscle> = scope == .singleSession ? (intent?.excludedMuscles ?? []) : []
    let excluded = profile.volumeOverrides.excludedMuscles.union(dayScoped)
    var overrides = profile.volumeOverrides
    overrides.excludedMuscles = excluded
    let profile = TrainingProfile(goal: profile.goal, experience: profile.experience, volumeOverrides: overrides)
    // ...unchanged from here except BalanceScorer's call, which gains `excludedMuscles: excluded` (see
    // below): MuscleVolumeAnalyzer.analyze(..., profile: profile, ...), VolumeScorer.score(..., profile: profile),
    // FrequencyScorer.score(..., profile: profile), etc. all now see the merged exclusion set for free.
```

`weeklyBand(for:profile:)`/`sessionBand(for:profile:)` change too (they're what actually reads
`profile.volumeOverrides.excludedMuscles` to force `isOptional = true` and zero the targets, matching how
`rotatorCuff`/`forearms` are already defined) — but **every other consumer downstream of `profile`**
(`VolumeScorer`, `FrequencyScorer`, `MuscleVolumeAnalyzer`/bars) needs no change, because they already just
forward whatever `profile` they're handed into those two functions.

`BalanceScorer.score` is the one exception that does need a new parameter: it doesn't take `profile:`
today (only `intent:`, used for `focus`), so it can't see the *global* exclusion set on its own. Add
`excludedMuscles: Set<FineMuscle>` as an explicit param (`TemplateQualityEngine` computes it once, at the
same merge point above, and passes it to both the profile rebuild and this call) and skip a `MuscleGroup`
in both group-loops (`weeklySplit`'s five majors, `singleSession`'s `archetypeGroups`) when every one of
its `children` is in that set. (This does not change behavior for the lower-back example — "back" already
only requires *any* back-group work, and the archetype table doesn't list lower back as expected for
`.upper` in the first place — but it closes the real edge case of excluding an entire group.)

**Why D1 (day-scoped, no weekly roll-up) holds structurally, not by convention:** the `scope ==
.singleSession` check in the merge above is the actual guarantee — a `.weeklySplit` call never unions
`intent?.excludedMuscles` in at all, so it is inert there by construction, independent of any UI. This is
deliberately defense-in-depth rather than relying solely on call-site discipline: even if a future screen
mistakenly handed a populated `TrainingIntent` into a weekly-scope call, the engine would still ignore its
`excludedMuscles`.

The UI layer gets a second, belt-and-suspenders fix on top, for a different reason — not correctness, but
so the control itself never appears somewhere it would silently no-op: `TrainingIntentRow` is a **shared**
component, used both by `CreateTemplateView` (day scope, `$intent`) and by `CreateSplitView`'s weekly panel
(`CreateSplitView.swift:249`, `TrainingIntentRow(intent: $intent, showsFocus: false)` — the *same*
split-wide `intent` that feeds the weekly score, and whose `excludedMuscles` the engine now ignores at that
scope regardless). `TrainingIntentRow` already solves exactly this "don't show a control that means nothing
here" problem for the focus chip via `showsFocus: Bool = true`, gated `false` at that one weekly call site.
The new "Skip muscles" chip gets the identical treatment: add `showsSkip: Bool = true`, render the chip
only `if showsSkip`, and pass `showsSkip: false` alongside the existing `showsFocus: false` at
`CreateSplitView.swift:249`. (The per-day path is unaffected either way — `dayRow`'s new chip binds to
`dayExcludedMuscles[i]`, not `intent`, and was never routed through the weekly `TrainingIntentRow`
instance.)

`daySummaries` (per-day, line ~262) is the one call site that must change to construct a fresh
`TrainingIntent(goal: intent.goal, focus: nil, excludedMuscles: dayExcludedMuscles[i])` per day, in place
of passing no intent at all today. `CreateTemplateView.qualityReport` (line 274) already passes its one
`intent` — once `TrainingIntentRow`'s new chip (with `showsSkip` defaulting `true` there) writes to
`intent.excludedMuscles`, no call-site change is needed there beyond the engine fix above.

### 2. Per-day storage for split days

`UserSplitDayRecord` gains:
```swift
var excludedMusclesJSON: String = ""   // SwiftData lightweight migration, same shape as intentJSON
var excludedMuscles: Set<FineMuscle> {
    get { /* decode, [] on empty/failure */ }
    set { /* encode */ }
}
```

`CreateSplitView` gains `@State private var dayExcludedMuscles: [Set<FineMuscle>] = Array(repeating: [], count: 7)`.
Load path mirrors `dayIsRest`/`dayTemplateIDs` (`.onAppear`, from each loaded `UserSplitDayRecord`). Save
path is `saveSplit()`'s `buildDays(for:)` (`CreateSplitView.swift:510`), which already rebuilds every
`UserSplitDayRecord` from the `@State` arrays on *every* save (edit or create) rather than mutating
existing records — `excludedMusclesJSON: encode(dayExcludedMuscles[i])` is one more field in that same
per-day `UserSplitDayRecord(...)` initializer call (line 515), no new code path. `daySummaries`' existing
per-day `.singleSession` scoring call constructs an ad-hoc
`TrainingIntent(goal: intent.goal, focus: nil, excludedMuscles: dayExcludedMuscles[i])` just for that call
— nothing persists a redundant per-day goal.

### 3. Cited recommendations

```swift
struct ResearchCitation {
    let authors: String   // "Schoenfeld, Grgic & Krieger"
    let year: Int
    let title: String
    let finding: String   // one sentence, plain English
}

enum TrainingScience {
    static let citations: [ResearchCitation] = [
        // sets-per-week dose-response — backs the mev/targetLow/targetHigh numbers themselves
        .init(authors: "Schoenfeld, Grgic & Krieger", year: 2017,
              title: "Dose-response relationship between weekly resistance training volume and increases in muscle mass",
              finding: "More weekly sets per muscle (up to ~20) reliably produced more muscle growth across the studies reviewed."),
        // frequency — backs targetWeeklyFrequency / FrequencyScorer
        .init(authors: "Schoenfeld, Grgic & Krieger", year: 2019,
              title: "How many times per week should a muscle be trained to maximize muscle hypertrophy?",
              finding: "Spreading the same weekly volume across 2+ sessions tended to build more muscle than cramming it into one."),
        // MEV/target/MRV framework itself
        .init(authors: "Israetel & Renaissance Periodization", year: 2019,
              title: "The Renaissance Periodization volume-landmarks framework (MEV/MAV/MRV)",
              finding: "Frames a productive range between a minimum that's worth doing and a maximum you can still recover from."),
    ]
}

extension MuscleGroup {
    var volumeRationale: String { /* one sentence per group, e.g. */
        // .back: "Back covers a lot of muscle mass and responds well to being trained twice a week."
    }
}
```

Seven one-sentence `rationale` strings (one per `MuscleGroup`), each a plain-English gloss tied back to
the shared citations above — not seven separate studies.

## UI

### Exclusion picker ("Skip muscles")

New sheet, `SkipMusclesSheet`, built on `MuscleTargetSheet`'s proven shape: `NavigationStack` → `List` →
`Section` per `MuscleGroup` → `Button` rows (checkmark circle, **not** `Toggle`) toggling membership in a
`Set<FineMuscle>`, Cancel/Done toolbar. Structurally this chip is unlike `focusChip`/`goalChip` (both
`Menu`s) — it opens a `.sheet`, so `TrainingIntentRow` needs its own local `@State` presentation flag to
drive that, not just another `Menu` label.

- `TrainingIntentRow` gains a third chip ("Skip muscles", badge = count when > 0) opening the sheet bound
  to `intent.excludedMuscles`, gated by a new `showsSkip: Bool = true` param (same shape as the existing
  `showsFocus`). Used as-is (both default `true`) in `CreateTemplateView`. `CreateSplitView`'s weekly-panel
  call (`CreateSplitView.swift:249`) passes `showsSkip: false` alongside its existing `showsFocus: false`
  — the chip must never appear on the weekly row, since that row's `intent` feeds the `.weeklySplit`
  score and any write there would silently violate D1 (see Architecture §1).
- `CreateSplitView`'s day rows gain the same chip, bound to `dayExcludedMuscles[i]` — not to `intent` at
  all, so it's unaffected by the `showsSkip` gate above.
- `MuscleBarRow` needs no change — it already renders `isOptional` muscles muted with an "optional" label,
  which is exactly the right treatment for an excluded muscle.

### Rater toggle

- `AppViewModel.showQualityRater: Bool = true`, persisted to `UserDefaults` like other boolean prefs.
- `SettingsView`"Training" section: `Toggle("Show Quality Rating", isOn: $vm.showQualityRater)`.
- `CreateTemplateView`/`CreateSplitView` wrap only their `TemplateQualityPanel` call (and, transitively,
  the "See full report" → `SplitQualityReportView` path) in `if vm.showQualityRater`. The coverage-bars
  component differs by screen — `CreateSplitView.qualityPanel` (line 95) is a standalone
  `@ViewBuilder` var, a sibling view within the same `Section` as `MuscleGroupPanelWeekly` (line 87), so
  wrapping just `qualityPanel`'s call site is enough — no structural change needed there. `CreateTemplateView`
  (line 384–413) currently renders `TemplateQualityPanel` and `MuscleCoverageBars` as two views inside the
  *same* `VStack`/`Section` — the fix there is to wrap just the `TemplateQualityPanel` call in the `if`,
  leaving `MuscleCoverageBars` and its enclosing `Section` unconditional, not to gate the whole section.

### Volume Targets citations

- `GroupTargetEditor` (the pushed per-group picker) gains a footer line: the group's `volumeRationale`,
  plus a `DisclosureGroup` ("Sources") listing the 2–3 shared citations in full (authors, year, title,
  finding) — shown per group but only ever the same shared list, not duplicated research.
- `VolumeTargetsView`'s group rows and the `GroupTargetEditor`'s existing weekly-sets picker gain the
  exclusion option: the picker's sentinel-0 row ("Default (low–high)") is joined by a second sentinel
  ("Not training this") that sets `vm.volumeOverrides.excludedMuscles` for that group's children (a group
  toggle at this global-preference layer, consistent with `VolumeOverrides` staying group-level for
  numeric targets — see D1/D5). This is the *global* exclusion lever; the per-day picker (previous
  section) is the *day-scoped* one.

## Phases

1. **Engine** — `VolumeOverrides.excludedMuscles`, `TrainingIntent.excludedMuscles` (+ backward-compatible
   decode), `weeklyBand`/`sessionBand` effective-exclusion logic, the merge step at the top of
   `TemplateQualityEngine.score` (rebuilds `profile` with unioned exclusions before calling any scorer),
   `BalanceScorer.score`'s new `excludedMuscles:` param + all-children-excluded group skip,
   `ResearchCitation` + `MuscleGroup.volumeRationale`. Unit tests for each (`TrainingScienceTests`,
   `TemplateQualityEngineTests`, `BalanceScorerTests`), including: one asserting a `TrainingIntent` with
   `excludedMuscles` set does *not* affect a `.weeklySplit`-scope `score(...)` call (the direct regression
   test for D1, exercising the engine-level guarantee independent of any UI gating); and one decoding a
   pre-this-change JSON fixture through **both** `TrainingIntent(jsonString:)` and
   `VolumeOverrides`'s decode path (the latter as exercised by `AppViewModel`'s `try?
   JSONDecoder().decode(VolumeOverrides.self, ...)`), asserting neither silently drops existing data.
2. **Template UI** — `SkipMusclesSheet`, `TrainingIntentRow`'s third chip (+ `showsSkip` param), wired in
   `CreateTemplateView`.
3. **Split UI** — `UserSplitDayRecord.excludedMusclesJSON` (SwiftData migration), `dayExcludedMuscles`
   array + per-day chip in `CreateSplitView`, `showsSkip: false` on the weekly `TrainingIntentRow` call,
   `daySummaries`' ad-hoc per-day `TrainingIntent`.
4. **Rater toggle** — `AppViewModel.showQualityRater`, Settings row, gate both builders' panels.
5. **Volume Targets citations + global exclusion** — `GroupTargetEditor` footer/disclosure, the
   "Not training this" sentinel on the weekly-sets picker.

## Risks

- **`Toggle` inside a `List` in this exact sheet/push context has previously failed to fire at all**
  (`VolumeTargetsView`'s `GroupTargetEditor`, logged in the `volume-targets-and-fatigue` memory). The
  exclusion picker is built on `MuscleTargetSheet`'s `Button`-row pattern specifically to avoid
  reintroducing that bug. The new "Not training this" picker row is a `Picker` addition (proven to work),
  not a `Toggle`.
- **Old saved data decoding without `excludedMuscles`** — applies to **both** structs, not just
  `TrainingIntent`. `VolumeOverrides` is decoded at `AppViewModel.swift:129` via
  `try? JSONDecoder().decode(VolumeOverrides.self, ...)`; a thrown decode silently yields `nil` and resets
  every existing user's saved `preference` *and* `groupWeeklyTarget` back to defaults on upgrade — not a
  crash, but silent data loss, and easy to miss because the `try?` swallows the error entirely. Both
  structs need the custom `init(from:)` and both need a pre-this-change JSON fixture test.
- **Citation accuracy** — the three citations above are real, well-known papers/frameworks; still worth a
  final read-through against the actual abstracts before shipping copy that names them, since this is
  user-facing "cited studies" text people may act on.
- **Regression surface is small by design**: no existing scorer file's logic changes except
  `BalanceScorer`'s group loops (additive skip) and the two `TrainingScience` band functions (additive
  override check before the existing `return`). Existing tests for unaffected paths (no exclusions set)
  should be unaffected.

## Build / test

```
xcodebuild test -scheme Elos -destination 'id=<iPhone17 udid>' -parallel-testing-enabled NO
```

`-parallel-testing-enabled NO` is mandatory (parallel sim clones intermittently report false failures).
`xcodebuild test` may still be blocked in this sandbox (`sandboxed-xcodebuild` memory) — fall back to the
`swiftc` harness for the pure Intelligence-layer logic if so, and confirm `build-for-testing` compiles.
